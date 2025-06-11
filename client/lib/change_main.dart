import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'package:table_calendar/table_calendar.dart';

import 'package:client/CounselingDetailpage.dart';
import 'package:client/data_measure.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Client Records',
      home: ClientRecordPage(counselorId: '1'),
    );
  }
}

class ClientRecordPage extends StatefulWidget {
  final String counselorId;
  ClientRecordPage({required this.counselorId});

  @override
  _ClientRecordPageState createState() => _ClientRecordPageState();
}

class _ClientRecordPageState extends State<ClientRecordPage> {
  List clients = [];
  List filteredClients = [];
  final TextEditingController _searchController = TextEditingController();
  bool _isNameAsc = true;

  int? _expandedIndex;
  Map<String, Map<String, List<String>>> _clientTimesByDate = {};
  Map<String, List<DateTime>> _clientMarkedDates = {};
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  String? _selectedClientId;
  String? _selectedClientName;

  @override
  void initState() {
    super.initState();
    fetchClients();
  }

  Future<void> fetchClients() async {
    final response = await http.get(
      Uri.parse('http://localhost:5000/clients/${widget.counselorId}'),
    );
    if (response.statusCode == 200) {
      setState(() {
        clients = json.decode(response.body);
        filteredClients = List.from(clients);
        _sortByLastSession();
      });
    }
  }

  Future<void> _fetchClientDetails(String clientId) async {
    if (_clientMarkedDates.containsKey(clientId)) return;

    final response = await http.get(
      Uri.parse('http://localhost:5000/client_history/$clientId'),
    );
    if (response.statusCode == 200) {
      List data = json.decode(response.body);
      Map<String, List<String>> timeMap = {};
      List<DateTime> markedDates = [];

      for (var item in data) {
        try {
          DateTime dt = HttpDate.parse(item['day']);
          String dateKey = '${dt.year}-${dt.month}-${dt.day}';
          String time =
              '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';
          timeMap.putIfAbsent(dateKey, () => []).add(time);
          markedDates.add(DateTime(dt.year, dt.month, dt.day));
        } catch (_) {}
      }

      setState(() {
        _clientTimesByDate[clientId] = timeMap;
        _clientMarkedDates[clientId] = markedDates;
      });
    }
  }

  void _filterClients(String keyword) {
    setState(() {
      filteredClients = clients
          .where((client) =>
              client['username'].toLowerCase().contains(keyword.toLowerCase()))
          .toList();
    });
  }

  void _sortByLastSession() {
    setState(() {
      filteredClients.sort((a, b) {
        final aTime = a['last_session_time'];
        final bTime = b['last_session_time'];
        if (aTime == null) return 1;
        if (bTime == null) return -1;
        try {
          return DateTime.parse(bTime).compareTo(DateTime.parse(aTime));
        } catch (_) {
          return 0;
        }
      });
    });
  }

  void _sortByName() {
    setState(() {
      filteredClients.sort((a, b) {
        return _isNameAsc
            ? a['username'].compareTo(b['username'])
            : b['username'].compareTo(a['username']);
      });
      _isNameAsc = !_isNameAsc;
    });
  }

  void _deleteClient(dynamic client) {
    setState(() {
      clients.remove(client);
      filteredClients.remove(client);
    });
  }

  void _editClient(Map<String, dynamic> client) {
    print('Edit: ${client['username']}');
  }

