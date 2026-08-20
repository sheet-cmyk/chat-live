import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shimmer/shimmer.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/routes.dart';
import '../providers/home_provider.dart';
import '../widgets/room_card.dart';
import '../widgets/category_tabs.dart';
import '../widgets/promo_banner.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedType = ref.watch(selectedCategoryProvider);
    final roomsAsync = ref.watch(roomsStreamProvider(selectedType));

    // عرض إشعار العملات اليومية المجانية
    ref.listen(pendingDailyCoinsProvider, (_, coins) {
      if (coins > 0) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ref.read(pendingDailyCoinsProvider.notifier).state = 0;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Text('🎁 ', style: TextStyle(fontSize: 20)),
                  Expanded(
                    child: Text(
                      'استلمت مكافأتك اليومية! +500,000 عملة 🪙',
                      style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              backgroundColor: const Color(0xFF1A1A2E),
              duration: const Duration(seconds: 4),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        });
      }
    });

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary,
          backgroundColor: AppColors.surface,
          onRefresh: () async => ref.invalidate(roomsStreamProvider),
          child: CustomScrollView(
            slivers: [
              // شريط العنوان
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: Row(
                    children: [
                      Container(
                        width: 34, height: 34,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: AppColors.primaryGradient,
                        ),
                        child: const Icon(Icons.celebration_rounded, size: 18, color: Colors.white),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Party Hub',
                        style: TextStyle(
                          fontSize: 20, fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary, fontFamily: 'Cairo',
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => context.push(AppRoutes.search),
                        icon: const Icon(Icons.search_rounded, color: AppColors.textSecondary),
                      ),
                      IconButton(
                        onPressed: () => context.push(AppRoutes.notification),
                        icon: const Icon(Icons.notifications_rounded, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ),

              // البانر الترويجي
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: PromoBanner(),
                ),
              ),

              // تبويبات الفئات
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.only(bottom: 16),
                  child: CategoryTabs(),
                ),
              ),

              // عنوان قسم الغرف
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Row(
                    children: [
                      Icon(Icons.radio_button_checked, color: AppColors.error, size: 14),
                      SizedBox(width: 6),
                      Text(
                        'الغرف الحية',
                        style: TextStyle(
                          color: AppColors.textPrimary, fontSize: 15,
                          fontWeight: FontWeight.w700, fontFamily: 'Cairo',
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // شبكة الغرف
              roomsAsync.when(
                data: (rooms) {
                  if (rooms.isEmpty) {
                    return const SliverFillRemaining(child: _EmptyRooms());
                  }
                  return SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverGrid(
                      delegate: SliverChildBuilderDelegate(
                        (_, i) => RoomCard(room: rooms[i]),
                        childCount: rooms.length,
                      ),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 0.82,
                      ),
                    ),
                  );
                },
                loading: () => SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverGrid(
                    delegate: SliverChildBuilderDelegate(
                      (_, __) => const _RoomShimmer(),
                      childCount: 6,
                    ),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 0.82,
                    ),
                  ),
                ),
                error: (_, __) => SliverFillRemaining(
                  child: _ErrorRooms(onRetry: () => ref.invalidate(roomsStreamProvider)),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 80)),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyRooms extends StatelessWidget {
  const _EmptyRooms();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('🎉', style: TextStyle(fontSize: 56)),
          SizedBox(height: 12),
          Text('لا توجد غرف حالياً', style: TextStyle(color: AppColors.textSecondary, fontFamily: 'Cairo', fontSize: 15)),
          SizedBox(height: 6),
          Text('كن أول من يبدأ الحفلة!', style: TextStyle(color: AppColors.textHint, fontFamily: 'Cairo', fontSize: 13)),
        ],
      ),
    );
  }
}

class _ErrorRooms extends StatelessWidget {
  const _ErrorRooms({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.wifi_off_rounded, size: 56, color: AppColors.textHint),
          const SizedBox(height: 12),
          const Text('تعذّر تحميل الغرف', style: TextStyle(color: AppColors.textSecondary, fontFamily: 'Cairo', fontSize: 15)),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('إعادة المحاولة', style: TextStyle(fontFamily: 'Cairo')),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary, foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoomShimmer extends StatelessWidget {
  const _RoomShimmer();

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.surfaceLight,
      highlightColor: AppColors.surface,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}
