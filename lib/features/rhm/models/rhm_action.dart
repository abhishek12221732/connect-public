import 'package:cloud_firestore/cloud_firestore.dart';

class RhmAction {
  final String id;
  final String userId;
  final String actionType;
  final int points;
  final DateTime createdAt;
  final String? sourceId;

  RhmAction({
    required this.id,
    required this.userId,
    required this.actionType,
    required this.points,
    required this.createdAt,
    this.sourceId,
  });

  // Helper to get a user-friendly title
  String get title {
    switch (actionType) {
      case 'date_night_completed':
        return 'Completed a Date Night';
      case 'check_in_completed':
        return 'Completed a Check-In';
      case 'bucket_list_completed':
        return 'Finished a Bucket List Item';
      case 'chat_message_sent':
        return 'Started a Conversation';
      case 'qotd_answered':
        return 'Asked the Daily Question';
      case 'shared_journal_entry':
        return 'Added to Shared Journal';
      case 'milestone_added':
        return 'Added a Milestone';
      case 'calendar_event_added':
        return 'Added a Shared Event';
      case 'bucket_list_added':
        return 'Added to Bucket List';
      case 'partner_connected':
        return 'Connected with Partner';
      case 'secret_note_sent':
        return 'Sent a Secret Note';
      default:
        return 'Gained points';
    }
  }

  factory RhmAction.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return RhmAction(
      id: doc.id,
      userId: data['userId'] ?? '',
      actionType: data['actionType'] ?? 'unknown',
      points: (data['points'] as num? ?? 0).toInt(),
      createdAt: (data['createdAt'] as Timestamp? ?? Timestamp.now()).toDate(),
      sourceId: data['sourceId'] as String?,
    );
  }
}
