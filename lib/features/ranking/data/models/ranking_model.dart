import 'package:cloud_firestore/cloud_firestore.dart';

enum RankingType { richest, hostStar, gifter, rising }

class RankingEntry {
  final String userId;
  final String userName;
  final String? userAvatar;
  final int score;
  final int rank;
  final int level;
  final int vipLevel;
  final RankingType type;

  const RankingEntry({
    required this.userId,
    required this.userName,
    this.userAvatar,
    required this.score,
    required this.rank,
    this.level = 1,
    this.vipLevel = 0,
    required this.type,
  });

  factory RankingEntry.fromFirestore(DocumentSnapshot doc, int rank, RankingType type) {
    final d = doc.data() as Map<String, dynamic>;
    return RankingEntry(
      userId: doc.id,
      userName: d['displayName'] ?? 'مستخدم',
      userAvatar: d['photoURL'],
      score: _scoreFor(d, type),
      rank: rank,
      level: (d['level'] as num?)?.toInt() ?? 1,
      vipLevel: (d['vipLevel'] as num?)?.toInt() ?? 0,
      type: type,
    );
  }

  static int _scoreFor(Map<String, dynamic> d, RankingType type) {
    switch (type) {
      case RankingType.richest:  return (d['coins'] as num?)?.toInt() ?? 0;
      case RankingType.gifter:   return (d['totalGiftsSent'] as num?)?.toInt() ?? 0;
      case RankingType.hostStar: return (d['totalRoomTime'] as num?)?.toInt() ?? 0;
      case RankingType.rising:   return (d['exp'] as num?)?.toInt() ?? 0;
    }
  }

  String get scoreLabel {
    switch (type) {
      case RankingType.richest:  return '$score 🪙';
      case RankingType.gifter:   return '$score 🎁';
      case RankingType.hostStar: return '${(score / 60).round()} دقيقة';
      case RankingType.rising:   return '$score XP';
    }
  }
}
