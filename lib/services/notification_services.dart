import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;
import 'package:flutter_timezone/flutter_timezone.dart';
// Conditional import for dart:html
import '../web_utils.dart' if (dart.library.html) '../web_utils_web.dart';
import 'package:feelings/utils/crashlytics_helper.dart';
import 'package:feelings/main.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:feelings/providers/user_provider.dart';
import 'package:feelings/providers/couple_provider.dart';


class NotificationService {
  static final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static void Function()? onNotificationClick;
  static String? _currentUserId;
  

  // (NEW) A simple flag to track if the chat screen is currently visible.
  static bool isChatScreenActive = false;

  // ✨ [NEW] Define the reminder channel here.
  static const AndroidNotificationChannel reminderChannel = AndroidNotificationChannel(
    'reminder_channel',
    'Reminder Notifications',
    description: 'This channel is used for event and milestone reminders.',
    importance: Importance.max,
    playSound: true,
  );

  static Future<void> initialize() async {
    // Skip notification setup on web platforms
    if (kIsWeb) {
      // Detect iOS web and show a message
      final userAgent = WebUtils.getUserAgent();
      if (userAgent.contains('iphone') ||
          userAgent.contains('ipad') ||
          userAgent.contains('ipod')) {
        // print('NotificationService: Push notifications are not available on iOS web.');
        // Optionally, you can trigger a callback or set a flag here for UI display
        return;
      }
      // print('NotificationService: Skipping notification setup on web platform');
      return;
    }

    // Check if we're on iOS and skip if needed
    if (!kIsWeb && Platform.isIOS) {
      try {
        await _firebaseMessaging.requestPermission(
          alert: true,
          badge: true,
          sound: true,
        );
      } catch (e, stack) {
          final crashlytics = CrashlyticsHelper();
          crashlytics.reportError(
            e,
            stack,
            reason: 'NotificationService.requestPermission (iOS) failed',
          );
          crashlytics.log('NotificationService iOS permission error: ${e.toString()}');
        // print('NotificationService: Error requesting iOS permissions: $e');
        return;
      }
    } else if (!kIsWeb && Platform.isAndroid) {
      // Android permission request
      await _firebaseMessaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
    }

    const DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const AndroidInitializationSettings androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    
    final InitializationSettings initSettings = InitializationSettings(
      android: androidInit,
      iOS: initializationSettingsDarwin,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onDidReceiveNotificationResponse,
    );

    tz.initializeTimeZones(); 
    // ✨ [MOVED] Timezone configuration is now centralized here.
    await _configureTimeZones();

    // ✨ [ADDED] Explicitly create the reminder channel.
    final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
        _localNotifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (androidImplementation != null) {
      await androidImplementation.createNotificationChannel(reminderChannel);
    }
    
    _firebaseMessaging.onTokenRefresh.listen((newToken) {
      // print('FCM Token refreshed: $newToken');
      _updateFcmTokenInFirestore(newToken);
    });

    // (MODIFIED) Foreground message handling now checks the flag.
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      // If the chat screen is active, do nothing.
      if (message.data['type'] == 'connection_updated') {
    print("Received connection update! Refreshing data...");
    
    // Get the navigator's context
    final context = navigatorKey.currentContext;
    if (context != null) {
      // Manually trigger the original fetch functions
      context.read<UserProvider>().fetchUserData();
      
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        context.read<CoupleProvider>().fetchCoupleAndPartnerData(user.uid);
      }
    }
    return; // Stop here, we don't want to show a notification
  }
      if (isChatScreenActive) {
        // print('Notification suppressed: User is on the chat screen.');
        return;
      }
      
