import 'dart:math';
import 'package:flutter/material.dart';

class NightSkyBackground extends StatefulWidget {
  const NightSkyBackground({super.key});

  @override
  State<NightSkyBackground> createState() => _NightSkyBackgroundState();
}

class _NightSkyBackgroundState extends State<NightSkyBackground>
    with TickerProviderStateMixin {
  late AnimationController _moonCtrl;
  late AnimationController _starCtrl;
  late AnimationController _shootCtrl;

  final _rng = Random();
  final List<_Star> _stars = [];
  _ShootingStar? _shooting;
  bool _starsGenerated = false;

  @override
  void initState() {
    super.initState();

    // القمر يتحرك من اليمين إلى اليسار كل 80 ثانية
    _moonCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 80),
    )..repeat();

    // بريق النجوم — دورة 4 ثوانٍ
    _starCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    // الشهاب — مدة 0.9 ثانية لكل شهاب
    _shootCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _scheduleShootingStar();
  }

  void _generateStars() {
    if (_starsGenerated) return;
    _starsGenerated = true;
    for (int i = 0; i < 65; i++) {
      _stars.add(_Star(
        x: _rng.nextDouble(),
        y: _rng.nextDouble() * 0.72,
        radius: 0.7 + _rng.nextDouble() * 1.6,
        phase: _rng.nextDouble() * 2 * pi,
        brightness: 0.55 + _rng.nextDouble() * 0.45,
      ));
    }
  }

  Future<void> _scheduleShootingStar() async {
    final ms = 3000 + _rng.nextInt(5000);
    await Future.delayed(Duration(milliseconds: ms));
    if (!mounted) return;
    setState(() {
      _shooting = _ShootingStar(
        startX: 0.55 + _rng.nextDouble() * 0.42,
        startY: _rng.nextDouble() * 0.22,
      );
    });
    await _shootCtrl.forward(from: 0);
    if (!mounted) return;
    setState(() => _shooting = null);
    _scheduleShootingStar();
  }

  @override
  void dispose() {
    _moonCtrl.dispose();
    _starCtrl.dispose();
    _shootCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _generateStars();
    return AnimatedBuilder(
      animation: Listenable.merge([_moonCtrl, _starCtrl, _shootCtrl]),
      builder: (ctx, _) {
        final size = MediaQuery.of(ctx).size;
        return CustomPaint(
          size: size,
          painter: _SkyPainter(
            moonT: _moonCtrl.value,
            starT: _starCtrl.value,
            stars: _stars,
            shooting: _shooting,
            shootT: _shootCtrl.value,
          ),
        );
      },
    );
  }
}

// ── بيانات النجم ──────────────────────────────────────────────────────────
class _Star {
  final double x, y, radius, phase, brightness;
  const _Star({
    required this.x,
    required this.y,
    required this.radius,
    required this.phase,
    required this.brightness,
  });
}

// ── بيانات الشهاب ─────────────────────────────────────────────────────────
class _ShootingStar {
  final double startX, startY;
  const _ShootingStar({required this.startX, required this.startY});
}

// ── الرسام الرئيسي ────────────────────────────────────────────────────────
class _SkyPainter extends CustomPainter {
  final double moonT, starT, shootT;
  final List<_Star> stars;
  final _ShootingStar? shooting;

  const _SkyPainter({
    required this.moonT,
    required this.starT,
    required this.stars,
    required this.shooting,
    required this.shootT,
  });

  @override
  void paint(Canvas canvas, Size size) {
    _drawStars(canvas, size);
    _drawMoon(canvas, size);
    _drawShooting(canvas, size);
  }

  // ── النجوم ───────────────────────────────────────────────────────────────
  void _drawStars(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    for (final s in stars) {
      final twinkle = 0.35 + 0.65 * (0.5 + 0.5 * sin(starT * 2 * pi + s.phase));
      final alpha = (s.brightness * twinkle * 230).round().clamp(0, 255);
      paint.color = Colors.white.withAlpha(alpha);
      canvas.drawCircle(
        Offset(s.x * size.width, s.y * size.height),
        s.radius * twinkle,
        paint,
      );
    }
  }

