import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../app/theme/app_colors.dart';

// مكافآت كل يوم من التسلسل (1-7)
const _dailyRewards = [50, 80, 120, 160, 200, 280, 500];

final dailyRewardProvider = FutureProvider<_RewardState>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  final lastStr = prefs.getString('last_checkin');
  final streak = prefs.getInt('checkin_streak') ?? 0;
  final claimed = prefs.getBool('claimed_today') ?? false;

  final lastDate = lastStr != null ? DateTime.parse(lastStr) : null;
  final today = DateTime.now();
  final isNewDay = lastDate == null || !_sameDay(lastDate, today);

  return _RewardState(
    streak: isNewDay ? streak : streak,
    canClaim: isNewDay && !claimed,
    todayReward: _dailyRewards[streak % 7],
  );
});

bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

class _RewardState {
  final int streak, todayReward;
  final bool canClaim;
  const _RewardState({required this.streak, required this.todayReward, required this.canClaim});
}

class DailyRewardScreen extends ConsumerStatefulWidget {
  const DailyRewardScreen({super.key});

  @override
  ConsumerState<DailyRewardScreen> createState() => _DailyRewardScreenState();
}

class _DailyRewardScreenState extends ConsumerState<DailyRewardScreen> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;
  bool _claiming = false;
  bool _justClaimed = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _scale = CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _claim(int coins, int currentStreak) async {
    if (_claiming) return;
    setState(() => _claiming = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final newStreak = currentStreak + 1;
      await prefs.setString('last_checkin', DateTime.now().toIso8601String());
      await prefs.setInt('checkin_streak', newStreak);
      await prefs.setBool('claimed_today', true);

      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        await FirebaseFirestore.instance.collection('users').doc(uid).update({
          'coins': FieldValue.increment(coins),
        });
      }

      setState(() => _justClaimed = true);
      await _ctrl.forward();
      ref.invalidate(dailyRewardProvider);
    } finally {
      setState(() => _claiming = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rewardAsync = ref.watch(dailyRewardProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: const Text('المكافأة اليومية', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700)),
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_rounded), onPressed: () => Navigator.pop(context)),
      ),
      body: rewardAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (_, __) => const Center(child: Text('خطأ', style: TextStyle(color: AppColors.textSecondary, fontFamily: 'Cairo'))),
        data: (state) => _buildBody(state),
      ),
    );
  }

  Widget _buildBody(_RewardState state) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // رأس البطاقة
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                const Text('🎁', style: TextStyle(fontSize: 52)),
                const SizedBox(height: 12),
                const Text('تسجيل الحضور اليومي', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700, fontFamily: 'Cairo')),
                const SizedBox(height: 4),
                Text(
                  'التسلسل الحالي: ${state.streak} يوم',
                  style: const TextStyle(color: Colors.white70, fontSize: 13, fontFamily: 'Cairo'),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // شبكة المكافآت
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 0.85,
            ),
            itemCount: 7,
            itemBuilder: (_, i) {
              final isPast = i < state.streak % 7;
              final isToday = i == state.streak % 7;
              final reward = _dailyRewards[i];

              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                decoration: BoxDecoration(
                  color: isPast
                      ? AppColors.success.withAlpha(30)
                      : isToday
                          ? AppColors.gold.withAlpha(40)
                          : AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isPast
                        ? AppColors.success.withAlpha(80)
                        : isToday
                            ? AppColors.gold
                            : Colors.transparent,
                    width: isToday ? 2 : 1,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    isPast
                        ? const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 22)
                        : Text(isToday ? '🪙' : '🎁', style: const TextStyle(fontSize: 20)),
                    const SizedBox(height: 4),
                    Text(
                      'يوم ${i + 1}',
                      style: TextStyle(
                        color: isToday ? AppColors.gold : AppColors.textSecondary,
                        fontSize: 10, fontFamily: 'Cairo',
                        fontWeight: isToday ? FontWeight.w700 : FontWeight.normal,
                      ),
                    ),
                    Text(
                      '+$reward',
                      style: TextStyle(
                        color: isToday ? AppColors.gold : AppColors.textHint,
                        fontSize: 11, fontFamily: 'Cairo', fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          const SizedBox(height: 24),

          // زر المطالبة
          if (_justClaimed)
            ScaleTransition(
              scale: _scale,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                decoration: BoxDecoration(
                  color: AppColors.success.withAlpha(30),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.success),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_circle_rounded, color: AppColors.success),
                    const SizedBox(width: 8),
                    Text(
                      'تم استلام ${state.todayReward} كوين! 🎉',
                      style: const TextStyle(color: AppColors.success, fontFamily: 'Cairo', fontWeight: FontWeight.w700, fontSize: 15),
                    ),
                  ],
                ),
              ),
            )
          else
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: state.canClaim ? AppColors.gold : AppColors.surfaceLight,
                  foregroundColor: state.canClaim ? Colors.black : AppColors.textHint,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: state.canClaim ? 4 : 0,
                ),
                onPressed: state.canClaim ? () => _claim(state.todayReward, state.streak) : null,
                child: _claiming
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                    : Text(
                        state.canClaim
                            ? 'استلم ${state.todayReward} كوين 🪙'
                            : 'تم الاستلام اليوم ✓',
                        style: const TextStyle(fontFamily: 'Cairo', fontSize: 16, fontWeight: FontWeight.w700),
                      ),
              ),
            ),

          const SizedBox(height: 16),
          const Text(
            '⚡ سجّل حضورك كل يوم للحصول على مكافآت أكبر!',
            style: TextStyle(color: AppColors.textHint, fontFamily: 'Cairo', fontSize: 12),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
