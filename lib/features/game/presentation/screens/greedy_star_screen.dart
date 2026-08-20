import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/greedy_star_repository.dart';
import '../../../wallet/presentation/providers/wallet_provider.dart';

// ── Food metadata ─────────────────────────────────────────────────────────────

class _Food {
  final String name, emoji;
  final int mult;
  final bool hot;
  const _Food(this.name, this.emoji, this.mult, {this.hot = false});
}

const _kFoods = <_Food>[
  _Food('جزر',    '🥕', 5),
  _Food('جمبري',  '🍤', 10),
  _Food('طماطم',  '🍅', 5),
  _Food('دجاج',   '🍗', 15),
  _Food('ذرة',    '🌽', 5),
  _Food('لحم',    '🥩', 25),
  _Food('بروكلي', '🥦', 5),
  _Food('سمك',    '🐟', 45, hot: true),
];

// Preset bet amounts
const _kAmounts = <int>[500, 1000, 5000, 10000, 50000, 100000];

// ── Screen ────────────────────────────────────────────────────────────────────

class GreedyStarScreen extends ConsumerStatefulWidget {
  const GreedyStarScreen({super.key});

  @override
  ConsumerState<GreedyStarScreen> createState() => _GSState();
}

class _GSState extends ConsumerState<GreedyStarScreen> with TickerProviderStateMixin {

  final _repo = GreedyStarRepository();

  StreamSubscription<GsState?>? _stateSub;
  StreamSubscription<MyBet?>? _betSub;
  StreamSubscription<QuerySnapshot<Object?>>? _allBetsSub;

  // Firebase state
  GsState? _state;
  MyBet? _myBet;
  Map<int, int> _betterCounts = {}; // foodIndex → player count

  // Local UI
  String _localPhase = 'loading';
  int _countdown = 30;
  int _resultCountdown = 7;
  int _highlight = -1;

  // Draft bets: foodIndex → accumulated amount
  final Map<int, int> _draft = {};
  int _selectedAmount = 1000; // currently active chip on amount bar

  int _myWinAmount = 0;
  bool _claimDone = false;
  String? _toast;
  bool _isPlacing = false;
  final _records = <Map<String, dynamic>>[];
  int? _trackedRound;

  // Animations
  late AnimationController _starCtrl;
  late Animation<double> _starY;
  late AnimationController _pulseCtrl;
  late Animation<double> _pulse;
  late AnimationController _glowCtrl;
  late Animation<double> _glow;
  late AnimationController _resultCtrl;
  late Animation<Offset> _resultSlide;

  Timer? _t1, _t2;

