import 'dart:convert';
import 'package:googleapis_auth/auth_io.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:feelings/utils/crashlytics_helper.dart';

class OAuthService {
  static Future<String?> getAccessToken() async {
    try {
      // Load the service account JSON file
      final jsonString = await rootBundle.loadString('assets/service_account.json');
      final credentials = ServiceAccountCredentials.fromJson(json.decode(jsonString));

      // Get an OAuth2 client
      final client = await clientViaServiceAccount(
        credentials,
        ['https://www.googleapis.com/auth/firebase.messaging'],
      );

      // Fetch the access token
      return client.credentials.accessToken.data;
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
}
