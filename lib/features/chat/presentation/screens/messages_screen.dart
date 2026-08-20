import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../../../../app/theme/app_colors.dart';
import '../../data/models/message_model.dart';
import '../../data/models/group_model.dart';
import '../../data/repositories/group_repository.dart';
import '../providers/chat_provider.dart';
import 'chat_screen.dart';
import 'group_chat_screen.dart';

// provider للمجموعات
final groupsProvider = StreamProvider<List<GroupModel>>((ref) {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return const Stream.empty();
  return GroupRepository().watchGroups(uid);
});

class MessagesScreen extends ConsumerStatefulWidget {
  const MessagesScreen({super.key});

  @override
  ConsumerState<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends ConsumerState<MessagesScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final myId = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        automaticallyImplyLeading: false,
        title: const Text('الرسائل', style: TextStyle(
          color: AppColors.textPrimary, fontFamily: 'Cairo',
          fontWeight: FontWeight.w700, fontSize: 18,
        )),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.group_add_rounded, color: AppColors.textSecondary),
            onPressed: () => _showCreateGroup(context, myId),
          ),
        ],
        bottom: TabBar(
          controller: _tabCtrl,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          labelStyle: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700),
          tabs: const [
            Tab(text: 'الخاصة'),
            Tab(text: 'المجموعات'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          _DirectMessages(myId: myId),
          _GroupMessages(myId: myId),
        ],
      ),
    );
  }

  void _showCreateGroup(BuildContext ctx, String myId) {
    final nameCtrl = TextEditingController();
    showModalBottomSheet(
      context: ctx,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20,
            MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(child: Container(width: 40, height: 4,
                decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),
            const Text('إنشاء مجموعة', style: TextStyle(
              color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w700, fontFamily: 'Cairo',
            )),
            const SizedBox(height: 16),
            TextField(
              controller: nameCtrl,
              autofocus: true,
              style: const TextStyle(color: AppColors.textPrimary, fontFamily: 'Cairo'),
              decoration: InputDecoration(
                hintText: 'اسم المجموعة...',
                hintStyle: const TextStyle(color: AppColors.textHint, fontFamily: 'Cairo'),
                filled: true,
                fillColor: AppColors.surfaceLight,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () async {
                  final name = nameCtrl.text.trim();
                  if (name.isEmpty) return;
                  final me = FirebaseAuth.instance.currentUser;
                  if (me == null) return;
                  await GroupRepository().createGroup(
                    adminId: me.uid,
                    adminName: me.displayName ?? 'مستخدم',
                    groupName: name,
                    memberIds: [me.uid],
                    memberNames: {me.uid: me.displayName ?? 'مستخدم'},
                  );
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: const Text('إنشاء', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700, fontSize: 15)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── تبويب الرسائل الخاصة ─────────────────────────────────────────
class _DirectMessages extends ConsumerWidget {
  const _DirectMessages({required this.myId});
  final String myId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final convs = ref.watch(conversationsProvider);
    return convs.when(
      loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
      error: (_, __) => const Center(
        child: Text('خطأ', style: TextStyle(color: AppColors.textSecondary, fontFamily: 'Cairo')),
      ),
      data: (list) {
        if (list.isEmpty) return const _EmptyState(icon: '💬', label: 'لا توجد محادثات خاصة بعد');
        return ListView.separated(
          itemCount: list.length,
          separatorBuilder: (_, __) => const Divider(color: AppColors.divider, height: 1, indent: 76),
          itemBuilder: (ctx, i) => _ConversationTile(
            conv: list[i], myId: myId,
            onTap: () => Navigator.push(ctx, MaterialPageRoute(
              builder: (_) => ChatScreen(conversation: list[i]),
            )),
          ),
        );
      },
    );
  }
}

// ── تبويب المجموعات ──────────────────────────────────────────────
class _GroupMessages extends ConsumerWidget {
  const _GroupMessages({required this.myId});
  final String myId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groups = ref.watch(groupsProvider);
    return groups.when(
      loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
      error: (_, __) => const Center(
        child: Text('خطأ', style: TextStyle(color: AppColors.textSecondary, fontFamily: 'Cairo')),
      ),
      data: (list) {
        if (list.isEmpty) return const _EmptyState(icon: '👥', label: 'لا توجد مجموعات بعد');
        return ListView.separated(
          itemCount: list.length,
          separatorBuilder: (_, __) => const Divider(color: AppColors.divider, height: 1, indent: 76),
          itemBuilder: (ctx, i) => _GroupTile(
            group: list[i], myId: myId,
            onTap: () => Navigator.push(ctx, MaterialPageRoute(
              builder: (_) => GroupChatScreen(group: list[i]),
            )),
          ),
        );
      },
    );
  }
}

// ── بطاقة المحادثة الخاصة ───────────────────────────────────────
class _ConversationTile extends StatelessWidget {
  const _ConversationTile({required this.conv, required this.myId, required this.onTap});
  final ConversationModel conv;
  final String myId;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final name = conv.otherUserName(myId);
    final avatar = conv.otherUserAvatar(myId);
    final unread = conv.myUnread(myId);
    final isMe = conv.lastSenderId == myId;

    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: Stack(
        clipBehavior: Clip.none,
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: AppColors.primary,
            backgroundImage: avatar != null ? CachedNetworkImageProvider(avatar) : null,
            child: avatar == null
                ? Text(name.isNotEmpty ? name[0] : '?',
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold))
                : null,
          ),
          Positioned(
            bottom: 0, left: 0,
            child: Container(
              width: 12, height: 12,
              decoration: BoxDecoration(
                color: AppColors.success, shape: BoxShape.circle,
                border: Border.all(color: AppColors.background, width: 2),
              ),
            ),
          ),
        ],
      ),
      title: Text(name, style: const TextStyle(
        color: AppColors.textPrimary, fontFamily: 'Cairo', fontWeight: FontWeight.w600, fontSize: 14,
      )),
      subtitle: conv.lastMessage != null
          ? Text(
              isMe ? 'أنت: ${conv.lastMessage}' : (conv.lastMessage ?? ''),
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: unread > 0 ? AppColors.textPrimary : AppColors.textHint,
                fontFamily: 'Cairo', fontSize: 12,
                fontWeight: unread > 0 ? FontWeight.w600 : FontWeight.normal,
              ),
            )
          : null,
      trailing: _TrailingTime(time: conv.lastMessageAt, unread: unread),
    );
  }
}

