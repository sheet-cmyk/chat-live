import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/admin_repository.dart';

final isAdminProvider = FutureProvider<bool>((ref) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return false;
  return AdminRepository().isAdmin(user.uid);
});
