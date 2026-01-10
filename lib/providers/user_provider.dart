// lib/features/auth/services/user_provider.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:feelings/features/auth/services/user_repository.dart';
import 'package:feelings/features/auth/models/user_model.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:feelings/services/notification_services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:typed_data';
import 'dart:convert';
// ✨ **[NEW IMPORT]** Ensure you have the cloud_functions package.
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:feelings/features/auth/services/auth_service.dart';
import 'package:feelings/services/encryption_service.dart';


class UserProvider with ChangeNotifier{
  Map<String, dynamic>? _userData;
  String? _localProfileImagePath;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final UserRepository _userRepository;
  UserModel? _currentUser;
  UserModel? get currentUser => _currentUser;
  bool _isLoading = true;
  String? _coupleId;
  
  // ✨ Error Tracking
  String? _error;
  bool get hasError => _error != null;

  String? _partnerLocalProfileImagePath;
String? get partnerLocalProfileImagePath => _partnerLocalProfileImagePath;
Uint8List? _webProfileImageBytes;
  Uint8List? _webPartnerProfileImageBytes;



  Map<String, dynamic>? _partnerData;
  StreamSubscription<DocumentSnapshot>? _partnerMoodSubscription;

  UserProvider(
      {UserRepository? userRepository})
      : _userRepository = userRepository ?? UserRepository();

  // ... (all other getters and methods remain the same) ...
  Map<String, dynamic>? get userData => _userData;

  String? get coupleId => _coupleId;


  String? get localProfileImagePath => _localProfileImagePath;

  /// Getter for Partner Data
  Map<String, dynamic>? get partnerData => _partnerData;

  bool get isLoading => _isLoading;

  void setCurrentUser(UserModel user) {
    _currentUser = user;
    notifyListeners();
  }

  bool get isLoggedIn => _currentUser != null;

  // ✨ Encryption Helpers
  String get encryptionStatus => _userData?['encryptionStatus'] ?? 'pending';
  bool get isEncryptionEnforced => encryptionStatus == 'enabled';


// lib/features/auth/services/user_provider.dart

