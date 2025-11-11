// lib/features/questions/repository/question_repository.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:feelings/features/questions/models/question_model.dart';
import 'dart:math';

class QuestionRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  // Initialize Random once for efficiency
  final Random _random = Random(); 

  // Using root collection paths as confirmed by the user
  static const String _questionsCollectionPath = 'questions';
  static const String _usersCollectionPath = 'users';

  // ✅ Getter for Firestore
  FirebaseFirestore get firestore => _firestore;

  // ✅ Getter for collection path
  static String get questionsCollectionPath => _questionsCollectionPath;

  /// Fetches all questions from the 'questions' collection.
  Future<List<QuestionModel>> getAllQuestions() async {
    final QuerySnapshot snapshot = await _firestore.collection(_questionsCollectionPath).get();
    return snapshot.docs.map((doc) => QuestionModel.fromMap(doc.data() as Map<String, dynamic>, doc.id)).toList();
  }

  /// Fetches a single question by its ID.
  Future<QuestionModel?> getQuestionById(String questionId) async {
    final DocumentSnapshot doc = await _firestore.collection(_questionsCollectionPath).doc(questionId).get();
    // Simplified null and existence check
    if (doc.exists && doc.data() != null) {
      return QuestionModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
    }
    return null;
  }

  /// Fetches questions belonging to a specific category.
  Future<List<QuestionModel>> getQuestionsByCategory(String category) async {
    final QuerySnapshot snapshot = await _firestore.collection(_questionsCollectionPath).where('category', isEqualTo: category).get();
    return snapshot.docs.map((doc) => QuestionModel.fromMap(doc.data() as Map<String, dynamic>, doc.id)).toList();
  }

  /// Fetches questions belonging to a specific subCategory.
  Future<List<QuestionModel>> getQuestionsBySubCategory(String subCategory) async {
    final QuerySnapshot snapshot = await _firestore.collection(_questionsCollectionPath).where('subCategory', isEqualTo: subCategory).get();
    return snapshot.docs.map((doc) => QuestionModel.fromMap(doc.data() as Map<String, dynamic>, doc.id)).toList();
  }

  /// Fetches questions belonging to both a specific category and subCategory.
  Future<List<QuestionModel>> getQuestionsByCategoryAndSubCategory(String category, String subCategory) async {
    final QuerySnapshot snapshot = await _firestore.collection(_questionsCollectionPath)
        .where('category', isEqualTo: category)
        .where('subCategory', isEqualTo: subCategory)
        .get();
    return snapshot.docs.map((doc) => QuestionModel.fromMap(doc.data() as Map<String, dynamic>, doc.id)).toList();
  }

  /// Fetches the list of question IDs marked as 'done' by a specific user.
  Future<List<String>> getDoneQuestions(String userId) async {
    // Early exit for empty userId
    if (userId.isEmpty) return []; 

    final DocumentSnapshot userDoc = await _firestore.collection(_usersCollectionPath).doc(userId).get();

    // Direct casting with null-aware operator for map and check key
    if (userDoc.exists) {
      return List<String>.from((userDoc.data() as Map<String, dynamic>?)?['doneQuestions'] ?? []);
    }
    return [];
  }

  /// Marks a question as done for a specific user.
  Future<void> markQuestionAsDone(String userId, String questionId) async {
    await _firestore.collection(_usersCollectionPath).doc(userId).update({
      'doneQuestions': FieldValue.arrayUnion([questionId])
    });
  }

  /// Removes a question from the 'done' list for a specific user.
  Future<void> removeQuestionFromDone(String userId, String questionId) async {
    await _firestore.collection(_usersCollectionPath).doc(userId).update({
      'doneQuestions': FieldValue.arrayRemove([questionId])
    });
  }

  /// Counts the number of questions marked as 'done' for a specific user.
  Future<int> countDoneQuestions(String userId) async {
    // Directly return length of the list from the getter
    return (await getDoneQuestions(userId)).length;
  }

  /// Gets a random question from all available questions.
  Future<QuestionModel?> getRandomQuestion() async {
    final List<QuestionModel> allQuestions = await getAllQuestions();
    if (allQuestions.isEmpty) return null;
    return allQuestions[_random.nextInt(allQuestions.length)]; // Use _random instance
  }

  /// Gets a random question from a specific category.
  Future<QuestionModel?> getRandomQuestionByCategory(String category) async {
    final List<QuestionModel> questionsInCategory = await getQuestionsByCategory(category);
    if (questionsInCategory.isEmpty) return null;
    return questionsInCategory[_random.nextInt(questionsInCategory.length)]; // Use _random instance
  }

  /// Gets a random question from a specific subCategory.
  Future<QuestionModel?> getRandomQuestionBySubCategory(String subCategory) async {
    final List<QuestionModel> questionsInSubCategory = await getQuestionsBySubCategory(subCategory);
    if (questionsInSubCategory.isEmpty) return null;
    return questionsInSubCategory[_random.nextInt(questionsInSubCategory.length)]; // Use _random instance
  }

  /// Gets a random question from a specific category and subCategory.
  Future<QuestionModel?> getRandomQuestionByCategoryAndSubCategory(String category, String subCategory) async {
    final List<QuestionModel> questions = await getQuestionsByCategoryAndSubCategory(category, subCategory);
    if (questions.isEmpty) return null;
    return questions[_random.nextInt(questions.length)]; // Use _random instance
  }

  /// Fetches all unique categories from the 'questions' collection.
  Future<List<String>> getAllCategories() async {
    final QuerySnapshot snapshot = await _firestore.collection(_questionsCollectionPath).get();
    final Set<String> categories = {};
    for (final doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>; // Cast once
      if (data.containsKey('category')) {
        categories.add(data['category'] as String);
      }
    }
    return categories.toList();
  }

  /// Fetches all unique subcategories for a given category.
  Future<List<String>> getSubCategoriesForCategory(String category) async {
    final QuerySnapshot snapshot = await _firestore.collection(_questionsCollectionPath)
        .where('category', isEqualTo: category)
        .get();
    final Set<String> subCategories = {};
    for (final doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>; // Cast once
      if (data.containsKey('subCategory')) {
        subCategories.add(data['subCategory'] as String);
      }
    }
    return subCategories.toList();
  }

  /// Fetches all unique subcategories across all categories.
  Future<List<String>> getAllSubCategories() async {
    final QuerySnapshot snapshot = await _firestore.collection(_questionsCollectionPath).get();
    final Set<String> subCategories = {};
    for (final doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>; // Cast once
      if (data.containsKey('subCategory')) {
        subCategories.add(data['subCategory'] as String);
      }
    }
    return subCategories.toList();
  }
}
