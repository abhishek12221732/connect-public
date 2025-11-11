import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:feelings/features/home/models/quick_action_model.dart';
import 'package:feelings/features/journal/screens/journal_screen.dart';
import 'package:feelings/features/chat/screens/chat_screen.dart';
import 'package:feelings/features/calendar/screens/add_event_wizard_screen.dart';
import 'package:feelings/features/questions/screens/questions_screen.dart';
import 'package:feelings/features/check_in/screens/check_in_screen.dart';
import 'package:feelings/features/date_night/screens/date_preference_picker_screen.dart';
import 'package:feelings/features/bucket_list/screens/bucket_list_screen.dart';

// Helper class for sorting actions by priority
class _ScoredAction {
  final QuickAction action;
  final int score;
  _ScoredAction(this.action, this.score);
}

class DynamicActionsProvider with ChangeNotifier {
  late SharedPreferences _prefs;

  // Timestamps for tracking when each action was last performed
  DateTime? _lastPersonalJournalSave;
  DateTime? _lastSharedJournalSave;
  DateTime? _lastMemoryUpload;
  DateTime? _lastMessageSent;
  DateTime? _lastEventAdded;
  DateTime? _lastQuestionAsked;
  DateTime? _lastBucketListItemAdded;
  DateTime? _lastDateDone;
  DateTime? _lastCheckInCompleted;

  DynamicActionsProvider() {
    _loadAllTimestamps();
  }

  // --- Public Methods to Record When an Action is Taken ---

  Future<void> recordPersonalJournalSaved() async {
    _lastPersonalJournalSave = DateTime.now();
    await _saveTimestamp('lastPersonalJournalSave', _lastPersonalJournalSave);
    notifyListeners();
  }
  Future<void> recordSharedJournalSaved() async {
    _lastSharedJournalSave = DateTime.now();
    await _saveTimestamp('lastSharedJournalSave', _lastSharedJournalSave);
    notifyListeners();
  }
  Future<void> recordMemoryUploaded() async {
    _lastMemoryUpload = DateTime.now();
    await _saveTimestamp('lastMemoryUpload', _lastMemoryUpload);
    notifyListeners();
  }
  Future<void> recordMessageSent() async {
    _lastMessageSent = DateTime.now();
    await _saveTimestamp('lastMessageSent', _lastMessageSent);
    notifyListeners();
  }
  Future<void> recordEventAdded() async {
    _lastEventAdded = DateTime.now();
    await _saveTimestamp('lastEventAdded', _lastEventAdded);
    notifyListeners();
  }
  Future<void> recordQuestionAsked() async {
    _lastQuestionAsked = DateTime.now();
    await _saveTimestamp('lastQuestionAsked', _lastQuestionAsked);
    notifyListeners();
  }
  Future<void> recordBucketListItemAdded() async {
    _lastBucketListItemAdded = DateTime.now();
    await _saveTimestamp('lastBucketListItemAdded', _lastBucketListItemAdded);
    notifyListeners();
  }
  Future<void> recordDateDone() async {
    _lastDateDone = DateTime.now();
    await _saveTimestamp('lastDateDone', _lastDateDone);
    notifyListeners();
  }
  Future<void> recordCheckInCompleted() async {
    _lastCheckInCompleted = DateTime.now();
    await _saveTimestamp('lastCheckInCompleted', _lastCheckInCompleted);
    notifyListeners();
  }

  // --- Core Logic to Get the Suggested Actions ---

  /// Returns a sorted and randomized list of the top 3 suggested actions.
  List<QuickAction> getDynamicActions() {
    return _generateAndSortActions();
  }

  /// Calculates a priority score. Actions never taken get the highest score.
  int _getDaysSince(DateTime? timestamp) {
    if (timestamp == null) {
      return 999; 
    }
    return DateTime.now().difference(timestamp).inDays;
  }
  
