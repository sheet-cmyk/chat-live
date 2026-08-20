import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/friend_model.dart';

class SocialRepository {
  final _db = FirebaseFirestore.instance;

  Future<void> sendFriendRequest({
    required String myId,
    required String myName,
    String? myAvatar,
    required String otherId,
    required String otherName,
    String? otherAvatar,
  }) async {
    final ids = [myId, otherId]..sort();
    final docId = ids.join('_');
    try {
      await _db.collection('friends').doc(docId).set(
        FriendModel(
          id: docId,
          requesterId: myId,
          requesterName: myName,
          requesterAvatar: myAvatar,
          receiverId: otherId,
          receiverName: otherName,
          receiverAvatar: otherAvatar,
          status: FriendStatus.pending,
          createdAt: DateTime.now(),
        ).toFirestore(),
        SetOptions(merge: false),
      );
    } catch (e) {
      debugPrint('[Social] sendFriendRequest error: $e');
    }
  }

  Future<void> acceptRequest(String docId) async {
    await _db.collection('friends').doc(docId).update({'status': 'accepted'});
  }

  Future<void> rejectOrUnfriend(String docId) async {
    await _db.collection('friends').doc(docId).delete();
  }

  Stream<List<FriendModel>> watchFriends(String userId) {
    return _db
        .collection('friends')
        .where('participants', arrayContains: userId)
        .where('status', isEqualTo: 'accepted')
        .snapshots()
        .map((s) => s.docs.map(FriendModel.fromFirestore).toList());
  }

  Stream<List<FriendModel>> watchPendingRequests(String userId) {
    return _db
        .collection('friends')
        .where('receiverId', isEqualTo: userId)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((s) => s.docs.map(FriendModel.fromFirestore).toList());
  }

  Future<FriendStatus?> checkFriendship(String myId, String otherId) async {
    final ids = [myId, otherId]..sort();
    final doc = await _db.collection('friends').doc(ids.join('_')).get();
    if (!doc.exists) return null;
    return FriendModel.fromFirestore(doc).status;
  }
}
