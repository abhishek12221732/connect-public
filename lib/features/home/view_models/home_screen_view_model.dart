// lib/features/home/view_models/home_screen_view_model.dart

import 'dart:async'; // ✨ [ADD] Import async for StreamSubscription
import 'package:flutter/material.dart';
import 'package:feelings/providers/user_provider.dart';
import 'package:feelings/providers/calendar_provider.dart';
import 'package:feelings/providers/bucket_list_provider.dart';
import 'package:feelings/providers/date_idea_provider.dart';
import 'package:feelings/providers/tips_provider.dart';
import 'package:feelings/providers/question_provider.dart';
import 'package:feelings/providers/journal_provider.dart';
import 'package:feelings/providers/done_dates_provider.dart';
// ✨ [ADD] Import the RHM repository
import 'package:feelings/features/rhm/repository/rhm_repository.dart'; 
import 'package:feelings/features/questions/models/question_model.dart';
import 'package:feelings/features/calendar/models/calendar_event.dart';
import 'package:feelings/features/date_night/models/date_idea.dart';
import 'package:feelings/features/check_in/models/check_in_model.dart';
import 'package:feelings/providers/check_in_provider.dart';
// Crashlytics logging removed from home screen view model per request.

// A simple data class to hold the stats for the UI.
class HomeScreenStats {
  // ... (unchanged)
  final int journalCount;
  final int bucketListCount;
  final int questionCount;
  final int doneDatesCount;

  HomeScreenStats({
    this.journalCount = 0,
    this.bucketListCount = 0,
    this.questionCount = 0,
    this.doneDatesCount = 0,
  });
}

// Enum to manage the screen's state clearly.
enum HomeScreenStatus { loading, loaded, error }

class HomeScreenViewModel extends ChangeNotifier {
  // --- DEPENDENCIES ---
  final UserProvider _userProvider;
  final QuestionProvider _questionProvider;
  final CalendarProvider _calendarProvider;
  final JournalProvider _journalProvider;
  final BucketListProvider _bucketListProvider;
  final DoneDatesProvider _doneDatesProvider;
  final DateIdeaProvider _dateIdeaProvider;
  final TipsProvider _tipsProvider;
  final CheckInProvider _checkInProvider;
  // ✨ [ADD] Add the RhmRepository
  final RhmRepository _rhmRepository; 
  bool _isDisposed = false;

  // --- STATE ---
  HomeScreenStatus _status = HomeScreenStatus.loading;
  HomeScreenStatus get status => _status;

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  QuestionModel? _dailyQuestion;
  QuestionModel? get dailyQuestion => _dailyQuestion;

  List<CalendarEvent> _upcomingEvents = [];
  List<CalendarEvent> get upcomingEvents => _upcomingEvents;

  HomeScreenStats _stats = HomeScreenStats();
  HomeScreenStats get stats => _stats;

  String _errorMessage = '';
  String get errorMessage => _errorMessage;

  CheckInModel? _partnerInsight;
  CheckInModel? get partnerInsight => _partnerInsight;

  List<Map<String, dynamic>> _dateSuggestions = [];
  List<Map<String, dynamic>> get dateSuggestions => _dateSuggestions;

  // ✨ [ADD] State for RHM
  int _rhmScore = 50; // Default to 50
  int get rhmScore => _rhmScore;
  StreamSubscription? _rhmSubscription;

  // --- CONSTRUCTOR ---
  // ✨ [MODIFY] Update the constructor
  HomeScreenViewModel({
    required UserProvider userProvider,
    required QuestionProvider questionProvider,
    required CalendarProvider calendarProvider,
    required JournalProvider journalProvider,
    required BucketListProvider bucketListProvider,
    required DoneDatesProvider doneDatesProvider,
    required DateIdeaProvider dateIdeaProvider,
    required TipsProvider tipsProvider,
    required CheckInProvider checkInProvider,
    required RhmRepository rhmRepository, // ✨ [ADD] Require it here
  })  : _userProvider = userProvider,
        _questionProvider = questionProvider,
        _calendarProvider = calendarProvider,
        _journalProvider = journalProvider,
        _bucketListProvider = bucketListProvider,
        _doneDatesProvider = doneDatesProvider,
        _dateIdeaProvider = dateIdeaProvider,
        _tipsProvider = tipsProvider,
        _checkInProvider = checkInProvider,
        _rhmRepository = rhmRepository { // ✨ [ADD] Initialize it
    _dateIdeaProvider.addListener(_onDateIdeaProviderUpdate);
    _checkInProvider.addListener(_onCheckInProviderUpdate);
    _journalProvider.addListener(_onDataChanged);
    _bucketListProvider.addListener(_onDataChanged);
    _questionProvider.addListener(_onDataChanged);
    _doneDatesProvider.addListener(_onDataChanged);
    _calendarProvider.addListener(_onDataChanged);
  }

