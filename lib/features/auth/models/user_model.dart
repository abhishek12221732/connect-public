// lib/features/auth/models/user_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';

// Enum for type-safe gender selection.
enum Gender {
  male,
  female,
  other,
  preferNotToSay,
}

class UserModel {
  final String id;
  final String email;
  final String? name;
  final String? profileImageUrl;
  final String? mood;
  final DateTime? moodLastUpdated;
  final List<String> doneQuestions;
  final double? latitude;
  final double? longitude;
  
  // Fields that were used in the app but not in the model.
  final String? coupleId;
  final bool notificationsEnabled;
  final bool locationSharingEnabled;
  final DateTime? createdAt;
  final DateTime? lastUpdated;

  // New requested fields.
  final String? loveLanguage;
  final Gender? gender;

  UserModel({
    required this.id,
    required this.email,
    this.name,
    this.profileImageUrl,
    this.mood,
    this.moodLastUpdated,
    List<String>? doneQuestions,
    this.latitude,
    this.longitude,
    this.coupleId,
    this.notificationsEnabled = true,
    this.locationSharingEnabled = true,
    this.createdAt,
    this.lastUpdated,
    this.loveLanguage,
    this.gender,
  }) : doneQuestions = doneQuestions ?? [];

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      id: map['userId'] ?? map['id'],
      email: map['email'],
      name: map['name'],
      profileImageUrl: map['profileImageUrl'],
      mood: map['mood'],
      moodLastUpdated: (map['moodLastUpdated'] as Timestamp?)?.toDate(),
      doneQuestions: List<String>.from(map['doneQuestions'] ?? []),
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
      coupleId: map['coupleId'],
      notificationsEnabled: map['notificationsEnabled'] ?? true,
      locationSharingEnabled: map['locationSharingEnabled'] ?? true,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
      lastUpdated: (map['lastUpdated'] as Timestamp?)?.toDate(),
      loveLanguage: map['loveLanguage'],
      gender: map['gender'] != null ? Gender.values.byName(map['gender']) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': id,
      'email': email,
      'name': name,
      'profileImageUrl': profileImageUrl,
      'mood': mood,
      'moodLastUpdated': moodLastUpdated,
      'doneQuestions': doneQuestions,
      'latitude': latitude,
      'longitude': longitude,
      'coupleId': coupleId,
      'notificationsEnabled': notificationsEnabled,
      'locationSharingEnabled': locationSharingEnabled,
      'createdAt': createdAt,
      'lastUpdated': lastUpdated,
      'loveLanguage': loveLanguage,
      'gender': gender?.name,
    };
  }
}