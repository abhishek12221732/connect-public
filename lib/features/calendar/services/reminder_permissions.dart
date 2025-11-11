// // reminder_permissions.dart

// import 'package:android_intent_plus/android_intent.dart';
// import 'package:flutter/material.dart';

// /// Launches the system settings page for exact alarms.
// void openExactAlarmSettings() {
//   final AndroidIntent intent = AndroidIntent(
//     action: 'android.settings.REQUEST_SCHEDULE_EXACT_ALARM',
//   );
//   intent.launch();
// }

// /// Shows a dialog prompting the user to enable exact alarms.
// /// If the user agrees, it opens the settings page.
// Future<void> requestExactAlarmPermission(BuildContext context) async {
//   return showDialog<void>(
//     context: context,
//     barrierDismissible: false, // User must tap a button.
//     builder: (BuildContext dialogContext) {
//       return AlertDialog(
//         title: const Text("Exact Alarms Permission Required"),
//         content: const Text(
//           "To ensure your reminders trigger exactly when needed, please enable the permission to schedule exact alarms in your device settings.",
//         ),
//         actions: <Widget>[
//           TextButton(
//             child: const Text("Cancel"),
//             onPressed: () {
//               Navigator.of(dialogContext).pop(); // Dismiss the dialog.
//             },
//           ),
//           TextButton(
//             child: const Text("Open Settings"),
//             onPressed: () {
//               Navigator.of(dialogContext).pop(); // Dismiss the dialog.
//               openExactAlarmSettings();
//             },
//           ),
//         ],
//       );
//     },
//   );
// }
