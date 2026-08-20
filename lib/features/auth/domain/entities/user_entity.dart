class UserEntity {
  final String uid;
  final String displayName;
  final String? avatar;
  final String? gender;
  final DateTime? birthday;
  final String? bio;
  final int coins;
  final int diamonds;
  final int level;
  final int exp;
  final int vipLevel;
  final DateTime? vipExpiry;
  final String? country;
  final String phoneNumber;
  final bool isOnline;
  final DateTime? lastSeen;
  final int followersCount;
  final int followingCount;
  final int friendsCount;
  final DateTime createdAt;

  const UserEntity({
    required this.uid,
    required this.displayName,
    this.avatar,
    this.gender,
    this.birthday,
    this.bio,
    this.coins = 0,
    this.diamonds = 0,
    this.level = 1,
    this.exp = 0,
    this.vipLevel = 0,
    this.vipExpiry,
    this.country,
    required this.phoneNumber,
    this.isOnline = false,
    this.lastSeen,
    this.followersCount = 0,
    this.followingCount = 0,
    this.friendsCount = 0,
    required this.createdAt,
  });

  bool get isVip => vipLevel > 0 && (vipExpiry?.isAfter(DateTime.now()) ?? false);
}
