import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../wallet/presentation/providers/wallet_provider.dart';

// ── رموز اللعبة ─────────────────────────────────────────────────────────────

class _Sym {
  final String emoji;
  final String name;
  final double mult3; // 3 متطابقة
  final double mult2; // 2 متطابقة (في أي موقع)
  const _Sym(this.emoji, this.name, this.mult3, this.mult2);
}

const _kSyms = [
  _Sym('🍒', 'كرز',    2.0,  0.5),
  _Sym('🍋', 'ليمون',  3.0,  0.5),
  _Sym('🍊', 'برتقال', 4.0,  0.5),
  _Sym('🍇', 'عنب',    5.0,  0.0),
  _Sym('🔔', 'جرس',    8.0,  0.0),
  _Sym('💎', 'ألماس', 15.0,  0.0),
  _Sym('7️⃣', 'سبعة', 25.0,  0.0),
];

const _kBets = [5000, 10000, 40000];

final _rng = Random();

// ── الشاشة الرئيسية ──────────────────────────────────────────────────────────

class SlotMachineScreen extends ConsumerStatefulWidget {
  const SlotMachineScreen({super.key});
  @override
  ConsumerState<SlotMachineScreen> createState() => _SlotMachineScreenState();
}

class _SlotMachineScreenState extends ConsumerState<SlotMachineScreen>
    with TickerProviderStateMixin {

  int _betIdx = 0; // 0=5K 1=10K 2=40K
  bool _spinning = false;
  bool _busy = false; // منع double-tap
  List<String> _results = ['🍒', '🍒', '🍒']; // ignore: prefer_final_fields
  List<bool> _stopped = [false, false, false];
  int? _winAmount;
  String? _message;
  bool _isWin = false;

  late AnimationController _winCtrl;
  late Animation<double> _winScale;

  @override
  void initState() {
    super.initState();
    _winCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _winScale = CurvedAnimation(parent: _winCtrl, curve: Curves.elasticOut);
  }

  @override
  void dispose() {
    _winCtrl.dispose();
    super.dispose();
  }

  // ── اختيار النتائج وحساب الربح ──────────────────────────────────────────

  List<String> _rollResults() {
    // زن الرموز حسب قيمتها — الأعلى قيمة أقل احتمالاً
    final weights = [30, 24, 18, 12, 8, 5, 3]; // مجموع=100
    String pick() {
      int r = _rng.nextInt(100);
      for (int i = 0; i < weights.length; i++) {
        r -= weights[i];
        if (r < 0) return _kSyms[i].emoji;
      }
      return _kSyms[0].emoji;
    }
    return [pick(), pick(), pick()];
  }

  int _calcWin(List<String> res, int bet) {
    if (res[0] == res[1] && res[1] == res[2]) {
      final sym = _kSyms.firstWhere((s) => s.emoji == res[0],
          orElse: () => _kSyms[0]);
      return (bet * sym.mult3).toInt();
    }
    if (res[0] == res[1] || res[1] == res[2] || res[0] == res[2]) {
      final matchEmoji = res[0] == res[1] ? res[0] : res[0] == res[2] ? res[0] : res[1];
      final sym = _kSyms.firstWhere((s) => s.emoji == matchEmoji,
          orElse: () => _kSyms[0]);
      if (sym.mult2 > 0) return (bet * sym.mult2).toInt();
    }
    return 0;
  }

  // ── تدوير ───────────────────────────────────────────────────────────────────

  Future<void> _spin() async {
    if (_spinning || _busy) return;
    final coins = ref.read(coinsProvider);
    final bet = _kBets[_betIdx];
    if (coins < bet) {
      _showMsg('رصيد غير كافٍ 😔', isWin: false);
      return;
    }

    setState(() {
      _spinning = true;
      _stopped = [false, false, false];
      _winAmount = null;
      _message = null;
      _busy = true;
    });
    HapticFeedback.mediumImpact();

    final results = _rollResults();
    final winAmount = _calcWin(results, bet);
    final net = winAmount - bet; // سالب = خسارة

    // وقف البكرات بشكل متتالي
    final delays = [1100, 1700, 2300];
    for (int i = 0; i < 3; i++) {
      Future.delayed(Duration(milliseconds: delays[i]), () {
        if (!mounted) return;
        setState(() {
          _results[i] = results[i];
          _stopped[i] = true;
        });
        if (i == 2) _onAllStopped(results, bet, net, winAmount);
      });
    }
  }

  Future<void> _onAllStopped(
      List<String> results, int bet, int net, int winAmount) async {
    setState(() => _spinning = false);

    // تحديث الرصيد في Firestore
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      try {
        final userRef = FirebaseFirestore.instance.collection('users').doc(uid);
        await FirebaseFirestore.instance.runTransaction((tx) async {
          final snap = await tx.get(userRef);
          final cur = (snap.data()?['coins'] as num?)?.toInt() ?? 0;
          tx.update(userRef, {'coins': FieldValue.increment(net)});
          // سجل اللعبة
          tx.set(
            userRef.collection('game_history').doc(),
            {
              'game': 'slot_machine',
              'bet': bet,
              'symbols': results,
              'winAmount': winAmount,
              'net': net,
              'balanceBefore': cur,
              'playedAt': FieldValue.serverTimestamp(),
            },
          );
        });
      } catch (_) {}
    }

    // إظهار النتيجة
    if (winAmount > 0) {
      final mult = winAmount / bet;
      setState(() {
        _winAmount = winAmount;
        _isWin = true;
        _message = results[0] == results[1] && results[1] == results[2]
            ? 'جاك بوت! 🎊  x${mult.toStringAsFixed(0)}'
            : 'ربحت! 🎉';
      });
      _winCtrl.forward(from: 0);
      HapticFeedback.heavyImpact();
    } else {
      setState(() { _isWin = false; _message = null; });
    }
    setState(() => _busy = false);
  }

  void _showMsg(String msg, {required bool isWin}) {
    setState(() { _message = msg; _isWin = isWin; });
  }

  // ── UI ───────────────────────────────────────────────────────────────────────

  String _fmt(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}م';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(n % 1000 == 0 ? 0 : 1)}ك';
    return '$n';
  }

  @override
  Widget build(BuildContext context) {
    final coins = ref.watch(coinsProvider);
    final bet   = _kBets[_betIdx];

    return Scaffold(
      backgroundColor: const Color(0xFF0D0011),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('🎰 Slot Machine',
            style: TextStyle(color: Colors.white, fontFamily: 'Cairo', fontWeight: FontWeight.w700)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // ── الرصيد ───────────────────────────────────────────────────
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF3D0070), Color(0xFF1A003A)]),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFFFD700).withAlpha(80)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('💰', style: TextStyle(fontSize: 22)),
                  const SizedBox(width: 8),
                  Text(
                    _fmt(coins),
                    style: const TextStyle(
                      color: Color(0xFFFFD700), fontSize: 22,
                      fontWeight: FontWeight.w800, fontFamily: 'Cairo',
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Text('عملة',
                      style: TextStyle(color: Colors.white54, fontFamily: 'Cairo', fontSize: 13)),
                ],
              ),
            ),

            const Spacer(),

            // ── آلة القمار ───────────────────────────────────────────────
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF2A0050), Color(0xFF1A002E)],
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFFFD700).withAlpha(100), width: 2),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFFD700).withAlpha(40),
                    blurRadius: 20, spreadRadius: 2,
                  ),
                ],
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // عنوان
                  const Text('🎰', style: TextStyle(fontSize: 36)),
                  const SizedBox(height: 12),

                  // البكرات الثلاث
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.black.withAlpha(120),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFFFD700).withAlpha(60)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: List.generate(3, (i) => _ReelWidget(
                        key: ValueKey(i),
                        spinning: _spinning && !_stopped[i],
                        finalEmoji: _results[i],
                        stopAfterMs: [1100, 1700, 2300][i],
                      )),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // خط الفوز
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(width: 60, height: 2,
                          color: const Color(0xFFFFD700).withAlpha(120)),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: Text('خط الفوز', style: TextStyle(
                            color: Color(0xFFFFD700), fontSize: 11,
                            fontFamily: 'Cairo', fontWeight: FontWeight.w600)),
                      ),
                      Container(width: 60, height: 2,
                          color: const Color(0xFFFFD700).withAlpha(120)),
                    ],
                  ),

                  // نتيجة
                  const SizedBox(height: 12),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: _message != null
                        ? ScaleTransition(
                            scale: _isWin ? _winScale : const AlwaysStoppedAnimation(1),
                            child: Container(
                              key: ValueKey(_message),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: _isWin
                                    ? const Color(0xFFFFD700).withAlpha(30)
                                    : Colors.redAccent.withAlpha(30),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _isWin ? const Color(0xFFFFD700) : Colors.redAccent,
                                  width: 1.5,
                                ),
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    _message!,
                                    style: TextStyle(
                                      color: _isWin ? const Color(0xFFFFD700) : Colors.redAccent,
                                      fontFamily: 'Cairo', fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  if (_winAmount != null) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      '+ ${_fmt(_winAmount!)} عملة 🪙',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontFamily: 'Cairo', fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          )
                        : const SizedBox(key: ValueKey('empty'), height: 48),
                  ),
                ],
              ),
            ),

            const Spacer(),

            // ── الرهان ───────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(right: 4, bottom: 8),
                    child: Text('الرهان:',
                        style: TextStyle(color: Colors.white54, fontFamily: 'Cairo', fontSize: 12)),
                  ),
                  Row(
                    children: List.generate(_kBets.length, (i) {
                      final selected = _betIdx == i;
                      return Expanded(
                        child: GestureDetector(
                          onTap: _spinning ? null : () => setState(() => _betIdx = i),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: EdgeInsets.only(
                              left: i > 0 ? 8 : 0,
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              gradient: selected
                                  ? const LinearGradient(colors: [Color(0xFFFFD700), Color(0xFFF0A500)])
                                  : null,
                              color: selected ? null : const Color(0xFF2A0050),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: selected ? const Color(0xFFFFD700) : Colors.white24,
                              ),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  _fmt(_kBets[i]),
                                  style: TextStyle(
                                    color: selected ? Colors.black : Colors.white,
                                    fontFamily: 'Cairo', fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                Text(
                                  'عملة',
                                  style: TextStyle(
                                    color: selected ? Colors.black87 : Colors.white38,
                                    fontFamily: 'Cairo', fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ── زر الدوران ───────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: SizedBox(
                width: double.infinity,
                height: 58,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  child: ElevatedButton(
                    onPressed: (_spinning || _busy) ? null : _spin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFFD700),
                      disabledBackgroundColor: const Color(0xFF555555),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: _spinning ? 0 : 8,
                      shadowColor: const Color(0xFFFFD700).withAlpha(120),
                    ),
                    child: _spinning
                        ? const SizedBox(
                            width: 24, height: 24,
                            child: CircularProgressIndicator(
                              color: Colors.black, strokeWidth: 2.5,
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text('🎰', style: TextStyle(fontSize: 20)),
                              const SizedBox(width: 10),
                              Text(
                                'دوّر  |  ${_fmt(bet)} عملة',
                                style: const TextStyle(
                                  color: Colors.black,
                                  fontFamily: 'Cairo', fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // ── جدول المكاسب ────────────────────────────────────────────
            GestureDetector(
              onTap: () => _showPaytable(context),
              child: const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.info_outline_rounded, color: Colors.white38, size: 14),
                    SizedBox(width: 4),
                    Text('جدول المكاسب',
                        style: TextStyle(color: Colors.white38, fontFamily: 'Cairo', fontSize: 12)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPaytable(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A002E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 36, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            const Text('🏆 جدول المكاسب', style: TextStyle(color: Color(0xFFFFD700), fontFamily: 'Cairo', fontSize: 15, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            ..._kSyms.reversed.map((s) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  SizedBox(
                    width: 56,
                    child: Text('${s.emoji}${s.emoji}${s.emoji}',
                        style: const TextStyle(fontSize: 15),
                        overflow: TextOverflow.clip),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(s.name,
                        style: const TextStyle(color: Colors.white70, fontFamily: 'Cairo', fontSize: 13),
                        overflow: TextOverflow.ellipsis),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFD700).withAlpha(30),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFFFD700).withAlpha(80)),
                    ),
                    child: Text(
                      'x${s.mult3.toStringAsFixed(0)}',
                      style: const TextStyle(color: Color(0xFFFFD700), fontFamily: 'Cairo', fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            )),
            const SizedBox(height: 8),
            const Divider(color: Colors.white12),
            const Text(
              'أي رمزين متطابقان من 🍒🍋🍊 → ×0.5',
              style: TextStyle(color: Colors.white38, fontFamily: 'Cairo', fontSize: 11),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ── بكرة واحدة ───────────────────────────────────────────────────────────────

class _ReelWidget extends StatefulWidget {
  const _ReelWidget({
    super.key,
    required this.spinning,
    required this.finalEmoji,
    required this.stopAfterMs,
  });
  final bool spinning;
  final String finalEmoji;
  final int stopAfterMs;

  @override
  State<_ReelWidget> createState() => _ReelWidgetState();
}

class _ReelWidgetState extends State<_ReelWidget> with SingleTickerProviderStateMixin {
  String _current = '🍒';
  Timer? _shuffleTimer;
  int _frame = 0;
  static final _emojiList = _kSyms.map((s) => s.emoji).toList();

  @override
  void initState() {
    super.initState();
    _current = widget.finalEmoji;
  }

  @override
  void didUpdateWidget(_ReelWidget old) {
    super.didUpdateWidget(old);
    if (widget.spinning && !old.spinning) {
      _startSpin();
    }
    if (!widget.spinning && old.spinning) {
      _stopSpin();
    }
  }

  void _startSpin() {
    _shuffleTimer?.cancel();
    _shuffleTimer = Timer.periodic(const Duration(milliseconds: 90), (_) {
      if (!mounted) return;
      setState(() {
        _frame++;
        _current = _emojiList[_frame % _emojiList.length];
      });
    });
  }

  void _stopSpin() {
    _shuffleTimer?.cancel();
    _shuffleTimer = null;
    if (!mounted) return;
    setState(() => _current = widget.finalEmoji);
  }

  @override
  void dispose() {
    _shuffleTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 88,
      height: 88,
      margin: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(160),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: widget.spinning
              ? const Color(0xFFFFD700).withAlpha(200)
              : Colors.white.withAlpha(30),
          width: widget.spinning ? 2 : 1,
        ),
        boxShadow: widget.spinning
            ? [BoxShadow(color: const Color(0xFFFFD700).withAlpha(60), blurRadius: 10, spreadRadius: 1)]
            : [],
      ),
      child: Center(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 80),
          transitionBuilder: (child, anim) => FadeTransition(
            opacity: anim, child: child,
          ),
          child: Text(
            _current,
            key: ValueKey('$_current$_frame'),
            style: const TextStyle(fontSize: 42),
          ),
        ),
      ),
    );
  }
}
