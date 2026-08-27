import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/dice_game_models.dart';

class DiceGameRepository {
  static const int _bettingSeconds = 16;
  static const int _rollingSeconds = 3;
  static const int _resultSeconds  = 3;

  final _db   = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  DocumentReference _roundDoc(String roomId) =>
      _db.collection('games').doc('dice').collection(roomId).doc('currentRound');

  CollectionReference _betsCol(String roomId) =>
      _db.collection('games').doc('dice').collection(roomId)
          .doc('currentRound').collection('bets');

  // ── Bootstrap / self-heal ─────────────────────────────────────────────────
  // Heals any stuck phase and creates the first round if needed.
  Future<void> ensureRound(String roomId) async {
    try {
      await _db.runTransaction((tx) async {
        final snap = await tx.get(_roundDoc(roomId));
        final now  = DateTime.now();

        if (!snap.exists) {
          tx.set(_roundDoc(roomId), _newRoundData(roundId: 1, lastResults: [], now: now));
          return;
        }

        final d     = snap.data() as Map<String, dynamic>;
        final phase = d['phase'] as String? ?? 'betting';

        if (phase == 'betting') {
          // Use bettingStartedAt (server timestamp) for accurate expiry check
          final startedAt = (d['bettingStartedAt'] as Timestamp?)?.toDate()
              ?? (d['bettingEndsAt'] as Timestamp?)?.toDate()
                  ?.subtract(const Duration(seconds: _bettingSeconds));
          if (startedAt == null) return;
          final endsAt = startedAt.add(const Duration(seconds: _bettingSeconds));
          if (!now.isAfter(endsAt)) return; // still active
          // Expired → roll
          final roll = _generateRoll();
          tx.update(_roundDoc(roomId), {
            'phase':            'rolling',
            'dice':             roll.$1,
            'total':            roll.$2,
            'winner':           roll.$3,
            'rollingStartedAt': FieldValue.serverTimestamp(),
          });

        } else if (phase == 'rolling') {
          final startedAt = (d['rollingStartedAt'] as Timestamp?)?.toDate();
          if (startedAt == null) {
            // No timestamp yet — add one now and let timer run from here
            tx.update(_roundDoc(roomId), {'rollingStartedAt': FieldValue.serverTimestamp()});
            return;
          }
          if (!now.isAfter(startedAt.add(const Duration(seconds: _rollingSeconds)))) return;
          // Rolling done → result
          tx.update(_roundDoc(roomId), {
            'phase':    'result',
            'resultAt': FieldValue.serverTimestamp(),
          });

        } else if (phase == 'result') {
          final resultAt = (d['resultAt'] as Timestamp?)?.toDate();
          if (resultAt == null) {
            tx.update(_roundDoc(roomId), {'resultAt': FieldValue.serverTimestamp()});
            return;
          }
          if (!now.isAfter(resultAt.add(const Duration(seconds: _resultSeconds)))) return;
          // Result done → new round
          tx.set(_roundDoc(roomId), _buildNextRound(d, now));
        }
      });
    } catch (_) {}
  }

  // ── Streams ──────────────────────────────────────────────────────────────
  Stream<DiceRound?> watchRound(String roomId) =>
      _roundDoc(roomId).snapshots().map((s) {
        if (!s.exists) return null;
        return DiceRound.fromMap(roomId, s.data() as Map<String, dynamic>);
      });

  Stream<DiceBet?> watchMyBet(String roomId) {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return const Stream.empty();
    return _betsCol(roomId).doc(uid).snapshots().map((s) {
      if (!s.exists) return null;
      return DiceBet.fromMap(s.data() as Map<String, dynamic>);
    });
  }