  // ── القمر ─────────────────────────────────────────────────────────────────
  void _drawMoon(Canvas canvas, Size size) {
    // يتحرك من اليمين (x=1.12) إلى اليسار (x=-0.12)
    final mx = (1.12 - moonT * 1.24) * size.width;
    final my = size.height * 0.11;
    const mr = 26.0;

    // توهج القمر
    canvas.drawCircle(
      Offset(mx, my),
      mr + 22,
      Paint()
        ..color = const Color(0xFFFFE87C).withAlpha(22)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18),
    );
    canvas.drawCircle(
      Offset(mx, my),
      mr + 10,
      Paint()
        ..color = const Color(0xFFFFEE90).withAlpha(35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );

    // جسم القمر — تدرج من أبيض-أصفر إلى ذهبي
    final moonRect = Rect.fromCircle(center: Offset(mx, my), radius: mr);
    canvas.drawCircle(
      Offset(mx, my),
      mr,
      Paint()
        ..shader = const RadialGradient(
          colors: [
            Color(0xFFFFFDE7),
            Color(0xFFFFEE90),
            Color(0xFFFFCA28),
          ],
          center: Alignment(-0.35, -0.35),
          radius: 1.0,
        ).createShader(moonRect),
    );

    // فوهات (Craters) — دوائر أغمق شفافة
    final craterPaint = Paint()
      ..color = const Color(0xFFE8A800).withAlpha(90)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(mx + 9,  my - 7), 5.0, craterPaint);
    canvas.drawCircle(Offset(mx - 11, my + 8), 4.0, craterPaint);
    canvas.drawCircle(Offset(mx + 3,  my + 10), 3.0, craterPaint);
    canvas.drawCircle(Offset(mx - 5,  my - 12), 2.5, craterPaint);
  }

  // ── الشهاب ────────────────────────────────────────────────────────────────
  void _drawShooting(Canvas canvas, Size size) {
    final ss = shooting;
    if (ss == null || shootT <= 0) return;

    const speed  = 170.0; // طول المسار الكلي بالبكسل
    const tailLen = 75.0;
    // اتجاه: أعلى اليمين → أسفل اليسار
    const dx = -0.707;
    const dy =  0.707;

    final sx = ss.startX * size.width;
    final sy = ss.startY * size.height;

    // موضع الرأس
    final hx = sx + dx * speed * shootT;
    final hy = sy + dy * speed * shootT;

    // موضع ذيل الشهاب (خلف الرأس في الاتجاه المعاكس)
    final tx = hx - dx * tailLen;
    final ty = hy - dy * tailLen;

    // تلاشي في نهاية الحركة
    final alpha = (shootT < 0.65)
        ? 1.0
        : (1.0 - shootT) / 0.35;

    // رسم الذيل بتدرج (8 شرائح)
    const steps = 8;
    for (int i = 0; i < steps; i++) {
      final t0 = i / steps;
      final t1 = (i + 1) / steps;
      final segAlpha = (t0 * alpha * 210).round().clamp(0, 255);
      final segWidth = 0.5 + 2.0 * t1;
      canvas.drawLine(
        Offset(tx + (hx - tx) * t0, ty + (hy - ty) * t0),
        Offset(tx + (hx - tx) * t1, ty + (hy - ty) * t1),
        Paint()
          ..color = Colors.white.withAlpha(segAlpha)
          ..strokeWidth = segWidth
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke,
      );
    }

    // رأس الشهاب — نقطة مضيئة
    canvas.drawCircle(
      Offset(hx, hy),
      3.5,
      Paint()..color = Colors.white.withAlpha((alpha * 255).round().clamp(0, 255)),
    );
    // هالة الرأس
    canvas.drawCircle(
      Offset(hx, hy),
      7.0,
      Paint()
        ..color = Colors.white.withAlpha((alpha * 55).round().clamp(0, 255))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );
  }

  @override
  bool shouldRepaint(covariant _SkyPainter old) => true;
}
