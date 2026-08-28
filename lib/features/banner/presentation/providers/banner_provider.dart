import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/banner_repository.dart';
import '../../data/models/banner_model.dart';

final bannerRepositoryProvider =
    Provider<BannerRepository>((_) => BannerRepository());

// Real-time stream of active banners shown to all users on the home screen
final activeBannersProvider = StreamProvider<List<BannerModel>>(
  (ref) => ref.watch(bannerRepositoryProvider).watchActiveBanners(),
);

// Real-time stream of ALL banners used only in the admin panel
final allBannersAdminProvider = StreamProvider<List<BannerModel>>(
  (ref) => ref.watch(bannerRepositoryProvider).watchAllBanners(),
);
