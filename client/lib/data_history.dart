import 'package:flutter/material.dart';

class DataHistory extends StatefulWidget {
  const DataHistory({super.key});

  @override
  State<DataHistory> createState() => _DataHistoryState();
}

class _DataHistoryState extends State<DataHistory> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('데이터 기록'),
      ),
      body: Center(
        // 버튼 두 개를 가로(Raw/Column) 배치할 수 있습니다.
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 첫 번째 버튼

            const SizedBox(width: 20), // 버튼 사이 간격
            // 두 번째 버튼
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const DataHistory()),
                );
              },
              child: const Text('다른 페이지'),
            ),
          ],
        ),
      ),
    );
  }
}
