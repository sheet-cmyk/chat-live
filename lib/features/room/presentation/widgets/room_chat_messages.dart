import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../data/models/room_message_model.dart';

typedef UserTapCallback = void Function(String userId, String userName, String? avatar);

class RoomChatMessages extends StatelessWidget {
  const RoomChatMessages({
    super.key,
    required this.messages,
    required this.scrollController,
    this.onUserTap,
  });

  final List<RoomMessageModel> messages;
  final ScrollController scrollController;
  final UserTapCallback? onUserTap;

  @override
  Widget build(BuildContext context) {
    if (messages.isEmpty) return const SizedBox.shrink();

    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: messages.length,
      itemBuilder: (_, i) {
        final msg = messages[i];
        if (msg.type == MessageType.gift) return _GiftMessage(msg: msg);
        return msg.isSystem
            ? _SystemMessage(msg: msg)
            : _UserMessage(msg: msg, onUserTap: onUserTap);
      },
    );
  }
}

class _SystemMessage extends StatelessWidget {
  const _SystemMessage({required this.msg});
  final RoomMessageModel msg;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black.withAlpha(80),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              msg.content,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11,
                fontFamily: 'Cairo',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GiftMessage extends StatelessWidget {
  const _GiftMessage({required this.msg});
  final RoomMessageModel msg;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.primary.withAlpha(60), AppColors.accent.withAlpha(40)],
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.primary.withAlpha(80)),
        ),
        child: Text(
          msg.content,
          style: const TextStyle(color: AppColors.gold, fontSize: 12, fontFamily: 'Cairo', fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

class _UserMessage extends StatelessWidget {
  const _UserMessage({required this.msg, this.onUserTap});
  final RoomMessageModel msg;
  final UserTapCallback? onUserTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          // أفاتار المُرسِل — اضغط عليه لفتح الملف الشخصي
          GestureDetector(
            onTap: () => _tapUser(),
            child: CircleAvatar(
              radius: 13,
              backgroundColor: AppColors.primary,
              backgroundImage: msg.senderAvatar != null
                  ? NetworkImage(msg.senderAvatar!)
                  : null,
              child: msg.senderAvatar == null
                  ? Text(
                      (msg.senderName ?? '?')[0].toUpperCase(),
                      style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold),
                    )
                  : null,
            ),
          ),
          const SizedBox(width: 6),
          // اسم + رسالة — اضغط على الاسم لفتح الملف الشخصي
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withAlpha(100),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(14),
                  topRight: Radius.circular(14),
                  bottomLeft: Radius.circular(14),
                  bottomRight: Radius.circular(4),
                ),
              ),
              child: RichText(
                text: TextSpan(
                  children: [
                    WidgetSpan(
                      child: GestureDetector(
                        onTap: () => _tapUser(),
                        child: Text(
                          '${msg.senderName ?? ''} ',
                          style: const TextStyle(
                            color: AppColors.primaryLight,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'Cairo',
                          ),
                        ),
                      ),
                    ),
                    TextSpan(
                      text: msg.content,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 12,
                        fontFamily: 'Cairo',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _tapUser() {
    if (onUserTap != null && msg.senderId != null) {
      onUserTap!(msg.senderId!, msg.senderName ?? 'مستخدم', msg.senderAvatar);
    }
  }
}
