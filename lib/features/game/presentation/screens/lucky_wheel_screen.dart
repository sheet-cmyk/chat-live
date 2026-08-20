import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../app/theme/app_colors.dart';

class _WheelPrize {
  final String label;
  final String emoji;
  final int coins;
  final Color color;
  const _WheelPrize(this.label, this.emoji, this.coins, this.color);
}

const _prizes = [
  _WheelPrize('10 عملة',    '🪙', 10,   Color(0xFF6C5CE7)),
  _WheelPrize('50 عملة',    '💰', 50,   Color(0xFFE17055)),
  _WheelPrize('خسارة',       '💀', 0,    Color(0xFF636E72)),
  _WheelPrize('100 عملة',   '🤑', 100,  Color(0xFF00B894)),
  _WheelPrize('30 عملة',    '🪙', 30,   Color(0xFFFD79A8)),
  _WheelPrize('500 عملة',   '💎', 500,  Color(0xFFFFD700)),
  _WheelPrize('خسارة',       '😢', 0,    Color(0xFF636E72)),
  _WheelPrize('200 عملة',   '🏆', 200,  Color(0xFF0984E3)),
];

final _spinningProvider = StateProvider<bool>((ref) => false);
final _resultProvider   = StateProvider<_WheelPrize?>((ref) => null);
final _angleProvider    = StateProvider<double>((ref) => 0);

class LuckyWheelScreen extends ConsumerStatefulWidget {
  const LuckyWheelScreen({super.key});

  @override
  ConsumerState<LuckyWheelScreen> createState() => _LuckyWheelScreenState();
}

class _LuckyWheelScreenState extends ConsumerState<LuckyWheelScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;
  static const _spinCost = 20;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 4));
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.decelerate);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _spin() async {
    if (ref.read(_spinningProvider)) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    // خصم تكلفة الدوران
    final userRef = FirebaseFirestore.instance.collection('users').doc(uid);
    final ok = await FirebaseFirestore.instance.runTransaction<bool>((tx) async {
      final snap = await tx.get(userRef);
      final coins = (snap.data()?['coins'] as num?)?.toInt() ?? 0;
      if (coins < _spinCost) return false;
      tx.update(userRef, {'coins': FieldValue.increment(-_spinCost)});
      return true;
    });

    if (!ok) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('رصيدك غير كافٍ! تحتاج 20 🪙', style: TextStyle(fontFamily: 'Cairo'))),
        );
      }
      return;
    }

    ref.read(_spinningProvider.notifier).state = true;
    ref.read(_resultProvider.notifier).state = null;

    final rng = Random();
    final winIdx = rng.nextInt(_prizes.length);
    final slice = (2 * pi) / _prizes.length;
    // الزاوية النهائية = دورات كاملة + موضع الجائزة
    final target = ref.read(_angleProvider) + (2 * pi * 6) + (slice * winIdx);

    _anim = Tween<double>(begin: ref.read(_angleProvider), end: target).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.decelerate),
    );
    _ctrl.forward(from: 0);

    _ctrl.addStatusListener((status) async {
      if (status == AnimationStatus.completed) {
        ref.read(_angleProvider.notifier).state = target % (2 * pi);
        final prize = _prizes[winIdx];
        ref.read(_resultProvider.notifier).state = prize;
        ref.read(_spinningProvider.notifier).state = false;

        if (prize.coins > 0) {
          await userRef.update({'coins': FieldValue.increment(prize.coins)});
        }

        _ctrl.removeStatusListener((_) {});
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final spinning = ref.watch(_spinningProvider);
    final result = ref.watch(_resultProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: AppColors.textPrimary, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('عجلة الحظ 🎡', style: TextStyle(
          color: AppColors.textPrimary, fontFamily: 'Cairo', fontWeight: FontWeight.w700,
        )),
        centerTitle: true,
      ),
      body: Column(
        children: [
          const SizedBox(height: 20),

          // تكلفة الدوران
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.divider),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('🪙', style: TextStyle(fontSize: 16)),
                SizedBox(width: 6),
                Text('$_spinCost عملة للدوران', style: TextStyle(
                  color: AppColors.textSecondary, fontFamily: 'Cairo', fontWeight: FontWeight.w600,
                )),
              ],
            ),
          ),

          const SizedBox(height: 30),

          // العجلة
          SizedBox(
            width: 300, height: 300,
            child: Stack(
              alignment: Alignment.center,
              children: [
                AnimatedBuilder(
                  animation: _anim,
                  builder: (_, __) => Transform.rotate(
                    angle: _anim.value,
                    child: CustomPaint(
                      size: const Size(300, 300),
                      painter: _WheelPainter(),
                    ),
                  ),
                ),
                // مؤشر
                Positioned(
                  top: 0,
                  child: Container(
                    width: 18, height: 30,
                    decoration: const BoxDecoration(
                      color: AppColors.error,
                      borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
                    ),
                  ),
                ),
                // مركز العجلة
                Container(
                  width: 50, height: 50,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: AppColors.primaryGradient,
                  ),
                  child: const Icon(Icons.star_rounded, color: Colors.white, size: 28),
                ),
              ],
            ),
          ),

          const SizedBox(height: 30),

          // نتيجة الدوران
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            child: result != null
                ? Container(
                    key: ValueKey(result.label),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        Text(result.emoji, style: const TextStyle(fontSize: 36)),
                        const SizedBox(height: 6),
                        Text(
                          result.coins > 0 ? 'مبروك! ${result.label}' : 'حظ أوفر المرة القادمة',
                          style: const TextStyle(
                            color: Colors.white, fontFamily: 'Cairo', fontWeight: FontWeight.w700, fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  )
                : const SizedBox(height: 80, key: ValueKey('empty')),
          ),

          const Spacer(),

          // زر الدوران
          Padding(
            padding: const EdgeInsets.fromLTRB(32, 0, 32, 32),
            child: SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: spinning ? null : _spin,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  disabledBackgroundColor: AppColors.surfaceLight,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: spinning
                    ? const SizedBox(
                        width: 24, height: 24,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Text('🎡 دوّر العجلة', style: TextStyle(
                        color: Colors.white, fontFamily: 'Cairo', fontWeight: FontWeight.w800, fontSize: 16,
                      )),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WheelPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final slice = (2 * pi) / _prizes.length;
    final textPainter = TextPainter(textDirection: TextDirection.rtl);

    for (int i = 0; i < _prizes.length; i++) {
      final start = slice * i - pi / 2;
      final paint = Paint()..color = _prizes[i].color;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        start, slice, true, paint,
      );

      // خط الفاصل
      final divider = Paint()..color = Colors.white..strokeWidth = 2;
      final endX = center.dx + radius * cos(start);
      final endY = center.dy + radius * sin(start);
      canvas.drawLine(center, Offset(endX, endY), divider);

      // النص
      final mid = start + slice / 2;
      final textR = radius * 0.62;
      final tx = center.dx + textR * cos(mid);
      final ty = center.dy + textR * sin(mid);

      canvas.save();
      canvas.translate(tx, ty);
      canvas.rotate(mid + pi / 2);

      textPainter.text = TextSpan(
        text: _prizes[i].emoji,
        style: const TextStyle(fontSize: 20),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(-textPainter.width / 2, -textPainter.height / 2));

      canvas.restore();
    }

    // حلقة خارجية
    final border = Paint()
      ..color = Colors.white.withAlpha(60)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawCircle(center, radius, border);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
