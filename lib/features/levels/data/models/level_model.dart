class LevelModel {
  final int level;
  final int expRequired;
  final String title;
  final String badge;
  final int coinsReward;

  const LevelModel({
    required this.level,
    required this.expRequired,
    required this.title,
    required this.badge,
    required this.coinsReward,
  });

  static const levels = [
    LevelModel(level: 1,  expRequired: 0,     title: 'مبتدئ',     badge: '🌱', coinsReward: 0),
    LevelModel(level: 2,  expRequired: 100,   title: 'متحمس',     badge: '⚡', coinsReward: 50),
    LevelModel(level: 3,  expRequired: 300,   title: 'نشيط',      badge: '🔥', coinsReward: 100),
    LevelModel(level: 4,  expRequired: 600,   title: 'محترف',     badge: '💫', coinsReward: 150),
    LevelModel(level: 5,  expRequired: 1000,  title: 'خبير',      badge: '🌟', coinsReward: 200),
    LevelModel(level: 6,  expRequired: 1500,  title: 'متميز',     badge: '🏆', coinsReward: 300),
    LevelModel(level: 7,  expRequired: 2200,  title: 'نجم',       badge: '⭐', coinsReward: 400),
    LevelModel(level: 8,  expRequired: 3000,  title: 'بطل',       badge: '🦁', coinsReward: 500),
    LevelModel(level: 9,  expRequired: 4000,  title: 'أسطورة',    badge: '🐉', coinsReward: 750),
    LevelModel(level: 10, expRequired: 5500,  title: 'إمبراطور',  badge: '👑', coinsReward: 1000),
    LevelModel(level: 11, expRequired: 7000,  title: 'سيد',       badge: '💎', coinsReward: 1200),
    LevelModel(level: 12, expRequired: 9000,  title: 'خرافي',     badge: '🌌', coinsReward: 1500),
  ];

  static LevelModel forExp(int exp) {
    LevelModel result = levels.first;
    for (final l in levels) {
      if (exp >= l.expRequired) result = l;
    }
    return result;
  }

  static double progressToNext(int exp) {
    final current = forExp(exp);
    final idx = levels.indexOf(current);
    if (idx >= levels.length - 1) return 1.0;
    final next = levels[idx + 1];
    final range = next.expRequired - current.expRequired;
    final done = exp - current.expRequired;
    return (done / range).clamp(0.0, 1.0);
  }
}
