import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

/// Helper class to centralize Crashlytics reporting and ensure consistent error handling
class CrashlyticsHelper {
  static final _instance = CrashlyticsHelper._();
  factory CrashlyticsHelper() => _instance;
  CrashlyticsHelper._();

  // Track if Crashlytics is available (for test mode)
  static bool _isInitialized = false;
  
  /// Initialize Crashlytics - call this in main() before using
  static Future<void> initialize() async {
    try {
      // Try to check if Crashlytics is available
      await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(true);
      _isInitialized = true;
    } catch (e) {
      // Crashlytics not available (test mode or disabled)
      _isInitialized = false;
      print('ℹ️  Crashlytics not available: $e');
    }
  }
  
  /// Disable Crashlytics (for test mode)
  static void disable() {
    _isInitialized = false;
  }

  /// Report an error to Crashlytics with context
  void reportError(
    Object error,
    StackTrace? stack, {
    String? reason,
    Map<String, String>? keys,
  }) {
    // If Crashlytics is not initialized, just print the error
    if (!_isInitialized) {
      print('📝 Error (Crashlytics disabled): $error');
      if (stack != null) print('Stack: $stack');
      return;
    }
    
    try {
      // Do not report common layout/render overflow errors — these are
      // benign UI issues that occur frequently on smaller screens and
      // clutter Crashlytics. Filter them centrally here.
      final message = error.toString();
      final overflowPattern = RegExp(
        r"render(flex|box).*overflow|overflowed|was not laid out",
        caseSensitive: false,
      );
      if (overflowPattern.hasMatch(message)) {
        // Optionally log locally for debugging, but do not send to Crashlytics
        // print('Filtered overflow error from Crashlytics: $message');
        return;
      }

      if (keys != null) {
        for (final entry in keys.entries) {
          FirebaseCrashlytics.instance.setCustomKey(entry.key, entry.value);
        }
      }

      FirebaseCrashlytics.instance.recordError(
        error,
        stack,
        reason: reason,
      );
    } catch (e) {
      // Fail silently - we don't want Crashlytics reporting to break the app
      print('⚠️  Crashlytics error: $e');
    }
  }

  /// Log a message to Crashlytics for additional context
  void log(String message) {
    // If Crashlytics is not initialized, just print the message
    if (!_isInitialized) {
      print('📝 Log (Crashlytics disabled): $message');
      return;
    }
    
    try {
      // Filter out noisy render overflow logs which are not actionable
      final overflowPattern = RegExp(
        r"render(flex|box).*overflow|overflowed|was not laid out",
        caseSensitive: false,
      );
      if (overflowPattern.hasMatch(message)) {
        // print('Filtered overflow log from Crashlytics: $message');
        return;
      }

      FirebaseCrashlytics.instance.log(message);
    } catch (e) {
      // Fail silently
      print('⚠️  Crashlytics error: $e');
    }
  }

  /// Set the user identifier in Crashlytics to correlate errors with users
  void setUserId(String userId) {
    if (!_isInitialized) return;
    
    try {
      FirebaseCrashlytics.instance.setUserIdentifier(userId);
    } catch (e) {
      // Fail silently
      print('⚠️  Crashlytics error: $e');
    }
  }
  
  /// Record Flutter fatal error
  static Future<void> recordFlutterFatalError(FlutterErrorDetails errorDetails) async {
    if (!_isInitialized) {
      print('📝 Fatal Error (Crashlytics disabled): ${errorDetails.exception}');
      return;
    }
    
    try {
      await FirebaseCrashlytics.instance.recordFlutterFatalError(errorDetails);
    } catch (e) {
      print('⚠️  Crashlytics error: $e');
    }
  }
  
  /// Record general error
  static Future<void> recordError(
    dynamic error,
    StackTrace? stack, {
    bool fatal = false,
  }) async {
    if (!_isInitialized) {
      print('📝 Error (Crashlytics disabled): $error');
      if (stack != null) print('Stack: $stack');
      return;
    }
    
    try {
      await FirebaseCrashlytics.instance.recordError(error, stack, fatal: fatal);
    } catch (e) {
      print('⚠️  Crashlytics error: $e');
    }
  }
}
