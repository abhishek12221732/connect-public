import 'package:flutter_test/flutter_test.dart';
import 'dart:async';

/// A simple logger class to make test output more readable.
class Log {
  static void i(String message) {
    // ignore: avoid_print
    print(message);
  }
}

/// Waits for a widget to appear in the widget tree with polling.
Future<void> waitForWidget(WidgetTester tester, Finder finder, {
  Duration timeout = const Duration(seconds: 15),
  Duration pollInterval = const Duration(milliseconds: 100),
}) async {
  final endTime = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(endTime)) {
    await tester.pump(pollInterval);
    if (finder.evaluate().isNotEmpty) {
      return;
    }
  }
  throw TestFailure('Widget not found within timeout: ${finder.toString()}');
}

/// Taps a widget with retry logic.
Future<void> tapWithRetry(WidgetTester tester, Finder finder, {
  int maxAttempts = 3,
  Duration retryDelay = const Duration(milliseconds: 500),
  bool warnIfMissed = true,
}) async {
  for (int attempt = 1; attempt <= maxAttempts; attempt++) {
    try {
      await waitForWidget(tester, finder, timeout: const Duration(seconds: 5));
      await tester.tap(finder, warnIfMissed: warnIfMissed);
      await tester.pumpAndSettle();
      Log.i('✅ Tap successful on attempt $attempt: ${finder.toString()}');
      return;
    } catch (e) {
      Log.i('⚠️ Tap attempt $attempt failed for ${finder.toString()}: $e');
      if (attempt == maxAttempts) {
        rethrow;
      }
      await tester.pump(retryDelay);
    }
  }
}
