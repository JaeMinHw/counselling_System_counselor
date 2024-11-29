import 'dart:async';
import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:syncfusion_flutter_core/core.dart';
import 'package:syncfusion_flutter_sliders/sliders.dart';
import 'package:intl/intl.dart';
import 'dart:convert'; // JSON 인코딩/디코딩
import 'dart:html' as html;
import 'dart:js' as js;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:syncfusion_flutter_sliders/sliders.dart';
import 'package:intl/intl.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

// WebSocket 채널 설정
final WebSocketChannel dataChannel =
    WebSocketChannel.connect(Uri.parse('ws://127.0.0.1:8765')); // 실시간 데이터 채널
final WebSocketChannel fullAudioChannel =
    WebSocketChannel.connect(Uri.parse('ws://127.0.0.1:8766')); // 전체 오디오 데이터 채널

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Combined Dashboard',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: CombinedDashboard(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class CombinedDashboard extends StatefulWidget {
  @override
  _CombinedDashboardState createState() => _CombinedDashboardState();
}

class _CombinedDashboardState extends State<CombinedDashboard> {
  IO.Socket? socket;
  bool _isConnected = false;
  bool _isConnectionRequested = false;
  bool _isConnectionAccepted = false;
  String _patientName = '';

  // 실시간 데이터 관련 상태 (1번 코드)
  List<ChartSampleData> chartData1 = [];
  List<ChartSampleData> chartData2 = [];
  List<ChartSampleData> chartData3 = [];
  late RangeController rangeController;
  DateTime _currentDate = DateTime.now();
  bool isStreaming = false;
  bool _isStreaming = false; // 데이터를 스트리밍 중인지 확인하는 플래그
  bool _isLineChart = true;
  late ZoomPanBehavior _zoomPanBehavior;
  int _currentIconIndex = 0;
  List<IconData> _icons = [
    Icons.auto_graph_rounded,
    Icons.star,
  ]; // Line과 Curve 변경 아이콘

  // 음성 녹음 관련 상태 (2번 코드)
  bool isRecording = false;
  bool isFullRecording = false;
  List<Map<String, dynamic>> messages = [];
  List<Uint8List> fullAudioData = [];
  html.MediaRecorder? mediaRecorder;
  html.MediaRecorder? fullMediaRecorder;

  @override
  void initState() {
    super.initState();
    _initializeAudioProcessing();

    // 1번 코드 초기화
    _zoomPanBehavior = ZoomPanBehavior(
      enablePinching: true,
      enableDoubleTapZooming: true,
      enableSelectionZooming: true,
      enablePanning: true,
    );

    rangeController = RangeController(
      start: DateTime.now().subtract(Duration(seconds: 5)),
      end: DateTime.now(),
    );

    // 2번 코드 WebSocket 초기화
    dataChannel.stream.listen((message) {
      final decodedMessage = json.decode(message);

      setState(() {
        if (decodedMessage is List) {
          for (var data in decodedMessage) {
            String text = data['text'] ?? '';
            if (text.isNotEmpty) {
              messages.add({
                "label": data['label'] ?? 'unknown',
                "text": text,
                "start": data['start'] ?? 0.0,
                "end": data['end'] ?? 0.0,
                "sentTime": data['send_time'] ?? '',
              });
            }
          }
        } else if (decodedMessage is Map<String, dynamic>) {
          String text = decodedMessage['text'] ?? '';
          if (text.isNotEmpty) {
            messages.add({
              "label": decodedMessage['label'] ?? 'unknown',
              "text": text,
              "start": decodedMessage['start'] ?? 0.0,
              "end": decodedMessage['end'] ?? 0.0,
              "sentTime": decodedMessage['send_time'] ?? '',
            });
          }
        }
      });
    });
  }

  void _initializeAudioProcessing() {
    js.context.callMethod('startAudioProcessing'); // 외부 VAD 호출

    html.window.addEventListener('audioStarted', (event) {
      if (!isRecording) {
        _startRecording();
      }
    });

    html.window.addEventListener('audioStopped', (event) {
      if (isRecording) {
        _stopRecording();
      }
    });
  }

