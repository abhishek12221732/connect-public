// lib/providers/journal_provider.dart

import 'dart:async';
import 'package:flutter/material.dart';
import '../features/journal/repository/journal_repository.dart';
import 'package:feelings/features/rhm/repository/rhm_repository.dart';
import './dynamic_actions_provider.dart';
import 'package:feelings/features/journal/screens/journal_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:feelings/services/encryption_service.dart';

class JournalProvider with ChangeNotifier {
  final DynamicActionsProvider _dynamicActionsProvider;

  JournalFilterOption? filterToShowOnNextLoad;
  bool showAddMemoryOnNextLoad = false;

  final JournalRepository _journalRepository;
  final RhmRepository _rhmRepository;

  List<Map<String, dynamic>> _personalEntries = [];
  List<Map<String, dynamic>> _sharedEntries = [];

  StreamSubscription? _personalJournalsSubscription;
  StreamSubscription? _sharedJournalsSubscription;
  StreamSubscription? _personalKeyWaitSub;
  StreamSubscription? _sharedKeyWaitSub;
  
  bool _isWaitingForPersonalKey = false;
  bool _isWaitingForSharedKey = false;

  List<Map<String, dynamic>> get personalEntries => _personalEntries;
  List<Map<String, dynamic>> get sharedEntries => _sharedEntries;

  JournalProvider(
    this._dynamicActionsProvider, {
    required JournalRepository journalRepository,
    required RhmRepository rhmRepository,
  })  : _journalRepository = journalRepository,
        _rhmRepository = rhmRepository;

  void clear() {
    // ... (unchanged)
    _personalJournalsSubscription?.cancel();
    _sharedJournalsSubscription?.cancel();
    _personalKeyWaitSub?.cancel();
    _sharedKeyWaitSub?.cancel();
    _personalEntries = [];
    _sharedEntries = [];
    filterToShowOnNextLoad = null;
    showAddMemoryOnNextLoad = false;
    // notifyListeners();
    print("[JournalProvider] Cleared and reset state.");
  }

  // ----- PERSONAL JOURNAL METHODS -----
  // ... (all personal journal methods are unchanged) ...
  void listenToPersonalJournals(String userId) async {
    // 1. Listen for Key Readiness to auto-retry
    _personalKeyWaitSub?.cancel();
    _personalKeyWaitSub = EncryptionService.instance.onKeyReady.listen((isReady) {
      if (isReady && _isWaitingForPersonalKey) {
        debugPrint("[Journal] Key ready, refreshing personal journals...");
        _isWaitingForPersonalKey = false;
        listenToPersonalJournals(userId);
      }
    });
    _personalJournalsSubscription?.cancel();
    _personalJournalsSubscription =
        _journalRepository.getPersonalJournalEntries(userId).listen(
      (snapshot) async {
        // ✨ --- [GUARD 1: ON-DATA] --- ✨
        // If the user is null, a logout just happened. Stop.
        if (FirebaseAuth.instance.currentUser == null) {
          debugPrint("[JournalProvider] Personal journal event received, but user is logged out. Ignoring.");
          return;
        }

        List<Map<String, dynamic>> processedEntries = [];

        for (var doc in snapshot.docs) {
          var data = doc.data();
          data['id'] = doc.id;

          // ✨ DECRYPTION LOGIC
          if (data['encryptionVersion'] == 1 && data['ciphertext'] != null) {
            try {
              if (!EncryptionService.instance.isReady) {
                 data['content'] = "⏳ Waiting for key...";
                 _isWaitingForPersonalKey = true;
              } else {
                 final decryptedText = await EncryptionService.instance.decryptText(
                  data['ciphertext'],
                  data['nonce'],
                  data['mac']
                );
                data['content'] = decryptedText;
              }
            } catch (e) {
              data['content'] = "🔒 Decryption Failed";
            }
          }
          // ✨ MIGRATION LOGIC
          else if (EncryptionService.instance.isReady && 
                   data['encryptionVersion'] == null && 
                   data['content'] != null && 
                   (data['content'] as String).isNotEmpty) {
             // Fire and forget migration
             _journalRepository.migrateLegacyPersonalJournal(userId, doc.id, data);
          }
          // ✨ END DECRYPTION

          processedEntries.add(data);
        }
        
        _personalEntries = processedEntries;
        notifyListeners();
      },
      onError: (error) {
        // ✨ --- [GUARD 2: ON-ERROR] --- ✨
        // This is the one that catches the PERMISSION_DENIED
        if (error is FirebaseException && error.code == 'permission-denied') {
          if (FirebaseAuth.instance.currentUser == null) {
            // This is the expected "crash" during logout.
            // It's safe to ignore and we don't need to log it as an error.
            debugPrint("[JournalProvider] Safely caught permission-denied on personal listener during logout.");
          } else {
            // This is a *real* permission error for a logged-in user.
            debugPrint("[JournalProvider] CRITICAL PERMISSION ERROR: $error");
            // You could log this to Crashlytics
          }
        } else {
          // A different, unexpected error
          debugPrint("[JournalProvider] Unexpected error: $error");
        }
      },
    );
  }

