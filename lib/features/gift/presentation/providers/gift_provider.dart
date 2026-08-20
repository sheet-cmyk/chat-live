import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/gift_model.dart';
import '../../data/repositories/gift_repository.dart';

final giftRepositoryProvider = Provider<GiftRepository>((ref) => GiftRepository());

final giftsProvider = FutureProvider<List<GiftModel>>((ref) async {
  return ref.watch(giftRepositoryProvider).fetchGifts();
});

final selectedGiftProvider = StateProvider<GiftModel?>((ref) => null);

final selectedGiftCategoryProvider = StateProvider<GiftCategory>((ref) => GiftCategory.popular);

// حالة إرسال هدية: null=inactive / loading=true / success=false
final sendingGiftProvider = StateProvider<bool>((ref) => false);

// الهدية المعروضة حالياً في الأنيميشن
final activeGiftAnimProvider = StateProvider<GiftSentRecord?>((ref) => null);