      // Otherwise, show the notification.
      if (message.notification != null) {
        // Pass the full message to get access to the data payload.
        _showNotification(message);
      }
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      if (onNotificationClick != null) {
        onNotificationClick!();
      }
    });
  }

  // This callback is preserved as you had it.
  // static void _onDidReceiveLocalNotification(
  //     int id, String? title, String? body, String? payload) async {
  //   // print('Notification received (iOS < 10, deprecated path): id $id, title: $title, body: $body, payload: $payload');
  // }

  static void _onDidReceiveNotificationResponse(NotificationResponse response) {
    if (onNotificationClick != null) {
      onNotificationClick!();
    }
    final String? payload = response.payload;
    if (payload != null) {
      // print('Notification tapped (iOS 10+ / Android): Payload: $payload');
    }
  }

  // (NEW) Method to dismiss a specific notification when its message is seen.
  static Future<void> dismissNotificationForMessage(String messageId) async {
    // Generate the same unique integer ID from the messageId string.
    final int notificationId = messageId.hashCode.abs() % 1000000;
    await _localNotifications.cancel(notificationId);
    // print('Dismissed notification for messageId: $messageId (ID: $notificationId)');
  }

  // Create a notification channel for a specific partner
  static Future<void> createPartnerNotificationChannel(String partnerName) async {
    final AndroidNotificationChannel channel = AndroidNotificationChannel(
      'chat_${partnerName.toLowerCase().replaceAll(' ', '_')}',
      partnerName, // This will show in the notification header
      description: 'Chat notifications from $partnerName',
      importance: Importance.max,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  // (MODIFIED) This method now takes the full RemoteMessage to access the data payload
  // for creating a unique notification ID.
 // (MODIFIED) This method now uses a dynamic channel ID to match the created channel.
// (MODIFIED) This method now customizes the content of individual and summary notifications.
static Future<void> _showNotification(RemoteMessage message) async {
  final notification = message.notification;
  if (notification == null) return;

  // --- Get Data and Define Keys ---
  final String? messageId = message.data['messageId'];
  final String? partnerName = message.data['partnerName'];
  final String? messageText = message.data['messageText'];

  // // Debug logging to see what we're receiving
  // print('NotificationService: FCM notification title = ${notification.title}');
  // print('NotificationService: FCM notification body = ${notification.body}');
  // print('NotificationService: FCM data partnerName = $partnerName');
  // print('NotificationService: FCM data messageText = $messageText');
  // print('NotificationService: FCM data messageId = $messageId');

  // Use a timestamp-based ID to help with ordering
  final int messageNotificationId = (messageId?.hashCode ?? DateTime.now().millisecondsSinceEpoch).abs() % 1000000;
  // Add a timestamp component to help with ordering in grouped view
  final int orderedNotificationId = messageNotificationId + (DateTime.now().millisecondsSinceEpoch % 1000);
  // final String title = partnerName ?? "New Message";
  final String body = messageText ?? notification.body ?? 'You have a new message';

  // print('NotificationService: Final title = $title');
  // print('NotificationService: Final body = $body');

  // (FIX) Create a unique group key AND summary ID for each partner
  // This ensures chats from different people do not mix.
  final String groupKey = 'chat_${partnerName ?? "default"}';
  final int groupSummaryId = (partnerName?.hashCode ?? 0);

  final String channelId = 'chat_${(partnerName ?? "default").toLowerCase().replaceAll(' ', '_')}';
  final String channelName = partnerName ?? 'Chat Messages';

  // --- ANDROID NOTIFICATION DETAILS ---

  // Details for the individual message notification
  final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
    channelId,
    channelName,
    importance: Importance.max,
    priority: Priority.high,
    groupKey: groupKey, // Use partner-specific group key
  );

  // Details for the group summary notification
  final AndroidNotificationDetails groupSummaryNotificationDetails = AndroidNotificationDetails(
    channelId,
    channelName,
    importance: Importance.max,
    priority: Priority.high,
    groupKey: groupKey, // Use partner-specific group key
    setAsGroupSummary: true,
    styleInformation: InboxStyleInformation(
      [], // Let the system build the lines from the individual notifications
      contentTitle: null, // (FIX) Remove title from grouped messages
      summaryText: 'New messages',
    ),
  );

  // --- iOS DETAILS ---
  final DarwinNotificationDetails iOSDetails = DarwinNotificationDetails(
    presentAlert: true,
    presentBadge: true,
    presentSound: true,
    threadIdentifier: groupKey, // Use partner-specific group key for iOS grouping
  );

  final NotificationDetails details = NotificationDetails(
    android: androidDetails,
    iOS: iOSDetails,
  );

  // --- SHOW NOTIFICATIONS ---

  // 1. Show the individual message notification
  // We pass 'null' as the title so only the body appears in the summary list.
  await _localNotifications.show(
    orderedNotificationId,
    null, // (FIX) No title for individual messages in grouped view
    body,  // Body is the message content
    details,
  );

  // 2. Show the group summary notification
  // The title/body here control the look of the COLLAPSED group.
  await _localNotifications.show(
    groupSummaryId, // Use a partner-specific ID for the summary
    null,           // (FIX) Remove title from grouped messages
    body,           // Collapsed Body = The latest message
    NotificationDetails(android: groupSummaryNotificationDetails),
  );
} 
  
  
  static Future<void> _configureTimeZones() async {
    try {
      final String timeZoneName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timeZoneName == 'Asia/Calcutta' ? 'Asia/Kolkata' : timeZoneName));
    } catch (e, stack) {
      final crashlytics = CrashlyticsHelper();
      crashlytics.reportError(
        e,
        stack,
        reason: 'NotificationService._configureTimeZones failed',
      );
      crashlytics.log('Timezone configuration error: ${e.toString()}');
      tz.setLocalLocation(tz.getLocation('UTC'));
    }
  }
  
  
  
  
  static Future<void> clearAllNotifications() async {
    await _localNotifications.cancelAll();
    // print('All notifications cleared.');
  }

  // --- ALL YOUR HELPER FUNCTIONS ARE PRESERVED BELOW ---

  static void setCurrentUserId(String userId) {
    _currentUserId = userId;
    // Only update FCM token on mobile platforms
    if (!kIsWeb) {
      _updateFcmTokenForUser(userId);
    }
  }

  static Future<void> _updateFcmTokenForUser(String userId) async {
    // Skip on web platforms
    if (kIsWeb) {
      // print('NotificationService: Skipping FCM token update on web platform');
      return;
    }

    try {
      String? token = await _firebaseMessaging.getToken();
      if (token != null) {
        await _firestore.collection('users').doc(userId).update({'fcmToken': token});
        // print('FCM Token updated for user $userId: $token');
      }
    } catch (e) {
      final crashlytics = CrashlyticsHelper();
      crashlytics.reportError(
        e,
        null,
        reason: 'NotificationService._updateFcmTokenForUser failed',
        keys: {'userId': userId},
      );
      crashlytics.log('Error updating FCM token: ${e.toString()}');
    }
  }

  static Future<void> _updateFcmTokenInFirestore(String newToken) async {
    // Skip on web platforms
    if (kIsWeb) {
      // print('NotificationService: Skipping FCM token refresh on web platform');
      return;
    }

    if (_currentUserId != null) {
      try {
        await _firestore.collection('users').doc(_currentUserId).update({'fcmToken': newToken});
        // print('FCM Token refreshed in Firestore for user $_currentUserId');
      } catch (e) {
          final crashlytics = CrashlyticsHelper();
          crashlytics.reportError(
            e,
            null,
            reason: 'NotificationService._updateFcmTokenInFirestore failed',
            keys: {'userId': _currentUserId ?? 'unknown'},
          );
          crashlytics.log('Error updating FCM token in Firestore: ${e.toString()}');
      }
    }
  }

  static Future<String?> getCurrentToken() async {
    // Skip on web platforms
    if (kIsWeb) {
      // print('NotificationService: Skipping FCM token retrieval on web platform');
      return null;
    }

    return await _firebaseMessaging.getToken();
  }

  static Future<String?> refreshToken() async {
    // Skip on web platforms
    if (kIsWeb) {
      // print('NotificationService: Skipping FCM token refresh on web platform');
      return null;
    }

    try {
      await _firebaseMessaging.deleteToken();
      String? newToken = await _firebaseMessaging.getToken();
      if (newToken != null && _currentUserId != null) {
        await _firestore.collection('users').doc(_currentUserId).update({'fcmToken': newToken});
        // print('FCM Token manually refreshed for user $_currentUserId: $newToken');
      }
      return newToken;
    } catch (e) {
      final crashlytics = CrashlyticsHelper();
      crashlytics.reportError(
        e,
        null,
        reason: 'NotificationService.refreshToken failed',
        keys: {'userId': _currentUserId ?? 'unknown'},
      );
      crashlytics.log('Error manually refreshing FCM token: ${e.toString()}');
      return null;
    }
  }

  static Future<Map<String, dynamic>> checkFcmStatus() async {
    // Skip on web platforms
    if (kIsWeb) {
      return {
        'hasToken': false,
        'token': null,
        'hasPermission': false,
        'currentUserId': _currentUserId,
        'platform': 'web',
        'message': 'FCM not supported on web platform',
      };
    }

    try {
      String? token = await _firebaseMessaging.getToken();
      NotificationSettings settings = await _firebaseMessaging.getNotificationSettings();
      
      return {
        'hasToken': token != null,
        'token': token,
        'hasPermission': settings.authorizationStatus == AuthorizationStatus.authorized,
        'currentUserId': _currentUserId,
        'authorizationStatus': settings.authorizationStatus.toString(),
        'platform': Platform.isIOS ? 'iOS' : 'Android',
      };
    } catch (e) {
      final crashlytics = CrashlyticsHelper();
      crashlytics.reportError(
        e,
        null,
        reason: 'NotificationService.checkFcmStatus failed',
        keys: {'userId': _currentUserId ?? 'unknown'},
      );
      crashlytics.log('Error checking FCM status: ${e.toString()}');
      return {
        'hasToken': false,
        'token': null,
        'hasPermission': false,
        'currentUserId': _currentUserId,
        'error': e.toString(),
        'platform': Platform.isIOS ? 'iOS' : 'Android',
      };
    }
  }

  static void clearCurrentUserId() {
    _currentUserId = null;
  }

  static Future<void> removeFcmTokenForUser(String userId) async {
    // Skip on web platforms
    if (kIsWeb) {
      // print('NotificationService: Skipping FCM token removal on web platform');
      return;
    }

    try {
      await _firebaseMessaging.deleteToken();
      await _firestore.collection('users').doc(userId).update({'fcmToken': FieldValue.delete()});
      // print('FCM token removed for user $userId');
    } catch (e) {
      final crashlytics = CrashlyticsHelper();
      crashlytics.reportError(
        e,
        null,
        reason: 'NotificationService.removeFcmTokenForUser failed',
        keys: {'userId': userId},
      );
      crashlytics.log('Error removing FCM token: ${e.toString()}');
    }
  }
}