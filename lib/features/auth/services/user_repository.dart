// lib/features/auth/services/user_repository.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:feelings/services/oauth_services.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:feelings/features/connectCouple/repository/couple_repository.dart';
// ✨ **[NEW IMPORT]** Ensure you have the cloud_functions package in pubspec.yaml
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'dart:math';
// Conditional import for dart:html
import '../../../web_utils.dart' if (dart.library.html) '../../../web_utils_web.dart';

class UserRepository {
  final FirebaseFirestore _firestore;
  final FirebaseMessaging _firebaseMessaging;

  UserRepository({FirebaseFirestore? firestore, FirebaseMessaging? firebaseMessaging})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _firebaseMessaging = firebaseMessaging ?? FirebaseMessaging.instance;

  // Getter for current user (used by CoupleProvider)
  dynamic get currentUser => null; // This is a placeholder - actual user comes from UserProvider

  // ... (all other methods like updateFcmToken, saveUserData, etc., remain the same) ...
  bool get _isIosWeb {
    if (kIsWeb) {
      final userAgent = WebUtils.getUserAgent();
      if (userAgent.contains('iphone') || userAgent.contains('ipad') || userAgent.contains('ipod')) {
        return true;
      }
    }
    return false;
  }
  
  Future<void> updateFcmToken(String userId) async {
    if (_isIosWeb) {
      print('UserRepository: Skipping FCM token update on iOS web');
      return;
    }
    String? token = await _firebaseMessaging.getToken();
    if (token != null) {
      await _firestore.collection('users').doc(userId).update({'fcmToken': token});
      print('FCM Token updated for user $userId: $token');
    } else {
      print('Failed to get FCM token for user $userId');
    }
  }

  // Refresh FCM token and update in Firestore
  Future<void> refreshFcmToken(String userId) async {
    if (_isIosWeb) {
      print('UserRepository: Skipping FCM token refresh on iOS web');
      return;
    }
    try {
      // Force token refresh
      await _firebaseMessaging.deleteToken();
      String? newToken = await _firebaseMessaging.getToken();
      if (newToken != null) {
        await _firestore.collection('users').doc(userId).update({'fcmToken': newToken});
        print('FCM Token refreshed for user $userId: $newToken');
      } else {
        print('Failed to get new FCM token for user $userId');
      }
    } catch (e, stack) {
      try {
        FirebaseCrashlytics.instance.recordError(e, stack, reason: 'UserRepository.refreshFcmToken failed for $userId');
        FirebaseCrashlytics.instance.log('Error refreshing FCM token: ${e.toString()}');
      } catch (_) {}
      print('Error refreshing FCM token: $e');
    }
  }

