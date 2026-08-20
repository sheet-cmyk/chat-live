import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

const String _seedAdminEmail = 'hussein1sheet@gmail.com';

class AdminRepository {
  static final AdminRepository _i = AdminRepository._();
  factory AdminRepository() => _i;
  AdminRepository._();

  final _db = FirebaseFirestore.instance;

  // Bootstrap: auto-grant admin to seed email on first login.
  Future<void> bootstrapIfNeeded(User user) async {
    if (user.email != _seedAdminEmail) return;
    final doc = await _db.collection('admins').doc(user.uid).get();
    if (!doc.exists) {
      await _db.collection('admins').doc(user.uid).set({
        'email': user.email,
        'grantedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<bool> isAdmin(String uid) async {
    final doc = await _db.collection('admins').doc(uid).get();
    return doc.exists;
  }

  // ── Users ──────────────────────────────────────────────────────
  Stream<List<Map<String, dynamic>>> watchUsers({String search = ''}) {
    Query q = _db.collection('users').orderBy('createdAt', descending: true).limit(80);
    return q.snapshots().map((snap) {
      final list = snap.docs.map((d) {
        final data = d.data() as Map<String, dynamic>;
        return {'uid': d.id, ...data};
      }).toList();
      if (search.isEmpty) return list;
      final lower = search.toLowerCase();
      return list.where((u) {
        final name = ((u['displayName'] ?? '') as String).toLowerCase();
        final phone = ((u['phone'] ?? '') as String).toLowerCase();
        return name.contains(lower) || phone.contains(lower);
      }).toList();
    });
  }

  Future<void> giveCoins(String userId, int amount) async {
    final batch = _db.batch();
    batch.update(_db.collection('users').doc(userId), {
      'coins': FieldValue.increment(amount),
    });
    batch.set(_db.collection('transactions').doc(), {
      'userId': userId,
      'type': 'reward',
      'coinsChange': amount,
      'diamondsChange': 0,
      'description': 'هدية من الإدارة 🎁 $amount عملة',
      'createdAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
  }

  Future<void> giveDiamonds(String userId, int amount) async {
    final batch = _db.batch();
    batch.update(_db.collection('users').doc(userId), {
      'diamonds': FieldValue.increment(amount),
    });
    batch.set(_db.collection('transactions').doc(), {
      'userId': userId,
      'type': 'reward',
      'coinsChange': 0,
      'diamondsChange': amount,
      'description': 'هدية ماس من الإدارة 💎 $amount ماسة',
      'createdAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
  }

  Future<void> setCoins(String userId, int amount) async {
    final snap = await _db.collection('users').doc(userId).get();
    final current = (snap.data()?['coins'] as num?)?.toInt() ?? 0;
    final diff = amount - current;
    final batch = _db.batch();
    batch.update(_db.collection('users').doc(userId), {'coins': amount});
    batch.set(_db.collection('transactions').doc(), {
      'userId': userId,
      'type': 'reward',
      'coinsChange': diff,
      'diamondsChange': 0,
      'description': 'تعديل رصيد من الإدارة → $amount عملة',
      'createdAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
  }

  Future<void> setDiamonds(String userId, int amount) async {
    await _db.collection('users').doc(userId).update({'diamonds': amount});
  }

  Future<void> banUser(String userId, String reason) async {
    final batch = _db.batch();
    batch.set(_db.collection('banned_users').doc(userId), {
      'userId': userId,
      'reason': reason,
      'bannedAt': FieldValue.serverTimestamp(),
    });
    batch.update(_db.collection('users').doc(userId), {'isBanned': true});
    await batch.commit();
  }

  Future<void> unbanUser(String userId) async {
    final batch = _db.batch();
    batch.delete(_db.collection('banned_users').doc(userId));
    batch.update(_db.collection('users').doc(userId), {'isBanned': false});
    await batch.commit();
  }

  Future<bool> isBanned(String userId) async {
    final doc = await _db.collection('banned_users').doc(userId).get();
    return doc.exists;
  }

  // ── Rooms ──────────────────────────────────────────────────────
  Stream<List<Map<String, dynamic>>> watchRooms() {
    return _db.collection('rooms').orderBy('createdAt', descending: true).limit(100).snapshots().map(
      (snap) => snap.docs.map((d) {
        final data = d.data();
        return {'roomId': d.id, ...data};
      }).toList(),
    );
  }

  Future<void> deleteRoom(String roomId) async {
    await _db.collection('rooms').doc(roomId).delete();
  }

  Future<void> clearAllSeats(String roomId) async {
    final batch = _db.batch();
    for (int i = 0; i < 9; i++) {
      batch.set(_db.collection('rooms').doc(roomId).collection('seats').doc('$i'), {
        'userId': null, 'userName': null, 'userAvatar': null,
        'isMuted': false, 'isLocked': false, 'userLevel': 1, 'userVip': 0,
      });
    }
    await batch.commit();
  }
}
