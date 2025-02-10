import 'package:client/data_history.dart';
import 'package:client/data_measure.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

// 데이터 측정 화면 갔다가 뒤로 오고 다시 데이터 측정 화면 가면 에러 발생

void main() {
  debugRepaintRainbowEnabled = true;
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: const MiddlePage(),
    );
  }
}

class MiddlePage extends StatefulWidget {
  const MiddlePage({super.key});

  @override
  State<MiddlePage> createState() => _MiddlePageState();
}

class _MiddlePageState extends State<MiddlePage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('선택 페이지'),
      ),
      body: Center(
        // 버튼 두 개를 가로 배치
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 첫 번째 버튼: 데이터 측정 화면으로 이동
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => DataMeasure()),
                );
              },
              child: const Text('데이터 측정'),
            ),
            const SizedBox(width: 20),
            // 두 번째 버튼: 데이터 기록 보기 화면
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const DataHistory()),
                );
              },
              child: const Text('데이터 기록 보기'),
            ),
          ],
        ),
      ),
    );
  }
}
