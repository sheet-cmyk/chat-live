import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/routes.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  bool _loading = false;

  Future<void> _googleLogin() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      final user = await ref.read(authRepositoryProvider).signInWithGoogle();
      if (!mounted) return;
      if (user != null) {
        context.go(AppRoutes.home);
      } else {
        context.push(AppRoutes.register);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'فشل تسجيل الدخول، يرجى المحاولة مجدداً',
            style: TextStyle(fontFamily: 'Cairo'),
          ),
          backgroundColor: Color(0xFFEA4335),
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // ── زخارف دوائر بألوان Google ────────────────────────────────
          Positioned(top: -55,  left: -55,   child: _Blob(190, const Color(0xFF4285F4))),
          Positioned(top: 50,   right: -35,  child: _Blob(110, const Color(0xFF34A853))),
          Positioned(bottom: -65, right: -45, child: _Blob(210, const Color(0xFFEA4335))),
          Positioned(bottom: 30,  left: -35,  child: _Blob(130, const Color(0xFFFBBC05))),
          // نقاط صغيرة عائمة
          Positioned(top: size.height * 0.36, left: 22,  child: _Blob(18, const Color(0xFF4285F4))),
          Positioned(top: size.height * 0.42, right: 26, child: _Blob(13, const Color(0xFFEA4335))),
          Positioned(top: size.height * 0.58, right: 20, child: _Blob(22, const Color(0xFF34A853))),
          Positioned(top: size.height * 0.63, left: 16,  child: _Blob(15, const Color(0xFFFBBC05))),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 36),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(height: size.height * 0.13),

                  // ── أيقونة التطبيق ────────────────────────────────────
                  Container(
                    width: 124, height: 124,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(22),
                          blurRadius: 24,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: Image.asset('assets/icon/icon.a1.png', fit: BoxFit.cover),
                    ),
                  ),

                  const SizedBox(height: 28),

                  // ── اسم التطبيق ───────────────────────────────────────
                  const Text(
                    'LivChat',
                    style: TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1A1A1A),
                      letterSpacing: -1.0,
                    ),
                  ),

                  const SizedBox(height: 12),

                  const Text(
                    'تواصل، استمتع، وكن جزء من المجتمع',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF5F6368),
                      fontFamily: 'Cairo',
                      height: 1.6,
                    ),
                  ),

                  const Spacer(),

                  // ── زر تسجيل الدخول بـ Google ──────────────────────────
                  _GoogleButton(
                    onTap: _loading ? null : _googleLogin,
                    isLoading: _loading,
                  ),

                  const SizedBox(height: 20),

                  Text(
                    'بتسجيل دخولك توافق على شروط الاستخدام وسياسة الخصوصية',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[400],
                      fontFamily: 'Cairo',
                    ),
                  ),

                  const SizedBox(height: 36),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── دائرة زخرفية ─────────────────────────────────────────────────────────────
class _Blob extends StatelessWidget {
  const _Blob(this.size, this.color);
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withAlpha(28),
        ),
      );
}

// ── زر Google ────────────────────────────────────────────────────────────────
class _GoogleButton extends StatelessWidget {
  const _GoogleButton({this.onTap, this.isLoading = false});
  final VoidCallback? onTap;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 56,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFDEDEDE), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(16),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: isLoading
            ? const Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Color(0xFF4285F4),
                  ),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: CustomPaint(painter: _GoogleGPainter()),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'المتابعة بـ Google',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF3C4043),
                      fontFamily: 'Cairo',
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

// ── رسم حرف G بألوان Google ──────────────────────────────────────────────────
class _GoogleGPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double r  = size.width / 2;
    final Offset c  = Offset(r, r);
    final double sw = r * 0.34;
    final double ar = r - sw / 2;
    final paint = Paint()
      ..style    = PaintingStyle.stroke
      ..strokeWidth = sw
      ..strokeCap   = StrokeCap.butt;

    // أحمر — الأعلى
    paint.color = const Color(0xFFEA4335);
    canvas.drawArc(Rect.fromCircle(center: c, radius: ar), -1.57, 1.57, false, paint);
    // أصفر — اليمين
    paint.color = const Color(0xFFFBBC05);
    canvas.drawArc(Rect.fromCircle(center: c, radius: ar), 0.0, 1.57, false, paint);
    // أخضر — الأسفل
    paint.color = const Color(0xFF34A853);
    canvas.drawArc(Rect.fromCircle(center: c, radius: ar), 1.57, 1.57, false, paint);
    // أزرق — اليسار
    paint.color = const Color(0xFF4285F4);
    canvas.drawArc(Rect.fromCircle(center: c, radius: ar), 3.14, 1.14, false, paint);

    // ذراع G الأفقي
    canvas.drawRect(
      Rect.fromLTWH(c.dx, c.dy - sw / 2, ar, sw),
      Paint()..color = const Color(0xFF4285F4)..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
