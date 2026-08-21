import 'package:flutter/material.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import '../../../../app/theme/app_colors.dart';

class PromoBanner extends StatefulWidget {
  const PromoBanner({super.key});

  @override
  State<PromoBanner> createState() => _PromoBannerState();
}

class _PromoBannerState extends State<PromoBanner> {
  final _controller = PageController();

  final _banners = const [
    _BannerData(
      'احتفل مع أصدقائك 🎉',
      'انضم لآلاف الغرف الحية الآن',
      [Color(0xFFE8E0FF), Color(0xFFF6D8FF), Color(0xFFFFF0C7), Color(0xFFFFE4E8)],
      '🎊',
    ),
    _BannerData(
      'أرسل هدايا رائعة 🎁',
      'اكتشف هدايا حصرية لأصدقائك',
      [Color(0xFFFFE4E8), Color(0xFFFFF0C7), Color(0xFFE0F4FF), Color(0xFFE4FFED)],
      '🎁',
    ),
    _BannerData(
      'احصل على VIP 👑',
      'مزايا حصرية وإطار مميز',
      [Color(0xFFFFF8E0), Color(0xFFFFF0C7), Color(0xFFFFE4C4), Color(0xFFFDE8FF)],
      '👑',
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 160,
          child: PageView.builder(
            controller: _controller,
            itemCount: _banners.length,
            onPageChanged: (_) => setState(() {}),
            itemBuilder: (_, i) => _BannerCard(data: _banners[i]),
          ),
        ),
        const SizedBox(height: 10),
        SmoothPageIndicator(
          controller: _controller,
          count: _banners.length,
          effect: const ExpandingDotsEffect(
            dotHeight: 7,
            dotWidth: 7,
            expansionFactor: 4,
            activeDotColor: AppColors.primary,
            dotColor: Color(0xFFDDD6FE),
          ),
        ),
      ],
    );
  }
}

class _BannerData {
  const _BannerData(this.title, this.subtitle, this.colors, this.emoji);
  final String title;
  final String subtitle;
  final List<Color> colors;
  final String emoji;
}

class _BannerCard extends StatelessWidget {
  const _BannerCard({required this.data});
  final _BannerData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: data.colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7C3AED).withAlpha(20),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        children: [
          // decorative large emoji background
          Positioned(
            left: -10,
            top: -10,
            child: Text(data.emoji, style: const TextStyle(fontSize: 90)),
          ),
          // content
          Padding(
            padding: const EdgeInsets.fromLTRB(100, 20, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  data.title,
                  style: const TextStyle(
                    color: Color(0xFF1A1A2E),
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'Cairo',
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  data.subtitle,
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 12,
                    fontFamily: 'Cairo',
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withAlpha(60),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Text('ابدأ الآن', style: TextStyle(
                    color: Colors.white, fontSize: 11,
                    fontWeight: FontWeight.w700, fontFamily: 'Cairo',
                  )),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