  Future<void> sendPushNotification(String receiverId, String message, {String? partnerName, String? messageText}) async {
    try {

      
      // Step 1: Get OAuth 2.0 Access Token
      String? accessToken = await OAuthService.getAccessToken();
      if (accessToken == null) {
        print("Failed to get OAuth Token");
        return;
      }

      // Step 2: Retrieve Receiver's FCM Token
      DocumentSnapshot receiverSnapshot = await FirebaseFirestore.instance.collection('users').doc(receiverId).get();
      final receiverData = receiverSnapshot.data() as Map<String, dynamic>;

    // ✨ CHECK NOTIFICATION PREFERENCE
    // We default to 'true' if the field doesn't exist for older users.
    final bool canReceiveNotifications = receiverData['notificationsEnabled'] ?? true;

    if (!canReceiveNotifications) {
      print("UserRepository: Skipping push notification because receiver ($receiverId) has them disabled.");
      return; // Stop the function here if notifications are disabled.
    }
    
    // Step 3: Continue with sending the notification if enabled
    String? fcmToken = receiverData['fcmToken'];
      if (fcmToken != null) {
        // Step 3: Send Push Notification with custom data
        final response = await http.post(
          Uri.parse("https://fcm.googleapis.com/v1/projects/feelings-d43f8/messages:send"),
          headers: {
            "Authorization": "Bearer $accessToken",
            "Content-Type": "application/json",
          },
          body: jsonEncode({
            "message": {
              "token": fcmToken,
              "notification": {
                "title": partnerName ?? "New Message",
                "body": messageText ?? message,
              },
              "data": {
                "partnerName": partnerName ?? "Partner",
                "messageText": messageText ?? message,
                "messageId": DateTime.now().millisecondsSinceEpoch.toString(),
              }
            },
          }),
        );

        print("FCM Response: ${response.body}");
        
        // Check if the token is invalid (UNREGISTERED error)
        if (response.statusCode == 404) {
          try {
            final responseData = jsonDecode(response.body);
            if (responseData['error']?['details']?[0]?['errorCode'] == 'UNREGISTERED') {
              print("FCM Token is invalid (UNREGISTERED). Removing token from Firestore.");
              // Remove the invalid token from Firestore
              await FirebaseFirestore.instance.collection('users').doc(receiverId).update({
                'fcmToken': FieldValue.delete(),
              });
              print("Invalid FCM token removed for user $receiverId");
              
              // Try to send notification again after a short delay (in case token was refreshed)
              await Future.delayed(Duration(seconds: 2));
              await sendPushNotification(receiverId, message, partnerName: partnerName);
            }
          } catch (e) {
            print("Error parsing FCM response: $e");
          }
        }
      } else {
        print("No FCM token found for user $receiverId");
      }
    } catch (e) {
      try {
        FirebaseCrashlytics.instance.recordError(e, null, reason: 'UserRepository.sendPushNotification failed for receiver $receiverId');
        FirebaseCrashlytics.instance.log('sendPushNotification error: ${e.toString()}');
      } catch (_) {}
      print("sendPushNotification error: $e");
    }
  }



/// Save User Data to Firestore
  Future<void> saveUserData({
    required String userId,
    required String email,
    required String name,
    String? profileImageUrl,
    String? loveLanguage,
    String? gender,
    bool notificationsEnabled = true,
    bool locationSharingEnabled = true,
  }) async {
    try {
      // ✨ bio and phone have been removed from this data map
      await _firestore.collection('users').doc(userId).set({
        'userId': userId,
        'email': email,
        'name': name,
        'profileImageUrl': profileImageUrl ?? '',
        'loveLanguage': loveLanguage,
        'gender': gender,
        'notificationsEnabled': notificationsEnabled,
        'locationSharingEnabled': locationSharingEnabled,
        'mood': null,
        'moodLastUpdated': null,
        'doneQuestions': [],
        'createdAt': FieldValue.serverTimestamp(),
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e, stack) {
      try {
        FirebaseCrashlytics.instance.recordError(e, stack, reason: 'UserRepository.saveUserData failed for $userId');
        FirebaseCrashlytics.instance.log('Failed to save user data: ${e.toString()}');
      } catch (_) {}
      throw Exception('Failed to save user data: ${e.toString()}');
    }
  }



  /// ✨ **[REWRITTEN]** Deletes all user data by invoking a secure Cloud Function.
  ///
  /// The client is no longer responsible for the deletion logic. It simply makes
  /// a single, authenticated call to the `deleteUserAccount` function which
  /// orchestrates the entire cleanup process on the backend.
  Future<void> deleteUserAccount() async {
    try {
      final callable =
          FirebaseFunctions.instance.httpsCallable('deleteUserAccount');
      // We don't need to pass any arguments, as the function securely
      // identifies the user via their auth context.
      await callable.call();
    } catch (e) {
      // The provider will handle the exception and show a message to the user.
      try {
        FirebaseCrashlytics.instance.recordError(e, null, reason: 'UserRepository.deleteUserAccount callable failed');
        FirebaseCrashlytics.instance.log('Error calling deleteUserAccount function: ${e.toString()}');
      } catch (_) {}
      print("Error calling deleteUserAccount function: $e");
      rethrow;
    }
  }

  // ✨ --- THIS METHOD IS REMOVED --- ✨
  // Logic is now handled by the UserProvider to prevent inconsistencies.
  // Future<void> deleteLocalProfileImage(String userId) async { ... }
  
  /// Fetch User Data from Firestore
  Future<Map<String, dynamic>?> getUserData(String userId, {Source? source}) async {
    try {
      DocumentSnapshot userDoc =
          await _firestore.collection('users').doc(userId).get(source != null ? GetOptions(source: source) : null);

      if (userDoc.exists) {
        return userDoc.data() as Map<String, dynamic>?;
      } else {
        return null;
      }
    } catch (e, stack) {
      try {
        FirebaseCrashlytics.instance.recordError(e, stack, reason: 'UserRepository.getUserData failed for $userId');
        FirebaseCrashlytics.instance.log('Failed to fetch user data: ${e.toString()}');
      } catch (_) {}
      throw Exception('Failed to fetch user data: ${e.toString()}');
    }
  }

  /// Update User Data in Firestore
  Future<void> updateUserData({
    required String userId,
    required Map<String, dynamic> updatedFields,
  }) async {
    try {
      await _firestore.collection('users').doc(userId).update(updatedFields);
    } catch (e) {
      throw Exception('Failed to update user data: ${e.toString()}');
    }
  }

  /// Update the user's current mood
  Future<void> updateUserMood({
    required String userId,
    required String mood,
  }) async {
    try {
      await updateUserData(
        userId: userId,
        updatedFields: {
          'mood': mood,
          'moodLastUpdated': FieldValue.serverTimestamp(),
        },
      );
    } catch (e) {
      throw Exception('Failed to update mood: ${e.toString()}');
    }
  }
  /// Fetch Partner Data from Firestore
  Future<Map<String, dynamic>?> getPartnerData(String partnerId, {String? currentUserId}) async {
    try {
      DocumentSnapshot partnerDoc =
          await _firestore.collection('users').doc(partnerId).get();

      if (!partnerDoc.exists) {
        return null;
      }

      final partnerData = Map<String, dynamic>.from(partnerDoc.data() as Map<String, dynamic>);

      // If currentUserId is provided, check if the relationship is inactive
      if (currentUserId != null && partnerData['coupleId'] != null) {
        // Import CoupleRepository locally to avoid circular imports
        final coupleRepo = CoupleRepository();
        final isInactive = await coupleRepo.isCoupleInactive(partnerData['coupleId']);
        if (isInactive) {
          partnerData.remove('profileImageUrl');
        }
      }

      return partnerData;
    } catch (e, stack) {
      try {
        FirebaseCrashlytics.instance.recordError(e, stack, reason: 'UserRepository.getPartnerData failed for $partnerId');
        FirebaseCrashlytics.instance.log('Failed to fetch partner data: ${e.toString()}');
      } catch (_) {}
      throw Exception('Failed to fetch partner data: ${e.toString()}');
    }
  }
  /// Listen to Partner's Mood Changes in Real-time
  Stream<DocumentSnapshot> listenToPartnerMood(String partnerId) {
    return _firestore.collection('users').doc(partnerId).snapshots();
  }

    /// Get Couple ID (from user document)
  Future<String?> getCoupleId(String userId) async {
    try {
      DocumentSnapshot userDoc = await _firestore.collection('users').doc(userId).get();
      if (userDoc.exists && userDoc.data() != null) {
        final data = userDoc.data() as Map<String, dynamic>;
        return data['coupleId'] as String?;
      }
      return null;
    } catch (e) {
      throw Exception('Failed to fetch couple ID: ${e.toString()}');
    }
  }

  /// Get Partner ID using coupleId from user document
  Future<String?> getPartnerId(String userId) async {
    try {
      // Get user's coupleId
      final coupleId = await getCoupleId(userId);
      if (coupleId == null) return null;
      // Fetch couple document
      final coupleDoc = await _firestore.collection('couples').doc(coupleId).get();
      if (!coupleDoc.exists || coupleDoc.data() == null) return null;
      final data = coupleDoc.data() as Map<String, dynamic>;
      if (data['user1Id'] == userId) {
        return data['user2Id'] as String?;
      } else if (data['user2Id'] == userId) {
        return data['user1Id'] as String?;
      }
      return null;
    } catch (e) {
      throw Exception('Failed to fetch partner ID: ${e.toString()}');
    }
  }

  /// Check if a user exists in Firestore
Future<bool> checkIfUserExists(String userId) async {
  try {
    DocumentSnapshot userDoc = await _firestore.collection('users').doc(userId).get();
    return userDoc.exists; // Returns true if the user exists, false otherwise
  } catch (e) {
    throw Exception('Failed to check if user exists: ${e.toString()}');
  }
}

/// Get the local path for storing the profile image
   Future<File?> _getLocalProfileImage(String userId) async {
    final directory = await getApplicationDocumentsDirectory();
    final filePath = '${directory.path}/profile_$userId.jpg';
    final file = File(filePath);
    
    if (file.existsSync()) {
      print("✅ Found local image at: $filePath");
      return file;
    } else {
      print("❌ No local image found for $userId");
      return null;
    }
  }

  Future<void> _saveProfileImageLocally(String userId, Uint8List imageBytes) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final filePath = '${directory.path}/profile_$userId.jpg';
      final file = File(filePath);
      
      await file.writeAsBytes(imageBytes);
      print("📥 Image saved locally at: $filePath");
    } catch (e) {
      print("⚠️ Error saving image locally: $e");
    }
  }

