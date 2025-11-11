import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:shared_preferences/shared_preferences.dart';

class ReminderService {
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  static final bool _initialized = false;

  ReminderService();

  // ✨ [NEW] Define the channel as a constant to ensure it's always the same.
  // static const AndroidNotificationChannel channel = AndroidNotificationChannel(
  //   'reminder_channel', // id
  //   'Reminder Notifications', // title
  //   description: 'This channel is used for event and milestone reminders.', // description
  //   importance: Importance.max,
  //   playSound: true,
  // );



 Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
  }) async {
    final tz.TZDateTime scheduledTime = tz.TZDateTime.from(scheduledDate, tz.local);
    print('[ReminderService] Scheduling notification on channel: reminder_channel');
    
    // ✨ [CHANGED] Reference the static channel object for consistency.
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'reminder_channel',
      'Reminder Notifications',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
    );
    const NotificationDetails details = NotificationDetails(android: androidDetails);
    
    await _localNotifications.zonedSchedule(
      id,
      title,
      body,
      scheduledTime,
      details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: null,
    );
    print('[ReminderService] Notification scheduled (id=$id)');
  }


  Future<void> cancelNotification(int id) async {
    print('[ReminderService] Canceling notification: id=$id');
    await _localNotifications.cancel(id);
    print('[ReminderService] Notification canceled (id=$id)');
  }

  // Future<void> testImmediateNotification() async {
  //   print('[ReminderService] Showing immediate test notification');
  //   const AndroidNotificationDetails androidDetails =
  //       AndroidNotificationDetails(
  //     'reminder_channel',
  //     'Reminder Notifications',
  //     channelDescription: 'This is a reminder from the connect app.',
  //     importance: Importance.max,
  //     priority: Priority.high,
  //     playSound: true,
  //   );
  //   const NotificationDetails details =
  //       NotificationDetails(android: androidDetails);
  //   await _localNotifications.show(
  //     99999, // test notification id
  //     'Test Immediate Notification',
  //     'If you see this, notifications are working!',
  //     details,
  //   );
  //   print('[ReminderService] Immediate test notification shown');
  // }
}
