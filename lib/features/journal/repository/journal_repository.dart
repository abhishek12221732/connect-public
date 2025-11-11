// lib/features/journal/repository/journal_repository.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class JournalRepository {
  final FirebaseFirestore _firestore;

  JournalRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  // ----- PERSONAL JOURNAL METHODS -----

  Future<DocumentReference> addPersonalJournalEntry(String userId, Map<String, dynamic> entryData) async {
    try {
      // ✨ [MODIFY] Return the DocumentReference from the .add() call
      final docRef = await _firestore
          .collection('users')
          .doc(userId)
          .collection('personal_journals')
          .add(entryData);
      return docRef;
    } catch (e) {
      throw Exception("Error adding personal journal entry: $e");
    }
  }

  Future<void> updatePersonalJournalEntry(String userId, String entryId, Map<String, dynamic> entryData) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('personal_journals')
          .doc(entryId)
          .update(entryData);
    } catch (e) {
      throw Exception("Error updating personal journal entry: $e");
    }
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> getPersonalJournalEntries(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('personal_journals')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  Future<void> deletePersonalJournal(String userId, String journalId) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('personal_journals')
          .doc(journalId)
          .delete();
    } catch (e) {
      throw Exception("Error deleting personal journal: $e");
    }
  }

  Future<int> getTotalPersonalJournals(String userId) async {
  try {
    final querySnapshot = await _firestore
        .collection('users')
        .doc(userId)
        .collection('personal_journals')
        .get();

    // Return the count of documents in the collection
    return querySnapshot.size;
  } catch (e) {
    throw Exception("Error fetching total personal journals: $e");
  }
}

  // ----- SHARED JOURNAL METHODS -----

  Future<DocumentReference> addSharedJournalEntry(String coupleId, Map<String, dynamic> entryData) async {
    try {
      // Ensure the data includes a 'createdBy' field.
      if (!entryData.containsKey('createdBy')) {
        throw Exception('Entry data must include createdBy user id.');
      }
      // ✨ [MODIFY] Return the DocumentReference from the .add() call
      final docRef = await _firestore
          .collection('couples')
          .doc(coupleId)
          .collection('shared_journals')
          .add(entryData);
      return docRef;
    } catch (e) {
      throw Exception("Error adding shared journal entry: $e");
    }
  }

  Future<void> updateSharedJournalEntry(String coupleId, String entryId, Map<String, dynamic> entryData) async {
    try {
      await _firestore
          .collection('couples')
          .doc(coupleId)
          .collection('shared_journals')
          .doc(entryId)
          .update(entryData);
    } catch (e) {
      throw Exception("Error updating shared journal entry: $e");
    }
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> getSharedJournalEntries(String coupleId) {
    return _firestore
        .collection('couples')
        .doc(coupleId)
        .collection('shared_journals')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  // lib/features/journal/repository/journal_repository.dart

Future<void> deleteSharedJournalSegment(String coupleId, String entryId, int segmentIndex) async {
  try {
    // Fetch the current entry.
    final entryDoc = await _firestore
        .collection('couples')
        .doc(coupleId)
        .collection('shared_journals')
        .doc(entryId)
        .get();

    if (!entryDoc.exists) {
      throw Exception('Entry does not exist.');
    }

    // Get the current segments.
    final segments = List<Map<String, dynamic>>.from(entryDoc.data()!['segments']);

    // Remove the segment at the specified index.
    segments.removeAt(segmentIndex);

    // Update the entry in Firestore with the updated segments.
    await _firestore
        .collection('couples')
        .doc(coupleId)
        .collection('shared_journals')
        .doc(entryId)
        .update({'segments': segments});
  } catch (e) {
    throw Exception("Error deleting shared journal segment: $e");
  }
}

  Future<void> deleteSharedJournalEntry(String coupleId, String entryId) async {
    try {
      await _firestore
          .collection('couples')
          .doc(coupleId)
          .collection('shared_journals')
          .doc(entryId)
          .delete();
    } catch (e) {
      throw Exception("Error deleting shared journal entry: $e");
    }
  }
}
