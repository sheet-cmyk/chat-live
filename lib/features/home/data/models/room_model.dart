import 'package:cloud_firestore/cloud_firestore.dart';

enum RoomType { chat, music, game, dating }
enum RoomCategory { all, popular, newest, nearby, gaming, music }

class RoomModel {
  final String roomId;
  final String name;
  final String? coverImage;
  final RoomType type;
  final String hostUid;
  final String hostName;
  final String? hostAvatar;
  final int onlineCount;
  final int maxSeats;
  final bool isLocked;
  final String? country;
  final String? announcement;
  final List<String> tags;
  final DateTime createdAt;
  final bool isLive;
  final int totalGifts;

  const RoomModel({
    required this.roomId,
    required this.name,
    this.coverImage,
    required this.type,
    required this.hostUid,
    required this.hostName,
    this.hostAvatar,
    this.onlineCount = 0,
    this.maxSeats = 9,
    this.isLocked = false,
    this.country,
    this.announcement,
    this.tags = const [],
    required this.createdAt,
    this.isLive = true,
    this.totalGifts = 0,
  });

  factory RoomModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return RoomModel(
      roomId: doc.id,
      name: d['name'] ?? '',
      coverImage: d['coverImage'],
      type: RoomType.values.firstWhere(
        (e) => e.name == (d['type'] ?? 'chat'),
        orElse: () => RoomType.chat,
      ),
      hostUid: d['hostUid'] ?? '',
      hostName: d['hostName'] ?? '',
      hostAvatar: d['hostAvatar'],
      onlineCount: d['onlineCount'] ?? 0,
      maxSeats: d['maxSeats'] ?? 9,
      isLocked: d['isLocked'] ?? false,
      country: d['country'],
      announcement: d['announcement'],
      tags: List<String>.from(d['tags'] ?? []),
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isLive: d['isLive'] ?? true,
      totalGifts: d['totalGifts'] ?? 0,
    );
  }

  Map<String, dynamic> toFirestore() => {
        'name': name,
        'coverImage': coverImage,
        'type': type.name,
        'hostUid': hostUid,
        'hostName': hostName,
        'hostAvatar': hostAvatar,
        'onlineCount': onlineCount,
        'maxSeats': maxSeats,
        'isLocked': isLocked,
        'country': country,
        'announcement': announcement,
        'tags': tags,
        'createdAt': Timestamp.fromDate(createdAt),
        'isLive': isLive,
        'totalGifts': totalGifts,
      };

  String get typeLabel {
    switch (type) {
      case RoomType.chat: return 'دردشة';
      case RoomType.music: return 'موسيقى';
      case RoomType.game: return 'ألعاب';
      case RoomType.dating: return 'تعارف';
    }
  }
}