  Future<void> fetchUserData() async {
    try {
      // ✨ RESET ERROR STATE
      _error = null;

      // ✨ SET LOADING TRUE AT THE VERY START
      if (!_isLoading) {
        _isLoading = true;
        notifyListeners();
      }

      User? user = _auth.currentUser;
      if (user == null) {
        _isLoading = false;
        notifyListeners();
        return; 
      }

      // --- ⚡ OPTIMIZATION: TRY CACHE FIRST ---
      try {
        _userData = await _userRepository.getUserData(user.uid, source: Source.cache);
        
        if (_userData != null) {
          debugPrint("⚡ [UserProvider] Loaded User Data from CACHE.");
          // We have cached data! Initialize UI immediately.
           try {
            _currentUser = UserModel.fromMap(_userData!);
            
            // Setup IDs
             NotificationService.setCurrentUserId(user.uid);
             try {
               FirebaseCrashlytics.instance.setUserIdentifier(user.uid);
             } catch (_) {}
             _coupleId = _userData!['coupleId'] as String?;

             // Load Keys if possible (also cached)
             if (_coupleId != null) {
                // Determine if we have local keys
                // We don't await this if we want INSTANT UI, but for keys we need them for chat.
                // It's fast usually.
                await EncryptionService.instance.loadMasterKey(_coupleId!);
             }
             
             // 🚀 SHOW UI NOW
             _isLoading = false;
             notifyListeners(); 
             
             // Queue secondary data fetch (partner images etc)
             _fetchSecondaryDataInBackground(user.uid);

          } catch (e) {
             debugPrint("⚠️ [UserProvider] Cache data was corrupt or invalid: $e");
             // Fallback to server will happen below
          }
        }
      } catch (e) {
        debugPrint("⚠️ [UserProvider] Cache miss or error: $e");
        // No cache available, just proceed to network fetch
      }


      // --- 🌐 STEP 2: FETCH FRESH SERVER DATA ---
      // This is "Stale-While-Revalidate". Even if cache loaded, we check server.
      debugPrint("🌐 [UserProvider] Fetching FRESH User Data from Server...");
      
      try {
        final serverUserData = await _userRepository.getUserData(user.uid, source: Source.server);
        
        // ... (your existing race condition fix for new signups)
        final isEmailUser = user.providerData.any((p) => p.providerId == 'password');
        if (serverUserData == null && isEmailUser && _userData == null) {
           // Only retry if we have NOTHING (no cache, no server)
          await Future.delayed(const Duration(milliseconds: 1500));
          _userData = await _userRepository.getUserData(user.uid);
        } else if (serverUserData != null) {
          _userData = serverUserData;
        }
      } catch (e) {
         debugPrint("⚠️ [UserProvider] Network fetch failed: $e");
         if (_userData == null) {
            // If we have NO data (no cache, and network failed), this is a critical error.
            rethrow; 
         }
         // If we have cache, we just silently fail the refresh.
      }
      
      if (_userData == null) {
        _isLoading = false;
        notifyListeners();
        return; // UserDataLoader will see null and navigate to /register
      }
      
      // --- UPDATE STATE WITH FRESH DATA ---

      try {
        _currentUser = UserModel.fromMap(_userData!);
      } catch (e, stack) {
        try {
          FirebaseCrashlytics.instance.recordError(e, stack, reason: 'UserProvider.fetchUserData failed to parse UserModel fromMap');
        } catch (_) {}
        // If parsing fails for SERVER data, it's a critical error if we don't have cache.
        // If we showed cache, we might want to keep showing it? 
        // For now, fail safe.
        _userData = null;
        _currentUser = null;
        _isLoading = false;
        notifyListeners();
        await _auth.signOut(); 
        return;
      }

      NotificationService.setCurrentUserId(user.uid);
      try {
        FirebaseCrashlytics.instance.setUserIdentifier(user.uid);
      } catch (_) {}

      _coupleId = _userData!['coupleId'] as String?;
      
      // ✨ AUTO-LOAD MASTER KEY ON LOGIN (Retry with fresh data)
      if (_coupleId != null) {
         try {
            await EncryptionService.instance.loadMasterKey(_coupleId!);
         } catch (e) {
            debugPrint("⚠️ [UserProvider] Failed to auto-load key: $e");
         }
      }

      _isLoading = false;
      notifyListeners(); // ✨ NOTIFY UI - FRESH DATA!

      // Step 4: Fetch all partner/image data in the background (Refresh those too)
      _fetchSecondaryDataInBackground(user.uid);

    } catch (e) {
      debugPrint('Error fetching user data: $e');
      if (_userData == null) {
         // ✨ SET ERROR STATE
          _error = "Failed to load user data";
          _isLoading = false;
          notifyListeners();
          // rethrow; // Don't rethrow, let the UI handle _error
      }
    }
  }

