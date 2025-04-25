import 'package:client/data_history.dart';
import 'package:client/data_measure.dart';
import 'package:flutter/material.dart';

// 데이터 측정 화면 갔다가 뒤로 오고 다시 데이터 측정 화면 가면 에러 발생

// void main() {
//   // debugRepaintRainbowEnabled = true;
//   runApp(const MyApp());
// }

class MiddlePage extends StatefulWidget {
  final String clientName;
  final String clientId;

  const MiddlePage(
      {required this.clientName, required this.clientId, super.key});

  @override
  State<MiddlePage> createState() => _MiddlePageState();
}

class _MiddlePageState extends State<MiddlePage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.clientName} - 선택 페이지'),
      ),
      body: Center(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => DataMeasure(
                        clientName: widget.clientName,
                        clientId: widget.clientId),
                  ),
                );
              },
              child: const Text('데이터 측정'),
            ),
            const SizedBox(width: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const DataHistory(),
                  ),
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
