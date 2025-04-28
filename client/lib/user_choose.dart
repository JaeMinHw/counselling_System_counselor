import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'middle_page.dart';

String myId = "1"; // 실제 ID로 변경 가능

void main() {
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: UserChoose(),
  ));
}

// ✅ 1. Client 클래스 정의
class Client {
  final String username;
  final String id;

  Client({required this.username, required this.id});

  factory Client.fromJson(Map<String, dynamic> json) {
    return Client(
      username: json['username'],
      id: json['id'],
    );
  }
}

// ✅ 2. UserChoose StatefulWidget
class UserChoose extends StatefulWidget {
  const UserChoose({super.key});

  @override
  State<UserChoose> createState() => _UserChooseState();
}

class _UserChooseState extends State<UserChoose> {
  late Future<List<Client>> _clientsFuture;
  List<Client> _allClients = [];
  List<Client> _filteredClients = [];
  String _searchKeyword = '';

  String counsel_name = '';

  @override
  void initState() {
    super.initState();
    _clientsFuture = _loadClients(); // 🔄 fetchClientsFromServer() 대신

    fetchCounselName();
  }

  Future<void> fetchCounselName() async {
    try {
      final response = await http.get(
        Uri.parse('http://218.151.124.83:5000/counsel_name/$myId'),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonData = json.decode(response.body);
        print(jsonData);
        setState(() {
          counsel_name = jsonData['counsel_name'];
        });
      } else {
        throw Exception('서버 오류: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('서버 연결 실패: $e');
    }
  }

  Future<List<Client>> _loadClients() async {
    final clients = await fetchClientsFromServer();
    _allClients = clients;
    _filteredClients = clients;
    return clients;
  }

  // ✅ 서버에서 Client 목록 받아오기
  Future<List<Client>> fetchClientsFromServer() async {
    try {
      final response = await http.get(
        Uri.parse('http://218.151.124.83:5000/clients/$myId'),
      );

      if (response.statusCode == 200) {
        final List<dynamic> jsonData = json.decode(response.body);
        print(jsonData);
        return jsonData.map((e) => Client.fromJson(e)).toList();
      } else {
        throw Exception('서버 오류: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('서버 연결 실패: $e');
    }
  }

  Future<void> _addClient(
      String username, String userId, String phone, String gender) async {
    try {
      final response = await http.post(
        Uri.parse('http://218.151.124.83:5000/add_client'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'username': username,
          'user_id': userId,
          'counselor_id': myId,
          'phone': phone,
          'gender': gender, // ✅ 추가: 성별도 같이 보낸다
        }),
      );

      if (response.statusCode == 200) {
        print('내담자 추가 성공');
      } else {
        print('내담자 추가 실패: ${response.body}');
      }
    } catch (e) {
      print('서버 오류: $e');
    }
  }

  // ✅ 검색 함수
  void _filterClients(String keyword) {
    setState(() {
      _searchKeyword = keyword;
      _filteredClients = _allClients
          .where((client) =>
              client.username.toLowerCase().contains(keyword.toLowerCase()))
          .toList();
    });
  }

  void _showAddClientDialog() {
    String username = '';
    String userId = '';
    String phone = '';
    String gender = '남자'; // 기본값 남자

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          // 💬 여기를 StatefulBuilder로 감싸야 해!!
          builder: (context, setState) {
            return AlertDialog(
              title: Text('내담자 추가'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    decoration: InputDecoration(labelText: '내담자 이름'),
                    onChanged: (value) {
                      username = value;
                    },
                  ),
                  TextField(
                    decoration: InputDecoration(labelText: '내담자 ID'),
                    onChanged: (value) {
                      userId = value;
                    },
                  ),
                  TextField(
                    decoration: InputDecoration(labelText: '내담자 전화번호'),
                    onChanged: (value) {
                      phone = value;
                    },
                  ),
                  SizedBox(height: 10),
                  Text('성별 선택', style: TextStyle(fontWeight: FontWeight.bold)),
                  Row(
                    children: [
                      Expanded(
                        child: RadioListTile<String>(
                          title: Text('남자'),
                          value: '남자',
                          groupValue: gender,
                          onChanged: (value) {
                            setState(() {
                              gender = value!;
                            });
                          },
                        ),
                      ),
                      Expanded(
                        child: RadioListTile<String>(
                          title: Text('여자'),
                          value: '여자',
                          groupValue: gender,
                          onChanged: (value) {
                            setState(() {
                              gender = value!;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('취소'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (username.isNotEmpty && userId.isNotEmpty) {
                      await _addClient(username, userId, phone, gender);
                      Navigator.pop(context);

                      // 여기! 페이지를 통째로 다시 띄워
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (context) => UserChoose()),
                      );
                    }
                  },
                  child: Text('추가'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('내담자 선택'),
      ),
      body: FutureBuilder<List<Client>>(
        future: _clientsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('오류 발생: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('내담자가 없습니다.'));
          }

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ✅ 상단 텍스트 + 검색창
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      ' $counsel_name님의 내담자 리스트',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(
                      width: 150,
                      child: TextField(
                        onChanged: _filterClients,
                        decoration: const InputDecoration(
                          hintText: '검색',
                          prefixIcon: Icon(Icons.search),
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(vertical: 8),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // ✅ 내담자 리스트
                Expanded(
                  child: SingleChildScrollView(
                    child: Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: _filteredClients.map((client) {
                        return ElevatedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => MiddlePage(
                                  clientName: client.username,
                                  clientId: client.id,
                                ),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                vertical: 20, horizontal: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(client.username),
                        );
                      }).toList(),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                // ✅ 내담자 추가 버튼
                Center(
                  child: ElevatedButton(
                    onPressed: () {
                      // 내담자 추가 기능 구현
                      _showAddClientDialog();
                    },
                    child: const Text('내담자 추가'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
