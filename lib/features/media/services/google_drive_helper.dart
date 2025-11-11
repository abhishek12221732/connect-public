import 'dart:io';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart';

class GoogleDriveHelper {
  GoogleSignIn? _googleSignIn;
  GoogleSignInAccount? _user;
  drive.DriveApi? _driveApi;

  // Lazy initialization of GoogleSignIn
  GoogleSignIn get _getGoogleSignIn {
    if (_googleSignIn == null) {
      // Only initialize GoogleSignIn on non-web platforms
      if (!kIsWeb) {
        _googleSignIn = GoogleSignIn(
          scopes: [drive.DriveApi.driveFileScope], // Permission to upload files
        );
      }
    }
    return _googleSignIn!;
  }

  /// Sign in to Google
  Future<void> signIn() async {
    // Skip Google Sign-In on web platform
    if (kIsWeb) {
      print("Google Sign-In not supported on web platform");
      throw Exception('Google Sign-In is not supported on web platform');
    }

    // ✨ Try to sign in silently first
    _user = await _getGoogleSignIn.signInSilently();

    // If silent fails, then show the prompt
    _user ??= await _getGoogleSignIn.signIn();
    
    if (_user == null) return; // User canceled sign-in

    final authHeaders = await _user!.authHeaders;
    final client = GoogleAuthClient(authHeaders);
    _driveApi = drive.DriveApi(client);
  }

  Future<String?> uploadChatImage(File file, Function(double)? onProgress) async {
    // Skip upload on web platform
    if (kIsWeb) {
      print("Google Drive upload not supported on web platform");
      throw Exception('Google Drive upload is not supported on web platform');
    }

    // 1. Ensure we are signed in (this will now try silently first)
    if (_driveApi == null) await signIn();
    if (_driveApi == null) throw Exception('Google Sign-In failed');


    // 2. We no longer call ImagePicker. We use the file provided.
    drive.File driveFile = drive.File();
    driveFile.name = "Chat_${DateTime.now().millisecondsSinceEpoch}.jpg";

    final fileStream = file.openRead();
    final media = drive.Media(fileStream, file.lengthSync());

    // 3. Handle progress
    // Note: Google Drive API's 'create' doesn't support progress.
    // This is a limitation of the API, not our code.
    // We'll just call the progress callback to show it started/ended.
    onProgress?.call(0.2); // 20% - Upload started

    final uploadedFile = await _driveApi!.files.create(
      driveFile,
      uploadMedia: media,
    );

    onProgress?.call(1.0); // 100% - Upload finished
    
    // Return the ID, not the full URL
    return uploadedFile.id;
  }

  /// Upload an image to Google Drive
  Future<String?> uploadToGoogleDrive() async {
    // Skip upload on web platform
    if (kIsWeb) {
      print("Google Drive upload not supported on web platform");
      throw Exception('Google Drive upload is not supported on web platform');
    }

    if (_driveApi == null) await signIn();

    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile == null) return null;

    File file = File(pickedFile.path);
    drive.File driveFile = drive.File();
    driveFile.name = "Memory_${DateTime.now().millisecondsSinceEpoch}.jpg";

    final fileStream = file.openRead();
    final media = drive.Media(fileStream, file.lengthSync());

    final uploadedFile = await _driveApi!.files.create(
      driveFile,
      uploadMedia: media,
    );

    return "https://drive.google.com/uc?export=view&id=${uploadedFile.id}"; // Public URL
  }

  /// Get web-compatible image URL with multiple fallback strategies
  static String getWebImageUrl(String imageId) {
    // List of CORS proxy services to try
    final corsProxies = [
      "https://api.allorigins.win/raw?url=",
      "https://cors-anywhere.herokuapp.com/",
      "https://thingproxy.freeboard.io/fetch/",
      "https://cors.bridged.cc/",
    ];
    
    final googleDriveUrl = "https://drive.google.com/uc?export=view&id=$imageId";
    
    // For now, return the first proxy (you can implement rotation logic)
    return "${corsProxies[0]}${Uri.encodeComponent(googleDriveUrl)}";
  }

  /// Get alternative image URL formats for fallback
  static List<String> getAlternativeImageUrls(String imageId) {
    final baseUrl = "https://drive.google.com/uc?export=view&id=$imageId";
    final corsProxies = [
      "https://api.allorigins.win/raw?url=",
      "https://cors-anywhere.herokuapp.com/",
      "https://thingproxy.freeboard.io/fetch/",
      "https://cors.bridged.cc/",
    ];
    
    return corsProxies.map((proxy) => "$proxy${Uri.encodeComponent(baseUrl)}").toList();
  }
}

class GoogleAuthClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _client = http.Client();

  GoogleAuthClient(this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(_headers);
    return _client.send(request);
  }
}
