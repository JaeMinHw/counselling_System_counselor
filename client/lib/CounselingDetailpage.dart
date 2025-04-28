import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:syncfusion_flutter_sliders/sliders.dart';
import 'package:http/http.dart' as http;
import 'package:syncfusion_flutter_core/core.dart';

import 'package:intl/intl.dart';

class CounselingDetailPage extends StatefulWidget {
  final int counselingId;

  const CounselingDetailPage({Key? key, required this.counselingId})
      : super(key: key);

  @override
  _CounselingDetailPageState createState() => _CounselingDetailPageState();
}

class _CounselingDetailPageState extends State<CounselingDetailPage> {
  List<ChartSampleData> chartData1 = [];
  List<ChartSampleData> chartData2 = [];
  List<Map<String, dynamic>> messages = [];

  late RangeController rangeController;
  late ZoomPanBehavior _zoomPanBehavior;
  final ScrollController _scrollController = ScrollController();

  bool _isLineChart = true;
  int _currentIconIndex = 0;
  List<String> _icons = ['assets/image/curve.png', 'assets/image/line.png'];

  @override
  void initState() {
    super.initState();
    _zoomPanBehavior = ZoomPanBehavior(
      enablePinching: true,
      enableDoubleTapZooming: true,
      enableSelectionZooming: true,
      enablePanning: true,
    );
    rangeController = RangeController(
      start: DateTime.now().subtract(Duration(seconds: 5)),
      end: DateTime.now(),
    );

    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      final response = await http.get(
        Uri.parse(
            'http://218.151.124.83:5000/get_counseling_detail/${widget.counselingId}'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == 'success') {
          setState(() {
            // chartData1과 chartData2가 존재하는 경우에만 처리
            if (data.containsKey('chartData1') && data['chartData1'] != null) {
              chartData1 = (data['chartData1'] as List).map((e) {
                return ChartSampleData(
                  x: DateTime.parse(e['x']),
                  y: (e['y'] as num).toDouble(),
                );
              }).toList();
            } else {
              chartData1 = []; // 없으면 빈 리스트
            }

            if (data.containsKey('chartData2') && data['chartData2'] != null) {
              chartData2 = (data['chartData2'] as List).map((e) {
                return ChartSampleData(
                  x: DateTime.parse(e['x']),
                  y: (e['y'] as num).toDouble(),
                );
              }).toList();
            } else {
              chartData2 = []; // 없으면 빈 리스트
            }

            // messages 부분은 정상적으로 받아오고 있음
            if (data.containsKey('messages') && data['messages'] != null) {
              messages = List<Map<String, dynamic>>.from(data['messages']);
            } else {
              messages = [];
            }
          });
        } else {
          print('데이터 가져오기 실패: ${data['message']}');
        }
      } else {
        print('서버 오류: ${response.statusCode}');
      }
    } catch (e) {
      print('데이터 가져오기 실패: $e');
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    rangeController.dispose();
    super.dispose();
  }

