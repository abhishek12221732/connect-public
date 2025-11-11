// lib/providers/calendar_provider.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:feelings/features/calendar/models/calendar_event.dart';
import 'package:feelings/features/calendar/repository/calendar_repository.dart';
import 'package:feelings/features/rhm/repository/rhm_repository.dart';
import 'package:feelings/features/calendar/services/reminder_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:feelings/features/calendar/models/milestone.dart';
// import 'package:collection/collection.dart'; // Make sure this is uncommented if used
import 'dynamic_actions_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CalendarProvider with ChangeNotifier {
  // ... (Properties _dynamicActionsProvider, _calendarRepository, _reminderService, _rhmRepository, subscriptions, lists, state variables are unchanged) ...
  final DynamicActionsProvider _dynamicActionsProvider;
  final CalendarRepository _calendarRepository;
  final ReminderService _reminderService;
  final RhmRepository _rhmRepository;

  StreamSubscription? _eventsSubscription;
  StreamSubscription? _milestonesSubscription;

  List<CalendarEvent> _events = [];
  List<Milestone> _milestones = [];
  String? _milestoneError;
  bool _milestonesLoading = false;
  String? _currentUserId;

  // ... (Getters events, allEvents, milestones, milestoneError, milestonesLoading are unchanged) ...
  List<CalendarEvent> get events {
    return _expandRecurringEvents(_filterPersonalEvents(_events));
  }

  List<CalendarEvent> get allEvents {
    return _expandRecurringEvents(_events);
  }

  List<Milestone> get milestones => _milestones;
  String? get milestoneError => _milestoneError;
  bool get milestonesLoading => _milestonesLoading;


  // Constructor (already updated)
  CalendarProvider(this._dynamicActionsProvider, {
    required CalendarRepository calendarRepository, // Now required
    ReminderService? reminderService,
    required RhmRepository rhmRepository,
  }) : _calendarRepository = calendarRepository,
       _reminderService = reminderService ?? ReminderService(),
       _rhmRepository = rhmRepository;

  // ... (clear, dispose, setCurrentUserId, _filterPersonalEvents, listenToEvents, listenToMilestones methods are unchanged) ...
    void clear() {
    _eventsSubscription?.cancel();
    _milestonesSubscription?.cancel();
    _events = [];
    _milestones = [];
    _milestoneError = null;
    _milestonesLoading = false;
    _currentUserId = null;
    // notifyListeners();
    debugPrint("[CalendarProvider] Cleared and reset state.");
  }

  @override
  void dispose() {
    clear();
    super.dispose();
  }

  void setCurrentUserId(String userId) {
    _currentUserId = userId;
    notifyListeners();
  }

  List<CalendarEvent> _filterPersonalEvents(List<CalendarEvent> events) {
    if (_currentUserId == null) return events;

    return events.where((event) {
      if (event.isPersonal == true) {
        return event.personalUserId == _currentUserId;
      }
      return true;
    }).toList();
  }

  void listenToEvents(String coupleId) {
    _eventsSubscription?.cancel();
    _eventsSubscription = _calendarRepository.getEvents(coupleId).listen(
      (snapshot) {
        // ✨ --- [GUARD 1: ON-DATA] --- ✨
        if (FirebaseAuth.instance.currentUser == null) {
          debugPrint("[CalendarProvider] Event received, but user is logged out. Ignoring.");
          return;
        }

        _events = snapshot.docs.map((doc) {
          return CalendarEvent.fromMap(doc.data(), doc.id);
        }).toList();
        notifyListeners();
      },
      onError: (error) {
        // ✨ --- [GUARD 2: ON-ERROR] --- ✨
        if (error is FirebaseException && error.code == 'permission-denied') {
          if (FirebaseAuth.instance.currentUser == null) {
            debugPrint("[CalendarProvider] Safely caught permission-denied on events listener during logout.");
          } else {
            debugPrint("[CalendarProvider] CRITICAL EVENT PERMISSION ERROR: $error");
          }
        } else {
          debugPrint("[CalendarProvider] Unexpected event error: $error");
        }
      },
    );
  }

  void listenToMilestones(String coupleId) {
    _milestonesLoading = true;
    _milestoneError = null;
    notifyListeners();

    _milestonesSubscription?.cancel();
    _milestonesSubscription = _calendarRepository.getMilestones(coupleId).listen(
      (snapshot) {
        // ✨ --- [GUARD 1: ON-DATA] --- ✨
        if (FirebaseAuth.instance.currentUser == null) {
          debugPrint("[CalendarProvider] Milestone event received, but user is logged out. Ignoring.");
          return;
        }

        _milestones = snapshot.docs.map((doc) {
          return Milestone.fromMap(doc.data(), doc.id);
        }).toList();
        _milestonesLoading = false;
        _milestoneError = null;
        notifyListeners();
      },
      onError: (error) {
        // ✨ --- [GUARD 2: ON-ERROR] --- ✨
        if (error is FirebaseException && error.code == 'permission-denied') {
          if (FirebaseAuth.instance.currentUser == null) {
            debugPrint("[CalendarProvider] Safely caught permission-denied on milestone listener during logout.");
          } else {
            debugPrint("[CalendarProvider] CRITICAL MILESTONE PERMISSION ERROR: $error");
            _milestoneError = error.toString();
          }
        } else {
          debugPrint("[CalendarProvider] Unexpected milestone error: $error");
          _milestoneError = error.toString();
        }
        _milestonesLoading = false;
        notifyListeners();
      },
    );
  }



  // ✨ [MODIFY] Update addEvent
  Future<String> addEvent(String coupleId, Map<String, dynamic> eventData) async {
    int notificationId = DateTime.now().millisecondsSinceEpoch.remainder(100000);
    eventData['notificationId'] = notificationId;

    // 1. Original call
    final docRef = await _calendarRepository.addEvent(coupleId, eventData);
    _dynamicActionsProvider.recordEventAdded();

    // ✨ [ADD] RHM Frequency Check and Logging Logic for regular events
    // We only add points for *shared* events, not personal ones.
    final bool isPersonalEvent = eventData['isPersonal'] ?? false;
    if (!isPersonalEvent) {
      const String actionType = 'calendar_event_added';
      const Duration frequencyLimit = Duration(days: 1); // Once per day

      try {
        final lastActionTime = await _rhmRepository.getLastActionTimestamp(coupleId, actionType);
        final now = DateTime.now();

        if (lastActionTime == null || now.difference(lastActionTime) >= frequencyLimit) {
           final String userId = eventData['createdBy'] as String? ?? ''; // Get creator ID
           if (userId.isNotEmpty) {
             await _rhmRepository.logAction(
               coupleId: coupleId,
               userId: userId, // User who created the event
               actionType: actionType,
               points: 1, // +1 point for adding a shared event
               sourceId: docRef.id,
             );
             debugPrint("[CalendarProvider] Logged +1 RHM for $actionType");
           } else {
             debugPrint("[CalendarProvider] Skipped RHM logging for $actionType (createdBy missing)");
           }
        } else {
          final timeRemaining = frequencyLimit - now.difference(lastActionTime);
          debugPrint("[CalendarProvider] Skipped RHM logging for $actionType (limit not met, ${timeRemaining.inHours}h remaining)");
        }
      } catch (e) {
        debugPrint("[CalendarProvider] Error checking/logging RHM action for event: $e");
      }
    } else {
      debugPrint("[CalendarProvider] Skipped RHM logging for event (personal event)");
    }


    // 3. Original reminder logic
    if (eventData['reminderTime'] != null) {
      DateTime scheduledDate = (eventData['reminderTime'] as Timestamp).toDate();
      if (scheduledDate.isAfter(DateTime.now())) {
        await _reminderService.scheduleNotification(
          id: notificationId,
          title: eventData['title'],
          body: eventData['description'] ?? 'You have an upcoming event!',
          scheduledDate: scheduledDate,
        );
      } else {
        debugPrint('[CalendarProvider] Reminder time is in the past. Notification not scheduled.');
      }
    }

    return docRef.id;
  }

  // ... (updateEvent, deleteEvent, _extractRealEventId, getUpcomingEvent, countUpcomingEvents, getUpcomingReminders, getUpcomingEvents are unchanged) ...
    Future<void> updateEvent(String coupleId, String eventId, Map<String, dynamic> eventData) async {
    final realEventId = _extractRealEventId(eventId);
    await _calendarRepository.updateEvent(coupleId, realEventId, eventData);
  }

  Future<void> deleteEvent(String coupleId, String eventId) async {
    final realEventId = _extractRealEventId(eventId);

    final eventIndex = _events.indexWhere((e) => e.id == realEventId);
    final CalendarEvent? event = eventIndex != -1 ? _events[eventIndex] : null;

    if (event != null && event.notificationId != null) {
      await _reminderService.cancelNotification(event.notificationId!);
    }

    await _calendarRepository.deleteEvent(coupleId, realEventId);
  }

  String _extractRealEventId(String eventId) {
    final idx = eventId.indexOf('_');
    if (idx > 0 && eventId.length > idx + 1) {
      final possibleDate = eventId.substring(idx + 1);
      if (RegExp(r'^\d{4}-\d{2}-\d{2}T').hasMatch(possibleDate)) {
        return eventId.substring(0, idx);
      }
    }
    return eventId;
  }

  CalendarEvent? getUpcomingEvent() {
    DateTime now = DateTime.now();
    List<CalendarEvent> upcomingEvents =
        events.where((event) => event.startDate.isAfter(now.subtract(const Duration(days: 1)))).toList();

    upcomingEvents.sort((a, b) => a.startDate.compareTo(b.startDate));

    return upcomingEvents.isNotEmpty ? upcomingEvents.first : null;
  }

  Future<int> countUpcomingEvents() async{
    DateTime now = DateTime.now();

    List<CalendarEvent> upcomingEvents = events.where((event) => event.startDate.isAfter(now.subtract(const Duration(days: 1)))).toList();
    return upcomingEvents.length;
  }

  List<CalendarEvent> getUpcomingReminders({int limit = 3}) {
    DateTime now = DateTime.now();

    List<CalendarEvent> upcomingReminders = events.where((event) {
      final reminder = event.reminderTime;
      return reminder != null && reminder.isAfter(now);
    }).toList();

    upcomingReminders.sort((a, b) {
      if (a.reminderTime == null) return 1;
      if (b.reminderTime == null) return -1;
      return a.reminderTime!.compareTo(b.reminderTime!);
    });

    return limit > 0 && upcomingReminders.length > limit
        ? upcomingReminders.sublist(0, limit)
        : upcomingReminders;
  }

  List<CalendarEvent> getUpcomingEvents({int limit = 3}) {
    DateTime now = DateTime.now();

    List<CalendarEvent> upcomingEvents = events.where((event) {
      return event.startDate.isAfter(now.subtract(const Duration(days: 1)));
    }).toList();

    upcomingEvents.sort((a, b) => a.startDate.compareTo(b.startDate));

    return limit > 0 && upcomingEvents.length > limit
        ? upcomingEvents.sublist(0, limit)
        : upcomingEvents;
  }

  // ... (addMilestone method already has RHM logic, no frequency needed) ...
  Future<String> addMilestone(String coupleId, Map<String, dynamic> milestoneData) async {
    try {
      final docRef = await _calendarRepository.addMilestone(coupleId, milestoneData);
      _milestoneError = null;

      try {
        final String userId = milestoneData['createdBy'] as String;
        // No frequency check needed for milestones as points are per unique milestone
        await _rhmRepository.logAction(
          coupleId: coupleId,
          userId: userId,
          actionType: 'milestone_added',
          points: 3, // +3 for adding a new milestone
          sourceId: docRef.id,
        );
         debugPrint("[CalendarProvider] Logged +3 RHM for milestone_added"); // Added print
      } catch (e) {
        debugPrint("[CalendarProvider] Error logging RHM action for milestone: $e");
      }

      final eventData = {
        "title": milestoneData['title'],
        "description": milestoneData['description'] ?? "Celebrating our ${milestoneData['title']?.toLowerCase()}.",
        "startDate": milestoneData['date'],
        "endDate": milestoneData['date'],
        "reminderTime": milestoneData['date'],
        "createdBy": milestoneData['createdBy'],
        "category": milestoneData['type'],
        "location": null,
        "repeat": 'yearly',
        "reminderPreset": 'on_time',
        "isPersonal": false,
        "personalUserId": null,
        "milestoneId": docRef.id,
      };

      await addEvent(coupleId, eventData);

      return docRef.id;
    } catch (e) {
      _milestoneError = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  // ... (updateMilestone, deleteMilestone, _expandRecurringEvents methods are unchanged) ...
    Future<void> updateMilestone(String coupleId, String milestoneId, Map<String, dynamic> milestoneData) async {
    try {
      await _calendarRepository.updateMilestone(coupleId, milestoneId, milestoneData);
      _milestoneError = null;

      // Find event associated with milestone
      final linkedIndex = _events.indexWhere((event) => event.milestoneId == milestoneId);
      final CalendarEvent? linkedEvent = linkedIndex != -1 ? _events[linkedIndex] : null;

      if (linkedEvent != null) {
        final updatedEventData = {
          "title": milestoneData['title'],
          "description": milestoneData['description'] ?? "Celebrating our ${milestoneData['title']?.toLowerCase()}.",
          "startDate": milestoneData['date'],
          "endDate": milestoneData['date'],
          "reminderTime": milestoneData['date'],
          "category": milestoneData['type'],
        };

        await updateEvent(coupleId, linkedEvent.id, updatedEventData);
      }
    } catch (e) {
      _milestoneError = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> deleteMilestone(String coupleId, String milestoneId) async {
    try {
      await _calendarRepository.deleteMilestone(coupleId, milestoneId);
      _milestoneError = null;
    } catch (e) {
      _milestoneError = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  List<CalendarEvent> _expandRecurringEvents(List<CalendarEvent> events, {int daysAhead = 90}) {
     final List<CalendarEvent> expanded = [];
    final now = DateTime.now();
    final endWindow = now.add(Duration(days: daysAhead));
    for (final event in events) {
      if (event.repeat == null || event.repeat == 'none') {
        // Only add non-recurring events if they are upcoming
        if (event.startDate.isAfter(now.subtract(const Duration(days: 1)))) {
           expanded.add(event);
        }
        continue;
      }
      DateTime instanceDate = DateTime(event.startDate.year, event.startDate.month, event.startDate.day, event.startDate.hour, event.startDate.minute);
      // Ensure the first instance is added if it's today or in the future
      if (instanceDate.isAfter(now.subtract(const Duration(days: 1))) && instanceDate.isBefore(endWindow)){
           expanded.add(CalendarEvent(
            id: '${event.id}_${instanceDate.toIso8601String()}', // Unique ID for instance
            title: event.title,
            description: event.description,
            startDate: instanceDate,
            endDate: event.endDate != null ? instanceDate.add(event.endDate!.difference(event.startDate)) : null,
            reminderTime: event.reminderTime != null ? instanceDate.add(event.reminderTime!.difference(event.startDate)) : null,
            createdBy: event.createdBy,
            notificationId: event.notificationId,
            category: event.category,
            location: event.location,
            repeat: event.repeat, // Keep original repeat info if needed, but this instance is singular
            color: event.color,
            reminderPreset: event.reminderPreset,
            isPersonal: event.isPersonal,
            personalUserId: event.personalUserId,
             milestoneId: event.milestoneId // Carry over milestoneId
          ));
      }

      // Calculate next occurrences
      while (instanceDate.isBefore(endWindow)) {
         DateTime nextDate = instanceDate; // Start from current instance date
        switch (event.repeat) {
          case 'daily':
            nextDate = nextDate.add(const Duration(days: 1));
            break;
          case 'weekly':
            nextDate = nextDate.add(const Duration(days: 7));
            break;
          case 'monthly':
             // Handle varying month lengths carefully
            try {
              nextDate = DateTime(nextDate.year, nextDate.month + 1, nextDate.day, nextDate.hour, nextDate.minute);
            } catch (e) { // Handle cases like Jan 31 -> Feb (no 31st) - go to last day of next month
                 nextDate = DateTime(nextDate.year, nextDate.month + 2, 0, nextDate.hour, nextDate.minute); // Day 0 gives last day of previous month
            }
            break;
          case 'yearly':
            try{
               nextDate = DateTime(nextDate.year + 1, nextDate.month, nextDate.day, nextDate.hour, nextDate.minute);
            } catch (e) { // Handle leap year Feb 29
                 if (nextDate.month == 2 && nextDate.day == 29) {
                    nextDate = DateTime(nextDate.year + 1, nextDate.month, 28, nextDate.hour, nextDate.minute);
                 } else {
                    rethrow; // Should not happen for other dates
                 }
            }
            break;
          default:
            nextDate = endWindow.add(const Duration(days: 1)); // Break loop
        }
        instanceDate = nextDate; // Move to the next calculated date

        // Add the next instance if it's within the window and after 'yesterday'
        if (instanceDate.isBefore(endWindow) && instanceDate.isAfter(now.subtract(const Duration(days: 1)))) {
          expanded.add(CalendarEvent(
            id: '${event.id}_${instanceDate.toIso8601String()}',
            title: event.title,
            description: event.description,
            startDate: instanceDate,
            endDate: event.endDate != null ? instanceDate.add(event.endDate!.difference(event.startDate)) : null,
            reminderTime: event.reminderTime != null ? instanceDate.add(event.reminderTime!.difference(event.startDate)) : null,
            createdBy: event.createdBy,
            notificationId: event.notificationId,
            category: event.category,
            location: event.location,
            repeat: event.repeat,
            color: event.color,
            reminderPreset: event.reminderPreset,
            isPersonal: event.isPersonal,
            personalUserId: event.personalUserId,
            milestoneId: event.milestoneId
          ));
        }
      }
    }
    // Sort expanded list by start date
    expanded.sort((a,b) => a.startDate.compareTo(b.startDate));
    return expanded;
  }
}