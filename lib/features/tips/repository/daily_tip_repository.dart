import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/daily_tip_model.dart';

class DailyTipRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Fetches the stored daily tip for a user.
  Future<DailyTip?> getDailyTip(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      final data = doc.data();
      if (data != null && data.containsKey('dailyTip')) {
        return DailyTip.fromMap(data['dailyTip']);
      }
      return null;
    } catch (e) {
      print('Error fetching daily tip: $e');
      return null;
    }
  }

  /// Saves or updates the daily tip for a user.
  Future<void> saveDailyTip(String userId, DailyTip dailyTip) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'dailyTip': dailyTip.toMap(),
      });
    } catch (e) {
      print('Error saving daily tip: $e');
      // Decide if you want to throw an exception or fail silently
    }
  }
}