import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../data/models/seat_model.dart';
import '../../data/models/room_message_model.dart';
import '../../data/repositories/room_state_repository.dart';
import '../../../home/data/models/room_model.dart';

// بيانات الراسل الأعلى في لوحة الهدايا
class GiftLeader {
  final String userId;
  final String name;
  final String? avatar;
  final int total;
  const GiftLeader(this.userId, this.name, this.avatar, this.total);
}

// الغرفة الحالية
final currentRoomProvider = StateProvider<RoomModel?>((ref) => null);

// ── مقاعد Firestore ──────────────────────────────────────────────
final roomSeatsStreamProvider =
    StreamProvider.family<List<SeatModel>, String>((ref, roomId) {
  return RoomStateRepository().watchSeats(roomId);
});

// مستوى الصوت المحلي (من ZEGOCLOUD)
final speakingUsersProvider = StateProvider<Set<String>>((ref) => {});

// المقاعد مع حالة التحدث المحلية مدمجة
final seatsProvider = Provider.family<List<SeatModel>, String>((ref, roomId) {
  final seats = ref.watch(roomSeatsStreamProvider(roomId)).valueOrNull ??
      List.generate(9, (i) => SeatModel(index: i));
  final speaking = ref.watch(speakingUsersProvider);
  return seats
      .map((s) => s.copyWith(
            isSpeaking: s.userId != null && speaking.contains(s.userId),
          ))
      .toList();
});

// ── كاتب المقاعد ─────────────────────────────────────────────────
class SeatsWriter {
  SeatsWriter(this._roomId);
  final String _roomId;
  final _repo = RoomStateRepository();

  Future<void> takeSeat(int index, {
    required String userId,
    required String userName,
    String? userAvatar,
    int userLevel = 1,
    int userVip = 0,
    String? nameColor,
  }) async {
    await _repo.takeSeat(
      _roomId,
      SeatModel(
        index: index,
        userId: userId,
        userName: userName,
        userAvatar: userAvatar,
        userLevel: userLevel,
        userVip: userVip,
        nameColor: nameColor,
      ),
    );
  }

  Future<void> leaveSeat(int index) async {
    await _repo.leaveSeat(_roomId, index);
  }

  Future<void> leaveSeatIfOwner(int index, String userId) async {
    await _repo.leaveSeatIfOwner(_roomId, index, userId);
  }

  Future<void> toggleMute(int index, bool currentMuted) async {
    await _repo.setSeatMuted(_roomId, index, !currentMuted);
  }

  Future<void> toggleLock(int index, bool currentLocked) async {
    await _repo.setSeatLocked(_roomId, index, !currentLocked);
  }

  Future<void> kickFromSeat(int index) async {
    await _repo.leaveSeat(_roomId, index);
  }
}

final seatsWriterProvider = Provider.family<SeatsWriter, String>(
  (ref, roomId) => SeatsWriter(roomId),
);

// ── رسائل Firestore ───────────────────────────────────────────────
final roomChatStreamProvider =
    StreamProvider.family<List<RoomMessageModel>, String>((ref, roomId) {
  return RoomStateRepository().watchMessages(roomId);
});

// كاتب الرسائل
final chatWriterProvider = Provider.family<_ChatWriter, String>(
  (ref, roomId) => _ChatWriter(roomId),
);

class _ChatWriter {
  _ChatWriter(this._roomId);
  final String _roomId;
  final _repo = RoomStateRepository();

  Future<void> sendUserMessage({
    required String senderId,
    required String senderName,
    String? senderAvatar,
    required String content,
    int level = 1,
    String? nameColor,
    String? textColor,
  }) async {
    await _repo.sendMessage(
      _roomId,
      RoomMessageModel(
        id: const Uuid().v4(),
        senderId: senderId,
        senderName: senderName,
        senderAvatar: senderAvatar,
        content: content,
        type: MessageType.text,
        createdAt: DateTime.now(),
        senderLevel: level,
        nameColor: nameColor,
        textColor: textColor,
      ),
    );
  }

  Future<void> sendSystem(String content) async {
    await _repo.sendMessage(
      _roomId,
      RoomMessageModel(
        id: const Uuid().v4(),
        content: content,
        type: MessageType.system,
        createdAt: DateTime.now(),
      ),
    );
  }

  Future<void> sendEmojiReaction({
    required String senderId,
    required String senderName,
    required String emoji,
  }) async {
    await _repo.sendMessage(
      _roomId,
      RoomMessageModel(
        id: const Uuid().v4(),
        senderId: senderId,
        senderName: senderName,
        content: emoji,
        type: MessageType.emoji,
        createdAt: DateTime.now(),
      ),
    );
  }

