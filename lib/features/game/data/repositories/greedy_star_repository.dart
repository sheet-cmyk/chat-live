import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../wallet/data/repositories/wallet_repository.dart';

// ── Models ────────────────────────────────────────────────────────────────────

class WinnerInfo {
  final String userId, userName;
  final String? avatar;
  final int amount;
  const WinnerInfo({required this.userId, required this.userName, this.avatar, required this.amount});

  factory WinnerInfo.fromMap(Map<String, dynamic> m) => WinnerInfo(
    userId: m['userId'] as String? ?? '',
    userName: m['userName'] as String? ?? 'مجهول',
    avatar: m['avatar'] as String?,
    amount: (m['amount'] as num?)?.toInt() ?? 0,
  );

  Map<String, dynamic> toMap() => {
    'userId': userId, 'userName': userName, 'avatar': avatar, 'amount': amount,
  };
}

class GsState {
  final String phase;
  final int roundId;
  final DateTime phaseStartAt;
  final int? winnerIndex;
  final List<WinnerInfo> topWinners;
  final List<int> lastWinners; // food indices of last 20 winners (oldest first)

  const GsState({
    required this.phase, required this.roundId,
    required this.phaseStartAt, required this.winnerIndex,
    required this.topWinners, required this.lastWinners,
  });

  factory GsState.fromMap(Map<String, dynamic> d) {
    DateTime startAt = DateTime.now();
    final ts = d['phaseStartAt'];
    if (ts is Timestamp) startAt = ts.toDate();
    final winners = (d['topWinners'] as List<dynamic>?)
        ?.map((w) => WinnerInfo.fromMap(w as Map<String, dynamic>)).toList() ?? [];
    final lastWinners = (d['lastWinners'] as List<dynamic>?)
        ?.map((w) => (w as num).toInt()).toList() ?? [];
    return GsState(
      phase: d['phase'] as String? ?? 'betting',
      roundId: (d['roundId'] as num?)?.toInt() ?? 1217,
      phaseStartAt: startAt,
      winnerIndex: (d['winnerIndex'] as num?)?.toInt(),
      topWinners: winners,
      lastWinners: lastWinners,
    );
  }

  int secsRemainingFor(int duration) {
    final elapsed = DateTime.now().difference(phaseStartAt).inSeconds;
    return (duration - elapsed).clamp(0, duration);
  }
}

// Represents one food entry in a user's multi-bet
class BetItem {
  final int foodIndex, amount;
  const BetItem({required this.foodIndex, required this.amount});

  factory BetItem.fromMap(Map<String, dynamic> d) => BetItem(
    foodIndex: (d['foodIndex'] as num).toInt(),
    amount: (d['amount'] as num).toInt(),
  );

  Map<String, dynamic> toMap() => {'foodIndex': foodIndex, 'amount': amount};
}

// A user's full bet for one round (can have up to 6 food items)
class MyBet {
  final List<BetItem> items;   // each food → its amount
  final int totalAmount;
  final bool paid;

  const MyBet({required this.items, required this.totalAmount, required this.paid});

  factory MyBet.fromMap(Map<String, dynamic> d) {
    // New map format: {f0: 5000, f3: 10000, totalAmount: ..., paid: ...}
    final mapItems = <BetItem>[];
    for (final e in d.entries) {
      if (e.key.length >= 2 && e.key.startsWith('f')) {
        final fi = int.tryParse(e.key.substring(1));
        if (fi != null && fi >= 0 && fi < 8) {
          final amt = (e.value as num?)?.toInt() ?? 0;
          if (amt > 0) mapItems.add(BetItem(foodIndex: fi, amount: amt));
        }
      }
    }
    if (mapItems.isNotEmpty) {
      return MyBet(
        items: mapItems,
        totalAmount: (d['totalAmount'] as num?)?.toInt() ?? mapItems.fold(0, (s, i) => s + i.amount),
        paid: d['paid'] as bool? ?? false,
      );
    }
    // Old array format
    if (d.containsKey('items')) {
      final items = (d['items'] as List<dynamic>)
          .map((i) => BetItem.fromMap(i as Map<String, dynamic>)).toList();
      return MyBet(
        items: items,
        totalAmount: (d['totalAmount'] as num?)?.toInt() ?? items.fold(0, (s, i) => s + i.amount),
        paid: d['paid'] as bool? ?? false,
      );
    }
    // Legacy single-bet
    final fi = (d['foodIndex'] as num?)?.toInt() ?? 0;
    final amt = (d['amount'] as num?)?.toInt() ?? 0;
    return MyBet(
      items: [BetItem(foodIndex: fi, amount: amt)],
      totalAmount: amt,
      paid: d['paid'] as bool? ?? false,
    );
  }

