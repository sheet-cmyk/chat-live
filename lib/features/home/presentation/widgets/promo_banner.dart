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
    _BannerData('احتفل مع أصدقائك 🎉', 'انضم لآلاف الغرف الحية الآن', AppColors.primaryGradient),
    _BannerData('أرسل هدايا رائعة 🎁', 'اكتشف هدايا حصرية لأصدقائك', LinearGradient(
      colors: [Color(0xFFEC4899), Color(0xFF7C3AED)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    )),
    _BannerData('احصل على VIP 👑', 'مزايا حصرية وإطار مميز', AppColors.goldGradient),
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
          height: 130,
          child: PageView.builder(
            controller: _controller,
            itemCount: _banners.length,
            onPageChanged: (_) {},
            itemBuilder: (_, i) => _BannerCard(data: _banners[i]),
          ),
        ),
        const SizedBox(height: 8),
        SmoothPageIndicator(
          controller: _controller,
          count: _banners.length,
          effect: const ExpandingDotsEffect(
            dotHeight: 6,
            dotWidth: 6,
            activeDotColor: AppColors.primary,
            dotColor: AppColors.surfaceLight,
          ),
        ),
      ],
    );
  }
}

class _BannerData {
  const _BannerData(this.title, this.subtitle, this.gradient);
  final String title;
  final String subtitle;
  final LinearGradient gradient;
}

class _BannerCard extends StatelessWidget {
  const _BannerCard({required this.data});
  final _BannerData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        gradient: data.gradient,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              data.title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
                fontFamily: 'Cairo',
              ),
            ),
            const SizedBox(height: 4),
            Text(
              data.subtitle,
              style: TextStyle(color: Colors.white.withAlpha(200), fontSize: 13, fontFamily: 'Cairo'),
            ),
          ],
        ),
      ),
    );
  }
}