  Future<void> _fetchSecondaryDataInBackground(String userId) async {
    try {
      // ✨ CHECK 1: Is the user still logged in and the *same* user?
    if (_auth.currentUser == null || _auth.currentUser!.uid != userId || _userData == null) {
      return; // User logged out or changed, abort task.
    }
      bool didUpdate = false;

      // 1. Fetch Partner Data
      if (_coupleId != null) {
        _partnerData = await _userRepository.fetchPartnerData(_coupleId!, userId);
        if (_partnerData != null) {
          listenToPartnerMood(_partnerData!['userId']);
          didUpdate = true;
        }
      }

      // ✨ CHECK 2: Check again after the first await.
    if (_userData == null) return;

      // 2. Cache User Image
      if (_userData!['profileImageUrl'] != null && _userData!['profileImageUrl'].isNotEmpty) {
        // ✨ FIX: Pass the userId to the caching function
        await _cacheProfileImage(userId, _userData!['profileImageUrl']);
      }

      // ✨ CHECK 3: And again...
    if (_userData == null) return;

      // 3. Cache Partner Image
      if (_partnerData != null && _partnerData!['profileImageUrl'] != null && _partnerData!['profileImageUrl'].isNotEmpty) {
        // ✨ FIX: Pass the partner's userId to the caching function
        await _cachePartnerProfileImage(_partnerData!['userId'], _partnerData!['profileImageUrl']);
      }

      // 4. Notify UI if new data (like partner) is available
      if (didUpdate) {
        if (_userData != null) {
        notifyListeners();
      }
      }

    } catch (e, stack) {
      try {
        FirebaseCrashlytics.instance.recordError(e, stack, reason: 'UserProvider._fetchSecondaryDataInBackground failed');
        FirebaseCrashlytics.instance.log('Error fetching secondary data: ${e.toString()}');
      } catch (_) {}
      print("Error fetching secondary data: $e");
      // Don't rethrow, as the app is already running.
    }
  }


// ✨ --- THIS METHOD IS REWRITTEN FOR USER-SPECIFIC CACHING --- ✨
  // ✨ FIX: Added userId parameter
  Future<void> _cacheProfileImage(String userId, String imageUrl) async {
    final prefs = await SharedPreferences.getInstance();
    // ✨ FIX: Use user-specific keys
    final cachedUrlKey = 'cachedProfileUrl_$userId';
    final cachedPathKey = 'cachedLocalProfilePath_$userId';
    final cachedUrl = prefs.getString(cachedUrlKey);

    // For mobile, define the standard file path
    File? imageFile;
    if (!kIsWeb) {
      final directory = await getApplicationDocumentsDirectory();
      // ✨ FIX: Use a user-specific filename
      final filePath = '${directory.path}/profile_image_$userId.jpg';
      imageFile = File(filePath);
    }
    
    // Download the new image if the URL has changed or if the file doesn't exist on mobile
    if (imageUrl != cachedUrl || (imageFile != null && !await imageFile.exists())) {
      // print("🔄 [Profile Image] New URL or missing cache. Starting download...");
      try {
        // On mobile, delete the old file before downloading the new one.
        if (imageFile != null && await imageFile.exists()) {
          await imageFile.delete();
          // print("🗑️ [Profile Image] Deleted old cached file.");
        }

        final response = await http.get(Uri.parse(imageUrl));
        if (response.statusCode == 200) {
          if (kIsWeb) {
            // print("💾 [Profile Image] Caching for WEB...");
            final bytes = response.bodyBytes;
            _webProfileImageBytes = bytes;
            // ✨ FIX: Use user-specific key
            await prefs.setString(cachedUrlKey, imageUrl);
            _localProfileImagePath = 'web_cached_profile'; 
          } else {
            // print("💾 [Profile Image] Caching for MOBILE...");
            await imageFile!.writeAsBytes(response.bodyBytes);
            // ✨ FIX: Use user-specific keys
            await prefs.setString(cachedPathKey, imageFile.path);
            await prefs.setString(cachedUrlKey, imageUrl);
            _localProfileImagePath = imageFile.path;
            // print("✅ [Profile Image] Successfully cached for mobile at: ${imageFile.path}");
          }
        } else {
          // print("❌ [Profile Image] Failed to download. Status: ${response.statusCode}");
        }
    } catch (e, stack) {
      try {
        FirebaseCrashlytics.instance.recordError(e, stack, reason: 'UserProvider._cacheProfileImage failed');
        FirebaseCrashlytics.instance.log('Error caching profile image: ${e.toString()}');
      } catch (_) {}
      // print("❌ [Profile Image] Error caching profile image: $e");
    }
    } else {
       // print("✅ [Profile Image] Using existing cached image.");
      if (kIsWeb) {
         _localProfileImagePath = 'web_cached_profile';
      } else {
        // ✨ FIX: Use user-specific key
        _localProfileImagePath = prefs.getString(cachedPathKey);
      }
    }
  }




// ✨ --- THIS METHOD IS REWRITTEN FOR USER-SPECIFIC CACHING --- ✨
  // ✨ FIX: Added partnerId parameter
  Future<void> _cachePartnerProfileImage(String partnerId, String imageUrl) async {
    final prefs = await SharedPreferences.getInstance();
    // ✨ FIX: Use partner-specific keys
    final cachedUrlKey = 'cachedPartnerProfileUrl_$partnerId';
    final cachedPathKey = 'cachedPartnerLocalProfilePath_$partnerId';
    final cachedUrl = prefs.getString(cachedUrlKey);

    File? imageFile;
    if (!kIsWeb) {
        final directory = await getApplicationDocumentsDirectory();
        // ✨ FIX: Use partner-specific filename
        final filePath = '${directory.path}/partner_profile_image_$partnerId.jpg';
        imageFile = File(filePath);
    }

  if (imageUrl != cachedUrl || (imageFile != null && !await imageFile.exists())) {
    // print("🔄 [Partner Image] New URL or missing cache. Starting download...");
        try {
            if (imageFile != null && await imageFile.exists()) {
                await imageFile.delete();
        // print("🗑️ [Partner Image] Deleted old cached file.");
            }
            final response = await http.get(Uri.parse(imageUrl));
            if (response.statusCode == 200) {
                if (kIsWeb) {
          // print("💾 [Partner Image] Caching for WEB...");
                    _webPartnerProfileImageBytes = response.bodyBytes;
                    // ✨ FIX: Use partner-specific key
                    await prefs.setString(cachedUrlKey, imageUrl);
                    _partnerLocalProfileImagePath = 'web_cached_partner_profile';
                } else {
          // print("💾 [Partner Image] Caching for MOBILE...");
                    await imageFile!.writeAsBytes(response.bodyBytes);
                    // ✨ FIX: Use partner-specific keys
                    await prefs.setString(cachedPathKey, imageFile.path);
                    await prefs.setString(cachedUrlKey, imageUrl);
                    _partnerLocalProfileImagePath = imageFile.path;
          // print("✅ [Partner Image] Successfully cached for mobile at: ${imageFile.path}");
                }
            } else {
        // print("❌ [Partner Image] Failed to download. Status: ${response.statusCode}");
            }
        } catch (e, stack) {
      try {
        FirebaseCrashlytics.instance.recordError(e, stack, reason: 'UserProvider._cachePartnerProfileImage failed');
        FirebaseCrashlytics.instance.log('Error caching partner profile image: ${e.toString()}');
      } catch (_) {}
      // print("❌ [Partner Image] Error caching partner profile image: $e");
        }
    } else {
    // print("✅ [Partner Image] Using existing cached image.");
        if (kIsWeb) {
            _partnerLocalProfileImagePath = 'web_cached_partner_profile';
        } else {
            // ✨ FIX: Use partner-specific key
            _partnerLocalProfileImagePath = prefs.getString(cachedPathKey);
        }
    }
}