  Future<String?> getProfileImage(String userId, String profileImageUrl) async {
    print("🔍 Checking for local image...");
    final localImage = await _getLocalProfileImage(userId);

    if (localImage != null) {
      print("✅ Using local image.");
      return localImage.path; // Load from local storage
    } else {
      print("🌍 Fetching image from Cloudinary: $profileImageUrl");
      try {
        final response = await http.get(Uri.parse(profileImageUrl));
        if (response.statusCode == 200) {
          print("✅ Image downloaded successfully.");
          await _saveProfileImageLocally(userId, response.bodyBytes);
          
          final newLocalImage = await _getLocalProfileImage(userId);
          if (newLocalImage != null) {
            print("✅ Now using newly saved local image.");
            return newLocalImage.path;
          }
        } else {
          print("⚠️ Failed to download image. Status Code: ${response.statusCode}");
        }
      } catch (e, stack) {
        try {
          FirebaseCrashlytics.instance.recordError(e, stack, reason: 'UserRepository.getProfileImage failed for $userId');
          FirebaseCrashlytics.instance.log('Error fetching profile image: ${e.toString()}');
        } catch (_) {}
        print("⚠️ Error fetching profile image: $e");
      }
    }
    return null;
  }

  Future<void> updateUserLocation(String userId, double latitude, double longitude) async {
  try {
    await _firestore.collection('users').doc(userId).update({
      'latitude': latitude,
      'longitude': longitude,
    });
  } catch (e) {
    throw Exception('Failed to update location: ${e.toString()}');
  }
}

