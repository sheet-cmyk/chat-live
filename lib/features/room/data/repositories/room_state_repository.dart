import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/seat_model.dart';
import '../models/room_message_model.dart';

class RoomStateRepository {
  static final RoomStateRepository _i = RoomStateRepository._();
  factory RoomStateRepository() => _i;
  RoomStateRepository._();

  final _db = FirebaseFirestore.instance;

  CollectionReference _seats(String roomId) =>
      _db.collection('rooms').doc(roomId).collection('seats');

  CollectionReference _messages(String roomId) =>
      _db.collection('rooms').doc(roomId).collection('room_messages');

  CollectionReference _members(String roomId) =>
      _db.collection('rooms').doc(roomId).collection('members');

  // ── مقاعد ───────────────────────────────────────────────────
  Stream<List<SeatModel>> watchSeats(String roomId) {
    return _seats(roomId).orderBy(FieldPath.documentId).snapshots().map(
      (snap) {
        // ابدأ بـ 9 مقاعد فارغة ثم ملأها من Firestore
        final seats = List.generate(9, (i) => SeatModel(index: i));
        for (final doc in snap.docs) {
          final idx = int.tryParse(doc.id);
          if (idx == null || idx < 0 || idx > 8) continue;
          final d = doc.data() as Map<String, dynamic>;
          seats[idx] = SeatModel(
            index: idx,
            userId: d['userId'] as String?,
            userName: d['userName'] as String?,
            userAvatar: d['userAvatar'] as String?,
            isMuted: d['isMuted'] as bool? ?? false,
            isLocked: d['isLocked'] as bool? ?? false,
            userLevel: d['userLevel'] as int? ?? 1,
            userVip: d['userVip'] as int? ?? 0,
          );
        }
        return seats;
      },
    );
  }

  Future<void> takeSeat(String roomId, SeatModel seat) async {
    await _seats(roomId).doc('${seat.index}').set({
      'userId': seat.userId,
      'userName': seat.userName,
      'userAvatar': seat.userAvatar,
      'isMuted': seat.isMuted,
      'isLocked': seat.isLocked,
      'userLevel': seat.userLevel,
      'userVip': seat.userVip,
    });
  }

  Future<void> leaveSeat(String roomId, int index) async {
    await _seats(roomId).doc('$index').set({
      'userId': null,
      'userName': null,
      'userAvatar': null,
      'isMuted': false,
      'isLocked': false,
      'userLevel': 1,
      'userVip': 0,
    });
  }

