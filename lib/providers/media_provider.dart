import 'dart:async'; // ✨ ADDED for StreamSubscription
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:feelings/features/media/repository/media_repository.dart';
import 'package:feelings/features/media/services/local_storage_helper.dart';
import './dynamic_actions_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MediaProvider extends ChangeNotifier {
  final DynamicActionsProvider _dynamicActionsProvider;
  MediaProvider(this._dynamicActionsProvider);

  final MediaRepository _mediaRepository = MediaRepository();
  bool _isLoading = false;
  bool _isUploading = false;
  double _uploadProgress = 0.0;
  String? _uploadError;
  
  // Cache for loaded images to prevent re-loading
  final Map<String, File> _imageCache = {};
  
  // Cache for memories list to prevent unnecessary rebuilds
  List<Map<String, dynamic>> _memoriesCache = [];
  bool _hasInitialized = false;

  // ✨ ADDED: Stream subscription to manage the listener
  StreamSubscription? _memoriesSubscription;

  // Property to hold the temporary memory data for the UI
  Map<String, dynamic>? optimisticMemory;

  bool get isLoading => _isLoading;
  bool get isUploading => _isUploading;
  double get uploadProgress => _uploadProgress;
  String? get uploadError => _uploadError;
  List<Map<String, dynamic>> get memoriesCache => _memoriesCache;
  bool get hasInitialized => _hasInitialized;

  // ✨ ADDED: The clear method to reset all state on logout
  void clear() {
    _memoriesSubscription?.cancel();
    _isLoading = false;
    _isUploading = false;
    _uploadProgress = 0.0;
    _uploadError = null;
    _imageCache.clear();
    _memoriesCache = [];
    _hasInitialized = false;
    optimisticMemory = null;
    // notifyListeners();
    print("[MediaProvider] Cleared and reset state.");
  }

  File? getCachedImage(String imageId) {
    return _imageCache[imageId];
  }

  void cacheImage(String imageId, File imageFile) {
    _imageCache[imageId] = imageFile;
  }

  void initializeMemoriesStream(String coupleId) {
    if (!_hasInitialized) {
      _memoriesSubscription?.cancel();
      _memoriesSubscription = _mediaRepository.fetchMedia(coupleId).listen(
        (memories) {
          // ✨ --- [GUARD 1: ON-DATA] --- ✨
          if (FirebaseAuth.instance.currentUser == null) {
            debugPrint("[MediaProvider] Event received, but user is logged out. Ignoring.");
            return;
          }

          _memoriesCache = memories;
          _hasInitialized = true;
          notifyListeners();
        },
        onError: (error) {
          // ✨ --- [GUARD 2: ON-ERROR] --- ✨
          if (error is FirebaseException && error.code == 'permission-denied') {
            if (FirebaseAuth.instance.currentUser == null) {
              debugPrint("[MediaProvider] Safely caught permission-denied on listener during logout.");
            } else {
              debugPrint("[MediaProvider] CRITICAL PERMISSION ERROR: $error");
            }
          } else {
            debugPrint("[MediaProvider] Unexpected error: $error");
          }
        },
      );
    }
  }

  set isLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _updateUploadProgress(double progress) {
    _uploadProgress = progress;
    notifyListeners();
  }

  void _clearUploadState() {
    _isUploading = false;
    _uploadProgress = 0.0;
    _uploadError = null;
    notifyListeners();
  }

  Future<void> uploadMedia(String coupleId, File imageFile, String text, String userId) async {
    final tempId = 'optimistic_${DateTime.now().millisecondsSinceEpoch}';
    optimisticMemory = {
      'docId': tempId,
      'imageId': imageFile.path,
      'text': text,
      'createdBy': userId,
      'createdAt': Timestamp.now(),
      'isOptimistic': true,
    };

    _isUploading = true;
    _uploadProgress = 0.0;
    _uploadError = null;
    notifyListeners();

    try {
      _updateUploadProgress(0.1);
      final driveImageId = await _mediaRepository.uploadToGoogleDrive(
        imageFile,
        (progress) {
          final mappedProgress = 0.1 + (progress * 0.2);
          _updateUploadProgress(mappedProgress);
        },
      );

      if (driveImageId == null) {
        throw Exception('Failed to upload image to Google Drive');
      }

      _updateUploadProgress(0.3);
      _updateUploadProgress(0.4);

      try {
        await LocalStorageHelper.saveImageLocally(imageFile, driveImageId);
        _updateUploadProgress(0.7);
      } catch (e) {
        print("⚠️ Local storage failed, but continuing: $e");
        _updateUploadProgress(0.7);
      }

      _updateUploadProgress(0.8);
      await _mediaRepository.saveMedia(coupleId, driveImageId, text, userId);
      _updateUploadProgress(1.0);

      await Future.delayed(const Duration(milliseconds: 500));
      _dynamicActionsProvider.recordMemoryUploaded();
    } catch (e) {
      _uploadError = e.toString();
      _isUploading = false;
      notifyListeners();
      print("❌ Error uploading media: $e");
      rethrow;
    } finally {
      optimisticMemory = null;
      _clearUploadState();
    }
  }

  Stream<List<Map<String, dynamic>>> fetchMediaStream(String coupleId) {
    return _mediaRepository.fetchMedia(coupleId);
  }

  Future<void> deletePost(String coupleId, String docId, String imageId) async {
    try {
      await _mediaRepository.deletePost(coupleId, docId, imageId);
    } catch (e) {
      print("❌ Error deleting post: $e");
      rethrow;
    }
  }

  Future<void> retryUpload(String coupleId, File imageFile, String text, String userId) async {
    _uploadError = null;
    await uploadMedia(coupleId, imageFile, text, userId);
  }

  void clearUploadError() {
    _uploadError = null;
    notifyListeners();
  }
  
  // ✨ ADDED: dispose method for proper cleanup.
  @override
  void dispose() {
    clear();
    super.dispose();
  }
}