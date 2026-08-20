import 'package:cloud_firestore/cloud_firestore.dart';

enum TransactionType { topup, giftSent, giftReceived, reward }

class TransactionModel {
  final String id;
  final String userId;
  final TransactionType type;
  final int coinsChange;
  final int diamondsChange;
  final String description;
  final DateTime createdAt;

  const TransactionModel({
    required this.id,
    required this.userId,
    required this.type,
    required this.coinsChange,
    required this.diamondsChange,
    required this.description,
    required this.createdAt,
  });

  factory TransactionModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return TransactionModel(
      id: doc.id,
      userId: d['userId'] ?? '',
      type: TransactionType.values.firstWhere(
        (t) => t.name == (d['type'] ?? 'reward'),
        orElse: () => TransactionType.reward,
      ),
      coinsChange: (d['coinsChange'] as num?)?.toInt() ?? 0,
      diamondsChange: (d['diamondsChange'] as num?)?.toInt() ?? 0,
      description: d['description'] ?? '',
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
    'userId': userId,
    'type': type.name,
    'coinsChange': coinsChange,
    'diamondsChange': diamondsChange,
    'description': description,
    'createdAt': FieldValue.serverTimestamp(),
  };

  bool get isIncome => coinsChange > 0 || diamondsChange > 0;
}