  // Clears the seat only if it is still owned by [userId] — prevents race conditions.
  Future<void> leaveSeatIfOwner(
      String roomId, int index, String userId) async {
    final ref = _seats(roomId).doc('$index');
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return;
      final current = (snap.data() as Map<String, dynamic>?)?['userId'];
      if (current != userId) return;
      tx.set(ref, {
        'userId': null,
        'userName': null,
        'userAvatar': null,
        'isMuted': false,
        'isLocked': false,
        'userLevel': 1,
        'userVip': 0,
      });
    });
  }

  Future<void> setSeatMuted(String roomId, int index, bool muted) async {
    await _seats(roomId).doc('$index').update({'isMuted': muted});
  }

  Future<void> setSeatLocked(String roomId, int index, bool locked) async {
    await _seats(roomId).doc('$index').update({'isLocked': locked});
  }

  // ── رسائل الغرفة ─────────────────────────────────────────────
  Stream<List<RoomMessageModel>> watchMessages(String roomId) {
    return _messages(roomId)
        .orderBy('createdAt', descending: false)
        .limitToLast(80)
        .snapshots()
        .map((snap) => snap.docs.map((doc) {
              final d = doc.data() as Map<String, dynamic>;
              return RoomMessageModel(
                id: doc.id,
                senderId: d['senderId'] as String?,
                senderName: d['senderName'] as String?,
                senderAvatar: d['senderAvatar'] as String?,
                content: d['content'] as String? ?? '',
                type: MessageType.values.firstWhere(
                  (e) => e.name == (d['type'] ?? 'text'),
                  orElse: () => MessageType.text,
                ),
                createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
                senderLevel: d['senderLevel'] as int? ?? 1,
                giftEmoji: d['giftEmoji'] as String?,
              );
            }).toList());
  }

  Future<void> sendMessage(String roomId, RoomMessageModel msg) async {
    final data = <String, dynamic>{
      'senderId': msg.senderId,
      'senderName': msg.senderName,
      'senderAvatar': msg.senderAvatar,
      'content': msg.content,
      'type': msg.type.name,
      'createdAt': Timestamp.fromDate(msg.createdAt),
      'senderLevel': msg.senderLevel,
    };
    if (msg.giftEmoji != null) data['giftEmoji'] = msg.giftEmoji;
    await _messages(roomId).doc(msg.id).set(data);
  }

  // ── أعضاء الغرفة ─────────────────────────────────────────────
  Future<void> joinRoom({
    required String roomId,
    required String userId,
    required String userName,
    String? userAvatar,
  }) async {
    final batch = _db.batch();
    // سجل في members
    batch.set(
      _members(roomId).doc(userId),
      {'userId': userId, 'userName': userName, 'userAvatar': userAvatar, 'joinedAt': FieldValue.serverTimestamp()},
    );
    // زد عدد المتصلين
    batch.update(
      _db.collection('rooms').doc(roomId),
      {'onlineCount': FieldValue.increment(1)},
    );
    await batch.commit();
  }

  Future<void> leaveRoom({required String roomId, required String userId}) async {
    final batch = _db.batch();
    batch.delete(_members(roomId).doc(userId));
    batch.update(
      _db.collection('rooms').doc(roomId),
      {'onlineCount': FieldValue.increment(-1)},
    );
    await batch.commit();
  }

  // ── كتم الدردشة ──────────────────────────────────────────────────
  CollectionReference _chatMuted(String roomId) =>
      _db.collection('rooms').doc(roomId).collection('chat_muted');

  Future<void> muteChatUser(String roomId, String userId, bool mute) async {
    final ref = _chatMuted(roomId).doc(userId);
    if (mute) {
      await ref.set({'mutedAt': FieldValue.serverTimestamp()});
    } else {
      await ref.delete();
    }
  }

  Stream<bool> isChatMutedStream(String roomId, String userId) {
    return _chatMuted(roomId).doc(userId).snapshots().map((s) => s.exists);
  }

  // ── طرد من الغرفة ─────────────────────────────────────────────────
  CollectionReference _kicks(String roomId) =>
      _db.collection('rooms').doc(roomId).collection('room_kicks');

  Future<void> kickFromRoom(String roomId, String userId) async {
    await _kicks(roomId).doc(userId).set({'kickedAt': FieldValue.serverTimestamp()});
  }

  Stream<bool> watchRoomKick(String roomId, String userId) {
    return _kicks(roomId).doc(userId).snapshots().map((s) => s.exists);
  }

  // ── إدارة الغرفة ─────────────────────────────────────────────────
  Future<void> updateRoomName(String roomId, String newName) async {
    await _db.collection('rooms').doc(roomId).update({'name': newName});
  }

  Future<void> activateChallenge(String roomId, DateTime endTime) async {
    await _db.collection('rooms').doc(roomId).update({
      'challengeActive': true,
      'challengeEndTime': Timestamp.fromDate(endTime),
      'challengeGiftTotal': 0,  // إعادة ضبط عداد الهدايا عند كل تحدي جديد
    });
  }

  Future<void> deactivateChallenge(String roomId) async {
    await _db.collection('rooms').doc(roomId).update({
      'challengeActive': false,
      'challengeEndTime': FieldValue.delete(),
    });
  }
}
