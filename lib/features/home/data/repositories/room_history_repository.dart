import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/room_model.dart';

class RoomHistoryRepository {
  static const _kKey = 'room_history';
  static const _kMax = 20;

  Future<void> addRoom(RoomModel room) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_kKey) ?? [];
    final list = raw.map((e) => jsonDecode(e) as Map<String, dynamic>).toList();

    // أزل إن وُجد مسبقاً (لتحديث الترتيب)
    list.removeWhere((m) => m['roomId'] == room.roomId);
    list.insert(0, _toMap(room));

    if (list.length > _kMax) list.removeRange(_kMax, list.length);

    await prefs.setStringList(_kKey, list.map(jsonEncode).toList());
  }

  Future<List<Map<String, dynamic>>> getHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_kKey) ?? [];
    return raw.map((e) => jsonDecode(e) as Map<String, dynamic>).toList();
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kKey);
  }

  Map<String, dynamic> _toMap(RoomModel r) => {
        'roomId': r.roomId,
        'name': r.name,
        'hostName': r.hostName,
        'hostAvatar': r.hostAvatar,
        'coverImage': r.coverImage,
        'type': r.type.name,
        'onlineCount': r.onlineCount,
        'visitedAt': DateTime.now().toIso8601String(),
      };
}
