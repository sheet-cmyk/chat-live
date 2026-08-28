import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/banner_model.dart';

class BannerRepository {
  BannerRepository._();
  static final BannerRepository _i = BannerRepository._();
  factory BannerRepository() => _i;

  final _db = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;

  // Active banners ordered by admin-defined order (used by all users)
  Stream<List<BannerModel>> watchActiveBanners() =>
      _db
          .collection('banners')
          .where('isActive', isEqualTo: true)
          .orderBy('order')
          .snapshots()
          .map((s) => s.docs.map(BannerModel.fromFirestore).toList());

  // All banners for admin management
  Stream<List<BannerModel>> watchAllBanners() =>
      _db
          .collection('banners')
          .orderBy('order')
          .snapshots()
          .map((s) => s.docs.map(BannerModel.fromFirestore).toList());

  Future<void> createBanner(BannerModel banner) async {
    await _db.collection('banners').add({
      ...banner.toFirestore(),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateBanner(BannerModel banner) =>
      _db.collection('banners').doc(banner.id).update(banner.toFirestore());

  Future<void> deleteBanner(String id, {String? imageUrl}) async {
    await _db.collection('banners').doc(id).delete();
    if (imageUrl != null && imageUrl.isNotEmpty) {
      try {
        await _storage.refFromURL(imageUrl).delete();
      } catch (_) {}
    }
  }

  Future<void> toggleActive(String id, bool value) =>
      _db.collection('banners').doc(id).update({
        'isActive': value,
        'updatedAt': FieldValue.serverTimestamp(),
      });

  Future<String> uploadBannerImage(File file) async {
    final ext = file.path.split('.').last.toLowerCase();
    final name = '${DateTime.now().millisecondsSinceEpoch}.$ext';
    final ref = _storage.ref('banners/$name');
    final snap = await ref.putFile(file);
    return snap.ref.getDownloadURL();
  }

  // Batch-update 'order' field so the list stays sorted after drag-to-reorder
  Future<void> reorderBanners(List<String> orderedIds) async {
    final batch = _db.batch();
    for (var i = 0; i < orderedIds.length; i++) {
      batch.update(_db.collection('banners').doc(orderedIds[i]), {
        'order': i,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }

  // Extract YouTube video ID from any YouTube URL format
  static String? extractVideoId(String url) {
    final re = RegExp(
      r'(?:youtube\.com/(?:watch\?(?:.*&)?v=|embed/|shorts/)|youtu\.be/)([a-zA-Z0-9_-]{11})',
    );
    return re.firstMatch(url)?.group(1);
  }
}