  Future<DocumentReference> addPersonalJournalEntry(String userId, Map<String, dynamic> entryData, {bool isEncryptionEnabled = false}) async {
    // ✨ [MODIFY] Capture and return the docRef
    final docRef = await _journalRepository.addPersonalJournalEntry(
      userId, 
      entryData, 
      isEncryptionEnabled: isEncryptionEnabled
    );
    _dynamicActionsProvider.recordPersonalJournalSaved();
    return docRef;
  }

  Future<void> updatePersonalJournalEntry(String userId, String entryId, Map<String, dynamic> entryData, {bool isEncryptionEnabled = false}) async {
    await _journalRepository.updatePersonalJournalEntry(
      userId, 
      entryId, 
      entryData, 
      isEncryptionEnabled: isEncryptionEnabled
    );
    _dynamicActionsProvider.recordPersonalJournalSaved();
  }

  Future<void> deletePersonalJournal(String userId, String journalId) async {
    try {
      await _journalRepository.deletePersonalJournal(userId, journalId);
      _personalEntries.removeWhere((journal) => journal['id'] == journalId);
      notifyListeners();
    } catch (e) {
      print("Failed to delete journal: $e");
    }
  }

  Future<int> getTotalPersonalJournals(String userId) async {
    try {
      return await _journalRepository.getTotalPersonalJournals(userId);
    } catch (e) {
      print("Failed to fetch total personal journals: $e");
      return 0;
    }
  }

  // ----- SHARED JOURNAL METHODS -----

  void listenToSharedJournals(String coupleId) async{
    // 1. Listen for Key Readiness to auto-retry
    _sharedKeyWaitSub?.cancel();
    _sharedKeyWaitSub = EncryptionService.instance.onKeyReady.listen((isReady) {
      if (isReady && _isWaitingForSharedKey) {
        debugPrint("[Journal] Key ready, refreshing shared journals...");
        _isWaitingForSharedKey = false;
        listenToSharedJournals(coupleId);
      }
    });
    _sharedJournalsSubscription?.cancel();
    _sharedJournalsSubscription =
        _journalRepository.getSharedJournalEntries(coupleId).listen(
      (snapshot)async {
        // ✨ --- [GUARD 1: ON-DATA] --- ✨
        if (FirebaseAuth.instance.currentUser == null) {
          debugPrint("[JournalProvider] Shared journal event received, but user is logged out. Ignoring.");
          return;
        }

        List<Map<String, dynamic>> processedEntries = [];

        for (var doc in snapshot.docs) {
          var data = doc.data();
          data['id'] = doc.id;

          // ✨ DECRYPT SEGMENTS
          if (data.containsKey('segments') && data['segments'] is List) {
             List<dynamic> segments = List.from(data['segments']);
             List<dynamic> decryptedSegments = [];
             bool needsMigration = false;
             
             for (var segment in segments) {
               Map<String, dynamic> segMap = Map<String, dynamic>.from(segment);
               
               if (segMap['encryptionVersion'] == 1 && segMap['ciphertext'] != null) {
                  try {
                    if (!EncryptionService.instance.isReady) {
                       segMap['content'] = "⏳ Waiting for key...";
                       _isWaitingForSharedKey = true;
                    } else {
                       final decryptedText = await EncryptionService.instance.decryptText(
                        segMap['ciphertext'], 
                        segMap['nonce'], 
                        segMap['mac']
                      );
                      segMap['content'] = decryptedText;
                    }
                  } catch (e) {
                    segMap['content'] = "⚠️ Error";
                  }
               }
               // Check for migration needed
               else if (EncryptionService.instance.isReady && 
                        segMap['type'] == 'text' && 
                        segMap['encryptionVersion'] == null &&
                        segMap['content'] != null &&
                        (segMap['content'] as String).isNotEmpty) {
                 needsMigration = true;
               }
               
               decryptedSegments.add(segMap);
             }
             
             data['segments'] = decryptedSegments;
             
             // ✨ MIGRATION TRIGGER
             if (needsMigration) {
               _journalRepository.migrateLegacySharedJournal(coupleId, doc.id, data);
             }
          }
          // ✨ END DECRYPT
          
          processedEntries.add(data);
        }

        _sharedEntries = processedEntries;
        notifyListeners();
      },
      onError: (error) {
        // ✨ --- [GUARD 2: ON-ERROR] --- ✨
        if (error is FirebaseException && error.code == 'permission-denied') {
          if (FirebaseAuth.instance.currentUser == null) {
            debugPrint("[JournalProvider] Safely caught permission-denied on shared listener during logout.");
          } else {
            debugPrint("[JournalProvider] CRITICAL SHARED PERMISSION ERROR: $error");
          }
        } else {
          debugPrint("[JournalProvider] Unexpected shared error: $error");
        }
      },
    );
  }

