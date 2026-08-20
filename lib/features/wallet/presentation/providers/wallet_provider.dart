import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../data/repositories/wallet_repository.dart';
import '../../data/models/transaction_model.dart';

final walletRepositoryProvider = Provider<WalletRepository>((ref) => WalletRepository());

final balanceStreamProvider = StreamProvider<Map<String, int>>((ref) {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return const Stream.empty();
  return ref.watch(walletRepositoryProvider).watchBalance(uid);
});

final coinsProvider = Provider<int>((ref) {
  return ref.watch(balanceStreamProvider).valueOrNull?['coins'] ?? 0;
});

final diamondsProvider = Provider<int>((ref) {
  return ref.watch(balanceStreamProvider).valueOrNull?['diamonds'] ?? 0;
});

final transactionsProvider = FutureProvider<List<TransactionModel>>((ref) async {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return [];
  return ref.watch(walletRepositoryProvider).fetchTransactions(uid);
});
