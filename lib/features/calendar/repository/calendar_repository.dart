import 'package:cloud_firestore/cloud_firestore.dart';

class CalendarRepository {
  final FirebaseFirestore _firestore;

  CalendarRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Add a new event for a couple.
  Future<DocumentReference> addEvent(String coupleId, Map<String, dynamic> eventData) async {
    try {
      return await _firestore
          .collection('couples')
          .doc(coupleId)
          .collection('events')
          .add(eventData);
    } catch (e) {
      throw Exception("Error adding calendar event: $e");
    }
  }

  /// Update an existing event.
  Future<void> updateEvent(String coupleId, String eventId, Map<String, dynamic> eventData) async {
    try {
      await _firestore
          .collection('couples')
          .doc(coupleId)
          .collection('events')
          .doc(eventId)
          .update(eventData);
    } catch (e) {
      throw Exception("Error updating calendar event: $e");
    }
  }

  /// Delete an event and cancel the reminder if it has one.
  Future<void> deleteEvent(String coupleId, String eventId) async {
  try {
    await _firestore
        .collection('couples')
        .doc(coupleId)
        .collection('events')
        .doc(eventId)
        .delete();
  } catch (e) {
    throw Exception("Error deleting calendar event: $e");
  }
}


  /// Get all events for a couple, ordered by startDate.
  Stream<QuerySnapshot<Map<String, dynamic>>> getEvents(String coupleId) {
    return _firestore
        .collection('couples')
        .doc(coupleId)
        .collection('events')
        .orderBy('startDate', descending: false)
        .snapshots();
  }
  Future<int> countUpcomingEvents(String coupleId) async {
    try {
      // Get the current date and time.
      DateTime now = DateTime.now();

      // Query for events with a startDate greater than the current date and time.
      QuerySnapshot<Map<String, dynamic>> snapshot = await _firestore
          .collection('couples')
          .doc(coupleId)
          .collection('events')
          .where('startDate', isGreaterThan: now)
          .get();

      // Return the count of the documents in the query snapshot.
      return snapshot.docs.length;
    } catch (e) {
      throw Exception("Error counting upcoming events: $e");
    }
  }

  // --- Milestone Methods ---

  /// Add a new milestone for a couple.
  Future<DocumentReference> addMilestone(String coupleId, Map<String, dynamic> milestoneData) async {
    // Validate required fields
    if (!milestoneData.containsKey('title') || milestoneData['title'] == null || (milestoneData['title'] as String).trim().isEmpty) {
      throw Exception('Milestone title is required.');
    }
    if (!milestoneData.containsKey('date') || milestoneData['date'] == null) {
      throw Exception('Milestone date is required.');
    }
    if (!milestoneData.containsKey('type') || milestoneData['type'] == null || (milestoneData['type'] as String).trim().isEmpty) {
      throw Exception('Milestone type is required.');
    }
    if (!milestoneData.containsKey('createdBy') || milestoneData['createdBy'] == null || (milestoneData['createdBy'] as String).trim().isEmpty) {
      throw Exception('Milestone createdBy is required.');
    }
    try {
      return await _firestore
          .collection('couples')
          .doc(coupleId)
          .collection('milestones')
          .add(milestoneData);
    } catch (e, stack) {
      print('Error adding milestone: $e\n$stack');
      throw Exception("Error adding milestone: $e");
    }
  }

  /// Update an existing milestone.
  Future<void> updateMilestone(String coupleId, String milestoneId, Map<String, dynamic> milestoneData) async {
    if (milestoneData.isEmpty) {
      throw Exception('No milestone data provided for update.');
    }
    try {
      await _firestore.runTransaction((transaction) async {
        final docRef = _firestore
            .collection('couples')
            .doc(coupleId)
            .collection('milestones')
            .doc(milestoneId);
        final snapshot = await transaction.get(docRef);
        if (!snapshot.exists) {
          throw Exception('Milestone does not exist.');
        }
        transaction.update(docRef, milestoneData);
      });
    } catch (e, stack) {
      print('Error updating milestone: $e\n$stack');
      throw Exception("Error updating milestone: $e");
    }
  }

  /// Delete a milestone.
  Future<void> deleteMilestone(String coupleId, String milestoneId) async {
    try {
      await _firestore.runTransaction((transaction) async {
        final docRef = _firestore
            .collection('couples')
            .doc(coupleId)
            .collection('milestones')
            .doc(milestoneId);
        final snapshot = await transaction.get(docRef);
        if (!snapshot.exists) {
          throw Exception('Milestone does not exist.');
        }
        transaction.delete(docRef);
      });
    } catch (e, stack) {
      print('Error deleting milestone: $e\n$stack');
      throw Exception("Error deleting milestone: $e");
    }
  }

  /// Get all milestones for a couple, ordered by date.
  Stream<QuerySnapshot<Map<String, dynamic>>> getMilestones(String coupleId) {
    return _firestore
        .collection('couples')
        .doc(coupleId)
        .collection('milestones')
        .orderBy('date', descending: false)
        .snapshots();
  }
}
