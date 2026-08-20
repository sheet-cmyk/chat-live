import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/routes.dart';
import '../providers/auth_provider.dart';
import '../../../wallet/presentation/providers/wallet_provider.dart';
import '../../../levels/presentation/providers/level_provider.dart';
import '../../../admin/presentation/providers/admin_provider.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final balance = ref.watch(balanceStreamProvider);
    final coins = balance.valueOrNull?['coins'] ?? 0;
    final diamonds = balance.valueOrNull?['diamonds'] ?? 0;
    final level = ref.watch(userLevelProvider);
    final progress = ref.watch(levelProgressProvider);
    final isAdmin = ref.watch(isAdminProvider).valueOrNull == true;

    return authState.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator(color: AppColors.primary))),
      error: (_, __) => const Scaffold(body: Center(child: Text('خطأ', style: TextStyle(color: AppColors.textSecondary)))),
      data: (user) {
        if (user == null) return const SizedBox.shrink();
        final name = user.displayName ?? 'مستخدم';
        final avatar = user.photoURL;

        return Scaffold(
          backgroundColor: AppColors.background,
          body: CustomScrollView(
            slivers: [
              // رأس الملف الشخصي
              SliverToBoxAdapter(
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // خلفية متدرجة
                    Container(
                      height: 200,
                      decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
                    ),
                    SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Row(
                          children: [
                            const Spacer(),
                            IconButton(
                              icon: const Icon(Icons.settings_rounded, color: Colors.white),
                              onPressed: () => context.push(AppRoutes.settings),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // الأفاتار + الاسم
                    Positioned(
                      bottom: -50,
                      left: 0, right: 0,
                      child: Column(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: AppColors.background, width: 4),
                              boxShadow: [BoxShadow(color: AppColors.primary.withAlpha(80), blurRadius: 16)],
                            ),
                            child: CircleAvatar(
                              radius: 48,
                              backgroundColor: AppColors.primary,
                              backgroundImage: avatar != null ? CachedNetworkImageProvider(avatar) : null,
                              child: avatar == null
                                  ? Text(name[0], style: const TextStyle(fontSize: 36, color: Colors.white, fontWeight: FontWeight.bold))
                                  : null,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // المعلومات
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(top: 60),
                  child: Column(
                    children: [
                      Text(name, style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'Cairo',
                      )),
                      const SizedBox(height: 4),
                      Text(user.email ?? user.phoneNumber ?? '', style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontFamily: 'Cairo',
                        fontSize: 13,
                      )),
                      const SizedBox(height: 10),
                      // شارة المستوى
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          gradient: AppColors.primaryGradient,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${level.badge} المستوى ${level.level} · ${level.title}',
                          style: const TextStyle(color: Colors.white, fontFamily: 'Cairo', fontSize: 12, fontWeight: FontWeight.w700),
                        ),
                      ),
                      const SizedBox(height: 8),
                      // شريط التقدم
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 40),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 6,
                            backgroundColor: AppColors.surfaceLight,
                            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // إحصائيات (كوينز + ماسات)
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 20),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: AppColors.card,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.divider),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _StatItem(icon: '🪙', value: '$coins', label: 'عملة'),
                            Container(width: 1, height: 36, color: AppColors.divider),
                            _StatItem(icon: '💎', value: '$diamonds', label: 'ماسة'),
                            Container(width: 1, height: 36, color: AppColors.divider),
                            _StatItem(icon: '⭐', value: 'Lv.${level.level}', label: 'المستوى'),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // أزرار
                      _ProfileButton(
                        icon: Icons.account_balance_wallet_rounded,
                        label: 'محفظتي',
                        color: AppColors.gold,
                        onTap: () => context.push(AppRoutes.wallet),
                      ),
                      _ProfileButton(
                        icon: Icons.workspace_premium_rounded,
                        label: 'عضوية VIP',
                        color: const Color(0xFFE040FB),
                        onTap: () => context.push(AppRoutes.vip),
                      ),
                      _ProfileButton(
                        icon: Icons.casino_rounded,
                        label: 'عجلة الحظ 🎡',
                        color: AppColors.accent,
                        onTap: () => context.push(AppRoutes.game),
                      ),
                      _ProfileButton(
                        icon: Icons.calendar_today_rounded,
                        label: 'المكافأة اليومية 🎁',
                        color: AppColors.gold,
                        onTap: () => context.push('/daily-reward'),
                      ),
                      _ProfileButton(
                        icon: Icons.history_rounded,
                        label: 'الغرف المزارة',
                        color: AppColors.accent,
                        onTap: () => context.push('/room-history'),
                      ),
                      _ProfileButton(
                        icon: Icons.people_rounded,
                        label: 'الأصدقاء',
                        color: AppColors.success,
                        onTap: () => context.push('/friends'),
                      ),
                      _ProfileButton(
                        icon: Icons.edit_rounded,
                        label: 'تعديل الملف الشخصي',
                        color: AppColors.primary,
                        onTap: () {},
                      ),
                      if (isAdmin)
                        _ProfileButton(
                          icon: Icons.admin_panel_settings_rounded,
                          label: 'لوحة الإدارة ⚙️',
                          color: Colors.amber,
                          onTap: () => context.push(AppRoutes.admin),
                        ),
                      _ProfileButton(
                        icon: Icons.logout_rounded,
                        label: 'تسجيل الخروج',
                        color: AppColors.error,
                        onTap: () async {
                          await ref.read(authRepositoryProvider).signOut();
                          if (context.mounted) context.go(AppRoutes.login);
                        },
                      ),

                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({required this.icon, required this.value, required this.label});
  final String icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(icon, style: const TextStyle(fontSize: 20)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w800,
          fontSize: 15,
        )),
        Text(label, style: const TextStyle(
          color: AppColors.textHint,
          fontFamily: 'Cairo',
          fontSize: 11,
        )),
      ],
    );
  }
}

class _ProfileButton extends StatelessWidget {
  const _ProfileButton({required this.icon, required this.label, required this.color, required this.onTap});
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        child: ListTile(
          onTap: onTap,
          leading: Icon(icon, color: color),
          title: Text(label, style: TextStyle(color: color, fontFamily: 'Cairo', fontWeight: FontWeight.w600)),
          trailing: const Icon(Icons.chevron_left_rounded, color: AppColors.textHint),
        ),
      ),
    );
  }
}
