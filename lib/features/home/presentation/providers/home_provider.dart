import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/room_model.dart';
import '../../data/repositories/room_repository.dart';

final roomRepositoryProvider = Provider<RoomRepository>((_) => RoomRepository());

// تبويب الفئة المختارة
final selectedCategoryProvider = StateProvider<RoomType?>((ref) => null);

// الغرف حسب الفئة (real-time)
final roomsStreamProvider = StreamProvider.family<List<RoomModel>, RoomType?>(
  (ref, type) => ref.watch(roomRepositoryProvider).watchRooms(type: type),
);

// الغرف الأحدث
final newestRoomsProvider = StreamProvider<List<RoomModel>>(
  (ref) => ref.watch(roomRepositoryProvider).watchNewestRooms(),
);

// تبويب التنقل السفلي
final bottomNavIndexProvider = StateProvider<int>((_) => 0);
