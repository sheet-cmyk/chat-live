import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/message_model.dart';
import '../../../../core/services/notification_service.dart';

class ChatRepository {
  final _db = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;

  Future<ConversationModel> getOrCreateConversation({
    required String myId,
    required String myName,
    String? myAvatar,
    required String otherId,
    required String otherName,
    String? otherAvatar,
  }) async {
    final ids = [myId, otherId]..sort();
    final convId = ids.join('_');
    final ref = _db.collection('conversations').doc(convId);

    final snap = await ref.get();
    if (snap.exists) return ConversationModel.fromFirestore(snap);

    final conv = ConversationModel(
      id: convId,
      participantIds: ids,
      participantNames: {myId: myName, otherId: otherName},
      participantAvatars: {myId: myAvatar, otherId: otherAvatar},
      unreadCount: {myId: 0, otherId: 0},
    );

    await ref.set({
      'participantIds': conv.participantIds,
      'participantNames': conv.participantNames,
      'participantAvatars': conv.participantAvatars,
      'unreadCount': conv.unreadCount,
      'lastMessage': null,
      'lastMessageAt': null,
      'lastSenderId': null,
    });

    return conv;
  }

  Stream<List<ConversationModel>> watchConversations(String userId) {
    return _db
        .collection('conversations')
        .where('participantIds', arrayContains: userId)
        .orderBy('lastMessageAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(ConversationModel.fromFirestore).toList());
  }

  Stream<List<MessageModel>> watchMessages(String conversationId) {
    return _db
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .orderBy('createdAt', descending: false)
        .limitToLast(100)
        .snapshots()
        .map((snap) => snap.docs.map(MessageModel.fromFirestore).toList());
  }

  Future<void> sendMessage({
    required String conversationId,
    required String senderId,
    required String senderName,
    String? senderAvatar,
    required String content,
    required String receiverId,
    MessageContentType contentType = MessageContentType.text,
  }) async {
    try {
      final convRef = _db.collection('conversations').doc(conversationId);
      final msgRef = convRef.collection('messages').doc();

      final batch = _db.batch();
      batch.set(msgRef, MessageModel(
        id: msgRef.id,
        conversationId: conversationId,
        senderId: senderId,
        senderName: senderName,
        senderAvatar: senderAvatar,
        content: content,
        contentType: contentType,
        createdAt: DateTime.now(),
      ).toFirestore());

      final preview = contentType == MessageContentType.image
          ? '📷 صورة'
          : contentType == MessageContentType.voice
              ? '🎤 رسالة صوتية'
              : content;

      batch.update(convRef, {
        'lastMessage': preview,
        'lastMessageAt': FieldValue.serverTimestamp(),
        'lastSenderId': senderId,
        'unreadCount.$receiverId': FieldValue.increment(1),
      });

      await batch.commit();

      // إشعار للمستقبل
      NotificationService.instance.sendToUser(
        targetUid: receiverId,
        title: senderName,
        body: preview,
        type: 'message',
        extra: {'senderId': senderId, 'conversationId': conversationId},
      );
    } catch (e) {
      debugPrint('[Chat] sendMessage error: $e');
    }
  }

  // رفع صورة إلى Storage ثم إرسالها
  Future<void> sendImageMessage({
    required String conversationId,
    required String senderId,
    required String senderName,
    String? senderAvatar,
    required File imageFile,
    required String receiverId,
  }) async {
    try {
      final fileName = '${const Uuid().v4()}.jpg';
      final ref = _storage.ref('chat_images/$conversationId/$fileName');
      await ref.putFile(imageFile, SettableMetadata(contentType: 'image/jpeg'));
      final url = await ref.getDownloadURL();

      await sendMessage(
        conversationId: conversationId,
        senderId: senderId,
        senderName: senderName,
        senderAvatar: senderAvatar,
        content: url,
        receiverId: receiverId,
        contentType: MessageContentType.image,
      );
    } catch (e) {
      debugPrint('[Chat] sendImageMessage error: $e');
    }
  }

  // رفع رسالة صوتية إلى Storage ثم إرسالها
  Future<void> sendVoiceMessage({
    required String conversationId,
    required String senderId,
    required String senderName,
    String? senderAvatar,
    required File audioFile,
    required String receiverId,
  }) async {
    try {
      final fileName = '${const Uuid().v4()}.m4a';
      final ref = _storage.ref('chat_audio/$conversationId/$fileName');
      await ref.putFile(audioFile, SettableMetadata(contentType: 'audio/m4a'));
      final url = await ref.getDownloadURL();

      await sendMessage(
        conversationId: conversationId,
        senderId: senderId,
        senderName: senderName,
        senderAvatar: senderAvatar,
        content: url,
        receiverId: receiverId,
        contentType: MessageContentType.voice,
      );
    } catch (e) {
      debugPrint('[Chat] sendVoiceMessage error: $e');
    }
  }

  Future<void> markAsRead(String conversationId, String userId) async {
    try {
      await _db.collection('conversations').doc(conversationId).update({
        'unreadCount.$userId': 0,
      });
    } catch (_) {}
  }

  Future<void> deleteMessage(String conversationId, String messageId) async {
    try {
      await _db
          .collection('conversations')
          .doc(conversationId)
          .collection('messages')
          .doc(messageId)
          .update({'isDeleted': true, 'content': 'تم حذف هذه الرسالة'});
    } catch (_) {}
  }
}