  // Call this method after a successful image upload
  Future<void> updateProfileImage(String newImageUrl) async {
    await _cacheProfileImage(_userData!['userId'],newImageUrl);
    if (_userData != null) {
      _userData!['profileImageUrl'] = newImageUrl;
      notifyListeners();
    }
  }

   Future<ImageProvider> getProfileImage() async {
    if (kIsWeb) {
      // For web, check if we have cached base64 data
      final prefs = await SharedPreferences.getInstance();
      final cachedImageData = prefs.getString('cachedProfileImageData');
      if (cachedImageData != null) {
        // print("✅ Profile image fetched from web cache");
        return MemoryImage(base64Decode(cachedImageData));
    } else if (_userData != null && _userData!['profileImageUrl'] != null) {
        // print("✅ Profile image fetched from network (web)");
      return NetworkImage(_userData!['profileImageUrl']);
      }
    } else {
      // For mobile, use file system
      if (_localProfileImagePath != null && File(_localProfileImagePath!).existsSync()) {
        // print("✅ Profile image fetched from mobile cache");
        return FileImage(File(_localProfileImagePath!));
      } else if (_userData != null && _userData!['profileImageUrl'] != null) {
        // print("✅ Profile image fetched from network (mobile)");
        return NetworkImage(_userData!['profileImageUrl']);
      }
    }
    
      // Return a default asset image or handle it in the UI
      return const AssetImage('assets/images/default_avatar.png'); // Make sure you have a default avatar
    }

  // Synchronous version for backward compatibility
  ImageProvider getProfileImageSync() {
  if (kIsWeb) {
    // 1. Check for in-memory bytes first (this is truly synchronous)
    if (_webProfileImageBytes != null) {
      // print("✅ [Profile Image] Loading from WEB MEMORY CACHE");
      return MemoryImage(_webProfileImageBytes!);
    }
    // 2. Fallback to the network URL from user data
    if (_userData != null && _userData!['profileImageUrl'] != null && _userData!['profileImageUrl'].isNotEmpty) {
      // print("🌐 [Profile Image] Loading from NETWORK (web sync fallback)");
      return NetworkImage(_userData!['profileImageUrl']);
    }
  } else {
    // Mobile logic remains the same
    if (_localProfileImagePath != null && File(_localProfileImagePath!).existsSync()) {
      return FileImage(File(_localProfileImagePath!));
    } else if (_userData != null && _userData!['profileImageUrl'] != null && _userData!['profileImageUrl'].isNotEmpty) {
      return NetworkImage(_userData!['profileImageUrl']);
    }
  }
  // 3. Final fallback to the default asset
  // print("🖼️ [Profile Image] Loading DEFAULT avatar");
  return const AssetImage('assets/images/default_avatar.png');
}

