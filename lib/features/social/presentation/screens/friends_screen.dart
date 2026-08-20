import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../app/theme/app_colors.dart';
import '../providers/social_provider.dart';

class FriendsScreen extends ConsumerStatefulWidget {
  const FriendsScreen({super.key});

  @override
  ConsumerState<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends ConsumerState<FriendsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pending = ref.watch(pendingRequestsProvider).valueOrNull ?? [];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: AppColors.textPrimary, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('الأصدقاء', style: TextStyle(
          color: AppColors.textPrimary, fontFamily: 'Cairo', fontWeight: FontWeight.w700,
        )),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textHint,
          labelStyle: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700),
          tabs: [
            const Tab(text: 'أصدقائي'),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('الطلبات', style: TextStyle(fontFamily: 'Cairo')),
                  if (pending.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(color: AppColors.error, borderRadius: BorderRadius.circular(8)),
                      child: Text('${pending.length}', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _FriendsList(),
          _PendingList(),
        ],
      ),
    );
  }
}

class _FriendsList extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myId = FirebaseAuth.instance.currentUser?.uid ?? '';
    final friends = ref.watch(friendsProvider);

    return friends.when(
      loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
      error: (_, __) => const Center(child: Text('خطأ في التحميل', style: TextStyle(color: AppColors.textSecondary, fontFamily: 'Cairo'))),
      data: (list) {
        if (list.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('👥', style: TextStyle(fontSize: 52)),
                SizedBox(height: 12),
                Text('لا يوجد أصدقاء بعد', style: TextStyle(color: AppColors.textPrimary, fontFamily: 'Cairo', fontSize: 16, fontWeight: FontWeight.w600)),
                SizedBox(height: 6),
                Text('ادخل غرفة وتعرف على أشخاص جدد!', style: TextStyle(color: AppColors.textHint, fontFamily: 'Cairo', fontSize: 13)),
              ],
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: list.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (_, i) => _FriendTile(
            friend: list[i],
            myId: myId,
            onUnfriend: () => ref.read(socialRepositoryProvider).rejectOrUnfriend(list[i].id),
          ),
        );
      },
    );
  }
}

class _PendingList extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myId = FirebaseAuth.instance.currentUser?.uid ?? '';
    final pending = ref.watch(pendingRequestsProvider);

    return pending.when(
      loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
      error: (_, __) => const Center(child: Text('خطأ', style: TextStyle(color: AppColors.textSecondary, fontFamily: 'Cairo'))),
      data: (list) {
        if (list.isEmpty) {
          return const Center(child: Text('لا توجد طلبات معلقة', style: TextStyle(color: AppColors.textHint, fontFamily: 'Cairo')));
        }
        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: list.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (_, i) => _RequestTile(
            friend: list[i],
            myId: myId,
            onAccept: () => ref.read(socialRepositoryProvider).acceptRequest(list[i].id),
            onReject: () => ref.read(socialRepositoryProvider).rejectOrUnfriend(list[i].id),
          ),
        );
      },
    );
  }
}

class _FriendTile extends StatelessWidget {
  const _FriendTile({required this.friend, required this.myId, required this.onUnfriend});
  final FriendModel friend;
  final String myId;
  final VoidCallback onUnfriend;

  @override
  Widget build(BuildContext context) {
    final name = friend.otherUserName(myId);
    final avatar = friend.otherUserAvatar(myId);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: AppColors.primary,
            backgroundImage: avatar != null ? CachedNetworkImageProvider(avatar) : null,
            child: avatar == null ? Text(name.isNotEmpty ? name[0] : '?', style: const TextStyle(color: Colors.white, fontSize: 16)) : null,
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(name, style: const TextStyle(color: AppColors.textPrimary, fontFamily: 'Cairo', fontWeight: FontWeight.w600))),
          TextButton(
            onPressed: onUnfriend,
            child: const Text('إلغاء', style: TextStyle(color: AppColors.error, fontFamily: 'Cairo')),
          ),
        ],
      ),
    );
  }
}

class _RequestTile extends StatelessWidget {
  const _RequestTile({required this.friend, required this.myId, required this.onAccept, required this.onReject});
  final FriendModel friend;
  final String myId;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final name = friend.otherUserName(myId);
    final avatar = friend.otherUserAvatar(myId);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: AppColors.primary,
            backgroundImage: avatar != null ? CachedNetworkImageProvider(avatar) : null,
            child: avatar == null ? Text(name.isNotEmpty ? name[0] : '?', style: const TextStyle(color: Colors.white, fontSize: 16)) : null,
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: const TextStyle(color: AppColors.textPrimary, fontFamily: 'Cairo', fontWeight: FontWeight.w600)),
              const Text('يريد إضافتك صديقاً', style: TextStyle(color: AppColors.textHint, fontFamily: 'Cairo', fontSize: 12)),
            ],
          )),
          Row(
            children: [
              GestureDetector(
                onTap: onAccept,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(8)),
                  child: const Text('قبول', style: TextStyle(color: Colors.white, fontFamily: 'Cairo', fontSize: 12, fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: onReject,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: AppColors.surfaceLight, borderRadius: BorderRadius.circular(8)),
                  child: const Text('رفض', style: TextStyle(color: AppColors.textHint, fontFamily: 'Cairo', fontSize: 12)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
