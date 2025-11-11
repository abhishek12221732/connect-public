import 'package:cloud_firestore/cloud_firestore.dart';

class CalendarEvent {
  final String id;
  final String title;
  final String description;
  final DateTime startDate;
  final DateTime? endDate;
  final DateTime? reminderTime;
  final String createdBy;
  final int? notificationId;
  final String category;
  final String? location;
  final String? repeat;
  final int? color;
  final String? reminderPreset;
  final bool? isPersonal;
  final String? personalUserId;
  final String? milestoneId;

  
  CalendarEvent({
    required this.id,
    required this.title,
    required this.description,
    required this.startDate,
    this.endDate,
    this.reminderTime,
    required this.createdBy,
    this.notificationId,
    this.category = 'event',
    this.location,
    this.repeat,
    this.color,
    this.reminderPreset,
    this.isPersonal,
    this.personalUserId,
     this.milestoneId,
  });
  
  factory CalendarEvent.fromMap(Map<String, dynamic> map, String documentId) {
    return CalendarEvent(
      id: documentId,
      title: map['title'] as String? ?? '',
      description: map['description'] as String? ?? '',
      startDate: (map['startDate'] as Timestamp).toDate(),
      endDate: map['endDate'] != null ? (map['endDate'] as Timestamp).toDate() : null,
      reminderTime: map['reminderTime'] != null ? (map['reminderTime'] as Timestamp).toDate() : null,
      createdBy: map['createdBy'] as String? ?? '',
      notificationId: map.containsKey('notificationId') ? (map['notificationId'] as int?) : null,
      category: map['category'] as String? ?? 'event',
      location: map['location'] as String?,
      repeat: map['repeat'] as String?,
      color: map['color'] is int ? map['color'] as int : null,
      reminderPreset: map['reminderPreset'] as String?,
      isPersonal: map['isPersonal'] as bool?,
      personalUserId: map['personalUserId'] as String?,
      milestoneId: map['milestoneId'], 
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': endDate != null ? Timestamp.fromDate(endDate!) : null,
      'reminderTime': reminderTime != null ? Timestamp.fromDate(reminderTime!) : null,
      'createdBy': createdBy,
      'notificationId': notificationId,
      'category': category,
      'location': location,
      'repeat': repeat,
      'color': color,
      'reminderPreset': reminderPreset,
      'isPersonal': isPersonal ?? false,
      'personalUserId': personalUserId,
      'milestoneId' : milestoneId,
    };
  }
}
