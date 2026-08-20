import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/ranking_model.dart';

class RankingRepository {
  final _db = FirebaseFirestore.instance;

  Future<List<RankingEntry>> fetchRanking(RankingType type, {int limit = 50}) async {
    final field = _fieldFor(type);
    try {
      final snap = await _db
          .collection('users')
          .orderBy(field, descending: true)
          .limit(limit)
          .get();
      return snap.docs.asMap().entries
          .map((e) => RankingEntry.fromFirestore(e.value, e.key + 1, type))
          .toList();
    } catch (_) {
      return [];
    }
  }

  String _fieldFor(RankingType type) {
    switch (type) {
      case RankingType.richest:  return 'coins';
      case RankingType.gifter:   return 'totalGiftsSent';
      case RankingType.hostStar: return 'totalRoomTime';
      case RankingType.rising:   return 'exp';
    }
  }
}
