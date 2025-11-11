import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/tip_model.dart';

class TipsRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Save a tip to Firestore (for future use)
  Future<void> saveTip(TipModel tip) async {
    try {
      await _firestore.collection('tips').doc(tip.id).set(tip.toMap());
    } catch (e) {
      throw Exception('Error saving tip: $e');
    }
  }

  /// Get tips by category from Firestore (for future use)
  Future<List<TipModel>> getTipsByCategory(String category) async {
    try {
      final querySnapshot = await _firestore
          .collection('tips')
          .where('category', isEqualTo: category)
          .get();
      
      return querySnapshot.docs
          .map((doc) => TipModel.fromMap(doc.data()))
          .toList();
    } catch (e) {
      throw Exception('Error fetching tips by category: $e');
    }
  }

  /// Get all tips from Firestore (for future use)
  Future<List<TipModel>> getAllTips() async {
    try {
      final querySnapshot = await _firestore.collection('tips').get();
      
      return querySnapshot.docs
          .map((doc) => TipModel.fromMap(doc.data()))
          .toList();
    } catch (e) {
      throw Exception('Error fetching all tips: $e');
    }
  }

  /// Save user tip interaction (for future analytics)
  Future<void> saveTipInteraction({
    required String userId,
    required String tipId,
    required String interactionType, // 'viewed', 'clicked', 'dismissed'
  }) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('tip_interactions')
          .add({
        'tipId': tipId,
        'interactionType': interactionType,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error saving tip interaction: $e');
      // Don't throw here as this is not critical
    }
  }
} 
