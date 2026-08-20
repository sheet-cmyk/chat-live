import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../wallet/data/repositories/wallet_repository.dart';
import '../../../wallet/presentation/providers/wallet_provider.dart';
import '../widgets/game_widgets.dart';

enum _DiceBet { even, odd }

class DiceBettingScreen extends ConsumerStatefulWidget {
  const DiceBettingScreen({super.key});

  @override
  ConsumerState<DiceBettingScreen> createState() => _DiceBettingScreenState();
}

class _DiceBettingScreenState extends ConsumerState<DiceBettingScreen>
    with SingleTickerProviderStateMixin {
  final _repo = WalletRepository();
  final _rng = Random();

  int _bet = 1000;
  _DiceBet? _chosen;
  int _diceResult = 1;
  bool _rolling = false;
  String? _resultMsg;
  bool? _won;

  late AnimationController _ctrl;
  late Animation<double> _rotate;

  static const _bets = [100, 500, 1000, 5000, 10000, 50000];
  static const _diceFaces = ['⚀', '⚁', '⚂', '⚃', '⚄', '⚅'];

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _rotate = Tween(begin: 0.0, end: 6 * pi).animate(CurvedAnimation(parent: _ctrl, curve: Curves.decelerate));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _roll() async {
    if (_chosen == null) { _snack('اختر زوجي أو فردي أولاً'); return; }
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    if (ref.read(coinsProvider) < _bet) { _snack('رصيدك غير كافٍ'); return; }

    setState(() { _rolling = true; _resultMsg = null; _won = null; });

    final ok = await _repo.deductCoins(uid, _bet, 'مراهنة النرد - $_bet عملة');
    if (!ok) { setState(() => _rolling = false); _snack('فشل خصم العملات'); return; }

    await _ctrl.forward(from: 0);
    final result = _rng.nextInt(6) + 1;
    final userWon = (_chosen == _DiceBet.even) == (result % 2 == 0);
    if (userWon) await _repo.addCoins(uid, _bet * 2, 'ربح النرد 🎲 +${_bet * 2} عملة');

    if (mounted) {
      setState(() {
        _diceResult = result;
        _won = userWon;
        _resultMsg = userWon ? 'فزت! +$_bet عملة صافي 🎉' : 'خسرت $_bet عملة 😢';
        _rolling = false;
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
        title: const Text('لعبة النرد 🎲', style: TextStyle(color: AppColors.textPrimary, fontFamily: 'Cairo', fontWeight: FontWeight.w700)),
        centerTitle: true,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_rounded, color: AppColors.textPrimary, size: 18), onPressed: () => Navigator.pop(context)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            GameBalanceBar(coins: coins),
            const SizedBox(height: 28),

            AnimatedBuilder(
              animation: _rotate,
              builder: (_, __) => Transform.rotate(
                angle: _rolling ? _rotate.value : 0,
                child: Text(_diceFaces[_diceResult - 1], style: const TextStyle(fontSize: 96)),
              ),
            ),
            Text('النتيجة: $_diceResult', style: const TextStyle(color: AppColors.textSecondary, fontFamily: 'Cairo', fontSize: 13)),

            if (!_rolling && _resultMsg != null) ...[
              const SizedBox(height: 12),
              GameResultBanner(message: _resultMsg!, won: _won!),
              const SizedBox(height: 8),
            ],

            const SizedBox(height: 20),
            const Text('اختر توقعك', style: TextStyle(color: AppColors.textSecondary, fontFamily: 'Cairo', fontSize: 14)),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: GameChoiceBtn(label: 'زوجي', emoji: '2️⃣', selected: _chosen == _DiceBet.even, onTap: () => setState(() => _chosen = _DiceBet.even))),
              const SizedBox(width: 12),
              Expanded(child: GameChoiceBtn(label: 'فردي', emoji: '1️⃣', selected: _chosen == _DiceBet.odd, onTap: () => setState(() => _chosen = _DiceBet.odd))),
            ]),
            const SizedBox(height: 24),
            const Text('مبلغ الرهان', style: TextStyle(color: AppColors.textSecondary, fontFamily: 'Cairo', fontSize: 14)),
            const SizedBox(height: 10),
            GameBetSelector(bets: _bets, selected: _bet, onSelect: (v) => setState(() => _bet = v)),
            const SizedBox(height: 28),

            GamePlayButton(loading: _rolling, bet: _bet, onTap: _roll),
            const SizedBox(height: 12),
            const Text('الفوز = 2× الرهان | الخسارة = رهانك كله', style: TextStyle(color: AppColors.textHint, fontFamily: 'Cairo', fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