  @override
  void dispose() {
    dataChannel.sink.close();
    fullAudioChannel.sink.close();
    rangeController.dispose();
    super.dispose();
  }

  void _connectWebSocket() {
    debugPrint("Attempting to connect to WebSocket...");

    socket = IO.io(
      'ws://218.151.124.83:5000',
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .enableAutoConnect()
          .enableForceNew()
          .setExtraHeaders({'Upgrade': 'websocket'})
          .build(),
    );

    socket!.onConnect((_) {
      setState(() {
        _isConnected = true;
      });
      debugPrint('Connected to the server');
      socket!.emit('counselor_login', {'counselor_id': '1'});
    });

    socket!.onDisconnect((_) {
      setState(() {
        _isConnected = false;
        _isConnectionRequested = false;
        _isConnectionAccepted = false;
      });
      debugPrint('Disconnected from the server');
    });

    socket!.on('connection_request', (data) {
      setState(() {
        _isConnectionRequested = true;
        _patientName = data['message'];
      });
      debugPrint('Connection requested by patient: $_patientName');
    });

    socket!.on('connection_accepted', (data) {
      setState(() {
        _isConnectionRequested = false;
        _isConnectionAccepted = true;
      });
      debugPrint('Connection accepted by server');
    });

    _setUpDataUpdateListener();
    socket!.connect();
  }

  void _setUpDataUpdateListener() {
    socket!.off('data_update'); // 기존 리스너 제거
    socket!.on('data_update', (data) {
      if (_isStreaming) {
        double newData1 = double.parse(data['data1'].toString());
        double newData2 = double.parse(data['data2'].toString());
        double newData3 = double.parse(data['data3'].toString());
        DateTime serverTime = data.containsKey('timestamp')
            ? DateTime.parse(data['timestamp'])
            : DateTime.now();
        _updateChartData(newData1, newData2, newData3, serverTime);
        debugPrint(
            "Received data update: data1=$newData1, data2=$newData2, data3=$newData3, time=$serverTime");
      }
    });
  }

  void _updateChartData(
      double data1, double data2, double data3, DateTime time) {
    setState(() {
      chartData1.add(ChartSampleData(x: time, y: data1));
      chartData2.add(ChartSampleData(x: time, y: data2));
      chartData3.add(ChartSampleData(x: time, y: data3));

      if (chartData1.length > 1000) {
        chartData1.removeAt(0);
        chartData2.removeAt(0);
        chartData3.removeAt(0);
      }

      rangeController.start = chartData1.last.x.subtract(Duration(seconds: 5));
      rangeController.end = chartData1.last.x;
    });
  }

  // 음성 녹음 시작
  Future<void> _startRecording() async {
    final stream =
        await html.window.navigator.mediaDevices!.getUserMedia({'audio': true});
    mediaRecorder = html.MediaRecorder(stream);

    mediaRecorder!.addEventListener('dataavailable', (event) {
      final blob = (event as html.BlobEvent).data;
      if (blob != null) {
        final reader = html.FileReader();
        reader.readAsArrayBuffer(blob);
        reader.onLoadEnd.listen((e) {
          final bytes = reader.result as Uint8List;

          final currentTime =
              DateTime.now().toIso8601String().substring(11, 19);
          print("Sending audio data of length: ${bytes.length}");

          final data = {
            "audio": bytes,
            "sentTime": currentTime,
          };

          dataChannel.sink.add(json.encode(data));
          print("Audio data sent to server with time: $currentTime");
        });
      } else {
        print("No data available in the blob.");
      }
    });

    mediaRecorder!.start();
    setState(() {
      isRecording = true;
    });
  }

  // 음성 녹음 정지
  void _stopRecording() {
    mediaRecorder?.stop();
    setState(() {
      isRecording = false;
    });
  }

