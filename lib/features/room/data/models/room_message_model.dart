enum MessageType { text, system, gift, join, leave }

class RoomMessageModel {
  final String id;
  final String? senderId;
  final String? senderName;
  final String? senderAvatar;
  final String content;
  final MessageType type;
  final DateTime createdAt;
  final int senderLevel;
  // gift-specific: emoji stored separately so animations can use it directly
  final String? giftEmoji;

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
  });

  bool get isSystem => type == MessageType.system || type == MessageType.join || type == MessageType.leave;
}
