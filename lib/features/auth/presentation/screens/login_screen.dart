import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/routes.dart';
import '../providers/auth_provider.dart';
import 'phone_auth_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  bool _googleLoading = false;
  bool _yahooLoading  = false;

  // Google
  Future<void> _googleLogin() async {
    if (_googleLoading) return;
    setState(() => _googleLoading = true);
    try {
      final user = await ref.read(authRepositoryProvider).signInWithGoogle();
      if (!mounted) return;
      (user != null && user.displayName.isNotEmpty)
          ? context.go(AppRoutes.home)
          : context.go(AppRoutes.setupProfile);
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString();
      if (msg.contains('cancelled') || msg.contains('canceled')) {
        // المستخدم ألغى — لا نُظهر خطأ
      } else if (msg.contains('google-idtoken-null') || msg.contains('SHA-1') || msg.contains('sha1')) {
        _showError('مشكلة في إعداد Google — تواصل مع الدعم');
      } else if (msg.contains('network')) {
        _showError('تحقق من اتصالك بالإنترنت');
      } else if (msg.contains('sign_in_failed') || msg.contains('ApiException')) {
        _showError('فشل تسجيل الدخول بـ Google — تأكد من الاتصال وحاول مرة أخرى');
      } else {
        _showError('فشل تسجيل الدخول بـ Google');
      }
    } finally {
      if (mounted) setState(() => _googleLoading = false);
    }
  }

  // Yahoo
  Future<void> _yahooLogin() async {
    if (_yahooLoading) return;
    setState(() => _yahooLoading = true);
    try {
      final user = await ref.read(authRepositoryProvider).signInWithYahoo();
      if (!mounted) return;
      (user != null && user.displayName.isNotEmpty)
          ? context.go(AppRoutes.home)
          : context.go(AppRoutes.setupProfile);
    } on Exception catch (e) {
      if (!mounted) return;
      final msg = e.toString();
      if (msg.contains('canceled') || msg.contains('cancelled') || msg.contains('sign_in_canceled')) {
        // المستخدم ألغى — لا نُظهر خطأ
      } else if (msg.contains('operation-not-allowed') || msg.contains('auth/operation-not-allowed')) {
        _showError('Yahoo غير مُفعَّل في Firebase Console — فعّله أولاً');
      } else if (msg.contains('network')) {
        _showError('تحقق من اتصالك بالإنترنت');
      } else {
        _showError('فشل تسجيل الدخول بـ Yahoo، حاول مرة أخرى');
      }
    } finally {
      if (mounted) setState(() => _yahooLoading = false);
    }
  }

  // Phone — فتح شاشة تسجيل الهاتف
  void _openPhoneScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PhoneAuthScreen()),
    );
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontFamily: 'Cairo')),
      backgroundColor: const Color(0xFFEA4335),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final size      = MediaQuery.of(context).size;
    final authState = ref.watch(authStateProvider);
    final hasUser   = authState.valueOrNull != null;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // زخارف دوائر ألوان Google
          const Positioned(top: -55,  left: -55,   child: _Blob(190, Color(0xFF4285F4))),
          const Positioned(top: 50,   right: -35,  child: _Blob(110, Color(0xFF34A853))),
          const Positioned(bottom: -65, right: -45, child: _Blob(210, Color(0xFFEA4335))),
          const Positioned(bottom: 30,  left: -35, child: _Blob(130, Color(0xFFFBBC05))),
          Positioned(top: size.height * 0.36, left: 22,  child: const _Blob(18, Color(0xFF4285F4))),
          Positioned(top: size.height * 0.42, right: 26, child: const _Blob(13, Color(0xFFEA4335))),
          Positioned(top: size.height * 0.58, right: 20, child: const _Blob(22, Color(0xFF34A853))),
          Positioned(top: size.height * 0.63, left: 16,  child: const _Blob(15, Color(0xFFFBBC05))),

          // زر تخطي — للمستخدم المسجل مسبقاً
          if (hasUser)
            Positioned(
              top: 0, left: 0, right: 0,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.only(left: 16, top: 10),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: GestureDetector(
                      onTap: () => context.go(AppRoutes.home),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A1A1A).withAlpha(200),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('تخطي',
                              style: TextStyle(color: Colors.white, fontSize: 15,
                                  fontWeight: FontWeight.w700, fontFamily: 'Cairo')),
                            SizedBox(width: 4),
                            Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 14),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 36),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(height: size.height * 0.10),

                  // أيقونة التطبيق
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 120, height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                          boxShadow: [BoxShadow(color: Colors.black.withAlpha(22), blurRadius: 24, offset: const Offset(0, 6))],
                        ),
                        child: ClipOval(
                          child: Image.asset('assets/icon/icon.chatlive.1.png', fit: BoxFit.cover),
                        ),
                      ),
                      Positioned(
                        top: -4, right: -4,
                        child: Container(
                          width: 30, height: 30,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE53935),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2.5),
                            boxShadow: [BoxShadow(color: const Color(0xFFE53935).withAlpha(100), blurRadius: 8, offset: const Offset(0, 3))],
                          ),
                          child: const Icon(Icons.close_rounded, color: Colors.white, size: 17),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // شحن مجاني
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF6B35), Color(0xFFE53935)],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [BoxShadow(color: const Color(0xFFE53935).withAlpha(80), blurRadius: 10, offset: const Offset(0, 4))],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.stars_rounded, color: Colors.white, size: 17),
                        SizedBox(width: 6),
                        Text('شحن مجاني',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800,
                              fontFamily: 'Cairo', fontSize: 15, letterSpacing: 0.3)),
                        SizedBox(width: 6),
                        Icon(Icons.stars_rounded, color: Colors.white, size: 17),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  const Text('LivChat',
                    style: TextStyle(fontSize: 38, fontWeight: FontWeight.w800,
                        color: Color(0xFF1A1A1A), letterSpacing: -1.0)),
                  const SizedBox(height: 8),
                  const Text('تواصل، استمتع، وكن جزء من المجتمع',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: Color(0xFF5F6368),
                        fontFamily: 'Cairo', height: 1.6)),

                  const Spacer(),

                  // Google
                  _LoginButton(
                    onTap: _googleLoading ? null : _googleLogin,
                    isLoading: _googleLoading,
                    icon: SizedBox(width: 22, height: 22, child: CustomPaint(painter: _GoogleGPainter())),
                    label: 'المتابعة بـ Google',
                    borderColor: const Color(0xFFDEDEDE),
                    textColor: const Color(0xFF3C4043),
                    bgColor: Colors.white,
                  ),

                  const SizedBox(height: 12),

                  // Yahoo
                  _LoginButton(
                    onTap: _yahooLoading ? null : _yahooLogin,
                    isLoading: _yahooLoading,
                    icon: const _YahooIcon(),
                    label: 'المتابعة بـ Yahoo',
                    borderColor: const Color(0xFF6001D2),
                    textColor: Colors.white,
                    bgColor: const Color(0xFF6001D2),
                  ),

                  const SizedBox(height: 12),

                  // رقم الهاتف
                  _LoginButton(
                    onTap: _openPhoneScreen,
                    icon: const Icon(Icons.phone_rounded, color: Colors.white, size: 20),
                    label: 'المتابعة برقم الهاتف',
                    borderColor: const Color(0xFF1565C0),
                    textColor: Colors.white,
                    bgColor: const Color(0xFF1565C0),
                  ),

                  const SizedBox(height: 20),

                  Text(
                    'بتسجيل دخولك توافق على شروط الاستخدام وسياسة الخصوصية',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11, color: Colors.grey[400], fontFamily: 'Cairo'),
                  ),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// زر تسجيل الدخول
