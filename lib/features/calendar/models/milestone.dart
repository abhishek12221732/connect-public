import 'package:cloud_firestore/cloud_firestore.dart';

class Milestone {
  final String id;
  final String title;
  final DateTime date;
  final String type; // e.g., 'anniversary', 'engagement', 'trip', etc.
  final String? description;
  final String createdBy;
  final String? icon; // Optional: icon name or emoji
  final int? color; // Optional: color value for UI

  Milestone({
    required this.id,
    required this.title,
    required this.date,
    required this.type,
    this.description,
    required this.createdBy,
    this.icon,
    this.color,
  });

  factory Milestone.fromMap(Map<String, dynamic> map, String documentId) {
    return Milestone(
      id: documentId,
      title: map['title'] as String? ?? '',
      date: (map['date'] as Timestamp).toDate(),
      type: map['type'] as String? ?? '',
      description: map['description'] as String?,
      createdBy: map['createdBy'] as String? ?? '',
      icon: map['icon'] as String?,
      color: map['color'] as int?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'date': Timestamp.fromDate(date),
      'type': type,
      'description': description,
      'createdBy': createdBy,
      'icon': icon,
      'color': color,
    };
  }
} 
