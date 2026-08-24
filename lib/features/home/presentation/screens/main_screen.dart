import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/routes.dart';
import '../../../../core/providers/active_room_provider.dart';
import '../../../../core/services/zego_service.dart';
import '../../data/repositories/room_repository.dart';
import '../providers/home_provider.dart';
import 'home_screen.dart';
import 'create_room_sheet.dart';
import '../../../auth/presentation/screens/profile_screen.dart';
import '../../../chat/presentation/screens/messages_screen.dart';
import '../../../ranking/presentation/screens/ranking_screen.dart';
import '../../../chat/presentation/providers/chat_provider.dart';
import '../../../room/presentation/providers/room_provider.dart';
import '../../../room/data/repositories/room_state_repository.dart';

class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> {
  static const _screens = [
    HomeScreen(),
    MessagesScreen(),
    RankingScreen(),
    ProfileScreen(),
  ];

  Future<void> _exitMinimizedRoom(MinimizedRoomState state) async {
    await ZegoService().leaveRoom();

    if (state.mySeat >= 0) {
      await ref.read(seatsWriterProvider(state.room.roomId)).leaveSeat(state.mySeat);
    }

    await ref.read(chatWriterProvider(state.room.roomId)).sendSystem(
      '${state.userName} غادر الغرفة',
    );

    await RoomStateRepository().leaveRoom(
      roomId: state.room.roomId,
      userId: state.userId,
    );

    ref.read(myCurrentSeatProvider.notifier).state = -1;
    ref.read(minimizedRoomProvider.notifier).state = null;
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = ref.watch(bottomNavIndexProvider);
    final minimized = ref.watch(minimizedRoomProvider);

    // احفظ التبويب الحالي عند كل تغيير
    ref.listen(bottomNavIndexProvider, (_, index) async {
      final prefs = await SharedPreferences.getInstance();
      prefs.setInt('last_nav_tab', index);
    });

    return Scaffold(
      body: Stack(
        children: [
          IndexedStack(index: currentIndex, children: _screens),
          if (minimized != null)
            _FloatingBubble(
              state: minimized,
              onTap: () {
                ref.read(minimizedRoomProvider.notifier).state = null;
                context.push(AppRoutes.room, extra: minimized.room);
              },
              onClose: () => _exitMinimizedRoom(minimized),
            ),
        ],
      ),
      floatingActionButton: _CreateRoomFab(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: _BottomNav(currentIndex: currentIndex),
    );
  }
}

// ── زر إنشاء الغرفة الذكي ─────────────────────────────────────────────
class _CreateRoomFab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () => _onTap(context, ref),
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: AppColors.primaryGradient,
          boxShadow: [
            BoxShadow(color: AppColors.primary.withAlpha(100), blurRadius: 20, spreadRadius: 0, offset: const Offset(0, 8)),
            BoxShadow(color: AppColors.accent.withAlpha(60), blurRadius: 12, spreadRadius: 0, offset: const Offset(0, 4)),
          ],
        ),
        child: const Icon(Icons.add_rounded, color: Colors.white, size: 32),
      ),
    );
  }

  Future<void> _onTap(BuildContext context, WidgetRef ref) async {
    // إن كانت هناك غرفة مصغّرة، استعدها
    final minimized = ref.read(minimizedRoomProvider);
    if (minimized != null) {
      ref.read(minimizedRoomProvider.notifier).state = null;
      if (context.mounted) context.push(AppRoutes.room, extra: minimized.room);
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // ابحث عن غرفة نشطة للمستخدم في Firestore
    final existing = await RoomRepository().fetchMyActiveRoom(user.uid);
    if (!context.mounted) return;

    if (existing != null) {
      // توجه للغرفة الموجودة
      context.push(AppRoutes.room, extra: existing);
    } else {
      // أنشئ غرفة جديدة
      showCreateRoomSheet(context);
    }
  }
}

// ── فقاعة الغرفة العائمة ──────────────────────────────────────────────
class _FloatingBubble extends StatefulWidget {
  const _FloatingBubble({
    required this.state,
    required this.onTap,
    required this.onClose,
  });
  final MinimizedRoomState state;
  final VoidCallback onTap;
  final VoidCallback onClose;

  @override
  State<_FloatingBubble> createState() => _FloatingBubbleState();
}

class _FloatingBubbleState extends State<_FloatingBubble> {
  Offset _offset = const Offset(16, 120);

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Positioned(
      left: _offset.dx,
      top: _offset.dy,
      child: GestureDetector(
        onPanUpdate: (d) {
          setState(() {
            _offset = Offset(
              (_offset.dx + d.delta.dx).clamp(0.0, size.width - 72),
              (_offset.dy + d.delta.dy).clamp(0.0, size.height - 140),
            );
          });
        },
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            GestureDetector(
              onTap: widget.onTap,
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: AppColors.primaryGradient,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withAlpha(140),
                      blurRadius: 18,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.mic_rounded, color: Colors.white, size: 22),
                    const SizedBox(height: 2),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        widget.state.room.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                          fontFamily: 'Cairo',
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              top: -5,
              right: -5,
              child: GestureDetector(
                onTap: widget.onClose,
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.red.shade600,
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                  child: const Icon(Icons.close, color: Colors.white, size: 13),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── شريط التنقل ───────────────────────────────────────────────────────
class _BottomNav extends ConsumerWidget {
  const _BottomNav({required this.currentIndex});
  final int currentIndex;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(totalUnreadProvider);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: const Color(0xFF3C4043).withAlpha(18))),
        boxShadow: [
          BoxShadow(color: const Color(0xFF3C4043).withAlpha(18), blurRadius: 16, offset: const Offset(0, -4)),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 72,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(icon: Icons.home_rounded,        label: 'الرئيسية', index: 0, current: currentIndex),
              _NavItem(icon: Icons.chat_bubble_rounded, label: 'الرسائل',  index: 1, current: currentIndex, badge: unread > 0 ? unread : null),
              const SizedBox(width: 56),
              _NavItem(icon: Icons.leaderboard_rounded, label: 'الترتيب',  index: 2, current: currentIndex),
              _NavItem(icon: Icons.person_rounded,      label: 'حسابي',    index: 3, current: currentIndex),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends ConsumerWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.index,
    required this.current,
    this.badge,
  });
  final IconData icon;
  final String label;
  final int index;
  final int current;
  final int? badge;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSelected = index == current;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => ref.read(bottomNavIndexProvider.notifier).state = index,
      child: SizedBox(
        width: 64,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(icon, color: isSelected ? AppColors.primary : AppColors.textHint, size: 24),
                if (badge != null)
                  Positioned(
                    top: -4, right: -6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(color: AppColors.error, borderRadius: BorderRadius.circular(8)),
                      child: Text(
                        badge! > 99 ? '99+' : '$badge',
                        style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 3),
            Text(label, style: TextStyle(
              color: isSelected ? AppColors.primary : AppColors.textHint,
              fontSize: 10,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.normal,
              fontFamily: 'Cairo',
            )),
          ],
        ),
      ),
    );
  }
}