  // Generates a unique 6-character couple code and assigns it to the user
  Future<String> generateAndAssignCoupleCode(String userId) async {
    final chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    // 1. Use a proper Random generator, not just time
    final random = Random();
    final codesRef = _firestore.collection('coupleCodes');
    final userRef = _firestore.collection('users').doc(userId);

    // 2. Define how many times to retry before failing
    const maxAttempts = 10;

    // 3. Run the entire logic as a single, atomic transaction
    return await _firestore.runTransaction((transaction) async {
      for (int attempt = 0; attempt < maxAttempts; attempt++) {
        // 4. Generate a much more random code
        final code = String.fromCharCodes(Iterable.generate(
          6,
          (_) => chars.codeUnitAt(random.nextInt(chars.length)),
        ));

        final codeDocRef = codesRef.doc(code);

        // 5. Read the document *inside* the transaction
        final doc = await transaction.get(codeDocRef);

        if (!doc.exists) {
          // 6. If it's free, write both documents and return
          transaction.set(codeDocRef, {'userId': userId});
          transaction.update(userRef, {'coupleCode': code});
          
          // 7. Success! Return the code.
          return code;
        }
        // 8. If doc.exists, the loop continues and generates a new code
      }

      // 9. If we tried 10 times and failed, throw an error.
      throw Exception('Failed to generate a unique couple code after $maxAttempts attempts.');
    });
  }

  // Looks up a userId by couple code
  Future<String?> getUserIdByCoupleCode(String code) async {
    final doc = await _firestore.collection('coupleCodes').doc(code).get();
    if (doc.exists && doc.data() != null && doc.data()!['userId'] != null) {
      return doc.data()!['userId'] as String;
    }
    return null;
  }

  /// Update the user's love language
  Future<void> updateUserLoveLanguage({
    required String userId,
    String? loveLanguage,
  }) async {
    try {
      await updateUserData(
        userId: userId,
        updatedFields: {'loveLanguage': loveLanguage},
      );
    } catch (e) {
      throw Exception('Failed to update love language: ${e.toString()}');
    }
  }

  /// Update the user's gender
  Future<void> updateUserGender({
    required String userId,
    String? gender,
  }) async {
    try {
      await updateUserData(
        userId: userId,
        updatedFields: {'gender': gender},
      );
    } catch (e) {
      throw Exception('Failed to update gender: ${e.toString()}');
    }
  }

