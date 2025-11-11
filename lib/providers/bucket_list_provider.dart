// Your BucketListProvider.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:feelings/features/bucket_list/repository/bucket_list_repository.dart';
import 'package:feelings/features/rhm/repository/rhm_repository.dart';
import 'package:feelings/providers/done_dates_provider.dart';
import './dynamic_actions_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class BucketListProvider with ChangeNotifier {
  // ... (Properties _dynamicActionsProvider, _repository, _rhmRepository, etc. are unchanged) ...
  final DynamicActionsProvider _dynamicActionsProvider;
  BucketListProvider(this._dynamicActionsProvider);

  BucketListRepository? _repository;
  RhmRepository? _rhmRepository;
  StreamSubscription? _bucketListSubscription;
  DoneDatesProvider? _doneDatesProvider;

  List<Map<String, dynamic>> _bucketList = [];
  bool _isLoading = false;
  bool _isInitialized = false;
  String? _error;

  String? _userId;
  String? _coupleId;
  String _sortBy = 'date';
  String _filterBy = 'all';
  bool _showCompleted = false;

  // ... (Getters are unchanged) ...
  List<Map<String, dynamic>> get bucketList => _bucketList;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isInitialized => _isInitialized;
  String get sortBy => _sortBy;
  String get filterBy => _filterBy;
  bool get showCompleted => _showCompleted;
  List<Map<String, dynamic>> get filteredBucketList => _applyFiltersAndSorts();


  void setDoneDatesProvider(DoneDatesProvider provider) {
    // ... (unchanged)
    _doneDatesProvider = provider;
  }

  Future<void> initialize({
    required String coupleId,
    required String userId,
    required RhmRepository rhmRepository,
  }) async {
    if (_isInitialized) {
      debugPrint("[BucketListProvider] Already initialized. Skipping init.");
      return;
    }
    if (_isLoading) {
      debugPrint("[BucketListProvider] Already loading. Skipping init attempt.");
      return;
    }

    _userId = userId;
    _coupleId = coupleId;
    _rhmRepository = rhmRepository;
    
    _repository = BucketListRepository(coupleId: coupleId);
    
    await _loadPreferences();

    _isLoading = true;
    _error = null;
    notifyListeners();

    final Completer<void> completer = Completer<void>();

    try {
      _bucketListSubscription?.cancel(); 

      _bucketListSubscription = _repository!.getBucketListStream().listen(
        (items) {
          // ✨ --- [GUARD 1: ON-DATA] --- ✨
          if (FirebaseAuth.instance.currentUser == null) {
            debugPrint("[BucketListProvider] Event received, but user is logged out. Ignoring.");
            return;
          }

          debugPrint("[BucketListProvider] Stream data received. Items count: ${items.length}");
          _bucketList = items;
          _isLoading = false;
          _error = null;
          if (!_isInitialized) {
            _isInitialized = true;
            debugPrint("[BucketListProvider] Initialized successfully with first data.");
          }
          notifyListeners();

          if (!completer.isCompleted) {
            completer.complete();
          }
        },
        onError: (error) {
          // ✨ --- [GUARD 2: ON-ERROR] --- ✨
          if (error is FirebaseException && error.code == 'permission-denied') {
            if (FirebaseAuth.instance.currentUser == null) {
              debugPrint("[BucketListProvider] Safely caught permission-denied on listener during logout.");
            } else {
              debugPrint("[BucketListProvider] CRITICAL PERMISSION ERROR: $error");
              _error = error.toString();
            }
          } else {
            debugPrint("[BucketListProvider] Unexpected error: $error");
            _error = error.toString();
          }

          _bucketList = [];
          _isLoading = false;
          _isInitialized = false; 
          notifyListeners();
          if (!completer.isCompleted) {
            completer.completeError(error);
          }
        },
        onDone: () {
          debugPrint("[BucketListProvider] BucketList stream closed.");
        },
      );

      await completer.future;
      debugPrint("[BucketListProvider] Initialize method completed.");

    } catch (e) {
      debugPrint("[BucketListProvider] Error during initialization: $e");
      _bucketList = [];
      _isLoading = false;
      _error = e.toString();
      _isInitialized = false;
      notifyListeners();
    }
  }



  void clear() {
    // ... (unchanged)
    _bucketListSubscription?.cancel();
    _bucketListSubscription = null;
    _repository = null;
    _rhmRepository = null; 
    _doneDatesProvider = null;
    _bucketList = [];
    _isLoading = false;
    _isInitialized = false;
    _error = null;
    _userId = null;
    _coupleId = null; 
    _sortBy = 'date';
    _filterBy = 'all';
    _showCompleted = false;
    // notifyListeners();
    debugPrint("[BucketListProvider] Cleared and reset state.");
  }

  // ... (Preference methods _loadPreferences, _savePreferences, resetPreferences, getCurrentPreferences are unchanged) ...
    Future<void> _loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _sortBy = prefs.getString('bucket_list_sort_by') ?? 'date';
      _filterBy = prefs.getString('bucket_list_filter_by') ?? 'all';
      _showCompleted = prefs.getBool('bucket_list_show_completed') ?? false;
      debugPrint("[BucketListProvider] Loaded preferences: sortBy=$_sortBy, filterBy=$_filterBy, showCompleted=$_showCompleted");
    } catch (e) {
      debugPrint("[BucketListProvider] Error loading preferences: $e");
    }
  }

  Future<void> _savePreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('bucket_list_sort_by', _sortBy);
      await prefs.setString('bucket_list_filter_by', _filterBy);
      await prefs.setBool('bucket_list_show_completed', _showCompleted);
      debugPrint("[BucketListProvider] Saved preferences: sortBy=$_sortBy, filterBy=$_filterBy, showCompleted=$_showCompleted");
    } catch (e) {
      debugPrint("[BucketListProvider] Error saving preferences: $e");
    }
  }
  
  Future<void> resetPreferences() async {
    _sortBy = 'date';
    _filterBy = 'all';
    _showCompleted = false;
    await _savePreferences();
    notifyListeners();
    debugPrint("[BucketListProvider] Preferences reset to defaults");
  }

  Map<String, dynamic> getCurrentPreferences() {
    return {
      'sortBy': _sortBy,
      'filterBy': _filterBy,
      'showCompleted': _showCompleted,
    };
  }

  // CRUD Operations
  // ✨ [MODIFY] Update addItem to check frequency
  Future<void> addItem(String title, {
    bool isDateIdea = false,
    String? dateId, // Renamed from dateIdeaId for clarity if needed
    String? description,
    String? category,
    List<String>? whatYoullNeed,
  }) async {
    if (_repository == null || _userId == null || _coupleId == null || _rhmRepository == null) {
      debugPrint("[BucketListProvider] Cannot add item: Not initialized or missing IDs/Repo.");
      return;
    }
    try {
      // 1. Original call
      await _repository!.addItem(
        _userId!,
        title,
        isDateIdea: isDateIdea,
        dateIdeaId: dateId, // Use the parameter name
        description: description,
        category: category,
        whatYoullNeed: whatYoullNeed,
      );
      _dynamicActionsProvider.recordBucketListItemAdded();

      // ✨ [ADD] RHM Frequency Check and Logging Logic
      const String actionType = 'bucket_list_added';
      const Duration frequencyLimit = Duration(days: 7); // Once per 7 days
      
      try {
        final lastActionTime = await _rhmRepository!.getLastActionTimestamp(_coupleId!, actionType);
        final now = DateTime.now();
        
        // Check if enough time has passed or if it's the first time
        if (lastActionTime == null || now.difference(lastActionTime) >= frequencyLimit) {
          await _rhmRepository!.logAction(
            coupleId: _coupleId!,
            userId: _userId!,
            actionType: actionType,
            points: 1, // +1 for adding a new item
          );
          debugPrint("[BucketListProvider] Logged +1 RHM for $actionType");
        } else {
           debugPrint("[BucketListProvider] Skipped RHM logging for $actionType (frequency limit)");
        }
      } catch (e) {
        debugPrint("[BucketListProvider] Error checking/logging RHM action for new item: $e");
      }

    } catch (e) {
      debugPrint("[BucketListProvider] Error adding item: $e");
    }
  }

  // ✨ [MODIFY] Update toggleItemCompletion to check frequency
  Future<void> toggleItemCompletion(String itemId, bool completed) async {
    if (_repository == null || _rhmRepository == null || _coupleId == null || _userId == null) {
      debugPrint("[BucketListProvider] Cannot toggle item: Not initialized or missing IDs/Repo.");
      return;
    }
    try {
      // 1. Original call
      await _repository!.toggleItemCompletion(itemId, completed);

      // ✨ [ADD] RHM Frequency Check and Logging Logic (only when completing)
      if (completed) {
        const String actionType = 'bucket_list_completed';
        const Duration frequencyLimit = Duration(days: 7); // Once per 7 days

        try {
          final lastActionTime = await _rhmRepository!.getLastActionTimestamp(_coupleId!, actionType);
          final now = DateTime.now();

          if (lastActionTime == null || now.difference(lastActionTime) >= frequencyLimit) {
            await _rhmRepository!.logAction(
              coupleId: _coupleId!,
              userId: _userId!,
              actionType: actionType,
              points: 5, // +5 for completing
              sourceId: itemId,
            );
             debugPrint("[BucketListProvider] Logged +5 RHM for $actionType");
          } else {
             debugPrint("[BucketListProvider] Skipped RHM logging for $actionType (frequency limit)");
          }
        } catch (e) {
          debugPrint("[BucketListProvider] Error checking/logging RHM action for item completion: $e");
        }
      }

      // 2. Original DoneDates logic
      if (completed && _doneDatesProvider != null) {
        // ... (DoneDates logic remains the same) ...
        final item = _bucketList.firstWhere(
          (item) => item['id'] == itemId,
          orElse: () => {},
        );
        
        if (item.isNotEmpty && item['isDateIdea'] == true) {
          await _doneDatesProvider!.addDoneDateFromBucketList(
            dateIdeaId: item['dateIdeaId'] ?? '',
            title: item['title'] ?? '',
            description: item['description'] ?? '',
            bucketListItemId: itemId,
            completedBy: _userId ?? '',
            actualDate: DateTime.now(),
          );
        }
      }
    } catch (e) {
      debugPrint("[BucketListProvider] Error toggling item completion: $e");
    }
  }

  // ... (deleteItem, updateItem, getUncheckedCount, searchItems methods are unchanged) ...
    Future<void> deleteItem(String itemId) async {
    if (_repository == null) {
      debugPrint("[BucketListProvider] Cannot delete item: Not initialized.");
      return;
    }
    try {
      await _repository!.deleteItem(itemId);
    } catch (e) {
      debugPrint("[BucketListProvider] Error deleting item: $e");
    }
  }

  Future<void> updateItem(String itemId, Map<String, dynamic> data) async {
    if (_repository == null) {
      debugPrint("[BucketListProvider] Cannot update item: Not initialized.");
      return;
    }
    try {
      await _repository!.updateItem(itemId, data);
    } catch (e) {
      debugPrint("[BucketListProvider] Error updating item: $e");
    }
  }

  Future<int> getUncheckedCount() async {
    if (!_isInitialized || _repository == null) {
      debugPrint("[BucketListProvider] getUncheckedCount called before init, returning 0.");
      return 0;
    }
    
    try {
      return await _repository!.countUncheckedItems();
    } catch (e) {
      debugPrint("[BucketListProvider] Error fetching unchecked count: $e");
      return 0;
    }
  }

  Stream<List<Map<String, dynamic>>> searchItems(String query) {
    if (_repository == null) {
      debugPrint("[BucketListProvider] Cannot search items: Not initialized.");
      return Stream.value([]);
    }
    return _repository!.searchItems(query);
  }

  // ... (Filters and Sorting methods setSortBy, setFilterBy, setShowCompleted, _applyFiltersAndSorts are unchanged) ...
  void setSortBy(String value) {
    if (_sortBy != value) {
      _sortBy = value;
      notifyListeners();
      _savePreferences();
    }
  }

  void setFilterBy(String value) {
    if (_filterBy != value) {
      _filterBy = value;
      notifyListeners();
      _savePreferences();
    }
  }

  void setShowCompleted(bool value) {
    if (_showCompleted != value) {
      _showCompleted = value;
      notifyListeners();
      _savePreferences();
    }
  }

  List<Map<String, dynamic>> _applyFiltersAndSorts() {
    final userId = _userId;
    if (userId == null) return [];

    var list = _bucketList.where((item) {
      if (!_showCompleted && item['completed'] == true) return false;
      if (_filterBy == 'mine') return item['createdBy'] == userId;
      if (_filterBy == 'partner') return item['createdBy'] != userId;
      return true;
    }).toList();

    if (_sortBy == 'alpha') {
      list.sort((a, b) => (a['title'] ?? '').compareTo(b['title'] ?? ''));
    } else {
      list.sort((a, b) {
        final aDate = (a['createdAt'] is DateTime) ? a['createdAt'] : DateTime(0);
        final bDate = (b['createdAt'] is DateTime) ? b['createdAt'] : DateTime(0);
        return bDate.compareTo(aDate);
      });
    }

    list.sort((a, b) {
      final aDone = a['completed'] == true;
      final bDone = b['completed'] == true;
      return aDone == bDone ? 0 : (aDone ? 1 : -1);
    });

    return list;
  }


  @override
  void dispose() {
    // ... (unchanged)
    debugPrint("[BucketListProvider] Disposing.");
    clear();
    super.dispose();
  }
}