  Future<ImageProvider> getPartnerProfileImage() async {
  if (kIsWeb) {
    // For web, check if we have cached base64 data
    final prefs = await SharedPreferences.getInstance();
    final cachedImageData = prefs.getString('cachedPartnerProfileImageData');
    if (cachedImageData != null) {
      // print("✅ Partner image fetched from web cache");
      return MemoryImage(base64Decode(cachedImageData));
    } else if (_partnerData != null && _partnerData!['profileImageUrl'] != null) {
      // print("✅ Partner image fetched from network (web)");
      return NetworkImage(_partnerData!['profileImageUrl']);
    }
  } else {
    // For mobile, use file system
  if (_partnerLocalProfileImagePath != null &&
      File(_partnerLocalProfileImagePath!).existsSync()) {
      // print("✅ Partner image fetched from mobile cache");
    return FileImage(File(_partnerLocalProfileImagePath!));
    } else if (_partnerData != null && _partnerData!['profileImageUrl'] != null) {
      // print("✅ Partner image fetched from network (mobile)");
      return NetworkImage(_partnerData!['profileImageUrl']);
    }
  }
  
  return const AssetImage('assets/images/default_avatar.png');
}

// Synchronous version for backward compatibility
ImageProvider getPartnerProfileImageSync() {
  if (kIsWeb) {
    // 1. Check for in-memory bytes first
    if (_webPartnerProfileImageBytes != null) {
      // print("✅ [Partner Image] Loading from WEB MEMORY CACHE");
      return MemoryImage(_webPartnerProfileImageBytes!);
    }
    // 2. Fallback to network
    if (_partnerData != null && _partnerData!['profileImageUrl'] != null && _partnerData!['profileImageUrl'].isNotEmpty) {
      // print("🌐 [Partner Image] Loading from NETWORK (web sync fallback)");
      return NetworkImage(_partnerData!['profileImageUrl']);
    }
  } else {
    // Mobile logic remains the same
    if (_partnerLocalProfileImagePath != null && File(_partnerLocalProfileImagePath!).existsSync()) {
      return FileImage(File(_partnerLocalProfileImagePath!));
    } else if (_partnerData != null && _partnerData!['profileImageUrl'] != null && _partnerData!['profileImageUrl'].isNotEmpty) {
      return NetworkImage(_partnerData!['profileImageUrl']);
    }
  }
  // 3. Final fallback
  // print("🖼️ [Partner Image] Loading DEFAULT avatar");
  return const AssetImage('assets/images/default_avatar.png');
}

  /// Fetch partner data using coupleId from user document
  Future<void> fetchPartnerData() async {
    try {
      if (_userData == null) return;

      String userId = _userData!['userId'];
      final partnerId = await _userRepository.getPartnerId(userId);

      if (partnerId != null) {
        _partnerData = await _userRepository.getPartnerData(partnerId);
        // print('UserProvider: Partner data loaded: $_partnerData');
        // Cache partner profile image if available
        if (_partnerData != null && _partnerData!['profileImageUrl'] != null && _partnerData!['profileImageUrl'].isNotEmpty) {
          await _cachePartnerProfileImage(_partnerData!['userId'],_partnerData!['profileImageUrl']);
        }
        notifyListeners();

        // Start listening to partner's mood
        listenToPartnerMood(partnerId);
      } else {
        _partnerData = null; // If no partner, clear partner data
        // print('UserProvider: No partner found, clearing partner data');
        stopListeningToPartner(); // Stop listening if no partner
      }
    } catch (e, stack) {
      try {
        FirebaseCrashlytics.instance.recordError(e, stack, reason: 'UserProvider.fetchPartnerData failed');
        FirebaseCrashlytics.instance.log('Error fetching partner data: ${e.toString()}');
      } catch (_) {}
      // print('Error fetching partner data: $e');
    }
  }



  /// Listen to Partner's Mood in Real-time
  void listenToPartnerMood(String partnerId) {
    stopListeningToPartner(); // Ensure no duplicate listeners

    _partnerMoodSubscription =
        _userRepository.listenToPartnerMood(partnerId).listen(
      (snapshot) {
        // ✨ --- [GUARD 1: ON-DATA] --- ✨
        if (FirebaseAuth.instance.currentUser == null) {
          debugPrint('[UserProvider] Partner mood event received, but user is logged out. Ignoring.');
          return;
        }

        if (snapshot.exists) {
          _partnerData = snapshot.data() as Map<String, dynamic>?;
          notifyListeners();
        }
      },
      onError: (error) {
        // ✨ --- [GUARD 2: ON-ERROR] --- ✨
        if (error is FirebaseException && error.code == 'permission-denied') {
          if (FirebaseAuth.instance.currentUser == null) {
            // This is the expected "crash" during logout.
            // It's safe to ignore.
            debugPrint("[UserProvider] Safely caught permission-denied on partner mood listener during logout.");
          } else {
            // This is a *real* permission error for a logged-in user.
            debugPrint("[UserProvider] CRITICAL PARTNER MOOD PERMISSION ERROR: $error");
          }
        } else {
          // A different, unexpected error
          debugPrint("[UserProvider] Unexpected partner mood error: $error");
        }
      },
    );
  }



