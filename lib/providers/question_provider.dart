// lib/features/questions/provider/question_provider.dart
import 'package:flutter/material.dart';
import 'package:feelings/features/questions/models/question_model.dart';
import 'package:feelings/features/questions/repository/questions_repository.dart';
import 'package:feelings/features/rhm/repository/rhm_repository.dart';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import 'dynamic_actions_provider.dart';

class QuestionProvider with ChangeNotifier {
  // ... (Properties _dynamicActionsProvider, _questionRepository, _rhmRepository, lists, state variables unchanged) ...
  final DynamicActionsProvider _dynamicActionsProvider;
  final QuestionRepository _questionRepository;
  final RhmRepository _rhmRepository;

  List<QuestionModel> _questions = [];
  List<String> _doneQuestions = [];
  bool _isLoading = false;
  List<String> _categories = [];
  Map<String, List<String>> _subCategoriesByCategory = {};
  QuestionModel? _dailyQuestion;
  bool _isLoadingDailyQuestion = false;
  QuestionModel? _currentRandomQuestion;


  // Constructor (already updated)
  QuestionProvider(this._dynamicActionsProvider, {
    required QuestionRepository questionRepository, // Now required
    required RhmRepository rhmRepository,
  }) : _questionRepository = questionRepository,
       _rhmRepository = rhmRepository;

  // ... (Getters, fetchQuestions, _isSameDay, fetchDailyQuestion, fetchQuestionsByCategory, etc., unchanged) ...
    List<QuestionModel> get availableQuestions =>
      _questions.where((q) => !_doneQuestions.contains(q.id)).toList();
  List<QuestionModel> get questions => _questions;
  List<String> get doneQuestions => _doneQuestions;
  bool get isLoading => _isLoading;
  List<String> get categories => _categories;
  QuestionModel? get dailyQuestion => _dailyQuestion;
  bool get isLoadingDailyQuestion => _isLoadingDailyQuestion;
  QuestionModel? get currentRandomQuestion => _currentRandomQuestion;


  List<String> getSubCategoriesForCategory(String category) {
    return _subCategoriesByCategory[category] ?? [];
  }

