// lib/providers/check_in_provider.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:feelings/features/check_in/models/check_in_model.dart';
import 'package:feelings/features/check_in/repository/check_in_repository.dart';
// import 'package:feelings/features/journal/repository/journal_repository.dart'; // Keep if used elsewhere
import 'package:feelings/features/rhm/repository/rhm_repository.dart';
import './dynamic_actions_provider.dart';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';

class CheckInProvider with ChangeNotifier {
  final DynamicActionsProvider _dynamicActionsProvider;
  final CheckInRepository _checkInRepository;
  final RhmRepository _rhmRepository;
  StreamSubscription? _partnerInsightSubscription;

  CheckInModel? _currentCheckIn;
  List<CheckInModel> _checkInHistory = [];
  bool _isLoading = false;
  String? _error;

  CheckInModel? _latestPartnerInsight;
  CheckInModel? get latestPartnerInsight => _latestPartnerInsight;

  // Constructor updated previously to require repositories
  CheckInProvider(this._dynamicActionsProvider, {
    required CheckInRepository checkInRepository,
    // ✨ Removed JournalRepository if it's ONLY used by CheckInProvider constructor in main.dart
    // required JournalRepository journalRepository, // Keep if still needed by other methods
    required RhmRepository rhmRepository,
  }) : _checkInRepository = checkInRepository,
       _rhmRepository = rhmRepository;

  // ... (Getters, clear, createCheckIn, fetchLatestPartnerInsight, markInsightAsRead, loadCheckIn are unchanged) ...
  // Getters
  CheckInModel? get currentCheckIn => _currentCheckIn;
  List<CheckInModel> get checkInHistory => _checkInHistory;
  bool get isLoading => _isLoading;
  String? get error => _error;

  CheckInRepository get checkInRepository => _checkInRepository;

  void clear() {
    _partnerInsightSubscription?.cancel();
    _currentCheckIn = null;
    _checkInHistory = [];
    _isLoading = false;
    _error = null;
    _latestPartnerInsight = null;
    // notifyListeners();
     debugPrint("[CheckInProvider] Cleared and reset state."); // Added debugPrint
  }

