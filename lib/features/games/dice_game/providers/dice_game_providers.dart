import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/dice_game_models.dart';
import '../repositories/dice_game_repository.dart';

// ── Singleton repository ─────────────────────────────────────────────────────
final diceRepoProvider = Provider<DiceGameRepository>((_) => DiceGameRepository());

// ── Panel visibility ─────────────────────────────────────────────────────────
final diceGameVisibleProvider = StateProvider<bool>((_) => false);
final diceGameRoomIdProvider  = StateProvider<String>((_) => '');

// ── Selected chip denomination ───────────────────────────────────────────────
final diceChipProvider = StateProvider<int>((_) => 100);

// ── Current round stream ─────────────────────────────────────────────────────
final diceRoundProvider = StreamProvider.family<DiceRound?, String>((ref, roomId) {
  return ref.read(diceRepoProvider).watchRound(roomId);
});

// ── My bet stream ────────────────────────────────────────────────────────────
final diceMyBetProvider = StreamProvider.family<DiceBet?, String>((ref, roomId) {
  return ref.read(diceRepoProvider).watchMyBet(roomId);
});

// ── Top players stream ───────────────────────────────────────────────────────
final diceTopPlayersProvider = StreamProvider.family<List<DiceTopPlayer>, String>(
  (ref, roomId) => ref.read(diceRepoProvider).watchTopPlayers(roomId),
);

// ── Countdown + phase-transition orchestrator ────────────────────────────────
//
// This notifier is the single point responsible for:
//   1. Ticking the betting countdown
//   2. Triggering requestRoll()       when betting timer hits 0
//   3. Triggering transitionToResult() after _rollingMs ms
//   4. Triggering startNextRound()    after _resultMs ms
//
// Firestore transactions inside each repo method are idempotent, so multiple
// clients calling them simultaneously is safe — only the first succeeds.
//
final diceCountdownProvider = StateNotifierProvider.family<_CountdownNotifier, int, String>(
  (ref, roomId) => _CountdownNotifier(ref, roomId),
);

const _rollingMs = 3000;
const _resultMs  = 3000;

class _CountdownNotifier extends StateNotifier<int> {
  _CountdownNotifier(this._ref, this._roomId) : super(16) {
    _sub = _ref.listen(
      diceRoundProvider(_roomId),
      (_, next) => _onRound(next.valueOrNull),
      fireImmediately: true,
    );
  }

  final Ref    _ref;
  final String _roomId;

  Timer?              _timer;
  ProviderSubscription? _sub;
  DiceRound?          _lastRound;
  bool                _disposed = false;

  // Track which round we already scheduled each phase-transition for,
  // so we never schedule twice for the same round.
  int? _rollingScheduledFor;
  int? _resultScheduledFor;

  void _onRound(DiceRound? round) {
    if (round == null || _disposed) return;

    // New round → reset scheduled flags
    if (_lastRound != null && round.roundId != _lastRound!.roundId) {
      _rollingScheduledFor = null;
      _resultScheduledFor  = null;
    }
    _lastRound = round;

    switch (round.phase) {
      case DiceRoundPhase.betting:
        final rem = round.secsRemaining();
        state = rem;
        if (rem <= 0) {
          _timer?.cancel();
          _timer = null;
          _ref.read(diceRepoProvider).requestRoll(_roomId);
        } else {
          _startTick(round);
        }

      case DiceRoundPhase.rolling:
        _timer?.cancel();
        _timer = null;   // must null so _startTick creates a fresh timer next round
        state = 0;
        _scheduleTransitionToResult(round);

      case DiceRoundPhase.result:
        _timer?.cancel();
        _timer = null;   // same
        state = 0;
        _scheduleNextRound(round);
    }
  }

  // ── Betting tick ──────────────────────────────────────────────────────────
  void _startTick(DiceRound round) {
    // Guard: only skip restart if the timer is ACTIVELY running for this same round.
    // Compare by roundId — bettingEndsAt comparison is trivially true since
    // _lastRound is already set to `round` before _startTick is called.
    final alreadyRunning = (_timer?.isActive ?? false) &&
        _lastRound?.roundId == round.roundId;
    if (alreadyRunning) return;
    _timer?.cancel();
    _timer = null;
    _lastRound = round;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_disposed) { _timer?.cancel(); _timer = null; return; }
      final r = _lastRound;
      if (r == null || r.phase != DiceRoundPhase.betting) {
        _timer?.cancel();
        _timer = null;
        return;
      }
      final rem = r.secsRemaining();
      state = rem;
      if (rem <= 0) {
        _timer?.cancel();
        _timer = null;
        _ref.read(diceRepoProvider).requestRoll(_roomId);
      }
    });
  }

  // ── Schedule rolling → result ─────────────────────────────────────────────
  void _scheduleTransitionToResult(DiceRound round) {
    if (_rollingScheduledFor == round.roundId) return;
    _rollingScheduledFor = round.roundId;

    // Derive delay from server timestamp if available, else use full duration
    int delayMs = _rollingMs;
    if (round.rollingStartedAt != null) {
      final elapsed = DateTime.now().difference(round.rollingStartedAt!).inMilliseconds;
      delayMs = (_rollingMs - elapsed).clamp(0, _rollingMs);
    }

    Future.delayed(Duration(milliseconds: delayMs), () {
      if (_disposed) return;
      _ref.read(diceRepoProvider).transitionToResult(_roomId);
    });
  }

  // ── Schedule result → next round ──────────────────────────────────────────
  void _scheduleNextRound(DiceRound round) {
    if (_resultScheduledFor == round.roundId) return;
    _resultScheduledFor = round.roundId;

    // Derive delay from server timestamp if available
    int delayMs = _resultMs;
    if (round.resultAt != null) {
      final elapsed = DateTime.now().difference(round.resultAt!).inMilliseconds;
      delayMs = (_resultMs - elapsed).clamp(0, _resultMs);
    }

    Future.delayed(Duration(milliseconds: delayMs), () {
      if (_disposed) return;
      _ref.read(diceRepoProvider).startNextRound(_roomId);
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _sub?.close();
    super.dispose();
  }
}

// ── Previous round bets (for repeat-bet) ─────────────────────────────────────
final dicePreviousBetProvider = StateProvider<DiceBet?>((_) => null);

// ── User's live coin balance ──────────────────────────────────────────────────
final diceUserCoinsProvider = StreamProvider<int>((ref) {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return Stream.value(0);
  return FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .snapshots()
      .map((s) => (s.data()?['coins'] as num?)?.toInt() ?? 0);
});
