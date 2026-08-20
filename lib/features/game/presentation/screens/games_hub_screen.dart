import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/routes.dart';
import '../../../../features/wallet/presentation/providers/wallet_provider.dart';
import 'lucky_wheel_screen.dart';
import 'dice_betting_screen.dart';
import 'coin_flip_screen.dart';
import 'number_guess_screen.dart';
import 'greedy_star_screen.dart';

class GamesHubScreen extends ConsumerWidget {
  const GamesHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coins = ref.watch(coinsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: const Text('الألعاب والمراهنات', style: TextStyle(color: AppColors.textPrimary, fontFamily: 'Cairo', fontWeight: FontWeight.w700)),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: AppColors.textPrimary, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(50),
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('🪙', style: TextStyle(fontSize: 20)),
                const SizedBox(width: 8),
                Text(
                  _formatCoins(coins),
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800, fontFamily: 'Cairo'),
                ),
                const SizedBox(width: 4),
                const Text('عملة', style: TextStyle(color: Colors.white70, fontSize: 13, fontFamily: 'Cairo')),
              ],
            ),
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
          childAspectRatio: 0.85,
          children: [
            _GameCard(
              emoji: '🎰',
              title: 'عجلة الحظ',
              subtitle: 'ادفع 20 عملة\nوادر العجلة',
              gradient: const [Color(0xFF6C5CE7), Color(0xFF4C1D95)],
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LuckyWheelScreen())),
            ),
            _GameCard(
              emoji: '🎲',
              title: 'لعبة النرد',
              subtitle: 'راهن على\nزوجي أو فردي',
              gradient: const [Color(0xFFE17055), Color(0xFFD63031)],
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DiceBettingScreen())),
            ),
            _GameCard(
              emoji: '🪙',
              title: 'عملة أو كتابة',
              subtitle: 'راهن على\nصورة أو كتابة',
              gradient: const [Color(0xFFFD79A8), Color(0xFFE84393)],
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CoinFlipScreen())),
            ),
            _GameCard(
              emoji: '🔢',
              title: 'خمّن الرقم',
              subtitle: 'اختر رقماً من 1-5\nواربح 4 أضعاف',
              gradient: const [Color(0xFF00B894), Color(0xFF00796B)],
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NumberGuessScreen())),
            ),
            _GameCard(
              emoji: '🍬',
              title: 'Sweet Bonanza',
              subtitle: 'لعبة الفواكه\nالمتتالية',
              gradient: const [Color(0xFFFF6B9D), Color(0xFFFF3D7F)],
              onTap: () => context.push(AppRoutes.sweetBonanza),
            ),
            _GameCard(
              emoji: '⭐',
              title: 'Greedy Star',
              subtitle: 'راهن على الطعام\nوادر العجلة',
              gradient: const [Color(0xFFF5A623), Color(0xFFD4700A)],
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const GreedyStarScreen())),
            ),
          ],
        ),
      ),
    );
  }

  String _formatCoins(int v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}م';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}ك';
    return '$v';
  }
}

class _GameCard extends StatelessWidget {
  const _GameCard({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.gradient,
    required this.onTap,
  });
  final String emoji, title, subtitle;
  final List<Color> gradient;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: gradient, begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(color: gradient.first.withAlpha(80), blurRadius: 16, offset: const Offset(0, 6)),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 52)),
            const SizedBox(height: 10),
            Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800, fontFamily: 'Cairo')),
            const SizedBox(height: 4),
            Text(subtitle, style: const TextStyle(color: Colors.white70, fontSize: 11, fontFamily: 'Cairo', height: 1.4), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
