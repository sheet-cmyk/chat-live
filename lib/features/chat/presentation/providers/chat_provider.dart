import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../data/repositories/chat_repository.dart';
import '../../data/models/message_model.dart';

final chatRepositoryProvider = Provider<ChatRepository>((ref) => ChatRepository());

final conversationsProvider = StreamProvider<List<ConversationModel>>((ref) {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return const Stream.empty();
  return ref.watch(chatRepositoryProvider).watchConversations(uid);
});

final messagesProvider = StreamProvider.family<List<MessageModel>, String>((ref, convId) {
  return ref.watch(chatRepositoryProvider).watchMessages(convId);
});

// المحادثة المفتوحة حالياً
final activeConversationProvider = StateProvider<ConversationModel?>((ref) => null);

// عدد الرسائل غير المقروءة (مجموع كل المحادثات)
final totalUnreadProvider = Provider<int>((ref) {
  final convs = ref.watch(conversationsProvider).valueOrNull ?? [];
  final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
  return convs.fold<int>(0, (sum, c) => sum + c.myUnread(uid));
});
