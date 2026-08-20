class VipLevel {
  final int level;
  final String name;
  final String badge;
  final int priceUsd;
  final int durationDays;
  final List<String> perks;

  const VipLevel({
    required this.level,
    required this.name,
    required this.badge,
    required this.priceUsd,
    required this.durationDays,
    required this.perks,
  });

  static const levels = [
    VipLevel(
      level: 1, name: 'برونزي', badge: '🥉',
      priceUsd: 5, durationDays: 30,
      perks: ['شارة VIP1', 'إدخال مميز للغرف', 'تأثيرات الدردشة'],
    ),
    VipLevel(
      level: 2, name: 'فضي', badge: '🥈',
      priceUsd: 15, durationDays: 30,
      perks: ['شارة VIP2', 'أولوية المقاعد', 'إطار صورة خاص', 'هدايا مجانية يومياً'],
    ),
    VipLevel(
      level: 3, name: 'ذهبي', badge: '🥇',
      priceUsd: 30, durationDays: 30,
      perks: ['شارة VIP3', 'إدخال فوري للغرف', 'تأثيرات صوتية', '2× EXP', '500 عملة يومياً'],
    ),
    VipLevel(
      level: 4, name: 'ألماسي', badge: '💎',
      priceUsd: 60, durationDays: 30,
      perks: ['شارة VIP4', 'جميع مزايا VIP3', 'تاج خاص', 'اسم ملوّن', '1000 عملة يومياً'],
    ),
    VipLevel(
      level: 5, name: 'أسطوري', badge: '👑',
      priceUsd: 100, durationDays: 30,
      perks: ['شارة VIP5', 'جميع المزايا', 'دخول حصري', 'هوية فريدة', '2500 عملة يومياً'],
    ),
  ];
}