  /// Stop Listening to Partner's Mood (e.g., on Logout)
  void stopListeningToPartner() {
    _partnerMoodSubscription?.cancel();
    _partnerMoodSubscription = null;
  }

  /// Authenticate user with SharedPreferences
  Future<void> authenticateWithSharedPreferences() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? userId = prefs.getString('userId');

      if (userId != null) {
        // Validate that the user exists in Firebase Auth
        User? currentUser = _auth.currentUser;
        if (currentUser == null || currentUser.uid != userId) {
          // Clear invalid stored data
          await prefs.remove('userId');
          throw Exception('Stored user session is invalid');
        }

        _userData = await _userRepository.getUserData(userId);
        if (_userData != null) {
          await fetchPartnerData(); // Fetch partner data after user data
          await updateFcmToken(userId);
          await getCoupleId();
          
          // Set current user ID in notification service for FCM token management
          // Set current user ID in notification service for FCM token management
          NotificationService.setCurrentUserId(userId);
          
          if (_coupleId != null) {
              debugPrint("🔐 [UserProvider] Auth restore success. Auto-loading Master Key for $_coupleId...");
              try {
                  await EncryptionService.instance.loadMasterKey(_coupleId!);
              } catch (e) {
                  debugPrint("⚠️ [UserProvider] Failed to auto-load key on restore: $e");
              }
          }

          notifyListeners();
        } else {
          // User data not found in Firestore, clear stored data
          await prefs.remove('userId');
          throw Exception('User data not found');
        }
      } else {
        throw Exception('No stored user session');
      }
    } catch (e) {
      try {
        FirebaseCrashlytics.instance.recordError(e, null, reason: 'UserProvider.authenticateWithSharedPreferences failed');
        FirebaseCrashlytics.instance.log('Error authenticating user with SharedPreferences: ${e.toString()}');
      } catch (_) {}
      // print('Error authenticating user with SharedPreferences: $e');
      rethrow; // Re-throw to allow calling code to handle the error
    }
  }

  /// Store userId in SharedPreferences
  Future<void> saveUserIdToSharedPreferences(String userId) async {
    try {
      // Validate that user data exists before saving
      if (_userData == null || _userData!['userId'] != userId) {
        throw Exception('User data not available or userId mismatch');
      }
      
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString('userId', userId);
      // print('User ID saved to SharedPreferences: $userId');
    } catch (e) {
      // print('Error saving userId to SharedPreferences: $e');
      rethrow; // Re-throw to allow calling code to handle the error
    }
  }

  /// Update user data in Firestore
  Future<void> updateUserData(Map<String, dynamic> updatedFields) async {
    try {
      User? user = _auth.currentUser;

      if (user != null) {
        await _userRepository.updateUserData(
          userId: user.uid,
          updatedFields: updatedFields,
        );

        _userData = {
          ...?_userData,
          ...updatedFields
        }; // Optimistically update local state
        
        // ✨ FIX: Also update the UserModel object so getters like currentUser.encryptionStatus return new values
        if (_userData != null) {
          try {
            _currentUser = UserModel.fromMap(_userData!);
          } catch (e) {
             debugPrint("Error updating UserModel: $e");
          }
        }
        notifyListeners();
      }
    } catch (e) {
      // print('Error updating user data: $e');
    }
  }

  /// Update user mood - OPTIMISTIC UPDATE
  Future<void> updateUserMood(String mood) async {
    try {
      User? user = _auth.currentUser;

      if (user != null) {
        // 1. Capture previous state for rollback
        final previousMood = _userData?['mood'];
        final previousUpdate = _userData?['moodLastUpdated'];

        // 2. Optimistic Update
        _userData = {
          ...?_userData,
          'mood': mood,
          'moodLastUpdated': DateTime.now(),
        };
        notifyListeners(); // ✨ UI updates instantly

        // 3. Perform Network Request
        try {
          await _userRepository.updateUserMood(
            userId: user.uid,
            mood: mood,
          );
        } catch (e) {
          // 4. Rollback on failure
          _userData = {
            ...?_userData,
            'mood': previousMood,
            'moodLastUpdated': previousUpdate,
          };
          notifyListeners();
          rethrow; // Let the caller know (though rarely handled in UI for fire-and-forget)
        }
      }
    } catch (e) {
      debugPrint('Error updating mood: $e');
    }
  }


  /// ✨ **[REWRITTEN]** The main method called from the UI to delete an account.
  /// First, it re-authenticates the user with their password for security confirmation.
  /// Then, it calls a single Cloud Function to handle the full deletion process.
  Future<void> deleteCurrentUserAccount(String password) async {
    final user = _auth.currentUser;
    if (user == null || user.email == null) {
      throw Exception("Cannot delete account: User is not signed in or email is missing.");
    }

    try {
      // STEP 1: Re-authenticate the user
      final cred = EmailAuthProvider.credential(email: user.email!, password: password);
      await user.reauthenticateWithCredential(cred);

      // STEP 2: Call the Cloud Function
      await _userRepository.deleteUserAccount();

      // ✨ --- ADD THIS LINE --- ✨
      // STEP 3: Hard reset encryption keys (Wipe Identity)
      await EncryptionService.instance.hardReset();

      // STEP 4: Manually sign out the client.
      // This is the missing piece that will notify the AuthWrapper.
      // await _auth.signOut();
      await _auth.signOut();
      
      // STEP 5: Clear all local provider data
      // clear is done by auth wrapper 
      // await clear();

    } on FirebaseAuthException catch (e) {
        // ... (your existing error handling)
        if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
             throw Exception("Incorrect password. Please try again.");
        }
        throw Exception("An error occurred during authentication. Please try again later.");
    } on FirebaseFunctionsException catch (e) {
      // ... (your existing error handling)
      if (e.code == 'unauthenticated') {
        throw Exception("Your session has expired. Please log in again to delete your account.");
      }
      throw Exception("An error occurred on the server. Please try again later.");
    } catch (e) {
      // ... (your existing error handling)
      rethrow;
    }
  }

  /// Sign out the current user and clear local data
  Future<void> signOut() async {
    try {
      debugPrint('[UserProvider] Signing out...');
      await _auth.signOut();
      debugPrint('[UserProvider] Firebase Auth Signout successful.');
      await clear();
      debugPrint('[UserProvider] Local data cleared.');
    } catch (e) {
      debugPrint('[UserProvider] Error during sign out: $e');
      // Ensure we clear even if auth signout fails (e.g. network issue)
      await clear(); 
    }
  }

  /// Clear user data (e.g., during logout)
