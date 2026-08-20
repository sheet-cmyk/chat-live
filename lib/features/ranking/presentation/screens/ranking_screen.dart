import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shimmer/shimmer.dart';
import '../../../../app/theme/app_colors.dart';
import '../../data/models/ranking_model.dart';
import '../providers/ranking_provider.dart';

class RankingScreen extends ConsumerWidget {
  const RankingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final type = ref.watch(selectedRankingTypeProvider);
    final ranking = ref.watch(rankingProvider(type));

    return Scaffold(
      backgroundColor: AppColors.background,
      body: NestedScrollView(
        headerSliverBuilder: (_, __) => [
          SliverAppBar(
            backgroundColor: AppColors.surface,
            automaticallyImplyLeading: false,
            pinned: true,
            title: const Text('لوحة المتصدرين', style: TextStyle(
              color: AppColors.textPrimary, fontFamily: 'Cairo', fontWeight: FontWeight.w700, fontSize: 18,
            )),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(48),
              child: _RankingTabs(),
            ),
          ),
        ],
        body: ranking.when(
          loading: () => _LoadingList(),
          error: (_, __) => const Center(child: Text('خطأ في التحميل', style: TextStyle(color: AppColors.textSecondary, fontFamily: 'Cairo'))),
          data: (list) {
            if (list.isEmpty) {
              return const Center(child: Text('لا توجد بيانات بعد 🏆', style: TextStyle(color: AppColors.textHint, fontFamily: 'Cairo')));
            }
            return CustomScrollView(
              slivers: [
                // المراكز الثلاثة الأولى
                if (list.length >= 3)
                  SliverToBoxAdapter(child: _TopThree(entries: list.take(3).toList())),
                // باقي القائمة
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (_, i) {
                      final entry = list[i + (list.length >= 3 ? 3 : 0)];
                      return _RankTile(entry: entry);
                    },
                    childCount: list.length - (list.length >= 3 ? 3 : 0),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 20)),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _RankingTabs extends ConsumerWidget {
  static const _tabs = [
    (RankingType.richest, '💰 الأثرياء'),
    (RankingType.gifter, '🎁 المهدين'),
    (RankingType.hostStar, '⭐ النجوم'),
    (RankingType.rising, '🚀 الصاعدون'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedRankingTypeProvider);
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        children: _tabs.map<Widget>((tab) {
          final type = tab.$1;
          final label = tab.$2;
          final isActive = selected == type;
          return GestureDetector(
            onTap: () => ref.read(selectedRankingTypeProvider.notifier).state = type,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: isActive ? AppColors.primary : AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(20),
              ),
              alignment: Alignment.center,
              child: Text(label, style: TextStyle(
                color: isActive ? Colors.white : AppColors.textSecondary,
                fontSize: 12,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.normal,
                fontFamily: 'Cairo',
              )),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// المراكز 1-2-3
class _TopThree extends StatelessWidget {
  const _TopThree({required this.entries});
  final List<RankingEntry> entries;

  @override
  Widget build(BuildContext context) {
    final first = entries[0];
    final second = entries[1];
    final third = entries[2];

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary.withAlpha(60), AppColors.accent.withAlpha(40)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _PodiumItem(entry: second, height: 80),
          _PodiumItem(entry: first, height: 110, isFirst: true),
          _PodiumItem(entry: third, height: 60),
        ],
      ),
    );
  }
}

class _PodiumItem extends StatelessWidget {
  const _PodiumItem({required this.entry, required this.height, this.isFirst = false});
  final RankingEntry entry;
  final double height;
  final bool isFirst;

  static const _medals = ['🥇', '🥈', '🥉'];

  @override
  Widget build(BuildContext context) {
    final size = isFirst ? 56.0 : 44.0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isFirst) const Text('👑', style: TextStyle(fontSize: 22)),
        CircleAvatar(
          radius: size / 2,
          backgroundColor: AppColors.primary,
          backgroundImage: entry.userAvatar != null ? NetworkImage(entry.userAvatar!) : null,
          child: entry.userAvatar == null
              ? Text(entry.userName.isNotEmpty ? entry.userName[0] : '?',
                  style: TextStyle(color: Colors.white, fontSize: isFirst ? 22 : 16, fontWeight: FontWeight.bold))
              : null,
        ),
        const SizedBox(height: 6),
        Text(_medals[entry.rank - 1], style: const TextStyle(fontSize: 18)),
        Text(
          entry.userName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: AppColors.textPrimary, fontFamily: 'Cairo', fontSize: 11, fontWeight: FontWeight.w600),
        ),
        Text(entry.scoreLabel, style: const TextStyle(color: AppColors.textHint, fontFamily: 'Cairo', fontSize: 10)),
      ],
    );
  }
}

// صف قائمة الترتيب
class _RankTile extends StatelessWidget {
  const _RankTile({required this.entry});
  final RankingEntry entry;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          // رقم الترتيب
          SizedBox(
            width: 32,
            child: Text(
              '#${entry.rank}',
              style: const TextStyle(
                color: AppColors.textHint, fontWeight: FontWeight.w700, fontSize: 13,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 10),
          CircleAvatar(
            radius: 20,
            backgroundColor: AppColors.primary,
            backgroundImage: entry.userAvatar != null ? NetworkImage(entry.userAvatar!) : null,
            child: entry.userAvatar == null
                ? Text(entry.userName.isNotEmpty ? entry.userName[0] : '?',
                    style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold))
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.userName, style: const TextStyle(
                  color: AppColors.textPrimary, fontFamily: 'Cairo', fontWeight: FontWeight.w600, fontSize: 13,
                )),
                Row(
                  children: [
                    _Badge('Lv.${entry.level}', AppColors.primary),
                    if (entry.vipLevel > 0) ...[
                      const SizedBox(width: 4),
                      _Badge('VIP${entry.vipLevel}', AppColors.gold),
                    ],
                  ],
                ),
              ],
            ),
          ),
          Text(entry.scoreLabel, style: const TextStyle(
            color: AppColors.gold, fontWeight: FontWeight.w700, fontFamily: 'Cairo', fontSize: 13,
          )),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge(this.label, this.color);
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: color.withAlpha(40),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w700)),
    );
  }
}

class _LoadingList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.surfaceLight,
      highlightColor: AppColors.card,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: 10,
        itemBuilder: (_, i) => Container(
          height: 60, margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}