  Future<Map<String, dynamic>?> fetchPartnerData(String coupleId, String currentUserId) async {
    try {
      // Step 1: Run the couple doc lookup and the inactivity check IN PARALLEL
      final results = await Future.wait([
        _firestore.collection('couples').doc(coupleId).get(),
        CoupleRepository().isCoupleInactive(coupleId), // Re-uses your existing logic
      ]);

      final coupleDoc = results[0] as DocumentSnapshot;
      final isInactive = results[1] as bool;

      if (!coupleDoc.exists) {
        print("fetchPartnerData: Couple doc $coupleId not found.");
        return null;
      }

      // Step 2: Synchronously find the partner's ID from the couple doc
      final data = coupleDoc.data() as Map<String, dynamic>;
      String? partnerId;
      if (data['user1Id'] == currentUserId) {
        partnerId = data['user2Id'] as String?;
      } else if (data['user2Id'] == currentUserId) {
        partnerId = data['user1Id'] as String?;
      }

      if (partnerId == null) {
        print("fetchPartnerData: Partner ID not found in couple doc.");
        return null;
      }

      // Step 3: Fetch the partner's user document
      DocumentSnapshot partnerDoc = await _firestore.collection('users').doc(partnerId).get();

      if (!partnerDoc.exists) {
         print("fetchPartnerData: Partner user doc $partnerId not found.");
        return null;
      }

      final partnerData = Map<String, dynamic>.from(partnerDoc.data() as Map<String, dynamic>);

      // Step 4: Apply the inactivity logic
      if (isInactive) {
        partnerData.remove('profileImageUrl'); // Hides image if inactive
      }

      return partnerData;

    } catch (e) {
      print("Error in fetchPartnerData: $e");
      // Re-throw so the provider can handle it
      throw Exception('Failed to fetch partner data: ${e.toString()}');
    }
  }

Future<void> sendConnectionUpdate(String receiverId) async {
    try {
      // Step 1: Get OAuth 2.0 Access Token
      String? accessToken = await OAuthService.getAccessToken();
      if (accessToken == null) {
        print("Failed to get OAuth Token for connection update");
        return;
      }

      // Step 2: Retrieve Receiver's FCM Token
      DocumentSnapshot receiverSnapshot = await _firestore.collection('users').doc(receiverId).get();
      if (!receiverSnapshot.exists) return; // User doesn't exist

      final receiverData = receiverSnapshot.data() as Map<String, dynamic>;
      String? fcmToken = receiverData['fcmToken'];

      if (fcmToken != null) {
        // Step 3: Send the *silent data message*
        // Notice there is NO "notification" block, only "data".
        final response = await http.post(
          Uri.parse("https://fcm.googleapis.com/v1/projects/feelings-d43f8/messages:send"),
          headers: {
            "Authorization": "Bearer $accessToken",
            "Content-Type": "application/json",
          },
          body: jsonEncode({
            "message": {
              "token": fcmToken,
              "data": {
                "type": "connection_updated", // This is the key
                "timestamp": DateTime.now().millisecondsSinceEpoch.toString(),
              }
            },
          }),
        );
        print("FCM Silent Connection Update Response: ${response.body}");
      }
    } catch (e, stack) {
      try {
        FirebaseCrashlytics.instance.recordError(e, stack, reason: 'sendConnectionUpdate failed');
      } catch (_) {}
      print("sendConnectionUpdate error: $e");
      // Do not rethrow, we don't want to fail the connection for this.
    }
  }

  // ===========================================================================
  // ✨ ENCRYPTION & KEY MANAGEMENT
  // ===========================================================================

  /// Get the user's encryption status ('pending', 'enabled', 'disabled')
  Future<String> getEncryptionStatus(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists && doc.data() != null) {
        return doc.data()!['encryptionStatus'] as String? ?? 'pending';
      }
      return 'pending';
    } catch (e) {
      print('Error getting encryption status: $e');
      return 'pending';
    }
  }

  /// Update the user's encryption status
  Future<void> setEncryptionStatus(String userId, String status) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'encryptionStatus': status,
        'lastEncryptionStatusUpdate': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error setting encryption status: $e');
      throw Exception('Failed to update encryption status');
    }
  }

  /// Upload the encrypted Master Key backup
  Future<void> uploadKeyBackup(String userId, Map<String, dynamic> encryptedBlob) async {
    try {
      // We store the backup in a subcollection to keep the user document light
      // and to allow for strict security rules (e.g., create-only, no update).
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('key_backup')
          .doc('master_key')
          .set({
        ...encryptedBlob,
        'createdAt': FieldValue.serverTimestamp(),
        'version': 1,
      });

      // Automatically mark encryption as enabled once a backup is uploaded
      await setEncryptionStatus(userId, 'enabled');
    } catch (e) {
      print('Error uploading key backup: $e');
      throw Exception('Failed to upload key backup');
    }
  }

  /// Retrieve the encrypted Master Key backup
  Future<Map<String, dynamic>?> getKeyBackup(String userId) async {
    try {
      final doc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('key_backup')
          .doc('master_key')
          .get();

      if (doc.exists) {
        return doc.data();
      }
      return null;
    } catch (e) {
      print('Error getting key backup: $e');
      return null;
    }
  }

}