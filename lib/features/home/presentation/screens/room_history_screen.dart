import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/routes.dart';
import '../../data/models/room_model.dart';
import '../../data/repositories/room_history_repository.dart';

final _historyProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return RoomHistoryRepository().getHistory();
});

class RoomHistoryScreen extends ConsumerWidget {
  const RoomHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(_historyProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: const Text('الغرف المزارة', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await RoomHistoryRepository().clear();
              ref.invalidate(_historyProvider);
            },
            child: const Text('مسح الكل', style: TextStyle(color: AppColors.error, fontFamily: 'Cairo', fontSize: 12)),
          ),
        ],
      ),
      body: historyAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (_, __) => const Center(child: Text('خطأ', style: TextStyle(color: AppColors.textSecondary, fontFamily: 'Cairo'))),
        data: (history) {
          if (history.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 80, height: 80,
                    decoration: const BoxDecoration(color: AppColors.surfaceLight, shape: BoxShape.circle),
                    child: const Icon(Icons.history_rounded, color: AppColors.textHint, size: 40),
                  ),
                  const SizedBox(height: 16),
                  const Text('لم تزر أي غرفة بعد', style: TextStyle(color: AppColors.textSecondary, fontFamily: 'Cairo', fontSize: 15)),
                ],
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: history.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) => _HistoryCard(data: history[i]),
          );
        },
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.data});
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final visitedAt = DateTime.tryParse(data['visitedAt'] ?? '') ?? DateTime.now();
    final diff = DateTime.now().difference(visitedAt);
    final timeStr = diff.inHours < 1
        ? 'منذ ${diff.inMinutes} دقيقة'
        : diff.inDays < 1
            ? 'منذ ${diff.inHours} ساعة'
            : 'منذ ${diff.inDays} يوم';

    return GestureDetector(
      onTap: () {
        // بناء RoomModel مؤقت للانتقال
        final room = RoomModel(
          roomId: data['roomId'] ?? '',
          name: data['name'] ?? '',
          coverImage: data['coverImage'],
          type: RoomType.values.firstWhere((e) => e.name == (data['type'] ?? 'chat'), orElse: () => RoomType.chat),
          hostUid: '',
          hostName: data['hostName'] ?? '',
          hostAvatar: data['hostAvatar'],
          createdAt: DateTime.now(),
        );
        context.push(AppRoutes.room, extra: room);
      },
      child: Container(
        decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(14)),
        child: Row(
          children: [
            // صورة الغرفة
            ClipRRect(
              borderRadius: const BorderRadius.horizontal(right: Radius.circular(14)),
              child: data['coverImage'] != null
                  ? CachedNetworkImage(
                      imageUrl: data['coverImage'],
                      width: 80, height: 80, fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => _placeholder(),
                    )
                  : _placeholder(),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(data['name'] ?? '', style: const TextStyle(
                      color: AppColors.textPrimary, fontFamily: 'Cairo', fontSize: 14, fontWeight: FontWeight.w600,
                    ), maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Text(data['hostName'] ?? '', style: const TextStyle(
                      color: AppColors.textSecondary, fontFamily: 'Cairo', fontSize: 12,
                    )),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.history_rounded, size: 12, color: AppColors.textHint),
                        const SizedBox(width: 4),
                        Text(timeStr, style: const TextStyle(color: AppColors.textHint, fontSize: 11, fontFamily: 'Cairo')),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(color: AppColors.primary.withAlpha(30), borderRadius: BorderRadius.circular(8)),
                          child: Text(
                            '${data['onlineCount'] ?? 0} متصل',
                            style: const TextStyle(color: AppColors.primary, fontSize: 10, fontFamily: 'Cairo'),
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder() => Container(
        width: 80, height: 80,
        color: AppColors.surfaceLight,
        child: const Icon(Icons.mic_rounded, color: AppColors.primary, size: 32),
      );
}
