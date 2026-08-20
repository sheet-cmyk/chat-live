import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../wallet/data/repositories/wallet_repository.dart';
import '../../../wallet/presentation/providers/wallet_provider.dart';
import '../widgets/game_widgets.dart';

class NumberGuessScreen extends ConsumerStatefulWidget {
  const NumberGuessScreen({super.key});

  @override
  ConsumerState<NumberGuessScreen> createState() => _NumberGuessScreenState();
}

class _NumberGuessScreenState extends ConsumerState<NumberGuessScreen>
    with SingleTickerProviderStateMixin {
  final _repo = WalletRepository();
  final _rng = Random();

  int _bet = 1000;
  int? _chosen;
  int? _result;
  bool _playing = false;
  String? _resultMsg;
  bool? _won;

  late AnimationController _ctrl;
  late Animation<double> _scale;

  static const _bets = [100, 500, 1000, 5000, 10000, 50000];

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _scale = CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _play() async {
    if (_chosen == null) { _snack('اختر رقماً من 1 إلى 5 أولاً'); return; }
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    if (ref.read(coinsProvider) < _bet) { _snack('رصيدك غير كافٍ'); return; }

    setState(() { _playing = true; _resultMsg = null; _won = null; _result = null; });

    final ok = await _repo.deductCoins(uid, _bet, 'تخمين الرقم - $_bet عملة');
    if (!ok) { setState(() => _playing = false); _snack('فشل خصم العملات'); return; }

    await Future.delayed(const Duration(milliseconds: 600));
    final result = _rng.nextInt(5) + 1;
    final userWon = result == _chosen;
    if (userWon) await _repo.addCoins(uid, _bet * 4, 'ربح التخمين 🔢 +${_bet * 4} عملة');

    _ctrl.forward(from: 0);

    if (mounted) {
      setState(() {
        _result = result;
        _won = userWon;
        _resultMsg = userWon ? 'خمّنت! +${_bet * 3} عملة صافي 🎉' : 'الرقم كان $result — خسرت $_bet عملة 😢';
        _playing = false;
      });
    }
  }

  void _snack(String msg) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(msg, style: const TextStyle(fontFamily: 'Cairo')), backgroundColor: AppColors.surface),
  );

  @override
  Widget build(BuildContext context) {
    final coins = ref.watch(coinsProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: const Text('خمّن الرقم 🔢', style: TextStyle(color: AppColors.textPrimary, fontFamily: 'Cairo', fontWeight: FontWeight.w700)),
        centerTitle: true,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_rounded, color: AppColors.textPrimary, size: 18), onPressed: () => Navigator.pop(context)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            GameBalanceBar(coins: coins),
            const SizedBox(height: 28),

            // عرض النتيجة
            ScaleTransition(
              scale: _result != null ? _scale : const AlwaysStoppedAnimation(1),
              child: Container(
                width: 110, height: 110,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: _won == null
                        ? [const Color(0xFF00B894), const Color(0xFF00796B)]
                        : _won!
                            ? [const Color(0xFF00B894), const Color(0xFF00796B)]
                            : [const Color(0xFFE17055), const Color(0xFFD63031)],
                  ),
                  boxShadow: [BoxShadow(color: const Color(0xFF00B894).withAlpha(80), blurRadius: 20)],
                ),
                child: Center(
                  child: _playing
                      ? const SizedBox(width: 36, height: 36, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                      : Text(
                          _result != null ? '$_result' : '?',
                          style: const TextStyle(color: Colors.white, fontSize: 48, fontWeight: FontWeight.w900),
                        ),
                ),
              ),
            ),
            const SizedBox(height: 8),

            if (!_playing && _resultMsg != null) ...[
              const SizedBox(height: 12),
              GameResultBanner(message: _resultMsg!, won: _won!),
              const SizedBox(height: 8),
            ],

            const SizedBox(height: 20),
            const Text('اختر رقمًا من 1 إلى 5', style: TextStyle(color: AppColors.textSecondary, fontFamily: 'Cairo', fontSize: 14)),
            const SizedBox(height: 12),

            // أزرار الأرقام
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(5, (i) {
                final n = i + 1;
                final isSel = _chosen == n;
                final isRight = _result == n;
                Color? borderColor;
                if (_result != null) {
                  borderColor = isRight ? AppColors.success : (isSel && !_won! ? AppColors.error : AppColors.divider);
                }
                return GestureDetector(
                  onTap: _playing ? null : () => setState(() { _chosen = n; _resultMsg = null; _won = null; _result = null; }),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 56, height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSel ? AppColors.primary.withAlpha(40) : AppColors.card,
                      border: Border.all(
                        color: borderColor ?? (isSel ? AppColors.primary : AppColors.divider),
                        width: isSel || isRight ? 2.5 : 1,
                      ),
                    ),
                    child: Center(
                      child: Text('$n', style: TextStyle(
                        color: isSel ? AppColors.primary : AppColors.textPrimary,
                        fontSize: 22, fontWeight: FontWeight.w800,
                      )),
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 28),
            const Text('مبلغ الرهان', style: TextStyle(color: AppColors.textSecondary, fontFamily: 'Cairo', fontSize: 14)),
            const SizedBox(height: 10),
            GameBetSelector(bets: _bets, selected: _bet, onSelect: (v) => setState(() => _bet = v)),
            const SizedBox(height: 28),
            GamePlayButton(loading: _playing, bet: _bet, onTap: _play),
            const SizedBox(height: 12),
            const Text('الفوز = 4× الرهان (صافي 3×) | احتمال الفوز 1 من 5', style: TextStyle(color: AppColors.textHint, fontFamily: 'Cairo', fontSize: 11)),
          ],
        ),
      ),
    );
  }
}
