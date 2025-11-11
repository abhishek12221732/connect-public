// lib/features/date_night/models/date_idea.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class DateIdea {
  final String id;
  final String ideaName;
  final String category;
  final String description;
  final List<String> whatYoullNeed;
  final Map<String, dynamic> preferences;
  final DateTime? favoritedAt;

  DateIdea({
    required this.id,
    required this.ideaName,
    required this.category,
    required this.description,
    required this.whatYoullNeed,
    required this.preferences,
    this.favoritedAt,
  });

  factory DateIdea.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    DateTime? favoritedAt;
    final favoritedAtRaw = data['favorited_at'];
    if (favoritedAtRaw is Timestamp) {
      favoritedAt = favoritedAtRaw.toDate();
    } else if (favoritedAtRaw is DateTime) {
      favoritedAt = favoritedAtRaw;
    } else {
      favoritedAt = null;
    }
    return DateIdea(
      id: doc.id,
      ideaName: data['idea_name'] ?? '',
      category: data['category'] ?? '',
      description: data['description'] ?? '',
      whatYoullNeed: List<String>.from(data['what_you_ll_need'] ?? []),
      preferences: Map<String, dynamic>.from(data['preferences'] ?? {}),
      favoritedAt: favoritedAt,
    );
  }
}