  Future<void> fetchQuestions(String userId) async {
    if (userId.isEmpty) {
      debugPrint("Error: userId is empty for fetchQuestions.");
      _questions = [];
      _doneQuestions = [];
      notifyListeners();
      return;
    }

    _isLoading = true;
    notifyListeners();

    try {
      _questions = await _questionRepository.getAllQuestions();
      _doneQuestions = await _questionRepository.getDoneQuestions(userId);
      _categories = await _questionRepository.getAllCategories();

      _subCategoriesByCategory = {};
      for (final String category in _categories) {
        _subCategoriesByCategory[category] = await _questionRepository.getSubCategoriesForCategory(category);
      }
    } catch (e) {
      debugPrint("Error fetching all questions/done questions: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
           date1.month == date2.month &&
           date1.day == date2.day;
  }

  Future<void> fetchDailyQuestion(String userId) async {
    if (userId.isEmpty) {
      debugPrint("Error: userId is empty for fetchDailyQuestion.");
      _dailyQuestion = null;
      _isLoadingDailyQuestion = false;
      notifyListeners();
      return;
    }

    _isLoadingDailyQuestion = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final today = DateTime.now();
      const lastFetchedDateKey = 'dailyQuestionDate';
      const storedQuestionIdKey = 'dailyQuestionId';

      final userDateKey = '${lastFetchedDateKey}_$userId';
      final userIdKey = '${storedQuestionIdKey}_$userId';

      final lastFetchedDateString = prefs.getString(userDateKey);
      final storedQuestionId = prefs.getString(userIdKey);
      final lastFetchedDate = lastFetchedDateString != null
          ? DateTime.tryParse(lastFetchedDateString)
          : null;

      final bool needsNewQuestion = storedQuestionId == null ||
          lastFetchedDate == null ||
          !_isSameDay(lastFetchedDate, today);

      if (needsNewQuestion) {
        final allQuestions = await _questionRepository.getAllQuestions();
        final doneQs = await _questionRepository.getDoneQuestions(userId); // Fetch fresh done list
        final availableQuestions = allQuestions
            .where((q) => !doneQs.contains(q.id))
            .toList();

        if (availableQuestions.isEmpty) {
          debugPrint("No new questions available.");
          _dailyQuestion = null;
          return;
        }

        final random = Random();
        final selectedQuestion =
            availableQuestions[random.nextInt(availableQuestions.length)];

        _dailyQuestion = selectedQuestion;
        await prefs.setString(userDateKey, today.toIso8601String());
        await prefs.setString(userIdKey, selectedQuestion.id);
      } else {
        _dailyQuestion = await _questionRepository.getQuestionById(storedQuestionId);
      }
    } catch (e, stackTrace) {
      debugPrint("Error fetching daily question: $e");
      debugPrint("Stack trace: $stackTrace");
      _dailyQuestion = null;
    } finally {
      _isLoadingDailyQuestion = false;
      notifyListeners();
    }
  }

  Future<void> fetchQuestionsByCategory(String category) async {
    _isLoading = true;
    notifyListeners();
    _questions = await _questionRepository.getQuestionsByCategory(category);
    _isLoading = false;
    notifyListeners();
  }

  Future<void> fetchQuestionsBySubCategory(String subCategory) async {
    _isLoading = true;
    notifyListeners();
    _questions = await _questionRepository.getQuestionsBySubCategory(subCategory);
    _isLoading = false;
    notifyListeners();
  }

  Future<void> fetchQuestionsByCategoryAndSubCategory(String category, String subCategory) async {
    _isLoading = true;
    notifyListeners();
    _questions = await _questionRepository.getQuestionsByCategoryAndSubCategory(category, subCategory);
    _isLoading = false;
    notifyListeners();
  }


  // ✨ [MODIFY] Update markQuestionAsDone to check frequency *per user*
  Future<void> markQuestionAsDone(String userId, String questionId, String coupleId) async {
    if (userId.isEmpty) return;

    // 1. Check if the question is already done *locally* before the DB call
    bool isNewCompletionLocally = !_doneQuestions.contains(questionId);

    // 2. Original DB call
    await _questionRepository.markQuestionAsDone(userId, questionId);

    // 3. Update local state
    if (isNewCompletionLocally) {
      _doneQuestions.add(questionId);
    }
    _dynamicActionsProvider.recordQuestionAsked();
    notifyListeners(); // Notify UI immediately

    // 4. ✨ [ADD] RHM Frequency Check and Logging Logic
    // Only log points if this is the daily question AND it's the first time
    // this specific user is marking it done within the frequency limit.
    if (_dailyQuestion != null && questionId == _dailyQuestion!.id) {
       const String actionType = 'qotd_answered';
       const Duration frequencyLimit = Duration(hours: 24); // Once per 24 hours per user

       try {
         // Use the new user-specific method
         final lastActionTime = await _rhmRepository.getLastActionTimestampForUser(coupleId, userId, actionType);
         final now = DateTime.now();

         if (lastActionTime == null || now.difference(lastActionTime) >= frequencyLimit) {
           await _rhmRepository.logAction(
             coupleId: coupleId,
             userId: userId, // Logged for the user who answered
             actionType: actionType,
             points: 1, // +1 point per partner
             sourceId: questionId,
           );
           debugPrint("[QuestionProvider] Logged +1 RHM for $actionType by user $userId");
         } else {
           final timeRemaining = frequencyLimit - now.difference(lastActionTime);
           debugPrint("[QuestionProvider] Skipped RHM logging for $actionType by user $userId (limit not met, ${timeRemaining.inHours}h remaining)");
         }
       } catch (e) {
         debugPrint("[QuestionProvider] Error checking/logging RHM action for QOTD: $e");
       }
    }
  }

  // ... (removeQuestionFromDone, countDoneQuestions, random question fetches, clearCurrentRandomQuestion, refreshCategoriesAndSubCategories, clear, dispose are unchanged) ...
   Future<void> removeQuestionFromDone(String userId, String questionId) async {
    if (userId.isEmpty) return;
    await _questionRepository.removeQuestionFromDone(userId, questionId);
    _doneQuestions.remove(questionId);
    notifyListeners();
  }

  Future<int> countDoneQuestions(String userId) async {
    if (userId.isEmpty) return 0;
    return _questionRepository.countDoneQuestions(userId);
  }

  Future<void> fetchRandomAvailableQuestion(String userId) async {
    _isLoading = true;
    notifyListeners();
    final List<QuestionModel> allQuestions = await _questionRepository.getAllQuestions();
    final List<String> doneQuestionsList = await _questionRepository.getDoneQuestions(userId);

    final List<QuestionModel> availableQuestions =
        allQuestions.where((q) => !doneQuestionsList.contains(q.id)).toList();

    if (availableQuestions.isNotEmpty) {
      final random = Random();
      _currentRandomQuestion = availableQuestions[random.nextInt(availableQuestions.length)];
    } else {
      _currentRandomQuestion = null;
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> fetchRandomAvailableQuestionByCategory(String userId, String category) async {
    _isLoading = true;
    notifyListeners();
    final List<QuestionModel> questionsInCategory = await _questionRepository.getQuestionsByCategory(category);
    final List<String> doneQuestionsList = await _questionRepository.getDoneQuestions(userId);
    final List<QuestionModel> availableQuestionsInCategory =
        questionsInCategory.where((q) => !doneQuestionsList.contains(q.id)).toList();

    if (availableQuestionsInCategory.isNotEmpty) {
      final random = Random();
      _currentRandomQuestion = availableQuestionsInCategory[random.nextInt(availableQuestionsInCategory.length)];
    } else {
      _currentRandomQuestion = null;
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> fetchRandomAvailableQuestionBySubCategory(String userId, String subCategory) async {
    _isLoading = true;
    notifyListeners();
    final List<QuestionModel> questionsInSubCategory = await _questionRepository.getQuestionsBySubCategory(subCategory);
    final List<String> doneQuestionsList = await _questionRepository.getDoneQuestions(userId);
    final List<QuestionModel> availableQuestionsInSubCategory =
        questionsInSubCategory.where((q) => !doneQuestionsList.contains(q.id)).toList();

    if (availableQuestionsInSubCategory.isNotEmpty) {
      final random = Random();
      _currentRandomQuestion = availableQuestionsInSubCategory[random.nextInt(availableQuestionsInSubCategory.length)];
    } else {
      _currentRandomQuestion = null;
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> fetchRandomAvailableQuestionByCategoryAndSubCategory(String userId, String category, String subCategory) async {
    _isLoading = true;
    notifyListeners();
    final List<QuestionModel> questions = await _questionRepository.getQuestionsByCategoryAndSubCategory(category, subCategory);
    final List<String> doneQuestionsList = await _questionRepository.getDoneQuestions(userId);
    final List<QuestionModel> availableQuestions =
        questions.where((q) => !doneQuestionsList.contains(q.id)).toList();

    if (availableQuestions.isNotEmpty) {
      final random = Random();
      _currentRandomQuestion = availableQuestions[random.nextInt(availableQuestions.length)];
    } else {
      _currentRandomQuestion = null;
    }
    _isLoading = false;
    notifyListeners();
  }

  void clearCurrentRandomQuestion() {
    _currentRandomQuestion = null;
    notifyListeners();
  }

  Future<void> refreshCategoriesAndSubCategories() async {
    _isLoading = true;
    notifyListeners();
    _categories = await _questionRepository.getAllCategories();
    _subCategoriesByCategory = {};
    for (final String category in _categories) {
      _subCategoriesByCategory[category] = await _questionRepository.getSubCategoriesForCategory(category);
    }
    _isLoading = false;
    notifyListeners();
  }

  void clear() {
    _questions = [];
    _doneQuestions = [];
    _isLoading = false;
    _categories = [];
    _subCategoriesByCategory = {};
    _dailyQuestion = null;
    _isLoadingDailyQuestion = false;
    _currentRandomQuestion = null;
    // notifyListeners();
    debugPrint("[QuestionProvider] Cleared and reset state.");
  }

  @override
  void dispose() {
    clear();
    super.dispose();
  }
}