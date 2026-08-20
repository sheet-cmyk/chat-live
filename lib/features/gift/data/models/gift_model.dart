import 'package:cloud_firestore/cloud_firestore.dart';

enum GiftCategory { popular, special, luxury, love }

class GiftModel {
  final String id;
  final String name;
  final String emoji;
  final int coinPrice;
  final int diamondValue;
  final GiftCategory category;
  final String? animationUrl;
  final bool isSpecial;

  const GiftModel({
    required this.id,
    required this.name,
    required this.emoji,
    required this.coinPrice,
    required this.diamondValue,
    required this.category,
    this.animationUrl,
    this.isSpecial = false,
  });

  factory GiftModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return GiftModel(
      id: doc.id,
      name: d['name'] ?? '',
      emoji: d['emoji'] ?? '🎁',
      coinPrice: (d['coinPrice'] as num?)?.toInt() ?? 0,
      diamondValue: (d['diamondValue'] as num?)?.toInt() ?? 0,
      category: GiftCategory.values.firstWhere(
        (c) => c.name == (d['category'] ?? 'popular'),
        orElse: () => GiftCategory.popular,
      ),
      animationUrl: d['animationUrl'],
      isSpecial: d['isSpecial'] ?? false,
    );
  }

  Map<String, dynamic> toFirestore() => {
    'name': name,
    'emoji': emoji,
    'coinPrice': coinPrice,
    'diamondValue': diamondValue,
    'category': category.name,
    'animationUrl': animationUrl,
    'isSpecial': isSpecial,
  };

  static List<GiftModel> defaultGifts() => [
    const GiftModel(id: 'rose', name: 'وردة', emoji: '🌹', coinPrice: 10, diamondValue: 1, category: GiftCategory.popular),
    const GiftModel(id: 'heart', name: 'قلب', emoji: '❤️', coinPrice: 20, diamondValue: 2, category: GiftCategory.popular),
    const GiftModel(id: 'star', name: 'نجمة', emoji: '⭐', coinPrice: 50, diamondValue: 5, category: GiftCategory.popular),
    const GiftModel(id: 'cake', name: 'كعكة', emoji: '🎂', coinPrice: 100, diamondValue: 10, category: GiftCategory.special),
    const GiftModel(id: 'crown', name: 'تاج', emoji: '👑', coinPrice: 200, diamondValue: 20, category: GiftCategory.special),
    const GiftModel(id: 'diamond', name: 'ماسة', emoji: '💎', coinPrice: 500, diamondValue: 50, category: GiftCategory.luxury),
    const GiftModel(id: 'rocket', name: 'صاروخ', emoji: '🚀', coinPrice: 1000, diamondValue: 100, category: GiftCategory.luxury, isSpecial: true),
    const GiftModel(id: 'ring', name: 'خاتم', emoji: '💍', coinPrice: 2000, diamondValue: 200, category: GiftCategory.love, isSpecial: true),
    const GiftModel(id: 'bouquet', name: 'باقة', emoji: '💐', coinPrice: 30, diamondValue: 3, category: GiftCategory.love),
    const GiftModel(id: 'teddy', name: 'دبدوب', emoji: '🧸', coinPrice: 80, diamondValue: 8, category: GiftCategory.love),
    const GiftModel(id: 'fire', name: 'نار', emoji: '🔥', coinPrice: 150, diamondValue: 15, category: GiftCategory.special),
    const GiftModel(id: 'unicorn', name: 'يونيكورن', emoji: '🦄', coinPrice: 999, diamondValue: 99, category: GiftCategory.luxury, isSpecial: true),
  ];
}

class GiftSentRecord {
  final String id;
  final String roomId;
  final String senderId;
  final String senderName;
  final String? senderAvatar;
  final String? receiverId;
  final String? receiverName;
  final String giftId;
  final String giftName;
  final String giftEmoji;
  final int coinPrice;
  final int diamondValue;
  final DateTime sentAt;

  const GiftSentRecord({
    required this.id,
    required this.roomId,
    required this.senderId,
    required this.senderName,
    this.senderAvatar,
    this.receiverId,
    this.receiverName,
    required this.giftId,
    required this.giftName,
    required this.giftEmoji,
    required this.coinPrice,
    required this.diamondValue,
    required this.sentAt,
  });

  factory GiftSentRecord.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return GiftSentRecord(
      id: doc.id,
      roomId: d['roomId'] ?? '',
      senderId: d['senderId'] ?? '',
      senderName: d['senderName'] ?? '',
      senderAvatar: d['senderAvatar'],
      receiverId: d['receiverId'],
      receiverName: d['receiverName'],
      giftId: d['giftId'] ?? '',
      giftName: d['giftName'] ?? '',
      giftEmoji: d['giftEmoji'] ?? '🎁',
      coinPrice: (d['coinPrice'] as num?)?.toInt() ?? 0,
      diamondValue: (d['diamondValue'] as num?)?.toInt() ?? 0,
      sentAt: (d['sentAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
    'roomId': roomId,
    'senderId': senderId,
    'senderName': senderName,
    'senderAvatar': senderAvatar,
    'receiverId': receiverId,
    'receiverName': receiverName,
    'giftId': giftId,
    'giftName': giftName,
    'giftEmoji': giftEmoji,
    'coinPrice': coinPrice,
    'diamondValue': diamondValue,
    'sentAt': FieldValue.serverTimestamp(),
  };
}
