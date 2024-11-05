import 'dart:async';
import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:syncfusion_flutter_core/core.dart';
import 'package:syncfusion_flutter_sliders/sliders.dart';
import 'package:intl/intl.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Counselor Dashboard',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MyHomePage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class MyHomePage extends StatefulWidget {
  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  IO.Socket? socket;
  bool _isConnected = false;
  bool _isConnectionRequested = false;
  bool _isConnectionAccepted = false;
  String _patientName = '';

  List<ChartSampleData> chartData1 = <ChartSampleData>[];
  List<ChartSampleData> chartData2 = <ChartSampleData>[];

  late RangeController rangeController;
  DateTime _currentDate = DateTime.now();
  bool _isStreaming = false; // 데이터를 스트리밍 중인지 확인하는 플래그

  @override
  void initState() {
    super.initState();

    rangeController = RangeController(
      start: DateTime.now().subtract(Duration(seconds: 5)),
      end: DateTime.now(),
    );
  }

  @override
  void dispose() {
    rangeController.dispose();
    socket?.disconnect();
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
        DateTime serverTime = data.containsKey('timestamp')
            ? DateTime.parse(data['timestamp'])
            : DateTime.now();
        _updateChartData(newData1, newData2, serverTime);
        debugPrint(
            "Received data update: data1=$newData1, data2=$newData2, time=$serverTime");
      }
    });
  }

  void _updateChartData(double data1, double data2, DateTime time) {
    setState(() {
      chartData1.add(ChartSampleData(x: time, y: data1));
      chartData2.add(ChartSampleData(x: time, y: data2));

      if (chartData1.length > 1000) {
        chartData1.removeAt(0);
        chartData2.removeAt(0);
      }

      rangeController.start = chartData1.last.x.subtract(Duration(seconds: 5));
      rangeController.end = chartData1.last.x;
    });
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
        title: Text("Counselor Dashboard"),
      ),
      body: Column(
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
            flex: 3,
            child: SfCartesianChart(
              title: ChartTitle(text: 'Real-time Data Chart'),
              primaryXAxis: DateTimeAxis(
                rangeController: rangeController,
                dateFormat: DateFormat('HH:mm:ss'),
                intervalType: DateTimeIntervalType.seconds,
              ),
              primaryYAxis: NumericAxis(),
              series: <SplineSeries<ChartSampleData, DateTime>>[
                SplineSeries<ChartSampleData, DateTime>(
                  dataSource: chartData1,
                  xValueMapper: (ChartSampleData data, _) => data.x,
                  yValueMapper: (ChartSampleData data, _) => data.y,
                  color: Colors.blue,
                ),
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
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: SfRangeSelector(
                min: chartData1.isNotEmpty
                    ? chartData1.first.x
                    : DateTime.now().subtract(Duration(seconds: 5)),
                max: chartData1.isNotEmpty ? chartData1.last.x : DateTime.now(),
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
                child: Container(
                  height: 75,
                  child: SfCartesianChart(
                    primaryXAxis: DateTimeAxis(
                      dateFormat: DateFormat('HH:mm:ss'),
                      intervalType: DateTimeIntervalType.seconds,
                    ),
                    primaryYAxis: NumericAxis(isVisible: false),
                    series: <SplineAreaSeries<ChartSampleData, DateTime>>[
                      SplineAreaSeries<ChartSampleData, DateTime>(
                        dataSource: chartData1,
                        xValueMapper: (ChartSampleData data, _) => data.x,
                        yValueMapper: (ChartSampleData data, _) => data.y,
                        borderColor: Colors.blue,
                        color: Colors.lightBlue.withOpacity(0.3),
                        borderWidth: 1,
                      ),
                      SplineAreaSeries<ChartSampleData, DateTime>(
                        dataSource: chartData2,
                        xValueMapper: (ChartSampleData data, _) => data.x,
                        yValueMapper: (ChartSampleData data, _) => data.y,
                        borderColor: Colors.red,
                        color: Colors.red.withOpacity(0.3),
                        borderWidth: 1,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          )
        ],
      ),
    );
  }
}

class ChartSampleData {
  ChartSampleData({required this.x, required this.y});
  final DateTime x;
  final double y;
}
