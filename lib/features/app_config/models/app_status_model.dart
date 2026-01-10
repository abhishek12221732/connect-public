import 'package:cloud_firestore/cloud_firestore.dart';

class AppStatusModel {
  final String title;
  final String message;
  final bool isActive;
  final bool isBlocking;
  final String type; // 'maintenance', 'update', 'info', 'warning'

  const AppStatusModel({
    required this.title,
    required this.message,
    this.isActive = false,
    this.isBlocking = false,
    this.type = 'info',
  });

  factory AppStatusModel.fromMap(Map<String, dynamic> map) {
    return AppStatusModel(
      title: map['title'] ?? 'Notice',
      message: map['message'] ?? '',
      isActive: map['isActive'] ?? false,
      isBlocking: map['isBlocking'] ?? false,
      type: map['type'] ?? 'info',
    );
  }

  factory AppStatusModel.fromSnapshot(DocumentSnapshot doc) {
    if (!doc.exists || doc.data() == null) {
      return const AppStatusModel(title: '', message: '');
    }
    return AppStatusModel.fromMap(doc.data() as Map<String, dynamic>);
  }

  factory AppStatusModel.empty() {
    return const AppStatusModel(title: '', message: '');
  }

  bool get shouldShow => isActive;
}
