import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../wallet/data/repositories/wallet_repository.dart';
import '../../../wallet/presentation/providers/wallet_provider.dart';
import '../widgets/game_widgets.dart';

enum _CoinSide { heads, tails }

class CoinFlipScreen extends ConsumerStatefulWidget {
  const CoinFlipScreen({super.key});

  @override
  ConsumerState<CoinFlipScreen> createState() => _CoinFlipScreenState();
}

class _CoinFlipScreenState extends ConsumerState<CoinFlipScreen>
    with SingleTickerProviderStateMixin {
  final _repo = WalletRepository();
  final _rng = Random();

  int _bet = 1000;
  _CoinSide? _chosen;
  bool _isHeads = true;
  bool _flipping = false;
  String? _resultMsg;
  bool? _won;

  late AnimationController _ctrl;
  late Animation<double> _flip;

  static const _bets = [100, 500, 1000, 5000, 10000, 50000];

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _flip = Tween(begin: 0.0, end: 4 * pi).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _play() async {
    if (_chosen == null) { _snack('اختر صورة أو كتابة أولاً'); return; }
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    if (ref.read(coinsProvider) < _bet) { _snack('رصيدك غير كافٍ'); return; }

    setState(() { _flipping = true; _resultMsg = null; _won = null; });

    final ok = await _repo.deductCoins(uid, _bet, 'رهان العملة - $_bet عملة');
    if (!ok) { setState(() => _flipping = false); _snack('فشل خصم العملات'); return; }

    await _ctrl.forward(from: 0);
    final result = _rng.nextBool();
    final userWon = (_chosen == _CoinSide.heads) == result;
    if (userWon) await _repo.addCoins(uid, _bet * 2, 'ربح العملة 🪙 +${_bet * 2} عملة');

    if (mounted) {
      setState(() {
        _isHeads = result;
        _won = userWon;
        _resultMsg = userWon ? 'فزت! +$_bet عملة صافي 🎉' : 'خسرت $_bet عملة 😢';
        _flipping = false;
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
        title: const Text('عملة أو كتابة 🪙', style: TextStyle(color: AppColors.textPrimary, fontFamily: 'Cairo', fontWeight: FontWeight.w700)),
        centerTitle: true,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_rounded, color: AppColors.textPrimary, size: 18), onPressed: () => Navigator.pop(context)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            GameBalanceBar(coins: coins),
            const SizedBox(height: 32),

            AnimatedBuilder(
              animation: _flip,
              builder: (_, __) {
                final angle = _flipping ? _flip.value : 0.0;
                final showFront = (angle % (2 * pi)) < pi;
                final displayHeads = _flipping ? showFront : _isHeads;
                return Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()..rotateY(angle),
                  child: Container(
                    width: 110, height: 110,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(colors: displayHeads
                          ? [const Color(0xFFFFD700), const Color(0xFFFF8C00)]
                          : [const Color(0xFFB0BEC5), const Color(0xFF607D8B)]),
                      boxShadow: [BoxShadow(color: Colors.amber.withAlpha(80), blurRadius: 20)],
                    ),
                    child: Center(child: Text(displayHeads ? '👑' : '✍️', style: const TextStyle(fontSize: 44))),
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
            Text(!_flipping ? (_isHeads ? 'صورة 👑' : 'كتابة ✍️') : '',
                style: const TextStyle(color: AppColors.textSecondary, fontFamily: 'Cairo', fontSize: 14)),

            if (!_flipping && _resultMsg != null) ...[
              const SizedBox(height: 12),
              GameResultBanner(message: _resultMsg!, won: _won!),
            ],

            const SizedBox(height: 24),
            const Text('اختر توقعك', style: TextStyle(color: AppColors.textSecondary, fontFamily: 'Cairo', fontSize: 14)),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: GameChoiceBtn(label: 'صورة', emoji: '👑', selected: _chosen == _CoinSide.heads, onTap: () => setState(() => _chosen = _CoinSide.heads))),
              const SizedBox(width: 12),
              Expanded(child: GameChoiceBtn(label: 'كتابة', emoji: '✍️', selected: _chosen == _CoinSide.tails, onTap: () => setState(() => _chosen = _CoinSide.tails))),
            ]),
            const SizedBox(height: 24),
            const Text('مبلغ الرهان', style: TextStyle(color: AppColors.textSecondary, fontFamily: 'Cairo', fontSize: 14)),
            const SizedBox(height: 10),
            GameBetSelector(bets: _bets, selected: _bet, onSelect: (v) => setState(() => _bet = v)),
            const SizedBox(height: 28),
            GamePlayButton(loading: _flipping, bet: _bet, onTap: _play),
            const SizedBox(height: 12),
            const Text('الفوز = 2× الرهان | الخسارة = رهانك كله', style: TextStyle(color: AppColors.textHint, fontFamily: 'Cairo', fontSize: 11)),
          ],
        ),
      ),
    );
  }
}
