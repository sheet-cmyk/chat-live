import 'package:flutter/material.dart';

// 7 ألوان اسم/كتابة متاحة للمستخدم
const kChatColors = <(String hex, String label)>[
  ('FFFFFF', 'أبيض'),
  ('FF2D55', 'وردي'),
  ('FFD700', 'ذهبي'),
  ('C0C0C0', 'فضي'),
  ('3498DB', 'أزرق'),
  ('2ECC71', 'أخضر'),
  ('9B59B6', 'بنفسجي'),
];

// مستويات إرسال الهدايا (7 مستويات)
const kGiftSendLevels = <(int minDiamonds, String label, String emoji, Color color)>[
  (0,        'مبتدئ',   '🥉', Color(0xFFCD7F32)),
  (10000,    'فضي',     '🥈', Color(0xFFC0C0C0)),
  (100000,   'ذهبي',    '🥇', Color(0xFFFFD700)),
  (500000,   'ماسي',    '💎', Color(0xFF4CF0FF)),
  (1000000,  'بلاتيني', '🏅', Color(0xFFE5E4E2)),
  (5000000,  'روبي',    '♦️', Color(0xFF9B59B6)),
  (20000000, 'تاج',     '👑', Color(0xFFFF2D55)),
];

// مستويات الغرفة (7 مستويات بناءً على إجمالي الهدايا الواردة)
const kRoomLevels = kGiftSendLevels;

Color hexColor(String? hex) {
  if (hex == null || hex.isEmpty) return Colors.white;
  try {
    final clean = hex.replaceAll('#', '').toUpperCase().padLeft(6, '0');
    return Color(int.parse('FF$clean', radix: 16));
  } catch (_) {
    return Colors.white;
  }
}

int giftSendLevelIndex(int totalSent) {
  for (int i = kGiftSendLevels.length - 1; i >= 0; i--) {
    if (totalSent >= kGiftSendLevels[i].$1) return i;
  }
  return 0;
}

// تنسيق الأرقام الكبيرة
String fmtDiamonds(int n) {
  if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1).replaceAll('.0', '')}M';
  if (n >= 1000)    return '${(n / 1000).toStringAsFixed(1).replaceAll('.0', '')}K';
  return '$n';
}
