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

// ── عدد المقاعد من Firestore (يتحدث فورياً عند التغيير) ─────────
final roomMaxSeatsProvider = StreamProvider.family<int, String>((ref, roomId) {
  return RoomStateRepository().watchRoomMaxSeats(roomId);
});

// ── مقاعد Firestore ──────────────────────────────────────────────
final roomSeatsStreamProvider =
    StreamProvider.family<List<SeatModel>, String>((ref, roomId) {
  final maxSeats = ref.watch(roomMaxSeatsProvider(roomId)).valueOrNull ?? 9;
  return RoomStateRepository().watchSeats(roomId, maxSeats: maxSeats);
});

// مستوى الصوت المحلي (من ZEGOCLOUD)
final speakingUsersProvider = StateProvider<Set<String>>((ref) => {});

// تعديلات محلية فورية قبل تأكيد Firestore (index → SeatModel? ، null = فارغ)
final optimisticSeatsProvider =
    StateProvider.family<Map<int, SeatModel?>, String>((_, __) => {});

// المقاعد مع حالة التحدث المحلية مدمجة + الـ optimistic patch
final seatsProvider = Provider.family<List<SeatModel>, String>((ref, roomId) {
  final maxSeats = ref.watch(roomMaxSeatsProvider(roomId)).valueOrNull ?? 9;
  final seats = ref.watch(roomSeatsStreamProvider(roomId)).valueOrNull ??
      List.generate(maxSeats, (i) => SeatModel(index: i));
  final patches = ref.watch(optimisticSeatsProvider(roomId));
  final speaking = ref.watch(speakingUsersProvider);
  return seats.map((s) {
    final SeatModel base;
    if (patches.containsKey(s.index)) {
      base = patches[s.index] ?? SeatModel(index: s.index);
    } else {
      base = s;
    }
    return base.copyWith(
      isSpeaking: base.userId != null && speaking.contains(base.userId),
    );
  }).toList();
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
    int sessionDiamonds = 0,
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
        sessionDiamonds: sessionDiamonds,
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
final isMicMutedProvider         = StateProvider<bool>((ref) => false);
final isRoomAudioMutedProvider   = StateProvider<bool>((ref) => false);
final myCurrentSeatProvider      = StateProvider<int>((ref) => -1);
final isHostProvider             = StateProvider<bool>((ref) => false);

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

// ── شريط الهدايا: هل هو نشط؟ ─────────────────────────────────────
final giftBarActiveProvider = StreamProvider.family<bool, String>((ref, roomId) {
  return FirebaseFirestore.instance
      .collection('rooms')
      .doc(roomId)
      .snapshots()
      .map((doc) => doc.data()?['challengeActive'] as bool? ?? false);
});

// ── إجمالي هدايا شريط الهدايا ─────────────────────────────────────
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

// ── عدد الزوار الحاليين (من subcollection members) ───────────────
final memberCountProvider = StreamProvider.family<int, String>((ref, roomId) {
  return RoomStateRepository().watchMemberCount(roomId);
});

// ── قائمة الزوار الحاليين ─────────────────────────────────────
final roomMembersProvider = StreamProvider.family<List<Map<String, dynamic>>, String>((ref, roomId) {
  return RoomStateRepository().watchMembers(roomId);
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
