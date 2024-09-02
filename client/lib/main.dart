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
  bool _isConnectionRequested = false;  // 연결 요청을 받았는지 여부를 추적합니다.
  bool _isConnectionAccepted = false;  // 연결 수락 여부를 추적합니다.
  String _patientName = ''; // 연결 요청을 보낸 환자의 이름

  List<FlSpot> _dataPoints1 = [];  // 첫 번째 데이터 시리즈
  List<FlSpot> _dataPoints2 = [];  // 두 번째 데이터 시리즈
  double _xValue = 0;  // X축 값 추적

  @override
  void initState() {
    super.initState();
    _connectWebSocket();
  }

  void _connectWebSocket() {
    socket = IO.io(
      'ws://192.168.0.72:5000',
      IO.OptionBuilder()
          .setTransports(['websocket']) // 웹소켓 전송 사용
          .enableAutoConnect() // 자동 연결 활성화
          .enableForceNew() // 새 연결 강제 적용
          .setExtraHeaders({'Upgrade': 'websocket'}) // 웹소켓 업그레이드
          .build(),
    );

    socket!.onConnect((_) {
      setState(() {
        _isConnected = true;
      });
      print('Connected to the server');
      // 상담사 로그인 이벤트 서버로 전송
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
      print('Data received: $data');
      setState(() {
        _xValue += 1;  // X축 값을 증가시킴
        _dataPoints1.add(FlSpot(_xValue, double.parse(data['data1'].toString())));
        _dataPoints2.add(FlSpot(_xValue, double.parse(data['data2'].toString())));

        // 데이터 포인트가 너무 많아지면 제거하여 그래프가 고정된 크기를 유지하게 함
        if (_dataPoints1.length > 20) {
          _dataPoints1.removeAt(0);
          _dataPoints2.removeAt(0);
        }
      });
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
    if (socket != null && socket!.connected) {
      socket!.emit('start');
    }
  }

  void _stopDataTransmission() {
    if (socket != null && socket!.connected) {
      socket!.emit('stop');
    }
  }

  @override
  void dispose() {
    _disconnectWebSocket();
    super.dispose();
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
                if (_isConnected && _isConnectionRequested) Column(
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
                ) else if (_isConnected && _isConnectionAccepted) Column(
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
                    // 그래프 추가
                    _buildChart(),
                  ],
                ) else Container(
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

  // 그래프 빌드 메소드
  Widget _buildChart() {
    return Container(
      height: 300,
      child: LineChart(
        LineChartData(
          gridData: FlGridData(show: true),
          titlesData: FlTitlesData(show: true),
          borderData: FlBorderData(show: true),
          lineBarsData: [
            LineChartBarData(
              spots: _dataPoints1,
              isCurved: true,
              colors: [Colors.blue],
              barWidth: 4,
              isStrokeCapRound: true,
            ),
            LineChartBarData(
              spots: _dataPoints2,
              isCurved: true,
              colors: [Colors.red],
              barWidth: 4,
              isStrokeCapRound: true,
            ),
          ],
          minX: _dataPoints1.isNotEmpty ? _dataPoints1.first.x : 0,
          maxX: _dataPoints1.isNotEmpty ? _dataPoints1.last.x : 20,
          minY: 0,
          maxY: 100,
        ),
      ),
    );
  }
}
