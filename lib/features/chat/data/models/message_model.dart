import 'package:cloud_firestore/cloud_firestore.dart';

enum MessageStatus { sent, delivered, read }
enum MessageContentType { text, image, gift, voice }

class MessageModel {
  final String id;
  final String conversationId;
  final String senderId;
  final String senderName;
  final String? senderAvatar;
  final String content;
  final MessageContentType contentType;
  final MessageStatus status;
  final DateTime createdAt;
  final bool isDeleted;

  const MessageModel({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.senderName,
    this.senderAvatar,
    required this.content,
    this.contentType = MessageContentType.text,
    this.status = MessageStatus.sent,
    required this.createdAt,
    this.isDeleted = false,
  });

  factory MessageModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return MessageModel(
      id: doc.id,
      conversationId: d['conversationId'] ?? '',
      senderId: d['senderId'] ?? '',
      senderName: d['senderName'] ?? '',
      senderAvatar: d['senderAvatar'],
      content: d['content'] ?? '',
      contentType: MessageContentType.values.firstWhere(
        (t) => t.name == (d['contentType'] ?? 'text'),
        orElse: () => MessageContentType.text,
      ),
      status: MessageStatus.values.firstWhere(
        (s) => s.name == (d['status'] ?? 'sent'),
        orElse: () => MessageStatus.sent,
      ),
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isDeleted: d['isDeleted'] ?? false,
    );
  }

  Map<String, dynamic> toFirestore() => {
    'conversationId': conversationId,
    'senderId': senderId,
    'senderName': senderName,
    'senderAvatar': senderAvatar,
    'content': content,
    'contentType': contentType.name,
    'status': status.name,
    'createdAt': FieldValue.serverTimestamp(),
    'isDeleted': isDeleted,
  };
}

class ConversationModel {
  final String id;
  final List<String> participantIds;
  final Map<String, String> participantNames;
  final Map<String, String?> participantAvatars;
  final String? lastMessage;
  final DateTime? lastMessageAt;
  final String? lastSenderId;
  final Map<String, int> unreadCount;

  const ConversationModel({
    required this.id,
    required this.participantIds,
    required this.participantNames,
    required this.participantAvatars,
    this.lastMessage,
    this.lastMessageAt,
    this.lastSenderId,
    this.unreadCount = const {},
  });

  factory ConversationModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return ConversationModel(
      id: doc.id,
      participantIds: List<String>.from(d['participantIds'] ?? []),
      participantNames: Map<String, String>.from(d['participantNames'] ?? {}),
      participantAvatars: Map<String, String?>.from(d['participantAvatars'] ?? {}),
      lastMessage: d['lastMessage'],
      lastMessageAt: (d['lastMessageAt'] as Timestamp?)?.toDate(),
      lastSenderId: d['lastSenderId'],
      unreadCount: Map<String, int>.from(d['unreadCount'] ?? {}),
    );
  }

  String otherUserId(String myId) =>
      participantIds.firstWhere((id) => id != myId, orElse: () => '');

  String otherUserName(String myId) => participantNames[otherUserId(myId)] ?? 'مستخدم';
  String? otherUserAvatar(String myId) => participantAvatars[otherUserId(myId)];
  int myUnread(String myId) => unreadCount[myId] ?? 0;
}
