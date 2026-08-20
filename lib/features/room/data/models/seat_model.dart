class SeatModel {
  final int index;
  final String? userId;
  final String? userName;
  final String? userAvatar;
  final bool isMuted;
  final bool isLocked;
  final bool isSpeaking;
  final int userLevel;
  final int userVip;

  const SeatModel({
    required this.index,
    this.userId,
    this.userName,
    this.userAvatar,
    this.isMuted = false,
    this.isLocked = false,
    this.isSpeaking = false,
    this.userLevel = 1,
    this.userVip = 0,
  });

  bool get isEmpty => userId == null;

  SeatModel copyWith({
    String? userId,
    String? userName,
    String? userAvatar,
    bool? isMuted,
    bool? isLocked,
    bool? isSpeaking,
    int? userLevel,
    int? userVip,
  }) {
    return SeatModel(
      index: index,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      userAvatar: userAvatar ?? this.userAvatar,
      isMuted: isMuted ?? this.isMuted,
      isLocked: isLocked ?? this.isLocked,
      isSpeaking: isSpeaking ?? this.isSpeaking,
      userLevel: userLevel ?? this.userLevel,
      userVip: userVip ?? this.userVip,
    );
  }

  SeatModel cleared() => SeatModel(index: index, isLocked: isLocked);
}
