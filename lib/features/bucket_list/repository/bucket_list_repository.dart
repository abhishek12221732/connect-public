import 'package:cloud_firestore/cloud_firestore.dart';
// REMOVE THIS LINE: import 'package:feelings/providers/user_provider.dart'; // No longer needed here

class BucketListRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _coupleId; // Store the coupleId once initialized

  // Constructor now requires coupleId
  BucketListRepository({required String coupleId}) : _coupleId = coupleId;

  // IMPORTANT: All methods below will now directly use _coupleId
  // They no longer need to call getCoupleId(userId) inside them.

  Future<void> addItem(String userId, String title, {
    bool isDateIdea = false,
    String? dateIdeaId,
    String? description,
    String? category,
    List<String>? whatYoullNeed,
  }) async {
    try {
      final docRef = _firestore
          .collection('couples')
          .doc(_coupleId)
          .collection('bucketList')
          .doc();

      final data = <String, dynamic>{
        'title': title,
        'completed': false,
        'createdBy': userId,
        'createdAt': FieldValue.serverTimestamp(),
        'isDateIdea': isDateIdea,
      };

      // Add date idea specific data if it's a date idea
      if (isDateIdea && dateIdeaId != null) {
        data['dateIdeaId'] = dateIdeaId;
        data['description'] = description;
        data['category'] = category;
        data['whatYoullNeed'] = whatYoullNeed;
      }

      await docRef.set(data);
    } catch (e) {
      throw Exception('Failed to add item: ${e.toString()}');
    }
  }

  Future<void> toggleItemCompletion(String itemId, bool completed) async { // userId not needed here
    try {
      // final coupleId = await getCoupleId(userId); // REMOVED
      // if (coupleId == null) throw Exception('No couple found for user'); // Redundant here

      await _firestore
          .collection('couples')
          .doc(_coupleId) // Use the stored _coupleId
          .collection('bucketList')
          .doc(itemId)
          .update({'completed': completed});
    } catch (e) {
      throw Exception('Failed to toggle completion: ${e.toString()}');
    }
  }

  Future<void> deleteItem(String itemId) async { // userId not needed here
    try {
      // final coupleId = await getCoupleId(userId); // REMOVED
      // if (coupleId == null) throw Exception('No couple found for user'); // Redundant here

      await _firestore
          .collection('couples')
          .doc(_coupleId) // Use the stored _coupleId
          .collection('bucketList')
          .doc(itemId)
          .delete();
    } catch (e) {
      throw Exception('Failed to delete item: ${e.toString()}');
    }
  }

  Stream<List<Map<String, dynamic>>> getBucketListStream() async* { // userId not needed here
    // No need for coupleId check here, as it's guaranteed by constructor
    yield* _firestore
        .collection('couples')
        .doc(_coupleId) // Use the stored _coupleId
        .collection('bucketList')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = doc.data();
            data['id'] = doc.id; // Add the document ID to the map

            // Convert Firestore Timestamp to Dart DateTime
            if (data.containsKey('createdAt') && data['createdAt'] is Timestamp) {
              data['createdAt'] = (data['createdAt'] as Timestamp).toDate();
            } else if (!data.containsKey('createdAt') || data['createdAt'] == null) {
              data['createdAt'] = DateTime.now(); // Fallback
            }
            return data;
          }).toList();
        });
    // Removed outer try-catch, stream errors are handled by the listener
  }

  Future<int> countUncheckedItems() async { // userId not needed here
    try {
      // No need for coupleId check here
      print(_coupleId);
      final snapshot = await _firestore
          .collection('couples')
          .doc(_coupleId) // Use the stored _coupleId
          .collection('bucketList')
          .where('completed', isEqualTo: false)
          .count()
          .get();

      return snapshot.count ?? 0;
    } catch (e) {
      throw Exception("Failed to count unchecked items: $e");
    }
  }

  // New: Search functionality
  Stream<List<Map<String, dynamic>>> searchItems(String query) async* { // userId not needed here
    // No need for coupleId check here
    yield* _firestore
        .collection('couples')
        .doc(_coupleId) // Use the stored _coupleId
        .collection('bucketList')
        .orderBy('title')
        .startAt([query]).endAt(['$query\uf8ff'])
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = doc.data();
            data['id'] = doc.id; // Add the document ID
            if (data.containsKey('createdAt') && data['createdAt'] is Timestamp) {
              data['createdAt'] = (data['createdAt'] as Timestamp).toDate();
            } else if (!data.containsKey('createdAt') || data['createdAt'] == null) {
              data['createdAt'] = DateTime.now();
            }
            return data;
          }).toList();
        });
    // Removed outer try-catch, stream errors are handled by the listener
  }

  Future<void> updateItem(String itemId, Map<String, dynamic> updates) async { // userId not needed here
    try {
      // No need for coupleId check here
      await _firestore
          .collection('couples')
          .doc(_coupleId) // Use the stored _coupleId
          .collection('bucketList')
          .doc(itemId)
          .update(updates);
    } catch (e) {
      throw Exception('Failed to update item: ${e.toString()}');
    }
  }
}
