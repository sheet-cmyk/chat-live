import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../data/models/friend_model.dart';
import '../../data/repositories/social_repository.dart';

export '../../data/models/friend_model.dart';

final socialRepositoryProvider = Provider<SocialRepository>((ref) => SocialRepository());

final friendsProvider = StreamProvider<List<FriendModel>>((ref) {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return const Stream.empty();
  return ref.watch(socialRepositoryProvider).watchFriends(uid);
});

final pendingRequestsProvider = StreamProvider<List<FriendModel>>((ref) {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return const Stream.empty();
  return ref.watch(socialRepositoryProvider).watchPendingRequests(uid);
});

final pendingCountProvider = Provider<int>((ref) {
  return ref.watch(pendingRequestsProvider).valueOrNull?.length ?? 0;
});
