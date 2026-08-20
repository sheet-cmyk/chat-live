import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../app/theme/app_colors.dart';
import '../../data/models/message_model.dart';
import '../providers/chat_provider.dart';
import '../widgets/message_bubble.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key, required this.conversation});
  final ConversationModel conversation;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _textCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _myId = FirebaseAuth.instance.currentUser?.uid ?? '';
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    ref.read(chatRepositoryProvider).markAsRead(widget.conversation.id, _myId);
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

    await ref.read(chatRepositoryProvider).sendMessage(
      conversationId: widget.conversation.id,
      senderId: me.uid,
      senderName: me.displayName ?? 'مستخدم',
      senderAvatar: me.photoURL,
      content: text,
      receiverId: widget.conversation.otherUserId(_myId),
    );

    setState(() => _sending = false);
    _scrollToBottom();
  }

  Future<void> _sendImage() async {
    final me = FirebaseAuth.instance.currentUser;
    if (me == null) return;

    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (picked == null) return;

    setState(() => _sending = true);
    await ref.read(chatRepositoryProvider).sendImageMessage(
      conversationId: widget.conversation.id,
      senderId: me.uid,
      senderName: me.displayName ?? 'مستخدم',
      senderAvatar: me.photoURL,
      imageFile: File(picked.path),
      receiverId: widget.conversation.otherUserId(_myId),
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
    final messages = ref.watch(messagesProvider(widget.conversation.id));
    final otherName = widget.conversation.otherUserName(_myId);
    final otherAvatar = widget.conversation.otherUserAvatar(_myId);

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
            CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.primary,
              backgroundImage: otherAvatar != null ? NetworkImage(otherAvatar) : null,
              child: otherAvatar == null
                  ? Text(otherName.isNotEmpty ? otherName[0] : '?',
                      style: const TextStyle(color: Colors.white, fontSize: 14))
                  : null,
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(otherName, style: const TextStyle(
                  color: AppColors.textPrimary, fontFamily: 'Cairo',
                  fontWeight: FontWeight.w700, fontSize: 14,
                )),
                const Text('متصل', style: TextStyle(color: AppColors.success, fontSize: 11, fontFamily: 'Cairo')),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.call_rounded, color: AppColors.textSecondary), onPressed: () {}),
          IconButton(icon: const Icon(Icons.more_vert_rounded, color: AppColors.textSecondary), onPressed: () {}),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: messages.when(
              loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
              error: (_, __) => const Center(
                child: Text('خطأ في تحميل الرسائل',
                    style: TextStyle(color: AppColors.textSecondary, fontFamily: 'Cairo')),
              ),
              data: (list) {
                if (list.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('👋', style: TextStyle(fontSize: 48)),
                        SizedBox(height: 8),
                        Text('ابدأ المحادثة!',
                            style: TextStyle(color: AppColors.textHint, fontFamily: 'Cairo')),
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
                    final showDate = i == 0 || !_sameDay(list[i - 1].createdAt, msg.createdAt);
                    final showAvatar = i == 0 || list[i - 1].senderId != msg.senderId;
                    return Column(
                      children: [
                        if (showDate) DateDivider(date: msg.createdAt),
                        MessageBubble(message: msg, isMe: isMe, showAvatar: showAvatar && !isMe),
                      ],
                    );
                  },
                );
              },
            ),
          ),
          _ChatInput(
            controller: _textCtrl,
            onSend: _send,
            onImage: _sendImage,
            sending: _sending,
          ),
        ],
      ),
    );
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.day == b.day && a.month == b.month && a.year == b.year;
}

// ── شريط الإدخال الكامل ─────────────────────────────────────────
class _ChatInput extends StatefulWidget {
  const _ChatInput({
    required this.controller,
    required this.onSend,
    required this.onImage,
    required this.sending,
  });
  final TextEditingController controller;
  final VoidCallback onSend;
  final VoidCallback onImage;
  final bool sending;

  @override
  State<_ChatInput> createState() => _ChatInputState();
}

class _ChatInputState extends State<_ChatInput> {
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(() {
      setState(() => _hasText = widget.controller.text.isNotEmpty);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      padding: EdgeInsets.only(
        left: 8, right: 8, top: 8,
        bottom: MediaQuery.of(context).viewInsets.bottom + 8,
      ),
      child: Row(
        children: [
          // أيقونة الصورة
          _IconBtn(
            icon: Icons.image_rounded,
            color: AppColors.primary,
            onTap: widget.onImage,
          ),
          const SizedBox(width: 4),

          // حقل النص
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(24),
              ),
              child: TextField(
                controller: widget.controller,
                style: const TextStyle(color: AppColors.textPrimary, fontFamily: 'Cairo'),
                maxLines: 4,
                minLines: 1,
                textDirection: TextDirection.rtl,
                decoration: const InputDecoration(
                  hintText: 'اكتب رسالة...',
                  hintStyle: TextStyle(color: AppColors.textHint, fontFamily: 'Cairo'),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                onSubmitted: (_) => widget.onSend(),
              ),
            ),
          ),
          const SizedBox(width: 4),

          // إرسال أو ميكروفون
          _hasText
              ? GestureDetector(
                  onTap: widget.sending ? null : widget.onSend,
                  child: Container(
                    width: 44, height: 44,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle, gradient: AppColors.primaryGradient,
                    ),
                    child: widget.sending
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                  ),
                )
              : Tooltip(
                  message: 'الرسائل الصوتية قريباً',
                  child: Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primary.withAlpha(20),
                    ),
                    child: Icon(Icons.mic_rounded, color: AppColors.primary.withAlpha(80), size: 22),
                  ),
                ),
        ],
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  const _IconBtn({required this.icon, required this.color, required this.onTap});
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38, height: 38,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color.withAlpha(25)),
        child: Icon(icon, color: color, size: 20),
      ),
    );
  }
}
