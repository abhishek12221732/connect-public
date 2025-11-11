// lib/providers/date_idea_provider.dart

import 'package:flutter/material.dart';
import 'package:feelings/features/date_night/services/date_idea_service.dart';
import 'package:feelings/features/date_night/models/date_idea.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'package:feelings/providers/done_dates_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DateIdeaProvider extends ChangeNotifier {
  final DateIdeaService _dateIdeaService = DateIdeaService();
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  DoneDatesProvider _doneDatesProvider;

  DateIdeaProvider({required DoneDatesProvider doneDatesProvider})
    : _doneDatesProvider = doneDatesProvider;

// ✨ ADD THIS METHOD
void updateDependencies(DoneDatesProvider doneDatesProvider) {
  _doneDatesProvider = doneDatesProvider;
}

  // Favorites
  List<DateIdea> favoriteIdeas = [];
  bool isFavoritesLoading = false;

  // Selected filters
  List<String> selectedLocations = [];
  String? selectedVibe;
  String? selectedBudget;
  String? selectedTime;

  // Generated idea and loading state
  DateIdea? generatedIdea;
  bool isLoading = false;

  // --- SUGGEST TO PARTNER LOGIC ---
  List<Map<String, dynamic>> _suggestions = [];
  Stream<List<Map<String, dynamic>>>? _suggestionsStream;
  String? _currentCoupleId; // Track current coupleId to avoid unnecessary re-listening
  
  // Track current suggestion for the generated date idea screen
  String? currentSuggestionId;
  String? currentSuggestionCoupleId;
  String? currentSuggestionIdeaId; // Track the specific idea ID that is a suggestion

  // Firestore suggestions stream subscription
  StreamSubscription<List<Map<String, dynamic>>>? _suggestionsSubscription;

  List<Map<String, dynamic>> get suggestions => _suggestions;
  Stream<List<Map<String, dynamic>>>? get suggestionsStream => _suggestionsStream;

  String? fallbackMessage;

  bool disposed = false;

  // ✨ ADDED: The clear method to reset all state on logout
  void clear() {
    // Cancel active listeners
    _suggestionsSubscription?.cancel();
    _suggestionsSubscription = null;

    // Reset all state variables
    favoriteIdeas = [];
    isFavoritesLoading = false;
    selectedLocations = [];
    selectedVibe = null;
    selectedBudget = null;
    selectedTime = null;
    generatedIdea = null;
    isLoading = false;
    _suggestions = [];
    _suggestionsStream = null;
    _currentCoupleId = null;
    currentSuggestionId = null;
    currentSuggestionCoupleId = null;
    currentSuggestionIdeaId = null;
    fallbackMessage = null;

    
    // notifyListeners();
    print("[DateIdeaProvider] Cleared and reset state.");
  }

  void listenToSuggestions(String coupleId) {
    if (disposed) {
      print('[DateIdeaProvider] Cannot listen to suggestions - provider is disposed');
      return;
    }
    
    if (_currentCoupleId == coupleId && _suggestionsSubscription != null) {
      print('[DateIdeaProvider] Already listening to suggestions for coupleId: $coupleId');
      return;
    }

    print('[DateIdeaProvider] Setting up suggestions stream for coupleId: $coupleId');
    
    _suggestionsSubscription?.cancel();
    _suggestionsSubscription = null;
    
    _currentCoupleId = coupleId;
    
    _suggestionsStream = _dateIdeaService.getSuggestionsStream(coupleId);
    _suggestionsSubscription = _suggestionsStream!.listen(
      (data) {
        // ✨ --- [GUARD 1: ON-DATA] --- ✨
        if (disposed || FirebaseAuth.instance.currentUser == null) { // Check disposed flag too
          debugPrint("[DateIdeaProvider] Event received, but user is logged out or provider disposed. Ignoring.");
          return;
        }

        print('[DateIdeaProvider] Firestore suggestions stream emitted: $data');
        _suggestions = data;
        print('[DateIdeaProvider] _suggestions updated: $_suggestions');
        notifyListeners();
      },
      onError: (error) {
        // ✨ --- [GUARD 2: ON-ERROR] --- ✨
        if (error is FirebaseException && error.code == 'permission-denied') {
          if (FirebaseAuth.instance.currentUser == null) {
            debugPrint("[DateIdeaProvider] Safely caught permission-denied on listener during logout.");
          } else {
            debugPrint("[DateIdeaProvider] CRITICAL PERMISSION ERROR: $error");
          }
        } else {
          debugPrint("[DateIdeaProvider] Unexpected error: $error");
        }
      },
    );
  }



  // ... (All other methods remain unchanged) ...
  Future<void> refreshSuggestions() async {
    if (_currentCoupleId == null || disposed) return;
    
    print('[DateIdeaProvider] Force refreshing suggestions for coupleId: $_currentCoupleId');
    
    try {
      final doc = await _db
          .collection('couples')
          .doc(_currentCoupleId)
          .collection('suggestedDateIdeas')
          .doc('suggestion')
          .get();
      
      if (doc.exists) {
        final data = doc.data()!;
        data['id'] = doc.id;
        _suggestions = [data];
        print('[DateIdeaProvider] Manual refresh successful: $_suggestions');
      } else {
        _suggestions = [];
        print('[DateIdeaProvider] Manual refresh: no suggestion document found');
      }
      if (!disposed) {
        notifyListeners();
      }
    } catch (e) {
      print('[DateIdeaProvider] Error in manual refresh: $e');
    }
  }

  bool get isStreamConnected => _suggestionsSubscription != null && !disposed;
  
  String? get currentCoupleId => _currentCoupleId;
  
  void clearSuggestionTracking() {
    currentSuggestionId = null;
    currentSuggestionCoupleId = null;
    currentSuggestionIdeaId = null;
    if (!disposed) {
      notifyListeners();
    }
  }
  
  bool isCurrentSuggestion(String ideaId) {
    return currentSuggestionIdeaId == ideaId && currentSuggestionId != null;
  }
  
  void setCurrentSuggestion(String suggestionId, String coupleId, String ideaId) {
    currentSuggestionId = suggestionId;
    currentSuggestionCoupleId = coupleId;
    currentSuggestionIdeaId = ideaId;
    print('[DateIdeaProvider] Set current suggestion: suggestionId=$suggestionId, coupleId=$coupleId, ideaId=$ideaId');
    notifyListeners();
  }
  
  void debugSuggestionState() {
    print('[DateIdeaProvider] Current suggestion state:');
    print('  currentSuggestionId: $currentSuggestionId');
    print('  currentSuggestionCoupleId: $currentSuggestionCoupleId');
    print('  currentSuggestionIdeaId: $currentSuggestionIdeaId');
  }
  
  Future<void> testStreamConnection() async {
    if (_suggestionsSubscription != null) {
      print('[DateIdeaProvider] Stream is connected');
    } else {
      print('[DateIdeaProvider] Stream is not connected');
    }
  }

  Future<DateIdea?> getDateIdeaById(String dateIdeaId) async {
    try {
      return await _dateIdeaService.getDateIdeaById(dateIdeaId);
    } catch (e) {
      print('[DateIdeaProvider] Error fetching date idea by ID: $e');
      return null;
    }
  }

  Future<void> suggestDateIdeaToPartner({
    required DateIdea idea,
    required String coupleId,
    required String currentUserId,
    required String partnerId,
    required Future<void> Function(String receiverId, String message) sendPushNotification,
  }) async {
    if (coupleId.isEmpty || currentUserId.isEmpty || partnerId.isEmpty) return;
    
    print('[DateIdeaProvider] Suggesting date idea: ${idea.ideaName}');
    
    await _dateIdeaService.suggestDateIdea(
      coupleId: coupleId,
      dateIdeaId: idea.id,
      ideaName: idea.ideaName,
      description: idea.description,
      suggestedBy: currentUserId,
      suggestedTo: partnerId,
    );
    
    await refreshSuggestions();
    
    await sendPushNotification(
      partnerId,
      "Your partner suggested a new date idea: ${idea.ideaName}",
    );
  }

  Future<void> markSuggestionAsDone(
  String coupleId,
  String suggestionId,
  String currentUserId, // ✨ ADD THIS
) async {
  if (coupleId.isEmpty) return;

  print('[DateIdeaProvider] Marking suggestion as done: $suggestionId');

  // --- 🛑 OLD LOGIC TO REMOVE ---
  /*
  _doneDatesService ??= DoneDatesService(
    repository: DoneDatesRepository(coupleId: coupleId),
  );

  final currentSuggestion = _suggestions.firstWhere(
    (suggestion) => suggestion['id'] == suggestionId,
    orElse: () => {},
  );

  if (currentSuggestion.isNotEmpty && generatedIdea != null) {
    await _doneDatesService!.markSuggestionAsDone(
      dateIdea: generatedIdea!,
      suggestionId: suggestionId,
      completedBy: currentSuggestion['suggestedBy'] ?? '',
      actualDate: DateTime.now(),
    );
  }
  */
  // --- 🛑 END OF OLD LOGIC ---

  // --- ✨ NEW LOGIC TO ADD ---
  final currentSuggestion = _suggestions.firstWhere(
    (suggestion) => suggestion['id'] == suggestionId,
    orElse: () => <String, dynamic>{}, // Return empty map
  );

  if (currentSuggestion.isNotEmpty) {
    try {
      // Call the provider that has the RHM logic
      await _doneDatesProvider.addDoneDateFromSuggestion(
        dateIdeaId: currentSuggestion['dateIdeaId'] ?? 'unknown_idea',
        title: currentSuggestion['ideaName'] ?? 'Date Idea',
        description: currentSuggestion['description'] ?? '',
        suggestionId: suggestionId,
        completedBy: currentUserId, // ✨ Use the current user
        actualDate: DateTime.now(),
        // You can add notes or rating here if you have them
      );
    } catch (e) {
      print("[DateIdeaProvider] Error calling addDoneDateFromSuggestion: $e");
      // Optionally rethrow or handle error
    }
  } else {
    print("[DateIdeaProvider] Could not find suggestion. RHM points may not be added.");
  }
  // --- ✨ END OF NEW LOGIC ---

  // This part stays the same:
  await _dateIdeaService.markSuggestionAsDone(
    coupleId: coupleId,
    suggestionId: suggestionId,
  );

  await refreshSuggestions();
}

  Future<void> cancelSuggestion({
    required String coupleId,
    required String suggestionId,
    required String currentUserId,
    required String partnerId,
    required Future<void> Function(String receiverId, String message) sendPushNotification,
  }) async {
    if (coupleId.isEmpty) return;
    
    print('[DateIdeaProvider] Canceling suggestion: $suggestionId');
    
    await _dateIdeaService.markSuggestionAsDone(
      coupleId: coupleId,
      suggestionId: suggestionId,
    );
    
    await refreshSuggestions();
    
    await sendPushNotification(
      partnerId,
      "Your partner canceled the suggested date idea",
    );
  }

  void toggleLocation(String location) {
    if (selectedLocations.contains(location)) {
      selectedLocations.remove(location);
    } else {
      selectedLocations.add(location);
    }
    notifyListeners();
  }

  void selectVibe(String vibe) {
    if (selectedVibe == vibe) {
      selectedVibe = null;
    } else {
      selectedVibe = vibe;
    }
    notifyListeners();
  }

  void selectBudget(String budget) {
    if (selectedBudget == budget) {
      selectedBudget = null;
    } else {
      selectedBudget = budget;
    }
    notifyListeners();
  }

  void selectTime(String time) {
    if (selectedTime == time) {
      selectedTime = null;
    } else {
      selectedTime = time;
    }
    notifyListeners();
  }

  Future<void> generateDateIdea({required String userId, required String coupleId, BuildContext? context}) async {
    if (userId.isEmpty || coupleId.isEmpty) {
      return;
    }
    isLoading = true;
    generatedIdea = null;
    fallbackMessage = null;
    if (!disposed) {
      clearSuggestionTracking();
    }
    notifyListeners();

    final result = await _dateIdeaService.getFilteredDateIdea(
      locations: selectedLocations,
      vibe: selectedVibe,
      budget: selectedBudget,
      time: selectedTime,
    );
    if (result != null) {
      generatedIdea = result.idea;
      fallbackMessage = null;
    } else {
      fallbackMessage = null;
    }
    isLoading = false;
    notifyListeners();
  }

  void reset() {
    selectedLocations.clear();
    selectedVibe = null;
    selectedBudget = null;
    selectedTime = null;
    generatedIdea = null;
    isLoading = false;
    notifyListeners();
  }

  void setFilters({
    List<String>? locations,
    String? vibe,
    String? budget,
    String? time,
  }) {
    selectedLocations = locations ?? [];
    selectedVibe = vibe;
    selectedBudget = budget;
    selectedTime = time;
    notifyListeners();
  }

  Future<void> addFavorite(DateIdea idea, String userId) async {
    if (userId.isEmpty) {
      return;
    }
    await _db.collection('users').doc(userId).collection('favorites').doc(idea.id).set({
      'idea_id': idea.id,
      'idea_name': idea.ideaName,
      'category': idea.category,
      'description': idea.description,
      'what_you_ll_need': idea.whatYoullNeed,
      'preferences': idea.preferences,
      'favorited_at': FieldValue.serverTimestamp(),
    });
    await fetchFavorites(userId);
  }

  Future<void> removeFavorite(String ideaId, String userId) async {
    if (userId.isEmpty) {
      return;
    }
    await _db.collection('users').doc(userId).collection('favorites').doc(ideaId).delete();
    await fetchFavorites(userId);
  }

  Future<void> fetchFavorites(String userId) async {
    if (userId.isEmpty) {
      return;
    }
    isFavoritesLoading = true;
    notifyListeners();
    final snapshot = await _db.collection('users').doc(userId).collection('favorites').get();
    favoriteIdeas = snapshot.docs.map((doc) => DateIdea.fromFirestore(doc)).toList();
    isFavoritesLoading = false;
    notifyListeners();
  }

  bool isFavorite(String ideaId) {
    final result = favoriteIdeas.any((idea) => idea.id == ideaId);
    return result;
  }
  
  // ✨ MODIFIED: The dispose method now calls the new clear method and handles the disposed flag.
  @override
  void dispose() {
    disposed = true;
    clear();
    super.dispose();
  }

  DateIdea? getCurrentDateIdea() {
    return generatedIdea;
  }
}