  void _onDataChanged() {
    if (_isDisposed) return;
    // ... (unchanged)
    // print("🔄 HomeScreenViewModel detected a change, refreshing data...");
    // Re-fetch only the data that needs updating
    final userId = _userProvider.getUserId();
    final coupleId = _userProvider.coupleId;

    if (userId != null && coupleId != null) {
      // Re-calculate stats
      _loadStats(userId, coupleId); 
      // Re-fetch upcoming events
      _upcomingEvents = _calendarProvider.getUpcomingEvents(limit: 3);
      // Update any other data that might have changed
      _dateSuggestions = _dateIdeaProvider.suggestions;
      
      // Tell the UI to rebuild with the new data
     if (!_isDisposed) notifyListeners();
    }
  }

  void _onDateIdeaProviderUpdate() {
    // ... (unchanged)
    if (_isDisposed) return;
    _dateSuggestions = _dateIdeaProvider.suggestions;
    notifyListeners();
  }

  void _onCheckInProviderUpdate() {
    // ... (unchanged)
    if (_isDisposed) return;
    _partnerInsight = _checkInProvider.latestPartnerInsight;
    notifyListeners();
  }

  // --- LOGIC ---
  // ✨ [MODIFY] Update the initialize method
  Future<void> initialize() async {
    try {

      // ... (unchanged)
      if (!_isInitialized) {
        _status = HomeScreenStatus.loading;
        notifyListeners();
      }

      final userId = _userProvider.getUserId();
      final coupleId = _userProvider.coupleId;
      final partnerId = _userProvider.partnerData?['userId'];

      if (userId == null) {
        throw Exception("User is not logged in.");
      }
      
      final dataFutures = <Future<void>>[];
      
      dataFutures.add(_questionProvider.fetchDailyQuestion(userId));

      if (coupleId != null) {
        // ... (unchanged listeners)
        _calendarProvider.listenToEvents(coupleId);
        _dateIdeaProvider.listenToSuggestions(coupleId);
        
        if (partnerId != null) {
          _checkInProvider.listenToLatestPartnerInsight(userId, partnerId);
        }

        // ✨ [ADD] Start listening to the RHM score
        _rhmSubscription?.cancel(); // Cancel any old subscription
        _rhmSubscription?.cancel(); // Cancel any old subscription
        _rhmSubscription = _rhmRepository.getRhmScoreStream(coupleId).listen(
      (score) {
        _rhmScore = score;
        if (!_isDisposed) notifyListeners(); // ✨ ADD THIS CHECK
      },
      onError: (e, stack) {
        print("Error in RHM score stream: $e");
        _rhmScore = 50; 
        if (!_isDisposed) notifyListeners(); // ✨ ADD THIS CHECK
      }
    );

        dataFutures.add(_tipsProvider.initialize(
          userId: userId,
          coupleId: coupleId,
          userData: _userProvider.userData!,
          partnerData: _userProvider.partnerData,
        ));
        
        _loadStats(userId, coupleId);

      }
      
      await Future.wait(dataFutures);
      
      _dailyQuestion = _questionProvider.dailyQuestion;
      _upcomingEvents = _calendarProvider.getUpcomingEvents(limit: 3);
      _partnerInsight = _checkInProvider.latestPartnerInsight;
      _dateSuggestions = _dateIdeaProvider.suggestions;

      _status = HomeScreenStatus.loaded;
      _isInitialized = true; 

    } catch (e) {
      _errorMessage = "Failed to load home screen: ${e.toString()}";
      _status = HomeScreenStatus.error;
      // Initialization error handling — log locally
      print('HomeScreenViewModel.initialize failed: $e');
    } finally {
      if (!_isDisposed) { // ✨ ADD THIS CHECK
      notifyListeners();
    }
    }
  }

  @override
  void dispose() {
    // ... (unchanged listener removals)
    _isDisposed = true;
    _dateIdeaProvider.removeListener(_onDateIdeaProviderUpdate);
    _checkInProvider.removeListener(_onCheckInProviderUpdate);
    _journalProvider.removeListener(_onDataChanged);
    _bucketListProvider.removeListener(_onDataChanged);
    _questionProvider.removeListener(_onDataChanged);
    _doneDatesProvider.removeListener(_onDataChanged);
    _calendarProvider.removeListener(_onDataChanged);
    // ✨ [ADD] Cancel the RHM subscription
    _rhmSubscription?.cancel(); 
    super.dispose();
  }

  Future<void> _loadStats(String userId, String coupleId) async {
    // ... (unchanged)
    // ✨ [MODIFY] Updated BucketListProvider call
    final results = await Future.wait([
      _journalProvider.getTotalPersonalJournals(userId),
      _bucketListProvider.getUncheckedCount(), // Removed params
      _questionProvider.countDoneQuestions(userId),
      _doneDatesProvider.getDoneDatesCount(coupleId),
    ]);

    _stats = HomeScreenStats(
      journalCount: results[0],
      bucketListCount: results[1],
      questionCount: results[2],
      doneDatesCount: results[3],
    );
    
    if (!_isDisposed) notifyListeners();
  }
}