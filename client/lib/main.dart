import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WebSocket Example',
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
  bool _isStartButtonEnabled = false; // Start 버튼 활성화 여부를 추적합니다.

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
    });

    socket!.onDisconnect((_) {
      setState(() {
        _isConnected = false;
        _isStartButtonEnabled = false; // 연결이 끊기면 Start 버튼 비활성화
      });
      print('Disconnected from the server');
    });

    socket!.on('enable_start', (data) {
      print('Received enable_start with data: $data');
      setState(() {
      _isStartButtonEnabled = data['enable'];
    });
    });


    socket!.connect();
  }

  void _disconnectWebSocket() {
    if (socket != null && socket!.connected) {
      socket!.disconnect();
    }
  }

  void _start() {
    // 'start' 이벤트를 서버에 전송
    socket!.emit('start');
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
          title: Text('WebSocket Example'),
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                if (_isConnected && _isStartButtonEnabled) Column(
                  children: [
                    ElevatedButton(
                      onPressed: _start,
                      child: Text('Start Connection'),
                    ),
                    SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: _disconnectWebSocket,
                      child: Text('Stop Connection'),
                    ),
                  ],
                ) else Container(
                  child: Text('Waiting for both clients to connect...'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
