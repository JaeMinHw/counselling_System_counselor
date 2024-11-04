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
  DateTime _currentDate = DateTime(2017, 1, 1);
  final DateTime _minDate = DateTime(2017, 1, 1);
  final DateTime _maxDate = DateTime(2018, 1, 1);
  late double initialRangeLength;

  @override
  void initState() {
    super.initState();

    // RangeController 초기화
    rangeController = RangeController(
      start: DateTime(2017, 5, 1),
      end: DateTime(2017, 9, 1),
    );

    // 초기 범위 길이 설정
    initialRangeLength =
        rangeController.end.difference(rangeController.start).inDays.toDouble();
  }

  @override
  void dispose() {
    rangeController.dispose();
    socket?.disconnect();
    super.dispose();
  }

  // WebSocket 연결 및 데이터 처리
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
      print('Connected to the server');
      socket!.emit('counselor_login', {'counselor_id': '1'});
    });

    socket!.onDisconnect((_) {
      setState(() {
        _isConnected = false;
        _isConnectionRequested = false;
        _isConnectionAccepted = false;
      });
      print('Disconnected from the server');
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
      print('Connection accepted: $data');
    });

    // 데이터 업데이트 이벤트 리스너 설정
    _setUpDataUpdateListener();

    socket!.connect();
  }

  void _setUpDataUpdateListener() {
    // 새로운 데이터 업데이트 리스너 설정
    socket!.on('data_update', (data) {
      double newData1 = double.parse(data['data1'].toString());
      double newData2 = double.parse(data['data2'].toString());
      _updateChartData(newData1, newData2);
    });
  }

  // 차트 데이터 업데이트
  void _updateChartData(double data1, double data2) {
    setState(() {
      chartData1.add(ChartSampleData(x: _currentDate, y: data1));
      chartData2.add(ChartSampleData(x: _currentDate, y: data2));

      _currentDate = _currentDate.add(Duration(days: 1));

      // 데이터가 1000개를 넘으면 오래된 데이터 삭제
      if (chartData1.length > 1000) {
        chartData1.removeAt(0);
        chartData2.removeAt(0);
      }

      // 최신 데이터에 맞춰 x축 범위를 조절
      rangeController.start = chartData1.first.x;
      rangeController.end = chartData1.last.x;
    });
  }

  void _startDataTransmission() {
    setState(() {
      chartData1.clear();
      chartData2.clear();
      _currentDate = DateTime(2017, 1, 1); // 날짜 초기화
    });

    if (socket != null && socket!.connected) {
      // `data_update` 리스너를 다시 설정
      _setUpDataUpdateListener();
      socket!.emit('start'); // 서버로 start 이벤트 전송
    }
  }

  void _stopDataTransmission() {
    if (socket != null && socket!.connected) {
      socket!.emit('stop'); // 서버로 stop 이벤트 전송
      socket!.off('data_update'); // 데이터 업데이트 이벤트만 해제
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
          // 상단 메인 그래프
          Expanded(
            flex: 3,
            child: SfCartesianChart(
              title: ChartTitle(text: 'Real-time Data Chart'),
              primaryXAxis: DateTimeAxis(
                minimum: _minDate,
                maximum: _maxDate,
                rangeController: rangeController,
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
          // 하단 기간 선택기
          Expanded(
            flex: 1,
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: SfRangeSelector(
                min: _minDate,
                max: _maxDate,
                interval: 1,
                dateIntervalType: DateIntervalType.months,
                showTicks: true,
                showLabels: true,
                controller: rangeController,
                dragMode: SliderDragMode.both,
                onChanged: (SfRangeValues values) {
                  setState(() {
                    Duration rangeDuration =
                        rangeController.end.difference(rangeController.start);

                    // 새로운 시작과 끝 값을 기반으로 비율 유지
                    DateTime newStart = values.start as DateTime;
                    DateTime newEnd = newStart.add(rangeDuration);

                    rangeController.start = newStart;
                    rangeController.end = newEnd;
                  });
                },
                child: Container(
                  height: 75,
                  child: SfCartesianChart(
                    primaryXAxis: DateTimeAxis(isVisible: false),
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
