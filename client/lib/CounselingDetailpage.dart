import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class CounselingDetailPage extends StatefulWidget {
  final int counselingId;
  final String clientName;

  const CounselingDetailPage(
      {required this.counselingId, required this.clientName, super.key});

  @override
  State<CounselingDetailPage> createState() => _CounselingDetailPageState();
}

class _CounselingDetailPageState extends State<CounselingDetailPage> {
  List<dynamic> conversationList = [];

  @override
  void initState() {
    super.initState();
    _fetchConversationData();
  }

  Future<void> _fetchConversationData() async {
    final url = Uri.parse(
        'http://218.151.124.83:5000/conversation_data/${widget.counselingId}');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      setState(() {
        conversationList = json.decode(response.body);
      });
    } else {
      print('Failed to load conversation data');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.clientName} - 대화 기록'),
      ),
      body: conversationList.isEmpty
          ? Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: conversationList.length,
              itemBuilder: (context, index) {
                final message = conversationList[index];
                final isMe = message['label'] == 'me';
                return ListTile(
                  title: Align(
                    alignment:
                        isMe ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      margin: const EdgeInsets.symmetric(vertical: 5),
                      decoration: BoxDecoration(
                        color: isMe ? Colors.blue[100] : Colors.grey[300],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(message['text'] ?? '',
                          style: TextStyle(fontSize: 16)),
                    ),
                  ),
                  subtitle: Align(
                    alignment:
                        isMe ? Alignment.centerRight : Alignment.centerLeft,
                    child: Text('시작: ${message['start']}',
                        style: TextStyle(fontSize: 12)),
                  ),
                );
              },
            ),
    );
  }
}
