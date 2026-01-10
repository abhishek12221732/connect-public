import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:dio/dio.dart';
import 'package:mime/mime.dart';
import 'package:path/path.dart';
import 'dart:convert';
import 'package:http_parser/http_parser.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart'; // ✨ Needed for SnackBar
import 'package:feelings/utils/globals.dart';
import 'package:feelings/services/encryption_service.dart';

class GoogleAuthCancelledException implements Exception {}

class MediaRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  GoogleSignIn? _googleSignIn;

  GoogleSignIn get _getGoogleSignIn {
    if (_googleSignIn == null) {
      if (!kIsWeb) {
        _googleSignIn = GoogleSignIn(
          scopes: ['https://www.googleapis.com/auth/drive.file'],
        );
      }
    }
    return _googleSignIn!;
  }

  Future<void> _setFilePublic(String fileId, String accessToken) async {
    final url = "https://www.googleapis.com/drive/v3/files/$fileId/permissions";
    try {
      final response = await Dio().post(
        url,
        options: Options(headers: {
          "Authorization": "Bearer $accessToken",
          "Content-Type": "application/json",
        }),
        data: jsonEncode({
          "role": "reader",
          "type": "anyone",
        }),
      );
      if (response.statusCode == 200) {
        print("✅ File is now public.");
      } else {
        print("❌ Failed to make file public: ${response.data}");
      }
    } catch (e) {
      print("❌ Error setting file public: $e");
    }
  }

  /// ✨ MODIFIED: This function now tries to sign in silently first.
  /// This is the fix for the "dimming" screen.
  Future<GoogleSignInAccount?> _signIn() async {
    try {
      if (kIsWeb) {
        throw Exception('Google Sign-In is not supported on web platform');
      }

      // 1. Try to sign in silently
      GoogleSignInAccount? account = await _getGoogleSignIn.signInSilently();

      // 2. If silent fails, show the prompt
      account ??= await _getGoogleSignIn.signIn();

      // ✨ 3. Handle Cancellation Globally
      if (account == null) {
        // 1. Show UI Message immediately via Global Key
        rootScaffoldMessengerKey.currentState?.showSnackBar(
          SnackBar(
            content: const Text('Sign-in cancelled. Image upload requires Google Drive access.'),
            backgroundColor: Colors.grey[800],
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );

        // 2. Throw specific exception to stop flow
        throw GoogleAuthCancelledException(); 
      }
      return account;
    } catch (e) {
      print("❌ Error during Google Sign-In: $e");
      throw Exception('Google sign-in failed: ${e.toString()}');
    }
  }

  /// ✨ MODIFIED: This is now the ONLY upload function.
  /// Both ChatProvider and MediaProvider will call this.
  /// It no longer picks an image; it receives one.
  Future<String?> uploadToGoogleDrive(
      File file, Function(double) onProgress) async {
    try {
      if (!await file.exists()) {
        throw Exception(
            'Selected file no longer exists. Please select another image.');
      }
      final fileSize = await file.length();
      if (fileSize > 10 * 1024 * 1024) {
        throw Exception(
            'File size too large. Please select an image smaller than 10MB.');
      }

      // ✨ Use our new silent-first sign-in
      final account = await _signIn();
      if (account == null) {
        print("❌ Google Sign-In required for upload.");
        return null;
      }

      final authentication = await account.authentication;
      final accessToken = authentication.accessToken;

      if (accessToken == null) {
        throw Exception('Failed to get access token. Please try signing in again.');
      }

      final mimeType = lookupMimeType(file.path) ?? 'image/jpeg';
      print("Uploading file: ${file.path}, MIME type: $mimeType");

      final url =
          "https://www.googleapis.com/upload/drive/v3/files?uploadType=multipart";
      final metadata = {
        "name": basename(file.path),
        "mimeType": mimeType,
      };

      FormData formData = FormData.fromMap({
        "metadata": MultipartFile.fromString(jsonEncode(metadata),
            contentType: MediaType('application', 'json')),
        "file": await MultipartFile.fromFile(file.path,
            contentType: MediaType.parse(mimeType)),
      });

      Dio dio = Dio();
      dio.options.connectTimeout = const Duration(seconds: 30);
      dio.options.receiveTimeout = const Duration(seconds: 60);

      final response = await dio.post(
        url,
        data: formData,
        options: Options(headers: {"Authorization": "Bearer $accessToken"}),
        onSendProgress: (sent, total) {
          if (total > 0) {
            double progress = sent / total;
            onProgress(progress);
          }
        },
      );

      if (response.statusCode == 200) {
        final fileId = response.data['id'];
        print("✅ File uploaded successfully, ID: $fileId");
        await _setFilePublic(fileId, accessToken);
        return fileId;
      } else {
        throw Exception('Upload failed with status: ${response.statusCode}');
      }
    } catch (e) {
      print("❌ Error uploading to Google Drive: $e");
      // Re-throw the specific exception message
      if (e is Exception) {
        throw e;
      } else {
        throw Exception('Upload failed: ${e.toString()}');
      }
    }
  }

  /// ✨ REMOVED: The broken uploadChatImage function is gone.

  /// Saves media details in Firestore
  Future<void> saveMedia(
      String coupleId, String imageId, String text, String userId, {bool isEncryptionEnabled = false}) async {
    try {
      // ✨ ENCRYPTION START
      String finalImageId = imageId;
      String finalText = text;
      String? ciphertextId;
      String? nonceId;
      String? macId;
      String? ciphertextText;
      String? nonceText;
      String? macText;
      int? encryptionVersion;
      
      print("🔒 [MediaRepo] saveMedia called. Encryption Ready? ${EncryptionService.instance.isReady}, Enabled? $isEncryptionEnabled");

      if (EncryptionService.instance.isReady && isEncryptionEnabled) {
         // 1. Encrypt Image ID
         final encId = await EncryptionService.instance.encryptText(imageId);
         ciphertextId = encId['ciphertext'];
         nonceId = encId['nonce'];
         macId = encId['mac'];
         // finalImageId = ""; // ✨ Don't hide completely if we want to allow hybrid? 
         // Actually, standard logic:
         finalImageId = ""; // Hide
         
         // 2. Encrypt Caption (if exists)
         if (text.isNotEmpty) {
           final encText = await EncryptionService.instance.encryptText(text);
           ciphertextText = encText['ciphertext'];
           nonceText = encText['nonce'];
           macText = encText['mac'];
           finalText = ""; // Hide
         }
         
         encryptionVersion = 1;
      }
      // ✨ ENCRYPTION END

      await _firestore
          .collection('couples')
          .doc(coupleId)
          .collection('media')
          .add({
        'imageId': finalImageId,
        'text': finalText,
        'createdBy': userId,
        'createdAt': Timestamp.now(),
        
        // Encrypted Fields for ID
        'ciphertextId': ciphertextId,
        'nonceId': nonceId,
        'macId': macId,
        
        // Encrypted Fields for Text
        'ciphertextText': ciphertextText,
        'nonceText': nonceText,
        'macText': macText,
        
        'encryptionVersion': encryptionVersion,
      });
      print("✅ Media saved successfully.");
    } catch (e) {
      print("❌ Error saving media to Firestore: $e");
      throw Exception('Failed to save memory: ${e.toString()}');
    }
  }

  /// Fetches media from Firestore
  Stream<List<Map<String, dynamic>>> fetchMedia(String coupleId) {
    try {
      print("Fetching media for coupleId: $coupleId");
      return _firestore
          .collection('couples')
          .doc(coupleId)
          .collection('media')
          .snapshots()
          .map((snapshot) {
        print("✅ Fetched ${snapshot.docs.length} media items.");
        final result = snapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'docId': doc.id,
            ...data,
          };
        }).toList();

        result.sort((a, b) {
          final aDate = (a['createdAt'] as Timestamp).toDate();
          final bDate = (b['createdAt'] as Timestamp).toDate();
          return bDate.compareTo(aDate); // Newest first
        });

        return result;
      });
    } catch (e) {
      print("❌ Error fetching media from Firestore: $e");
      return const Stream.empty();
    }
  }

  // ✨ --- NEW: MIGRATION METHOD ---
  Future<void> migrateLegacyMedia(String coupleId, String mediaId, Map<String, dynamic> data) async {
    if (!EncryptionService.instance.isReady) return;
    
    // Skip if already encrypted or missing crucial data
    if (data['encryptionVersion'] != null) return;
    
    // We only migrate if we have an imageId (text is optional)
    final imageId = data['imageId'] as String?;
    if (imageId == null || imageId.isEmpty) return; // Also check if imageId is empty string
    final text = data['text'] as String? ?? "";

    try {
      String? ciphertextId;
      String? nonceId;
      String? macId; // Added macId for imageId
      String? ciphertextText;
      String? nonceText;
      String? macText; // Added macId for text
      
      // 1. Encrypt Image ID
      final encId = await EncryptionService.instance.encryptText(imageId);
      ciphertextId = encId['ciphertext'];
      nonceId = encId['nonce'];
      macId = encId['mac']; // Assign macId
      
      // 2. Encrypt Text (if present)
      if (text.isNotEmpty) {
        final encText = await EncryptionService.instance.encryptText(text);
        ciphertextText = encText['ciphertext'];
        nonceText = encText['nonce'];
        macText = encText['mac']; // Assign macId
      }

      await _firestore
          .collection('couples')
          .doc(coupleId)
          .collection('media')
          .doc(mediaId)
          .update({
            // Hide original data
            'imageId': "", 
            'text': text.isNotEmpty ? "" : "",
            
            // Add encrypted fields
            'ciphertextId': ciphertextId,
            'nonceId': nonceId,
            'macId': macId, // Add macId to update
            'ciphertextText': ciphertextText,
            'nonceText': nonceText,
            'macText': macText, // Add macId to update
            'encryptionVersion': 1,
          });
          
      print("🔒 [Migration] Memory $mediaId migrated."); // Changed debugPrint to print
    } catch (e) {
      print("⚠️ [Migration] Memory $mediaId failed: $e"); // Changed debugPrint to print
    }
  }

  Future<void> deletePost(
      String coupleId, String docId, String imageId) async {
    try {
      await _firestore
          .collection('couples')
          .doc(coupleId)
          .collection('media')
          .doc(docId)
          .delete();
      // ✨ --- CHANGE --- ✨
      // Call the new public function
      await deleteFromGoogleDrive(imageId);
      // ✨ --- END OF CHANGE --- ✨
    } catch (e) {
      print("❌ Error deleting post: $e");
      throw Exception('Failed to delete memory: ${e.toString()}');
    }
  }

  // ✨ --- NEW PUBLIC DELETE FUNCTION --- ✨
  // This was formerly _deleteFromGoogleDrive
  Future<void> deleteFromGoogleDrive(String fileId) async {
    try {
      final account = await _getGoogleSignIn.signInSilently();
      if (account == null) {
        print("⚠️ No active Google account for Drive deletion");
        return;
      }
      final authentication = await account.authentication;
      if (authentication.accessToken == null) {
        print("⚠️ No access token for Drive deletion");
        return;
      }
      final url = "https://www.googleapis.com/drive/v3/files/$fileId";
      await Dio().delete(
        url,
        options: Options(
          headers: {
            "Authorization": "Bearer ${authentication.accessToken}",
          },
        ),
      );
      print("✅ File deleted from Google Drive");
    } catch (e) {
      print("❌ Error deleting from Google Drive: $e");
      // Don't rethrow, as this might be called from multiple places
      // and we don't want to block other deletions.
    }
  }
}