  // Returns amount bet on a specific food
  int amountFor(int foodIndex) {
    for (final item in items) {
      if (item.foodIndex == foodIndex) return item.amount;
    }
    return 0;
  }

  // Returns true if user bet on this food
  bool hasBetOn(int foodIndex) => items.any((i) => i.foodIndex == foodIndex);
}

// ── Repository ────────────────────────────────────────────────────────────────

class GreedyStarRepository {
  static const probs = <int>[15, 14, 15, 12, 15, 9, 15, 5];
  static const multipliers = <int>[5, 10, 5, 15, 5, 25, 5, 45];

  final _db = FirebaseFirestore.instance;
  final _wallet = WalletRepository();

  DocumentReference get _game => _db.doc('games/greedy_star');
  CollectionReference _bets(int roundId) =>
      _game.collection('rounds').doc('$roundId').collection('bets');

  // ── Streams ───────────────────────────────────────────────────────

  Stream<GsState?> watchState() => _game.snapshots().map((s) {
    if (!s.exists) return null;
    return GsState.fromMap(s.data() as Map<String, dynamic>);
  });

  Stream<MyBet?> watchMyBet(int roundId) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const Stream.empty();
    return _bets(roundId).doc(uid).snapshots().map((s) {
      if (!s.exists) return null;
      return MyBet.fromMap(s.data() as Map<String, dynamic>);
    });
  }

  Stream<QuerySnapshot> watchBets(int roundId) => _bets(roundId).snapshots();

  // ── Init ──────────────────────────────────────────────────────────

  Future<void> ensureGame() async {
    try {
      final snap = await _game.get();
      if (!snap.exists) {
        await _game.set({
          'phase': 'betting',
          'roundId': 1217,
          'phaseStartAt': FieldValue.serverTimestamp(),
          'winnerIndex': null,
          'topWinners': [],
        });
      }
    } catch (_) {}
  }

  // ── Phase transitions ─────────────────────────────────────────────

  Future<int?> tryTransitionToSpinning(int roundId) async {
    int? winner;
    try {
      await _db.runTransaction((t) async {
        final snap = await t.get(_game);
        if (!snap.exists) return;
        final d = snap.data() as Map<String, dynamic>;
        if (d['phase'] != 'betting' || (d['roundId'] as num).toInt() != roundId) return;
        winner = _pickWinner();
        t.update(_game, {
          'phase': 'spinning', 'winnerIndex': winner,
          'phaseStartAt': FieldValue.serverTimestamp(),
        });
      });
    } catch (_) {}
    return winner;
  }

  Future<bool> tryTransitionToResult(int roundId, int winnerIndex) async {
    // Compute top winners from multi-item bets
    List<Map<String, dynamic>> top = [];
    try {
      final betsSnap = await _bets(roundId).get();
      final mult = multipliers[winnerIndex];
      for (final doc in betsSnap.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final bet = MyBet.fromMap(data);
        final winAmt = bet.amountFor(winnerIndex) * mult;
        if (winAmt <= 0) continue;
        final userSnap = await _db.collection('users').doc(doc.id).get();
        final ud = userSnap.data();
        top.add({
          'userId': doc.id,
          'userName': ud?['name'] ?? ud?['username'] ?? 'مجهول',
          'avatar': ud?['avatar'],
          'amount': winAmt,
        });
      }
      top.sort((a, b) => (b['amount'] as int).compareTo(a['amount'] as int));
    } catch (_) {}

    bool done = false;
    try {
      await _db.runTransaction((t) async {
        final snap = await t.get(_game);
        if (!snap.exists) return;
        final d = snap.data() as Map<String, dynamic>;
        if (d['phase'] != 'spinning' || (d['roundId'] as num).toInt() != roundId) return;
        t.update(_game, {
          'phase': 'result',
          'phaseStartAt': FieldValue.serverTimestamp(),
          'topWinners': top.take(3).toList(),
        });
        done = true;
      });
    } catch (_) {}
    return done;
  }

  Future<bool> tryStartNextRound(int roundId) async {
    bool done = false;
    try {
      await _db.runTransaction((t) async {
        final snap = await t.get(_game);
        if (!snap.exists) return;
        final d = snap.data() as Map<String, dynamic>;
        if (d['phase'] != 'result' || (d['roundId'] as num).toInt() != roundId) return;

        // Append winner to lastWinners (keep last 20)
        final winner = (d['winnerIndex'] as num?)?.toInt();
        final prev = List<dynamic>.from(d['lastWinners'] as List? ?? []);
        if (winner != null) prev.add(winner);
        final trimmed = prev.length > 20 ? prev.sublist(prev.length - 20) : prev;

        t.update(_game, {
          'phase': 'betting', 'roundId': roundId + 1,
          'phaseStartAt': FieldValue.serverTimestamp(),
          'winnerIndex': null, 'topWinners': [],
          'lastWinners': trimmed,
        });
        done = true;
      });
    } catch (_) {}
    return done;
  }

  // ── Place multi-bet ───────────────────────────────────────────────

  // bets: foodIndex → amount (1–6 entries, each amount > 0)
  Future<String?> placeMultiBet({
    required int roundId,
    required Map<int, int> bets,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return 'يجب تسجيل الدخول';
    if (bets.isEmpty) return 'اختر طعاماً واحداً على الأقل';

    final validBets = Map.fromEntries(bets.entries.where((e) => e.value > 0));
    if (validBets.isEmpty) return 'أضف مبلغاً للرهان';

    final total = validBets.values.fold(0, (s, v) => s + v);

    // Check no existing bet
    final existing = await _bets(roundId).doc(uid).get();
    if (existing.exists) return 'رهنت بالفعل في هذه الجولة';

    // Deduct total from wallet
    final ok = await _wallet.deductCoins(uid, total, 'رهان Greedy Star جولة $roundId');
    if (!ok) return 'رصيدك من العملات غير كافٍ';

    // Write multi-bet doc
    final items = validBets.entries
        .map((e) => {'foodIndex': e.key, 'amount': e.value})
        .toList();
    try {
      await _bets(roundId).doc(uid).set({
        'items': items,
        'totalAmount': total,
        'placedAt': FieldValue.serverTimestamp(),
        'paid': false,
      });
      return null;
    } catch (e) {
      // Refund on Firestore write failure
      await _wallet.addCoins(uid, total, 'استرداد رهان Greedy Star');
      return 'فشل تسجيل الرهان، حاول مرة أخرى';
    }
  }

  // ── Immediate tap-bet (no confirm) ───────────────────────────────
  // Each tap deducts amount and upserts into the bet doc using map keys (f0..f7)

  Future<String?> tapBet({
    required int roundId,
    required int foodIndex,
    required int amount,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return 'يجب تسجيل الدخول';

    final ok = await _wallet.deductCoins(uid, amount, 'رهان Greedy Star جولة $roundId');
    if (!ok) return 'رصيدك غير كافٍ';

    try {
      await _bets(roundId).doc(uid).set({
        'f$foodIndex': FieldValue.increment(amount),
        'totalAmount': FieldValue.increment(amount),
        'paid': false,
        'placedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      return null;
    } catch (e) {
      await _wallet.addCoins(uid, amount, 'استرداد رهان Greedy Star جولة $roundId');
      return 'فشل التسجيل، حاول مرة أخرى';
    }
  }

  // ── Claim payout (handles multi-item bets) ────────────────────────

  Future<int> claimPayout(int roundId, int winnerIndex) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return 0;
    final mult = multipliers[winnerIndex];
    int claimed = 0;
    try {
      await _db.runTransaction((t) async {
        final betRef = _bets(roundId).doc(uid);
        final snap = await t.get(betRef);
        if (!snap.exists) return;
        final data = snap.data() as Map<String, dynamic>;
        if (data['paid'] == true) return;

        final bet = MyBet.fromMap(data);
        final winningAmt = bet.amountFor(winnerIndex);
        if (winningAmt <= 0) return;

        claimed = winningAmt * mult;
        t.update(_db.collection('users').doc(uid), {'coins': FieldValue.increment(claimed)});
        t.update(betRef, {'paid': true, 'winAmount': claimed});
      });
    } catch (_) {}
    return claimed;
  }

  int _pickWinner() {
    final r = Random().nextInt(100);
    int c = 0;
    for (int i = 0; i < probs.length; i++) {
      c += probs[i];
      if (r < c) return i;
    }
    return 0;
  }
}
