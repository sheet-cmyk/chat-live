import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/user_entity.dart';

class UserModel extends UserEntity {
  const UserModel({
    required super.uid,
    required super.displayName,
    super.avatar,
    super.gender,
    super.birthday,
    super.bio,
    super.coins,
    super.diamonds,
    super.level,
    super.exp,
    super.vipLevel,
    super.vipExpiry,
    super.country,
    required super.phoneNumber,
    super.isOnline,
    super.lastSeen,
    super.followersCount,
    super.followingCount,
    super.friendsCount,
    required super.createdAt,
  });

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserModel(
      uid: doc.id,
      displayName: data['displayName'] ?? '',
      avatar: data['avatar'],
      gender: data['gender'],
      birthday: (data['birthday'] as Timestamp?)?.toDate(),
      bio: data['bio'],
      coins: data['coins'] ?? 0,
      diamonds: data['diamonds'] ?? 0,
      level: data['level'] ?? 1,
      exp: data['exp'] ?? 0,
      vipLevel: data['vipLevel'] ?? 0,
      vipExpiry: (data['vipExpiry'] as Timestamp?)?.toDate(),
      country: data['country'],
      phoneNumber: data['phoneNumber'] ?? '',
      isOnline: data['isOnline'] ?? false,
      lastSeen: (data['lastSeen'] as Timestamp?)?.toDate(),
      followersCount: data['followersCount'] ?? 0,
      followingCount: data['followingCount'] ?? 0,
      friendsCount: data['friendsCount'] ?? 0,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'displayName': displayName,
      'avatar': avatar,
      'gender': gender,
      'birthday': birthday != null ? Timestamp.fromDate(birthday!) : null,
      'bio': bio,
      'coins': coins,
      'diamonds': diamonds,
      'level': level,
      'exp': exp,
      'vipLevel': vipLevel,
      'vipExpiry': vipExpiry != null ? Timestamp.fromDate(vipExpiry!) : null,
      'country': country,
      'phoneNumber': phoneNumber,
      'isOnline': isOnline,
      'lastSeen': lastSeen != null ? Timestamp.fromDate(lastSeen!) : null,
      'followersCount': followersCount,
      'followingCount': followingCount,
      'friendsCount': friendsCount,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  UserModel copyWith({
    String? displayName,
    String? avatar,
    String? gender,
    DateTime? birthday,
    String? bio,
    int? coins,
    int? diamonds,
    int? level,
    int? exp,
    int? vipLevel,
    DateTime? vipExpiry,
    String? country,
    bool? isOnline,
    DateTime? lastSeen,
    int? followersCount,
    int? followingCount,
    int? friendsCount,
  }) {
    return UserModel(
      uid: uid,
      displayName: displayName ?? this.displayName,
      avatar: avatar ?? this.avatar,
      gender: gender ?? this.gender,
      birthday: birthday ?? this.birthday,
      bio: bio ?? this.bio,
      coins: coins ?? this.coins,
      diamonds: diamonds ?? this.diamonds,
      level: level ?? this.level,
      exp: exp ?? this.exp,
      vipLevel: vipLevel ?? this.vipLevel,
      vipExpiry: vipExpiry ?? this.vipExpiry,
      country: country ?? this.country,
      phoneNumber: phoneNumber,
      isOnline: isOnline ?? this.isOnline,
      lastSeen: lastSeen ?? this.lastSeen,
      followersCount: followersCount ?? this.followersCount,
      followingCount: followingCount ?? this.followingCount,
      friendsCount: friendsCount ?? this.friendsCount,
      createdAt: createdAt,
    );
  }
}
