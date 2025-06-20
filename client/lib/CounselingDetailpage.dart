import 'dart:convert';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

class CounselingDetailPage extends StatefulWidget {
  final int counselingId;

  const CounselingDetailPage({Key? key, required this.counselingId})
      : super(key: key);

  @override
  _CounselingDetailPageState createState() => _CounselingDetailPageState();
}

class _CounselingDetailPageState extends State<CounselingDetailPage> {
  List<FlSpot> spots = [];
  List<DateTime> timestamps = [];

  double minX = 0;
  double maxX = 10;
  double maxLimit = 100;

  Offset? dragStart;

  @override
  void initState() {
    super.initState();
    _fetchData(widget.counselingId);
  }

  Future<void> _fetchData(int counselingId) async {
    final response = await http.get(
        Uri.parse('http://218.151.124.83:5000/get_bio_detail/$counselingId'));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final List<dynamic> messages = data['messages'];

      List<FlSpot> tempSpots = [];
      List<DateTime> tempTimestamps = [];

      for (int i = 0; i < messages.length; i++) {
        final item = messages[i];
        final time = DateTime.parse(item['value_time']);
        final value = (item['O1_value'] as num).toDouble();
        tempSpots.add(FlSpot(i.toDouble(), value));
        tempTimestamps.add(time);
      }

      setState(() {
        spots = tempSpots;
        timestamps = tempTimestamps;
        maxLimit = (spots.length - 1).toDouble();
        minX = 0;
        maxX = 10;
      });
    }
  }

  String _formatTimestamp(int index) {
    if (index < 0 || index >= timestamps.length) return '';
    return DateFormat('HH:mm:ss').format(timestamps[index]);
  }

  @override
  Widget build(BuildContext context) {
    double fixedRange = (maxX - minX).clamp(1, maxLimit);

    return Scaffold(
      appBar: AppBar(title: Text("상담 생체 데이터")),
      body: Column(
        children: [
          Expanded(
            child: GestureDetector(
              onHorizontalDragStart: (details) {
                dragStart = details.localPosition;
              },
              onHorizontalDragUpdate: (details) {
                if (dragStart != null) {
                  double dx = details.localPosition.dx - dragStart!.dx;
                  double screenWidth = MediaQuery.of(context).size.width;
                  double step = -(dx / screenWidth) * maxLimit;
                  setState(() {
                    minX = (minX + step).clamp(0, maxLimit - fixedRange);
                    maxX = (minX + fixedRange).clamp(minX + 1, maxLimit);
                  });
                  dragStart = details.localPosition;
                }
              },
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: spots.isEmpty
                    ? Center(child: CircularProgressIndicator())
                    : LineChart(
                        LineChartData(
                          minX: minX,
                          maxX: maxX,
                          minY: 0,
                          maxY: 120,
                          lineBarsData: [
                            LineChartBarData(
                              spots: spots,
                              isCurved: true,
                              color: Colors.blue,
                              barWidth: 2,
                              dotData: FlDotData(show: false),
                            )
                          ],
                          titlesData: FlTitlesData(
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                interval: 5,
                                getTitlesWidget: (value, meta) {
                                  int index = value.toInt();
                                  return Text(
                                    _formatTimestamp(index),
                                    style: TextStyle(fontSize: 10),
                                  );
                                },
                              ),
                            ),
                            topTitles: AxisTitles(
                                sideTitles: SideTitles(showTitles: false)),
                            rightTitles: AxisTitles(
                                sideTitles: SideTitles(showTitles: false)),
                          ),
                          gridData: FlGridData(show: true),
                          borderData: FlBorderData(show: true),
                          lineTouchData: LineTouchData(enabled: false),
                        ),
                      ),
              ),
            ),
          ),
          if (spots.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  Text("구간 선택: ${minX.toInt()} ~ ${maxX.toInt()}"),
                  RangeSlider(
                    values: RangeValues(minX, maxX),
                    min: 0,
                    max: maxLimit,
                    divisions: (maxLimit - 0).toInt().clamp(1, 200),
                    onChanged: (RangeValues values) {
                      setState(() {
                        minX = values.start;
                        maxX = values.end;
                      });
                    },
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
