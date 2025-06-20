import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'dart:convert';
import 'package:client/CounselingDetailpage.dart';

class DataHistory extends StatefulWidget {
  const DataHistory({super.key});

  @override
  State<DataHistory> createState() => _DataHistoryState();
}

class _DataHistoryState extends State<DataHistory> {
  IO.Socket? socket;
  List<dynamic> allClients = [];
  Map<String, List<Map<String, dynamic>>> groupedByDate = {};

  @override
  void initState() {
    super.initState();
    _connectSocket();
  }

  void _connectSocket() {
    socket = IO.io(
      'http://218.151.124.83:5000',
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .enableAutoConnect()
          .enableForceNew()
          .build(),
    );

    socket!.onConnect((_) {
      print('Socket connected');

      socket!.emit('counselor_login', {'counselor_id': '1'});

      Future.delayed(Duration(milliseconds: 300), () {
        socket!.emit('data_history');
      });
    });

    socket!.on('data_history_result', (data) {
      print('data_history_result: $data');
      if (data['status'] == 'success') {
        setState(() {
          allClients = data['clients'];
          _groupSessionsByDate();
        });
      } else {
        print('Data history error: ${data['message']}');
      }
    });

    socket!.emit('eeg_data', {'counselor_id': '1'});

    socket!.onDisconnect((_) {
      print('Socket disconnected');
    });
  }

  void _groupSessionsByDate() {
    groupedByDate.clear();

    for (var client in allClients) {
      final clientName = client['username'];
      final sessions = client['valid_sessions'];

      for (var session in sessions) {
        final date = session['day'];
        final time = session['time'];
        final counselingId = session['counseling_id'];

        groupedByDate.putIfAbsent(date, () => []);
        groupedByDate[date]!.add({
          'time': time,
          'counseling_id': counselingId,
          'client_name': clientName,
        });
      }
    }

    print("groupedByDate: $groupedByDate");
  }

  void _handleDateTap(String date) {
    final sessions = groupedByDate[date]!;

    if (sessions.length == 1) {
      // ✅ 1개 → 바로 이동
      _goToDetailPage(sessions[0]['counseling_id'], sessions[0]['client_name']);
    } else {
      // ✅ 여러 개 → 시간 선택 다이얼로그
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: Text("시간 선택 - $date"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: sessions.map((s) {
              return ListTile(
                title: Text(s['time']),
                onTap: () {
                  Navigator.pop(context);
                  _goToDetailPage(s['counseling_id'], s['client_name']);
                },
              );
            }).toList(),
          ),
        ),
      );
    }
  }

  void _goToDetailPage(int counselingId, String clientName) {
    print("이동: $clientName / counseling_id: $counselingId");

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CounselingDetailPage(
          counselingId: counselingId,
        ),
      ),
    );
  }

  @override
  void dispose() {
    socket?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dates = groupedByDate.keys.toList()..sort();

    return Scaffold(
      appBar: AppBar(
        title: Text('데이터 기록'),
      ),
      body: dates.isEmpty
          ? Center(child: Text('기록이 없습니다.'))
          : ListView.builder(
              itemCount: dates.length,
              itemBuilder: (context, index) {
                final date = dates[index];
                return ListTile(
                  title: Text('날짜: $date'),
                  onTap: () => _handleDateTap(date),
                );
              },
            ),
    );
  }
}
