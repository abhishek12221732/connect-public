import 'dart:async';
import 'package:flutter/material.dart';
import 'package:feelings/features/rhm/models/rhm_action.dart';
import 'package:feelings/features/rhm/repository/rhm_repository.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RhmDetailProvider with ChangeNotifier {
  final RhmRepository _rhmRepository;
  StreamSubscription? _actionsSubscription;

  List<RhmAction> _recentActions = [];
  bool _isLoading = false;
  String? _error;

  String _userId = '';
  String _partnerId = '';

  List<RhmAction> get recentActions => _recentActions;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // --- Calculated Getters ---
  
  /// Total points earned by the current user in the last 7 days
  int get userScore {
    return _recentActions
        .where((action) => action.userId == _userId)
        .fold(0, (sum, action) => sum + action.points);
  }

  /// Total points earned by the partner in the last 7 days
  int get partnerScore {
     return _recentActions
        .where((action) => action.userId == _partnerId)
        .fold(0, (sum, action) => sum + action.points);
  }

  /// Total points (same as the score calculation)
  int get totalActivityPoints {
    return _recentActions.fold(0, (sum, action) => sum + action.points);
  }

  RhmDetailProvider({required RhmRepository rhmRepository})
      : _rhmRepository = rhmRepository;

  void initialize(String coupleId, String userId, String partnerId) {
    if (_actionsSubscription != null) {
      clear(); // Clear old listeners if any
    }
    
    _userId = userId;
    _partnerId = partnerId;
    _isLoading = true;
    notifyListeners();

    _actionsSubscription = _rhmRepository.getRecentActionsStream(coupleId).listen(
      (actions) {
        // ✨ --- [GUARD 1: ON-DATA] --- ✨
        if (FirebaseAuth.instance.currentUser == null) {
          debugPrint("[RhmDetailProvider] Event received, but user is logged out. Ignoring.");
          return;
        }

        _recentActions = actions;
        _isLoading = false;
        _error = null;
        notifyListeners();
      },
      onError: (error) {
        // ✨ --- [GUARD 2: ON-ERROR] --- ✨
        if (error is FirebaseException && error.code == 'permission-denied') {
          if (FirebaseAuth.instance.currentUser == null) {
            debugPrint("[RhmDetailProvider] Safely caught permission-denied on listener during logout.");
          } else {
            debugPrint("[RhmDetailProvider] CRITICAL PERMISSION ERROR: $error");
            _error = "Failed to load activity: $error";
          }
        } else {
          debugPrint("[RhmDetailProvider] Unexpected error: $error");
          _error = "Failed to load activity: $error";
        }
        _isLoading = false;
        notifyListeners();
      },
    );
  }



  void clear() {
    _actionsSubscription?.cancel();
    _actionsSubscription = null;
    _recentActions = [];
    _isLoading = false;
    _error = null;
    _userId = '';
    _partnerId = '';
    // notifyListeners();
  }

  @override
  void dispose() {
    clear();
    super.dispose();
  }
}