// In user_provider.dart

Future<void> clear() async {
    // --- DEBUG LOG ---
    // Stop any active listeners
    stopListeningToPartner();
    debugPrint('[7b] UserProvider: Starting clear() method.');
    
    // ✨ Clear Encryption Keys (Session only, preserve identity)
    EncryptionService.instance.clearSessionKeys();
    
    // ✨ --- THIS IS THE FIX --- ✨
    // In test mode, we skip all I/O (SharedPreferences/File) 
    // to prevent the test runner from hanging.
    if (!AuthService.isTestMode) {
      try {
        final SharedPreferences prefs = await SharedPreferences.getInstance();
        final String? userId = _userData?['userId'];
        
        // --- DEBUG LOG ---
        debugPrint('[7c] UserProvider: Clearing data for userId: $userId.');

        // Clear user-specific data from SharedPreferences and local files
        if (userId != null) {
          final String profilePathKey = 'cachedLocalProfilePath$userId';
          final String? profilePath = prefs.getString(profilePathKey);
          
          await prefs.remove('cachedProfileUrl$userId');
          await prefs.remove(profilePathKey);
          
          // The check for AuthService.isTestMode here is redundant
          // since it's already in the outer if, but it doesn't hurt.
          if (!kIsWeb && profilePath != null) { 
              final profileFile = File(profilePath);
              if (await profileFile.exists()) {
                await profileFile.delete();
                // --- DEBUG LOG ---
                debugPrint('[7d] UserProvider: Deleted cached profile image file at $profilePath.');
              }
            }
        }
      } catch (e, stack) {
        // --- DEBUG LOG ---
        debugPrint('[FATAL] UserProvider: CRITICAL ERROR Failed to clear user data: $e');
        FirebaseCrashlytics.instance.recordError(e, stack, reason: 'UserProvider.clear failed');
        // Do not rethrow; we must continue cleanup.
      }
    } else {
      debugPrint('[7c] UserProvider: In test mode, skipping SharedPreferences/File cleanup.');
    }
    // ✨ --- END OF FIX --- ✨


    
    // --- DEBUG LOG ---
    debugPrint('[7e] UserProvider: Stopped partner mood listener.');

    // Reset all state variables
    _userData = null;
    _currentUser = null;
    _partnerData = null;
    // ... reset all other fields
    _isLoading = true; // Set to true for the next login flow

    // --- DEBUG LOG ---
    debugPrint('[7f] UserProvider: Internal state has been reset.');

    notifyListeners();
    // --- DEBUG LOG ---
    debugPrint('[7g] UserProvider: clear() finished and notified listeners.');

  }


  /// Get User ID
  String? getUserId() {
    return _userData?['userId'];
  }

  /// Get Partner ID
  String? getPartnerId() {
    return _partnerData?['userId'];
  }

  Future<void> updateFcmToken(String userId) async {
    // Use the notification service to update FCM token
    NotificationService.setCurrentUserId(userId);
  }

  // Refresh FCM token (useful when tokens become invalid)
  Future<void> refreshFcmToken(String userId) async {
    await _userRepository.refreshFcmToken(userId);
  }

  // Manually refresh FCM token using notification service
  Future<String?> manuallyRefreshFcmToken() async {
    return await NotificationService.refreshToken();
  }

  // Check FCM status
  Future<Map<String, dynamic>> checkFcmStatus() async {
    return await NotificationService.checkFcmStatus();
  }

  // Debug method to test FCM notifications
  Future<void> testFcmNotification() async {
    try {
      final userId = getUserId();
      if (userId != null) {
  // print('Testing FCM notification for user: $userId');

  // Check FCM status first
  await checkFcmStatus();
  // print('FCM Status: $status');

  // Try to send a test notification to self
  await sendPushNotification(userId, 'Test notification from Connect app');
  // print('Test notification sent');
      } else {
        // print('No user ID available for FCM test');
      }
    } catch (e) {
      // print('Error testing FCM notification: $e');
    }
  }

  Future<void> sendPushNotification(String receiverId, String message) async {
    await _userRepository.sendPushNotification(receiverId, message);
  }

  /// Fetch Couple ID
  /// Fetch Couple ID and return it as a string
  Future<void> getCoupleId() async {
    try {
      if (_userData == null) return;

      String userId = _userData!['userId'];
      _coupleId = await _userRepository.getCoupleId(userId);
      notifyListeners(); // If UI depends on this value
    } catch (e) {
      // print('Error fetching couple ID: $e');
    }
  }


  Future<void> updateUserLocation(double latitude, double longitude) async {
  try {
    User? user = _auth.currentUser;
    if (user != null) {
      await _userRepository.updateUserLocation(user.uid, latitude, longitude);
      _userData = {
        ...?_userData,
        'latitude': latitude,
        'longitude': longitude,
      };
      notifyListeners();
    }
  } catch (e) {
    // print('Error updating user location: $e');
  }
}

  Future<String> generateAndAssignCoupleCode(String userId) async {
    return await _userRepository.generateAndAssignCoupleCode(userId);
  }


  // ✨ [NEW] Update love language in provider and Firestore
  Future<void> updateUserLoveLanguage(String? loveLanguage) async {
    final userId = getUserId();
    if (userId == null) return;

    try {
      await _userRepository.updateUserLoveLanguage(
        userId: userId,
        loveLanguage: loveLanguage,
      );
      // Optimistically update local state
      if (_userData != null) {
        _userData!['loveLanguage'] = loveLanguage;
        notifyListeners();
      }
    } catch (e) {
      // print('Error updating love language: $e');
      rethrow;
    }
  }

  // ✨ [NEW] Update gender in provider and Firestore
  Future<void> updateUserGender(Gender? gender) async {
    final userId = getUserId();
    if (userId == null) return;

    try {
      // Convert enum to string for storage, or null if it's not set
      final genderString = gender?.name;
      await _userRepository.updateUserGender(
        userId: userId,
        gender: genderString,
      );
      // Optimistically update local state
      if (_userData != null) {
        _userData!['gender'] = genderString;
        notifyListeners();
      }
    } catch (e) {
      // print('Error updating gender: $e');
      rethrow;
    }
  }


}