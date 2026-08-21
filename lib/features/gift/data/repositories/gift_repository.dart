import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/gift_model.dart';
import '../../../wallet/data/repositories/wallet_repository.dart';

class GiftRepository {
  final _db = FirebaseFirestore.instance;
  final _wallet = WalletRepository();

  Future<List<GiftModel>> fetchGifts() async {
    try {
      final snap = await _db.collection('gifts').orderBy('coinPrice').get();
      if (snap.docs.isEmpty) return GiftModel.defaultGifts();
      return snap.docs.map(GiftModel.fromFirestore).toList();
    } catch (_) {
      return GiftModel.defaultGifts();
    }
  }

  Future<bool> sendGift({
    required String roomId,
    required String senderId,
    required String senderName,
    String? senderAvatar,
    String? receiverId,
    String? receiverName,
    required GiftModel gift,
    int quantity = 1,
  }) async {
    try {
      final totalCost = gift.coinPrice * quantity;
      final totalDiamonds = gift.diamondValue * quantity;

      final success = await _wallet.deductCoins(
        senderId,
        totalCost,
        quantity > 1
            ? 'إرسال ${gift.name} x$quantity'
            : 'إرسال هدية ${gift.name}',
      );
      if (!success) return false;

      if (receiverId != null) {
        await _wallet.addDiamonds(
          receiverId,
          totalDiamonds,
          quantity > 1
              ? 'استقبال ${gift.name} x$quantity'
              : 'استقبال هدية ${gift.name}',
        );
      }

      try {
        await _db.collection('rooms').doc(roomId).collection('gifts').add(
          GiftSentRecord(
            id: '',
            roomId: roomId,
            senderId: senderId,
            senderName: senderName,
            senderAvatar: senderAvatar,
            receiverId: receiverId,
            receiverName: receiverName,
            giftId: gift.id,
            giftName: gift.name,
            giftEmoji: gift.emoji,
            coinPrice: gift.coinPrice,
            diamondValue: gift.diamondValue,
            quantity: quantity,
            isSpecial: gift.isSpecial,
            sentAt: DateTime.now(),
          ).toFirestore(),
        );
      } catch (e) {
        debugPrint('[Gift] gift record write failed (non-critical): $e');
      }

      return true;
    } catch (e) {
      debugPrint('[Gift] sendGift error: $e');
      return false;
    }
  }

  Stream<List<GiftSentRecord>> watchRoomGifts(String roomId) {
    return _db
        .collection('rooms')
        .doc(roomId)
        .collection('gifts')
        .orderBy('sentAt', descending: true)
        .limit(10)
        .snapshots()
        .map((snap) => snap.docs.map(GiftSentRecord.fromFirestore).toList());
  }
}