  void _moveToGraphTime(String selectedTime) {
    try {
      List<String> parts = selectedTime.split(":");
      int hours = int.parse(parts[0]);
      int minutes = int.parse(parts[1]);
      int seconds = int.parse(parts[2]);
      DateTime parsedTime = DateTime(
        DateTime.now().year,
        DateTime.now().month,
        DateTime.now().day,
        hours,
        minutes,
        seconds,
      );
      setState(() {
        rangeController.start = parsedTime.subtract(Duration(seconds: 5));
        rangeController.end = parsedTime.add(Duration(seconds: 5));
      });
    } catch (e) {
      debugPrint("Error in _moveToGraphTime: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('상담 기록 상세 보기'),
        actions: [
          IconButton(
            icon: Image.asset(_icons[_currentIconIndex],
                width: 30, height: 30, color: Colors.black),
            onPressed: () {
              setState(() {
                _currentIconIndex = (_currentIconIndex + 1) % _icons.length;
                _isLineChart = !_isLineChart;
              });
            },
          ),
        ],
      ),
      body: Row(
        children: [
          Expanded(
            flex: 3,
            child: Column(
              children: [
                Expanded(
                  flex: 1,
                  child: SfCartesianChart(
                    title: ChartTitle(text: 'Data 1 Chart'),
                    zoomPanBehavior: _zoomPanBehavior,
                    primaryXAxis: DateTimeAxis(
                      dateFormat: DateFormat('HH:mm:ss'),
                      intervalType: DateTimeIntervalType.seconds,
                      rangeController: rangeController,
                    ),
                    primaryYAxis: NumericAxis(),
                    series: _isLineChart
                        ? [
                            LineSeries<ChartSampleData, DateTime>(
                              dataSource: chartData1,
                              xValueMapper: (ChartSampleData data, _) => data.x,
                              yValueMapper: (ChartSampleData data, _) => data.y,
                            ),
                          ]
                        : [
                            SplineSeries<ChartSampleData, DateTime>(
                              dataSource: chartData1,
                              xValueMapper: (ChartSampleData data, _) => data.x,
                              yValueMapper: (ChartSampleData data, _) => data.y,
                            ),
                          ],
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: SfCartesianChart(
                    title: ChartTitle(text: 'Data 2 Chart'),
                    primaryXAxis: DateTimeAxis(
                      dateFormat: DateFormat('HH:mm:ss'),
                      intervalType: DateTimeIntervalType.seconds,
                      rangeController: rangeController,
                    ),
                    primaryYAxis: NumericAxis(),
                    series: _isLineChart
                        ? [
                            LineSeries<ChartSampleData, DateTime>(
                              dataSource: chartData2,
                              xValueMapper: (ChartSampleData data, _) => data.x,
                              yValueMapper: (ChartSampleData data, _) => data.y,
                            ),
                          ]
                        : [
                            SplineSeries<ChartSampleData, DateTime>(
                              dataSource: chartData2,
                              xValueMapper: (ChartSampleData data, _) => data.x,
                              yValueMapper: (ChartSampleData data, _) => data.y,
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
                          : DateTime.now().subtract(Duration(seconds: 1000)),
                      max: chartData1.isNotEmpty
                          ? chartData1.last.x
                          : DateTime.now(),
                      interval: 1,
                      dateIntervalType: DateIntervalType.seconds,
                      showTicks: true,
                      showLabels: false,
                      controller: rangeController,
                      dragMode: SliderDragMode.both,
                      child: SfCartesianChart(
                        primaryXAxis: DateTimeAxis(
                          intervalType: DateTimeIntervalType.seconds,
                          rangeController: rangeController,
                        ),
                        primaryYAxis: NumericAxis(isVisible: false),
                        series: _isLineChart
                            ? [
                                LineSeries<ChartSampleData, DateTime>(
                                  dataSource: chartData1,
                                  xValueMapper: (ChartSampleData data, _) =>
                                      data.x,
                                  yValueMapper: (ChartSampleData data, _) =>
                                      data.y,
                                ),
                                LineSeries<ChartSampleData, DateTime>(
                                  dataSource: chartData2,
                                  xValueMapper: (ChartSampleData data, _) =>
                                      data.x,
                                  yValueMapper: (ChartSampleData data, _) =>
                                      data.y,
                                ),
                              ]
                            : [
                                SplineSeries<ChartSampleData, DateTime>(
                                  dataSource: chartData1,
                                  xValueMapper: (ChartSampleData data, _) =>
                                      data.x,
                                  yValueMapper: (ChartSampleData data, _) =>
                                      data.y,
                                ),
                                SplineSeries<ChartSampleData, DateTime>(
                                  dataSource: chartData2,
                                  xValueMapper: (ChartSampleData data, _) =>
                                      data.x,
                                  yValueMapper: (ChartSampleData data, _) =>
                                      data.y,
                                ),
                              ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
              flex: 1,
              child: ListView.builder(
                controller: _scrollController,
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final message = messages[index];
                  final bool isMe = message['label'] == 'me';

                  return GestureDetector(
                    onTap: () {
                      _moveToGraphTime(message['sentTime']);
                    },
                    child: Align(
                      alignment:
                          isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        padding: EdgeInsets.all(10),
                        margin:
                            EdgeInsets.symmetric(vertical: 5, horizontal: 10),
                        decoration: BoxDecoration(
                          color: isMe ? Colors.blue[100] : Colors.grey[300],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(message['text'] ?? '',
                                style: TextStyle(fontSize: 16)),
                            SizedBox(height: 4),
                            Text(message['sentTime'] ?? '',
                                style: TextStyle(
                                    fontSize: 12, color: Colors.black54)),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              )),
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
