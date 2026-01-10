import 'dart:convert';
import 'package:googleapis_auth/auth_io.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:feelings/utils/crashlytics_helper.dart';

class OAuthService {
  // ✨ Cache token to avoid redundant OAuth handshakes
  static String? _cachedToken;
  static DateTime? _tokenExpiry;
  
  static Future<String?> getAccessToken() async {
    try {
      // Return cached token if still valid (tokens typically valid for 1 hour)
      if (_cachedToken != null && 
          _tokenExpiry != null && 
          DateTime.now().isBefore(_tokenExpiry!)) {
        print('Using cached OAuth token');
        return _cachedToken;
      }
      
      print('Fetching new OAuth token...');
      // Load the service account JSON file
      final jsonString = await rootBundle.loadString('assets/service_account.json');
      final credentials = ServiceAccountCredentials.fromJson(json.decode(jsonString));

      // Get an OAuth2 client
      final client = await clientViaServiceAccount(
        credentials,
        ['https://www.googleapis.com/auth/firebase.messaging'],
      );

      // Fetch and cache the access token (valid for ~55 minutes, we refresh at 50)
      _cachedToken = client.credentials.accessToken.data;
      _tokenExpiry = DateTime.now().add(const Duration(minutes: 50));
      
      print('New OAuth token cached until $_tokenExpiry');
      return _cachedToken;
    } catch (e, stack) {
      final crashlytics = CrashlyticsHelper();
      crashlytics.reportError(
        e,
        stack,
        reason: 'OAuthService.getAccessToken failed',
      );
      crashlytics.log('OAuthService.getAccessToken error: ${e.toString()}');
      print("Error getting access token: $e");
      return null;
    }
  }
  
  // ✨ Method to force token refresh if needed
  static void clearCache() {
    _cachedToken = null;
    _tokenExpiry = null;
  }
}
