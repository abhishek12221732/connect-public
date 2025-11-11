import 'package:cloud_firestore/cloud_firestore.dart';

class DoneDatesRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _coupleId;

  DoneDatesRepository({required String coupleId}) : _coupleId = coupleId;

  String get coupleId => _coupleId;

  /// Add a completed date to the done dates collection
  Future<void> addDoneDate({
    required String dateIdeaId,
    required String title,
    required String description,
    required String source, // 'suggestion', 'calendar', 'bucket_list'
    required String sourceId,
    required String completedBy,
    DateTime? actualDate,
    String? notes,
    int? rating,
    List<String>? photos,
  }) async {
    try {
      await _firestore
          .collection('couples')
          .doc(_coupleId)
          .collection('doneDates')
          .add({
        'dateIdeaId': dateIdeaId,
        'title': title,
        'description': description,
        'source': source,
        'sourceId': sourceId,
        'completedBy': completedBy,
        'completedAt': FieldValue.serverTimestamp(),
        'actualDate': actualDate != null ? Timestamp.fromDate(actualDate) : null,
        'notes': notes,
        'rating': rating,
        'photos': photos ?? [],
      });
    } catch (e) {
      throw Exception('Failed to add done date: ${e.toString()}');
    }
  }

  /// Get all done dates for a couple
  Stream<List<Map<String, dynamic>>> getDoneDatesStream() {
    return _firestore
        .collection('couples')
        .doc(_coupleId)
        .collection('doneDates')
        .orderBy('completedAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = doc.data();
            data['id'] = doc.id;
            
            // Convert timestamps to DateTime
            if (data['completedAt'] is Timestamp) {
              data['completedAt'] = (data['completedAt'] as Timestamp).toDate();
            }
            if (data['actualDate'] is Timestamp) {
              data['actualDate'] = (data['actualDate'] as Timestamp).toDate();
            }
            
            return data;
          }).toList();
        });
  }

  /// Get done dates by source
  Stream<List<Map<String, dynamic>>> getDoneDatesBySource(String source) {
    return _firestore
        .collection('couples')
        .doc(_coupleId)
        .collection('doneDates')
        .where('source', isEqualTo: source)
        .orderBy('completedAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = doc.data();
            data['id'] = doc.id;
            
            if (data['completedAt'] is Timestamp) {
              data['completedAt'] = (data['completedAt'] as Timestamp).toDate();
            }
            if (data['actualDate'] is Timestamp) {
              data['actualDate'] = (data['actualDate'] as Timestamp).toDate();
            }
            
            return data;
          }).toList();
        });
  }

  /// Update a done date (e.g., add notes, rating, photos)
  Future<void> updateDoneDate(String doneDateId, Map<String, dynamic> updates) async {
    try {
      await _firestore
          .collection('couples')
          .doc(_coupleId)
          .collection('doneDates')
          .doc(doneDateId)
          .update(updates);
    } catch (e) {
      throw Exception('Failed to update done date: ${e.toString()}');
    }
  }

  /// Delete a done date
  Future<void> deleteDoneDate(String doneDateId) async {
    try {
      await _firestore
          .collection('couples')
          .doc(_coupleId)
          .collection('doneDates')
          .doc(doneDateId)
          .delete();
    } catch (e) {
      throw Exception('Failed to delete done date: ${e.toString()}');
    }
  }

  /// Check if a date idea has been completed
  Future<bool> isDateIdeaCompleted(String dateIdeaId) async {
    try {
      final snapshot = await _firestore
          .collection('couples')
          .doc(_coupleId)
          .collection('doneDates')
          .where('dateIdeaId', isEqualTo: dateIdeaId)
          .limit(1)
          .get();
      
      return snapshot.docs.isNotEmpty;
    } catch (e) {
      throw Exception('Failed to check if date idea is completed: ${e.toString()}');
    }
  }

  /// Get statistics about done dates
  Future<Map<String, dynamic>> getDoneDatesStats() async {
    try {
      final snapshot = await _firestore
          .collection('couples')
          .doc(_coupleId)
          .collection('doneDates')
          .get();
      
      final totalDates = snapshot.docs.length;
      final bySource = <String, int>{};
      final byMonth = <String, int>{};
      
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final source = data['source'] as String? ?? 'unknown';
        bySource[source] = (bySource[source] ?? 0) + 1;
        
        if (data['actualDate'] is Timestamp) {
          final date = (data['actualDate'] as Timestamp).toDate();
          final monthKey = '${date.year}-${date.month.toString().padLeft(2, '0')}';
          byMonth[monthKey] = (byMonth[monthKey] ?? 0) + 1;
        }
      }
      
      return {
        'totalDates': totalDates,
        'bySource': bySource,
        'byMonth': byMonth,
      };
    } catch (e) {
      throw Exception('Failed to get done dates stats: ${e.toString()}');
    }
  }
} 
