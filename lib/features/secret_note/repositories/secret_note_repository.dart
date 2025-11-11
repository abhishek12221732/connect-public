// lib/features/secret_note/repository/secret_note_repository.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:feelings/features/chat/models/message_model.dart';
import 'dart:async';
import 'package:flutter/material.dart';

class SecretNoteRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Listens for new, unread secret notes.
  /// Returns a stream of the message list.
  Stream<List<MessageModel>> listenToUnreadNotes(
      String coupleId, String currentUserId) {
    final query = _firestore
        .collection('couples')
        .doc(coupleId)
        .collection('secret_notes')
        .where('receiverId', isEqualTo: currentUserId)
        .where('isRead', isEqualTo: false)
        .orderBy('timestamp', descending: true);

    // Map the snapshot stream to a List<MessageModel> stream
    return query.snapshots().map((snapshot) {
      try {
        return snapshot.docs
            .map((doc) =>
                MessageModel.fromMap(doc.data()))
            .toList();
      } catch (e) {
        debugPrint("[SecretNoteRepository] Error parsing notes: $e");
        return []; // Return empty list on parsing error
      }
    });
  }

  /// Marks a specific note as read in Firestore.
  Future<void> markNoteAsRead(String coupleId, String noteId) async {
    try {
      await _firestore
          .collection('couples')
          .doc(coupleId)
          .collection('secret_notes')
          .doc(noteId)
          .update({'isRead': true});
    } catch (e) {
      debugPrint("[SecretNoteRepository] Error marking note as read: $e");
      rethrow;
    }
  }

  /// Writes a new secret note document to Firestore.
  /// This function now generates the ID and adds the `isRead` flag.
  Future<void> sendSecretNote(String coupleId, MessageModel note) async {
    try {
      // Generate the ID here
      final noteRef = _firestore
          .collection('couples')
          .doc(coupleId)
          .collection('secret_notes')
          .doc();

      // Create the final model with the generated ID
      final finalNote = note.copyWith(id: noteRef.id);

      // Convert to map and add the required `isRead` flag
      final noteData = finalNote.toMap();
      noteData['isRead'] = false;

      await noteRef.set(noteData);
    } catch (e) {
      debugPrint("[SecretNoteRepository] Error sending secret note: $e");
      rethrow;
    }
  }
}