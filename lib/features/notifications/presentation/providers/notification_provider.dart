import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../data/repositories/notification_repository.dart';

final notificationRepositoryProvider = Provider<NotificationRepository>(
  (ref) => NotificationRepository(),
);

// استدعه عند تسجيل الدخول
Future<void> initNotifications(Ref ref) async {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return;
  await ref.read(notificationRepositoryProvider).init(uid);
}
