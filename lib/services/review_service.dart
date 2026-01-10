import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

class ReviewService {
  static final ReviewService _instance = ReviewService._internal();
  factory ReviewService() => _instance;
  ReviewService._internal();

  final InAppReview _inAppReview = InAppReview.instance;
  
  // Keys for SharedPreferences
  static const String _kInstallDateKey = 'app_install_date';
  static const String _kLastReviewRequestDateKey = 'last_review_request_date';
  
  // Configuration
  static const int _kDaysBeforeFirstRequest = 3;
  static const int _kDaysBetweenRequests = 30;
  static const String _kStoreUrl = 'https://play.google.com/store/apps/details?id=com.feelings.app';

  /// Initialize the service (call this at app startup)
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    if (!prefs.containsKey(_kInstallDateKey)) {
      await prefs.setInt(_kInstallDateKey, DateTime.now().millisecondsSinceEpoch);
      debugPrint('ReviewService: First run detected. Install date saved.');
    }
  }

  /// Checks if we should show the review prompt
  Future<bool> _shouldAskForReview() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();

    // 1. Check Install Date (First buffer)
    final installDateMs = prefs.getInt(_kInstallDateKey) ?? now.millisecondsSinceEpoch;
    final installDate = DateTime.fromMillisecondsSinceEpoch(installDateMs);
    final daysSinceInstall = now.difference(installDate).inDays;

    if (daysSinceInstall < _kDaysBeforeFirstRequest) {
      debugPrint('ReviewService: Too early. Installed $daysSinceInstall days ago (min $_kDaysBeforeFirstRequest).');
      return false;
    }

    // 2. Check Last Request Date (Cooldown)
    final lastRequestMs = prefs.getInt(_kLastReviewRequestDateKey);
    if (lastRequestMs != null) {
      final lastRequestDate = DateTime.fromMillisecondsSinceEpoch(lastRequestMs);
      final daysSinceLastRequest = now.difference(lastRequestDate).inDays;
      
      if (daysSinceLastRequest < _kDaysBetweenRequests) {
        debugPrint('ReviewService: Cooldown active. Last request $daysSinceLastRequest days ago (wait $_kDaysBetweenRequests).');
        return false;
      }
    }

    return true;
  }

  /// Triggers the native In-App Review dialog if conditions are met
  Future<void> requestSmartReview(BuildContext context) async {
    debugPrint('ReviewService: Requesting smart review...');
    final isAvailable = await _inAppReview.isAvailable();
    debugPrint('ReviewService: In-App Review Available? $isAvailable');

    if (!isAvailable) {
      debugPrint('ReviewService: In-App Review not available.');
      return;
    }

    final shouldAsk = await _shouldAskForReview();
    debugPrint('ReviewService: Should ask? $shouldAsk');
    
    if (!shouldAsk) return;

    try {
      debugPrint('ReviewService: Calling _inAppReview.requestReview()');
      await _inAppReview.requestReview();
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_kLastReviewRequestDateKey, DateTime.now().millisecondsSinceEpoch);
      debugPrint('ReviewService: Review requested successfully.');
    } catch (e) {
      debugPrint('ReviewService: Error requesting review: $e');
    }
  }

  /// Opens the store listing page directly (Manual trigger)
  Future<void> openStoreListing() async {
    // Try to open via in_app_review's helper first
    if (await _inAppReview.isAvailable()) {
      try {
        await _inAppReview.openStoreListing(appStoreId: 'com.feelings.app'); // appStoreId is mostly for iOS, Android uses package name automagically or we can use url fallback
        return;
      } catch (_) {
        // Fallback to URL launcher
      }
    }
    
    // Fallback: Launch URL manually
    final Uri url = Uri.parse(_kStoreUrl);
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      debugPrint('ReviewService: Could not launch store URL.');
    }
  }
}
