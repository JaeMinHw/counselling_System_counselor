import 'dart:async';
import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:syncfusion_flutter_core/core.dart';
import 'package:syncfusion_flutter_sliders/sliders.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:js' as js;
import 'dart:typed_data';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:flutter/rendering.dart';

// <-- colors.dart: AppColors가 정의되어 있다고 가정합니다.
import 'theme/colors.dart';

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
        useMaterial3: true,
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
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
  final ScrollController _scrollController = ScrollController();

  bool _isVoiceDetectionEnabled = true;
  int data_keep_count = 100000;
  IO.Socket? socket;
  bool _isConnected = false;
  bool _isConnectionRequested = false;
  bool _isConnectionAccepted = false;
  String _patientName = '';

  List<ChartSampleData> chartData1 = [];
  List<ChartSampleData> chartData2 = [];
  List<ChartSampleData> chartData3 = [];
  late RangeController rangeController;
  DateTime _currentDate = DateTime.now();
  bool isStreaming = false;
  bool _isStreaming = false;
  bool _isLineChart = true;
  late ZoomPanBehavior _zoomPanBehavior;
  int _currentIconIndex = 0;
  List<String> _icons = ['assets/image/curve.png', 'assets/image/line.png'];

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

    // onZooming나 onZoomEnd 파라미터는 현재 버전(28.2.3)에서는 제공되지 않으므로 기본 ZoomPanBehavior만 사용합니다.
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

    // WebSocket 메시지 수신
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

  // _toggleVoiceDetection: 마이크 on/off를 토글합니다.
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
    js.context.callMethod('startAudioProcessing');
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
    _scrollController.dispose();
    dataChannel.sink.close();
    fullAudioChannel.sink.close();
    rangeController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  void _connectWebSocket() {
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
      socket!.emit('counselor_login', {'counselor_id': '1'});
    });
    socket!.onDisconnect((_) {
      setState(() {
        _isConnected = false;
        _isConnectionRequested = false;
        _isConnectionAccepted = false;
      });
    });
    socket!.on('connection_request', (data) {
      setState(() {
        _isConnectionRequested = true;
        _patientName = data['message'];
      });
    });
    socket!.on('connection_accepted', (data) {
      setState(() {
        _isConnectionRequested = false;
        _isConnectionAccepted = true;
      });
    });
    _setUpDataUpdateListener();
    socket!.connect();
  }

  void _setUpDataUpdateListener() {
    socket!.off('data_update');
    socket!.off('data_update_batch');
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
            }
          }
        }
      }
    });
    socket!.on('feature_detect', (data) {
      final Map<String, dynamic> receivedData = data;
      final String time = receivedData['time'] as String;
      final String feature = receivedData['feature'] as String;
      _addEmotionToClosestMessage(time, feature);
    });
  }

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
      setState(() {
        messages[closestIndex]['emotion'] = feature;
      });
    } else {
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

  void _sortMessagesByTime() {
    messages.sort((a, b) {
      final DateTime timeA = DateFormat('HH:mm:ss').parse(a['sentTime']);
      final DateTime timeB = DateFormat('HH:mm:ss').parse(b['sentTime']);
      return timeA.compareTo(timeB);
    });
  }

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

  Future<void> _startRecording() async {
    if (!_isVoiceDetectionEnabled) return;
    final stream =
        await html.window.navigator.mediaDevices!.getUserMedia({'audio': true});
    mediaRecorder = html.MediaRecorder(stream);
    mediaRecorder!.addEventListener('dataavailable', (event) {
      if (!_isVoiceDetectionEnabled) return;
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

  void _stopRecording() {
    mediaRecorder?.stop();
    setState(() {
      isRecording = false;
    });
  }

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
          fullAudioData.add(bytes);
        });
      }
    });
    fullMediaRecorder!.start();
    setState(() {
      isFullRecording = true;
    });
  }

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
        title: Text("사용자 데이터 그래프"),
        actions: [
          IconButton(
            icon: Image.asset(_icons[_currentIconIndex],
                width: 30, height: 30, color: Colors.black),
            onPressed: () {
              setState(() {
                _currentIconIndex = (_currentIconIndex + 1) % _icons.length;
                _isLineChart = !_isLineChart;
              });
            },
          ),
        ],
      ),
      body: Row(
        children: [
          // 왼쪽 (그래프 영역)
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
                Expanded(
                  flex: 1,
                  child: ClipRect(
                    child: SfCartesianChart(
                      title: ChartTitle(text: 'Data 1 Chart'),
                      zoomPanBehavior: _zoomPanBehavior,
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
                                xValueMapper: (ChartSampleData data, _) =>
                                    data.x,
                                yValueMapper: (ChartSampleData data, _) =>
                                    data.y,
                                color: Colors.blue,
                                animationDuration: 0,
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
                                animationDuration: 0,
                              ),
                            ],
                    ),
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: ClipRect(
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
                                xValueMapper: (ChartSampleData data, _) =>
                                    data.x,
                                yValueMapper: (ChartSampleData data, _) =>
                                    data.y,
                                color: Colors.red,
                              ),
                            ]
                          : [
                              SplineSeries<ChartSampleData, DateTime>(
                                dataSource: chartData2,
                                xValueMapper: (ChartSampleData data, _) =>
                                    data.x,
                                yValueMapper: (ChartSampleData data, _) =>
                                    data.y,
                                color: Colors.red,
                              ),
                            ],
                    ),
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: ClipRect(
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
                                xValueMapper: (ChartSampleData data, _) =>
                                    data.x,
                                yValueMapper: (ChartSampleData data, _) =>
                                    data.y,
                                color: Colors.green,
                              ),
                            ]
                          : [
                              SplineSeries<ChartSampleData, DateTime>(
                                dataSource: chartData3,
                                xValueMapper: (ChartSampleData data, _) =>
                                    data.x,
                                yValueMapper: (ChartSampleData data, _) =>
                                    data.y,
                                color: Colors.green,
                                animationDuration: 0,
                              ),
                            ],
                    ),
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: ClipRect(
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
                        showLabels: false,
                        controller: rangeController,
                        dragMode: SliderDragMode.both,
                        onChanged: (SfRangeValues values) {
                          setState(() {
                            DateTime newStart = values.start as DateTime;
                            DateTime newEnd = values.end as DateTime;
                            const minMs = 5000;
                            final diffMs =
                                newEnd.difference(newStart).inMilliseconds;
                            if (diffMs < minMs) {
                              newEnd =
                                  newStart.add(Duration(milliseconds: minMs));
                            }
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
                ),
              ],
            ),
          ),
          // 오른쪽 (대화창)
          Expanded(
            flex: 1,
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Column(
                  children: [
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
                    Expanded(
                      child: messages.isEmpty
                          ? Center(child: Text('No data available'))
                          : ListView.builder(
                              controller: _scrollController,
                              itemCount: messages.length,
                              itemBuilder: (context, index) {
                                return _buildChatBubble(
                                    context, index, constraints.maxWidth);
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

  Widget _buildChatBubble(BuildContext context, int index, double parentWidth) {
    final message = messages[index];
    final bool isMe = (message['label'] == 'me');
    return GestureDetector(
      onTap: () {
        _moveToGraphTime(message['sentTime']);
      },
      onLongPress: () async {
        final newValue = await showDialog<String>(
          context: context,
          builder: (context) {
            return SimpleDialog(
              title: Text('Select Label'),
              children: ['me', 'another', 'unknown'].map((label) {
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
        child: isMe
            ? _buildRightBubble(context, message, parentWidth)
            : _buildLeftBubble(context, message, parentWidth),
      ),
    );
  }

  Widget _buildLeftBubble(
      BuildContext context, Map<String, dynamic> message, double parentWidth) {
    final bool isUnknown = (message['label'] == 'unknown');
    final emotion = message['emotion'];
    Color bubbleColor =
        isUnknown ? AppColors.leftBubbleUnknown : AppColors.leftBubbleDefault;
    if (emotion == 'anxiety') {
      bubbleColor = AppColors.emotionAnxiety;
    } else if (emotion == 'angry') {
      bubbleColor = AppColors.emotionAngry;
    }
    Color avatarColor = bubbleColor;
    final textColor = isUnknown
        ? const Color.fromARGB(221, 63, 63, 63).withOpacity(0.5)
        : Colors.white;
    final emotionColor =
        isUnknown ? Colors.black54.withOpacity(0.3) : Colors.white70;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          backgroundColor: avatarColor,
          child: Text(isUnknown ? '??' : '다른',
              style: TextStyle(color: Colors.white)),
        ),
        SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              constraints: BoxConstraints(maxWidth: parentWidth * 0.5),
              decoration: BoxDecoration(
                color: bubbleColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(message['text'] ?? '',
                      softWrap: true,
                      maxLines: null,
                      style: TextStyle(fontSize: 16, color: textColor)),
                  if (emotion != null)
                    Text('Emotion: $emotion',
                        style: TextStyle(
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                            color: emotionColor)),
                ],
              ),
            ),
            SizedBox(height: 4),
            Text(message['sentTime'] ?? '',
                style: TextStyle(fontSize: 12, color: Colors.black54)),
          ],
        ),
      ],
    );
  }

  Widget _buildRightBubble(
      BuildContext context, Map<String, dynamic> message, double parentWidth) {
    final bool isUnknown = (message['label'] == 'unknown');
    final emotion = message['emotion'];
    Color bubbleColor =
        isUnknown ? AppColors.rightBubbleUnknown : AppColors.rightBubbleDefault;
    if (emotion == 'anxiety') {
      bubbleColor = AppColors.emotionAnxiety;
    } else if (emotion == 'angry') {
      bubbleColor = AppColors.emotionAngry;
    }
    Color circleColor = bubbleColor;
    final textColor =
        isUnknown ? const Color.fromARGB(255, 133, 133, 133) : Colors.black87;
    final emotionColor = isUnknown ? Colors.grey : Colors.blueGrey;
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              constraints: BoxConstraints(maxWidth: parentWidth * 0.5),
              decoration: BoxDecoration(
                color: bubbleColor,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                      color: Colors.grey.shade300,
                      offset: Offset(0, 1),
                      blurRadius: 4)
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(message['text'] ?? '',
                      style: TextStyle(fontSize: 16, color: textColor)),
                  if (emotion != null)
                    Text('Emotion: $emotion',
                        style: TextStyle(
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                            color: emotionColor)),
                ],
              ),
            ),
            SizedBox(height: 4),
            Text(message['sentTime'] ?? '',
                style: TextStyle(fontSize: 12, color: Colors.black54)),
          ],
        ),
        SizedBox(width: 8),
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(color: circleColor, shape: BoxShape.circle),
          child: Center(
            child: Text(isUnknown ? '??' : '나',
                style: TextStyle(
                    color: const Color.fromARGB(255, 0, 0, 0),
                    fontSize: 14,
                    fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }
}

class ChartSampleData {
  ChartSampleData({required this.x, required this.y});
  final DateTime x;
  final double y;
}
