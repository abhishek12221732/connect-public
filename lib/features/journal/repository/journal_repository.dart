// lib/features/journal/repository/journal_repository.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:feelings/services/encryption_service.dart';

class JournalRepository {
  final FirebaseFirestore _firestore;

  JournalRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  // ----- PERSONAL JOURNAL METHODS -----

  Future<DocumentReference> addPersonalJournalEntry(String userId, Map<String, dynamic> entryData, {bool isEncryptionEnabled = false}) async {
    try {
      // ✨ ENCRYPT BEFORE SENDING
      final encryptedData = await _encryptPersonalEntry(entryData, isEncryptionEnabled: isEncryptionEnabled);

      final docRef = await _firestore
          .collection('users')
          .doc(userId)
          .collection('personal_journals')
          .add(encryptedData);
      return docRef;
    } catch (e) {
      throw Exception("Error adding personal journal entry: $e");
    }
  }

  Future<void> updatePersonalJournalEntry(String userId, String entryId, Map<String, dynamic> entryData, {bool isEncryptionEnabled = false}) async {
    try {
      // ✨ ENCRYPT BEFORE UPDATING
      final encryptedData = await _encryptPersonalEntry(entryData, isEncryptionEnabled: isEncryptionEnabled);

      await _firestore
          .collection('users')
          .doc(userId)
          .collection('personal_journals')
          .doc(entryId)
          .update(encryptedData);
    } catch (e) {
      throw Exception("Error updating personal journal entry: $e");
    }
  }

