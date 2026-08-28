import 'package:cloud_firestore/cloud_firestore.dart';

class BannerModel {
  const BannerModel({
    required this.id,
    required this.type,
    this.imageUrl,
    this.youtubeUrl,
    this.youtubeVideoId,
    required this.durationSeconds,
    required this.order,
    required this.isActive,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String type; // 'image' | 'youtube'
  final String? imageUrl;
  final String? youtubeUrl;
  final String? youtubeVideoId;
  final int durationSeconds;
  final int order;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory BannerModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return BannerModel(
      id: doc.id,
      type: data['type'] as String? ?? 'image',
      imageUrl: data['imageUrl'] as String?,
      youtubeUrl: data['youtubeUrl'] as String?,
      youtubeVideoId: data['youtubeVideoId'] as String?,
      durationSeconds: (data['durationSeconds'] as num?)?.toInt() ?? 10,
      order: (data['order'] as num?)?.toInt() ?? 0,
      isActive: data['isActive'] as bool? ?? true,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'type': type,
        'imageUrl': imageUrl,
        'youtubeUrl': youtubeUrl,
        'youtubeVideoId': youtubeVideoId,
        'durationSeconds': durationSeconds,
        'order': order,
        'isActive': isActive,
        'updatedAt': FieldValue.serverTimestamp(),
      };

  BannerModel copyWith({
    String? id,
    String? type,
    String? imageUrl,
    String? youtubeUrl,
    String? youtubeVideoId,
    int? durationSeconds,
    int? order,
    bool? isActive,
  }) =>
      BannerModel(
        id: id ?? this.id,
        type: type ?? this.type,
        imageUrl: imageUrl ?? this.imageUrl,
        youtubeUrl: youtubeUrl ?? this.youtubeUrl,
        youtubeVideoId: youtubeVideoId ?? this.youtubeVideoId,
        durationSeconds: durationSeconds ?? this.durationSeconds,
        order: order ?? this.order,
        isActive: isActive ?? this.isActive,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );
}