  Future<void> sendGift({
    required String senderId,
    required String senderName,
    String? senderAvatar,
    String? receiverName,
    required String giftEmoji,
    required String giftName,
  }) async {
    final to = receiverName != null ? ' لـ $receiverName' : '';
    await _repo.sendMessage(
      _roomId,
      RoomMessageModel(
        id: const Uuid().v4(),
        senderId: senderId,
        senderName: senderName,
        senderAvatar: senderAvatar,
        content: '$senderName أرسل $giftEmoji $giftName$to 🎁',
        type: MessageType.gift,
        giftEmoji: giftEmoji,
        createdAt: DateTime.now(),
      ),
    );
  }
}

// ── حالات محلية ──────────────────────────────────────────────────
final isMicMutedProvider = StateProvider<bool>((ref) => false);
final myCurrentSeatProvider = StateProvider<int>((ref) => -1);
final isHostProvider = StateProvider<bool>((ref) => false);

// ── كتم الدردشة (roomId::userId) ─────────────────────────────────
final chatMutedProvider = StreamProvider.family<bool, String>((ref, key) {
  final idx = key.indexOf('::');
  if (idx < 0) return const Stream.empty();
  return RoomStateRepository().isChatMutedStream(key.substring(0, idx), key.substring(idx + 2));
});

// ── مجموع ماسات المستخدم المستلمة (للشريط تحت اسم المقعد) ────────
// يستخدم totalGiftDiamonds إن وجد، وإلا يرجع لـ diamonds كاحتياط
final userGiftDiamondsProvider = StreamProvider.family<int, String>((ref, userId) {
  if (userId.isEmpty) return const Stream.empty();
  return FirebaseFirestore.instance
      .collection('users')
      .doc(userId)
      .snapshots()
      .map((doc) {
        final data = doc.data();
        if (data == null) return 0;
        final total = (data['totalGiftDiamonds'] as num?)?.toInt();
        if (total != null && total > 0) return total;
        return (data['diamonds'] as num?)?.toInt() ?? 0;
      });
});

// ── إجمالي ماسات الهدايا خلال التحدي ────────────────────────────────
final challengeGiftTotalProvider = StreamProvider.family<int, String>((ref, roomId) {
  return FirebaseFirestore.instance
      .collection('rooms')
      .doc(roomId)
      .snapshots()
      .map((doc) {
        if (doc.data()?['challengeActive'] != true) return 0;
        return (doc.data()?['challengeGiftTotal'] as num?)?.toInt() ?? 0;
      });
});

// ── وقت انتهاء التحدي (null = لا يوجد تحدي نشط) ───────────────────
final challengeEndTimeProvider = StreamProvider.family<DateTime?, String>((ref, roomId) {
  return FirebaseFirestore.instance
      .collection('rooms')
      .doc(roomId)
      .snapshots()
      .map((doc) {
        final data = doc.data();
        if (data == null || data['challengeActive'] != true) return null;
        final ts = data['challengeEndTime'] as Timestamp?;
        return ts?.toDate();
      });
});

// ── إجمالي هدايا الغرفة (لحساب مستوى الغرفة) ─────────────────────
final roomTotalGiftsProvider = StreamProvider.family<int, String>((ref, roomId) {
  return FirebaseFirestore.instance
      .collection('rooms')
      .doc(roomId)
      .snapshots()
      .map((doc) => (doc.data()?['totalGiftsRoom'] as num?)?.toInt() ?? 0);
});

// ── لوحة صدارة الهدايا في الغرفة (top 5 senders) ─────────────────
final roomGiftLeaderboardProvider =
    StreamProvider.family<List<GiftLeader>, String>((ref, roomId) {
  return FirebaseFirestore.instance
      .collection('rooms')
      .doc(roomId)
      .collection('gift_leaderboard')
      .orderBy('total', descending: true)
      .limit(5)
      .snapshots()
      .map((snap) => snap.docs.map((doc) {
            final d = doc.data();
            return GiftLeader(
              doc.id,
              d['senderName'] as String? ?? 'مستخدم',
              d['senderAvatar'] as String?,
              (d['total'] as num?)?.toInt() ?? 0,
            );
          }).toList());
});

// ── إجمالي ما أرسله المستخدم من هدايا ────────────────────────────
final userTotalSentProvider = StreamProvider.family<int, String>((ref, userId) {
  if (userId.isEmpty) return const Stream.empty();
  return FirebaseFirestore.instance
      .collection('users')
      .doc(userId)
      .snapshots()
      .map((doc) => (doc.data()?['totalGiftsSent'] as num?)?.toInt() ?? 0);
});
