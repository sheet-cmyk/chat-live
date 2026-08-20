import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'theme/app_theme.dart';
import 'routes.dart';
import '../l10n/app_localizations.dart';
import '../core/services/notification_service.dart';
import '../core/localization/locale_provider.dart';

class PartyHubApp extends ConsumerStatefulWidget {
  const PartyHubApp({super.key});

  @override
  ConsumerState<PartyHubApp> createState() => _PartyHubAppState();
}

class _PartyHubAppState extends ConsumerState<PartyHubApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _listenAuth();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final isOnline = state == AppLifecycleState.resumed;
    FirebaseFirestore.instance.collection('users').doc(uid).set({
      'isOnline': isOnline,
      'lastSeen': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true)).catchError((_) {});
  }

  void _listenAuth() {
    FirebaseAuth.instance.authStateChanges().listen((user) async {
      if (user != null) {
        // تفعيل الإشعارات وتحديث حالة الاتصال
        await NotificationService.instance.init(user.uid);
        FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'isOnline': true,
          'lastSeen': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true)).catchError((_) {});
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeProvider);
    return ScreenUtilInit(
      designSize: const Size(390, 844),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        return MaterialApp.router(
          title: 'Party Hub',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.darkTheme,
          routerConfig: appRouter,
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: const [Locale('ar'), Locale('en')],
          builder: (context, child) {
            return Directionality(
              textDirection: locale.languageCode == 'ar' ? TextDirection.rtl : TextDirection.ltr,
              child: child!,
            );
          },
        );
      },
    );
  }
}
