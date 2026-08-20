import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/group_model.dart';
import '../models/message_model.dart';
import '../../../../core/services/notification_service.dart';

class GroupRepository {
  final _db = FirebaseFirestore.instance;

  Future<GroupModel> createGroup({
    required String adminId,
    required String adminName,
    required String groupName,
    required List<String> memberIds,
    required Map<String, String> memberNames,
  }) async {
    final ref = _db.collection('groups').doc();
    final unreadCounts = {for (final id in memberIds) id: 0};
    final group = GroupModel(
      id: ref.id,
      name: groupName,
      adminId: adminId,
      memberIds: memberIds,
      memberNames: memberNames,
      unreadCounts: unreadCounts,
    );
    await ref.set(group.toFirestore());
    return group;
  }

  Stream<List<GroupModel>> watchGroups(String userId) {
    return _db
        .collection('groups')
        .where('memberIds', arrayContains: userId)
        .orderBy('lastMessageAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(GroupModel.fromFirestore).toList());
  }

  Stream<List<MessageModel>> watchMessages(String groupId) {
    return _db
        .collection('groups')
        .doc(groupId)
        .collection('messages')
        .orderBy('createdAt', descending: false)
        .limitToLast(100)
        .snapshots()
        .map((snap) => snap.docs.map(MessageModel.fromFirestore).toList());
  }

  Future<void> sendMessage({
    required String groupId,
    required String senderId,
    required String senderName,
    String? senderAvatar,
    required String content,
    required List<String> memberIds,
    MessageContentType contentType = MessageContentType.text,
  }) async {
    try {
      final groupRef = _db.collection('groups').doc(groupId);
      final msgRef = groupRef.collection('messages').doc();
      final batch = _db.batch();

      batch.set(msgRef, MessageModel(
        id: msgRef.id,
        conversationId: groupId,
        senderId: senderId,
        senderName: senderName,
        senderAvatar: senderAvatar,
        content: content,
        contentType: contentType,
        createdAt: DateTime.now(),
      ).toFirestore());

      // زيّد عداد القراءة لكل عضو عدا المُرسِل
      final unreadUpdate = <String, dynamic>{
        'lastMessage': content,
        'lastMessageAt': FieldValue.serverTimestamp(),
      };
      for (final uid in memberIds) {
        if (uid != senderId) {
          unreadUpdate['unreadCounts.$uid'] = FieldValue.increment(1);
        }
      }
      batch.update(groupRef, unreadUpdate);

      await batch.commit();

      // أرسل إشعار للأعضاء الآخرين
      for (final uid in memberIds) {
        if (uid != senderId) {
          NotificationService.instance.sendToUser(
            targetUid: uid,
            title: senderName,
            body: content,
            type: 'group_message',
            extra: {'groupId': groupId},
          );
        }
      }
    } catch (e) {
      debugPrint('[Group] sendMessage error: $e');
    }
  }

  Future<void> markAsRead(String groupId, String userId) async {
    try {
      await _db.collection('groups').doc(groupId).update({
        'unreadCounts.$userId': 0,
      });
    } catch (_) {}
  }

  Future<void> addMember(String groupId, String userId, String userName) async {
    try {
      await _db.collection('groups').doc(groupId).update({
        'memberIds': FieldValue.arrayUnion([userId]),
        'memberNames.$userId': userName,
        'unreadCounts.$userId': 0,
      });
    } catch (_) {}
  }

  Future<void> removeMember(String groupId, String userId) async {
    try {
      final doc = await _db.collection('groups').doc(groupId).get();
      final data = doc.data() as Map<String, dynamic>;
      final names = Map<String, dynamic>.from(data['memberNames'] ?? {});
      final counts = Map<String, dynamic>.from(data['unreadCounts'] ?? {});
      names.remove(userId);
      counts.remove(userId);
      await _db.collection('groups').doc(groupId).update({
        'memberIds': FieldValue.arrayRemove([userId]),
        'memberNames': names,
        'unreadCounts': counts,
      });
    } catch (_) {}
  }

  String generateGroupId() => const Uuid().v4();
}