  /// Defines all possible actions, scores them, sorts them, and returns the top 3.
  List<QuickAction> _generateAndSortActions() {
    final allPossibleActions = [
      _ScoredAction(
        QuickAction(
          id: 'start_checkin',
          label: "Check-in",
          icon: Icons.check_circle,
          actionBuilder: (context) => () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CheckInScreen())),
        ),
        _getDaysSince(_lastCheckInCompleted),
      ),
      _ScoredAction(
        QuickAction(
          id: 'open_chat',
          label: "Chat",
          icon: Icons.chat,
          actionBuilder: (context) => () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ChatScreen())),
        ),
        _getDaysSince(_lastMessageSent),
      ),
      _ScoredAction(
        QuickAction(
          id: 'ask_question',
          label: "Question",
          icon: Icons.question_answer,
          actionBuilder: (context) => () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const QuestionsScreen())),
        ),
        _getDaysSince(_lastQuestionAsked),
      ),
      _ScoredAction(
        QuickAction(
          id: 'add_memory',
          label: "Add Memory",
          icon: Icons.photo_camera,
          actionBuilder: (context) => () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const JournalScreen(showAddMemoryModal: true))),
        ),
        _getDaysSince(_lastMemoryUpload),
      ),
      _ScoredAction(
        QuickAction(
          id: 'plan_date',
          label: "Plan Date",
          icon: Icons.favorite,
          actionBuilder: (context) => () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const DatePreferencePickerScreen())),
        ),
        _getDaysSince(_lastDateDone),
      ),
      _ScoredAction(
        QuickAction(
          id: 'add_bucket_item',
          label: "Bucket List",
          icon: Icons.format_list_bulleted,
          actionBuilder: (context) => () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const BucketListScreen(showAddItemModal: true))),
        ),
        _getDaysSince(_lastBucketListItemAdded),
      ),
       _ScoredAction(
        QuickAction(
          id: 'add_event',
          label: "Add Event",
          icon: Icons.calendar_today,
          actionBuilder: (context) => () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AddEventWizardScreen())),
        ),
        _getDaysSince(_lastEventAdded),
      ),
      _ScoredAction(
        QuickAction(
          id: 'view_personal_journal',
          label: "Personal",
          icon: Icons.book,
          actionBuilder: (context) => () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const JournalScreen(filterToShow: JournalFilterOption.personal))),
        ),
        _getDaysSince(_lastPersonalJournalSave),
      ),
      _ScoredAction(
        QuickAction(
          id: 'view_shared_journal',
          label: "Shared",
          icon: Icons.people,
          actionBuilder: (context) => () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const JournalScreen(filterToShow: JournalFilterOption.shared))),
        ),
        _getDaysSince(_lastSharedJournalSave),
      ),
    ];
    
    // Sort the list so the most "overdue" actions are first.
    allPossibleActions.sort((a, b) => b.score.compareTo(a.score));

    // Take the top 5, shuffle them to keep suggestions fresh, and then pick 3.
    final topActions = allPossibleActions.take(5).toList()..shuffle();
    return topActions.take(3).map((scoredAction) => scoredAction.action).toList();
  }

  // --- Persistence Logic to save and load timestamps ---

  Future<void> _loadAllTimestamps() async {
    _prefs = await SharedPreferences.getInstance();
    _lastPersonalJournalSave = _getTimestamp('lastPersonalJournalSave');
    _lastSharedJournalSave = _getTimestamp('lastSharedJournalSave');
    _lastMemoryUpload = _getTimestamp('lastMemoryUpload');
    _lastMessageSent = _getTimestamp('lastMessageSent');
    _lastEventAdded = _getTimestamp('lastEventAdded');
    _lastQuestionAsked = _getTimestamp('lastQuestionAsked');
    _lastBucketListItemAdded = _getTimestamp('lastBucketListItemAdded');
    _lastDateDone = _getTimestamp('lastDateDone');
    _lastCheckInCompleted = _getTimestamp('lastCheckInCompleted');
    notifyListeners();
  }

  DateTime? _getTimestamp(String key) {
    final value = _prefs.getString(key);
    return value != null ? DateTime.tryParse(value) : null;
  }

  Future<void> _saveTimestamp(String key, DateTime? value) async {
    if (value != null) {
      await _prefs.setString(key, value.toIso8601String());
    }
  }


  // --- Public Method to Clear All Data ---

  /// Clears all saved timestamps from memory and persistent storage.
  ///
  /// This is useful for user logout or data reset functionality.
  Future<void> clear() async {
    // 1. Define all keys that are used for persistence
    final keysToClear = [
      'lastPersonalJournalSave',
      'lastSharedJournalSave',
      'lastMemoryUpload',
      'lastMessageSent',
      'lastEventAdded',
      'lastQuestionAsked',
      'lastBucketListItemAdded',
      'lastDateDone',
      'lastCheckInCompleted',
    ];

    // 2. Clear persistent state (run removals in parallel for efficiency)
    await Future.wait(keysToClear.map((key) => _prefs.remove(key)));

    // 3. Clear in-memory state
    _lastPersonalJournalSave = null;
    _lastSharedJournalSave = null;
    _lastMemoryUpload = null;
    _lastMessageSent = null;
    _lastEventAdded = null;
    _lastQuestionAsked = null;
    _lastBucketListItemAdded = null;
    _lastDateDone = null;
    _lastCheckInCompleted = null;

    // 4. Notify listeners to update the UI
    notifyListeners();
  }
}