  // ✨ [MODIFY] This method now calls the new daily-limit helper
  Future<DocumentReference> addSharedJournalEntry(String coupleId, Map<String, dynamic> entryData, {bool isEncryptionEnabled = false}) async {
    // 1. Original call
    // ✨ [MODIFY] Capture and return the docRef
    final docRef = await _journalRepository.addSharedJournalEntry(
      coupleId, 
      entryData, 
      isEncryptionEnabled: isEncryptionEnabled
    );
    _dynamicActionsProvider.recordSharedJournalSaved();

    // ✨ [MODIFY] RHM logging logic (unchanged from your file)
    try {
      // Your repo file says entryData MUST contain 'createdBy'
      final String userId = entryData['createdBy'] as String;

      // Log the action using the new helper with daily limit
      await _logSharedJournalRhmAction(coupleId, userId);
    } catch (e) {
      // Don't fail the operation if logging fails. Just log the error.
      print("Error logging RHM action for shared journal: $e");
    }

    // ✨ [MODIFY] Return the docRef at the end
    return docRef;
  }

  // ✨ [MODIFY] This method now also logs RHM actions, with a new signature
  Future<void> updateSharedJournalEntry(
    String coupleId,
    String userId, // ✨ [ADD] userId is now required
    String entryId,
    Map<String, dynamic> entryData, {
      bool isEncryptionEnabled = false,
  }) async {
    // 1. Original call
    await _journalRepository.updateSharedJournalEntry(
        coupleId, 
        entryId, 
        entryData, 
        isEncryptionEnabled: isEncryptionEnabled
    );
    _dynamicActionsProvider.recordSharedJournalSaved();

    // ✨ [ADD] RHM logging logic for updates, with daily limit
    try {
      // The userId is now passed as a parameter
      await _logSharedJournalRhmAction(coupleId, userId);
    } catch (e) {
      print("Error logging RHM action for shared journal update: $e");
    }
  }

  Future<void> deleteSharedJournalSegment(
      String coupleId, String entryId, int segmentIndex) async {
    // ... (unchanged)
    try {
      await _journalRepository.deleteSharedJournalSegment(
          coupleId, entryId, segmentIndex);
      final entry =
          _sharedEntries.firstWhere((entry) => entry['id'] == entryId);
      entry['segments'].removeAt(segmentIndex);
      notifyListeners();
    } catch (e) {
      print("Failed to delete segment: $e");
    }
  }

  Future<void> deleteSharedJournalEntry(String coupleId, String entryId) async {
    // ... (unchanged)
    try {
      await _journalRepository.deleteSharedJournalEntry(coupleId, entryId);
      _sharedEntries.removeWhere((entry) => entry['id'] == entryId);
      notifyListeners();
    } catch (e) {
      print("Failed to delete shared journal entry: $e");
      rethrow;
    }
  }

  void setNextJournalFilter(JournalFilterOption filter) {
    // ... (unchanged)
    filterToShowOnNextLoad = filter;
  }

  void setNextShowAddMemory() {
    // ... (unchanged)
    showAddMemoryOnNextLoad = true;
  }

  void clearCommands() {
    // ... (unchanged)
    filterToShowOnNextLoad = null;
    showAddMemoryOnNextLoad = false;
  }

  // ✨ [ADD] New private helper method for RHM logging with daily limit
  Future<void> _logSharedJournalRhmAction(String coupleId, String userId) async {
    const String actionType = 'shared_journal_entry';
    try {
      // 1. Get the last time this user did this action
      final DateTime? lastActionTime =
          await _rhmRepository.getLastActionTimestampForUser(
        coupleId,
        userId,
        actionType,
      );

      bool shouldLog = false;
      if (lastActionTime == null) {
        // User has never done this action before
        shouldLog = true;
      } else {
        // User has done it before, check if it was before today
        final now = DateTime.now();
        // Get the start of the current calendar day
        final startOfToday = DateTime(now.year, now.month, now.day);

        if (lastActionTime.isBefore(startOfToday)) {
          // Last action was yesterday or earlier.
          shouldLog = true;
        }
      }

      // 2. Log it if we should
      if (shouldLog) {
        await _rhmRepository.logAction(
          coupleId: coupleId,
          userId: userId,
          actionType: actionType,
          points: 2, // +2 for a shared journal entry
        );
      }
      // If !shouldLog, they already did it today, so we do nothing.
    } catch (e) {
      // Don't fail the operation if logging fails. Just log the error.
      print("Error in _logSharedJournalRhmAction: $e");
    }
  }

  @override
  void dispose() {
    clear();
    super.dispose();
  }
}