  // 전체 오디오 녹음 시작
  Future<void> _startFullRecording() async {
    final stream =
        await html.window.navigator.mediaDevices!.getUserMedia({'audio': true});
    fullMediaRecorder = html.MediaRecorder(stream);

    fullMediaRecorder!.addEventListener('dataavailable', (event) {
      final blob = (event as html.BlobEvent).data;
      if (blob != null) {
        final reader = html.FileReader();
        reader.readAsArrayBuffer(blob);
        reader.onLoadEnd.listen((e) {
          final bytes = reader.result as Uint8List;

          fullAudioData.add(bytes); // 전체 오디오 데이터를 저장
          print("Recording full audio data of length: ${bytes.length}");
        });
      } else {
        print("No data available in the blob.");
      }
    });

    fullMediaRecorder!.start();
    setState(() {
      isFullRecording = true;
    });
  }

  // 전체 오디오 녹음 정지 및 전송
  void _stopFullRecording() async {
    fullMediaRecorder?.stop();
    setState(() {
      isFullRecording = false;
    });

    // 딜레이 추가
    await Future.delayed(Duration(seconds: 1));

    // 전체 오디오 데이터를 WebSocket 서버로 전송
    if (fullAudioData.isNotEmpty) {
      final timeOnly = DateTime.now().toIso8601String().substring(11, 19);
      final data = {
        "audio": fullAudioData, // 전체 오디오 데이터를 전송
        "sentTime": timeOnly,
      };

      fullAudioChannel.sink.add(json.encode(data));
      print("Full audio data sent to server with time: $timeOnly");

      // 전체 오디오 데이터 초기화
      fullAudioData.clear();
    } else if (fullAudioData.isEmpty) {
      print("empty");
    }

    print("Full recording stopped.");
  }

  void _startDataTransmission() {
    setState(() {
      _isStreaming = true;
      if (chartData1.isNotEmpty) {
        _currentDate = chartData1.last.x; // 마지막 시간으로 초기화
      }
    });

    _setUpDataUpdateListener();
    if (socket != null && socket!.connected) {
      socket!.emit('start');
      debugPrint("Data transmission started");
    }
  }

