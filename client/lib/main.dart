// import 'dart:async';
// import 'package:flutter/material.dart';
// import 'package:socket_io_client/socket_io_client.dart' as IO;
// import 'package:fl_chart/fl_chart.dart';
// import 'package:intl/intl.dart'; // 시간을 포맷팅하는데 사용

// void main() {
//   runApp(MyApp());
// }

// class MyApp extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       title: 'Counselor Dashboard',
//       theme: ThemeData(
//         primarySwatch: Colors.blue,
//       ),
//       home: MyHomePage(),
//       debugShowCheckedModeBanner: false,
//     );
//   }
// }

// class MyHomePage extends StatefulWidget {
//   @override
//   _MyHomePageState createState() => _MyHomePageState();
// }

// class _MyHomePageState extends State<MyHomePage> {
//   IO.Socket? socket;
//   bool _isConnected = false;
//   bool _isConnectionRequested = false;
//   bool _isConnectionAccepted = false;
//   String _patientName = '';

//   List<FlSpot> _dataPoints1 = [];
//   List<FlSpot> _dataPoints2 = [];
//   List<String> _timeLabels = []; // 시간을 레이블로 저장

//   int _maxDataPoints = 80; // 그래프에 표시될 최대 데이터 포인트 수
//   double _minX = 0;
//   double _maxX = 80; // 처음에는 10개 데이터 포인트만 보여줌
//   double _xValue = 0; // X축 값을 추적하는 변수

//   StreamController<List<FlSpot>>? _dataStreamController1;
//   StreamController<List<FlSpot>>? _dataStreamController2;

//   @override
//   void initState() {
//     super.initState();
//     _connectWebSocket();
//   }

//   @override
//   void dispose() {
//     _dataStreamController1?.close();
//     _dataStreamController2?.close();
//     _disconnectWebSocket();
//     super.dispose();
//   }

//   void _connectWebSocket() {
//     socket = IO.io(
//       'ws://192.168.0.72:5000',
//       IO.OptionBuilder()
//           .setTransports(['websocket'])
//           .enableAutoConnect()
//           .enableForceNew()
//           .setExtraHeaders({'Upgrade': 'websocket'})
//           .build(),
//     );

//     socket!.onConnect((_) {
//       setState(() {
//         _isConnected = true;
//       });
//       print('Connected to the server');
//       socket!.emit('counselor_login', {'counselor_id': '1'});
//     });

//     socket!.onDisconnect((_) {
//       setState(() {
//         _isConnected = false;
//         _isConnectionRequested = false;
//         _isConnectionAccepted = false;
//       });
//       print('Disconnected from the server');
//     });

//     socket!.on('connection_request', (data) {
//       setState(() {
//         _isConnectionRequested = true;
//         _patientName = data['message'];
//       });
//     });

//     socket!.on('data_update', (data) {
//       if (_dataStreamController1 == null || _dataStreamController2 == null) {
//         return;
//       }

//       final String serverTime = data['time']; // 서버에서 받은 시간
//       final String formattedTime = _formatTime(serverTime); // 시, 분, 초로 변환

//       _timeLabels.add(formattedTime); // X축 레이블에 시간 추가

//       _xValue += 1; // X축 값을 증가시킴

//       _dataPoints1.add(FlSpot(_xValue, double.parse(data['data1'].toString())));
//       _dataPoints2.add(FlSpot(_xValue, double.parse(data['data2'].toString())));

//       // 데이터 포인트가 10개를 넘으면 가장 오래된 데이터와 시간 제거
//       if (_dataPoints1.length > _maxDataPoints) {
//         _dataPoints1.removeAt(0);
//         _dataPoints2.removeAt(0);
//         _timeLabels.removeAt(0); // 가장 오래된 시간 레이블 제거
//       }

//       // X축 범위 업데이트 (최신 데이터 포인트에 맞게 스크롤되도록)
//       _minX = (_dataPoints1.isNotEmpty && _dataPoints1.length >= _maxDataPoints)
//           ? _dataPoints1.first.x
//           : 0;
//       _maxX = (_minX + _maxDataPoints).toDouble();

//       _dataStreamController1!.add(_dataPoints1);
//       _dataStreamController2!.add(_dataPoints2);
//     });

