// lib/features/secret_note/repository/secret_note_repository.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:feelings/features/chat/models/message_model.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:feelings/services/encryption_service.dart';

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

  /// Deletes a specific note from Firestore (Used for ephemeral "seen" behavior).
  Future<void> deleteSecretNote(String coupleId, String noteId) async {
    try {
      await _firestore
          .collection('couples')
          .doc(coupleId)
          .collection('secret_notes')
          .doc(noteId)
          .delete();
    } catch (e) {
      debugPrint("[SecretNoteRepository] Error deleting secret note: $e");
      rethrow;
    }
  }

  /// (Legacy) Marks a specific note as read in Firestore.
  /// KEPT FOR BACKWARD COMPATIBILITY during migration, but new flow uses delete.
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
  // Inside sendSecretNote(String coupleId, MessageModel note)

  Future<void> sendSecretNote(String coupleId, MessageModel note) async {
    try {
      // 1. Generate the ID here
      final noteRef = _firestore
          .collection('couples')
          .doc(coupleId)
          .collection('secret_notes')
          .doc();

      // ✨ ENCRYPTION LOGIC START
      String? ciphertext;
      String? nonce;
      String? mac;
      int? encryptionVersion;
      String finalContent = note.content; // Default
      String? finalGoogleDriveImageId = note.googleDriveImageId;

      // Check if encryption is ready AND if there is content to encrypt
      if (EncryptionService.instance.isReady && note.encryptionVersion == null) {
        try {
          // CASE A: Text Note
          if (note.content.isNotEmpty) {
             final encrypted = await EncryptionService.instance.encryptText(note.content);
             ciphertext = encrypted['ciphertext'];
             nonce = encrypted['nonce'];
             mac = encrypted['mac'];
             encryptionVersion = 1;
             mac = encrypted['mac'];
             encryptionVersion = 1;
             finalContent = "🔒 Encrypted Note"; // 🔒 Fallback for legacy clients
          }
          // CASE B: Image Note (Encrypt the ID)
          else if (note.messageType == 'image' && note.googleDriveImageId != null) {
             final encrypted = await EncryptionService.instance.encryptText(note.googleDriveImageId!);
             ciphertext = encrypted['ciphertext'];
             nonce = encrypted['nonce'];
             mac = encrypted['mac'];
             encryptionVersion = 1;
             finalGoogleDriveImageId = ""; // 🔒 Hide ID
          }
        } catch (e) {
          debugPrint("⚠️ Secret Note Encryption failed: $e");
        }
      }
      // ✨ ENCRYPTION LOGIC END

      // 2. Create the final model with the generated ID AND encrypted fields
      final finalNote = note.copyWith(
        id: noteRef.id,
        content: finalContent,
        googleDriveImageId: finalGoogleDriveImageId, // Use the masked ID
        
        ciphertext: ciphertext,
        nonce: nonce,
        mac: mac,
        encryptionVersion: encryptionVersion,
      );

      // 3. Convert to map and add the required `isRead` flag
      final noteData = finalNote.toMap();
      noteData['isRead'] = false; // Secret Notes are always unread upon sending

      await noteRef.set(noteData);
    } catch (e) {
      debugPrint("[SecretNoteRepository] Error sending secret note: $e");
      rethrow;
    }
  }
  // ----- MIGRATION METHODS -----

  Future<void> migrateLegacySecretNote(String coupleId, MessageModel note) async {
    if (!EncryptionService.instance.isReady) return;
    
    // Only migrate if plaintext exists and no encryption info
    if (note.encryptionVersion != null) return;

    try {
      final docRef = _firestore
          .collection('couples')
          .doc(coupleId)
          .collection('secret_notes')
          .doc(note.id);

      String? ciphertext;
      String? nonce;
      String? mac;
      Map<String, dynamic> updates = {};

      // CASE A: Text Note
      if (note.messageType == 'text' && note.content.isNotEmpty) {
        final encrypted = await EncryptionService.instance.encryptText(note.content);
        ciphertext = encrypted['ciphertext'];
        nonce = encrypted['nonce'];
        mac = encrypted['mac'];
        
        
        updates = {
          'content': '🔒 Encrypted Note', // Fallback
          'ciphertext': ciphertext,
          'nonce': nonce,
          'mac': mac,
          'encryptionVersion': 1,
        };
      } 
      // CASE B: Image Note
      else if (note.messageType == 'image' && note.googleDriveImageId != null) {
        final encrypted = await EncryptionService.instance.encryptText(note.googleDriveImageId!);
        ciphertext = encrypted['ciphertext'];
        nonce = encrypted['nonce'];
        mac = encrypted['mac'];
        
        updates = {
          'googleDriveImageId': '', // Clear plaintext ID
          'ciphertext': ciphertext,
          'nonce': nonce,
          'mac': mac,
          'encryptionVersion': 1,
        };
      }

      if (updates.isNotEmpty) {
        // debugPrint("🔒 [Migration] Migrating Secret Note ${note.id}...");
        await docRef.update(updates);
      }

    } catch (e) {
      debugPrint("⚠️ [Migration] Secret Note ${note.id} migration failed: $e");
    }
  }
}