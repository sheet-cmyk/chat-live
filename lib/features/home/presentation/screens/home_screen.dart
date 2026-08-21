import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
              backgroundColor: AppColors.textPrimary,
              duration: const Duration(seconds: 4),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          );
        });
      }
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // decorative background
          const Positioned.fill(child: _DecorativeBg()),

          SafeArea(
            child: RefreshIndicator(
              color: AppColors.primary,
              backgroundColor: Colors.white,
              onRefresh: () async => ref.invalidate(roomsStreamProvider),
              child: CustomScrollView(
                slivers: [
                  // ── Header ──────────────────────────────────────
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                      child: Row(
                        children: [
                          // Party Hub icon
                          Container(
                            width: 44, height: 44,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: AppColors.primaryGradient,
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary.withAlpha(60),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Icon(Icons.celebration_rounded, size: 22, color: Colors.white),
                          ),
                          const SizedBox(width: 10),
                          const Text(
                            'Party Hub',
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                              fontFamily: 'Cairo',
                              letterSpacing: -0.5,
                            ),
                          ),
                          const Spacer(),
                          // Search button
                          _HeaderBtn(
                            icon: Icons.search_rounded,
                            color: AppColors.blue,
                            onTap: () => context.push(AppRoutes.search),
                          ),
                          const SizedBox(width: 8),
                          // Notification button
                          _HeaderBtn(
                            icon: Icons.notifications_rounded,
                            color: AppColors.orange,
                            onTap: () => context.push(AppRoutes.notification),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ── Hero Banner ──────────────────────────────────
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: PromoBanner(),
                    ),
                  ),

                  // ── Category Tabs ────────────────────────────────
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.only(bottom: 16),
                      child: CategoryTabs(),
                    ),
                  ),

                  // ── Live Rooms Header ────────────────────────────
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
                      child: Row(
                        children: [
                          const Text(
                            'الغرف الحية',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              fontFamily: 'Cairo',
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            width: 8, height: 8,
                            decoration: const BoxDecoration(
                              color: AppColors.red,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            'الكل',
                            style: TextStyle(
                              color: AppColors.primary.withAlpha(200),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              fontFamily: 'Cairo',
                            ),
                          ),
                          Icon(Icons.chevron_left_rounded,
                            color: AppColors.primary.withAlpha(200), size: 18),
                        ],
                      ),
                    ),
                  ),

                  // ── Rooms Grid ───────────────────────────────────
                  roomsAsync.when(
                    data: (rooms) {
                      if (rooms.isEmpty) {
                        return const SliverFillRemaining(child: _EmptyRooms());
                      }
                      return SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        sliver: SliverGrid(
                          delegate: SliverChildBuilderDelegate(
                            (_, i) => RoomCard(
                              room: rooms[i],
                              isOwner: rooms[i].hostUid == FirebaseAuth.instance.currentUser?.uid,
                            ),
                            childCount: rooms.length,
                          ),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: 14,
                            crossAxisSpacing: 14,
                            childAspectRatio: 0.80,
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
                          mainAxisSpacing: 14,
                          crossAxisSpacing: 14,
                          childAspectRatio: 0.80,
                        ),
                      ),
                    ),
                    error: (_, __) => SliverFillRemaining(
                      child: _ErrorRooms(onRetry: () => ref.invalidate(roomsStreamProvider)),
                    ),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 100)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Header circular button ─────────────────────────────────────────────
class _HeaderBtn extends StatelessWidget {
  const _HeaderBtn({required this.icon, required this.color, required this.onTap});
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44, height: 44,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF3C4043).withAlpha(20),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Icon(icon, color: color, size: 22),
      ),
    );
  }
}

// ── Decorative Background ──────────────────────────────────────────────
class _DecorativeBg extends StatelessWidget {
  const _DecorativeBg();

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final h = MediaQuery.of(context).size.height;
    return IgnorePointer(
      child: CustomPaint(
        size: Size(w, h),
        painter: _BgPainter(),
      ),
    );
  }
}