  String formatDate(String? dateTimeStr) {
    if (dateTimeStr == null || dateTimeStr.trim().isEmpty) return '-';
    try {
      final datePart = dateTimeStr.split(' ').first;
      final dt = DateTime.parse(datePart);
      return '${dt.year}/${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')}';
    } catch (_) {
      return '-';
    }
  }

  String formatTime(String? dateTimeStr) {
    if (dateTimeStr == null || dateTimeStr.trim().isEmpty) return '-';
    try {
      final parts = dateTimeStr.split(' ');
      if (parts.length < 2) return '-';
      final timePart = parts[1];
      final dt = DateTime.parse('2000-01-01 $timePart');
      final hour = dt.hour > 12 ? dt.hour - 12 : dt.hour;
      final suffix = dt.hour >= 12 ? 'pm' : 'am';
      return '$hour:${dt.minute.toString().padLeft(2, '0')} $suffix';
    } catch (_) {
      return '-';
    }
  }

  String _buildDayDifferenceText(String? dateTimeStr) {
    if (dateTimeStr == null || dateTimeStr.trim().isEmpty) return '';
    try {
      final parts = dateTimeStr.split(' ');
      final datePart = parts.first;
      final dt = DateTime.parse(datePart);
      final now = DateTime.now();
      final diff = now.difference(dt).inDays;

      if (diff == 0) return '오늘';
      if (diff == 1) return '어제';
      return '$diff일 전';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Client Records")),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              onChanged: (value) => _filterClients(value),
              decoration: InputDecoration(
                hintText: 'Search records',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _filterClients('');
                        },
                      )
                    : null,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Row(
              children: [
                Expanded(
                  flex: 4,
                  child: Row(
                    children: [
                      Text('이름', style: TextStyle(color: Colors.grey)),
                      IconButton(
                        icon: Icon(
                          _isNameAsc
                              ? Icons.arrow_drop_up
                              : Icons.arrow_drop_down,
                          size: 18,
                        ),
                        onPressed: _sortByName,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Row(
                    children: [
                      Text('최근 상담 일자', style: TextStyle(color: Colors.grey)),
                      IconButton(
                        icon: Icon(Icons.arrow_drop_down, size: 18),
                        onPressed: _sortByLastSession,
                      ),
                    ],
                  ),
                ),
                Expanded(flex: 1, child: SizedBox()),
              ],
            ),
          ),
          Divider(),
          Expanded(
            child: ListView.builder(
              itemCount: filteredClients.length,
              itemBuilder: (context, index) {
                final client = filteredClients[index];
                final clientId = client['id'];
                final clientName = client['username'];
                final markedDates = _clientMarkedDates[clientId] ?? [];

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () async {
                          print(client['id']);
                          print(client['username']);
                          setState(() {
                            _expandedIndex =
                                (_expandedIndex == index) ? null : index;
                            _selectedClientId = clientId;
                            _selectedClientName = clientName;
                            _selectedDay = null;
                          });
                          await _fetchClientDetails(clientId);
                        },
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 4,
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      backgroundImage: AssetImage(
                                        (client['gender'] == 'male' ||
                                                client['gender'] == '남자')
                                            ? 'assets/image/man.png'
                                            : 'assets/image/woman.png',
                                      ),
                                    ),
                                    SizedBox(width: 10),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(client['username'],
                                            style: TextStyle(
                                                fontWeight: FontWeight.bold)),
                                        Text(clientId,
                                            style:
                                                TextStyle(color: Colors.grey)),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              Expanded(
                                flex: 3,
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // 날짜 + 시간 (세로 정렬)
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(formatDate(
                                            client['last_session_time'])),
                                        Text(
                                          formatTime(
                                              client['last_session_time']),
                                          style: TextStyle(color: Colors.grey),
                                        ),
                                      ],
                                    ),
                                    SizedBox(width: 32), // 약간의 간격만
                                    // '며칠 전' 정보
                                    Text(
                                      _buildDayDifferenceText(
                                          client['last_session_time']),
                                      style: TextStyle(color: Colors.blueGrey),
                                    ),
                                  ],
                                ),
                              ),
                              Expanded(
                                flex: 1,
                                child: Center(
                                  child: Container(
                                    height: 36,
                                    padding:
                                        EdgeInsets.symmetric(horizontal: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.grey[200],
                                      border: Border.all(color: Colors.grey),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: PopupMenuButton<String>(
                                      padding: EdgeInsets.zero,
                                      onSelected: (value) {
                                        if (value == 'edit')
                                          _editClient(client);
                                        if (value == 'delete')
                                          _deleteClient(client);
                                      },
                                      itemBuilder: (context) => [
                                        PopupMenuItem(
                                            value: 'edit',
                                            child: Text('개인정보 수정')),
                                        PopupMenuItem(
                                            value: 'delete',
                                            child: Text('Delete record',
                                                style: TextStyle(
                                                    color: Colors.red))),
                                      ],
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.settings,
                                              size: 24,
                                              color: Colors.grey[800]),
                                          Icon(Icons.arrow_drop_down,
                                              size: 24,
                                              color: Colors.grey[800]),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (_expandedIndex == index)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 12),
                        child: Column(
                          children: [
                            ElevatedButton(
                              onPressed: () {
                                final clientName = client['username'];
                                final clientId = client['id'];

                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => DataMeasure(
                                      clientName: clientName,
                                      clientId: clientId,
                                    ),
                                  ),
                                );
                              },
                              child: Text('상담하러 가기'),
                            ),
                            SizedBox(height: 12),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // 🟣 왼쪽: 달력
                                Expanded(
                                  flex: 1,
                                  child: TableCalendar(
                                    firstDay: DateTime.utc(2020, 1, 1),
                                    lastDay: DateTime.now(),
                                    focusedDay: _focusedDay,
                                    selectedDayPredicate: (day) =>
                                        isSameDay(_selectedDay, day),
                                    onDaySelected: (selectedDay, focusedDay) {
                                      setState(() {
                                        _selectedDay = selectedDay;
                                        _focusedDay = focusedDay;
                                      });
                                    },
                                    eventLoader: (day) {
                                      return markedDates.any((d) =>
                                              d.year == day.year &&
                                              d.month == day.month &&
                                              d.day == day.day)
                                          ? ['✓']
                                          : [];
                                    },
                                    calendarFormat: CalendarFormat.month,
                                    onFormatChanged: (format) {
                                      setState(() {
                                        _focusedDay = DateTime.now();
                                        _selectedDay = DateTime.now();
                                      });
                                    },
                                    calendarBuilders: CalendarBuilders(
                                      defaultBuilder:
                                          (context, day, focusedDay) {
                                        bool isMarked = markedDates.any((d) =>
                                            d.year == day.year &&
                                            d.month == day.month &&
                                            d.day == day.day);
                                        if (isMarked) {
                                          return Center(
                                            child: Container(
                                              decoration: BoxDecoration(
                                                color: Colors.blue[100],
                                                shape: BoxShape.circle,
                                              ),
                                              padding: EdgeInsets.all(8),
                                              child: Text('${day.day}',
                                                  style: TextStyle(
                                                      color: Colors.black)),
                                            ),
                                          );
                                        }
                                        return null;
                                      },
                                      todayBuilder: (context, day, focusedDay) {
                                        return Center(
                                          child: Container(
                                            decoration: BoxDecoration(
                                              color: Colors.orangeAccent,
                                              shape: BoxShape.circle,
                                            ),
                                            padding: EdgeInsets.all(8),
                                            child: Text('${day.day}',
                                                style: TextStyle(
                                                    color: Colors.white)),
                                          ),
                                        );
                                      },
                                      selectedBuilder:
                                          (context, day, focusedDay) {
                                        return Center(
                                          child: Container(
                                            decoration: BoxDecoration(
                                              color: Colors.blue,
                                              shape: BoxShape.circle,
                                            ),
                                            padding: EdgeInsets.all(8),
                                            child: Text('${day.day}',
                                                style: TextStyle(
                                                    color: Colors.white)),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),

                                SizedBox(width: 12),

                                // 🟡 오른쪽: 상담 시간 → ❗ 가운데 정렬로 변경
                                Expanded(
                                  flex: 1,
                                  child: Column(
                                    mainAxisAlignment:
                                        MainAxisAlignment.center, // ✅ 수직 중앙 정렬
                                    children: [
                                      if (_selectedDay != null &&
                                          _selectedClientId != null)
                                        _buildSessionTimes(_selectedClientId!,
                                            _selectedClientName!, _selectedDay!)
                                    ],
                                  ),
                                ),
                              ],
                            )
                          ],
                        ),
                      ),
                    Divider(height: 1, color: Colors.grey[300]),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
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

  Widget _buildSessionTimes(
      String clientId, String clientName, DateTime selectedDay) {
    final dateKey =
        "${selectedDay.year}-${selectedDay.month}-${selectedDay.day}";
    final times = _clientTimesByDate[clientId]?[dateKey] ?? [];

    if (times.isEmpty) return SizedBox.shrink();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text('상담 시간:', style: TextStyle(fontWeight: FontWeight.bold)),
        SizedBox(height: 12),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 12,
          runSpacing: 8,
          children: times.map((t) {
            return ElevatedButton(
              onPressed: () {
                print(
                    'Clicked $t for client $clientId to name $clientName on $dateKey');
                // move to data_history
                // Navigator.pop(context);
                // _goToDetailPage(s['counseling_id'], s['client_name']);
              },
              child: Text(t),
            );
          }).toList(),
        ),
      ],
    );
  }
}