  // ── Init / dispose ─────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _initAnims();
    _repo.ensureGame();
    _stateSub = _repo.watchState().listen(_onStateUpdate);
  }

  void _initAnims() {
    _starCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _starY = Tween<double>(begin: 0, end: -7)
        .animate(CurvedAnimation(parent: _starCtrl, curve: Curves.easeInOut));

    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 650))
      ..repeat(reverse: true);
    _pulse = Tween<double>(begin: 1.0, end: 1.12)
        .animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    _glowCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 500))
      ..repeat(reverse: true);
    _glow = Tween<double>(begin: 4.0, end: 14.0)
        .animate(CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut));

    _resultCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _resultSlide = Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
        .animate(CurvedAnimation(parent: _resultCtrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _stateSub?.cancel();
    _betSub?.cancel();
    _allBetsSub?.cancel();
    _t1?.cancel();
    _t2?.cancel();
    _starCtrl.dispose();
    _pulseCtrl.dispose();
    _glowCtrl.dispose();
    _resultCtrl.dispose();
    super.dispose();
  }

  // ── Firebase listeners ─────────────────────────────────────────────

  void _onStateUpdate(GsState? state) {
    if (!mounted || state == null) return;

    final prevPhase = _state?.phase;
    final prevRound = _state?.roundId;
    _state = state;

    // New round — reset per-round state
    if (state.roundId != prevRound || _trackedRound != state.roundId) {
      _trackedRound = state.roundId;

      _betSub?.cancel();
      _allBetsSub?.cancel();

      _betSub = _repo.watchMyBet(state.roundId).listen((bet) {
        if (!mounted) return;
        setState(() => _myBet = bet);
      });

      _allBetsSub = _repo.watchBets(state.roundId).listen((snap) {
        if (!mounted) return;
        final counts = <int, int>{};
        for (final doc in snap.docs) {
          final d = doc.data() as Map<String, dynamic>;
          final bet = MyBet.fromMap(d);
          for (final item in bet.items) {
            counts[item.foodIndex] = (counts[item.foodIndex] ?? 0) + 1;
          }
        }
        setState(() => _betterCounts = counts);
      });

      setState(() {
        _myBet = null;
        _myWinAmount = 0;
        _claimDone = false;
        _draft.clear();
        _betterCounts = {};
      });
    }

    final phaseChanged = state.phase != prevPhase || state.roundId != prevRound;
    if (phaseChanged) {
      _handlePhaseChange(state);
    } else {
      if (state.phase == 'betting') {
        final s = state.secsRemainingFor(30);
        if (mounted) setState(() => _countdown = s);
      } else if (state.phase == 'result') {
        final s = state.secsRemainingFor(7);
        if (mounted) setState(() => _resultCountdown = s);
      }
    }
  }

  void _handlePhaseChange(GsState state) {
    _t1?.cancel();
    _t2?.cancel();

    if (state.phase == 'betting') {
      _resultCtrl.reverse();
      setState(() {
        _localPhase = 'betting';
        _highlight = -1;
        _countdown = state.secsRemainingFor(30);
      });
      _t1 = Timer.periodic(const Duration(seconds: 1), (t) {
        if (!mounted) { t.cancel(); return; }
        final rem = _state?.secsRemainingFor(30) ?? 0;
        setState(() => _countdown = rem);
        if (rem <= 0) { t.cancel(); _repo.tryTransitionToSpinning(state.roundId); }
      });
    }

    else if (state.phase == 'spinning') {
      setState(() { _localPhase = 'spinning'; _highlight = 0; });
      _startSpinAnim(state.winnerIndex ?? 0, state.roundId);
    }

    else if (state.phase == 'result') {
      setState(() {
        _localPhase = 'result';
        _highlight = state.winnerIndex ?? -1;
        _resultCountdown = state.secsRemainingFor(7);
      });
      _resultCtrl.forward();
      if (state.winnerIndex != null) _tryAutoClaim(state.roundId, state.winnerIndex!);
      _t1 = Timer.periodic(const Duration(seconds: 1), (t) {
        if (!mounted) { t.cancel(); return; }
        final rem = _state?.secsRemainingFor(7) ?? 0;
        setState(() => _resultCountdown = rem);
        if (rem <= 0) { t.cancel(); _repo.tryStartNextRound(state.roundId); }
      });
    }
  }

  void _startSpinAnim(int winnerIndex, int roundId) {
    int step = 0;
    void tick() {
      if (!mounted) return;
      setState(() => _highlight = step % 8);
      step++;
      int ms;
      if (step < 12) {
        ms = 70;
      } else if (step < 20) {
        ms = 100 + (step - 12) * 25;
      } else {
        ms = 340;
      }
      if (step >= 25) { _landOnWinner(winnerIndex, step, roundId); return; }
      _t2 = Timer(Duration(milliseconds: ms), tick);
    }
    tick();
  }

  void _landOnWinner(int winnerIndex, int step, int roundId) {
    final cur = step % 8;
    int diff = (winnerIndex - cur + 8) % 8;
    if (diff == 0) diff = 8;
    int landed = 0;
    _t2 = Timer.periodic(const Duration(milliseconds: 340), (t) {
      if (!mounted) { t.cancel(); return; }
      landed++;
      setState(() => _highlight = (cur + landed) % 8);
      if (landed >= diff) {
        t.cancel();
        Future.delayed(const Duration(milliseconds: 600), () {
          if (mounted) _repo.tryTransitionToResult(roundId, winnerIndex);
        });
      }
    });
  }

  Future<void> _tryAutoClaim(int roundId, int winnerIndex) async {
    if (_claimDone) return;
    _claimDone = true;
    final won = await _repo.claimPayout(roundId, winnerIndex);
    if (!mounted) return;
    final myBetSnap = _myBet;
    if (won > 0) {
      setState(() => _myWinAmount = won);
      _records.insert(0, {
        'round': roundId, 'food': winnerIndex,
        'bet': myBetSnap?.totalAmount ?? 0, 'win': won,
        'items': myBetSnap?.items.map((i) => {'f': i.foodIndex, 'a': i.amount}).toList() ?? [],
      });
    } else if (myBetSnap != null) {
      _records.insert(0, {
        'round': roundId, 'food': winnerIndex,
        'bet': myBetSnap.totalAmount, 'win': 0,
        'items': myBetSnap.items.map((i) => {'f': i.foodIndex, 'a': i.amount}).toList(),
      });
    }
    if (_records.length > 20) _records.removeLast();
  }

  // ── Draft bet actions ──────────────────────────────────────────────

  // Each tap adds _selectedAmount to that food (cumulative, no undo)
  void _onFoodTap(int fi, int coins) {
    if (_localPhase != 'betting' || _myBet != null) return;
    if (_selectedAmount == 0) { _showToast('اختر مبلغاً من الشريط أولاً'); return; }
    if (!_draft.containsKey(fi) && _draft.length >= 6) {
      _showToast('الحد الأقصى 6 أطعمة مختلفة');
      return;
    }
    final newTotal = _draft.values.fold(0, (s, v) => s + v) + _selectedAmount;
    if (newTotal > coins) { _showToast('رصيدك غير كافٍ 🪙'); return; }
    setState(() => _draft[fi] = (_draft[fi] ?? 0) + _selectedAmount);
  }

  void _onAmountTap(int amt) {
    setState(() => _selectedAmount = amt);
  }

  Future<void> _onBet(int coins) async {
    if (_localPhase != 'betting') { _showToast('انتهى وقت الرهان'); return; }
    if (_myBet != null) { _showToast('رهنت بالفعل في هذه الجولة'); return; }
    if (_draft.isEmpty) { _showToast('اضغط على الأطعمة لإضافة رهانات'); return; }
    final total = _draft.values.fold(0, (s, v) => s + v);
    if (total > coins) { _showToast('رصيدك غير كافٍ — المطلوب ${_fmtNum(total)} 🪙'); return; }

    setState(() => _isPlacing = true);
    final err = await _repo.placeMultiBet(
      roundId: _state!.roundId,
      bets: Map.from(_draft),
    );
    if (!mounted) return;
    setState(() => _isPlacing = false);
    if (err != null) {
      _showToast(err);
    } else {
      setState(() => _draft.clear());
      _showToast('✅ تم تسجيل رهانك!');
    }
  }

  void _showToast(String msg) {
    setState(() => _toast = msg);
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) setState(() => _toast = null);
    });
  }

  // ── BUILD ──────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final coins = ref.watch(coinsProvider);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFF5A623), Color(0xFFE8921A), Color(0xFFD4800F)],
              begin: Alignment.topCenter, end: Alignment.bottomCenter,
            ),
          ),
          child: SafeArea(
            child: Stack(children: [
              const _DotPattern(),
              Column(children: [
                _buildHeader(coins),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const ClampingScrollPhysics(),
                    child: Column(children: [
                      _buildWheelArea(coins),
                      _buildPhaseBar(),
                      _buildAmountBar(),
                      if (_myBet != null) _buildPlacedBetSummary() else _buildBetBar(coins),
                      _buildBottomRow(coins),
                      const SizedBox(height: 8),
                    ]),
                  ),
                ),
              ]),
              if (_localPhase == 'result' && _state != null) _buildResultOverlay(),
              if (_toast != null) _buildToast(),
            ]),
          ),
        ),
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────

  Widget _buildHeader(int coins) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
          child: Row(children: [
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: 32, height: 32,
                decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.black.withAlpha(60)),
                child: const Icon(Icons.close_rounded, color: Colors.white, size: 18),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _showRules,
              child: Stack(clipBehavior: Clip.none, children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFFFFD700), Color(0xFFFFA500)]),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Text('قاعدة', style: TextStyle(color: Colors.brown, fontFamily: 'Cairo', fontWeight: FontWeight.w800, fontSize: 12)),
                ),
                Positioned(top: -3, left: -3,
                  child: Container(width: 7, height: 7, decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFFF3B9A)))),
              ]),
            ),
            Expanded(
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF2ECC71), Color(0xFF27AE60), Color(0xFF1E8449)]),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFDAA520), width: 2),
                  ),
                  child: const Text('Greedy Star ⭐',
                    style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900,
                      shadows: [Shadow(color: Colors.black54, blurRadius: 4, offset: Offset(1, 2))])),
                ),
              ),
            ),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('جولة #${_state?.roundId ?? '-'}',
                style: const TextStyle(color: Colors.white, fontFamily: 'Cairo', fontSize: 10, fontWeight: FontWeight.bold)),
              Text(_localPhase == 'betting' ? 'رهان' : _localPhase == 'spinning' ? 'دوران' : _localPhase == 'result' ? 'نتيجة' : '...',
                style: const TextStyle(color: Colors.white70, fontFamily: 'Cairo', fontSize: 9)),
            ]),
          ]),
        ),
        // ── Balance chip ──────────────────────────────────────────────
        Container(
          margin: const EdgeInsets.fromLTRB(14, 6, 14, 0),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF3A1A00), Color(0xFF5C2E00), Color(0xFF3A1A00)]),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: const Color(0xFFDAA520), width: 2),
            boxShadow: [BoxShadow(color: Colors.black.withAlpha(80), blurRadius: 10, offset: const Offset(0, 3))],
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Text('🪙', style: TextStyle(fontSize: 22)),
            const SizedBox(width: 8),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('رصيدك', style: TextStyle(color: Colors.white54, fontFamily: 'Cairo', fontSize: 10)),
              Text(_fmtNumFull(coins),
                style: const TextStyle(color: Color(0xFFFFD700), fontFamily: 'Cairo', fontWeight: FontWeight.w900, fontSize: 20,
                  shadows: [Shadow(color: Colors.black54, blurRadius: 4)])),
            ]),
            const SizedBox(width: 12),
            Container(width: 1, height: 30, color: const Color(0xFFDAA520).withAlpha(80)),
            const SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('المشتركون', style: TextStyle(color: Colors.white54, fontFamily: 'Cairo', fontSize: 10)),
              Text('${_betterCounts.values.fold(0, (a, b) => a + b)} لاعب',
                style: const TextStyle(color: Colors.white, fontFamily: 'Cairo', fontWeight: FontWeight.w800, fontSize: 14)),
            ]),
          ]),
        ),
      ],
    );
  }

  // ── Wheel ──────────────────────────────────────────────────────────

  Widget _buildWheelArea(int coins) {
    return LayoutBuilder(builder: (ctx, box) {
      final w = box.maxWidth;
      final cx = w / 2;
      const cy = 140.0, r = 105.0, bSize = 63.0, h = 310.0;
      return SizedBox(
        width: w, height: h,
        child: Stack(clipBehavior: Clip.none, children: [
          CustomPaint(size: Size(w, h), painter: _WheelPainter(cx: cx, cy: cy, r: r)),
          for (int i = 0; i < 8; i++) _buildBubble(i, cx, cy, r, bSize, coins),
          _buildCenterStar(cx, cy),
        ]),
      );
    });
  }

  Widget _buildBubble(int i, double cx, double cy, double r, double bSize, int coins) {
    final angle = -pi / 2 + i * pi / 4;
    final bx = cx + r * cos(angle);
    final by = cy + r * sin(angle);
    final food = _kFoods[i];

    final inDraft = _draft.containsKey(i);
    final draftAmt = _draft[i] ?? 0;
    final isMyBet = _myBet?.hasBetOn(i) ?? false;
    final myBetAmt = _myBet?.amountFor(i) ?? 0;
    final isHighlighted = _highlight == i;
    final isWinner = _state?.winnerIndex == i && _localPhase == 'result';
    final betterCount = _betterCounts[i] ?? 0;
    final canBet = _localPhase == 'betting' && _myBet == null;

    Widget bubble = AnimatedBuilder(
      animation: Listenable.merge([_pulseCtrl, _glowCtrl]),
      builder: (_, __) {
        final scale = (inDraft || isMyBet) && _localPhase == 'betting' ? _pulse.value : 1.0;
        final glowR = isHighlighted ? _glow.value : (inDraft ? 8.0 : 0.0);
        return Transform.scale(
          scale: scale,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Stack(clipBehavior: Clip.none, children: [
              Container(
                width: bSize, height: bSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: isHighlighted
                        ? [Colors.white, const Color(0xFFFFE066), const Color(0xFFFF8C00)]
                        : isWinner
                            ? [const Color(0xFFFFFFAA), const Color(0xFFFFD700), const Color(0xFFFF8C00)]
                            : inDraft || isMyBet
                                ? [const Color(0xFFFFE8A0), const Color(0xFFFFB300), const Color(0xFFE07000)]
                                : [const Color(0xFFFFD580), const Color(0xFFFF9500), const Color(0xFFE07000)],
                    center: const Alignment(-0.3, -0.3), radius: 0.85,
                  ),
                  border: Border.all(
                    color: isHighlighted ? Colors.white
                        : isMyBet ? const Color(0xFF27AE60)
                        : inDraft ? const Color(0xFFFFD700)
                        : const Color(0xFFDAA520),
                    width: isHighlighted ? 4 : (isMyBet || inDraft) ? 3.5 : 2.5,
                  ),
                  boxShadow: [BoxShadow(
                    color: isHighlighted ? Colors.white.withAlpha(220)
                        : inDraft ? const Color(0xFFFFD700).withAlpha(160)
                        : Colors.black.withAlpha(55),
                    blurRadius: glowR + 4, spreadRadius: isHighlighted ? 3 : 0,
                  )],
                ),
                child: Stack(children: [
                  // Emoji — shifted up slightly to leave room for multiplier
                  Align(
                    alignment: const Alignment(0, -0.30),
                    child: Text(food.emoji, style: TextStyle(fontSize: bSize * 0.43)),
                  ),
                  // Multiplier INSIDE the circle at the bottom — bold & clear
                  Positioned(
                    bottom: 6, left: 0, right: 0,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: Colors.black.withAlpha(160),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text('×${food.mult}',
                          style: const TextStyle(color: Colors.white, fontSize: 11,
                            fontWeight: FontWeight.w900,
                            shadows: [Shadow(color: Colors.black, blurRadius: 2)])),
                      ),
                    ),
                  ),
                ]),
              ),
              // Betters count
              if (betterCount > 0)
                Positioned(top: -5, right: -5,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(color: Colors.indigo.shade700, borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white, width: 1)),
                    child: Text('$betterCount', style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w900)),
                  )),
              // HOT badge
              if (food.hot)
                Positioned(top: 2, left: -3,
                  child: Transform.rotate(angle: -0.3,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(color: const Color(0xFFFF3B30), borderRadius: BorderRadius.circular(5)),
                      child: const Text('HOT', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w900)),
                    ))),
            ]),
            // Amount below circle — full number (e.g. 10,500) when bet is set
            if ((inDraft && draftAmt > 0) || (isMyBet && myBetAmt > 0))
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: isMyBet ? const Color(0xFF1A6B38) : const Color(0xFF7A3A00),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white, width: 1),
                  ),
                  child: Text(
                    _fmtFull(isMyBet ? myBetAmt : draftAmt),
                    style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900),
                  ),
                ),
              )
            else
              const SizedBox(height: 3),
          ]),
        );
      },
    );

    return Positioned(
      left: bx - bSize / 2,
      top: by - bSize / 2,
      child: GestureDetector(onTap: canBet ? () => _onFoodTap(i, coins) : null, child: bubble),
    );
  }

  Widget _buildCenterStar(double cx, double cy) {
    return Positioned(
      left: cx - 48, top: cy - 62,
      child: SizedBox(
        width: 96,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14),
              boxShadow: [BoxShadow(color: Colors.black.withAlpha(60), blurRadius: 6)]),
            child: Column(children: [
              if (_localPhase == 'betting') ...[
                const Text('حدد الوقت', style: TextStyle(color: Color(0xFF7A4200), fontSize: 9, fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                Text('${_countdown}S', style: const TextStyle(color: Color(0xFFE05000), fontSize: 20, fontWeight: FontWeight.w900)),
              ] else if (_localPhase == 'spinning')
                const Text('دوران...', style: TextStyle(color: Color(0xFF7A4200), fontSize: 11, fontFamily: 'Cairo', fontWeight: FontWeight.w800))
              else if (_localPhase == 'result')
                Text('${_resultCountdown}S', style: const TextStyle(color: Color(0xFFE05000), fontSize: 20, fontWeight: FontWeight.w900))
              else
                const SizedBox(height: 26, child: Center(child: SizedBox(width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFE05000))))),
            ]),
          ),
          const SizedBox(height: 5),
          Container(
            width: 92, height: 76,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(46),
              gradient: const LinearGradient(
                colors: [Color(0xFF2ECC71), Color(0xFF27AE60), Color(0xFF1A7A3A)],
                begin: Alignment.topLeft, end: Alignment.bottomRight,
              ),
              border: Border.all(color: const Color(0xFFDAA520), width: 3),
              boxShadow: [BoxShadow(color: Colors.green.withAlpha(100), blurRadius: 10, spreadRadius: 2)],
            ),
            child: AnimatedBuilder(
              animation: _starY,
              builder: (_, child) => Transform.translate(offset: Offset(0, _starY.value), child: child),
              child: _buildStarChar(),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildStarChar() {
    return SizedBox(
      width: 92, height: 76,
      child: Stack(children: [
        const Center(child: Text('⭐', style: TextStyle(fontSize: 52))),
        Positioned(top: 22, left: 22,
          child: Container(width: 7, height: 3, decoration: BoxDecoration(color: Colors.brown.shade800, borderRadius: BorderRadius.circular(3)))),
        Positioned(top: 21, right: 20,
          child: Container(width: 6, height: 6, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.brown.shade800))),
        Positioned(top: 22, right: 22,
          child: Container(width: 2, height: 2, decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white))),
        Positioned(bottom: 17, left: 0, right: 0,
          child: Center(child: Container(width: 14, height: 7,
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.brown.shade700, width: 2.5),
                left: BorderSide(color: Colors.brown.shade700, width: 2),
                right: BorderSide(color: Colors.brown.shade700, width: 2),
              ),
              borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(7), bottomRight: Radius.circular(7)),
            )))),
        Positioned(top: 28, left: 14,
          child: Container(width: 9, height: 5, decoration: BoxDecoration(color: Colors.pink.withAlpha(90), borderRadius: BorderRadius.circular(5)))),
        Positioned(top: 28, right: 14,
          child: Container(width: 9, height: 5, decoration: BoxDecoration(color: Colors.pink.withAlpha(90), borderRadius: BorderRadius.circular(5)))),
      ]),
    );
  }

  // ── Phase bar ──────────────────────────────────────────────────────

  Widget _buildPhaseBar() {
    String msg;
    if (_localPhase == 'betting') {
      if (_myBet != null) {
        msg = '✅ رهانك مسجّل — ${_myBet!.items.length} طعام، مجموع ${_fmtNum(_myBet!.totalAmount)} 🪙';
      } else if (_draft.isNotEmpty) {
        final total = _draft.values.fold(0, (s, v) => s + v);
        msg = 'رهانك: ${_fmtFull(total)} 🪙 على ${_draft.length} طعام — اضغط "راهن" للتسجيل';
      } else {
        msg = 'اختر المبلغ ← اضغط على الطعام لإضافة الرهان';
      }
    } else if (_localPhase == 'spinning') {
      msg = '🎡 العجلة تدور... انتظر النتيجة';
    } else if (_localPhase == 'result') {
      msg = 'الجولة التالية خلال ${_resultCountdown}s ⏱';
    } else {
      msg = 'يتم تحميل اللعبة...';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 9),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF2ECC71), Color(0xFF27AE60), Color(0xFF1E8449)]),
        boxShadow: [BoxShadow(color: Colors.green.withAlpha(80), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Text(msg, textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.white, fontFamily: 'Cairo', fontWeight: FontWeight.w800, fontSize: 13,
          shadows: [Shadow(color: Colors.black38, blurRadius: 3)])),
    );
  }

  // ── Amount bar — select chip, then tap foods to accumulate ───────────

  Widget _buildAmountBar() {
    final canBet = _localPhase == 'betting' && _myBet == null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [Color(0xFF4A2000), Color(0xFF6B3200), Color(0xFF4A2000)]),
        border: Border(
          top: BorderSide(color: Color(0xFF3A1A00), width: 2),
          bottom: BorderSide(color: Color(0xFF3A1A00), width: 2),
        ),
      ),
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 5),
          child: Text(
            canBet ? 'اختر المبلغ ← اضغط على الطعام (كل ضغطة تُضيف المبلغ)' : '',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white.withAlpha(150), fontFamily: 'Cairo', fontSize: 10),
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: _kAmounts.map((amt) {
            final isSelected = _selectedAmount == amt;
            return GestureDetector(
              onTap: canBet ? () => _onAmountTap(amt) : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isSelected
                        ? [const Color(0xFFFFD700), const Color(0xFFFFA000)]
                        : [const Color(0xFF2A2A2A), const Color(0xFF1A1A1A)],
                  ),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected ? Colors.white : Colors.transparent,
                    width: isSelected ? 2 : 0,
                  ),
                  boxShadow: isSelected
                      ? [BoxShadow(color: Colors.amber.withAlpha(140), blurRadius: 10, spreadRadius: 1)]
                      : [],
                ),
                child: Text(
                  _fmtNum(amt),
                  style: TextStyle(
                    color: !canBet ? Colors.white24
                        : isSelected ? Colors.brown.shade900
                        : Colors.white70,
                    fontSize: 11, fontWeight: FontWeight.w900,
                    fontFamily: 'Cairo',
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ]),
    );
  }

  // ── Bet bar — shows draft summary + RAH BET button ────────────────

  Widget _buildBetBar(int coins) {
    if (_localPhase != 'betting') return const SizedBox.shrink();

    final total = _draft.values.fold(0, (s, v) => s + v);
    final canBet = _draft.isNotEmpty && total <= coins && !_isPlacing;

    return Container(
      margin: const EdgeInsets.fromLTRB(10, 5, 10, 5),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(90),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _draft.isEmpty
              ? Colors.white.withAlpha(30)
              : const Color(0xFFFFD700).withAlpha(120),
          width: 1.5,
        ),
      ),
      child: Row(children: [
        // Draft chips
        Expanded(
          child: _draft.isEmpty
              ? Text('اضغط على الأطعمة لإضافة رهانات',
                  style: TextStyle(color: Colors.white.withAlpha(100), fontFamily: 'Cairo', fontSize: 11))
              : Wrap(spacing: 5, runSpacing: 4, children: _draft.entries.map((e) {
                  final food = _kFoods[e.key];
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(18),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFFD700).withAlpha(80)),
                    ),
                    child: Text(
                      '${food.emoji} ${_fmtFull(e.value)}',
                      style: const TextStyle(color: Colors.white, fontFamily: 'Cairo',
                          fontWeight: FontWeight.w700, fontSize: 11),
                    ),
                  );
                }).toList()),
        ),
        const SizedBox(width: 8),
        // BET button
        GestureDetector(
          onTap: canBet ? () => _onBet(coins) : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: canBet
                    ? [const Color(0xFF27AE60), const Color(0xFF1A7A3A)]
                    : [Colors.grey.shade700, Colors.grey.shade800],
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: canBet
                  ? [BoxShadow(color: Colors.green.withAlpha(120), blurRadius: 10)]
                  : [],
            ),
            child: _isPlacing
                ? const SizedBox(width: 22, height: 22,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                : Column(mainAxisSize: MainAxisSize.min, children: [
                    const Text('راهن', style: TextStyle(color: Colors.white,
                        fontFamily: 'Cairo', fontWeight: FontWeight.w900, fontSize: 14)),
                    if (total > 0)
                      Text('${_fmtFull(total)} 🪙',
                        style: const TextStyle(color: Color(0xFFFFD700),
                            fontFamily: 'Cairo', fontWeight: FontWeight.w800, fontSize: 10)),
                  ]),
          ),
        ),
      ]),
    );
  }

  // ── Placed bet summary (after confirming) ──────────────────────────

  Widget _buildPlacedBetSummary() {
    final bet = _myBet;
    if (bet == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.fromLTRB(10, 4, 10, 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF1A5C2E), Color(0xFF27AE60), Color(0xFF1A5C2E)]),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF27AE60), width: 2),
        boxShadow: [BoxShadow(color: Colors.green.withAlpha(80), blurRadius: 10)],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Text('✅', style: TextStyle(fontSize: 16)),
          const SizedBox(width: 6),
          Text('رهانك مسجّل — ${bet.items.length} طعام',
            style: const TextStyle(color: Colors.white, fontFamily: 'Cairo', fontWeight: FontWeight.w900, fontSize: 13)),
          const Spacer(),
          Text('مجموع: ${_fmtNum(bet.totalAmount)} 🪙',
            style: const TextStyle(color: Color(0xFFFFD700), fontFamily: 'Cairo', fontWeight: FontWeight.w800, fontSize: 12)),
        ]),
        const SizedBox(height: 8),
        Wrap(spacing: 6, runSpacing: 4, children: bet.items.map((item) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: Colors.black.withAlpha(60), borderRadius: BorderRadius.circular(14)),
            child: Text(
              '${_kFoods[item.foodIndex].emoji} ${_kFoods[item.foodIndex].name}  ${_fmtNum(item.amount)} 🪙 × ${_kFoods[item.foodIndex].mult}',
              style: const TextStyle(color: Colors.white, fontFamily: 'Cairo', fontSize: 11, fontWeight: FontWeight.bold),
            ),
          );
        }).toList()),
      ]),
    );
  }

  // ── Bottom row ─────────────────────────────────────────────────────

  Widget _buildBottomRow(int coins) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      child: Row(children: [
        Expanded(child: _statBtn('سجلاتي 📋', const Color(0xFF2196F3), Colors.white, onTap: _showRecords)),
        const SizedBox(width: 8),
        Expanded(child: _statBtn('القواعد 📖', Colors.brown.shade700, Colors.white, onTap: _showRules)),
      ]),
    );
  }

  Widget _statBtn(String text, Color bg, Color fg, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 10),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(24),
          boxShadow: [BoxShadow(color: bg.withAlpha(80), blurRadius: 8, offset: const Offset(0, 3))]),
        child: Text(text, textAlign: TextAlign.center,
          style: TextStyle(color: fg, fontFamily: 'Cairo', fontWeight: FontWeight.w800, fontSize: 12)),
      ),
    );
  }

  // ── Result overlay ─────────────────────────────────────────────────

  Widget _buildResultOverlay() {
    final state = _state!;
    final winner = state.winnerIndex ?? 0;
    final food = _kFoods[winner];
    final iWon = _myBet?.hasBetOn(winner) ?? false;

    return SlideTransition(
      position: _resultSlide,
      child: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFD4700A), Color(0xFFE89020), Color(0xFFF5A623)],
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Stack(children: [
            const _DotPattern(),
            SingleChildScrollView(
              child: Column(children: [
                // Top bar
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
                  child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(color: Colors.black.withAlpha(80), borderRadius: BorderRadius.circular(12)),
                      child: Text('($_resultCountdown)S', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(color: Colors.black.withAlpha(80), borderRadius: BorderRadius.circular(12)),
                      child: Text('جولة #${state.roundId}', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ]),
                ),
                // Winner food
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Stack(alignment: Alignment.center, children: [
                    const Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Padding(padding: EdgeInsets.only(left: 30), child: Text('🎉', style: TextStyle(fontSize: 28))),
                      Padding(padding: EdgeInsets.only(right: 30), child: Text('🎉', style: TextStyle(fontSize: 28))),
                    ]),
                    Column(children: [
                      AnimatedBuilder(
                        animation: _starY,
                        builder: (_, child) => Transform.translate(offset: Offset(0, _starY.value), child: child),
                        child: Text(food.emoji, style: const TextStyle(fontSize: 70)),
                      ),
                      const SizedBox(height: 2),
                      Text(food.name, style: const TextStyle(color: Colors.white, fontFamily: 'Cairo', fontWeight: FontWeight.w900, fontSize: 20,
                        shadows: [Shadow(color: Colors.black54, blurRadius: 4)])),
                      Text('${food.mult}× المضاعف', style: const TextStyle(color: Color(0xFFFFD700), fontFamily: 'Cairo', fontWeight: FontWeight.w800, fontSize: 14)),
                    ]),
                  ]),
                ),
                // My result
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 14),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: iWon
                          ? [const Color(0xFF27AE60).withAlpha(180), const Color(0xFF1E8449).withAlpha(160)]
                          : [Colors.brown.withAlpha(120), Colors.brown.withAlpha(80)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: iWon ? const Color(0xFF27AE60) : const Color(0xFFDAA520).withAlpha(100)),
                  ),
                  child: Row(children: [
                    Text(iWon ? '🏆' : (_myBet != null ? '😔' : '👀'), style: const TextStyle(fontSize: 32)),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(
                        iWon ? 'فزت! 🎊' : (_myBet != null ? 'خسرت هذه الجولة' : 'لم تراهن'),
                        style: TextStyle(color: iWon ? Colors.white : Colors.white70, fontFamily: 'Cairo', fontWeight: FontWeight.w900, fontSize: 15)),
                      if (iWon && _myWinAmount > 0)
                        Text('+${_fmtNumFull(_myWinAmount)} 🪙 أضيفت لرصيدك!',
                          style: const TextStyle(color: Color(0xFFFFD700), fontFamily: 'Cairo', fontWeight: FontWeight.w800, fontSize: 13))
                      else if (_myBet != null && !iWon)
                        Text('خسرت ${_fmtNum(_myBet!.amountFor(winner))} 🪙 على ${food.name}',
                          style: TextStyle(color: Colors.red.shade300, fontFamily: 'Cairo', fontSize: 12)),
                    ])),
                  ]),
                ),
                const SizedBox(height: 12),
                // Top 3
                if (state.topWinners.isNotEmpty) ...[
                  Row(children: [
                    Expanded(child: Container(height: 1, color: Colors.white.withAlpha(60), margin: const EdgeInsets.symmetric(horizontal: 14))),
                    Padding(padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text('أكبر الفائزين 🏆',
                        style: TextStyle(color: Colors.white.withAlpha(200), fontFamily: 'Cairo', fontSize: 12, fontWeight: FontWeight.bold))),
                    Expanded(child: Container(height: 1, color: Colors.white.withAlpha(60), margin: const EdgeInsets.symmetric(horizontal: 14))),
                  ]),
                  const SizedBox(height: 10),
                  _buildPodium(state.topWinners),
                ],
                const SizedBox(height: 16),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _buildPodium(List<WinnerInfo> winners) {
    final cnt = winners.length.clamp(1, 3);
    final order = cnt == 1 ? [winners[0]] : cnt == 2 ? [winners[1], winners[0]] : [winners[2], winners[0], winners[1]];
    final ranks = cnt == 1 ? ['1'] : cnt == 2 ? ['2', '1'] : ['3', '1', '2'];
    final rankColors = [const Color(0xFFCD7F32), const Color(0xFFFFD700), const Color(0xFFB0C4DE)];
    final rcOrder = cnt == 1 ? [rankColors[0]] : cnt == 2 ? [rankColors[2], rankColors[0]] : [rankColors[2], rankColors[0], rankColors[1]];
    final offsets = cnt == 1 ? [0.0] : cnt == 2 ? [0.0, -18.0] : [0.0, -18.0, -6.0];
    final sizes = cnt == 1 ? [68.0] : cnt == 2 ? [58.0, 68.0] : [54.0, 68.0, 58.0];
    final bgColors = [const Color(0xFF4CAF50), const Color(0xFF2196F3), const Color(0xFFFF5722), const Color(0xFF9C27B0), const Color(0xFFFF9800)];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(order.length, (i) {
        final w = order[i];
        final isFirst = ranks[i] == '1';
        final bg = bgColors[w.userId.hashCode.abs() % bgColors.length];
        return Transform.translate(
          offset: Offset(0, offsets[i]),
          child: Column(children: [
            Stack(children: [
              CircleAvatar(
                radius: sizes[i] / 2,
                backgroundColor: bg,
                backgroundImage: (w.avatar != null && w.avatar!.isNotEmpty) ? NetworkImage(w.avatar!) : null,
                child: (w.avatar == null || w.avatar!.isEmpty)
                    ? Text(w.userName.isNotEmpty ? w.userName[0].toUpperCase() : '؟',
                        style: TextStyle(color: Colors.white, fontSize: sizes[i] * 0.38, fontWeight: FontWeight.bold))
                    : null,
              ),
              Positioned(top: 0, right: 0,
                child: Container(width: 20, height: 20,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: rcOrder[i], border: Border.all(color: Colors.white, width: 1.5)),
                  child: Center(child: Text(ranks[i], style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900))))),
            ]),
            const SizedBox(height: 4),
            SizedBox(width: 74, child: Text(w.userName, textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontFamily: 'Cairo', fontSize: isFirst ? 12 : 10, fontWeight: FontWeight.bold),
              maxLines: 1, overflow: TextOverflow.ellipsis)),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: Colors.black.withAlpha(100), borderRadius: BorderRadius.circular(14),
                border: Border.all(color: rcOrder[i].withAlpha(150))),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(_fmtNum(w.amount), style: TextStyle(color: rcOrder[i], fontSize: isFirst ? 12 : 10, fontWeight: FontWeight.w900)),
                const SizedBox(width: 2),
                const Text('🪙', style: TextStyle(fontSize: 11)),
              ]),
            ),
          ]),
        );
      }),
    );
  }

  // ── Toast ──────────────────────────────────────────────────────────

  Widget _buildToast() {
    return Positioned(
      top: 140, left: 24, right: 24,
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
          decoration: BoxDecoration(color: Colors.black.withAlpha(220), borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: Colors.black.withAlpha(80), blurRadius: 12)]),
          child: Text(_toast!, textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontFamily: 'Cairo', fontSize: 14, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  // ── Dialogs ────────────────────────────────────────────────────────

  void _showRules() {
    showDialog(
      context: context,
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: const Color(0xFF3A1A00),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: Color(0xFFDAA520), width: 2)),
          title: const Text('قواعد اللعبة', style: TextStyle(color: Color(0xFFFFD700), fontFamily: 'Cairo', fontWeight: FontWeight.w900, fontSize: 18), textAlign: TextAlign.center),
          content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            _rule('1', 'اضغط على الطعام في العجلة لاختياره'),
            _rule('2', 'اختر المبلغ من الشريط الذهبي (500 → 100ك)'),
            _rule('3', 'راهن على 6 أطعمة مختلفة بمبالغ مختلفة'),
            _rule('4', 'اضغط "تأكيد الرهان" — يُخصم المجموع فوراً'),
            _rule('5', 'إذا فاز طعامك → مبلغك × المضاعف لرصيدك'),
            _rule('6', 'كل جولة 30 ثانية، والنتيجة مباشرة'),
            _rule('7', 'السمك 🐟 (45×) أعلى ربح وأقل احتمالية'),
            const SizedBox(height: 8),
            // Food table
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.white.withAlpha(10), borderRadius: BorderRadius.circular(10)),
              child: Column(children: _kFoods.map((f) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(children: [
                  Text(f.emoji, style: const TextStyle(fontSize: 18)),
                  const SizedBox(width: 8),
                  Expanded(child: Text(f.name, style: const TextStyle(color: Colors.white70, fontFamily: 'Cairo', fontSize: 12))),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: f.hot ? const Color(0xFFFF3B30) : const Color(0xFFE07000).withAlpha(120), borderRadius: BorderRadius.circular(8)),
                    child: Text('${f.mult}×', style: const TextStyle(color: Colors.white, fontFamily: 'Cairo', fontWeight: FontWeight.w900, fontSize: 12)),
                  ),
                ]),
              )).toList()),
            ),
          ]),
          actions: [
            Center(child: TextButton(
              style: TextButton.styleFrom(backgroundColor: const Color(0xFFFFD700),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 8)),
              onPressed: () => Navigator.pop(context),
              child: const Text('فهمت! ✅', style: TextStyle(color: Colors.brown, fontFamily: 'Cairo', fontWeight: FontWeight.w900, fontSize: 15)),
            )),
          ],
        ),
      ),
    );
  }

  Widget _rule(String n, String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(width: 20, height: 20, decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFFFD700)),
        child: Center(child: Text(n, style: const TextStyle(color: Colors.brown, fontSize: 11, fontWeight: FontWeight.w900)))),
      const SizedBox(width: 8),
      Expanded(child: Text(text, style: const TextStyle(color: Colors.white70, fontFamily: 'Cairo', fontSize: 12))),
    ]),
  );

  void _showRecords() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF3A1A00),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20)), side: BorderSide(color: Color(0xFFDAA520), width: 2)),
      isScrollControlled: true,
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: DraggableScrollableSheet(
          expand: false, initialChildSize: 0.55, maxChildSize: 0.85,
          builder: (_, ctrl) => Column(children: [
            Padding(padding: const EdgeInsets.all(12),
              child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white30, borderRadius: BorderRadius.circular(2)))),
            const Text('سجل مشاركاتي', style: TextStyle(color: Color(0xFFFFD700), fontFamily: 'Cairo', fontWeight: FontWeight.w900, fontSize: 18)),
            const Divider(color: Color(0xFFDAA520)),
            Expanded(
              child: _records.isEmpty
                  ? const Center(child: Text('لا توجد سجلات بعد', style: TextStyle(color: Colors.white54, fontFamily: 'Cairo')))
                  : ListView.builder(
                      controller: ctrl,
                      itemCount: _records.length,
                      itemBuilder: (_, idx) {
                        final rec = _records[idx];
                        final win = rec['win'] as int;
                        final bet = rec['bet'] as int;
                        final winnerFood = _kFoods[rec['food'] as int];
                        final items = rec['items'] as List? ?? [];
                        return ExpansionTile(
                          leading: Text(winnerFood.emoji, style: const TextStyle(fontSize: 26)),
                          title: Text('جولة ${rec['round']} — الفائز: ${winnerFood.name}',
                            style: const TextStyle(color: Colors.white, fontFamily: 'Cairo', fontWeight: FontWeight.w700, fontSize: 13)),
                          subtitle: Text(
                            'رهان: ${_fmtNum(bet)} 🪙  ${win > 0 ? '→ +${_fmtNum(win)} 🏆' : '→ خسارة'}',
                            style: TextStyle(color: win > 0 ? const Color(0xFFFFD700) : Colors.red.shade300, fontFamily: 'Cairo', fontSize: 11)),
                          trailing: Text(win > 0 ? '+${_fmtNum(win)}' : '--',
                            style: TextStyle(color: win > 0 ? const Color(0xFF27AE60) : Colors.white38, fontWeight: FontWeight.w900, fontSize: 14)),
                          iconColor: Colors.white54,
                          collapsedIconColor: Colors.white38,
                          children: items.map<Widget>((item) {
                            final fi = (item as Map)['f'] as int;
                            final amt = item['a'] as int;
                            final food = _kFoods[fi];
                            final isWon = fi == rec['food'] && win > 0;
                            return Padding(
                              padding: const EdgeInsets.fromLTRB(16, 2, 16, 2),
                              child: Row(children: [
                                Text(food.emoji, style: const TextStyle(fontSize: 18)),
                                const SizedBox(width: 8),
                                Text('${food.name}  ${_fmtNum(amt)} 🪙',
                                  style: const TextStyle(color: Colors.white70, fontFamily: 'Cairo', fontSize: 12)),
                                const Spacer(),
                                Text(isWon ? '+${_fmtNum(amt * food.mult)} 🏆' : (fi == rec['food'] ? '+${_fmtNum(amt * food.mult)}' : 'خسر'),
                                  style: TextStyle(color: isWon ? const Color(0xFFFFD700) : Colors.red.shade300, fontFamily: 'Cairo', fontWeight: FontWeight.w700, fontSize: 11)),
                              ]),
                            );
                          }).toList(),
                        );
                      }),
            ),
          ]),
        ),
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────

  String _fmtNum(int v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}م';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(v % 1000 == 0 ? 0 : 1)}ك';
    return '$v';
  }

  // Full number with commas — shown below food bubble (e.g. 10,500)
  String _fmtFull(int v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(v % 1000000 == 0 ? 0 : 1)}م';
    return v.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
  }

  // Full number with commas for balance display
  String _fmtNumFull(int v) {
    if (v >= 1000000) {
      final m = v / 1000000;
      return '${m.toStringAsFixed(m % 1 == 0 ? 0 : 2)}م';
    }
    if (v >= 1000) {
      return v.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
    }
    return '$v';
  }
}

