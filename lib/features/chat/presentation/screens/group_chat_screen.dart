import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../app/theme/app_colors.dart';
import '../../data/models/group_model.dart';
import '../../data/models/message_model.dart';
import '../../data/repositories/group_repository.dart';
import '../widgets/message_bubble.dart';

final _groupMessagesProvider = StreamProvider.family<List<MessageModel>, String>((ref, groupId) {
  return GroupRepository().watchMessages(groupId);
});

class GroupChatScreen extends ConsumerStatefulWidget {
  const GroupChatScreen({super.key, required this.group});
  final GroupModel group;

  @override
  ConsumerState<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends ConsumerState<GroupChatScreen> {
  final _textCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _myId = FirebaseAuth.instance.currentUser?.uid ?? '';
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    GroupRepository().markAsRead(widget.group.id, _myId);
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty || _sending) return;
    final me = FirebaseAuth.instance.currentUser;
    if (me == null) return;

    _textCtrl.clear();
    setState(() => _sending = true);
    await GroupRepository().sendMessage(
      groupId: widget.group.id,
      senderId: me.uid,
      senderName: me.displayName ?? 'مستخدم',
      senderAvatar: me.photoURL,
      content: text,
      memberIds: widget.group.memberIds,
    );
    setState(() => _sending = false);
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final messagesAsync = ref.watch(_groupMessagesProvider(widget.group.id));
    final isAdmin = widget.group.adminId == _myId;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        leadingWidth: 32,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: AppColors.textPrimary, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Container(
              width: 36, height: 36,
              decoration: const BoxDecoration(shape: BoxShape.circle, gradient: AppColors.primaryGradient),
              child: const Icon(Icons.group_rounded, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.group.name, style: const TextStyle(
                  color: AppColors.textPrimary, fontFamily: 'Cairo',
                  fontWeight: FontWeight.w700, fontSize: 14,
                )),
                Text('${widget.group.memberIds.length} عضو', style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 11, fontFamily: 'Cairo',
                )),
              ],
            ),
          ],
        ),
        actions: [
          if (isAdmin)
            IconButton(
              icon: const Icon(Icons.settings_rounded, color: AppColors.textSecondary),
              onPressed: () => _showGroupSettings(context),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: messagesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
              error: (_, __) => const Center(
                child: Text('خطأ في التحميل', style: TextStyle(color: AppColors.textSecondary, fontFamily: 'Cairo')),
              ),
              data: (list) {
                if (list.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('👥', style: TextStyle(fontSize: 48)),
                        SizedBox(height: 8),
                        Text('لا توجد رسائل بعد', style: TextStyle(color: AppColors.textHint, fontFamily: 'Cairo')),
                      ],
                    ),
                  );
                }
                WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
                return ListView.builder(
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  itemCount: list.length,
                  itemBuilder: (_, i) {
                    final msg = list[i];
                    final isMe = msg.senderId == _myId;
                    final showDate = i == 0 ||
                        !_sameDay(list[i - 1].createdAt, msg.createdAt);
                    final showAvatar = i == 0 || list[i - 1].senderId != msg.senderId;
                    return Column(
                      children: [
                        if (showDate) DateDivider(date: msg.createdAt),
                        MessageBubble(
                          message: msg, isMe: isMe,
                          showAvatar: showAvatar && !isMe,
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
          _GroupInput(
            controller: _textCtrl,
            onSend: _send,
            sending: _sending,
          ),
        ],
      ),
    );
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.day == b.day && a.month == b.month && a.year == b.year;

  void _showGroupSettings(BuildContext ctx) {
    showModalBottomSheet(
      context: ctx,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _GroupSettingsSheet(group: widget.group, myId: _myId),
    );
  }
}

// ── شريط إدخال المجموعة ─────────────────────────────────────────
class _GroupInput extends StatefulWidget {
  const _GroupInput({required this.controller, required this.onSend, required this.sending});
  final TextEditingController controller;
  final VoidCallback onSend;
  final bool sending;

  @override
  State<_GroupInput> createState() => _GroupInputState();
}

class _GroupInputState extends State<_GroupInput> {
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(() => setState(() => _hasText = widget.controller.text.isNotEmpty));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      padding: EdgeInsets.only(
        left: 12, right: 12, top: 8,
        bottom: MediaQuery.of(context).viewInsets.bottom + 8,
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surfaceLight, borderRadius: BorderRadius.circular(24),
              ),
              child: TextField(
                controller: widget.controller,
                style: const TextStyle(color: AppColors.textPrimary, fontFamily: 'Cairo'),
                maxLines: 4, minLines: 1,
                textDirection: TextDirection.rtl,
                decoration: const InputDecoration(
                  hintText: 'اكتب رسالة للمجموعة...',
                  hintStyle: TextStyle(color: AppColors.textHint, fontFamily: 'Cairo'),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                onSubmitted: (_) => widget.onSend(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _hasText && !widget.sending ? widget.onSend : null,
            child: Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: _hasText ? AppColors.primaryGradient : null,
                color: _hasText ? null : AppColors.surfaceLight,
              ),
              child: widget.sending
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : Icon(Icons.send_rounded,
                      color: _hasText ? Colors.white : AppColors.textHint, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}

// ── إعدادات المجموعة (للأدمن) ───────────────────────────────────
class _GroupSettingsSheet extends StatelessWidget {
  const _GroupSettingsSheet({required this.group, required this.myId});
  final GroupModel group;
  final String myId;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(child: Container(width: 40, height: 4,
              decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 16),
          Text(group.name, style: const TextStyle(
            color: AppColors.textPrimary, fontSize: 17, fontWeight: FontWeight.w700, fontFamily: 'Cairo',
          )),
          const SizedBox(height: 4),
          Text('${group.memberIds.length} عضو', style: const TextStyle(
            color: AppColors.textSecondary, fontFamily: 'Cairo', fontSize: 13,
          )),
          const SizedBox(height: 16),
          const Divider(color: AppColors.divider),
          const SizedBox(height: 8),
          const Text('الأعضاء', style: TextStyle(
            color: AppColors.textSecondary, fontFamily: 'Cairo', fontSize: 12,
          )),
          const SizedBox(height: 8),
          SizedBox(
            height: 200,
            child: ListView.builder(
              itemCount: group.memberIds.length,
              itemBuilder: (_, i) {
                final uid = group.memberIds[i];
                final name = group.memberNames[uid] ?? 'مستخدم';
                final isAdmin = uid == group.adminId;
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    radius: 18,
                    backgroundColor: AppColors.primary,
                    child: Text(name[0], style: const TextStyle(color: Colors.white, fontSize: 14)),
                  ),
                  title: Text(name, style: const TextStyle(
                    color: AppColors.textPrimary, fontFamily: 'Cairo', fontSize: 13,
                  )),
                  trailing: isAdmin
                      ? Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withAlpha(30),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text('أدمن', style: TextStyle(
                            color: AppColors.primary, fontSize: 10, fontFamily: 'Cairo',
                          )),
                        )
                      : myId == group.adminId
                          ? IconButton(
                              icon: const Icon(Icons.remove_circle_outline_rounded,
                                  color: AppColors.error, size: 18),
                              onPressed: () async {
                                await GroupRepository().removeMember(group.id, uid);
                                if (context.mounted) Navigator.pop(context);
                              },
                            )
                          : null,
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.error,
                side: const BorderSide(color: AppColors.error),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.exit_to_app_rounded),
              label: const Text('مغادرة المجموعة', style: TextStyle(fontFamily: 'Cairo')),
              onPressed: () async {
                await GroupRepository().removeMember(group.id, myId);
                if (context.mounted) {
                  Navigator.pop(context);
                  Navigator.pop(context);
                }
              },
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