  Future<Map<String, dynamic>> _encryptPersonalEntry(Map<String, dynamic> entryData, {bool isEncryptionEnabled = false}) async {
    // Only encrypt if service is ready AND enabled AND content exists
    if (!EncryptionService.instance.isReady || !isEncryptionEnabled || entryData['content'] == null) {
        return entryData;
    }

    final newEntry = Map<String, dynamic>.from(entryData);
    
    try {
      final content = newEntry['content'] as String;
      final encrypted = await EncryptionService.instance.encryptText(content);
      
      newEntry['content'] = "🔒 Encrypted Journal"; // 🔒 Fallback for legacy clients
      newEntry['ciphertext'] = encrypted['ciphertext'];
      newEntry['nonce'] = encrypted['nonce'];
      newEntry['mac'] = encrypted['mac'];
      newEntry['encryptionVersion'] = 1;
    } catch (e) {
      print("⚠️ Personal Journal Encryption Failed: $e");
    }

    return newEntry;
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

  Future<DocumentReference> addSharedJournalEntry(String coupleId, Map<String, dynamic> entryData, {bool isEncryptionEnabled = false}) async {
    try {
      if (!entryData.containsKey('createdBy')) {
        throw Exception('Entry data must include createdBy user id.');
      }
      
      // ✨ ENCRYPT BEFORE SENDING
      final encryptedData = await _encryptEntryData(entryData, isEncryptionEnabled: isEncryptionEnabled);

      final docRef = await _firestore
          .collection('couples')
          .doc(coupleId)
          .collection('shared_journals')
          .add(encryptedData); // Use encryptedData here
          
      return docRef;
    } catch (e) {
      throw Exception("Error adding shared journal entry: $e");
    }
  }

  Future<void> updateSharedJournalEntry(String coupleId, String entryId, Map<String, dynamic> entryData, {bool isEncryptionEnabled = false}) async {
    try {
      // ✨ ENCRYPT BEFORE UPDATING
      final encryptedData = await _encryptEntryData(entryData, isEncryptionEnabled: isEncryptionEnabled);

      await _firestore
          .collection('couples')
          .doc(coupleId)
          .collection('shared_journals')
          .doc(entryId)
          .update(encryptedData); // Use encryptedData here
          
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

  // Helper to encrypt segments inside the entry data
  Future<Map<String, dynamic>> _encryptEntryData(Map<String, dynamic> entryData, {bool isEncryptionEnabled = false}) async {
    // 1. Check if encryption is ready AND enabled
    if (!EncryptionService.instance.isReady || !isEncryptionEnabled) return entryData;

    final newEntryData = Map<String, dynamic>.from(entryData);

    // 2. Check if there are segments to encrypt
    if (newEntryData.containsKey('segments') && newEntryData['segments'] is List) {
      List<dynamic> segments = List.from(newEntryData['segments']);
      List<dynamic> encryptedSegments = [];

      for (var segment in segments) {
        Map<String, dynamic> segMap = Map<String, dynamic>.from(segment);
        
        // Only encrypt if it is a text segment and has content
        // Handle both 'text' and 'content' keys, prioritize 'text'
        final content = segMap['text'] ?? segMap['content'];
        
        if ((segMap['type'] == 'text' || segMap['type'] == null) && content != null) {
          try {
            final encrypted = await EncryptionService.instance.encryptText(content);
            
            // Replace plaintext content with placeholder
            segMap['text'] = "🔒 Encrypted content"; 
            segMap.remove('content');
            
            // Add encrypted fields
            segMap['ciphertext'] = encrypted['ciphertext'];
            segMap['nonce'] = encrypted['nonce'];
            segMap['mac'] = encrypted['mac'];
            segMap['encryptionVersion'] = 1;
            segMap['type'] = 'text'; // Normalize
            
          } catch (e) {
            debugPrint("⚠️ Journal Segment Encryption failed: $e");
          }
        }
        encryptedSegments.add(segMap);
      }
      newEntryData['segments'] = encryptedSegments;
    }
    
    return newEntryData;
  }
  // ----- MIGRATION METHODS -----

  Future<void> migrateLegacyPersonalJournal(String userId, String entryId, Map<String, dynamic> entryData) async {
    if (!EncryptionService.instance.isReady) return;
    
    // Only migrate if plaintext exists and no encryption info
    if (entryData['encryptionVersion'] != null || entryData['content'] == null) return;

    try {
      final content = entryData['content'] as String;
      if (content.isEmpty) return; // Nothing to encrypt

      final encrypted = await EncryptionService.instance.encryptText(content);
      
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('personal_journals')
          .doc(entryId)

          .update({
            'content': '🔒 Encrypted Journal', // 🔒 Fallback
            'ciphertext': encrypted['ciphertext'],
            'nonce': encrypted['nonce'],
            'mac': encrypted['mac'],
            'encryptionVersion': 1,
          });
          
      debugPrint("🔒 [Migration] Personal Journal $entryId migrated.");
    } catch (e) {
      debugPrint("⚠️ [Migration] Personal Journal $entryId failed: $e");
    }
  }

  Future<void> migrateLegacySharedJournal(String coupleId, String entryId, Map<String, dynamic> entryData) async {
    if (!EncryptionService.instance.isReady) return;
    
    // Check if we need migration (at least one segment is plaintext 'text')
    if (!entryData.containsKey('segments') || entryData['segments'] is! List) return;
    
    List<dynamic> segments = List.from(entryData['segments']);
    bool needsMigration = false;
    List<dynamic> updatedSegments = [];

    for (var segment in segments) {
      Map<String, dynamic> segMap = Map<String, dynamic>.from(segment);
      
      // Check if this segment needs encryption
      // Legacy segments might not have 'type', assume 'text' if missing.
      // Legacy segments use 'text' key, not 'content'.
      final isTextType = segMap['type'] == 'text' || segMap['type'] == null;
      final content = segMap['text'] ?? segMap['content'];
      
      if (isTextType && 
          content != null && 
          (content as String).isNotEmpty &&
          segMap['encryptionVersion'] == null) {
            
        needsMigration = true;
        try {
          final encrypted = await EncryptionService.instance.encryptText(content);
          
          segMap['text'] = "🔒 Encrypted content"; // Fallback
          segMap.remove('content'); // Ensure we don't have mixed keys
          
          segMap['ciphertext'] = encrypted['ciphertext'];
          segMap['nonce'] = encrypted['nonce'];
          segMap['mac'] = encrypted['mac'];
          segMap['encryptionVersion'] = 1;
          segMap['type'] = 'text'; // Normalize type
        } catch (e) {
          debugPrint("⚠️ Journal Segment Encryption failed during migration: $e");
        }
      }
      updatedSegments.add(segMap);
    }

    if (needsMigration) {
      try {
        await _firestore
            .collection('couples')
            .doc(coupleId)
            .collection('shared_journals')
            .doc(entryId)
            .update({'segments': updatedSegments});
            
        debugPrint("🔒 [Migration] Shared Journal $entryId migrated.");
      } catch (e) {
        debugPrint("⚠️ [Migration] Shared Journal $entryId failed: $e");
      }
    }
  }
}
