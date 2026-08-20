import 'package:cloud_firestore/cloud_firestore.dart';

enum FriendStatus { pending, accepted, blocked }

class FriendModel {
  final String id;
  final String requesterId;
  final String requesterName;
  final String? requesterAvatar;
  final String receiverId;
  final String receiverName;
  final String? receiverAvatar;
  final FriendStatus status;
  final DateTime createdAt;

  const FriendModel({
    required this.id,
    required this.requesterId,
    required this.requesterName,
    this.requesterAvatar,
    required this.receiverId,
    required this.receiverName,
    this.receiverAvatar,
    required this.status,
    required this.createdAt,
  });

  factory FriendModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return FriendModel(
      id: doc.id,
      requesterId: d['requesterId'] ?? '',
      requesterName: d['requesterName'] ?? '',
      requesterAvatar: d['requesterAvatar'],
      receiverId: d['receiverId'] ?? '',
      receiverName: d['receiverName'] ?? '',
      receiverAvatar: d['receiverAvatar'],
      status: FriendStatus.values.firstWhere(
        (s) => s.name == (d['status'] ?? 'pending'),
        orElse: () => FriendStatus.pending,
      ),
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
    'requesterId': requesterId,
    'requesterName': requesterName,
    'requesterAvatar': requesterAvatar,
    'receiverId': receiverId,
    'receiverName': receiverName,
    'receiverAvatar': receiverAvatar,
    'status': status.name,
    'createdAt': FieldValue.serverTimestamp(),
    'participants': [requesterId, receiverId],
  };

  String otherUserId(String myId) => requesterId == myId ? receiverId : requesterId;
  String otherUserName(String myId) => requesterId == myId ? receiverName : requesterName;
  String? otherUserAvatar(String myId) => requesterId == myId ? receiverAvatar : requesterAvatar;
}