// ── بطاقة المجموعة ───────────────────────────────────────────────
class _GroupTile extends StatelessWidget {
  const _GroupTile({required this.group, required this.myId, required this.onTap});
  final GroupModel group;
  final String myId;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final unread = group.myUnread(myId);
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: Container(
        width: 52, height: 52,
        decoration: const BoxDecoration(shape: BoxShape.circle, gradient: AppColors.primaryGradient),
        child: const Icon(Icons.group_rounded, color: Colors.white, size: 26),
      ),
      title: Text(group.name, style: const TextStyle(
        color: AppColors.textPrimary, fontFamily: 'Cairo', fontWeight: FontWeight.w600, fontSize: 14,
      )),
      subtitle: group.lastMessage != null
          ? Text(group.lastMessage!, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: unread > 0 ? AppColors.textPrimary : AppColors.textHint,
                fontFamily: 'Cairo', fontSize: 12,
                fontWeight: unread > 0 ? FontWeight.w600 : FontWeight.normal,
              ))
          : Text('${group.memberIds.length} عضو',
              style: const TextStyle(color: AppColors.textHint, fontFamily: 'Cairo', fontSize: 12)),
      trailing: _TrailingTime(time: group.lastMessageAt, unread: unread),
    );
  }
}

class _TrailingTime extends StatelessWidget {
  const _TrailingTime({this.time, required this.unread});
  final DateTime? time;
  final int unread;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (time != null)
          Text(_timeLabel(time!), style: TextStyle(
            color: unread > 0 ? AppColors.primary : AppColors.textHint, fontSize: 11,
          )),
        const SizedBox(height: 4),
        if (unread > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(10)),
            child: Text('$unread', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
          ),
      ],
    );
  }

  String _timeLabel(DateTime dt) {
    final now = DateTime.now();
    if (dt.day == now.day) return DateFormat('hh:mm a', 'ar').format(dt);
    if (dt.day == now.subtract(const Duration(days: 1)).day) return 'أمس';
    return DateFormat('d/M', 'ar').format(dt);
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.label});
  final String icon;
  final String label;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(icon, style: const TextStyle(fontSize: 56)),
        const SizedBox(height: 12),
        Text(label, style: const TextStyle(
          color: AppColors.textHint, fontFamily: 'Cairo', fontSize: 14,
        )),
      ],
    ),
  );
}
