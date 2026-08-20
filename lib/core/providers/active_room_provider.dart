import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/home/data/models/room_model.dart';

class MinimizedRoomState {
  final RoomModel room;
  final int mySeat;
  final String userId;
  final String userName;
  const MinimizedRoomState({
    required this.room,
    required this.mySeat,
    required this.userId,
    required this.userName,
  });
}

final minimizedRoomProvider = StateProvider<MinimizedRoomState?>((ref) => null);
