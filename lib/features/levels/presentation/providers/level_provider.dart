import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../../data/models/level_model.dart';

export '../../data/models/level_model.dart';

final userExpProvider = StreamProvider<int>((ref) {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return const Stream.empty();
  return FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .snapshots()
      .map((s) => (s.data()?['exp'] as num?)?.toInt() ?? 0);
});

final userLevelProvider = Provider<LevelModel>((ref) {
  final exp = ref.watch(userExpProvider).valueOrNull ?? 0;
  return LevelModel.forExp(exp);
});

final levelProgressProvider = Provider<double>((ref) {
  final exp = ref.watch(userExpProvider).valueOrNull ?? 0;
  return LevelModel.progressToNext(exp);
});

// منح XP للمستخدم
Future<void> grantExp(String userId, int amount) async {
  try {
    await FirebaseFirestore.instance.collection('users').doc(userId).update({
      'exp': FieldValue.increment(amount),
    });
  } catch (e) {
    debugPrint('[Level] grantExp error: $e');
  }
}