  // ── Place bet ─────────────────────────────────────────────────────────────
  Future<String?> placeBet({
    required String     roomId,
    required DiceBetType type,
    required int        amount,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return 'يجب تسجيل الدخول';
    if (amount <= 0) return 'المبلغ غير صحيح';

    try {
      final userRef  = _db.collection('users').doc(uid);
      final roundRef = _roundDoc(roomId);
      final betRef   = _betsCol(roomId).doc(uid);
      final logRef   = _db.collection('users').doc(uid).collection('transactions').doc();
      String? err;

      await _db.runTransaction((tx) async {
        final roundSnap = await tx.get(roundRef);
        if (!roundSnap.exists) { err = 'الجولة غير موجودة'; return; }
        final rd = roundSnap.data() as Map<String, dynamic>;
        if (rd['phase'] != 'betting') { err = 'انتهى وقت الرهان'; return; }

        // Check expiry using bettingStartedAt (server timestamp) + 20s
        final startedAt = (rd['bettingStartedAt'] as Timestamp?)?.toDate()
            ?? (rd['bettingEndsAt'] as Timestamp?)?.toDate()
                ?.subtract(const Duration(seconds: _bettingSeconds));
        if (startedAt != null &&
            DateTime.now().isAfter(
                startedAt.add(const Duration(seconds: _bettingSeconds)))) {
          err = 'انتهى وقت الرهان';
          return;
        }

        final userSnap = await tx.get(userRef);
        final coins    = (userSnap.data())?['coins'] ?? 0;
        if (coins < amount) { err = 'رصيدك غير كافٍ'; return; }

        // Read existing bet to detect stale data from a previous round
        final betSnap      = await tx.get(betRef);
        final currentRound = (rd['roundId'] as num).toInt();
        final existingRound = betSnap.exists
            ? ((betSnap.data() as Map<String, dynamic>)['roundId'] as num?)?.toInt()
            : null;
        final isSameRound = existingRound == currentRound;

        tx.update(userRef, {'coins': FieldValue.increment(-amount)});
        final cu = _auth.currentUser;

        if (isSameRound) {
          // Same round — accumulate on top of existing bet
          tx.set(betRef, {
            type.key:   FieldValue.increment(amount),
            'total':    FieldValue.increment(amount),
            'paid':     false,
            'placedAt': FieldValue.serverTimestamp(),
            'roundId':  currentRound,
            'userName': cu?.displayName ?? 'مستخدم',
            if (cu?.photoURL != null) 'avatar': cu!.photoURL,
          }, SetOptions(merge: true));
        } else {
          // New round (stale doc) — overwrite completely so old amounts don't bleed through
          tx.set(betRef, {
            type.key:   amount,
            'total':    amount,
            'paid':     false,
            'placedAt': FieldValue.serverTimestamp(),
            'roundId':  currentRound,
            'userName': cu?.displayName ?? 'مستخدم',
            if (cu?.photoURL != null) 'avatar': cu!.photoURL,
          });
        }

        tx.update(roundRef, {'${type.key}Bets': FieldValue.increment(amount)});
        tx.set(logRef, {
          'type':      'bet_dice',
          'amount':    -amount,
          'note':      'رهان ${type.label} جولة $currentRound',
          'createdAt': FieldValue.serverTimestamp(),
        });
      });
      return err;
    } catch (e) {
      return 'خطأ: ${e.toString()}';
    }
  }

  // ── Request roll (called when betting timer hits 0) ───────────────────────
  Future<void> requestRoll(String roomId) async {
    try {
      await _db.runTransaction((tx) async {
        final snap = await tx.get(_roundDoc(roomId));
        if (!snap.exists) return;
        final d = snap.data() as Map<String, dynamic>;
        if (d['phase'] != 'betting') return;
        // Use bettingStartedAt (server timestamp) + 20s for expiry check
        final startedAt = (d['bettingStartedAt'] as Timestamp?)?.toDate()
            ?? (d['bettingEndsAt'] as Timestamp?)?.toDate()
                ?.subtract(const Duration(seconds: _bettingSeconds));
        if (startedAt == null) return;
        final endsAt = startedAt.add(const Duration(seconds: _bettingSeconds));
        if (DateTime.now().isBefore(endsAt.subtract(const Duration(seconds: 2)))) return;

        final roll = _generateRoll();
        tx.update(_roundDoc(roomId), {
          'phase':            'rolling',
          'dice':             roll.$1,
          'total':            roll.$2,
          'winner':           roll.$3,
          'rollingStartedAt': FieldValue.serverTimestamp(),
        });
      });
    } catch (_) {}
  }

  // ── Transition to result (called after rolling animation) ────────────────
  Future<void> transitionToResult(String roomId) async {
    try {
      await _db.runTransaction((tx) async {
        final snap = await tx.get(_roundDoc(roomId));
        if (!snap.exists) return;
        final d = snap.data() as Map<String, dynamic>;
        if (d['phase'] != 'rolling') return;
        tx.update(_roundDoc(roomId), {
          'phase':    'result',
          'resultAt': FieldValue.serverTimestamp(),
        });
      });
    } catch (_) {}
  }

  // ── Start next round ──────────────────────────────────────────────────────
  Future<void> startNextRound(String roomId) async {
    try {
      await _db.runTransaction((tx) async {
        final snap = await tx.get(_roundDoc(roomId));
        if (!snap.exists) return;
        final d = snap.data() as Map<String, dynamic>;
        if (d['phase'] != 'result') return;
        tx.set(_roundDoc(roomId), _buildNextRound(d, DateTime.now()));
      });
      // Clean up old bets (fire-and-forget)
      _betsCol(roomId).get().then((snap) {
        final batch = _db.batch();
        for (final d in snap.docs) { batch.delete(d.reference); }
        batch.commit().catchError((_) {});
      }).catchError((_) {});
    } catch (_) {}
  }

  // ── Claim payout ──────────────────────────────────────────────────────────
  Future<int> claimPayout(String roomId, DiceBetType winner) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return 0;
    int claimed = 0;
    try {
      await _db.runTransaction((tx) async {
        final betRef = _betsCol(roomId).doc(uid);
        final snap   = await tx.get(betRef);
        if (!snap.exists) return;
        final data = snap.data() as Map<String, dynamic>;
        if (data['paid'] == true) return;
        final bet     = DiceBet.fromMap(data);
        final wagered = bet.amountFor(winner);
        if (wagered <= 0) {
          tx.update(betRef, {'paid': true, 'winAmount': 0});
          return;
        }
        claimed = wagered * winner.multiplier;
        tx.update(_db.collection('users').doc(uid), {'coins': FieldValue.increment(claimed)});
        tx.update(betRef, {'paid': true, 'winAmount': claimed});
      });
    } catch (_) {}
    return claimed;
  }

