import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:dio/dio.dart';
import 'package:mime/mime.dart';
import 'package:path/path.dart';
import 'dart:convert';
import 'package:http_parser/http_parser.dart';
import 'package:flutter/foundation.dart';

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

      if (account == null) {
        throw Exception('Google sign-in was cancelled or failed.');
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
      String coupleId, String imageId, String text, String userId) async {
    try {
      print("Saving media for coupleId: $coupleId");
      await _firestore
          .collection('couples')
          .doc(coupleId)
          .collection('media')
          .add({
        'imageId': imageId,
        'text': text,
        'createdBy': userId,
        'createdAt': Timestamp.now(),
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