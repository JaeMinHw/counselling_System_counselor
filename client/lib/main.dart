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
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:flutter/rendering.dart';

// WebSocket 채널 설정
final WebSocketChannel dataChannel =
    WebSocketChannel.connect(Uri.parse('ws://127.0.0.1:8765')); // 실시간 데이터 채널
final WebSocketChannel fullAudioChannel =
    WebSocketChannel.connect(Uri.parse('ws://127.0.0.1:8766')); // 전체 오디오 데이터 채널

void main() {
  debugRepaintRainbowEnabled = true;
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Combined Dashboard',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true, // 만약 Material3 쓰신다면...
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          // surfaceTintColor도 3.7+ 버전에서는 필요할 수 있음
          surfaceTintColor: Colors.transparent,
          iconTheme: IconThemeData(color: Colors.black),
          titleTextStyle: TextStyle(color: Colors.black, fontSize: 20),
        ),
      ),
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
  // ScrollController 추가
  final ScrollController _scrollController = ScrollController();
  // 음성 감지 상태 추가
  bool _isVoiceDetectionEnabled = true; // 음성 감지 초기값 (활성화)
  int data_keep_count = 100000;
  IO.Socket? socket;
  bool _isConnected = false;
  bool _isConnectionRequested = false;
  bool _isConnectionAccepted = false;
  String _patientName = '';

  // 실시간 데이터 관련 상태
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

  // 음성 녹음 관련 상태
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

    // 그래프 초기화
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

    // WebSocket 메시지 수신 리스너
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
        _sortMessagesByTime();
        _scrollToBottom();
      });
    });
  }

  // 음성 감지 상태 변경
  void _toggleVoiceDetection() {
    setState(() {
      _isVoiceDetectionEnabled = !_isVoiceDetectionEnabled;

      if (!_isVoiceDetectionEnabled && isFullRecording) {
        _stopFullRecording();
        _showAlert("마이크가 꺼져 녹음이 중단되었습니다.");
      }
    });
  }

  void _showAlert(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("알림"),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("확인"),
          ),
        ],
      ),
    );
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
    _scrollController.dispose(); // ScrollController 해제
    dataChannel.sink.close();
    fullAudioChannel.sink.close();
    rangeController.dispose();
    super.dispose();
  }

  // 메시지 추가 시 스크롤 이동
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
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
    socket!.off('data_update_batch'); // 배치 리스너 제거

    // 즉시 데이터 리스너
    socket!.on('data_update', (data) {
      if (_isStreaming) {
        double newValue = double.parse(data['value'].toString());
        String sensor = data['sensor'];
        DateTime serverTime = data.containsKey('time')
            ? DateTime.parse(data['time'])
            : DateTime.now();

        if (sensor == 'data2') {
          _updateChartData2(newValue, serverTime);
        } else if (sensor == 'data3') {
          _updateChartData3(newValue, serverTime);
        }
      }
    });

    // 배치 데이터 리스너
    socket!.on('data_update_batch', (data) {
      if (_isStreaming) {
        if (data.containsKey('data1_batch')) {
          List<dynamic> batch = data['data1_batch'];

          for (var entry in batch) {
            if (entry is Map &&
                entry.containsKey('value') &&
                entry.containsKey('time')) {
              try {
                double newData1 = double.parse(entry['value'].toString());
                DateTime entryTime = DateTime.parse(entry['time'].toString());
                _updateChartData1(newData1, entryTime);
              } catch (e) {
                debugPrint('Error parsing batch entry: $e');
              }
            } else {
              debugPrint('Invalid batch entry: $entry');
            }
          }
        } else {
          debugPrint('Invalid batch format received: $data');
        }
      }
    });

    // 감정(특징) 분석 결과
    socket!.on('feature_detect', (data) {
      final Map<String, dynamic> receivedData = data;
      final String time = receivedData['time'] as String;
      final String feature = receivedData['feature'] as String;
      // 가장 가까운 메시지에 감정을 추가 or 새 메시지 생성
      _addEmotionToClosestMessage(time, feature);
    });
  }

  // 메시지에 감정 태그 추가하는 로직
  int _findClosestMessageIndex(String time) {
    final DateTime targetTime = DateFormat('HH:mm:ss').parse(time);
    int closestIndex = 0;
    Duration smallestDifference = Duration(hours: 24);

    for (int i = 0; i < messages.length; i++) {
      final DateTime messageTime =
          DateFormat('HH:mm:ss').parse(messages[i]['sentTime']);
      final Duration difference = (messageTime.difference(targetTime)).abs();
      if (difference < smallestDifference) {
        smallestDifference = difference;
        closestIndex = i;
      }
    }
    return closestIndex;
  }

  void _addEmotionToClosestMessage(String time, String feature) {
    final DateTime targetTime = DateFormat('HH:mm:ss').parse(time);
    int closestIndex = _findClosestMessageIndex(time);

    final DateTime closestMessageTime =
        DateFormat('HH:mm:ss').parse(messages[closestIndex]['sentTime']);
    final Duration difference =
        (closestMessageTime.difference(targetTime)).abs();

    if (difference.inSeconds <= 3) {
      // 기존 메시지에 감정을 추가
      setState(() {
        messages[closestIndex]['emotion'] = feature;
      });
    } else {
      // 새로운 메시지를 추가
      final Map<String, dynamic> newMessage = {
        'sentTime': time,
        'text': '',
        'label': 'emotion',
        'emotion': feature,
      };
      setState(() {
        messages.add(newMessage);
        _sortMessagesByTime();
      });
    }
    _scrollToBottom();
  }

  // 메시지 시간 정렬
  void _sortMessagesByTime() {
    messages.sort((a, b) {
      final DateTime timeA = DateFormat('HH:mm:ss').parse(a['sentTime']);
      final DateTime timeB = DateFormat('HH:mm:ss').parse(b['sentTime']);
      return timeA.compareTo(timeB);
    });
  }

  // 그래프 업데이트 (Data1)
  void _updateChartData1(double data1, DateTime time) async {
    await Future.delayed(Duration.zero);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() {
        chartData1.add(ChartSampleData(x: time, y: data1));
        if (chartData1.length > data_keep_count) {
          chartData1.removeAt(0);
        }
        rangeController.start =
            chartData1.last.x.subtract(Duration(seconds: 5));
        rangeController.end = chartData1.last.x;
      });
    });
  }

  // 그래프 업데이트 (Data2)
  void _updateChartData2(double data2, DateTime time) async {
    await Future.delayed(Duration.zero);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() {
        chartData2.add(ChartSampleData(x: time, y: data2));
        if (chartData2.length > data_keep_count) {
          chartData2.removeAt(0);
        }
        rangeController.start =
            chartData2.last.x.subtract(Duration(seconds: 5));
        rangeController.end = chartData2.last.x;
      });
    });
  }

  // 그래프 업데이트 (Data3)
  void _updateChartData3(double data3, DateTime time) {
    setState(() {
      chartData3.add(ChartSampleData(x: time, y: data3));
      if (chartData3.length > data_keep_count) {
        chartData3.removeAt(0);
      }
      rangeController.start = chartData3.last.x.subtract(Duration(seconds: 5));
      rangeController.end = chartData3.last.x;
    });
  }

  // 음성 녹음 시작
  Future<void> _startRecording() async {
    if (!_isVoiceDetectionEnabled) {
      return; // 음성 감지 비활성화 시 녹음 시작 안 함
    }
    final stream =
        await html.window.navigator.mediaDevices!.getUserMedia({'audio': true});
    mediaRecorder = html.MediaRecorder(stream);

    mediaRecorder!.addEventListener('dataavailable', (event) {
      if (!_isVoiceDetectionEnabled) {
        return;
      }
      final blob = (event as html.BlobEvent).data;
      if (blob != null) {
        final reader = html.FileReader();
        reader.readAsArrayBuffer(blob);
        reader.onLoadEnd.listen((e) {
          final bytes = reader.result as Uint8List;
          final currentTime =
              DateTime.now().toIso8601String().substring(11, 19);

          final data = {
            "audio": bytes,
            "sentTime": currentTime,
          };
          dataChannel.sink.add(json.encode(data));
        });
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
          fullAudioData.add(bytes); // 전체 오디오 데이터 누적
        });
      }
    });

    fullMediaRecorder!.start();
    setState(() {
      isFullRecording = true;
    });
  }

  // 전체 오디오 녹음 정지 + 전송
  void _stopFullRecording() async {
    fullMediaRecorder?.stop();
    setState(() {
      isFullRecording = false;
    });

    await Future.delayed(Duration(seconds: 1));

    if (fullAudioData.isNotEmpty) {
      final timeOnly = DateTime.now().toIso8601String().substring(11, 19);
      final data = {
        "audio": fullAudioData,
        "sentTime": timeOnly,
      };
      fullAudioChannel.sink.add(json.encode(data));
      fullAudioData.clear();
    }
  }

  void _startDataTransmission() {
    setState(() {
      _isStreaming = true;
      if (chartData1.isNotEmpty) {
        _currentDate = chartData1.last.x;
      }
    });
    _setUpDataUpdateListener();
    if (socket != null && socket!.connected) {
      socket!.emit('start');
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
    }
  }

  // 특정 메시지 클릭 시 해당 그래프 시간으로 이동
  void _moveToGraphTime(String selectedTime) {
    try {
      List<String> parts = selectedTime.split(":");
      int hours = int.parse(parts[0]);
      int minutes = int.parse(parts[1]);
      int seconds = int.parse(parts[2]);

      DateTime parsedTime = DateTime(
        DateTime.now().year,
        DateTime.now().month,
        DateTime.now().day,
        hours,
        minutes,
        seconds,
      );

      setState(() {
        rangeController.start = parsedTime.subtract(Duration(seconds: 5));
        rangeController.end = parsedTime.add(Duration(seconds: 5));
      });
    } catch (e) {
      debugPrint("Error in _moveToGraphTime: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent, // 완전 투명
        elevation: 0, // 그림자 제거
        scrolledUnderElevation: 0, // 추가

        title: Text("사용자 데이터 그래프"),
        actions: [
          // 그래프 유형 전환 (Line <-> Curve)
          IconButton(
            icon: Icon(
              _icons[_currentIconIndex],
              color: Colors.black,
            ),
            onPressed: () {
              setState(() {
                _currentIconIndex = (_currentIconIndex + 1) % _icons.length;
                _isLineChart = !_isLineChart;
              });
            },
            tooltip: _isLineChart ? "Switch to Curve" : "Switch to Line",
          ),
        ],
      ),
      body: Row(
        children: [
          // 왼쪽: 그래프 영역
          Expanded(
            flex: 3,
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

                // 세 개의 그래프 (Data1, Data2, Data3)
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
                              animationDuration: 0,
                            ),
                          ]
                        : [
                            SplineSeries<ChartSampleData, DateTime>(
                              dataSource: chartData1,
                              xValueMapper: (ChartSampleData data, _) => data.x,
                              yValueMapper: (ChartSampleData data, _) => data.y,
                              color: Colors.blue,
                              animationDuration: 0,
                            ),
                          ],
                  ),
                ),
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

          // 오른쪽: 음성 채팅/메시지 영역
          // 오른쪽: 음성 채팅/메시지 영역
          Expanded(
            flex: 1,
            child: LayoutBuilder(
              builder: (context, constraints) {
                // 이 builder 안에서 constraints.maxWidth => 오른쪽 패널의 실제 너비
                return Column(
                  children: [
                    // (1) 윗부분: 버튼 + 마이크 아이콘 (기존 코드 그대로)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Center(
                            child: ElevatedButton(
                              onPressed:
                                  (_isVoiceDetectionEnabled && !isFullRecording)
                                      ? _startFullRecording
                                      : (_isVoiceDetectionEnabled &&
                                              isFullRecording)
                                          ? _stopFullRecording
                                          : null,
                              child: Text(
                                isFullRecording
                                    ? "Stop Full Recording"
                                    : "Start Full Recording",
                              ),
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: _toggleVoiceDetection,
                          child: Image.asset(
                            _isVoiceDetectionEnabled
                                ? 'assets/image/mic_on.png'
                                : 'assets/image/mic_off.png',
                            width: 48,
                            height: 48,
                          ),
                        ),
                      ],
                    ),

                    // (2) 아래부분: 메시지 리스트
                    Expanded(
                      child: messages.isEmpty
                          ? Center(child: Text('No data available'))
                          : ListView.builder(
                              controller: _scrollController,
                              itemCount: messages.length,
                              itemBuilder: (context, index) {
                                // 여기서 constraints.maxWidth를 _buildChatBubble에 넘김
                                return _buildChatBubble(
                                  context,
                                  index,
                                  constraints.maxWidth, // 우측 영역 실제 너비
                                );
                              },
                            ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // -- [1] 메시지 빌드 함수 ------------------------------------------------
  Widget _buildChatBubble(BuildContext context, int index, double parentWidth) {
    final message = messages[index];
    final bool isMe = (message['label'] == 'me');

    return GestureDetector(
      onTap: () {
        // 메시지 클릭 시 그래프 이동
        _moveToGraphTime(message['sentTime']);
      },
      onLongPress: () async {
        // 라벨 수정 기능
        final newValue = await showDialog<String>(
          context: context,
          builder: (context) {
            return SimpleDialog(
              title: Text('Select Label'),
              children: [
                'me',
                'another',
                'unknown',
              ].map((label) {
                return SimpleDialogOption(
                  onPressed: () {
                    Navigator.pop(context, label);
                  },
                  child: Text(label),
                );
              }).toList(),
            );
          },
        );
        if (newValue != null && newValue.isNotEmpty) {
          setState(() {
            message['label'] = newValue;
          });
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
        // isMe에 따라 왼쪽/오른쪽 말풍선 구분
        child: isMe
            ? _buildRightBubble(context, message, parentWidth)
            : _buildLeftBubble(context, message, parentWidth),
      ),
    );
  }

// -- [2] 왼쪽 말풍선 (KK + 파란말풍선) -------------------------------------
  Widget _buildLeftBubble(
      BuildContext context, Map<String, dynamic> message, double parentWidth) {
    // unknown인지 판단
    final bool isUnknown = (message['label'] == 'unknown');

    // unknown이면 회색+50% 투명, 아니면 파란색
    final bubbleColor =
        isUnknown ? Colors.grey.shade400.withOpacity(0.3) : Colors.blue;

    // unknown이면 텍스트 색상도 조금 어둡고 투명하게
    final textColor = isUnknown
        ? const Color.fromARGB(221, 63, 63, 63).withOpacity(0.5)
        : Colors.white;

    // emotion 부분도 유사하게
    final emotionColor =
        isUnknown ? Colors.black54.withOpacity(0.3) : Colors.white70;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // KK 프로필 (CircleAvatar)
        CircleAvatar(
          backgroundColor:
              isUnknown ? Colors.grey.withOpacity(0.5) : Colors.blue,
          child: Text(
            isUnknown ? '??' : '다른', // unknown이면 '??'
            style: TextStyle(color: Colors.white),
          ),
        ),
        SizedBox(width: 8),

        // 말풍선 + 시간
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              constraints: BoxConstraints(
                maxWidth: parentWidth * 0.35,
              ),
              decoration: BoxDecoration(
                color: bubbleColor, // 수정된 배경색
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message['text'] ?? '',
                    softWrap: true, // 화면 너비가 모자라면 자동 줄바꿈
                    maxLines: null, // 줄 수 제한 없음 (길면 여러 줄)
                    style: TextStyle(
                      fontSize: 16,
                      color: textColor, // 수정된 텍스트 색
                    ),
                  ),
                  if (message['emotion'] != null)
                    Text(
                      'Emotion: ${message['emotion']}',
                      style: TextStyle(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                        color: emotionColor, // 감정 표기 색상도 투명도 적용 가능
                      ),
                    ),
                ],
              ),
            ),
            SizedBox(height: 4),
            Text(
              message['sentTime'] ?? '',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ],
        ),
      ],
    );
  }

  // -- [3] 오른쪽 말풍선 (흰 말풍선 + 보라 원 아이콘) -------------------------
  Widget _buildRightBubble(
      BuildContext context, Map<String, dynamic> message, double parentWidth) {
    // unknown인지 판단
    final bool isUnknown = (message['label'] == 'unknown');

    // unknown이면 좀 더 흐린 회색, 아니면 흰 말풍선
    final bubbleColor = isUnknown ? Colors.grey.shade300 : Colors.white;
    // unknown이면 텍스트색도 좀 더 어두운색
    final textColor =
        isUnknown ? const Color.fromARGB(255, 133, 133, 133) : Colors.black87;
    final emotionColor = isUnknown ? Colors.grey : Colors.blueGrey;

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 말풍선 + 시간
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              constraints: BoxConstraints(
                maxWidth: parentWidth * 0.35,
              ),
              decoration: BoxDecoration(
                color: bubbleColor,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.shade300,
                    offset: Offset(0, 1),
                    blurRadius: 4,
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message['text'] ?? '',
                    style: TextStyle(fontSize: 16, color: textColor),
                  ),
                  if (message['emotion'] != null)
                    Text(
                      'Emotion: ${message['emotion']}',
                      style: TextStyle(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                        color: emotionColor,
                      ),
                    ),
                ],
              ),
            ),
            SizedBox(height: 4),
            Text(
              message['sentTime'] ?? '',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ],
        ),

        SizedBox(width: 8),

        // 보라색 원형 아이콘
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isUnknown ? Colors.grey : Colors.purple,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              isUnknown ? '??' : '나',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// 차트용 데이터 구조
class ChartSampleData {
  ChartSampleData({required this.x, required this.y});
  final DateTime x;
  final double y;
}
