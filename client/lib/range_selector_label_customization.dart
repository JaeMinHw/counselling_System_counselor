import 'dart:math';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

class SimpleChart extends StatefulWidget {
  @override
  _SimpleChartState createState() => _SimpleChartState();
}

class _SimpleChartState extends State<SimpleChart> {
  final List<ChartSampleData> chartData = <ChartSampleData>[];

  @override
  void initState() {
    super.initState();
    // 임의의 데이터 생성
    for (int i = 0; i < 366; i++) {
      chartData.add(ChartSampleData(
          x: DateTime(2000).add(Duration(days: i)),
          y: Random().nextInt(190) + 50));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Simple Chart")),
      body: SfCartesianChart(
        title: ChartTitle(text: 'Sample Line Chart'),
        primaryXAxis: DateTimeAxis(),
        primaryYAxis: NumericAxis(),
        series: <SplineSeries<ChartSampleData, DateTime>>[
          SplineSeries<ChartSampleData, DateTime>(
            dataSource: chartData,
            xValueMapper: (ChartSampleData sales, _) => sales.x as DateTime,
            yValueMapper: (ChartSampleData sales, _) => sales.y,
            color: const Color.fromRGBO(0, 193, 187, 1),
            // borderColor: Colors.blue,
          )
        ],
      ),
    );
  }
}

class ChartSampleData {
  ChartSampleData({this.x, this.y});
  final DateTime? x;
  final double? y;
}
