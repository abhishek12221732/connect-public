import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:feelings/features/date_night/repository/done_dates_repository.dart';
import 'package:feelings/features/calendar/repository/calendar_repository.dart';
// ✨ [ADD] Import the new RHM repository
import 'package:feelings/features/rhm/repository/rhm_repository.dart'; 
import './dynamic_actions_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DoneDatesProvider extends ChangeNotifier {
  final DynamicActionsProvider _dynamicActionsProvider;
  DoneDatesRepository? _repository;
  final CalendarRepository _calendarRepository;
  // ✨ [ADD] Add the RhmRepository instance
  RhmRepository? _rhmRepository; 
  
  // ✨ Store the stream subscription to cancel it later
  StreamSubscription? _doneDatesSubscription;

  List<Map<String, dynamic>> _doneDates = [];
  bool _isLoading = false;
  String? _error;
  bool _isInitialized = false;
  Timer? _calendarValidationTimer;
  
  // Getters
  List<Map<String, dynamic>> get doneDates => _doneDates;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isInitialized => _isInitialized;

  // ✨ [MODIFY] Update the constructor
  DoneDatesProvider(this._dynamicActionsProvider, {
    required CalendarRepository calendarRepository,
    required RhmRepository rhmRepository, // ✨ [ADD] Require it here
  }) : _calendarRepository = calendarRepository,
       _rhmRepository = rhmRepository; // ✨ [ADD] Initialize it

  // ✨ ADDED: The crucial clear method to reset state on logout
  void clear() {
    _repository = null;
    
    // ✨ [FIX] Do NOT clear the injected RhmRepository.
    // It's a stateless dependency provided by the constructor
    // and should persist for the life of the provider.
    // _rhmRepository = null; // <-- THIS LINE IS REMOVED
    
    _doneDatesSubscription?.cancel(); // Stop listening to the old user's data
    _calendarValidationTimer?.cancel();
    _doneDates = [];
    _isLoading = false;
    _error = null;
    _isInitialized = false;
    // print("DoneDatesProvider cleared.");
    // notifyListeners();
  }

  /// Initialize the repository with coupleId
  void initializeRepository(String coupleId) {
    // Prevent re-creating the repository if it's already for the correct couple
    if (_repository?.coupleId == coupleId) return;
    _repository = DoneDatesRepository(coupleId: coupleId);
    // When repository changes, we are no longer initialized with its data
    _isInitialized = false; 
    
    // ✨ [ADD] We also need to ensure the RHM repo is available.
    // The RhmRepository itself doesn't need the coupleId, 
    // but we need to ensure it's not null.
    if (_rhmRepository == null) {
      // print("Error: RhmRepository is null in DoneDatesProvider. It must be provided via constructor.");
      // This is a safeguard. It should be provided by the MultiProvider.
    }
  }

  /// Check if repository is initialized
  bool get isRepositoryInitialized => _repository != null;

  /// Initialize the provider and start listening to done dates
  Future<void> initialize() async {
    if (_isInitialized || _repository == null) return;
    if (_isLoading) return; 
    
    _isLoading = true;
    notifyListeners();

    final completer = Completer<void>();

    try {
      await _doneDatesSubscription?.cancel();

      _doneDatesSubscription = _repository!.getDoneDatesStream().listen(
        (dates) {
          // ✨ --- [GUARD 1: ON-DATA] --- ✨
          if (FirebaseAuth.instance.currentUser == null) {
            debugPrint("[DoneDatesProvider] Event received, but user is logged out. Ignoring.");
            return;
          }

          _doneDates = dates;
          _isLoading = false;
          _error = null;
          _isInitialized = true;
          notifyListeners();
          if (!completer.isCompleted) {
            completer.complete();
          }
        },
        onError: (error) {
          // ✨ --- [GUARD 2: ON-ERROR] --- ✨
          if (error is FirebaseException && error.code == 'permission-denied') {
            if (FirebaseAuth.instance.currentUser == null) {
              debugPrint("[DoneDatesProvider] Safely caught permission-denied on listener during logout.");
            } else {
              debugPrint("[DoneDatesProvider] CRITICAL PERMISSION ERROR: $error");
              _error = error.toString();
            }
          } else {
            debugPrint("[DoneDatesProvider] Unexpected error: $error");
            _error = error.toString();
          }

          _isLoading = false;
          _isInitialized = false; // Failed to initialize
          notifyListeners();
          if (!completer.isCompleted) {
            completer.completeError(error);
          }
        },
      );
      
      _startCalendarValidationTimer();
      await completer.future;

    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      _isInitialized = false;
      notifyListeners();
      if (!completer.isCompleted) {
        completer.completeError(e);
      }
    }
  }



  /// Safely gets the count of done dates, initializing the provider if needed.
  Future<int> getDoneDatesCount(String coupleId) async {
    // ... (unchanged)
    if (!_isInitialized || _repository?.coupleId != coupleId) {
      initializeRepository(coupleId);
      await initialize();
    }
    return doneDates.length;
  }
  
  // ... (dispose method is unchanged)
  
  @override
  void dispose() {
    clear();
    super.dispose();
  }

  /// Add a completed date from suggestion
  // ✨ [MODIFY] This method
 Future<void> addDoneDateFromSuggestion({
    required String dateIdeaId,
    required String title,
    required String description,
    required String suggestionId,
    required String completedBy,
    DateTime? actualDate,
    String? notes,
    int? rating,
  }) async {
    if (_repository == null || _rhmRepository == null) {
      _error = 'Repository not initialized';
      notifyListeners();
      throw Exception(_error);
    }
    
    try {
      // --- ✨ DEBUG LOGS ---
      final String userId = completedBy;
      const String actionType = 'date_night_completed';
      final String coupleId = _repository!.coupleId;

      debugPrint("[Freq Check] Checking for: userId=$userId, actionType=$actionType, coupleId=$coupleId");
      
      final lastActionTime = await _rhmRepository!.getLastActionTimestampForUser(
        coupleId,
        userId,
        actionType,
      );
      
      debugPrint("[Freq Check] Found lastActionTime: $lastActionTime");
      // --- END DEBUG LOGS ---

      if (lastActionTime != null) {
        final durationSinceLast = DateTime.now().difference(lastActionTime);
        debugPrint("[Freq Check] Time since last: $durationSinceLast");
        if (durationSinceLast < const Duration(days: 3)) {
          debugPrint("[Freq Check] FAILED: Too soon.");
          throw Exception('You can only log a completed date once every 3 days.');
        }
      }
      debugPrint("[Freq Check] PASSED: Proceeding to log action.");

      // 1. Original call
      await _repository!.addDoneDate(
        dateIdeaId: dateIdeaId,
        title: title,
        description: description,
        source: 'suggestion',
        sourceId: suggestionId,
        completedBy: completedBy,
        actualDate: actualDate ?? DateTime.now(),
        notes: notes,
        rating: rating,
      );
      _dynamicActionsProvider.recordDateDone();

      // 2. Log to Firestore
      await _rhmRepository!.logAction(
        coupleId: _repository!.coupleId,
        userId: completedBy,
        actionType: actionType,
        points: 5,
        sourceId: suggestionId,
      );
      debugPrint("[Freq Check] Logged action successfully.");
      
    } catch (e) {
      debugPrint("[Freq Check] Error during addDoneDateFromSuggestion: $e");
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// Add a completed date from calendar event
  Future<void> addDoneDateFromCalendar({
    required String dateIdeaId,
    required String title,
    required String description,
    required String eventId,
    required String completedBy,
    required DateTime eventDate,
    String? notes,
    int? rating,
  }) async {
    if (_repository == null || _rhmRepository == null) {
      _error = 'Repository not initialized';
      notifyListeners();
      throw Exception(_error);
    }
    
    try {
      // --- ✨ DEBUG LOGS ---
      final String userId = completedBy;
      const String actionType = 'date_night_completed';
      final String coupleId = _repository!.coupleId;

      debugPrint("[Freq Check] Checking for: userId=$userId, actionType=$actionType, coupleId=$coupleId");
      
      final lastActionTime = await _rhmRepository!.getLastActionTimestampForUser(
        coupleId,
        userId,
        actionType,
      );
      
      debugPrint("[Freq Check] Found lastActionTime: $lastActionTime");
      // --- END DEBUG LOGS ---
      
      if (lastActionTime != null) {
        final durationSinceLast = DateTime.now().difference(lastActionTime);
        debugPrint("[Freq Check] Time since last: $durationSinceLast");
        if (durationSinceLast < const Duration(days: 3)) {
          debugPrint("[Freq Check] FAILED: Too soon.");
          throw Exception('Frequency limit (3 days) reached for date_night_completed.');
        }
      }
      debugPrint("[Freq Check] PASSED: Proceeding to log action.");


      // 1. Original call
      await _repository!.addDoneDate(
        dateIdeaId: dateIdeaId,
        title: title,
        description: description,
        source: 'calendar',
        sourceId: eventId,
        completedBy: completedBy,
        actualDate: eventDate,
        notes: notes,
        rating: rating,
      );
      _dynamicActionsProvider.recordDateDone();

      // 2. Log to Firestore
      await _rhmRepository!.logAction(
        coupleId: _repository!.coupleId,
        userId: completedBy,
        actionType: actionType,
        points: 5,
        sourceId: eventId,
      );
      debugPrint("[Freq Check] Logged action successfully.");

    } catch (e) {
      debugPrint("[Freq Check] Error during addDoneDateFromCalendar: $e");
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// Add a completed date from bucket list
  Future<void> addDoneDateFromBucketList({
    required String dateIdeaId,
    required String title,
    required String description,
    required String bucketListItemId,
    required String completedBy,
    DateTime? actualDate,
    String? notes,
    int? rating,
  }) async {
    // (This method has no RHM logic, so it is unchanged)
    if (_repository == null || _rhmRepository == null) {
      _error = 'Repository not initialized';
      notifyListeners();
      throw Exception(_error);
    }
    
    try {
      await _repository!.addDoneDate(
        dateIdeaId: dateIdeaId,
        title: title,
        description: description,
        source: 'bucket_list',
        sourceId: bucketListItemId,
        completedBy: completedBy,
        actualDate: actualDate ?? DateTime.now(),
        notes: notes,
        rating: rating,
      );
      _dynamicActionsProvider.recordDateDone();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// Update a done date (add notes, rating, photos)
  Future<void> updateDoneDate(String doneDateId, Map<String, dynamic> updates) async {
    // ... (unchanged)
    if (_repository == null) {
      _error = 'Repository not initialized';
      notifyListeners();
      return;
    }
    
    try {
      await _repository!.updateDoneDate(doneDateId, updates);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// Delete a done date
  Future<void> deleteDoneDate(String doneDateId) async {
    // ... (unchanged)
    if (_repository == null) {
      _error = 'Repository not initialized';
      notifyListeners();
      return;
    }
    
    try {
      await _repository!.deleteDoneDate(doneDateId);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// Check if a date idea has been completed
  Future<bool> isDateIdeaCompleted(String dateIdeaId) async {
    // ... (unchanged)
    if (_repository == null) {
      return false;
    }
    
    try {
      return await _repository!.isDateIdeaCompleted(dateIdeaId);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Get done dates by source
  List<Map<String, dynamic>> getDoneDatesBySource(String source) {
    // ... (unchanged)
    return _doneDates.where((date) => date['source'] == source).toList();
  }

  /// Get done dates statistics
  Future<Map<String, dynamic>> getStats() async {
    // ... (unchanged)
    if (_repository == null) {
      return {};
    }
    
    try {
      return await _repository!.getDoneDatesStats();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return {};
    }
  }
  
  // ... (All timer and validation methods are unchanged) ...
  /// Start timer to validate calendar events that have passed
  void _startCalendarValidationTimer() {
    // Check every hour for passed calendar events
    _calendarValidationTimer?.cancel(); // Cancel previous timer
    _calendarValidationTimer = Timer.periodic(const Duration(hours: 1), (timer) {
      _validatePassedCalendarEvents();
    });
  }

  /// Validate calendar events that have passed their date
  Future<void> _validatePassedCalendarEvents() async {
    try {
      final now = DateTime.now();
      final yesterday = now.subtract(const Duration(days: 1));
      
      // Get all calendar events
      if (_repository == null) return;
      final eventsSnapshot = await _calendarRepository.getEvents(_repository!.coupleId).first;
      
      for (final eventDoc in eventsSnapshot.docs) {
        final eventData = eventDoc.data();
        final eventDate = (eventData['startDate'] as Timestamp).toDate();
        
        // Check if event has passed (yesterday or earlier) and hasn't been marked as done
        if (eventDate.isBefore(now) && eventDate.isAfter(yesterday)) {
          final eventId = eventDoc.id;
          final isAlreadyDone = _doneDates.any((doneDate) => 
            doneDate['source'] == 'calendar' && doneDate['sourceId'] == eventId
          );
          
          if (!isAlreadyDone) {
            // Only add to done dates if it's a date idea
            final isDateIdea = eventData['isDateIdea'] == true;
            
            if (isDateIdea) {
              // print('Date idea calendar event passed: ${eventData['title']} on $eventDate - Adding to done dates');
              
              // Automatically add to done dates
              try {
                await addDoneDateFromCalendar(
                  dateIdeaId: eventData['dateIdeaId'] ?? '', // If it was added from a date idea
                  title: eventData['title'] ?? '',
                  description: eventData['description'] ?? '',
                  eventId: eventId,
                  completedBy: eventData['createdBy'] ?? 'both',
                  eventDate: eventDate,
                );
              } catch (e) {
                // Catch the frequency limit error so the timer loop doesn't break
                debugPrint('Failed to auto-add calendar date (likely frequency limit): $e');
              }
            } else {
              // print('Regular calendar event passed: ${eventData['title']} on $eventDate - Not adding to done dates');
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error validating passed calendar events: $e');
    }
  }

  /// Manual validation of passed calendar events (can be called from UI)
  Future<void> validatePassedCalendarEvents() async {
    await _validatePassedCalendarEvents();
  }

  /// Force validation of all calendar events (for testing)
  Future<void> forceValidateAllCalendarEvents() async {
    try {
      final now = DateTime.now();
      
      // Get all calendar events
      if (_repository == null) return;
      final eventsSnapshot = await _calendarRepository.getEvents(_repository!.coupleId).first;
      
      for (final eventDoc in eventsSnapshot.docs) {
        final eventData = eventDoc.data();
        final eventDate = (eventData['startDate'] as Timestamp).toDate();
        
        // Check if event has passed and hasn't been marked as done
        if (eventDate.isBefore(now)) {
          final eventId = eventDoc.id;
          final isAlreadyDone = _doneDates.any((doneDate) => 
            doneDate['source'] == 'calendar' && doneDate['sourceId'] == eventId
          );
          
          if (!isAlreadyDone) {
            // Only add to done dates if it's a date idea
            final isDateIdea = eventData['isDateIdea'] == true;
            
            if (isDateIdea) {
              // print('Adding passed date idea calendar event to done dates: ${eventData['title']} on $eventDate');
              
              // Automatically add to done dates
              try {
                await addDoneDateFromCalendar(
                  dateIdeaId: eventData['dateIdeaId'] ?? '',
                  title: eventData['title'] ?? '',
                  description: eventData['description'] ?? '',
                  eventId: eventId,
                  completedBy: eventData['createdBy'] ?? 'both',
                  eventDate: eventDate,
                );
              } catch (e) {
                // Catch the frequency limit error so the loop doesn't break
                debugPrint('Failed to force-add calendar date (likely frequency limit): $e');
              }
            } else {
              // print('Skipping regular calendar event: ${eventData['title']} on $eventDate - Not a date idea');
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error force validating calendar events: $e');
    }
  }

  /// Check if validation timer is running
  bool get isValidationTimerRunning => _calendarValidationTimer != null && _calendarValidationTimer!.isActive;

  /// Get recent done dates (last 30 days)
  List<Map<String, dynamic>> getRecentDoneDates() {
    final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
    return _doneDates.where((date) {
      final actualDate = date['actualDate'] as DateTime?;
      return actualDate != null && actualDate.isAfter(thirtyDaysAgo);
    }).toList();
  }

  /// Get done dates for a specific month
  List<Map<String, dynamic>> getDoneDatesForMonth(int year, int month) {
    return _doneDates.where((date) {
      final actualDate = date['actualDate'] as DateTime?;
      return actualDate != null && 
               actualDate.year == year && 
               actualDate.month == month;
    }).toList();
  }

}