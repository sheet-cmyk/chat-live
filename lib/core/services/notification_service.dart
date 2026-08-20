import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:uuid/uuid.dart';

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final _fln = FlutterLocalNotificationsPlugin();
  final _messaging = FirebaseMessaging.instance;
  final _db = FirebaseFirestore.instance;

  static const _channelId = 'party_hub_main';
  static const _channelName = 'Party Hub';

  Future<void> init(String userId) async {
    // --- Local Notifications setup ---
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _fln.initialize(
      const InitializationSettings(android: android),
      onDidReceiveNotificationResponse: _onTap,
    );

    await _fln
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(const AndroidNotificationChannel(
          _channelId,
          _channelName,
          importance: Importance.high,
          playSound: true,
        ));

    // --- FCM Permission ---
    final settings = await _messaging.requestPermission(
      alert: true, badge: true, sound: true,
    );
    if (settings.authorizationStatus == AuthorizationStatus.denied) return;

    // --- Save token ---
    final token = await _messaging.getToken();
    if (token != null) await _saveToken(userId, token);
    _messaging.onTokenRefresh.listen((t) => _saveToken(userId, t));

    // --- Foreground messages ---
    FirebaseMessaging.onMessage.listen((msg) => _showLocal(msg));

    // --- Tap on notification when app in background ---
    FirebaseMessaging.onMessageOpenedApp.listen(_handleOpen);

    // --- Tap when app was terminated ---
    final initial = await _messaging.getInitialMessage();
    if (initial != null) _handleOpen(initial);
  }

  Future<void> _saveToken(String userId, String token) async {
    await _db.collection('users').doc(userId).set({'fcmToken': token}, SetOptions(merge: true))
        .catchError((_) {});
  }

  void _showLocal(RemoteMessage msg) {
    final n = msg.notification;
    if (n == null) return;
    _fln.show(
      n.hashCode,
      n.title,
      n.body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId, _channelName,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
      ),
      payload: msg.data['route'],
    );
  }

  void _onTap(NotificationResponse res) {
    // Navigation يتم عبر payload — يمكن توسيعه لاحقاً بـ GlobalKey<NavigatorState>
    debugPrint('[FCM] notification tapped: ${res.payload}');
  }

  void _handleOpen(RemoteMessage msg) {
    debugPrint('[FCM] opened from: ${msg.data}');
  }

  // --- إرسال إشعار لمستخدم آخر عبر Firestore ---
  Future<void> sendToUser({
    required String targetUid,
    required String title,
    required String body,
    required String type,
    Map<String, dynamic> extra = const {},
  }) async {
    try {
      final notifId = const Uuid().v4();
      await _db
          .collection('users')
          .doc(targetUid)
          .collection('notifications')
          .doc(notifId)
          .set({
        'id': notifId,
        'title': title,
        'body': body,
        'type': type,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
        ...extra,
      });
    } catch (e) {
      debugPrint('[FCM] sendToUser error: $e');
    }
  }

  Future<void> clearToken(String userId) async {
    try {
      await _messaging.deleteToken();
      await _db
          .collection('users')
          .doc(userId)
          .update({'fcmToken': FieldValue.delete()});
    } catch (_) {}
  }
}
