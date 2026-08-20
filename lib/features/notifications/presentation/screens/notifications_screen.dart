import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../app/theme/app_colors.dart';
import 'package:cached_network_image/cached_network_image.dart';

// بيانات إشعار واحد
class _NotifItem {
  final String id, title, body, type;
  final String? avatar;
  final bool isRead;
  final DateTime createdAt;

  const _NotifItem({
    required this.id, required this.title, required this.body,
    required this.type, this.avatar, required this.isRead, required this.createdAt,
  });

  factory _NotifItem.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return _NotifItem(
      id: doc.id,
      title: d['title'] as String? ?? '',
      body: d['body'] as String? ?? '',
      type: d['type'] as String? ?? 'system',
      avatar: d['avatar'] as String?,
      isRead: d['isRead'] as bool? ?? false,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

final _notifsProvider = StreamProvider<List<_NotifItem>>((ref) {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return const Stream.empty();
  return FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .collection('notifications')
      .orderBy('createdAt', descending: true)
      .limit(50)
      .snapshots()
      .map((s) => s.docs.map(_NotifItem.fromDoc).toList());
});

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifsAsync = ref.watch(_notifsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: const Text('الإشعارات', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton(
            onPressed: () => _markAllRead(),
            child: const Text('تحديد الكل مقروء', style: TextStyle(color: AppColors.primary, fontFamily: 'Cairo', fontSize: 12)),
          ),
        ],
      ),
      body: notifsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (_, __) => const Center(child: Text('خطأ في تحميل الإشعارات', style: TextStyle(color: AppColors.textSecondary, fontFamily: 'Cairo'))),
        data: (notifs) {
          if (notifs.isEmpty) return _emptyState();
          return ListView.separated(
            itemCount: notifs.length,
            separatorBuilder: (_, __) => const Divider(color: AppColors.divider, height: 1),
            itemBuilder: (_, i) => _NotifTile(notif: notifs[i]),
          );
        },
      ),
    );
  }

  void _markAllRead() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .where('isRead', isEqualTo: false)
        .get()
        .then((snap) {
      final batch = FirebaseFirestore.instance.batch();
      for (final doc in snap.docs) {
        batch.update(doc.reference, {'isRead': true});
      }
      batch.commit();
    });
  }

  Widget _emptyState() => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80, height: 80,
              decoration: const BoxDecoration(color: AppColors.surfaceLight, shape: BoxShape.circle),
              child: const Icon(Icons.notifications_off_outlined, color: AppColors.textHint, size: 40),
            ),
            const SizedBox(height: 16),
            const Text('لا توجد إشعارات', style: TextStyle(color: AppColors.textSecondary, fontFamily: 'Cairo', fontSize: 15)),
            const SizedBox(height: 8),
            const Text('ستظهر هنا إشعارات المتابعين والهدايا', style: TextStyle(color: AppColors.textHint, fontFamily: 'Cairo', fontSize: 12)),
          ],
        ),
      );
}

class _NotifTile extends StatelessWidget {
  const _NotifTile({required this.notif});
  final _NotifItem notif;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _markRead(),
      child: Container(
        color: notif.isRead ? Colors.transparent : AppColors.primary.withAlpha(15),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // أيقونة أو صورة
            _avatar(),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(notif.title, style: const TextStyle(color: AppColors.textPrimary, fontFamily: 'Cairo', fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(notif.body, style: const TextStyle(color: AppColors.textSecondary, fontFamily: 'Cairo', fontSize: 12)),
                  const SizedBox(height: 4),
                  Text(_timeAgo(notif.createdAt), style: const TextStyle(color: AppColors.textHint, fontSize: 10, fontFamily: 'Cairo')),
                ],
              ),
            ),
            if (!notif.isRead)
              Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle)),
          ],
        ),
      ),
    );
  }

  Widget _avatar() {
    if (notif.avatar != null) {
      return CachedNetworkImage(
        imageUrl: notif.avatar!,
        imageBuilder: (_, img) => CircleAvatar(radius: 22, backgroundImage: img),
        placeholder: (_, __) => _iconAvatar(),
        errorWidget: (_, __, ___) => _iconAvatar(),
      );
    }
    return _iconAvatar();
  }

  Widget _iconAvatar() {
    final icon = switch (notif.type) {
      'follow' => Icons.person_add_rounded,
      'gift'   => Icons.card_giftcard_rounded,
      'room'   => Icons.mic_rounded,
      'like'   => Icons.favorite_rounded,
      _        => Icons.notifications_rounded,
    };
    final color = switch (notif.type) {
      'follow' => AppColors.primary,
      'gift'   => AppColors.gold,
      'room'   => AppColors.accent,
      'like'   => AppColors.error,
      _        => AppColors.textSecondary,
    };
    return Container(
      width: 44, height: 44,
      decoration: BoxDecoration(color: color.withAlpha(30), shape: BoxShape.circle),
      child: Icon(icon, color: color, size: 22),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'الآن';
    if (diff.inMinutes < 60) return 'منذ ${diff.inMinutes} دقيقة';
    if (diff.inHours < 24) return 'منذ ${diff.inHours} ساعة';
    return 'منذ ${diff.inDays} يوم';
  }

  void _markRead() {
    if (notif.isRead) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    FirebaseFirestore.instance
        .collection('users').doc(uid)
        .collection('notifications').doc(notif.id)
        .update({'isRead': true});
  }
}
