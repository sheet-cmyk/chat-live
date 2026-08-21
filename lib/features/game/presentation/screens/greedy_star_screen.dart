import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/greedy_star_repository.dart';
import '../../../wallet/presentation/providers/wallet_provider.dart';

// ── Egyptian Palette ──────────────────────────────────────────────────────────
const _kGold       = Color(0xFFD4AF37);
const _kBrightGold = Color(0xFFF5C542);
const _kTurquoise  = Color(0xFF0FA3A5);
const _kDeepTeal   = Color(0xFF075E63);
const _kEmerald    = Color(0xFF087F5B);
const _kRoyalPurple= Color(0xFF39205F);
const _kDeepPurple = Color(0xFF241638);
const _kSandstone  = Color(0xFFC89B5B);
const _kCream      = Color(0xFFFFF4D6);
const _kDarkBrown  = Color(0xFF3A2415);

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
  int _totalBettors = 0;

  // Local UI
  String _localPhase = 'loading';
  int _countdown = 30;
  int _resultCountdown = 7;
  int _highlight = -1;

  int _selectedAmount = 1000; // active chip on amount bar
  Set<int> _tapping = {};     // foods with in-flight tapBet request

  int _myWinAmount = 0;
  bool _claimDone = false;
  String? _toast;
  final _records = <Map<String, dynamic>>[];
  final _optimisticBets = <int, int>{}; // رهانات فورية قبل تأكيد Firebase
  int? _trackedRound;

  // Animations
  late AnimationController _starCtrl;
  late Animation<double> _starY;
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
        setState(() { _myBet = bet; _optimisticBets.clear(); });
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
        setState(() {
          _betterCounts = counts;
          _totalBettors = snap.docs.length;
        });
      });

      setState(() {
        _myBet = null;
        _myWinAmount = 0;
        _claimDone = false;
        _tapping = {};
        _betterCounts = {};
        _totalBettors = 0;
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
      if (step < 8) {
        ms = 50;
      } else if (step < 14) {
        ms = 65 + (step - 8) * 18; // 65→173 ms
      } else {
        ms = 175;
      }
      if (step >= 18) { _landOnWinner(winnerIndex, step, roundId); return; }
      _t2 = Timer(Duration(milliseconds: ms), tick);
    }
    tick();
  }

  void _landOnWinner(int winnerIndex, int step, int roundId) {
    final cur = step % 8;
    int diff = (winnerIndex - cur + 8) % 8;
    if (diff == 0) diff = 8;
    int landed = 0;
    _t2 = Timer.periodic(const Duration(milliseconds: 160), (t) {
      if (!mounted) { t.cancel(); return; }
      landed++;
      setState(() => _highlight = (cur + landed) % 8);
      if (landed >= diff) {
        t.cancel();
        Future.delayed(const Duration(milliseconds: 280), () {
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

  // ── Bet actions ────────────────────────────────────────────────────

  void _onAmountTap(int amt) => setState(() => _selectedAmount = amt);

  // حساب الرهان الفعلي (مؤكد من Firebase + رهانات فورية معلّقة)
  MyBet? get _effectiveBet {
    if (_optimisticBets.isEmpty) return _myBet;
    final base = <int, int>{};
    for (final item in (_myBet?.items ?? <BetItem>[])) {
      base[item.foodIndex] = item.amount;
    }
    for (final e in _optimisticBets.entries) {
      base[e.key] = (base[e.key] ?? 0) + e.value;
    }
    final items = base.entries
        .map((e) => BetItem(foodIndex: e.key, amount: e.value))
        .toList();
    return MyBet(
      items: items,
      totalAmount: items.fold(0, (s, i) => s + i.amount),
      paid: false,
    );
  }

  // Each food tap: optimistic update first, then Firebase in background
  Future<void> _onFoodTap(int fi, int coins) async {
    if (_localPhase != 'betting') { _showToast('انتهى وقت الرهان'); return; }
    if (_selectedAmount == 0) { _showToast('اختر مبلغاً أولاً'); return; }
    if (_tapping.contains(fi)) return;
    if (_selectedAmount > coins) { _showToast('رصيدك غير كافٍ 🪙'); return; }

    // 6-food limit (يشمل الرهانات الفورية المعلّقة)
    final eff = _effectiveBet;
    if (eff != null && !eff.hasBetOn(fi) && eff.items.length >= 6) {
      _showToast('الحد الأقصى 6 أطعمة مختلفة');
      return;
    }

    // تحديث فوري: يظهر الرهان في الواجهة قبل تأكيد Firebase
    setState(() {
      _tapping.add(fi);
      _optimisticBets[fi] = (_optimisticBets[fi] ?? 0) + _selectedAmount;
    });

    final err = await _repo.tapBet(
      roundId: _state!.roundId,
      foodIndex: fi,
      amount: _selectedAmount,
    );
    if (!mounted) return;
    setState(() {
      _tapping.remove(fi);
      if (err != null) {
        // فشل — تراجع عن التحديث الفوري
        _optimisticBets[fi] = (_optimisticBets[fi] ?? 0) - _selectedAmount;
        if ((_optimisticBets[fi] ?? 0) <= 0) _optimisticBets.remove(fi);
        _showToast(err);
      }
    });
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
              colors: [Color(0xFF0C3A3E), Color(0xFF071E22), Color(0xFF04120F)],
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
                          _buildRecentBar(),
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
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _kDeepTeal,
                  border: Border.all(color: _kGold, width: 1.5),
                ),
                child: const Icon(Icons.close_rounded, color: _kCream, size: 18),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _showRules,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [_kGold, _kSandstone]),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _kBrightGold, width: 1),
                ),
                child: const Text('القواعد', style: TextStyle(color: _kDarkBrown, fontFamily: 'Cairo', fontWeight: FontWeight.w800, fontSize: 11)),
              ),
            ),
            Expanded(
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [_kEmerald, _kDeepTeal, _kEmerald]),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _kGold, width: 2),
                    boxShadow: [BoxShadow(color: _kGold.withAlpha(60), blurRadius: 6)],
                  ),
                  child: const Text('النجمة الجشعة 🌟',
                    style: TextStyle(color: _kCream, fontSize: 13, fontWeight: FontWeight.w900, fontFamily: 'Cairo',
                      shadows: [Shadow(color: Colors.black54, blurRadius: 4, offset: Offset(1, 2))])),
                ),
              ),
            ),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('جولة #${_state?.roundId ?? '-'}',
                style: const TextStyle(color: _kBrightGold, fontFamily: 'Cairo', fontSize: 10, fontWeight: FontWeight.bold)),
              Text(_localPhase == 'betting' ? 'رهان' : _localPhase == 'spinning' ? 'دوران' : _localPhase == 'result' ? 'نتيجة' : '...',
                style: const TextStyle(color: _kSandstone, fontFamily: 'Cairo', fontSize: 9)),
            ]),
          ]),
        ),
        // ── Balance chip ──────────────────────────────────────────────
        Container(
          margin: const EdgeInsets.fromLTRB(14, 6, 14, 0),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [_kDeepTeal, _kDeepPurple, _kDeepTeal]),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: _kGold, width: 2),
            boxShadow: [BoxShadow(color: _kGold.withAlpha(40), blurRadius: 8, offset: const Offset(0, 3))],
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Text('🪙', style: TextStyle(fontSize: 22)),
            const SizedBox(width: 8),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('رصيدك', style: TextStyle(color: _kSandstone, fontFamily: 'Cairo', fontSize: 10)),
              Text(_fmtNumFull(coins),
                style: const TextStyle(color: _kBrightGold, fontFamily: 'Cairo', fontWeight: FontWeight.w900, fontSize: 20,
                  shadows: [Shadow(color: Colors.black54, blurRadius: 4)])),
            ]),
            const SizedBox(width: 12),
            Container(width: 1, height: 30, color: _kGold.withAlpha(80)),
            const SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('المشتركون', style: TextStyle(color: _kSandstone, fontFamily: 'Cairo', fontSize: 10)),
              Text('${_betterCounts.values.fold(0, (a, b) => a + b)} لاعب',
                style: const TextStyle(color: _kCream, fontFamily: 'Cairo', fontWeight: FontWeight.w800, fontSize: 14)),
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
      const cy = 168.0, r = 126.0, bSize = 76.0, h = 372.0;
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

    final isMyBet = _effectiveBet?.hasBetOn(i) ?? false;
    final myBetAmt = _effectiveBet?.amountFor(i) ?? 0;
    final isHighlighted = _highlight == i;
    final isWinner = _state?.winnerIndex == i && _localPhase == 'result';
    final canBet = _localPhase == 'betting';

    Widget bubble = AnimatedBuilder(
      animation: _glowCtrl,
      builder: (_, __) {
        const scale = 1.0;
        final glowR = isHighlighted ? _glow.value : 0.0;
        const isPharaoh = false;
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
                        ? [_kBrightGold, _kGold, _kSandstone]
                        : isWinner
                            ? [_kBrightGold, _kGold, const Color(0xFF8B6914)]
                            : isMyBet
                                ? [const Color(0xFF0FA3A5), _kDeepTeal, const Color(0xFF033C3F)]
                                : [_kRoyalPurple, _kDeepPurple, const Color(0xFF110D1E)],
                    center: const Alignment(-0.3, -0.3), radius: 0.85,
                  ),
                  border: Border.all(
                    color: isHighlighted ? _kBrightGold
                        : isMyBet ? _kTurquoise
                        : isPharaoh ? _kGold
                        : _kGold.withAlpha(180),
                    width: isHighlighted ? 4 : isMyBet ? 3.5 : isPharaoh ? 3 : 2,
                  ),
                  boxShadow: [BoxShadow(
                    color: isHighlighted ? _kBrightGold.withAlpha(200)
                        : isMyBet ? _kTurquoise.withAlpha(140)
                        : isPharaoh ? _kGold.withAlpha(80)
                        : Colors.black.withAlpha(55),
                    blurRadius: glowR + 4, spreadRadius: isHighlighted ? 3 : 0,
                  )],
                ),
                child: isPharaoh
                    ? Center(child: Column(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
                        Text('👑', style: TextStyle(fontSize: bSize * 0.34)),
                        Text('فرعون', style: TextStyle(
                          color: isHighlighted ? _kDarkBrown : _kGold,
                          fontSize: 9, fontFamily: 'Cairo', fontWeight: FontWeight.w900,
                          shadows: const [Shadow(color: Colors.black54, blurRadius: 2)],
                        )),
                      ]))
                    : Stack(children: [
                        Align(
                          alignment: const Alignment(0, -0.30),
                          child: Text(food.emoji, style: TextStyle(fontSize: bSize * 0.43)),
                        ),
                        Positioned(
                          bottom: 6, left: 0, right: 0,
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: _kGold,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text('×${food.mult}',
                                style: const TextStyle(color: _kDarkBrown, fontSize: 11,
                                  fontWeight: FontWeight.w900)),
                            ),
                          ),
                        ),
                      ]),
              ),
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
            // Amount below bubble — shown when user has bet on this food
            if (isMyBet && myBetAmt > 0)
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: _kDeepTeal,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _kGold, width: 1),
                  ),
                  child: Text(_fmtFull(myBetAmt),
                    style: const TextStyle(color: _kBrightGold, fontSize: 9, fontWeight: FontWeight.w900)),
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
      // Center the circle: cx-46 horizontally, cy-46 vertically
      left: cx - 46, top: cy - 46,
      child: Container(
        width: 92, height: 92,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(46),
          gradient: const LinearGradient(
            colors: [_kTurquoise, _kDeepTeal, Color(0xFF033C3F)],
            begin: Alignment.topLeft, end: Alignment.bottomRight,
          ),
          border: Border.all(color: _kGold, width: 3),
          boxShadow: [BoxShadow(color: _kGold.withAlpha(80), blurRadius: 12, spreadRadius: 2)],
        ),
        child: Stack(children: [
          // Star bouncing in center
          AnimatedBuilder(
            animation: _starY,
            builder: (_, child) => Transform.translate(offset: Offset(0, _starY.value + 6), child: child),
            child: _buildStarChar(),
          ),
          // Countdown overlaid at top inside the circle
          Positioned(
            top: 4, left: 0, right: 0,
            child: Center(
              child: _localPhase == 'betting'
                  ? Text('$_countdown',
                      style: const TextStyle(color: Colors.white, fontSize: 22,
                        fontWeight: FontWeight.w900,
                        shadows: [Shadow(color: Colors.black54, blurRadius: 4)]))
                  : _localPhase == 'result'
                      ? Text('$_resultCountdown',
                          style: const TextStyle(color: Colors.white, fontSize: 22,
                            fontWeight: FontWeight.w900,
                            shadows: [Shadow(color: Colors.black54, blurRadius: 4)]))
                      : _localPhase == 'spinning'
                          ? const Text('🎡', style: TextStyle(fontSize: 16))
                          : const SizedBox(width: 16, height: 16,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
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
          child: Container(width: 7, height: 3, decoration: BoxDecoration(color: const Color(0xFF3D1A50), borderRadius: BorderRadius.circular(3)))),
        Positioned(top: 21, right: 20,
          child: Container(width: 6, height: 6, decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFF3D1A50)))),
        Positioned(top: 22, right: 22,
          child: Container(width: 2, height: 2, decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white))),
        Positioned(bottom: 17, left: 0, right: 0,
          child: Center(child: Container(width: 14, height: 7,
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: const Color(0xFF4D2060), width: 2.5),
                left: BorderSide(color: const Color(0xFF4D2060), width: 2),
                right: BorderSide(color: const Color(0xFF4D2060), width: 2),
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
      final eff = _effectiveBet;
      if (eff != null) {
        msg = '✅ رهانك: ${_fmtFull(eff.totalAmount)} 🪙 على ${eff.items.length} طعام — اضغط مجدداً لإضافة المزيد';
      } else {
        msg = 'اختر المبلغ 👇  ثم اضغط على الطعام مباشرةً';
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
        gradient: const LinearGradient(colors: [_kDeepTeal, _kEmerald, _kDeepTeal]),
        border: const Border(
          top: BorderSide(color: _kGold, width: 1),
          bottom: BorderSide(color: _kGold, width: 1),
        ),
        boxShadow: [BoxShadow(color: _kGold.withAlpha(40), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Text(msg, textAlign: TextAlign.center,
        style: const TextStyle(color: _kCream, fontFamily: 'Cairo', fontWeight: FontWeight.w800, fontSize: 13,
          shadows: [Shadow(color: Colors.black54, blurRadius: 3)])),
    );
  }

  // ── Amount bar — select chip, then tap foods to accumulate ───────────

  Widget _buildAmountBar() {
    final canBet = _localPhase == 'betting'; // stays active even after placing bets

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [_kDeepPurple, _kRoyalPurple, _kDeepPurple]),
        border: Border(
          top: BorderSide(color: _kGold, width: 1),
          bottom: BorderSide(color: _kGold, width: 1),
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
                        ? [_kBrightGold, _kGold, _kSandstone]
                        : [_kDeepPurple, _kRoyalPurple],
                  ),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected ? _kBrightGold : _kGold.withAlpha(120),
                    width: isSelected ? 2 : 1,
                  ),
                  boxShadow: isSelected
                      ? [BoxShadow(color: _kGold.withAlpha(160), blurRadius: 10, spreadRadius: 1)]
                      : [],
                ),
                child: Text(
                  _fmtNum(amt),
                  style: TextStyle(
                    color: !canBet ? Colors.white24
                        : isSelected ? _kDarkBrown
                        : _kSandstone,
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

  // ── Recent winners bar — history strip showing last 20 winning foods ─

  Widget _buildRecentBar() {
    final winners = _state?.lastWinners ?? [];
    // Also show current round winner if in result phase
    final all = [
      ...winners,
      if (_localPhase == 'result' && (_state?.winnerIndex != null)) _state!.winnerIndex!,
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(8, 5, 8, 5),
      decoration: const BoxDecoration(
        color: Color(0xFF041214),
        border: Border(
          top: BorderSide(color: _kGold, width: 1),
          bottom: BorderSide(color: _kGold, width: 1),
        ),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          const Text('𓂀', style: TextStyle(fontSize: 12, color: _kGold)),
          const SizedBox(width: 4),
          const Text('آخر النتائج',
            style: TextStyle(color: _kSandstone, fontFamily: 'Cairo', fontSize: 10, fontWeight: FontWeight.bold)),
          const Spacer(),
          Text('${all.length} جولة',
            style: const TextStyle(color: _kGold, fontFamily: 'Cairo', fontSize: 9)),
        ]),
        const SizedBox(height: 4),
        SizedBox(
          height: 36,
          child: all.isEmpty
              ? Center(child: Text('ستظهر النتائج هنا بعد انتهاء كل جولة',
                  style: TextStyle(color: Colors.white.withAlpha(60), fontFamily: 'Cairo', fontSize: 9)))
              : ListView.builder(
                  scrollDirection: Axis.horizontal,
                  reverse: false,
                  itemCount: all.length,
                  itemBuilder: (_, idx) {
                    final fi = all[idx];
                    final isLatest = idx == all.length - 1;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: isLatest ? 34 : 30,
                        height: isLatest ? 34 : 30,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isLatest
                              ? _kGold.withAlpha(60)
                              : _kRoyalPurple.withAlpha(120),
                          border: Border.all(
                            color: isLatest ? _kBrightGold : _kGold.withAlpha(100),
                            width: isLatest ? 2 : 1,
                          ),
                          boxShadow: isLatest
                              ? [BoxShadow(color: _kGold.withAlpha(120), blurRadius: 6)]
                              : [],
                        ),
                        child: Center(
                          child: Text(_kFoods[fi].emoji,
                            style: TextStyle(fontSize: isLatest ? 18 : 15)),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ]),
    );
  }

  // ── Bottom row ─────────────────────────────────────────────────────

  Widget _buildBottomRow(int coins) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      child: Row(children: [
        Expanded(child: _statBtn('سجلاتي 📋', _kDeepTeal, _kCream, onTap: _showRecords)),
        const SizedBox(width: 8),
        Expanded(child: _statBtn('القواعد 📖', _kRoyalPurple, _kCream, onTap: _showRules)),
      ]),
    );
  }

  Widget _statBtn(String text, Color bg, Color fg, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: _kGold, width: 1.5),
          boxShadow: [BoxShadow(color: _kGold.withAlpha(60), blurRadius: 8, offset: const Offset(0, 3))],
        ),
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
    final iWon = _effectiveBet?.hasBetOn(winner) ?? false;
    final numWon = _betterCounts[winner] ?? 0;
    final numBet = _totalBettors;

    return Positioned(
      bottom: 0, left: 0, right: 0,
      child: SlideTransition(
        position: _resultSlide,
        child: Container(
          height: MediaQuery.of(context).size.height * 0.66,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0A3038), Color(0xFF071E22), Color(0xFF04100E)],
              begin: Alignment.topCenter, end: Alignment.bottomCenter,
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: const Border(
              top: BorderSide(color: _kGold, width: 2),
              left: BorderSide(color: _kGold, width: 1),
              right: BorderSide(color: _kGold, width: 1),
            ),
            boxShadow: [BoxShadow(color: Colors.black.withAlpha(180), blurRadius: 30, spreadRadius: 4, offset: const Offset(0, -4))],
          ),
          child: Column(children: [

            // ── شريط علوي: عداد + جولة ───────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: Colors.black.withAlpha(80), borderRadius: BorderRadius.circular(10)),
                  child: Text('($_resultCountdown)ث', style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w900, fontFamily: 'Cairo')),
                ),
                const Spacer(),
                Container(width: 40, height: 4, decoration: BoxDecoration(
                  color: const Color(0xFFD6A928).withAlpha(100),
                  borderRadius: BorderRadius.circular(2),
                )),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: Colors.black.withAlpha(80), borderRadius: BorderRadius.circular(10)),
                  child: Text('جولة #${state.roundId}', style: const TextStyle(color: Colors.white54, fontSize: 12, fontFamily: 'Cairo')),
                ),
              ]),
            ),

            // ── الطعام الفائز في الوسط ────────────────────────
            const SizedBox(height: 6),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Text('🎉', style: TextStyle(fontSize: 22)),
              const SizedBox(width: 8),
              AnimatedBuilder(
                animation: _starY,
                builder: (_, child) => Transform.translate(offset: Offset(0, _starY.value), child: child),
                child: Text(food.emoji, style: const TextStyle(fontSize: 58)),
              ),
              const SizedBox(width: 8),
              const Text('🎉', style: TextStyle(fontSize: 22)),
            ]),
            Text(food.name, textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontFamily: 'Cairo', fontWeight: FontWeight.w900, fontSize: 20,
                shadows: [Shadow(color: Colors.black54, blurRadius: 4)])),
            Text('${food.mult}× المضاعف', textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFFFFD700), fontFamily: 'Cairo', fontWeight: FontWeight.w700, fontSize: 13)),

            // ── نتيجة المستخدم ────────────────────────────────
            const SizedBox(height: 8),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: iWon ? _kEmerald.withAlpha(90) : _kDeepTeal.withAlpha(80),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: iWon ? _kTurquoise.withAlpha(200) : _kGold.withAlpha(120)),
              ),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text(iWon ? '🏆' : (_myBet != null || _optimisticBets.isNotEmpty ? '😔' : '👀'), style: const TextStyle(fontSize: 22)),
                const SizedBox(width: 8),
                Text(
                  iWon
                    ? 'فزت! +${_fmtNum(_myWinAmount)} 🪙'
                    : (_effectiveBet != null
                        ? 'خسرت ${_fmtNum(_effectiveBet!.amountFor(winner))} 🪙'
                        : 'لم تراهن'),
                  style: TextStyle(
                    color: iWon ? _kBrightGold : _kCream,
                    fontFamily: 'Cairo', fontWeight: FontWeight.w900, fontSize: 15),
                ),
              ]),
            ),

            // ── فاز / راهن (مبالغ المستخدم) ──────────────────
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                Column(children: [
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(_fmtNum(_effectiveBet?.totalAmount ?? 0),
                      style: const TextStyle(color: Colors.white, fontFamily: 'Cairo', fontWeight: FontWeight.w900, fontSize: 20)),
                    const Text(' 🪙', style: TextStyle(fontSize: 14)),
                  ]),
                  const Text('راهن', style: TextStyle(color: Colors.white54, fontFamily: 'Cairo', fontSize: 11)),
                ]),
                Container(width: 1, height: 32, color: const Color(0xFFD6A928).withAlpha(60)),
                Column(children: [
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(iWon ? _fmtNum(_myWinAmount) : '0',
                      style: TextStyle(color: iWon ? const Color(0xFFFFD700) : Colors.white38, fontFamily: 'Cairo', fontWeight: FontWeight.w900, fontSize: 20)),
                    const Text(' 🪙', style: TextStyle(fontSize: 14)),
                  ]),
                  const Text('فاز', style: TextStyle(color: Colors.white54, fontFamily: 'Cairo', fontSize: 11)),
                ]),
              ]),
            ),

            // ── فاصل ─────────────────────────────────────────
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(children: [
                Expanded(child: Container(height: 1, color: _kGold.withAlpha(80))),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text('أكبر الفائزين 🏆',
                    style: TextStyle(color: _kGold.withAlpha(200), fontFamily: 'Cairo', fontSize: 11, fontWeight: FontWeight.bold)),
                ),
                Expanded(child: Container(height: 1, color: _kGold.withAlpha(80))),
              ]),
            ),

            // ── منصة الفائزين الثلاثة ─────────────────────────
            if (state.topWinners.isNotEmpty)
              Expanded(child: Center(child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                child: _buildPodium(state.topWinners),
              )))
            else
              const Spacer(),
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
            // Bet amount
            if (w.betAmount > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: Colors.black.withAlpha(80), borderRadius: BorderRadius.circular(10)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text('راهن: ', style: TextStyle(color: Colors.white54, fontSize: isFirst ? 9 : 8, fontFamily: 'Cairo')),
                  Text(_fmtNum(w.betAmount), style: TextStyle(color: Colors.white70, fontSize: isFirst ? 9 : 8, fontWeight: FontWeight.w700)),
                  const Text(' 🪙', style: TextStyle(fontSize: 9)),
                ]),
              ),
            const SizedBox(height: 2),
            // Win amount
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: Colors.black.withAlpha(100), borderRadius: BorderRadius.circular(14),
                border: Border.all(color: rcOrder[i].withAlpha(150))),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text('ربح: ', style: TextStyle(color: rcOrder[i].withAlpha(180), fontSize: isFirst ? 10 : 9, fontFamily: 'Cairo')),
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
          decoration: BoxDecoration(
            color: _kDeepTeal,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _kGold, width: 1.5),
            boxShadow: [BoxShadow(color: Colors.black.withAlpha(80), blurRadius: 12)],
          ),
          child: Text(_toast!, textAlign: TextAlign.center,
            style: const TextStyle(color: _kCream, fontFamily: 'Cairo', fontSize: 14, fontWeight: FontWeight.bold)),
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
          backgroundColor: const Color(0xFF071E22),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: _kGold, width: 2)),
          title: const Text('قواعد اللعبة', style: TextStyle(color: _kBrightGold, fontFamily: 'Cairo', fontWeight: FontWeight.w900, fontSize: 18), textAlign: TextAlign.center),
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
              decoration: BoxDecoration(color: _kDeepTeal.withAlpha(60), borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _kGold.withAlpha(80))),
              child: Column(children: _kFoods.map((f) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(children: [
                  Text(f.emoji, style: const TextStyle(fontSize: 18)),
                  const SizedBox(width: 8),
                  Expanded(child: Text(f.name,
                    style: const TextStyle(color: _kCream, fontFamily: 'Cairo', fontSize: 12))),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: f.hot ? const Color(0xFFB8400A) : _kRoyalPurple,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _kGold.withAlpha(120)),
                    ),
                    child: Text('${f.mult}×', style: const TextStyle(color: _kBrightGold, fontFamily: 'Cairo', fontWeight: FontWeight.w900, fontSize: 12)),
                  ),
                ]),
              )).toList()),
            ),
          ]),
          actions: [
            Center(child: TextButton(
              style: TextButton.styleFrom(backgroundColor: _kGold,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: _kBrightGold)),
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 8)),
              onPressed: () => Navigator.pop(context),
              child: const Text('فهمت! ✅', style: TextStyle(color: _kDarkBrown, fontFamily: 'Cairo', fontWeight: FontWeight.w900, fontSize: 15)),
            )),
          ],
        ),
      ),
    );
  }

  Widget _rule(String n, String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(width: 20, height: 20, decoration: const BoxDecoration(shape: BoxShape.circle, color: _kGold),
        child: Center(child: Text(n, style: const TextStyle(color: _kDarkBrown, fontSize: 11, fontWeight: FontWeight.w900)))),
      const SizedBox(width: 8),
      Expanded(child: Text(text, style: const TextStyle(color: _kCream, fontFamily: 'Cairo', fontSize: 12))),
    ]),
  );

  void _showRecords() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF071E22),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20)), side: BorderSide(color: _kGold, width: 2)),
      isScrollControlled: true,
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: DraggableScrollableSheet(
          expand: false, initialChildSize: 0.55, maxChildSize: 0.85,
          builder: (_, ctrl) => Column(children: [
            Padding(padding: const EdgeInsets.all(12),
              child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white30, borderRadius: BorderRadius.circular(2)))),
            const Text('سجل مشاركاتي', style: TextStyle(color: _kBrightGold, fontFamily: 'Cairo', fontWeight: FontWeight.w900, fontSize: 18)),
            const Divider(color: _kGold),
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
    if (v >= 1000000) {
      final d = v / 1000000;
      return '${d % 1 == 0 ? d.toInt() : d.toStringAsFixed(1)}M';
    }
    if (v >= 1000) {
      final d = v / 1000;
      return '${d % 1 == 0 ? d.toInt() : d.toStringAsFixed(1)}K';
    }
    return '$v';
  }

  // Full number with commas — shown below food bubble (e.g. 10,500)
  String _fmtFull(int v) {
    if (v >= 1000000) {
      final d = v / 1000000;
      return '${d % 1 == 0 ? d.toInt() : d.toStringAsFixed(1)}M';
    }
    return v.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
  }

  // Full number with commas for balance display
  String _fmtNumFull(int v) {
    if (v >= 1000000) {
      final d = v / 1000000;
      return '${d % 1 == 0 ? d.toInt() : d.toStringAsFixed(2)}M';
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
    // زخرف مصري: خطوط متقاطعة ذهبية خفيفة + علامة عنخ مصغّرة
    final linePaint = Paint()
      ..color = _kGold.withAlpha(18)
      ..strokeWidth = 0.6
      ..style = PaintingStyle.stroke;
    final dotPaint = Paint()
      ..color = _kTurquoise.withAlpha(25)
      ..style = PaintingStyle.fill;

    // شبكة خطوط متقاطعة خفيفة
    const step = 48.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), linePaint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
    }

    // نقاط تركواز عند كل تقاطع
    for (double cx = 0; cx < size.width + step; cx += step) {
      for (double cy = 0; cy < size.height + step; cy += step) {
        canvas.drawCircle(Offset(cx, cy), 2.0, dotPaint);
        // شكل لوتس مصغّر (دائرة مع خطوط بتلات)
        final petalPaint = Paint()
          ..color = _kGold.withAlpha(14)
          ..strokeWidth = 0.8
          ..style = PaintingStyle.stroke;
        for (int j = 0; j < 4; j++) {
          final a = j * pi / 2;
          canvas.drawLine(
            Offset(cx + 3 * cos(a), cy + 3 * sin(a)),
            Offset(cx + 8 * cos(a), cy + 8 * sin(a)),
            petalPaint,
          );
        }
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
    // خلفية العجلة الرئيسية — تركواز مصري
    canvas.drawCircle(Offset(cx, cy), r + 45,
      Paint()..shader = RadialGradient(
        colors: [_kTurquoise, _kDeepTeal, const Color(0xFF03383C)], radius: 0.85,
      ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: r + 45)));

    // الحلقة الخارجية الذهبية
    canvas.drawCircle(Offset(cx, cy), r + 36,
      Paint()..color = _kGold..style = PaintingStyle.stroke..strokeWidth = 6);
    canvas.drawCircle(Offset(cx, cy), r + 30,
      Paint()..color = _kBrightGold.withAlpha(80)..style = PaintingStyle.stroke..strokeWidth = 2);

    // حلقة داخلية ذهبية
    final innerRing = Paint()..color = _kGold..style = PaintingStyle.stroke..strokeWidth = 3.5;
    canvas.drawCircle(Offset(cx, cy), 50, innerRing);

    // الأذرع — بني داكن + ذهبي
    final spoke  = Paint()..color = _kDarkBrown..strokeWidth = 7..strokeCap = StrokeCap.round..style = PaintingStyle.stroke;
    final spokeL = Paint()..color = _kGold..strokeWidth = 1.5..strokeCap = StrokeCap.round..style = PaintingStyle.stroke;
    for (int i = 0; i < 8; i++) {
      final a = -pi / 2 + i * pi / 4;
      final sx = cx + 52 * cos(a); final sy = cy + 52 * sin(a);
      final ex = cx + (r + 12) * cos(a); final ey = cy + (r + 12) * sin(a);
      canvas.drawLine(Offset(sx, sy), Offset(ex, ey), spoke);
      canvas.drawLine(Offset(sx, sy), Offset(ex, ey), spokeL);
    }

    // الدائرة الوسطى
    canvas.drawCircle(Offset(cx, cy), 48,
      Paint()..shader = RadialGradient(colors: [_kDeepTeal, const Color(0xFF031A1C)])
          .createShader(Rect.fromCircle(center: Offset(cx, cy), radius: 50)));
    canvas.drawCircle(Offset(cx, cy), 48, innerRing);

    // الأرجل الداعمة
    final leg = Paint()..color = _kDarkBrown..strokeWidth = 8..strokeCap = StrokeCap.round..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(cx, cy + r + 30), Offset(cx - 40, size.height - 10), leg);
    canvas.drawLine(Offset(cx, cy + r + 30), Offset(cx + 40, size.height - 10), leg);
    canvas.drawLine(Offset(cx - 50, size.height - 10), Offset(cx + 50, size.height - 10), leg);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
