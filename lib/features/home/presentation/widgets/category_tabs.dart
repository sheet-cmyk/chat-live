import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/app_colors.dart';
import '../../data/models/room_model.dart';
import '../providers/home_provider.dart';

class CategoryTabs extends ConsumerWidget {
  const CategoryTabs({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedCategoryProvider);

    final tabs = [
      _TabData(null,           'الكل',    Icons.apps_rounded,           AppColors.blue,   const Color(0xFFE8F0FE)),
      _TabData(RoomType.chat,  'دردشة',   Icons.chat_bubble_rounded,    AppColors.red,    const Color(0xFFFFEBEA)),
      _TabData(RoomType.music, 'موسيقى',  Icons.music_note_rounded,     AppColors.yellow, const Color(0xFFFFF8E1)),
      _TabData(RoomType.game,  'ألعاب',   Icons.sports_esports_rounded, AppColors.green,  const Color(0xFFE8F5E9)),
      _TabData(RoomType.dating,'تعارف',   Icons.favorite_rounded,       AppColors.accent, const Color(0xFFFCE4EC)),
    ];

    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: tabs.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final tab = tabs[i];
          final isActive = selected == tab.type;
          return GestureDetector(
            onTap: () => ref.read(selectedCategoryProvider.notifier).state = tab.type,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isActive ? tab.color : tab.lightColor,
                borderRadius: BorderRadius.circular(24),
                boxShadow: isActive
                    ? [BoxShadow(color: tab.color.withAlpha(60), blurRadius: 8, offset: const Offset(0, 3))]
                    : [],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(tab.icon, size: 15,
                    color: isActive ? Colors.white : tab.color),
                  const SizedBox(width: 6),
                  Text(
                    tab.label,
                    style: TextStyle(
                      color: isActive ? Colors.white : tab.color,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Cairo',
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _TabData {
  const _TabData(this.type, this.label, this.icon, this.color, this.lightColor);
  final RoomType? type;
  final String label;
  final IconData icon;
  final Color color;
  final Color lightColor;
}
