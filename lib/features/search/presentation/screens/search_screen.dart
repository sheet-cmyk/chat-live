import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../home/data/models/room_model.dart';
import '../../../home/data/repositories/room_repository.dart';
import '../../../home/presentation/widgets/room_card.dart';

final _searchQueryProvider = StateProvider<String>((_) => '');
final _searchResultsProvider = FutureProvider.family<List<RoomModel>, String>(
  (ref, q) => ref.read(_roomRepoProvider).searchRooms(q),
);
final _roomRepoProvider = Provider<RoomRepository>((_) => RoomRepository());

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = ref.watch(_searchQueryProvider);
    final resultsAsync = query.length >= 2
        ? ref.watch(_searchResultsProvider(query))
        : null;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // شريط البحث
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: TextField(
                controller: _controller,
                autofocus: true,
                style: const TextStyle(color: AppColors.textPrimary, fontFamily: 'Cairo'),
                decoration: InputDecoration(
                  hintText: 'ابحث عن غرفة أو مستخدم...',
                  prefixIcon: const Icon(Icons.search_rounded, color: AppColors.primary),
                  suffixIcon: query.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close_rounded, color: AppColors.textHint),
                          onPressed: () {
                            _controller.clear();
                            ref.read(_searchQueryProvider.notifier).state = '';
                          },
                        )
                      : null,
                ),
                onChanged: (v) => ref.read(_searchQueryProvider.notifier).state = v.trim(),
              ),
            ),

            // النتائج
            Expanded(
              child: query.length < 2
                  ? const _SearchHint()
                  : resultsAsync!.when(
                      data: (rooms) => rooms.isEmpty
                          ? const _NoResults()
                          : GridView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                mainAxisSpacing: 12,
                                crossAxisSpacing: 12,
                                childAspectRatio: 0.82,
                              ),
                              itemCount: rooms.length,
                              itemBuilder: (_, i) => RoomCard(room: rooms[i]),
                            ),
                      loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
                      error: (e, _) => Center(child: Text('$e', style: const TextStyle(color: AppColors.error))),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchHint extends StatelessWidget {
  const _SearchHint();
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_rounded, size: 64, color: AppColors.textHint),
          SizedBox(height: 12),
          Text('ابحث عن غرف الحفلات', style: TextStyle(color: AppColors.textSecondary, fontFamily: 'Cairo', fontSize: 15)),
          SizedBox(height: 6),
          Text('اكتب اسم الغرفة للبحث', style: TextStyle(color: AppColors.textHint, fontFamily: 'Cairo', fontSize: 13)),
        ],
      ),
    );
  }
}

class _NoResults extends StatelessWidget {
  const _NoResults();
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off_rounded, size: 64, color: AppColors.textHint),
          SizedBox(height: 12),
          Text('لا توجد نتائج', style: TextStyle(color: AppColors.textSecondary, fontFamily: 'Cairo', fontSize: 15)),
        ],
      ),
    );
  }
}
