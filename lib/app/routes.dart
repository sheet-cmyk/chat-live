import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../features/auth/presentation/screens/login_screen.dart';
import '../features/auth/presentation/screens/setup_profile_screen.dart';
import '../features/auth/presentation/providers/auth_provider.dart';
import '../features/home/presentation/screens/main_screen.dart';
import '../features/home/presentation/providers/home_provider.dart';
import '../features/room/presentation/screens/room_screen.dart';
import '../features/home/data/models/room_model.dart';
import '../features/wallet/presentation/screens/wallet_screen.dart';
import '../features/vip/presentation/screens/vip_screen.dart';
import '../features/game/presentation/screens/games_hub_screen.dart';
import '../features/social/presentation/screens/friends_screen.dart';
import '../features/search/presentation/screens/search_screen.dart';
import '../features/settings/presentation/screens/settings_screen.dart';
import '../features/notifications/presentation/screens/notifications_screen.dart';
import '../features/wallet/presentation/screens/daily_reward_screen.dart';
import '../features/home/presentation/screens/room_history_screen.dart';
import '../features/wallet/data/repositories/wallet_repository.dart';
import '../features/sweet_bonanza/screens/sb_entry_screen.dart';
import '../features/admin/presentation/screens/admin_screen.dart';
import '../features/admin/data/repositories/admin_repository.dart';
import '../features/game/presentation/screens/greedy_star_screen.dart';

// عدد العملات اليومية المستلمة — يُعرض كإشعار في الصفحة الرئيسية
final pendingDailyCoinsProvider = StateProvider<int>((_) => 0);

class AppRoutes {
  static const String splash = '/';
  static const String login = '/login';
  static const String home = '/home';
  static const String room = '/room';
  static const String chat = '/chat';
  static const String profile = '/profile';
  static const String search = '/search';
  static const String ranking = '/ranking';
  static const String wallet = '/wallet';
  static const String settings = '/settings';
  static const String gift = '/gift';
  static const String vip = '/vip';
  static const String game = '/game';
  static const String sweetBonanza = '/sweet-bonanza';
  static const String notification = '/notification';
  static const String admin = '/admin';
  static const String greedyStar    = '/greedy-star';
  static const String setupProfile  = '/setup-profile';
}

final _rootNavigatorKey = GlobalKey<NavigatorState>();

GoRouter createAppRouter(WidgetRef ref) {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: AppRoutes.splash,
    redirect: (context, state) {
      final authState = ref.read(authStateProvider);
      final isLoggedIn = authState.valueOrNull != null;
      final isOnAuthPage = state.matchedLocation == AppRoutes.login ||
          state.matchedLocation == AppRoutes.splash;

      if (!isLoggedIn && !isOnAuthPage) return AppRoutes.login;
      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.home,
        builder: (context, state) => const MainScreen(),
      ),
    ],
  );
}

// Router الرئيسي
final GoRouter appRouter = GoRouter(
  initialLocation: AppRoutes.splash,
  routes: [
    GoRoute(
      path: AppRoutes.splash,
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: AppRoutes.login,
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: AppRoutes.home,
      builder: (context, state) => const MainScreen(),
    ),
    GoRoute(
      path: AppRoutes.room,
      builder: (context, state) {
        final room = state.extra as RoomModel;
        return RoomScreen(key: ValueKey(room.roomId), room: room);
      },
    ),
    GoRoute(
      path: AppRoutes.wallet,
      builder: (context, state) => const WalletScreen(),
    ),
    GoRoute(
      path: AppRoutes.vip,
      builder: (context, state) => const VipScreen(),
    ),
    GoRoute(
      path: AppRoutes.game,
      builder: (context, state) => const GamesHubScreen(),
    ),
    GoRoute(
      path: '/friends',
      builder: (context, state) => const FriendsScreen(),
    ),
    GoRoute(
      path: AppRoutes.search,
      builder: (context, state) => const SearchScreen(),
    ),
    GoRoute(
      path: AppRoutes.settings,
      builder: (context, state) => const SettingsScreen(),
    ),
    GoRoute(
      path: AppRoutes.notification,
      builder: (context, state) => const NotificationsScreen(),
    ),
    GoRoute(
      path: '/daily-reward',
      builder: (context, state) => const DailyRewardScreen(),
    ),
    GoRoute(
      path: '/room-history',
      builder: (context, state) => const RoomHistoryScreen(),
    ),
    GoRoute(
      path: AppRoutes.sweetBonanza,
      builder: (context, state) => const SbEntryScreen(),
    ),
    GoRoute(
      path: AppRoutes.admin,
      builder: (context, state) => const AdminScreen(),
    ),
    GoRoute(
      path: AppRoutes.greedyStar,
      builder: (context, state) => const GreedyStarScreen(),
    ),
    GoRoute(
      path: AppRoutes.setupProfile,
      builder: (context, state) => const SetupProfileScreen(),
    ),
  ],
);

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigate();
  }

  Future<void> _navigate() async {
    // انتظر Firebase فقط — بدون delay
    final user = await ref.read(authStateProvider.future);
    if (!mounted) return;

    if (user != null) {
      // تحقق من وجود ملف شخصي مكتمل في Firestore
      final profile = await ref.read(authRepositoryProvider).fetchCurrentUser();
      if (!mounted) return;

      if (profile == null || profile.displayName.isEmpty) {
        // مستخدم جديد أو لم يُكمل الملف الشخصي
        context.go(AppRoutes.setupProfile);
        return;
      }

      AdminRepository().bootstrapIfNeeded(user);
      final wallet = WalletRepository();
      wallet.ensureWelcomeBonus(user.uid);
      wallet.checkAndClaimDailyFreeCoins(user.uid).then((claimed) {
        if (claimed > 0 && mounted) {
          ref.read(pendingDailyCoinsProvider.notifier).state = claimed;
        }
      });
      // استعادة التبويب الأخير الذي كان فيه المستخدم
      final prefs = await SharedPreferences.getInstance();
      final lastTab = prefs.getInt('last_nav_tab') ?? 0;
      if (mounted) ref.read(bottomNavIndexProvider.notifier).state = lastTab;
      if (mounted) context.go(AppRoutes.home);
    } else {
      context.go(AppRoutes.login);
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(backgroundColor: Colors.white);
  }
}