class _LoginButton extends StatelessWidget {
  const _LoginButton({
    required this.onTap,
    required this.icon,
    required this.label,
    required this.borderColor,
    required this.textColor,
    required this.bgColor,
    this.isLoading = false,
  });

  final VoidCallback? onTap;
  final Widget icon;
  final String label;
  final Color borderColor, textColor, bgColor;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedOpacity(
        opacity: onTap == null ? 0.6 : 1.0,
        duration: const Duration(milliseconds: 150),
        child: Container(
          width: double.infinity,
          height: 54,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor, width: 1.5),
            boxShadow: [BoxShadow(color: Colors.black.withAlpha(14), blurRadius: 10, offset: const Offset(0, 3))],
          ),
          child: isLoading
              ? Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: textColor)))
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    icon,
                    const SizedBox(width: 10),
                    Text(label, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: textColor, fontFamily: 'Cairo')),
                  ],
                ),
        ),
      ),
    );
  }
}

// دائرة زخرفية
class _Blob extends StatelessWidget {
  const _Blob(this.size, this.color);
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        width: size, height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color.withAlpha(28)),
      );
}

// أيقونة Yahoo
class _YahooIcon extends StatelessWidget {
  const _YahooIcon();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 22, height: 22,
      child: Center(
        child: Text('Y!',
          style: TextStyle(color: Colors.white, fontSize: 16,
              fontWeight: FontWeight.w900, letterSpacing: -1)),
      ),
    );
  }
}

// رسم حرف G
class _GoogleGPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final r = size.width / 2;
    final c = Offset(r, r);
    final sw = r * 0.34;
    final ar = r - sw / 2;
    final paint = Paint()..style = PaintingStyle.stroke..strokeWidth = sw..strokeCap = StrokeCap.butt;

    paint.color = const Color(0xFFEA4335);
    canvas.drawArc(Rect.fromCircle(center: c, radius: ar), -1.57, 1.57, false, paint);
    paint.color = const Color(0xFFFBBC05);
    canvas.drawArc(Rect.fromCircle(center: c, radius: ar), 0.0, 1.57, false, paint);
    paint.color = const Color(0xFF34A853);
    canvas.drawArc(Rect.fromCircle(center: c, radius: ar), 1.57, 1.57, false, paint);
    paint.color = const Color(0xFF4285F4);
    canvas.drawArc(Rect.fromCircle(center: c, radius: ar), 3.14, 1.14, false, paint);
    canvas.drawRect(Rect.fromLTWH(c.dx, c.dy - sw / 2, ar, sw),
        Paint()..color = const Color(0xFF4285F4)..style = PaintingStyle.fill);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