//     socket!.on('connection_accepted', (data) {
//       setState(() {
//         _isConnectionRequested = false;
//         _isConnectionAccepted = true;
//       });
//       print('Connection accepted: $data');
//     });

//     socket!.connect();
//   }

//   // 서버에서 받은 시간을 시, 분, 초로 변환하는 함수
//   String _formatTime(String serverTime) {
//     DateTime dateTime =
//         DateTime.parse(serverTime); // 서버에서 받은 시간을 DateTime 객체로 변환
//     return DateFormat('HH:mm:ss').format(dateTime); // 시:분:초 형식으로 반환
//   }

//   void _disconnectWebSocket() {
//     if (socket != null && socket!.connected) {
//       socket!.disconnect();
//     }
//   }

//   void _acceptConnection() {
//     if (socket != null && socket!.connected) {
//       socket!.emit('accept_connection');
//     }
//   }

//   void _declineConnection() {
//     if (socket != null && socket!.connected) {
//       socket!.emit('decline_connection');
//       setState(() {
//         _isConnectionRequested = false;
//       });
//     }
//   }

//   void _startDataTransmission() {
//     if (_dataStreamController1 != null && _dataStreamController2 != null) {
//       _dataStreamController1!.close();
//       _dataStreamController2!.close();
//     }

//     _dataStreamController1 = StreamController<List<FlSpot>>();
//     _dataStreamController2 = StreamController<List<FlSpot>>();

//     setState(() {
//       _dataPoints1.clear();
//       _dataPoints2.clear();
//       _timeLabels.clear(); // 시간 레이블도 초기화
//       _xValue = 0; // X축 값 초기화
//     });

//     if (socket != null && socket!.connected) {
//       socket!.emit('start');
//     }
//   }

//   void _stopDataTransmission() {
//     if (socket != null && socket!.connected) {
//       socket!.emit('stop');
//       socket!.off('data_update');

//       _dataStreamController1?.close();
//       _dataStreamController2?.close();
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return GestureDetector(
//       onTap: () => FocusScope.of(context).unfocus(),
//       child: Scaffold(
//         appBar: AppBar(
//           title: Text('Counselor Dashboard'),
//           centerTitle: true,
//         ),
//         body: SafeArea(
//           child: Padding(
//             padding: const EdgeInsets.all(16.0),
//             child: Column(
//               children: [
//                 if (_isConnected && _isConnectionRequested)
//                   Column(
//                     children: [
//                       Text('Connect with $_patientName?'),
//                       SizedBox(height: 8),
//                       ElevatedButton(
//                         onPressed: _acceptConnection,
//                         child: Text('Accept Connection'),
//                       ),
//                       SizedBox(height: 8),
//                       ElevatedButton(
//                         onPressed: _declineConnection,
//                         child: Text('Decline Connection'),
//                       ),
//                     ],
//                   )
//                 else if (_isConnected && _isConnectionAccepted)
//                   Column(
//                     children: [
//                       Text('Connected with $_patientName'),
//                       SizedBox(height: 8),
//                       ElevatedButton(
//                         onPressed: _startDataTransmission,
//                         child: Text('Start'),
//                       ),
//                       SizedBox(height: 8),
//                       ElevatedButton(
//                         onPressed: _stopDataTransmission,
//                         child: Text('Stop'),
//                       ),
//                       SizedBox(height: 16),
//                       if (_dataStreamController1 != null)
//                         StreamBuilder<List<FlSpot>>(
//                           stream: _dataStreamController1!.stream,
//                           builder: (context, snapshot1) {
//                             if (snapshot1.hasData) {
//                               return _buildChart(snapshot1.data!, 1);
//                             } else {
//                               return CircularProgressIndicator();
//                             }
//                           },
//                         ),
//                       SizedBox(height: 16),
//                       if (_dataStreamController2 != null)
//                         StreamBuilder<List<FlSpot>>(
//                           stream: _dataStreamController2!.stream,
//                           builder: (context, snapshot2) {
//                             if (snapshot2.hasData) {
//                               return _buildChart(snapshot2.data!, 2);
//                             } else {
//                               return CircularProgressIndicator();
//                             }
//                           },
//                         ),
//                     ],
//                   )
//                 else
//                   Container(
//                     child: Text(_isConnected
//                         ? 'Waiting for connection request...'
//                         : 'Disconnected from the server.'),
//                   ),
//               ],
//             ),
//           ),
//         ),
//       ),
//     );
//   }

//   // 그래프를 그리는 함수
//   Widget _buildChart(List<FlSpot> dataPoints, int chartNumber) {
//     return Container(
//       height: 300,
//       child: LineChart(
//         LineChartData(
//           gridData: FlGridData(show: true),
//           titlesData: FlTitlesData(
//             bottomTitles: SideTitles(
//               showTitles: true,
//               getTitles: (value) {
//                 final int index =
//                     value.toInt() - _minX.toInt(); // X값에 맞는 시간 인덱스
//                 if (index < 0 || index >= _timeLabels.length) {
//                   return '';
//                 }
//                 return _timeLabels[index]; // X축에 시간 레이블 표시
//               },
//               reservedSize: 22,
//               margin: 8,
//               interval: 1, // 일정 간격으로 레이블 표시
//             ),
//           ),
//           borderData: FlBorderData(show: true),
//           lineBarsData: [
//             LineChartBarData(
//               spots: dataPoints,
//               isCurved: true,
//               colors: [chartNumber == 1 ? Colors.blue : Colors.red],
//               barWidth: 4,
//               isStrokeCapRound: true,
//             ),
//           ],
//           minX: _minX,
//           maxX: _maxX,
//           minY: 0,
//           maxY: 100,
//         ),
//       ),
//     );
//   }
// }

// -------------------------------------------------------------------------------------
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:syncfusion_flutter_core/core.dart';
import 'package:syncfusion_flutter_sliders/sliders.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Range Selector Chart',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: RangeSelectorChart(),
    );
  }
}

