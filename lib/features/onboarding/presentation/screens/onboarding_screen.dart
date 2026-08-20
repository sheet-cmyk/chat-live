import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../app/routes.dart';

const _kOnboardingDone = 'onboarding_done';

Future<bool> isOnboardingDone() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(_kOnboardingDone) ?? false;
}

Future<void> markOnboardingDone() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(_kOnboardingDone, true);
}

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  static const _slides = [
    _Slide(
      emoji: '🎉',
      title: 'مرحباً بك في Party Hub',
      body: 'تطبيق الحفلات الصوتية الأول — أنشئ غرفتك وادعُ أصدقاءك واستمتع بجلسات لا تُنسى',
      gradient: [Color(0xFF7C3AED), Color(0xFF4C1D95)],
    ),
    _Slide(
      emoji: '🎤',
      title: 'غرف صوتية حية',
      body: 'انضم لآلاف الغرف الصوتية المباشرة، تحدّث مع العالم وعبّر عن نفسك بصوتك',
      gradient: [Color(0xFFEC4899), Color(0xFF9333EA)],
    ),
    _Slide(
      emoji: '🎁',
      title: 'هدايا وإثارة',
      body: 'أرسل هدايا رائعة، تسلّق قائمة المشاهير، وكُن نجم الحفلة',
      gradient: [Color(0xFFF59E0B), Color(0xFFEF4444)],
    ),
    _Slide(
      emoji: '👑',
      title: 'ابدأ رحلتك الآن',
      body: 'سجّل دخولك وابدأ في بناء مجتمعك — Party Hub ينتظرك!',
      gradient: [Color(0xFF10B981), Color(0xFF0EA5E9)],
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next() {
    if (_page < _slides.length - 1) {
      _controller.nextPage(duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
    } else {
      _finish();
    }
  }

  Future<void> _finish() async {
    await markOnboardingDone();
    if (mounted) context.go(AppRoutes.login);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // صفحات الـ onboarding
          PageView.builder(
            controller: _controller,
            itemCount: _slides.length,
            onPageChanged: (i) => setState(() => _page = i),
            itemBuilder: (_, i) => _SlideView(slide: _slides[i]),
          ),

          // تخطي
          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: TextButton(
                onPressed: _finish,
                child: const Text('تخطي', style: TextStyle(color: Colors.white70, fontFamily: 'Cairo', fontSize: 14)),
              ),
            ),
          ),

          // نقاط + زر التالي
          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // نقاط التنقل
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(_slides.length, (i) {
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: i == _page ? 24 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: i == _page ? Colors.white : Colors.white38,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 32),
                    // زر التالي
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF7C3AED),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 0,
                        ),
                        onPressed: _next,
                        child: Text(
                          _page == _slides.length - 1 ? 'ابدأ الآن 🚀' : 'التالي',
                          style: const TextStyle(fontFamily: 'Cairo', fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Slide {
  final String emoji, title, body;
  final List<Color> gradient;
  const _Slide({required this.emoji, required this.title, required this.body, required this.gradient});
}

class _SlideView extends StatelessWidget {
  const _SlideView({required this.slide});
  final _Slide slide;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: slide.gradient, begin: Alignment.topLeft, end: Alignment.bottomRight),
      ),
      child: Stack(
        children: [
          // دوائر زخرفية
          Positioned(top: -60, right: -60,
            child: Container(width: 220, height: 220,
              decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withAlpha(20)))),
          Positioned(bottom: 120, left: -80,
            child: Container(width: 280, height: 280,
              decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withAlpha(12)))),

          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(slide.emoji, style: const TextStyle(fontSize: 96)),
                  const SizedBox(height: 32),
                  Text(
                    slide.title,
                    style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800, fontFamily: 'Cairo'),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    slide.body,
                    style: const TextStyle(color: Colors.white70, fontSize: 15, fontFamily: 'Cairo', height: 1.7),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
