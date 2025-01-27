// lib/colors.dart (예: 프로젝트 내 lib 폴더)
// 원하는 폴더/파일명으로 변경 가능

import 'package:flutter/material.dart';

class AppColors {
  // -------------------------
  // 1) 대화 말풍선 기본 색상
  // -------------------------
  // (왼쪽, 상대방)
  static const Color leftBubbleDefault = Colors.blue;
  static final Color leftBubbleUnknown = Colors.grey.shade400.withOpacity(0.3);

  // (오른쪽, 나)
  static const Color rightBubbleDefault = Colors.white;
  static final Color rightBubbleUnknown = Colors.grey.shade300;

  // -------------------------
  // 2) 감정(Emotion)별 강조 색상
  // -------------------------
  static final Color emotionAnxiety = const Color.fromARGB(255, 207, 195, 88)
      .withOpacity(0.5); // 노란-ish 색 + 투명도
  static final Color emotionAngry = Colors.red.withOpacity(0.5);

  // (필요하다면 추가 감정)
  // static final Color emotionHappy = Colors.green.withOpacity(0.5);
  // static final Color emotionSad = Colors.blue.withOpacity(0.5);

  // -------------------------
  // 3) 아바타 / 아이콘 색상
  // -------------------------
  // 왼쪽(another) 기본
  static final Color leftAvatarDefault = Colors.blue;
  static final Color leftAvatarUnknown = Colors.grey.withOpacity(0.5);

  // 오른쪽(나) 아이콘 (기본 보라색)
  static final Color rightCircleDefault = Colors.purple;
  static final Color rightCircleUnknown = Colors.grey;

  // -------------------------
  // 4) 기타 버튼/배경색 등
  // -------------------------
  static const Color greyColor3 = Color(0xFFE0E4EB); // 예시 버튼 배경
}
