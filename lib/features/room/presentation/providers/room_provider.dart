import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../data/models/seat_model.dart';
import '../../data/models/room_message_model.dart';
import '../../data/repositories/room_state_repository.dart';
import '../../../home/data/models/room_model.dart';

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