  // ── Top players stream ────────────────────────────────────────────────────
  Stream<List<DiceTopPlayer>> watchTopPlayers(String roomId) {
    return _betsCol(roomId).snapshots().map((snap) {
      final players = <DiceTopPlayer>[];
      for (final doc in snap.docs) {
        final data  = doc.data() as Map<String, dynamic>;
        final total = (data['total'] as num?)?.toInt() ?? 0;
        if (total <= 0) continue;
        players.add(DiceTopPlayer(
          userId:       doc.id,
          userName:     data['userName'] as String? ?? 'مستخدم',
          avatar:       data['avatar'] as String?,
          totalWagered: total,
        ));
      }
      players.sort((a, b) => b.totalWagered.compareTo(a.totalWagered));
      return players.take(5).toList();
    });
  }

  // ── History ────────────────────────────────────────────────────────────────
  Future<List<DiceHistoryEntry>> fetchHistory(String roomId, {int limit = 30}) async {
    try {
      final snap = await _roundDoc(roomId).get();
      if (!snap.exists) return [];
      final d   = snap.data() as Map<String, dynamic>;
      final raw = (d['lastResults'] as List<dynamic>?) ?? [];
      return raw.map((e) => DiceHistoryEntry.fromMap(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
  static (List<int>, int, String) _generateRoll() {
    final rng = Random.secure();
    final d1  = rng.nextInt(6) + 1;
    final d2  = rng.nextInt(6) + 1;
    final d3  = rng.nextInt(6) + 1;
    final t   = d1 + d2 + d3;
    final w   = calcWinner(d1, d2, d3);
    return ([d1, d2, d3], t, w.key);
  }

  static Map<String, dynamic> _newRoundData({
    required int              roundId,
    required List<dynamic>    lastResults,
    required DateTime         now,
  }) {
    final endsAt = now.add(const Duration(seconds: _bettingSeconds));
    return {
      'roundId':          roundId,
      'phase':            'betting',
      'bettingStartedAt': FieldValue.serverTimestamp(),
      'bettingEndsAt':    Timestamp.fromDate(endsAt),
      'dice':             null,
      'total':            null,
      'winner':           null,
      'rollingStartedAt': null,
      'resultAt':         null,
      'smallBets':        0,
      'bigBets':          0,
      'tripleBets':       0,
      'lastResults':      lastResults,
    };
  }

  static Map<String, dynamic> _buildNextRound(Map<String, dynamic> d, DateTime now) {
    final oldId      = (d['roundId'] as num?)?.toInt() ?? 1;
    final oldDice    = (d['dice'] as List?)?.map((e) => (e as num).toInt()).toList() ?? [1,1,1];
    final winner     = d['winner'] as String?;
    final total      = (d['total'] as num?)?.toInt() ?? 3;
    final prev       = List<dynamic>.from(d['lastResults'] as List? ?? []);
    prev.insert(0, {'roundId': oldId, 'dice': oldDice, 'total': total, 'winner': winner});
    return _newRoundData(
      roundId:     oldId + 1,
      lastResults: prev.take(20).toList(),
      now:         now,
    );
  }
}
