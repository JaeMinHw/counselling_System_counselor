import 'dart:async';
import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:fl_chart/fl_chart.dart';

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

  List<FlSpot> _dataPoints1 = [];
  List<FlSpot> _dataPoints2 = [];
  List<String> _timeLabels = [];
  int _maxDataPoints = 100;  // 그래프에 표시될 최대 데이터 포인트 수

  StreamController<List<FlSpot>>? _dataStreamController1;
  StreamController<List<FlSpot>>? _dataStreamController2;

  @override
  void initState() {
    super.initState();
    _connectWebSocket();
  }

  @override
  void dispose() {
    _dataStreamController1?.close();
    _dataStreamController2?.close();
    _disconnectWebSocket();
    super.dispose();
  }

  void _connectWebSocket() {
    socket = IO.io(
      'ws://192.168.0.72:5000',
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

    socket!.on('data_update', (data) {
      if (_dataStreamController1 == null || _dataStreamController2 == null) {
        return;
      }

      final String time = data['time']; // 서버에서 받은 시간
      _timeLabels.add(time);

      _dataPoints1.add(FlSpot(_timeLabels.length.toDouble(), double.parse(data['data1'].toString())));
      _dataPoints2.add(FlSpot(_timeLabels.length.toDouble(), double.parse(data['data2'].toString())));

      // 데이터 포인트 제한
      if (_dataPoints1.length > _maxDataPoints) {
        _dataPoints1.removeAt(0);
        _dataPoints2.removeAt(0);
        _timeLabels.removeAt(0);
      }

      _dataStreamController1!.add(_dataPoints1);
      _dataStreamController2!.add(_dataPoints2);
    });

    socket!.on('connection_accepted', (data) {
      setState(() {
        _isConnectionRequested = false;
        _isConnectionAccepted = true;
      });
      print('Connection accepted: $data');
    });

    socket!.connect();
  }

  void _disconnectWebSocket() {
    if (socket != null && socket!.connected) {
      socket!.disconnect();
    }
  }

  void _acceptConnection() {
    if (socket != null && socket!.connected) {
      socket!.emit('accept_connection');
    }
  }

  void _declineConnection() {
    if (socket != null && socket!.connected) {
      socket!.emit('decline_connection');
      setState(() {
        _isConnectionRequested = false;
      });
    }
  }

  void _startDataTransmission() {
    if (_dataStreamController1 != null && _dataStreamController2 != null) {
      _dataStreamController1!.close();
      _dataStreamController2!.close();
    }

    _dataStreamController1 = StreamController<List<FlSpot>>();
    _dataStreamController2 = StreamController<List<FlSpot>>();

    setState(() {
      _dataPoints1.clear();
      _dataPoints2.clear();
      _timeLabels.clear();
    });

    if (socket != null && socket!.connected) {
      socket!.emit('start');
    }
  }

  void _stopDataTransmission() {
    if (socket != null && socket!.connected) {
      socket!.emit('stop');
      socket!.off('data_update');

      _dataStreamController1?.close();
      _dataStreamController2?.close();

    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        appBar: AppBar(
          title: Text('Counselor Dashboard'),
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                if (_isConnected && _isConnectionRequested)
                  Column(
                    children: [
                      Text('Connect with $_patientName?'),
                      SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: _acceptConnection,
                        child: Text('Accept Connection'),
                      ),
                      SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: _declineConnection,
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
                        child: Text('Start'),
                      ),
                      SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: _stopDataTransmission,
                        child: Text('Stop'),
                      ),
                      SizedBox(height: 16),
                      if (_dataStreamController1 != null &&
                          _dataStreamController2 != null)
                        StreamBuilder<List<FlSpot>>(
                          stream: _dataStreamController1!.stream,
                          builder: (context, snapshot1) {
                            return StreamBuilder<List<FlSpot>>(
                              stream: _dataStreamController2!.stream,
                              builder: (context, snapshot2) {
                                if (snapshot1.hasData && snapshot2.hasData) {
                                  return _buildChart(
                                    snapshot1.data!,
                                    snapshot2.data!,
                                  );
                                } else {
                                  return CircularProgressIndicator();
                                }
                              },
                            );
                          },
                        ),
                    ],
                  )
                else
                  Container(
                    child: Text(_isConnected
                        ? 'Waiting for connection request...'
                        : 'Disconnected from the server.'),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChart(
      List<FlSpot> dataPoints1, List<FlSpot> dataPoints2) {
    return Container(
      height: 300,
      child: LineChart(
        LineChartData(
          gridData: FlGridData(show: true),
          titlesData: FlTitlesData(
            bottomTitles: SideTitles(
              showTitles: true,
              getTitles: (value) {
                final int index = value.toInt();
                if (index < 0 || index >= _timeLabels.length) {
                  return '';
                }
                return _timeLabels[index];
              },
              reservedSize: 22,
              margin: 8,
            ),
          ),
          borderData: FlBorderData(show: true),
          lineBarsData: [
            LineChartBarData(
              spots: dataPoints1,
              isCurved: true,
              colors: [Colors.blue],
              barWidth: 4,
              isStrokeCapRound: true,
            ),
            LineChartBarData(
              spots: dataPoints2,
              isCurved: true,
              colors: [Colors.red],
              barWidth: 4,
              isStrokeCapRound: true,
            ),
          ],
          minX: dataPoints1.isNotEmpty ? dataPoints1.first.x : 0,
          maxX: dataPoints1.isNotEmpty ? dataPoints1.last.x : _maxDataPoints.toDouble(),
          minY: 0,
          maxY: 100,
        ),
      ),
    );
  }
}
