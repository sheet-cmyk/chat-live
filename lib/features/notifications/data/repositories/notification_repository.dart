import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

class NotificationRepository {
  final _messaging = FirebaseMessaging.instance;
  final _db = FirebaseFirestore.instance;

  Future<void> init(String userId) async {
    try {
      final settings = await _messaging.requestPermission(
        alert: true, badge: true, sound: true,
      );
      if (settings.authorizationStatus == AuthorizationStatus.denied) return;

      final token = await _messaging.getToken();
      if (token != null) await _saveToken(userId, token);

      _messaging.onTokenRefresh.listen((t) => _saveToken(userId, t));

      FirebaseMessaging.onMessage.listen(_onForeground);
    } catch (e) {
      debugPrint('[FCM] init error: $e');
    }
  }

  Future<void> _saveToken(String userId, String token) async {
    await _db.collection('users').doc(userId).update({'fcmToken': token});
  }

  void _onForeground(RemoteMessage msg) {
    debugPrint('[FCM] رسالة في المقدمة: ${msg.notification?.title}');
  }

  Future<void> clearToken(String userId) async {
    try {
      await _messaging.deleteToken();
      await _db.collection('users').doc(userId).update({'fcmToken': FieldValue.delete()});
    } catch (_) {}
  }
}
