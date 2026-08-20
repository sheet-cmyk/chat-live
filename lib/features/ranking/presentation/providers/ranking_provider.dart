import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/ranking_model.dart';
import '../../data/repositories/ranking_repository.dart';

final rankingRepositoryProvider = Provider<RankingRepository>((ref) => RankingRepository());

final selectedRankingTypeProvider = StateProvider<RankingType>((ref) => RankingType.richest);

final rankingProvider = FutureProvider.family<List<RankingEntry>, RankingType>((ref, type) {
  return ref.watch(rankingRepositoryProvider).fetchRanking(type);
});
