// lib/features/check_in/repository/check_in_repository.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:feelings/features/check_in/models/check_in_model.dart';
import 'dart:math';

class CheckInRepository {
  final FirebaseFirestore _firestore;
  final Random _random = Random();

  CheckInRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  // ... (All existing methods from createCheckIn to notifyPartnerCheckInCompleted are unchanged)
  Future<String> createCheckIn(String userId, String coupleId, {List<CheckInQuestion>? questions}) async {
    try {
      // Generate a unique ID for the check-in session
      final checkInId = _firestore
          .collection('users')
          .doc(userId)
          .collection('check_ins')
          .doc()
          .id;
      
      // Store only the basic metadata, no questions or answers yet
      final checkInData = {
        'userId': userId,
        'coupleId': coupleId,
        'timestamp': FieldValue.serverTimestamp(),
        'isCompleted': false,
        'sharedInsights': [],
        'reminderSet': false,
      };

      await _firestore
          .collection('users')
          .doc(userId)
          .collection('check_ins')
          .doc(checkInId)
          .set(checkInData);

      return checkInId;
    } catch (e) {
      throw Exception('Error creating check-in: $e');
    }
  }

  Future<CheckInModel?> getCheckInById(String userId, String checkInId) async {
    try {
      final doc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('check_ins')
          .doc(checkInId)
          .get();

      if (doc.exists && doc.data() != null) {
        return CheckInModel.fromMap(doc.data()!, doc.id);
      }
      return null;
    } catch (e) {
      throw Exception('Error fetching check-in: $e');
    }
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> getUserCheckIns(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('check_ins')
        .where('isCompleted', isEqualTo: true)
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  Future<void> completeCheckIn(String userId, String checkInId, List<CheckInQuestion> questions, Map<String, dynamic> answers) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('check_ins')
          .doc(checkInId)
          .update({
        'questions': questions.map((q) => q.toMap()).toList(),
        'answers': answers,
        'isCompleted': true,
        'completedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Error completing check-in: $e');
    }
  }

  Future<void> addSharedInsights(String userId, String checkInId, List<String> insights) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('check_ins')
          .doc(checkInId)
          .update({
        'sharedInsights': FieldValue.arrayUnion(insights),
      });
    } catch (e) {
      throw Exception('Error adding shared insights: $e');
    }
  }

  Future<void> addUserInsights(String userId, String checkInId, List<String> insights) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('check_ins')
          .doc(checkInId)
          .update({
        'userInsights': insights,
      });
    } catch (e) {
      throw Exception('Error adding user insights: $e');
    }
  }

  Future<void> setReminder(String userId, String checkInId, bool reminderSet) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('check_ins')
          .doc(checkInId)
          .update({
        'reminderSet': reminderSet,
      });
    } catch (e) {
      throw Exception('Error setting reminder: $e');
    }
  }

  Future<CheckInModel?> getLastCompletedCheckIn(String userId) async {
    try {
      final querySnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('check_ins')
          .where('isCompleted', isEqualTo: true)
          .orderBy('completedAt', descending: true)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final doc = querySnapshot.docs.first;
        return CheckInModel.fromMap(doc.data(), doc.id);
      }
      return null;
    } catch (e) {
      throw Exception('Error fetching last completed check-in: $e');
    }
  }

  Future<List<CheckInModel>> getRecentCompletedCheckIns(String userId, {int limit = 5}) async {
    try {
      final querySnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('check_ins')
          .where('isCompleted', isEqualTo: true)
          .orderBy('completedAt', descending: true)
          .limit(limit)
          .get();
      return querySnapshot.docs
          .map((doc) => CheckInModel.fromMap(doc.data(), doc.id))
          .toList();
    } catch (e) {
      throw Exception('Error fetching recent completed check-ins: $e');
    }
  }

  Future<Map<String, dynamic>> getCheckInStats(String userId) async {
    try {
      final querySnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('check_ins')
          .where('isCompleted', isEqualTo: true)
          .get();

      int completedCheckIns = querySnapshot.docs.length;

      return {
        'totalCheckIns': completedCheckIns,
        'completedCheckIns': completedCheckIns,
        'completionRate': 1.0, 
      };
    } catch (e) {
      throw Exception('Error fetching check-in statistics: $e');
    }
  }
  
  Future<List<CheckInQuestion>> generateQuestions({Map<String, dynamic>? previousAnswers, List<CheckInModel>? recentHistory}) async {
    // ... (generateQuestions implementation is unchanged)
    final coreQuestions = [
      CheckInQuestion(
        id: 'overall_satisfaction',
        question: 'How satisfied are you with your relationship overall?',
        type: QuestionType.slider,
        minValue: 1,
        maxValue: 10,
        category: 'satisfaction',
      ),
      CheckInQuestion(
        id: 'feeling_connected',
        question: 'How connected do you feel to your partner?',
        type: QuestionType.slider,
        minValue: 1,
        maxValue: 10,
        category: 'connection',
      ),
    ];

    final additionalQuestions = [
      CheckInQuestion(
        id: 'communication_quality',
        question: 'How would you rate the quality of your communication this week?',
        type: QuestionType.slider,
        minValue: 1,
        maxValue: 10,
        category: 'communication',
      ),
      CheckInQuestion(
        id: 'quality_time',
        question: 'Have you spent quality time together this week?',
        type: QuestionType.yesNo,
        category: 'time',
      ),
      CheckInQuestion(
        id: 'appreciation',
        question: 'What’s one thing you appreciate most about your partner this week?',
        type: QuestionType.textInput,
        placeholder: 'Share your thoughts...',
        isRequired: false,
        category: 'gratitude',
      ),
      CheckInQuestion(
        id: 'feeling_heard',
        question: 'How heard do you feel by your partner?',
        type: QuestionType.slider,
        minValue: 1,
        maxValue: 10,
        category: 'communication',
      ),
      CheckInQuestion(
        id: 'stress_level',
        question: 'How stressed have you felt in your relationship this week?',
        type: QuestionType.slider,
        minValue: 1,
        maxValue: 10,
        category: 'stress',
      ),
      CheckInQuestion(
        id: 'future_optimism',
        question: 'How optimistic are you about your future together?',
        type: QuestionType.slider,
        minValue: 1,
        maxValue: 10,
        category: 'future',
      ),
      CheckInQuestion(
        id: 'conflict_resolution',
        question: 'How well do you feel conflicts were resolved this week?',
        type: QuestionType.slider,
        minValue: 1,
        maxValue: 10,
        category: 'conflict',
      ),
      CheckInQuestion(
        id: 'physical_intimacy',
        question: 'How satisfied are you with your physical intimacy?',
        type: QuestionType.slider,
        minValue: 1,
        maxValue: 10,
        category: 'intimacy',
      ),
      CheckInQuestion(
        id: 'emotional_support',
        question: 'How supported do you feel emotionally by your partner?',
        type: QuestionType.slider,
        minValue: 1,
        maxValue: 10,
        category: 'support',
      ),
      CheckInQuestion(
        id: 'shared_goals',
        question: 'How aligned do you feel with your partner on shared goals?',
        type: QuestionType.slider,
        minValue: 1,
        maxValue: 10,
        category: 'goals',
      ),
      CheckInQuestion(
        id: 'fun_together',
        question: 'How much fun have you had together recently?',
        type: QuestionType.slider,
        minValue: 1,
        maxValue: 10,
        category: 'fun',
      ),
      CheckInQuestion(
        id: 'trust_level',
        question: 'How much do you trust your partner?',
        type: QuestionType.slider,
        minValue: 1,
        maxValue: 10,
        category: 'trust',
      ),
      CheckInQuestion(
        id: 'personal_growth',
        question: 'Do you feel your relationship supports your personal growth?',
        type: QuestionType.yesNo,
        category: 'growth',
      ),
      CheckInQuestion(
        id: 'recent_challenge',
        question: 'Describe a recent challenge you faced together and how you handled it.',
        type: QuestionType.textInput,
        placeholder: 'Describe the challenge...',
        isRequired: false,
        category: 'challenge',
      ),
      CheckInQuestion(
        id: 'gratitude_specific',
        question: 'What is something specific your partner did this week that you’re grateful for?',
        type: QuestionType.textInput,
        placeholder: 'Be specific...',
        isRequired: false,
        category: 'gratitude',
      ),
      CheckInQuestion(
        id: 'support_given',
        question: 'How much support do you feel you gave your partner this week?',
        type: QuestionType.slider,
        minValue: 1,
        maxValue: 10,
        category: 'support',
      ),
      CheckInQuestion(
        id: 'date_night',
        question: 'Did you have a date night or special time together this week?',
        type: QuestionType.yesNo,
        category: 'time',
      ),
      CheckInQuestion(
        id: 'laugh_together',
        question: 'Did you laugh together this week?',
        type: QuestionType.yesNo,
        category: 'fun',
      ),
      CheckInQuestion(
        id: 'external_stress',
        question: 'Have outside stresses affected your relationship this week?',
        type: QuestionType.yesNo,
        category: 'stress',
      ),
      CheckInQuestion(
        id: 'goal_progress',
        question: 'Did you make progress on any shared goals this week?',
        type: QuestionType.yesNo,
        category: 'goals',
      ),
    ];

    final personalizedQuestions = <CheckInQuestion>[];
    if (previousAnswers != null) {
      if (previousAnswers['communication_quality'] != null && previousAnswers['communication_quality'] < 6) {
        personalizedQuestions.add(CheckInQuestion(
          id: 'communication_followup',
          question: 'You rated communication low last time. Is there something you wish was different?',
          type: QuestionType.textInput,
          placeholder: 'Share your thoughts...',
          isRequired: false,
          category: 'communication',
        ));
      }
    }

    if (recentHistory != null && recentHistory.length >= 3) {
      final sortedHistory = List<CheckInModel>.from(recentHistory)
        ..sort((a, b) => (b.completedAt ?? DateTime(0)).compareTo(a.completedAt ?? DateTime(0)));
      List<double> getMetric(String key) {
        return sortedHistory
            .map((c) => c.answers[key])
            .where((v) => v != null)
            .map((v) => v is int ? v.toDouble() : v as double)
            .toList();
      }
      List<String?> getStringMetric(String key) {
        return sortedHistory
            .map((c) => c.answers[key] as String?)
            .toList();
      }

      final satisfaction = getMetric('overall_satisfaction');
      if (satisfaction.length >= 3) {
        if (satisfaction[0] < 7 && satisfaction[1] < 7 && satisfaction[2] < 7) {
          personalizedQuestions.add(CheckInQuestion(
            id: 'satisfaction_trend',
            question: 'Your satisfaction has been low for a while. Would you like to reflect on why?',
            type: QuestionType.textInput,
            placeholder: 'Share your thoughts...',
            isRequired: false,
            category: 'satisfaction',
            isTrendBased: true,
          ));
        } else if (satisfaction[0] < satisfaction[1] && satisfaction[1] < satisfaction[2]) {
          personalizedQuestions.add(CheckInQuestion(
            id: 'satisfaction_drop',
            question: 'Your satisfaction has been dropping. Is there something that changed?',
            type: QuestionType.textInput,
            placeholder: 'Share your thoughts...',
            isRequired: false,
            category: 'satisfaction',
            isTrendBased: true,
          ));
        }
      }

      final stress = getMetric('stress_level');
      if (stress.length >= 3) {
        if (stress[0] > 7 && stress[1] > 7 && stress[2] > 7) {
          personalizedQuestions.add(CheckInQuestion(
            id: 'stress_trend',
            question: 'Your stress has been high for a while. Would you like to talk about what’s causing it?',
            type: QuestionType.textInput,
            placeholder: 'Share your thoughts...',
            isRequired: false,
            category: 'stress',
            isTrendBased: true,
          ));
        } else if (stress[0] > stress[1] && stress[1] > stress[2]) {
          personalizedQuestions.add(CheckInQuestion(
            id: 'stress_rising',
            question: 'Your stress has been rising. Is there something new affecting you?',
            type: QuestionType.textInput,
            placeholder: 'Share your thoughts...',
            isRequired: false,
            category: 'stress',
            isTrendBased: true,
          ));
        }
      }

      final communication = getMetric('communication_quality');
      if (communication.length >= 3) {
        if (communication[0] < 6 && communication[1] < 6 && communication[2] < 6) {
          personalizedQuestions.add(CheckInQuestion(
            id: 'communication_trend',
            question: 'Communication has been tough lately. Would you like to reflect on it?',
            type: QuestionType.textInput,
            placeholder: 'Share your thoughts...',
            isRequired: false,
            category: 'communication',
            isTrendBased: true,
          ));
        } else if (communication[0] < communication[1] && communication[1] < communication[2]) {
          personalizedQuestions.add(CheckInQuestion(
            id: 'communication_drop',
            question: 'Your communication rating has been dropping. Any thoughts on why?',
            type: QuestionType.textInput,
            placeholder: 'Share your thoughts...',
            isRequired: false,
            category: 'communication',
            isTrendBased: true,
          ));
        }
      }

      final intimacy = getMetric('physical_intimacy');
      if (intimacy.length >= 3) {
        if (intimacy[0] < 6 && intimacy[1] < 6 && intimacy[2] < 6) {
          personalizedQuestions.add(CheckInQuestion(
            id: 'intimacy_trend',
            question: 'You’ve reported low satisfaction with physical intimacy for a while. Would you like to reflect on this?',
            type: QuestionType.textInput,
            placeholder: 'Share your thoughts...',
            isRequired: false,
            category: 'intimacy',
            isTrendBased: true,
          ));
        } else if (intimacy[0] < intimacy[1] && intimacy[1] < intimacy[2]) {
          personalizedQuestions.add(CheckInQuestion(
            id: 'intimacy_drop',
            question: 'Your satisfaction with physical intimacy has been dropping. Any changes you’ve noticed?',
            type: QuestionType.textInput,
            placeholder: 'Share your thoughts...',
            isRequired: false,
            category: 'intimacy',
            isTrendBased: true,
          ));
        }
      }

      final support = getMetric('emotional_support');
      if (support.length >= 3) {
        if (support[0] < 6 && support[1] < 6 && support[2] < 6) {
          personalizedQuestions.add(CheckInQuestion(
            id: 'support_trend',
            question: 'You’ve felt emotionally unsupported for a while. Would you like to talk about it?',
            type: QuestionType.textInput,
            placeholder: 'Share your thoughts...',
            isRequired: false,
            category: 'support',
            isTrendBased: true,
          ));
        }
      }
      final supportGiven = getMetric('support_given');
      if (supportGiven.length >= 3) {
        if (supportGiven[0] < supportGiven[1] && supportGiven[1] < supportGiven[2]) {
          personalizedQuestions.add(CheckInQuestion(
            id: 'support_given_drop',
            question: 'You’ve reported giving less support to your partner recently. Is something making it harder?',
            type: QuestionType.textInput,
            placeholder: 'Share your thoughts...',
            isRequired: false,
            category: 'support',
            isTrendBased: true,
          ));
        }
      }

      final goals = getMetric('shared_goals');
      if (goals.length >= 3) {
        if (goals[0] < 6 && goals[1] < 6 && goals[2] < 6) {
          personalizedQuestions.add(CheckInQuestion(
            id: 'goals_trend',
            question: 'You’ve felt less aligned on shared goals for a while. Would you like to reflect on this?',
            type: QuestionType.textInput,
            placeholder: 'Share your thoughts...',
            isRequired: false,
            category: 'goals',
            isTrendBased: true,
          ));
        }
      }
      final goalProgress = sortedHistory
        .map((c) => c.answers['goal_progress'] as String?)
        .where((v) => v != null)
        .toList();
      if (goalProgress.length >= 3 && goalProgress[0] == 'No' && goalProgress[1] == 'No' && goalProgress[2] == 'No') {
        personalizedQuestions.add(CheckInQuestion(
          id: 'goal_progress_trend',
          question: 'You haven’t made progress on shared goals for a while. Any obstacles you’d like to discuss?',
          type: QuestionType.textInput,
          placeholder: 'Share your thoughts...',
          isRequired: false,
          category: 'goals',
          isTrendBased: true,
        ));
      }

      final fun = getMetric('fun_together');
      if (fun.length >= 3) {
        if (fun[0] < 6 && fun[1] < 6 && fun[2] < 6) {
          personalizedQuestions.add(CheckInQuestion(
            id: 'fun_trend',
            question: 'You haven’t had much fun together lately. Would you like ideas for fun activities?',
            type: QuestionType.textInput,
            placeholder: 'Share your thoughts...',
            isRequired: false,
            category: 'fun',
            isTrendBased: true,
          ));
        }
      }

      int gratitudeMissing = 0;
      for (int i = 0; i < 3 && i < sortedHistory.length; i++) {
        final checkIn = sortedHistory[i];
        final wasAsked = checkIn.questions.any((q) => q.id == 'gratitude_specific');
        final answer = checkIn.answers['gratitude_specific'] as String?;
        if (wasAsked && (answer == null || answer.trim().isEmpty)) {
          gratitudeMissing++;
        }
      }
      if (gratitudeMissing == 3) {
        personalizedQuestions.add(CheckInQuestion(
          id: 'gratitude_trend',
          question: 'It’s been a while since you noted something specific you’re grateful for. Has it been hard to notice positives?',
          type: QuestionType.textInput,
          placeholder: 'Share your thoughts...',
          isRequired: false,
          category: 'gratitude',
          isTrendBased: true,
        ));
      }
    }

    final filteredAdditional = additionalQuestions.where((q) => !personalizedQuestions.any((p) => p.id == q.id)).toList();

    final shuffledQuestions = List<CheckInQuestion>.from(filteredAdditional);
    shuffledQuestions.shuffle(_random);
    final selectedAdditional = shuffledQuestions.take(5 + _random.nextInt(3)).toList();

    final allQuestions = [
      ...coreQuestions,
      ...personalizedQuestions,
      ...selectedAdditional,
    ];
    return allQuestions;
  }
  
  Future<void> notifyPartnerCheckInCompleted(String coupleId, String partnerId) async {
    try {
      await _firestore
          .collection('couples')
          .doc(coupleId)
          .collection('notifications')
          .add({
        'type': 'check_in_completed',
        'message': 'Your partner completed their relationship health check-in!',
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
        'recipientId': partnerId,
      });
    } catch (e) {
      throw Exception('Error notifying partner: $e');
    }
  }

  // ✨ [ADD] New method to delete a specific check-in document.
  Future<void> deleteCheckIn(String userId, String checkInId) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('check_ins')
          .doc(checkInId)
          .delete();
    } catch (e) {
      throw Exception('Error deleting check-in: $e');
    }
  }

  Stream<CheckInModel?> getLatestSharedCheckInStream(String currentUserId, String partnerId) {
    final query = _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('check_ins')
        .where('sharedByUserId', isEqualTo: partnerId)
        .where('isRead', isEqualTo: false)
        .orderBy('timestamp', descending: true)
        .limit(1);

    return query.snapshots().map((snapshot) {
      if (snapshot.docs.isNotEmpty) {
        return CheckInModel.fromFirestore(snapshot.docs.first);
      }
      return null; 
    });
  }

  Future<void> shareFullCheckInWithPartner({
    required String partnerId,
    required CheckInModel checkInToShare,
  }) async {
    try {
      final checkInMap = checkInToShare.toMap();

      checkInMap['sharedByUserId'] = checkInToShare.userId; 
      checkInMap['isFullCheckInShared'] = true; 
      checkInMap['isRead'] = false;
      checkInMap.remove('userInsights'); 

      await _firestore
          .collection('users')
          .doc(partnerId)
          .collection('check_ins')
          .doc(checkInToShare.id)
          .set(checkInMap);
          
    } catch (e) {
      print('Error sharing full check-in with partner: $e');
      rethrow;
    }
  }

  Future<void> shareSelectedInsightsToPartner({
    required String userId,
    required String partnerId,
    required String coupleId,
    required List<String> selectedInsights,
    required String checkInId, 
  }) async {
    try {
      final partialCheckInData = {
        'sharedByUserId': userId,
        'coupleId': coupleId,
        'isRead': false,
        'isCompleted': true,
        'isFullCheckInShared': false, 
        'timestamp': FieldValue.serverTimestamp(),
        'completedAt': FieldValue.serverTimestamp(),
        'sharedInsights': selectedInsights,
        'answers': {},
        'questions': [],
      };

      await _firestore
          .collection('users')
          .doc(partnerId)
          .collection('check_ins')
          .doc(checkInId)
          .set(partialCheckInData);
    } catch (e) {
      throw Exception('Error sharing selected insights: $e');
    }
  }

  Future<CheckInModel?> getLatestSharedCheckInFromPartner(String currentUserId, String partnerId) async {
    final snapshot = await _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('check_ins')
        .where('sharedByUserId', isEqualTo: partnerId)
        .where('isRead', isEqualTo: false)
        .orderBy('timestamp', descending: true)
        .limit(1)
        .get();

    if (snapshot.docs.isNotEmpty) {
      return CheckInModel.fromFirestore(snapshot.docs.first);
    }
    return null;
  }

  Future<void> markInsightAsRead(String currentUserId, String checkInId) async {
    await _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('check_ins')
        .doc(checkInId)
        .update({'isRead': true});
  }
}