import 'package:cloud_firestore/cloud_firestore.dart';

enum GiftCategory { popular, special, luxury, love }

class GiftModel {
  final String id;
  final String name;
  final String emoji;
  final int coinPrice;      // ماسات يدفعها المرسل
  final int diamondValue;   // ماسات يستقبلها المستقبل
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

  // ── هدايا افتراضية بأسعار ماسات من 10 إلى 50,000 ──────────────────────
  static List<GiftModel> defaultGifts() => const [
    // ── الكل / شائع ─────────────────────── 10 - 99 ماسة ──
    GiftModel(id: 'rose',     name: 'وردة',       emoji: '🌹', coinPrice: 10,  diamondValue: 10,  category: GiftCategory.popular),
    GiftModel(id: 'kiss',     name: 'بوسة',       emoji: '💋', coinPrice: 15,  diamondValue: 15,  category: GiftCategory.popular),
    GiftModel(id: 'heart',    name: 'قلب',        emoji: '❤️', coinPrice: 20,  diamondValue: 20,  category: GiftCategory.popular),
    GiftModel(id: 'balloon',  name: 'بالون',      emoji: '🎈', coinPrice: 25,  diamondValue: 25,  category: GiftCategory.popular),
    GiftModel(id: 'star',     name: 'نجمة',       emoji: '⭐', coinPrice: 30,  diamondValue: 30,  category: GiftCategory.popular),
    GiftModel(id: 'bear',     name: 'دبدوب',      emoji: '🧸', coinPrice: 49,  diamondValue: 49,  category: GiftCategory.popular),
    GiftModel(id: 'fire',     name: 'نار',        emoji: '🔥', coinPrice: 69,  diamondValue: 69,  category: GiftCategory.popular),
    GiftModel(id: 'bouquet',  name: 'باقة',       emoji: '💐', coinPrice: 99,  diamondValue: 99,  category: GiftCategory.popular),

    // ── حب ──────────────────────────────── 30 - 1000 ماسة ──
    GiftModel(id: 'gold_heart', name: 'قلب ذهبي', emoji: '💛', coinPrice: 30,   diamondValue: 30,   category: GiftCategory.love),
    GiftModel(id: 'couple',     name: 'عشاق',     emoji: '👫', coinPrice: 100,  diamondValue: 100,  category: GiftCategory.love),
    GiftModel(id: 'wedding',    name: 'زفاف',     emoji: '💒', coinPrice: 500,  diamondValue: 500,  category: GiftCategory.love, isSpecial: true),
    GiftModel(id: 'infinity',   name: 'إلى الأبد',emoji: '♾️', coinPrice: 1000, diamondValue: 1000, category: GiftCategory.love, isSpecial: true),

    // ── مميز ────────────────────────────── 100 - 999 ماسة ──
    GiftModel(id: 'cake',    name: 'كعكة',      emoji: '🎂', coinPrice: 100, diamondValue: 100, category: GiftCategory.special),
    GiftModel(id: 'music',   name: 'موسيقى',    emoji: '🎵', coinPrice: 150, diamondValue: 150, category: GiftCategory.special),
    GiftModel(id: 'crown',   name: 'تاج',       emoji: '👑', coinPrice: 199, diamondValue: 199, category: GiftCategory.special),
    GiftModel(id: 'diamond', name: 'ماسة',      emoji: '💎', coinPrice: 299, diamondValue: 299, category: GiftCategory.special),
    GiftModel(id: 'unicorn', name: 'يونيكورن',  emoji: '🦄', coinPrice: 499, diamondValue: 499, category: GiftCategory.special, isSpecial: true),
    GiftModel(id: 'ring',    name: 'خاتم',      emoji: '💍', coinPrice: 699, diamondValue: 699, category: GiftCategory.special, isSpecial: true),

    // ── فاخر ────────────────────────────── 1,000 - 50,000 ماسة ──
    GiftModel(id: 'rocket',   name: 'صاروخ',  emoji: '🚀', coinPrice: 1000,  diamondValue: 1000,  category: GiftCategory.luxury, isSpecial: true),
    GiftModel(id: 'car',      name: 'سيارة',  emoji: '🏎️', coinPrice: 2000,  diamondValue: 2000,  category: GiftCategory.luxury, isSpecial: true),
    GiftModel(id: 'yacht',    name: 'يخت',    emoji: '⛵',  coinPrice: 5000,  diamondValue: 5000,  category: GiftCategory.luxury, isSpecial: true),
    GiftModel(id: 'castle',   name: 'قصر',    emoji: '🏰', coinPrice: 10000, diamondValue: 10000, category: GiftCategory.luxury, isSpecial: true),
    GiftModel(id: 'universe', name: 'الكون',  emoji: '🌌', coinPrice: 50000, diamondValue: 50000, category: GiftCategory.luxury, isSpecial: true),
  ];
}

// ── سجل الهدية المرسلة ────────────────────────────────────────────────────

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
  final int quantity;
  final bool isSpecial;
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
    this.quantity = 1,
    this.isSpecial = false,
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
      quantity: (d['quantity'] as num?)?.toInt() ?? 1,
      isSpecial: d['isSpecial'] ?? false,
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
    'quantity': quantity,
    'isSpecial': isSpecial,
    'sentAt': FieldValue.serverTimestamp(),
  };
}
