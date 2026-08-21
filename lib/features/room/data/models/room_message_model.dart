enum MessageType { text, system, gift, join, leave, emoji }

class RoomMessageModel {
  final String id;
  final String? senderId;
  final String? senderName;
  final String? senderAvatar;
  final String content;
  final MessageType type;
  final DateTime createdAt;
  final int senderLevel;
  final String? giftEmoji;
  final String? nameColor;  // لون اسم المُرسِل (hex)
  final String? textColor;  // لون نص الرسالة (hex)

  const RoomMessageModel({
    required this.id,
    this.senderId,
    this.senderName,
    this.senderAvatar,
    required this.content,
    required this.type,
    required this.createdAt,
    this.senderLevel = 1,
    this.giftEmoji,
    this.nameColor,
    this.textColor,
  });

  bool get isSystem => type == MessageType.system || type == MessageType.join || type == MessageType.leave;
}
