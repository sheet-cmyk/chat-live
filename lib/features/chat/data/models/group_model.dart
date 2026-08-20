import 'package:cloud_firestore/cloud_firestore.dart';

class GroupModel {
  final String id;
  final String name;
  final String? coverImage;
  final String adminId;
  final List<String> memberIds;
  final Map<String, String> memberNames;
  final String? lastMessage;
  final DateTime? lastMessageAt;
  final Map<String, int> unreadCounts;

  const GroupModel({
    required this.id,
    required this.name,
    this.coverImage,
    required this.adminId,
    required this.memberIds,
    this.memberNames = const {},
    this.lastMessage,
    this.lastMessageAt,
    this.unreadCounts = const {},
  });

  factory GroupModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return GroupModel(
      id: doc.id,
      name: d['name'] ?? '',
      coverImage: d['coverImage'],
      adminId: d['adminId'] ?? '',
      memberIds: List<String>.from(d['memberIds'] ?? []),
      memberNames: Map<String, String>.from(d['memberNames'] ?? {}),
      lastMessage: d['lastMessage'],
      lastMessageAt: (d['lastMessageAt'] as Timestamp?)?.toDate(),
      unreadCounts: Map<String, int>.from(d['unreadCounts'] ?? {}),
    );
  }

  Map<String, dynamic> toFirestore() => {
    'name': name,
    'coverImage': coverImage,
    'adminId': adminId,
    'memberIds': memberIds,
    'memberNames': memberNames,
    'lastMessage': lastMessage,
    'lastMessageAt': lastMessageAt != null ? Timestamp.fromDate(lastMessageAt!) : null,
    'unreadCounts': unreadCounts,
    'createdAt': FieldValue.serverTimestamp(),
  };

  int myUnread(String uid) => unreadCounts[uid] ?? 0;
  String adminName() => memberNames[adminId] ?? 'المدير';
}
