// lib/features/rhm/repository/rhm_repository.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart'; // Import for debugPrint
import 'package:feelings/features/rhm/models/rhm_action.dart';
// Add this import
import 'package:feelings/services/rhm_animation_service.dart';



class RhmRepository {
  final FirebaseFirestore _firestore;

  RhmRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  // ... (logAction and getRhmScoreStream methods remain the same) ...
  Future<void> logAction({
    required String coupleId,
    required String userId,
    required String actionType,
    required int points,
    String? sourceId,
  }) async {
    try {
      final DateTime expiryDate = DateTime.now().add(const Duration(days: 8));
      await _firestore
          .collection('couples')
          .doc(coupleId)
          .collection('rhm_actions')
          .add({
        'createdAt': Timestamp.now(),
        'expireAt': Timestamp.fromDate(expiryDate),
        'userId': userId,
        'actionType': actionType,
        'points': points,
        'sourceId': sourceId,
      });
      final reason = RhmAction(
      id: '', // A dummy value, not needed here
      userId: userId,
      actionType: actionType,
      points: points,
      createdAt: DateTime.now(),
    ).title;

    // Trigger the animation with the points and the reason from your model.
    rhmAnimationService.awardPoints(points, reason);
    } catch (e) {
      debugPrint("Error logging RHM action: $e"); // Use debugPrint
    }
  }

  Stream<int> getRhmScoreStream(String coupleId) {
    final DateTime cutoff = DateTime.now().subtract(const Duration(days: 7));
    final query = _firestore
        .collection('couples')
        .doc(coupleId)
        .collection('rhm_actions')
        .where('createdAt', isGreaterThan: Timestamp.fromDate(cutoff));

    return query.snapshots().map((snapshot) {
      int activityPoints = 0;
      for (final doc in snapshot.docs) {
        final data = doc.data();
        if (data.containsKey('points')) {
          activityPoints += (data['points'] as num).toInt();
        }
      }

      // --- ✨ NEW SCORING LOGIC ---
      //
      // Old logic: int finalScore = 50 + activityPoints;
      // This was flawed, as an inactive couple had a score of 50.
      //
      // New logic:
      // We set a "target" number of points a healthy, active couple
      // should aim for in a 7-day period. Let's set this to 65.
      // A score of 65 points in a week = 100% RHM.
      //
      // (Total Points / Target) * 100
      const double targetPoints = 75.0; 
      
      // Calculate the score as a percentage of the target
      double calculatedScore = (activityPoints / targetPoints) * 100.0;
      
      // Clamp the score between 0 and 100
      if (calculatedScore > 100.0) {
        return 100;
      }
      if (calculatedScore < 0) {
        return 0;
      }
      
      // Return the final score as an integer
      return calculatedScore.toInt();
      //
      // --- END NEW SCORING LOGIC ---
    });
  }

  Stream<List<RhmAction>> getRecentActionsStream(String coupleId) {
    final DateTime cutoff = DateTime.now().subtract(const Duration(days: 7));
    final query = _firestore
        .collection('couples')
        .doc(coupleId)
        .collection('rhm_actions')
        .where('createdAt', isGreaterThan: Timestamp.fromDate(cutoff))
        .orderBy('createdAt', descending: true)
        .limit(50); // Get the 50 most recent actions

    return query.snapshots().map((snapshot) {
      try {
        return snapshot.docs.map((doc) => RhmAction.fromFirestore(doc)).toList();
      } catch (e) {
        debugPrint("Error mapping RhmAction: $e");
        return [];
      }
    });
  }

  Future<DateTime?> getLastActionTimestamp(String coupleId, String actionType) async {
    try {
      final querySnapshot = await _firestore
          .collection('couples')
          .doc(coupleId)
          .collection('rhm_actions')
          .where('actionType', isEqualTo: actionType)
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final data = querySnapshot.docs.first.data();
        final timestamp = data['createdAt'] as Timestamp?;
        return timestamp?.toDate();
      }
      return null;
    } catch (e) {
      debugPrint("Error getting last action timestamp for $actionType: $e"); // Use debugPrint
      return null;
    }
  }

  // ✨ [ADD] New method to get the timestamp of the last action *for a specific user*
  Future<DateTime?> getLastActionTimestampForUser(String coupleId, String userId, String actionType) async {
    try {
      final querySnapshot = await _firestore
          .collection('couples')
          .doc(coupleId)
          .collection('rhm_actions')
          .where('actionType', isEqualTo: actionType)
          .where('userId', isEqualTo: userId) // Filter by user ID
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final data = querySnapshot.docs.first.data();
        final timestamp = data['createdAt'] as Timestamp?;
        return timestamp?.toDate();
      }
      return null; // No previous action of this type found for this user
    } catch (e) {
      debugPrint("Error getting last action timestamp for user $userId, action $actionType: $e"); // Use debugPrint
      return null; // Return null on error
    }
  }
}