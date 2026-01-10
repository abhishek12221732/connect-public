import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/app_status_model.dart'; // Ensure correct import

class AppConfigService with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  StreamSubscription<DocumentSnapshot>? _statusSubscription;
  AppStatusModel _appStatus = AppStatusModel.empty();

  AppStatusModel get appStatus => _appStatus;

  // Singleton pattern for easy access (optional, but providers are better)
  // We will likely use Provider to inject this, but keeping a static instance can be handy for non-context checks.
  
  void initialize() {
    _listenToAppStatus();
  }

  void _listenToAppStatus() {
    _statusSubscription?.cancel();
    debugPrint("🌐 [AppConfig] Listening for global alerts...");
    
    _statusSubscription = _firestore
        .collection('app_config')
        .doc('status')
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists) {
        final newStatus = AppStatusModel.fromSnapshot(snapshot);
        
        // Only notify if something actually changed (Basic equality check optimization)
        if (newStatus.isActive != _appStatus.isActive || 
            newStatus.message != _appStatus.message ||
            newStatus.isBlocking != _appStatus.isBlocking) {
             debugPrint("🌐 [AppConfig] Update received: Blocking=${newStatus.isBlocking}, Msg=${newStatus.message}");
             _appStatus = newStatus;
             notifyListeners();
        }
      } else {
        // Doc doesn't exist, assume everything is fine
        if (_appStatus.isActive) {
          _appStatus = AppStatusModel.empty();
          notifyListeners();
        }
      }
    }, onError: (e) {
      debugPrint("❌ [AppConfig] Error listening to status: $e");
    });
  }

  @override
  void dispose() {
    _statusSubscription?.cancel();
    super.dispose();
  }
}
