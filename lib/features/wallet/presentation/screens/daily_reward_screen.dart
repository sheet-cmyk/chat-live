import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../app/theme/app_colors.dart';
import '../../data/repositories/wallet_repository.dart';

class DailyRewardScreen extends ConsumerStatefulWidget {
  const DailyRewardScreen({super.key});

  @override
  ConsumerState<DailyRewardScreen> createState() => _DailyRewardScreenState();
}

class _DailyRewardScreenState extends ConsumerState<DailyRewardScreen>
    with SingleTickerProviderStateMixin {
  // عداد محلي للعرض السلس
  int _displaySeconds = -1; // -1 = تحميل
  Timer? _ticker;

  // اشتراك مباشر بالـ Stream لضمان استقبال القيمة الأولية فوراً
  StreamSubscription<int>? _streamSub;

  bool _claiming = false;
  bool _justClaimed = false;

  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pulseAnim = Tween(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    // يُشغّل tick كل ثانية لتحريك العداد
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        if (_displaySeconds > 0) _displaySeconds--;
      });
    });

    // الاشتراك بالـ Stream مباشرة → يُعطي القيمة الأولية فور فتح الشاشة
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      _streamSub = WalletRepository().watchDailyGiftSeconds(uid).listen((secs) {
        if (!mounted) return;
        // نُزامن فقط لما:
        // • أول قيمة (_displaySeconds == -1)
        // • أو بعد الاستلام (secs > 86000 يعني تجدّد)
        // • أو الفرق كبير (أكثر من 5 ثواني = انحراف)
        final shouldSync = _displaySeconds == -1 ||
            secs > _displaySeconds + 5 ||
            (secs == 0 && _displaySeconds > 5);
        if (shouldSync) {
          setState(() => _displaySeconds = secs);
        }
      });
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _streamSub?.cancel();
    _pulseCtrl.dispose();
    super.dispose();
  }

  Future<void> _claim() async {
    if (_claiming) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    setState(() => _claiming = true);
    try {
      final result = await WalletRepository().claimDailyGift(uid);
      if (!mounted) return;

      if (result.claimed) {
        setState(() {
          _justClaimed = true;
          _displaySeconds = 86400; // Stream سيُزامن القيمة الحقيقية تلقائياً
        });
      } else if (result.error != null) {
        _showSnack(result.error!);
      } else {
        // لم تنتهِ الـ 24 ساعة بعد
        setState(() => _displaySeconds = result.secondsRemaining);
      }
    } finally {
      if (mounted) setState(() => _claiming = false);
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontFamily: 'Cairo')),
      backgroundColor: Colors.red,
      behavior: SnackBarBehavior.floating,
    ));
  }

  String _formatTime(int totalSeconds) {
    final h = totalSeconds ~/ 3600;
    final m = (totalSeconds % 3600) ~/ 60;
    final s = totalSeconds % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final loading = _displaySeconds == -1;
    final canClaim = !loading && _displaySeconds <= 0 && !_justClaimed;

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D1A),
        elevation: 0,
        title: const Text(
          'المكافأة اليومية',
          style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700, color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white70),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.gold))
          : SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  _buildHeroCard(canClaim),
                  const SizedBox(height: 32),
                  _buildCountdownOrButton(canClaim),
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  Widget _buildHeroCard(bool canClaim) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A1040), Color(0xFF2D1B69)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.gold.withAlpha(60), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppColors.gold.withAlpha(30),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          ScaleTransition(
            scale: canClaim ? _pulseAnim : const AlwaysStoppedAnimation(1.0),
            child: Container(
              width: 100, height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.gold.withAlpha(80),
                    AppColors.gold.withAlpha(20),
                  ],
                ),
                border: Border.all(color: AppColors.gold, width: 2),
                boxShadow: canClaim
                    ? [BoxShadow(color: AppColors.gold.withAlpha(100), blurRadius: 20)]
                    : [],
              ),
              child: const Center(
                child: Text('🪙', style: TextStyle(fontSize: 44)),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'هدية يومية',
            style: TextStyle(
              fontFamily: 'Cairo', fontSize: 22,
              fontWeight: FontWeight.w800, color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('🪙', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 6),
              Text(
                '1,200,000 ذهب',
                style: TextStyle(
                  fontFamily: 'Cairo', fontSize: 20,
                  fontWeight: FontWeight.w900, color: AppColors.gold,
                  shadows: [Shadow(color: AppColors.gold.withAlpha(150), blurRadius: 8)],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'كل 24 ساعة',
            style: TextStyle(
              fontFamily: 'Cairo', fontSize: 13,
              color: Colors.white.withAlpha(120),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCountdownOrButton(bool canClaim) {
    if (_justClaimed) return _buildClaimedSuccess();
    if (canClaim) return _buildClaimButton();
    return _buildCountdown();
  }

  Widget _buildCountdown() {
    return Column(
      children: [
        const Text(
          'الوقت المتبقي للهدية القادمة',
          style: TextStyle(fontFamily: 'Cairo', fontSize: 14, color: Colors.white54),
        ),
        const SizedBox(height: 16),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 40),
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 30),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1040),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white12),
          ),
          child: Text(
            _formatTime(_displaySeconds),
            style: TextStyle(
              fontFamily: 'monospace', fontSize: 46,
              fontWeight: FontWeight.w900, color: AppColors.gold,
              letterSpacing: 4,
              shadows: [Shadow(color: AppColors.gold.withAlpha(120), blurRadius: 12)],
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 60),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Text('ساعة',  style: TextStyle(fontFamily: 'Cairo', fontSize: 11, color: Colors.white38)),
              Text('دقيقة', style: TextStyle(fontFamily: 'Cairo', fontSize: 11, color: Colors.white38)),
              Text('ثانية', style: TextStyle(fontFamily: 'Cairo', fontSize: 11, color: Colors.white38)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildClaimButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        children: [
          const Text(
            '🎉 هديتك جاهزة!',
            style: TextStyle(fontFamily: 'Cairo', fontSize: 16, color: Colors.white70),
          ),
          const SizedBox(height: 20),
          ScaleTransition(
            scale: _pulseAnim,
            child: GestureDetector(
              onTap: _claiming ? null : _claim,
              child: Container(
                width: double.infinity,
                height: 64,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.gold, Color(0xFFFFB300)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.gold.withAlpha(120),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Center(
                  child: _claiming
                      ? const SizedBox(
                          width: 26, height: 26,
                          child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2.5),
                        )
                      : const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('🎁', style: TextStyle(fontSize: 24)),
                            SizedBox(width: 10),
                            Text(
                              'استلم الهدية',
                              style: TextStyle(
                                fontFamily: 'Cairo', fontSize: 20,
                                fontWeight: FontWeight.w900, color: Colors.black,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClaimedSuccess() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 32),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.green.withAlpha(25),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.green.withAlpha(100)),
      ),
      child: Column(
        children: [
          const Text('✅', style: TextStyle(fontSize: 40)),
          const SizedBox(height: 12),
          const Text(
            'تم استلام هديتك!',
            style: TextStyle(
              fontFamily: 'Cairo', fontSize: 18,
              fontWeight: FontWeight.w800, color: Colors.greenAccent,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            '🪙 1,200,000 ذهب أُضيفت لحسابك',
            style: TextStyle(fontFamily: 'Cairo', fontSize: 14, color: Colors.white70),
          ),
          const SizedBox(height: 16),
          const Text(
            'الهدية القادمة خلال 24 ساعة',
            style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: Colors.white38),
          ),
          const SizedBox(height: 12),
          Text(
            _formatTime(_displaySeconds),
            style: const TextStyle(
              fontFamily: 'monospace', fontSize: 28,
              fontWeight: FontWeight.w800, color: AppColors.gold,
              letterSpacing: 3,
            ),
          ),
        ],
      ),
    );
  }
}