class RangeSelectorChart extends StatefulWidget {
  @override
  _RangeSelectorChartState createState() => _RangeSelectorChartState();
}

class _RangeSelectorChartState extends State<RangeSelectorChart> {
  List<ChartSampleData> chartData = <ChartSampleData>[];
  late RangeController rangeController;

  @override
  void initState() {
    super.initState();
    // 차트 데이터 생성
    for (int i = 0; i < 365; i++) {
      chartData.add(ChartSampleData(
          x: DateTime(2017, 1, 1).add(Duration(days: i)),
          y: 0.95 - i * 0.0005 + Random().nextDouble() * 0.02));
    }

    // RangeController 초기화
    rangeController = RangeController(
      start: DateTime(2017, 5, 1),
      end: DateTime(2017, 9, 1),
    );
  }

  @override
  void dispose() {
    rangeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Range Selector Chart"),
      ),
      body: Column(
        children: [
          // 상단 메인 그래프
          Expanded(
            flex: 3,
            child: SfCartesianChart(
              title: ChartTitle(text: 'EUR Exchange Rate From USD 2017'),
              primaryXAxis: DateTimeAxis(
                minimum: DateTime(2017, 1, 1),
                maximum: DateTime(2018, 1, 1),
                rangeController: rangeController,
              ),
              primaryYAxis: NumericAxis(),
              series: <SplineSeries<ChartSampleData, DateTime>>[
                SplineSeries<ChartSampleData, DateTime>(
                  dataSource: chartData,
                  xValueMapper: (ChartSampleData data, _) => data.x,
                  yValueMapper: (ChartSampleData data, _) => data.y,
                  color: const Color.fromRGBO(0, 193, 187, 1),
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
                min: DateTime(2017, 1, 1),
                max: DateTime(2018, 1, 1),
                interval: 1,
                dateIntervalType: DateIntervalType.months,
                showTicks: true,
                showLabels: true,
                controller: rangeController,
                onChanged: (SfRangeValues values) {
                  setState(() {});
                },
                child: Container(
                  height: 75,
                  child: SfCartesianChart(
                    primaryXAxis: DateTimeAxis(isVisible: false),
                    primaryYAxis: NumericAxis(isVisible: false),
                    series: <SplineAreaSeries<ChartSampleData, DateTime>>[
                      SplineAreaSeries<ChartSampleData, DateTime>(
                        dataSource: chartData,
                        xValueMapper: (ChartSampleData data, _) => data.x,
                        yValueMapper: (ChartSampleData data, _) => data.y,
                        borderColor: const Color.fromRGBO(0, 193, 187, 1),
                        color: const Color.fromRGBO(163, 226, 224, 1),
                        borderWidth: 1,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
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
