import 'package:cloud_firestore/cloud_firestore.dart';

class BoardModel {
  final String id;
  final String name;
  final String addedBy;
  final Timestamp createdAt;

  BoardModel({
    required this.id,
    required this.name,
    required this.addedBy,
    required this.createdAt,
  });

  factory BoardModel.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    return BoardModel(
      id: doc.id,
      name: (data['name'] ?? 'No Name') as String,
      addedBy: (data['addedBy'] ?? 'Unknown') as String,
      createdAt: data['createdAt'] ?? Timestamp.now(),
    );
  }

}
