import 'package:feelings/features/date_night/repository/done_dates_repository.dart';
import 'package:feelings/features/date_night/models/date_idea.dart';

class DoneDatesService {
  final DoneDatesRepository _repository;

  DoneDatesService({required DoneDatesRepository repository}) : _repository = repository;

  /// Mark a suggested date idea as done
  Future<void> markSuggestionAsDone({
    required DateIdea dateIdea,
    required String suggestionId,
    required String completedBy,
    DateTime? actualDate,
    String? notes,
    int? rating,
  }) async {
    await _repository.addDoneDate(
      dateIdeaId: dateIdea.id,
      title: dateIdea.ideaName,
      description: dateIdea.description,
      source: 'suggestion',
      sourceId: suggestionId,
      completedBy: completedBy,
      actualDate: actualDate ?? DateTime.now(),
      notes: notes,
      rating: rating,
    );
  }

  /// Mark a calendar event as done (when event date passes)
  Future<void> markCalendarEventAsDone({
    required DateIdea dateIdea,
    required String eventId,
    required String completedBy,
    required DateTime eventDate,
    String? notes,
    int? rating,
  }) async {
    await _repository.addDoneDate(
      dateIdeaId: dateIdea.id,
      title: dateIdea.ideaName,
      description: dateIdea.description,
      source: 'calendar',
      sourceId: eventId,
      completedBy: completedBy,
      actualDate: eventDate,
      notes: notes,
      rating: rating,
    );
  }

  /// Mark a bucket list item as done (if it's a date idea)
  Future<void> markBucketListItemAsDone({
    required String bucketListItemId,
    required String title,
    required String completedBy,
    String? dateIdeaId,
    String? description,
    DateTime? actualDate,
    String? notes,
    int? rating,
  }) async {
    // Only add to done dates if it's actually a date idea
    if (dateIdeaId != null && description != null) {
      await _repository.addDoneDate(
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
    }
  }

  /// Check if a date idea has been completed
  Future<bool> isDateIdeaCompleted(String dateIdeaId) async {
    return await _repository.isDateIdeaCompleted(dateIdeaId);
  }

  /// Get all done dates
  Stream<List<Map<String, dynamic>>> getDoneDatesStream() {
    return _repository.getDoneDatesStream();
  }

  /// Get done dates by source
  Stream<List<Map<String, dynamic>>> getDoneDatesBySource(String source) {
    return _repository.getDoneDatesBySource(source);
  }

  /// Update a done date
  Future<void> updateDoneDate(String doneDateId, Map<String, dynamic> updates) async {
    await _repository.updateDoneDate(doneDateId, updates);
  }

  /// Delete a done date
  Future<void> deleteDoneDate(String doneDateId) async {
    await _repository.deleteDoneDate(doneDateId);
  }

  /// Get statistics about done dates
  Future<Map<String, dynamic>> getStats() async {
    return await _repository.getDoneDatesStats();
  }
} 