 Future<String?> createCheckIn(String userId, String coupleId) async {
    try {
      _setLoading(true);
      _clearError();

      final checkInId = await _checkInRepository.createCheckIn(userId, coupleId);

      _currentCheckIn = CheckInModel(
        id: checkInId,
        userId: userId,
        coupleId: coupleId,
        timestamp: DateTime.now(),
        questions: [],
        answers: {},
        isCompleted: false,
      );

      notifyListeners();
      return checkInId;
    } catch (e) {
      _setError('Failed to create check-in: $e');
      return null;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> fetchLatestPartnerInsight(String currentUserId, String partnerId) async {
    try {
      _clearError();
      final insight = await _checkInRepository.getLatestSharedCheckInFromPartner(currentUserId, partnerId);

      _latestPartnerInsight = insight;
      notifyListeners();

    } catch (e) {
       debugPrint('Could not fetch partner insight: $e'); // Added debugPrint
      _latestPartnerInsight = null;
      notifyListeners();
    }
  }

  Future<void> markInsightAsRead(String currentUserId, String checkInId) async {
    try {
      await _checkInRepository.markInsightAsRead(currentUserId, checkInId);
      if (_latestPartnerInsight?.id == checkInId) {
        _latestPartnerInsight = null;
        notifyListeners();
      }
    } catch (e) {
      _setError('Failed to mark insight as read: $e');
    }
  }

  Future<void> loadCheckIn(String userId, String checkInId) async {
    try {
      _setLoading(true);
      _clearError();

      final checkIn = await _checkInRepository.getCheckInById(userId, checkInId);
      if (checkIn != null) {
        _currentCheckIn = checkIn;
        notifyListeners();
      }
    } catch (e) {
      _setError('Failed to load check-in: $e');
    } finally {
      _setLoading(false);
    }
  }


  // ✨ [MODIFY] Update completeCheckIn to check frequency
  Future<void> completeCheckIn(String userId, String checkInId, String coupleId, List<CheckInQuestion> questions, Map<String, dynamic> answers, String? partnerId, {Function(String receiverId, String message)? sendPushNotification}) async {
    try {
      _setLoading(true);
      _clearError();

      // 1. Original call
      await _checkInRepository.completeCheckIn(userId, checkInId, questions, answers);

      // ✨ [ADD] RHM Frequency Check and Logging Logic
      const String actionType = 'check_in_completed';
      const Duration frequencyLimit = Duration(days: 7); // Once per 7 days

      try {
        // --- THIS LINE IS NOW FIXED ---
        // It now checks the last action time for the specific user, not the couple.
        final lastActionTime = await _rhmRepository.getLastActionTimestampForUser(coupleId, userId, actionType);
        final now = DateTime.now();

        // Check if enough time has passed or if it's the first time
        if (lastActionTime == null || now.difference(lastActionTime) >= frequencyLimit) {
          // Determine points based on overall_satisfaction
          int rhmPoints = 5; // Default for just completing
          if (answers.containsKey('overall_satisfaction')) {
            final satisfaction = (answers['overall_satisfaction'] as num).toDouble();
            if (satisfaction >= 8) {
              rhmPoints = 10; // "We're feeling great!"
            } else if (satisfaction >= 5) {
              rhmPoints = 7; // "We're doing good"
            } else {
              rhmPoints = 5; // "We need to talk" (still reward the act)
            }
          }

          // Log the action to the RHM repository
          await _rhmRepository.logAction(
            coupleId: coupleId,
            userId: userId, // User completing the check-in gets the credit initially
            actionType: actionType,
            points: rhmPoints,
            sourceId: checkInId,
          );
          debugPrint("[CheckInProvider] Logged +$rhmPoints RHM for $actionType");
        } else {
          final timeRemaining = frequencyLimit - now.difference(lastActionTime);
          debugPrint("[CheckInProvider] Skipped RHM logging for $actionType (limit not met, ${timeRemaining.inHours}h remaining)");
        }
      } catch (e) {
        debugPrint("[CheckInProvider] Error checking/logging RHM action for check-in: $e");
      }

      // 2. Rest of the original method
      final checkIn = await _checkInRepository.getCheckInById(userId, checkInId);
      if (checkIn != null) {
        final recentHistory = await _checkInRepository.getRecentCompletedCheckIns(userId, limit: 5);
        final userInsights = generateInsights(checkIn, recentHistory: recentHistory, forPartner: false);
        await _checkInRepository.addUserInsights(userId, checkInId, userInsights);
      }

      if (partnerId != null && sendPushNotification != null) {
        await sendPushNotification(partnerId, 'Your partner completed their relationship health check-in!');
      }

      await loadCheckIn(userId, checkInId);
      _dynamicActionsProvider.recordCheckInCompleted();
    } catch (e) {
      _setError('Failed to complete check-in: $e');
    } finally {
      _setLoading(false);
    }
  }

  // ... (shareInsights, setReminder, getStats, getLastCompletedCheckIn, getUserCheckInsStream, clearCurrentCheckIn, generateInsights, shareFullCheckInWithPartner, listenToLatestPartnerInsight, cancelCheckIn, shareSelectedInsights, helper methods _setLoading, _setError, _clearError, dispose are unchanged) ...
    Future<void> shareInsights(String userId, String checkInId, List<String> insights, String coupleId, {String? partnerFirstName}) async {
    try {
      _setLoading(true);
      _clearError();
      final checkIn = await _checkInRepository.getCheckInById(userId, checkInId);
      if (checkIn != null) {
        final recentHistory = await _checkInRepository.getRecentCompletedCheckIns(userId, limit: 5);
        final partnerInsights = generateInsights(
          checkIn,
          recentHistory: recentHistory,
          forPartner: true,
        );
        await _checkInRepository.addSharedInsights(userId, checkInId, partnerInsights);
      } else {
        await _checkInRepository.addSharedInsights(userId, checkInId, insights);
      }
      await loadCheckIn(userId, checkInId);
    } catch (e) {
      _setError('Failed to share insights: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> setReminder(String userId, String checkInId, bool reminderSet) async {
    try {
      _setLoading(true);
      _clearError();

      await _checkInRepository.setReminder(userId, checkInId, reminderSet);

      await loadCheckIn(userId, checkInId);
    } catch (e) {
      _setError('Failed to set reminder: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<Map<String, dynamic>> getStats(String userId) async {
    try {
      _setLoading(true);
      _clearError();

      return await _checkInRepository.getCheckInStats(userId);
    } catch (e) {
      _setError('Failed to get statistics: $e');
      return {};
    } finally {
      _setLoading(false);
    }
  }

  Future<CheckInModel?> getLastCompletedCheckIn(String userId, {String? partnerId}) async {
    try {
      _clearError();
      final all = await _checkInRepository.getRecentCompletedCheckIns(userId, limit: 10);
      final filtered = all.where((c) => c.sharedByUserId == null || (partnerId != null && c.sharedByUserId != partnerId)).toList();
      return filtered.isNotEmpty ? filtered.first : null;
    } catch (e) {
      _setError('Failed to get last completed check-in: $e');
      return null;
    }
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> getUserCheckInsStream(String userId) {
    return _checkInRepository.getUserCheckIns(userId);
  }

  void clearCurrentCheckIn() {
    _currentCheckIn = null;
    notifyListeners();
  }

  List<String> generateInsights(
    CheckInModel checkIn, {
    List<CheckInModel>? recentHistory,
    bool forPartner = false,
    String? userName,
    String? partnerName,
  }) {
    // ... (generateInsights implementation is unchanged)
    final insights = <String>[];
    final answers = checkIn.answers;
    final name = forPartner
        ? ((partnerName != null && partnerName.trim().isNotEmpty) ? partnerName : 'Your partner')
        : 'You';
    final maxInsightsPerMetric = 1;
    final maxTotalInsights = 6;
    final usedMetrics = <String, int>{};

    void addInsight(String metric, String text) {
      if ((usedMetrics[metric] ?? 0) < maxInsightsPerMetric && insights.length < maxTotalInsights) {
        insights.add(text);
        usedMetrics[metric] = (usedMetrics[metric] ?? 0) + 1;
      }
    }

    if (recentHistory != null && recentHistory.isNotEmpty) {
      final sortedHistory = List<CheckInModel>.from(recentHistory)
        ..sort((a, b) => (b.completedAt ?? DateTime(0)).compareTo(a.completedAt ?? DateTime(0)));
      List<double> getMetric(String key) {
        return sortedHistory
            .map((c) => c.answers[key])
            .where((v) => v != null)
            .map((v) => v is int ? v.toDouble() : v as double)
            .toList();
      }
      // List<String?> getStringMetric(String key) {
      //   return sortedHistory.map((c) => c.answers[key] as String?).toList();
      // }

      final satisfaction = getMetric('overall_satisfaction');
      if (satisfaction.length >= 2) {
        final diff = satisfaction[0] - satisfaction[1];
        if (diff > 0.5) {
          addInsight('satisfaction', forPartner
            ? '$name’s satisfaction improved by ${diff.toStringAsFixed(1)} since their last check-in.'
            : 'Your satisfaction improved by ${diff.toStringAsFixed(1)} since your last check-in! Celebrate what worked.');
        } else if (diff < -0.5) {
          addInsight('satisfaction', forPartner
            ? '$name’s satisfaction dropped by ${diff.abs().toStringAsFixed(1)} since their last check-in.'
            : 'Your satisfaction dropped by ${diff.abs().toStringAsFixed(1)} since your last check-in. Consider what changed.');
        }
      }
      if (satisfaction.length >= 3 && satisfaction.every((v) => v >= 8)) {
        addInsight('satisfaction', forPartner
          ? '$name has consistently rated their satisfaction highly.'
          : 'You’ve consistently rated your satisfaction highly—wonderful!');
      } else if (satisfaction.length >= 3 && satisfaction[0] < 7 && satisfaction[1] < 7 && satisfaction[2] < 7) {
        addInsight('satisfaction', forPartner
          ? '$name’s satisfaction has been low for a while.'
          : 'Your satisfaction has been low for a while. Maybe discuss what could help.');
      }
      if (satisfaction.length >= 4 && (satisfaction[0] - satisfaction[3]).abs() > 2) {
        addInsight('satisfaction', forPartner
          ? '$name’s satisfaction has changed a lot recently.'
          : 'Your satisfaction has changed a lot recently. Reflect on what might be causing ups and downs.');
      }

      final stress = getMetric('stress_level');
      if (stress.length >= 2) {
        final diff = stress[0] - stress[1];
        if (diff > 0.5) {
          addInsight('stress', forPartner
            ? '$name’s stress increased by ${diff.toStringAsFixed(1)} since their last check-in.'
            : 'Your stress increased by ${diff.toStringAsFixed(1)} since your last check-in.');
        } else if (diff < -0.5) {
          addInsight('stress', forPartner
            ? '$name’s stress decreased by ${diff.abs().toStringAsFixed(1)} since their last check-in.'
            : 'Your stress decreased by ${diff.abs().toStringAsFixed(1)} since your last check-in.');
        }
      }
      if (stress.length >= 3 && stress.every((v) => v > 7)) {
        addInsight('stress', forPartner
          ? '$name has been feeling high stress for a while.'
          : 'Your stress has been high for a while. Consider some relaxation or self-care together.');
      }
      if (stress.length >= 4 && (stress[0] - stress[3]).abs() > 2) {
        addInsight('stress', forPartner
          ? '$name’s stress levels have been up and down.'
          : 'Your stress levels have been up and down. Try to notice what helps you feel calmer.');
      }

      final connection = getMetric('feeling_connected');
      if (connection.length >= 2) {
        final diff = connection[0] - connection[1];
        if (diff > 0.5) {
          addInsight('connection', forPartner
            ? '$name felt more connected to you than last time.'
            : 'You felt more connected to your partner than last time!');
        } else if (diff < -0.5) {
          addInsight('connection', forPartner
            ? '$name felt less connected to you than last time.'
            : 'You felt less connected to your partner than last time.');
        }
      }
      if (connection.length >= 3 && connection.every((v) => v >= 8)) {
        addInsight('connection', forPartner
          ? '$name has been feeling very connected lately.'
          : 'You’ve been feeling very connected lately—keep nurturing that bond!');
      } else if (connection.length >= 3 && connection[0] < 7 && connection[1] < 7 && connection[2] < 7) {
        addInsight('connection', forPartner
          ? '$name has been feeling less connected for a while.'
          : 'You have been feeling less connected for a while. Maybe plan some quality time together.');
      }
      if (connection.length >= 4 && (connection[0] - connection[3]).abs() > 2) {
        addInsight('connection', forPartner
          ? '$name’s sense of connection has changed a lot recently.'
          : 'Your sense of connection has changed a lot recently. Reflect on what brings you closer.');
      }

      final communication = getMetric('communication_quality');
      if (communication.length >= 3 && communication.every((v) => v >= 8)) {
        addInsight('communication', forPartner
          ? '$name has been communicating very well lately.'
          : 'Your communication has been excellent lately!');
      } else if (communication.length >= 3 && communication[0] < 6 && communication[1] < 6 && communication[2] < 6) {
        addInsight('communication', forPartner
          ? 'Communication has been tough for $name for a while.'
          : 'Communication has been tough for a while. Maybe try a new way of sharing thoughts.');
      }

      final intimacy = getMetric('physical_intimacy');
      if (intimacy.length >= 3 && intimacy.every((v) => v >= 8)) {
        addInsight('intimacy', forPartner
          ? '$name has been very satisfied with intimacy.'
          : 'You’ve been very satisfied with intimacy—wonderful!');
      } else if (intimacy.length >= 3 && intimacy[0] < 6 && intimacy[1] < 6 && intimacy[2] < 6) {
        addInsight('intimacy', forPartner
          ? 'Intimacy has been low for $name for a while.'
          : 'Intimacy has been low for a while. Consider talking about what you both enjoy.');
      }

      final support = getMetric('emotional_support');
      if (support.length >= 3 && support.every((v) => v >= 8)) {
        addInsight('support', forPartner
          ? '$name has felt very supported emotionally.'
          : 'You’ve felt very supported emotionally—great!');
      } else if (support.length >= 3 && support[0] < 6 && support[1] < 6 && support[2] < 6) {
        addInsight('support', forPartner
          ? '$name has felt less supported lately.'
          : 'You’ve felt less supported lately. Maybe share what would help you feel more cared for.');
      }

      final fun = getMetric('fun_together');
      if (fun.length >= 3 && fun.every((v) => v >= 8)) {
        addInsight('fun', forPartner
          ? '$name has been having lots of fun together.'
          : 'You’ve been having lots of fun together—keep it up!');
      } else if (fun.length >= 3 && fun[0] < 6 && fun[1] < 6 && fun[2] < 6) {
        addInsight('fun', forPartner
          ? 'It’s been a while since $name had fun together.'
          : 'It’s been a while since you had fun together. Maybe try a new activity or date idea.');
      }

      // int gratitudeMissing = 0;
      // for (int i = 0; i < 3 && i < sortedHistory.length; i++) {
      //   final checkIn = sortedHistory[i];
      //   final wasAsked = checkIn.questions.any((q) => q.id == 'gratitude_specific');
      //   final answer = checkIn.answers['gratitude_specific'] as String?;
      //   if (wasAsked && (answer == null || answer.trim().isEmpty)) {
      //     gratitudeMissing++;
      //   }
      // }

      final goals = getMetric('shared_goals');
      if (goals.length >= 3 && goals.every((v) => v >= 8)) {
        addInsight('goals', forPartner
          ? '$name feels very aligned on shared goals.'
          : 'You feel very aligned on your shared goals—amazing!');
      } else if (goals.length >= 3 && goals[0] < 6 && goals[1] < 6 && goals[2] < 6) {
        addInsight('goals', forPartner
          ? '$name has felt less aligned on goals for a while.'
          : 'You’ve felt less aligned on goals for a while. Maybe revisit your shared dreams together.');
      }

      if (satisfaction.isNotEmpty && stress.isNotEmpty && satisfaction[0] >= 8 && stress[0] > 7) {
        addInsight('contrast', forPartner
          ? '$name is satisfied overall, but stress is high—maybe talk about what’s working and what’s challenging.'
          : 'You’re satisfied overall, but stress is high—talk about what’s working and what’s challenging.');
      }
      if (satisfaction.isNotEmpty && fun.isNotEmpty && satisfaction[0] < 7 && fun[0] >= 8) {
        addInsight('contrast', forPartner
          ? '$name is having fun together, but satisfaction is low. Reflect on what might be missing.'
          : 'You’re having fun together, but satisfaction is low. Reflect on what’s missing.');
      }
    }

    if (answers.containsKey('overall_satisfaction')) {
      final satisfaction = answers['overall_satisfaction'] as double;
      addInsight('satisfaction', forPartner
        ? '$name rated their relationship satisfaction as ${satisfaction.toInt()}/10.'
        : 'You rated your relationship satisfaction as ${satisfaction.toInt()}/10. That\'s wonderful! Consider telling your partner what\'s working well.');
    }
    if (answers.containsKey('feeling_connected')) {
      final connection = answers['feeling_connected'] as double;
      if (connection < 7) {
        addInsight('connection', forPartner
          ? '$name felt less connected than usual.'
          : 'You\'re feeling less connected than usual. Consider spending some quality time together or having a heart-to-heart conversation.');
      }
    }
    if (answers.containsKey('appreciation') && answers['appreciation'] != null && answers['appreciation'].toString().isNotEmpty) {
      addInsight('gratitude', forPartner
        ? '$name noted appreciation for: "${answers['appreciation']}".'
        : 'You noted appreciation for: "${answers['appreciation']}". This is beautiful - consider sharing this with your partner!');
    }
    if (answers.containsKey('communication_quality')) {
      final communication = answers['communication_quality'] as double;
      if (communication < 6) {
        addInsight('communication', forPartner
          ? '$name rated communication quality as ${communication.toInt()}/10.'
          : 'Communication quality seems lower than ideal. Maybe try setting aside time for deeper conversations.');
      }
    }
    return insights;
  }

  Future<void> shareFullCheckInWithPartner(String userId, String partnerId, String checkInId) async {
    try {
      final checkIn = await _checkInRepository.getCheckInById(userId, checkInId);
      if (checkIn == null) {
        throw Exception("Check-in not found, cannot share.");
      }

      final recentHistory = await _checkInRepository.getRecentCompletedCheckIns(userId, limit: 5);

      final allPartnerInsights = generateInsights(
        checkIn,
        recentHistory: recentHistory,
        forPartner: true,
      );

      final checkInWithInsights = checkIn.copyWith(
        sharedInsights: allPartnerInsights,
      );

      await _checkInRepository.shareFullCheckInWithPartner(
        partnerId: partnerId,
        checkInToShare: checkInWithInsights,
      );

    } catch (e) {
      _setError('Failed to share full check-in: $e');
      rethrow;
    }
  }

  void listenToLatestPartnerInsight(String currentUserId, String partnerId) {
    _partnerInsightSubscription?.cancel();

    _partnerInsightSubscription = _checkInRepository
        .getLatestSharedCheckInStream(currentUserId, partnerId)
        .listen(
      (insight) {
        // ✨ --- [GUARD 1: ON-DATA] --- ✨
        if (FirebaseAuth.instance.currentUser == null) {
          debugPrint("[CheckInProvider] Insight event received, but user is logged out. Ignoring.");
          return;
        }

        _latestPartnerInsight = insight;
        notifyListeners();
      },
      onError: (error) {
        // ✨ --- [GUARD 2: ON-ERROR] --- ✨
        if (error is FirebaseException && error.code == 'permission-denied') {
          if (FirebaseAuth.instance.currentUser == null) {
            debugPrint("[CheckInProvider] Safely caught permission-denied on insight listener during logout.");
          } else {
            debugPrint("[CheckInProvider] CRITICAL INSIGHT PERMISSION ERROR: $error");
          }
        } else {
          debugPrint("[CheckInProvider] Unexpected insight error: $error");
        }
      },
    );
  }

  Future<void> cancelCheckIn(String userId, String checkInId) async {
    try {
      _setLoading(true);
      _clearError();

      await _checkInRepository.deleteCheckIn(userId, checkInId);

      if (_currentCheckIn?.id == checkInId) {
        _currentCheckIn = null;
      }
    } catch (e) {
      _setError('Failed to cancel check-in: $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> shareSelectedInsights({
    required String userId,
    required String partnerId,
    required String coupleId,
    required List<String> insights,
    required String checkInId,
  }) async {
    try {
      _setLoading(true);
      _clearError();
      await _checkInRepository.shareSelectedInsightsToPartner(
        userId: userId,
        partnerId: partnerId,
        coupleId: coupleId,
        selectedInsights: insights,
        checkInId: checkInId,
      );
    } catch (e) {
      _setError('Failed to share selected insights: $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  // Helper methods
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String error) {
    _error = error;
    notifyListeners();
  }

  void _clearError() {
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    clear(); // This is better for centralization
    super.dispose();
  }
}