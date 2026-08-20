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

  const GsState({
    required this.phase, required this.roundId,
    required this.phaseStartAt, required this.winnerIndex, required this.topWinners,
  });

  factory GsState.fromMap(Map<String, dynamic> d) {
    DateTime startAt = DateTime.now();
    final ts = d['phaseStartAt'];
    if (ts is Timestamp) startAt = ts.toDate();
    final winners = (d['topWinners'] as List<dynamic>?)
        ?.map((w) => WinnerInfo.fromMap(w as Map<String, dynamic>)).toList() ?? [];
    return GsState(
      phase: d['phase'] as String? ?? 'betting',
      roundId: (d['roundId'] as num?)?.toInt() ?? 1217,
      phaseStartAt: startAt,
      winnerIndex: (d['winnerIndex'] as num?)?.toInt(),
      topWinners: winners,
    );
  }

  int secsRemainingFor(int duration) {
    final elapsed = DateTime.now().difference(phaseStartAt).inSeconds;
    return (duration - elapsed).clamp(0, duration);
  }
}

class MyBet {
  final int foodIndex, amount;
  final bool paid;
  const MyBet({required this.foodIndex, required this.amount, required this.paid});

  factory MyBet.fromMap(Map<String, dynamic> d) => MyBet(
    foodIndex: (d['foodIndex'] as num).toInt(),
    amount: (d['amount'] as num).toInt(),
    paid: d['paid'] as bool? ?? false,
  );
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
    // Compute top winners from bets
    List<Map<String, dynamic>> top = [];
    try {
      final betsSnap = await _bets(roundId).get();
      final mult = multipliers[winnerIndex];
      for (final doc in betsSnap.docs) {
        final data = doc.data() as Map<String, dynamic>;
        if ((data['foodIndex'] as num).toInt() != winnerIndex) continue;
        final amount = (data['amount'] as num).toInt() * mult;
        final userSnap = await _db.collection('users').doc(doc.id).get();
        final ud = userSnap.data();
        top.add({
          'userId': doc.id,
          'userName': ud?['name'] ?? ud?['username'] ?? 'مجهول',
          'avatar': ud?['avatar'],
          'amount': amount,
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
        t.update(_game, {
          'phase': 'betting', 'roundId': roundId + 1,
          'phaseStartAt': FieldValue.serverTimestamp(),
          'winnerIndex': null, 'topWinners': [],
        });
        done = true;
      });
    } catch (_) {}
    return done;
  }

  // ── Bet ───────────────────────────────────────────────────────────

  Future<String?> placeBet({
    required int roundId, required int foodIndex, required int amount,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return 'يجب تسجيل الدخول';

    // Check no existing bet
    final existing = await _bets(roundId).doc(uid).get();
    if (existing.exists) return 'لقد رهنت في هذه الجولة بالفعل';

    final ok = await _wallet.deductCoins(uid, amount, 'رهان Greedy Star جولة $roundId');
    if (!ok) return 'رصيدك من العملات غير كافٍ';

    try {
      await _bets(roundId).doc(uid).set({
        'foodIndex': foodIndex,
        'amount': amount,
        'placedAt': FieldValue.serverTimestamp(),
        'paid': false,
      });
      return null;
    } catch (e) {
      await _wallet.addCoins(uid, amount, 'استرداد رهان Greedy Star');
      return 'فشل تسجيل الرهان، حاول مرة أخرى';
    }
  }

  // ── Claim payout ──────────────────────────────────────────────────

  Future<int> claimPayout(int roundId, int winnerIndex) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return 0;
    int claimed = 0;
    try {
      await _db.runTransaction((t) async {
        final betRef = _bets(roundId).doc(uid);
        final snap = await t.get(betRef);
        if (!snap.exists) return;
        final data = snap.data() as Map<String, dynamic>;
        if (data['paid'] == true) return;
        if ((data['foodIndex'] as num).toInt() != winnerIndex) return;
        final mult = multipliers[winnerIndex];
        claimed = (data['amount'] as num).toInt() * mult;
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
