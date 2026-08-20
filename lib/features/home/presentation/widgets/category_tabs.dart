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
      (null, 'الكل', Icons.apps_rounded),
      (RoomType.chat, 'دردشة', Icons.chat_bubble_rounded),
      (RoomType.music, 'موسيقى', Icons.music_note_rounded),
      (RoomType.game, 'ألعاب', Icons.sports_esports_rounded),
      (RoomType.dating, 'تعارف', Icons.favorite_rounded),
    ];

    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: tabs.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final (type, label, icon) = tabs[i];
          final isActive = selected == type;
          return GestureDetector(
            onTap: () => ref.read(selectedCategoryProvider.notifier).state = type,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                gradient: isActive ? AppColors.primaryGradient : null,
                color: isActive ? null : AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isActive ? Colors.transparent : AppColors.divider,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 14, color: isActive ? Colors.white : AppColors.textSecondary),
                  const SizedBox(width: 5),
                  Text(
                    label,
                    style: TextStyle(
                      color: isActive ? Colors.white : AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: isActive ? FontWeight.w700 : FontWeight.normal,
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
