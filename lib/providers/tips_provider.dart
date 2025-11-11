import 'dart:async';
import 'package:flutter/material.dart';
import '../features/tips/models/tip_model.dart';
import '../features/tips/models/daily_tip_model.dart';
import '../features/tips/services/tip_service.dart';
import '../features/tips/repository/daily_tip_repository.dart';
import '../features/check_in/models/check_in_model.dart';
import '../features/check_in/repository/check_in_repository.dart';

class TipsProvider with ChangeNotifier {
  final TipService _tipService = TipService();
  final CheckInRepository _checkInRepository = CheckInRepository();
  final DailyTipRepository _dailyTipRepository = DailyTipRepository();
  
  TipModel? _currentTip;
  bool _isLoading = false;
  
  // User context
  String? _userId;
  Map<String, dynamic>? _userData;
  Map<String, dynamic>? _partnerData;
  List<CheckInModel> _recentCheckIns = [];

  // Getters
  TipModel? get currentTip => _currentTip;
  bool get isLoading => _isLoading;
  String? get userId => _userId;

  // ✨ ADDED: The clear method to reset all state on logout
  void clear() {
    _currentTip = null;
    _isLoading = false;
    _userId = null;
    _userData = null;
    _partnerData = null;
    _recentCheckIns = [];
    // notifyListeners();
    // print("[TipsProvider] Cleared and reset state.");
  }

  /// Initialize the provider with user context
  Future<void> initialize({
    required String userId,
    required String coupleId,
    required Map<String, dynamic> userData,
    required Map<String, dynamic>? partnerData,
  }) async {
    _userId = userId;
    _userData = userData;
    _partnerData = partnerData;
    
    await _loadRecentCheckIns();
    await _fetchOrGenerateDailyTip();
  }

  /// Load recent check-ins for tip generation
  Future<void> _loadRecentCheckIns() async {
    if (_userId == null) return;
    
    try {
      _recentCheckIns = await _checkInRepository.getRecentCompletedCheckIns(_userId!, limit: 5);
    } catch (e) {
      // print('Error loading recent check-ins: $e');
      _recentCheckIns = [];
    }
  }

  /// Main logic for fetching or generating the Tip of the Day
  Future<void> _fetchOrGenerateDailyTip() async {
    if (_userId == null || _userData == null) return;

    _isLoading = true;
    notifyListeners();

    try {
      final storedDailyTip = await _dailyTipRepository.getDailyTip(_userId!);
      if (storedDailyTip != null && _isToday(storedDailyTip.date)) {
        // print("🔍 [TipsProvider] Valid tip for today found. Displaying stored tip.");
        _currentTip = storedDailyTip.tip;
      } else {
        // print("🔍 [TipsProvider] No valid tip for today. Generating a new one.");
        await _generateAndSaveNewDailyTip();
      }
    } catch (e) {
      // print('Error fetching or generating daily tip: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  /// Generates a new tip, sets it, and saves it to Firestore.
  Future<void> _generateAndSaveNewDailyTip() async {
    final userMood = _userData!['mood'] ?? 'Neutral';
    final partnerMood = _partnerData?['mood'];

    final tipPool = _tipService.generateDynamicTips(
      userMood: userMood,
      partnerMood: partnerMood,
      recentCheckIns: _recentCheckIns,
      userData: _userData,
      partnerData: _partnerData,
    );

    if (tipPool.isNotEmpty) {
      final newTip = tipPool.first;
      _currentTip = newTip;
      
      final dailyTip = DailyTip(tip: newTip, date: DateTime.now());
      await _dailyTipRepository.saveDailyTip(_userId!, dailyTip);
      // print("🔍 [TipsProvider] New tip generated and saved for today.");
    } else {
      _currentTip = null;
      // print("🔍 [TipsProvider] Could not generate any tips.");
    }
  }

  /// Update user context (called when mood or other data changes)
  Future<void> updateUserContext({
    Map<String, dynamic>? userData,
    Map<String, dynamic>? partnerData,
  }) async {
    bool moodChanged = false;
    if (userData != null && _userData?['mood'] != userData['mood']) {
      moodChanged = true;
    }
    if (partnerData != null && _partnerData?['mood'] != partnerData['mood']) {
      moodChanged = true;
    }
    
    if (userData != null) _userData = userData;
    if (partnerData != null) _partnerData = partnerData;
    
    if (moodChanged) {
      await _loadRecentCheckIns();
      await _fetchOrGenerateDailyTip();
    }
  }
  
  /// Helper to check if a date is today
  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month && date.day == now.day;
  }

  // ✨ MODIFIED: The dispose method now calls the new clear method.
  @override
  void dispose() {
    clear();
    super.dispose();
  }
}