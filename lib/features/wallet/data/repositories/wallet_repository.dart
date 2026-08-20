import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/transaction_model.dart';

class WalletRepository {
  final _db = FirebaseFirestore.instance;

  Future<Map<String, int>> getBalance(String userId) async {
    final doc = await _db.collection('users').doc(userId).get();
    if (!doc.exists) return {'coins': 0, 'diamonds': 0};
    final d = doc.data()!;
    return {
      'coins': (d['coins'] as num?)?.toInt() ?? 0,
      'diamonds': (d['diamonds'] as num?)?.toInt() ?? 0,
    };
  }

  Stream<Map<String, int>> watchBalance(String userId) {
    return _db.collection('users').doc(userId).snapshots().map((doc) {
      if (!doc.exists) return {'coins': 0, 'diamonds': 0};
      final d = doc.data()!;
      return {
        'coins': (d['coins'] as num?)?.toInt() ?? 0,
        'diamonds': (d['diamonds'] as num?)?.toInt() ?? 0,
      };
    });
  }

  Future<bool> deductCoins(String userId, int amount, String reason) async {
    try {
      return await _db.runTransaction((tx) async {
        final ref = _db.collection('users').doc(userId);
        final snap = await tx.get(ref);
        final current = (snap.data()?['coins'] as num?)?.toInt() ?? 0;
        if (current < amount) return false;
        tx.update(ref, {'coins': FieldValue.increment(-amount)});
        tx.set(
          _db.collection('transactions').doc(),
          TransactionModel(
            id: '', userId: userId,
            type: TransactionType.giftSent,
            coinsChange: -amount, diamondsChange: 0,
            description: reason,
            createdAt: DateTime.now(),
          ).toFirestore(),
        );
        return true;
      });
    } catch (e) {
      debugPrint('[Wallet] deductCoins error: $e');
      return false;
    }
  }

  Future<void> addDiamonds(String userId, int amount, String reason) async {
    try {
      await _db.runTransaction((tx) async {
        final ref = _db.collection('users').doc(userId);
        tx.update(ref, {'diamonds': FieldValue.increment(amount)});
        tx.set(
          _db.collection('transactions').doc(),
          TransactionModel(
            id: '', userId: userId,
            type: TransactionType.giftReceived,
            coinsChange: 0, diamondsChange: amount,
            description: reason,
            createdAt: DateTime.now(),
          ).toFirestore(),
        );
      });
    } catch (e) {
      debugPrint('[Wallet] addDiamonds error: $e');
    }
  }

  Future<void> addCoins(String userId, int amount, String description) async {
    try {
      await _db.runTransaction((tx) async {
        final ref = _db.collection('users').doc(userId);
        tx.update(ref, {'coins': FieldValue.increment(amount)});
        tx.set(
          _db.collection('transactions').doc(),
          TransactionModel(
            id: '',
            userId: userId,
            type: TransactionType.reward,
            coinsChange: amount,
            diamondsChange: 0,
            description: description,
            createdAt: DateTime.now(),
          ).toFirestore(),
        );
      });
    } catch (e) {
      debugPrint('[Wallet] addCoins error: $e');
    }
  }

  /// يُعطي 500,000 عملة مرحباً لأي مستخدم لم يستلمها بعد (مستخدمون قدامى)
  Future<void> ensureWelcomeBonus(String userId) async {
    try {
      await _db.runTransaction((tx) async {
        final ref = _db.collection('users').doc(userId);
        final snap = await tx.get(ref);
        if (!snap.exists) return;
        if (snap.data()!['welcomeBonusClaimed'] == true) return;

        tx.update(ref, {
          'coins': FieldValue.increment(500000),
          'welcomeBonusClaimed': true,
        });
        tx.set(
          _db.collection('transactions').doc(),
          {
            'userId': userId,
            'type': 'reward',
            'coinsChange': 500000,
            'diamondsChange': 0,
            'description': 'هدية الترحيب 🎁 500,000 عملة',
            'createdAt': FieldValue.serverTimestamp(),
          },
        );
      });
    } catch (e) {
      debugPrint('[Wallet] ensureWelcomeBonus error: $e');
    }
  }

  /// يتحقق ويُعطي 500,000 عملة مجانية مرة واحدة يومياً
  /// يُرجع المبلغ الممنوح أو 0 إن سبق الاستلام اليوم
  Future<int> checkAndClaimDailyFreeCoins(String userId) async {
    try {
      return await _db.runTransaction<int>((tx) async {
        final ref = _db.collection('users').doc(userId);
        final snap = await tx.get(ref);
        if (!snap.exists) return 0;

        final data = snap.data()!;
        final lastTs = data['lastDailyFreeCoins'] as Timestamp?;
        final now = DateTime.now();

        if (lastTs != null) {
          final last = lastTs.toDate();
          final sameDay = last.year == now.year && last.month == now.month && last.day == now.day;
          if (sameDay) return 0;
        }

        const amount = 500000;
        tx.update(ref, {
          'coins': FieldValue.increment(amount),
          'lastDailyFreeCoins': Timestamp.fromDate(now),
        });
        tx.set(
          _db.collection('transactions').doc(),
          {
            'userId': userId,
            'type': 'reward',
            'coinsChange': amount,
            'diamondsChange': 0,
            'description': 'مكافأة يومية مجانية 🎁 500,000 عملة',
            'createdAt': FieldValue.serverTimestamp(),
          },
        );
        return amount;
      });
    } catch (e) {
      debugPrint('[Wallet] dailyFreeCoins error: $e');
      return 0;
    }
  }

  Future<List<TransactionModel>> fetchTransactions(String userId, {int limit = 20}) async {
    final snap = await _db
        .collection('transactions')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();
    return snap.docs.map(TransactionModel.fromFirestore).toList();
  }
}