class _BgPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    void circle(double x, double y, double r, Color c, {double alpha = 0.08}) {
      canvas.drawCircle(
        Offset(x, y), r,
        Paint()..color = c.withAlpha((alpha * 255).round())..style = PaintingStyle.fill,
      );
    }

    void ring(double x, double y, double r, Color c, {double alpha = 0.10, double stroke = 3}) {
      canvas.drawCircle(
        Offset(x, y), r,
        Paint()..color = c.withAlpha((alpha * 255).round())
          ..style = PaintingStyle.stroke..strokeWidth = stroke,
      );
    }

    // Top-left large partial circle
    circle(-w * 0.18, -h * 0.04, w * 0.42, AppColors.primary, alpha: 0.07);
    ring(-w * 0.05, h * 0.12, w * 0.28, AppColors.blue, alpha: 0.10, stroke: 2);

    // Top-right accent
    circle(w * 1.10, -h * 0.02, w * 0.32, AppColors.yellow, alpha: 0.12);
    circle(w * 0.88, h * 0.06, w * 0.10, AppColors.red, alpha: 0.10);

    // Mid-left dots
    for (int i = 0; i < 5; i++) {
      circle(w * 0.04, h * 0.28 + i * 28, 4, AppColors.green, alpha: 0.18);
    }

    // Mid-right ring
    ring(w * 1.04, h * 0.40, w * 0.22, AppColors.accent, alpha: 0.09, stroke: 2.5);

    // Bottom decorative elements
    circle(w * 0.12, h * 0.75, w * 0.16, AppColors.cyan, alpha: 0.10);
    circle(w * 0.90, h * 0.68, w * 0.20, AppColors.primary, alpha: 0.06);
    ring(w * 0.72, h * 0.80, w * 0.12, AppColors.yellow, alpha: 0.12, stroke: 2);

    // Small scattered dots
    final dotPositions = [
      [0.78, 0.14], [0.22, 0.46], [0.88, 0.32],
      [0.14, 0.60], [0.65, 0.55], [0.42, 0.88],
    ];
    final dotColors = [
      AppColors.blue, AppColors.red, AppColors.green,
      AppColors.yellow, AppColors.accent, AppColors.cyan,
    ];
    for (int i = 0; i < dotPositions.length; i++) {
      circle(w * dotPositions[i][0], h * dotPositions[i][1],
        5, dotColors[i], alpha: 0.20);
    }

    // Wavy line (top area)
    final wavePaint = Paint()
      ..color = AppColors.primary.withAlpha(18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    final wavePath = Path();
    wavePath.moveTo(w * 0.30, h * 0.02);
    for (int i = 0; i < 6; i++) {
      final x1 = w * (0.30 + i * 0.08 + 0.04);
      final y1 = h * (i.isEven ? 0.00 : 0.04);
      final x2 = w * (0.30 + (i + 1) * 0.08);
      final y2 = h * 0.02;
      wavePath.quadraticBezierTo(x1, y1, x2, y2);
    }
    canvas.drawPath(wavePath, wavePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

// ── Empty state ────────────────────────────────────────────────────────
class _EmptyRooms extends StatelessWidget {
  const _EmptyRooms();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              shape: BoxShape.circle,
            ),
            child: const Center(child: Text('🎉', style: TextStyle(fontSize: 36))),
          ),
          const SizedBox(height: 16),
          const Text('لا توجد غرف حالياً',
            style: TextStyle(color: AppColors.textSecondary, fontFamily: 'Cairo', fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          const Text('كن أول من يبدأ الحفلة!',
            style: TextStyle(color: AppColors.textHint, fontFamily: 'Cairo', fontSize: 13)),
        ],
      ),
    );
  }
}

// ── Error state ────────────────────────────────────────────────────────
class _ErrorRooms extends StatelessWidget {
  const _ErrorRooms({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(
              color: AppColors.red.withAlpha(15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.wifi_off_rounded, size: 32, color: AppColors.red),
          ),
          const SizedBox(height: 16),
          const Text('تعذّر تحميل الغرف',
            style: TextStyle(color: AppColors.textSecondary, fontFamily: 'Cairo', fontSize: 15)),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('إعادة المحاولة', style: TextStyle(fontFamily: 'Cairo')),
          ),
        ],
      ),
    );
  }
}

// ── Shimmer card ───────────────────────────────────────────────────────
class _RoomShimmer extends StatelessWidget {
  const _RoomShimmer();

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: const Color(0xFFF0F2FF),
      highlightColor: Colors.white,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF0F2FF),
          borderRadius: BorderRadius.circular(24),
        ),
      ),
    );
  }
}