// ── Dot pattern ───────────────────────────────────────────────────────────────

class _DotPattern extends StatelessWidget {
  const _DotPattern();
  @override
  Widget build(BuildContext context) => Positioned.fill(child: CustomPaint(painter: _DotPainter()));
}

class _DotPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = Colors.white.withAlpha(18)..style = PaintingStyle.fill;
    for (double x = 0; x < size.width; x += 22) {
      for (double y = 0; y < size.height; y += 22) {
        canvas.drawCircle(Offset(x, y), 2, p);
      }
    }
  }
  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

// ── Wheel painter ─────────────────────────────────────────────────────────────

class _WheelPainter extends CustomPainter {
  final double cx, cy, r;
  const _WheelPainter({required this.cx, required this.cy, required this.r});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawCircle(Offset(cx, cy), r + 45,
      Paint()..shader = const RadialGradient(
        colors: [Color(0xFFFFD580), Color(0xFFF5A623), Color(0xFFE07000)], radius: 0.8,
      ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: r + 45)));

    canvas.drawCircle(Offset(cx, cy), r + 36,
      Paint()..color = const Color(0xFFDAA520)..style = PaintingStyle.stroke..strokeWidth = 5);

    final innerRing = Paint()..color = const Color(0xFFB8860B)..style = PaintingStyle.stroke..strokeWidth = 3.5;
    canvas.drawCircle(Offset(cx, cy), 50, innerRing);

    final spoke = Paint()..color = const Color(0xFF8B5E00)..strokeWidth = 7..strokeCap = StrokeCap.round..style = PaintingStyle.stroke;
    final spokeL = Paint()..color = const Color(0xFFD4A017)..strokeWidth = 2..strokeCap = StrokeCap.round..style = PaintingStyle.stroke;
    for (int i = 0; i < 8; i++) {
      final a = -pi / 2 + i * pi / 4;
      final sx = cx + 52 * cos(a); final sy = cy + 52 * sin(a);
      final ex = cx + (r + 12) * cos(a); final ey = cy + (r + 12) * sin(a);
      canvas.drawLine(Offset(sx, sy), Offset(ex, ey), spoke);
      canvas.drawLine(Offset(sx, sy), Offset(ex, ey), spokeL);
    }

    canvas.drawCircle(Offset(cx, cy), 48,
      Paint()..shader = const RadialGradient(colors: [Color(0xFF8B5E00), Color(0xFF5C3A00)])
          .createShader(Rect.fromCircle(center: Offset(cx, cy), radius: 50)));
    canvas.drawCircle(Offset(cx, cy), 48, innerRing);

    final leg = Paint()..color = const Color(0xFF6B4200)..strokeWidth = 8..strokeCap = StrokeCap.round..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(cx, cy + r + 30), Offset(cx - 40, size.height - 10), leg);
    canvas.drawLine(Offset(cx, cy + r + 30), Offset(cx + 40, size.height - 10), leg);
    canvas.drawLine(Offset(cx - 50, size.height - 10), Offset(cx + 50, size.height - 10), leg);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
