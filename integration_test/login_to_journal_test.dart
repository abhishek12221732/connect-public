import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:feelings/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Login and navigate to Journal flow', (WidgetTester tester) async {
    // 1. Launch the app
    app.main(isTesting: true);
    
    // Wait for app to settle (splash screen, auth check, etc.)
    // WigglingText in LoadingScreen loops infinitely, so pumpAndSettle will timeout.
    // Increased to 8 seconds to ensure Windows app has fully rendered frame.
    await tester.pump(const Duration(seconds: 8));

    // 2. Identify current screen
    // Check for Login Screen presence by looking for the email field
    final emailField = find.byKey(const Key('login_email_field'));
    final loginButton = find.byKey(const Key('login_button'));
    
    // If Email field is present, perform Login
    if (emailField.evaluate().isNotEmpty) {
      print('Login Screen detected. Logging in...');
      
      // Enter Credentials
      await tester.enterText(emailField, 'johndoe1903@gmail.com');
      await tester.pump(const Duration(milliseconds: 500));
      
      final passwordField = find.byKey(const Key('login_password_field'));
      await tester.enterText(passwordField, 'john@1234A');
      await tester.pump(const Duration(milliseconds: 500));
      
      // Tap Login
      await tester.tap(loginButton);
      
      // PulsingDotsIndicator loops, so we cannot use pumpAndSettle.
      // Wait for network request and navigation.
      await tester.pump(const Duration(seconds: 5)); 
      await tester.pump(const Duration(seconds: 2)); // Extra buffer
    } else {
      print('Login Screen not detected (or timed out). Checking for Home Screen...');
    }

    // 3. Verify Home Screen (or Bottom Nav)
    // We expect the Bottom Navigation Bar to be present
    final homeNavButton = find.byKey(const Key('nav_home_button'));
    expect(homeNavButton, findsOneWidget, reason: 'Should be on Home Screen after login');

    // 4. Navigate to Journal
    print('Navigating to Journal...');
    final journalNavButton = find.byKey(const Key('nav_journey_button'));
    await tester.tap(journalNavButton);
    
    await tester.pump(const Duration(seconds: 3)); // Wait for transition

    // 5. Verify Journal Screen
    // Verify Journal Screen title 'Our Journey'
    expect(find.text('Our Journey'), findsOneWidget); 
  });
}
