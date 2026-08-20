import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../l10n/app_localizations.dart';
import '../app/theme/app_colors.dart';
import '../features/auth/presentation/screens/login_screen.dart';
import '../features/auth/presentation/screens/otp_screen.dart';
import '../features/auth/presentation/screens/register_screen.dart';
import '../features/auth/presentation/providers/auth_provider.dart';
import '../features/home/presentation/screens/main_screen.dart';
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
import '../features/onboarding/presentation/screens/onboarding_screen.dart';
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
  static const String otp = '/otp';
  static const String register = '/register';
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
  static const String greedyStar = '/greedy-star';
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
          state.matchedLocation == AppRoutes.otp ||
          state.matchedLocation == AppRoutes.register ||
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
        path: AppRoutes.otp,
        builder: (context, state) => const OtpScreen(),
      ),
      GoRoute(
        path: AppRoutes.register,
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: AppRoutes.home,
        builder: (context, state) => const Scaffold(
          body: Center(child: Text('الشاشة الرئيسية - المرحلة 3A', style: TextStyle(color: Colors.white))),
        ),
      ),
    ],
  );
}

// Router بسيط بدون Auth Guard للمرحلة الحالية
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
      path: AppRoutes.otp,
      builder: (context, state) => const OtpScreen(),
    ),
    GoRoute(
      path: AppRoutes.register,
      builder: (context, state) => const RegisterScreen(),
    ),
    GoRoute(
      path: AppRoutes.home,
      builder: (context, state) => const MainScreen(),
    ),
    GoRoute(
      path: AppRoutes.room,
      builder: (context, state) {
        final room = state.extra as RoomModel;
        return RoomScreen(room: room);
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
      path: '/onboarding',
      builder: (context, state) => const OnboardingScreen(),
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
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    // أول تشغيل → Onboarding
    final done = await isOnboardingDone();
    if (!mounted) return;
    if (!done) { context.go('/onboarding'); return; }

    // انتظر Firebase حتى تُعيد جلسة المستخدم المخزّنة
    final user = await ref.read(authStateProvider.future);
    if (!mounted) return;

    if (user != null) {
      // Bootstrap admin privileges for seed email (safe no-op for others)
      AdminRepository().bootstrapIfNeeded(user);
      final wallet = WalletRepository();
      // هدية الترحيب للمستخدمين القدامى (تُعطى مرة واحدة فقط)
      wallet.ensureWelcomeBonus(user.uid);
      // المكافأة اليومية المجانية
      wallet.checkAndClaimDailyFreeCoins(user.uid).then((claimed) {
        if (claimed > 0 && mounted) {
          ref.read(pendingDailyCoinsProvider.notifier).state = claimed;
        }
      });
      context.go(AppRoutes.home);
    } else {
      context.go(AppRoutes.login);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      body: Stack(
        children: [
          Container(decoration: const BoxDecoration(gradient: AppColors.darkGradient)),
          Positioned(
            top: -60, right: -60,
            child: Container(
              width: 200, height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withAlpha(40),
              ),
            ),
          ),
          Positioned(
            bottom: -80, left: -40,
            child: Container(
              width: 250, height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.accent.withAlpha(30),
              ),
            ),
          ),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 110, height: 110,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: AppColors.primaryGradient,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withAlpha(100),
                        blurRadius: 30, spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.celebration_rounded, size: 60, color: Colors.white),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Party Hub',
                  style: TextStyle(fontSize: 36, fontWeight: FontWeight.w700, color: AppColors.textPrimary, letterSpacing: 1.2),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.partyTime,
                  style: const TextStyle(fontSize: 16, color: AppColors.textSecondary, fontFamily: 'Cairo'),
                ),
                const SizedBox(height: 48),
                const SizedBox(
                  width: 28, height: 28,
                  child: CircularProgressIndicator(
                    color: AppColors.primary, strokeWidth: 2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