  void _stopDataTransmission() {
    if (socket != null && socket!.connected) {
      setState(() {
        _isStreaming = false;
        DateTime stopTime = DateTime.now();
        chartData1.add(ChartSampleData(x: stopTime, y: 0));
        chartData2.add(ChartSampleData(x: stopTime, y: 0));
        chartData3.add(ChartSampleData(x: stopTime, y: 0));
      });
      socket!.emit('stop');
      socket!.off('data_update');
      debugPrint("Data transmission stopped");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Combined Dashboard"),
        actions: [
          // 그래프 유형 전환 아이콘 버튼
          IconButton(
            icon: Icon(
              _icons[_currentIconIndex],
              color: Colors.black,
            ),
            onPressed: () {
              setState(() {
                _currentIconIndex = (_currentIconIndex + 1) % _icons.length;
                _isLineChart = !_isLineChart; // Line/Curve 전환
              });
            },
            tooltip: _isLineChart ? "Switch to Curve" : "Switch to Line",
          ),
        ],
      ),
      body: Row(
        children: [
          // 왼쪽: 실시간 데이터 시각화 (1번 코드)
          Expanded(
            flex: 2,
            child: Column(
              children: [
                if (!_isConnected)
                  Center(
                    child: ElevatedButton(
                      onPressed: _connectWebSocket,
                      child: Text("Connect"),
                    ),
                  )
                else if (_isConnected && _isConnectionRequested)
                  Column(
                    children: [
                      Text('Connect with $_patientName?'),
                      SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: () {
                          if (socket != null && socket!.connected) {
                            socket!.emit('accept_connection');
                          }
                        },
                        child: Text('Accept Connection'),
                      ),
                      SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: () {
                          if (socket != null && socket!.connected) {
                            socket!.emit('decline_connection');
                            setState(() {
                              _isConnectionRequested = false;
                            });
                          }
                        },
                        child: Text('Decline Connection'),
                      ),
                    ],
                  )
                else if (_isConnected && _isConnectionAccepted)
                  Column(
                    children: [
                      Text('Connected with $_patientName'),
                      SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: _startDataTransmission,
                        child: Text('Start Data Transmission'),
                      ),
                      SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: _stopDataTransmission,
                        child: Text('Stop Data Transmission'),
                      ),
                    ],
                  ),
                // 첫 번째 그래프 - chartData1만 사용
                Expanded(
                  flex: 1,
                  child: SfCartesianChart(
                    title: ChartTitle(text: 'Data 1 Chart'),
                    primaryXAxis: DateTimeAxis(
                      dateFormat: DateFormat('HH:mm:ss'),
                      intervalType: DateTimeIntervalType.seconds,
                      rangeController: rangeController,
                    ),
                    primaryYAxis: NumericAxis(),
                    series: _isLineChart
                        ? [
                            LineSeries<ChartSampleData, DateTime>(
                              dataSource: chartData1,
                              xValueMapper: (ChartSampleData data, _) => data.x,
                              yValueMapper: (ChartSampleData data, _) => data.y,
                              color: Colors.blue,
                            ),
                          ]
                        : [
                            SplineSeries<ChartSampleData, DateTime>(
                              dataSource: chartData1,
                              xValueMapper: (ChartSampleData data, _) => data.x,
                              yValueMapper: (ChartSampleData data, _) => data.y,
                              color: Colors.blue,
                            ),
                          ],
                  ),
                ),
                // 두 번째 그래프 - chartData2만 사용
                Expanded(
                  flex: 1,
                  child: SfCartesianChart(
                    title: ChartTitle(text: 'Data 2 Chart'),
                    primaryXAxis: DateTimeAxis(
                      dateFormat: DateFormat('HH:mm:ss'),
                      intervalType: DateTimeIntervalType.seconds,
                      rangeController: rangeController,
                    ),
                    primaryYAxis: NumericAxis(),
                    series: _isLineChart
                        ? [
                            LineSeries<ChartSampleData, DateTime>(
                              dataSource: chartData2,
                              xValueMapper: (ChartSampleData data, _) => data.x,
                              yValueMapper: (ChartSampleData data, _) => data.y,
                              color: Colors.red,
                            ),
                          ]
                        : [
                            SplineSeries<ChartSampleData, DateTime>(
                              dataSource: chartData2,
                              xValueMapper: (ChartSampleData data, _) => data.x,
                              yValueMapper: (ChartSampleData data, _) => data.y,
                              color: Colors.red,
                            ),
                          ],
                  ),
                ),
                // 세 번째 그래프 - chartData3만 사용
                Expanded(
                  flex: 1,
                  child: SfCartesianChart(
                    title: ChartTitle(text: 'Data 3 Chart'),
                    primaryXAxis: DateTimeAxis(
                      dateFormat: DateFormat('HH:mm:ss'),
                      intervalType: DateTimeIntervalType.seconds,
                      rangeController: rangeController,
                    ),
                    primaryYAxis: NumericAxis(),
                    series: _isLineChart
                        ? [
                            LineSeries<ChartSampleData, DateTime>(
                              dataSource: chartData3,
                              xValueMapper: (ChartSampleData data, _) => data.x,
                              yValueMapper: (ChartSampleData data, _) => data.y,
                              color: Colors.green,
                            ),
                          ]
                        : [
                            SplineSeries<ChartSampleData, DateTime>(
                              dataSource: chartData3,
                              xValueMapper: (ChartSampleData data, _) => data.x,
                              yValueMapper: (ChartSampleData data, _) => data.y,
                              color: Colors.green,
                            ),
                          ],
                  ),
                ),
                // 아래의 기간 선택기 그래프 - 모든 데이터를 포함
                Expanded(
                  flex: 1,
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: SfRangeSelector(
                      min: chartData1.isNotEmpty
                          ? chartData1.first.x
                          : DateTime.now().subtract(Duration(seconds: 1000)),
                      max: chartData1.isNotEmpty
                          ? chartData1.last.x
                          : DateTime.now(),
                      interval: 1,
                      dateIntervalType: DateIntervalType.seconds,
                      showTicks: true,
                      showLabels: true,
                      controller: rangeController,
                      dragMode: SliderDragMode.both,
                      onChanged: (SfRangeValues values) {
                        setState(() {
                          DateTime newStart = values.start as DateTime;
                          DateTime newEnd = values.end as DateTime;
                          rangeController.start = newStart;
                          rangeController.end = newEnd;
                        });
                      },
                      child: SfCartesianChart(
                        primaryXAxis: DateTimeAxis(
                          intervalType: DateTimeIntervalType.seconds,
                          rangeController: rangeController,
                        ),
                        primaryYAxis: NumericAxis(isVisible: false),
                        series: _isLineChart
                            ? [
                                LineSeries<ChartSampleData, DateTime>(
                                  dataSource: chartData1,
                                  xValueMapper: (ChartSampleData data, _) =>
                                      data.x,
                                  yValueMapper: (ChartSampleData data, _) =>
                                      data.y,
                                  color: Colors.blue,
                                ),
                                LineSeries<ChartSampleData, DateTime>(
                                  dataSource: chartData2,
                                  xValueMapper: (ChartSampleData data, _) =>
                                      data.x,
                                  yValueMapper: (ChartSampleData data, _) =>
                                      data.y,
                                  color: Colors.red,
                                ),
                                LineSeries<ChartSampleData, DateTime>(
                                  dataSource: chartData3,
                                  xValueMapper: (ChartSampleData data, _) =>
                                      data.x,
                                  yValueMapper: (ChartSampleData data, _) =>
                                      data.y,
                                  color: Colors.green,
                                ),
                              ]
                            : [
                                SplineSeries<ChartSampleData, DateTime>(
                                  dataSource: chartData1,
                                  xValueMapper: (ChartSampleData data, _) =>
                                      data.x,
                                  yValueMapper: (ChartSampleData data, _) =>
                                      data.y,
                                  color: Colors.blue,
                                ),
                                SplineSeries<ChartSampleData, DateTime>(
                                  dataSource: chartData2,
                                  xValueMapper: (ChartSampleData data, _) =>
                                      data.x,
                                  yValueMapper: (ChartSampleData data, _) =>
                                      data.y,
                                  color: Colors.red,
                                ),
                                SplineSeries<ChartSampleData, DateTime>(
                                  dataSource: chartData3,
                                  xValueMapper: (ChartSampleData data, _) =>
                                      data.x,
                                  yValueMapper: (ChartSampleData data, _) =>
                                      data.y,
                                  color: Colors.green,
                                ),
                              ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // 오른쪽: 음성 관련 데이터 표시 (2번 코드)
          Expanded(
            flex: 1,
            child: Column(
              children: [
                ElevatedButton(
                  onPressed: isFullRecording
                      ? _stopFullRecording
                      : _startFullRecording,
                  child: Text(isFullRecording
                      ? "Stop Full Recording"
                      : "Start Full Recording"),
                ),
                Expanded(
                  child: messages.isEmpty
                      ? Center(child: Text('No data available'))
                      : ListView.builder(
                          itemCount: messages.length,
                          itemBuilder: (context, index) {
                            final message = messages[index];
                            return ListTile(
                              title: Row(
                                children: [
                                  Text(
                                    'Speaker: ',
                                    style:
                                        TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  GestureDetector(
                                    onTap: () async {
                                      final newValue = await showDialog<String>(
                                        context: context,
                                        builder: (context) {
                                          return SimpleDialog(
                                            title: Text('Select Label'),
                                            children: [
                                              'me',
                                              'another',
                                              'unknown'
                                            ]
                                                .map((label) =>
                                                    SimpleDialogOption(
                                                      onPressed: () {
                                                        Navigator.pop(
                                                            context, label);
                                                      },
                                                      child: Text(label),
                                                    ))
                                                .toList(),
                                          );
                                        },
                                      );
                                      if (newValue != null &&
                                          newValue.isNotEmpty) {
                                        setState(() {
                                          message['label'] = newValue;
                                        });
                                        print("Label updated to: $newValue");
                                      }
                                    },
                                    child: Text(
                                      message['label'],
                                      style: TextStyle(
                                        color: message['label'] == 'me'
                                            ? Colors.blue
                                            : Colors.green,
                                        decoration: TextDecoration.underline,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(message['text']),
                                  Text("Sent Time: ${message['sentTime']}",
                                      style: TextStyle(
                                          fontSize: 12, color: Colors.grey)),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// 실시간 데이터 및 오디오 관련 구조체 (예시)
class ChartSampleData {
  ChartSampleData({required this.x, required this.y});
  final DateTime x;
  final double y;
}
