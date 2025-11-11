import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/date_idea.dart';

class DateIdeaResult {
  final DateIdea idea;
  final bool isFallback;
  final bool isLocationFallback;
  DateIdeaResult({required this.idea, this.isFallback = false, this.isLocationFallback = false});
}

class DateIdeaService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final _random = Random();

  /// Main function to get a filtered date idea with fallback strategy.
  Future<DateIdeaResult?> getFilteredDateIdea({
    List<String>? locations,
    String? vibe,
    String? budget,
    String? time,
  }) async {
    try {
      // Attempt 1: All filters
      DateIdea? idea = await _fetchAndFilter(
        locations: locations,
        vibe: vibe,
        budget: budget,
        time: time,
      );
      if (idea != null) return DateIdeaResult(idea: idea);

      // Attempt 2: Location + Vibe
      idea = await _fetchAndFilter(
        locations: locations,
        vibe: vibe,
      );
      if (idea != null) return DateIdeaResult(idea: idea, isLocationFallback: true);

      // Attempt 3: Only location filter
      idea = await _fetchAndFilter(locations: locations);
      if (idea != null) {
        return DateIdeaResult(idea: idea, isLocationFallback: true);
      }

      // Attempt 4: Fallback to any random idea
      final fallbackSnapshot = await _db.collection('dateIdeas').get();
      if (fallbackSnapshot.docs.isNotEmpty) {
        final randomDoc = fallbackSnapshot.docs[_random.nextInt(fallbackSnapshot.docs.length)];
        return DateIdeaResult(idea: DateIdea.fromFirestore(randomDoc), isFallback: true);
      }
    } catch (e) {
      // Remove all print and debugPrint statements
    }

    return null;
  }

  /// Internal query builder and filter logic
  Future<DateIdea?> _fetchAndFilter({
    List<String>? locations,
    String? vibe,
    String? budget,
    String? time,
  }) async {
    try {
      Query query = _db.collection('dateIdeas');

      if (budget != null && budget.isNotEmpty) {
        query = query.where('preferences.budget', isEqualTo: budget);
      }

      if (time != null && time.isNotEmpty) {
        query = query.where('preferences.time', isEqualTo: time);
      }

      if (locations != null && locations.isNotEmpty) {
        query = query.where('preferences.location', arrayContainsAny: locations);
      }

      if (vibe != null && vibe.isNotEmpty) {
        query = query.where('preferences.vibe', isEqualTo: vibe);
      }

      final querySnapshot = await query.get();
      if (querySnapshot.docs.isEmpty) return null;

      final ideas = querySnapshot.docs.map((doc) => DateIdea.fromFirestore(doc)).toList();
      return ideas.isNotEmpty ? ideas[_random.nextInt(ideas.length)] : null;
    } catch (e) {
      // Remove all print and debugPrint statements
      return null;
    }
  }

  /// Suggest a date idea to partner (add to Firestore)
  Future<void> suggestDateIdea({
    required String coupleId,
    required String dateIdeaId,
    required String ideaName,
    required String description,
    required String suggestedBy,
    required String suggestedTo,
  }) async {
    print('[DateIdeaService] Suggesting date idea to Firestore: $ideaName');
    try {
      await _db
          .collection('couples')
          .doc(coupleId)
          .collection('suggestedDateIdeas')
          .doc('suggestion')
          .set({
        'dateIdeaId': dateIdeaId,
        'ideaName': ideaName,
        'description': description,
        'suggestedBy': suggestedBy,
        'suggestedTo': suggestedTo,
        'status': 'pending',
        'timestamp': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true)); // Changed to merge: true to allow updates
      print('[DateIdeaService] Successfully suggested date idea to Firestore');
    } catch (e) {
      print('[DateIdeaService] Error suggesting date idea: $e');
      rethrow;
    }
  }

  /// Stream suggestions for a couple (single suggestion document)
  Stream<List<Map<String, dynamic>>> getSuggestionsStream(String coupleId) {
    print('[DateIdeaService] Setting up suggestions stream for coupleId: $coupleId');
    return _db
        .collection('couples')
        .doc(coupleId)
        .collection('suggestedDateIdeas')
        .doc('suggestion')
        .snapshots()
        .map((doc) {
          print('[DateIdeaService] Stream snapshot received: exists=${doc.exists}');
          if (doc.exists) {
            final data = doc.data()!;
            data['id'] = doc.id;
            print('[DateIdeaService] Stream data: $data');
            return [data];
          } else {
            print('[DateIdeaService] Stream: document does not exist');
            return <Map<String, dynamic>>[];
          }
        })
        .handleError((error) {
          print('[DateIdeaService] Stream error: $error');
          return <Map<String, dynamic>>[];
        });
  }

  /// Mark a suggestion as done
  Future<void> markSuggestionAsDone({
    required String coupleId,
    required String suggestionId,
  }) async {
    await _db
        .collection('couples')
        .doc(coupleId)
        .collection('suggestedDateIdeas')
        .doc(suggestionId)
        .update({'status': 'done'});
  }

  /// Fetch a date idea by ID
  Future<DateIdea?> getDateIdeaById(String dateIdeaId) async {
    try {
      final doc = await _db.collection('dateIdeas').doc(dateIdeaId).get();
      if (doc.exists) {
        return DateIdea.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      print('[DateIdeaService] Error fetching date idea by ID: $e');
      return null;
    }
  }
}
