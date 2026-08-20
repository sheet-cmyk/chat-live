import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/room_model.dart';

class RoomRepository {
  final _col = FirebaseFirestore.instance.collection('rooms');

  // ── الغرف المباشرة (real-time) ───────────────────────────────
  Stream<List<RoomModel>> watchRooms({RoomType? type, int limit = 20}) {
    Query query = _col
        .where('isLive', isEqualTo: true)
        .orderBy('onlineCount', descending: true)
        .limit(limit);
    if (type != null) {
      query = query.where('type', isEqualTo: type.name);
    }
    return query.snapshots().map(
          (snap) => snap.docs.map(RoomModel.fromFirestore).toList(),
        );
  }

  // ── الأحدث ───────────────────────────────────────────────────
  Stream<List<RoomModel>> watchNewestRooms({int limit = 20}) {
    return _col
        .where('isLive', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((s) => s.docs.map(RoomModel.fromFirestore).toList());
  }

  // ── بحث بالاسم ───────────────────────────────────────────────
  Future<List<RoomModel>> searchRooms(String query) async {
    if (query.isEmpty) return [];
    final snap = await _col
        .where('isLive', isEqualTo: true)
        .where('name', isGreaterThanOrEqualTo: query)
        .where('name', isLessThan: '${query}z')
        .limit(15)
        .get();
    return snap.docs.map(RoomModel.fromFirestore).toList();
  }

  // ── إنشاء غرفة ───────────────────────────────────────────────
  Future<String> createRoom(RoomModel room) async {
    final ref = await _col.add(room.toFirestore());
    return ref.id;
  }

  // ── حذف/إنهاء غرفة ───────────────────────────────────────────
  Future<void> endRoom(String roomId) async {
    await _col.doc(roomId).update({'isLive': false});
  }

  // ── تحديث عدد المتصلين ────────────────────────────────────────
  Future<void> updateOnlineCount(String roomId, int count) async {
    await _col.doc(roomId).update({'onlineCount': count});
  }

  // ── جلب غرفة واحدة ───────────────────────────────────────────
  Future<RoomModel?> fetchRoom(String roomId) async {
    final doc = await _col.doc(roomId).get();
    if (!doc.exists) return null;
    return RoomModel.fromFirestore(doc);
  }

  // ── جلب الغرفة النشطة للمستخدم ───────────────────────────────
  Future<RoomModel?> fetchMyActiveRoom(String userId) async {
    final snap = await _col
        .where('hostUid', isEqualTo: userId)
        .where('isLive', isEqualTo: true)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    return RoomModel.fromFirestore(snap.docs.first);
  }

  // ── تعديل بيانات الغرفة ──────────────────────────────────────
  Future<void> updateRoom(
    String roomId, {
    String? name,
    bool? isLocked,
    RoomType? type,
  }) async {
    final data = <String, dynamic>{};
    if (name != null) data['name'] = name;
    if (isLocked != null) data['isLocked'] = isLocked;
    if (type != null) data['type'] = type.name;
    if (data.isEmpty) return;
    await _col.doc(roomId).update(data);
  }
}
