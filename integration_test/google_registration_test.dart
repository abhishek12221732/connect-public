import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Import your app's main entry point and other necessary files
import '../test/main_test.dart' as app;
import 'package:feelings/providers/theme_provider.dart';
import 'package:feelings/features/home/screens/bottom_nav_bar.dart';

// Import the shared helper functions and mocks
import 'test_helpers.dart';
import 'package_helpers/firebase_core_mock.dart';
import 'package_helpers/google_sign_in_mock.dart'; // MOCK for Google Sign-In

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late ThemeProvider themeProvider;

  setUpAll(() async {
    Log.i('╔═══════════════════════════════════════════════╗');
    Log.i('║  🧪 GOOGLE SIGN-IN TEST SETUP                ║');
    Log.i('╚═══════════════════════════════════════════════╝');
    
    setupFirebaseCoreMocks();
    SharedPreferences.setMockInitialValues({});
    Log.i('✅ SharedPreferences mocked');

    // Set up the Google Sign-In mock BEFORE Firebase init
    setupGoogleSignInMocks();
    Log.i('✅ Google Sign-In mocked');
    
    await Firebase.initializeApp();
    Log.i('✅ Firebase initialized');

    // Connect to emulators
    const String emulatorHost = '127.0.0.1';
    const int authEmulatorPort = 9099;
    const int firestoreEmulatorPort = 8080;

    try {
      await FirebaseAuth.instance.useAuthEmulator(emulatorHost, authEmulatorPort);
      FirebaseFirestore.instance.useFirestoreEmulator(emulatorHost, firestoreEmulatorPort);
      Log.i('✅ Connected to Firebase Emulators');
    } catch (e) {
      Log.i('EMULATOR CONNECTION FAILED: $e');
      rethrow;
    }

    themeProvider = ThemeProvider();
    await themeProvider.loadThemeFromPrefs();
  });

  testWidgets('Full E2E Flow: Google Sign-In and Onboarding', (WidgetTester tester) async {
    Log.i('--- STARTING E2E TEST: Google Sign-In ---');

    // 1. --- Start the App ---
    await tester.pumpWidget(app.MyApp(themeProvider: themeProvider));
    await tester.pumpAndSettle();

    // 2. --- GOOGLE SIGN-IN ---
    Log.i('--- Phase 1: GOOGLE SIGN-IN (MOCKED) ---');
    await waitForWidget(tester, find.text('Sign In'));

    // --- THIS IS THE FIX ---
    // Find the button by its text. This is more robust than finding by widget type.
    final googleSignInButton = find.text('Sign in with Google');
    
    // Tap the button
    await tapWithRetry(tester, googleSignInButton);
    
    Log.i('Mock Google Sign-In running... Waiting for navigation...');
    await tester.pumpAndSettle(const Duration(seconds: 5));

    // 3. --- ONBOARDING (with Google User data) ---
    Log.i('--- Phase 2: ONBOARDING (Google User) ---');
    await waitForWidget(tester, find.text('Get Started'));
    
    // Verify pre-filled data from mock
    expect(find.text('Google User'), findsOneWidget, reason: 'Mock Google User name not found on profile page.');
    
    // Continue with the rest of the onboarding flow...
    // ... (same steps as the email test for profile, partner, location, mood) ...
    
    await waitForWidget(tester, find.text('How Are You Feeling?'));
    await tester.tap(find.widgetWithText(ElevatedButton, 'Finish'));
    await tester.pumpAndSettle(const Duration(seconds: 5));

    // 4. --- FINAL VERIFICATION ---
    expect(find.byType(BottomNavBar), findsOneWidget, reason: "App did not navigate to Home Screen after onboarding.");
    Log.i('✅ Onboarding complete, landed on Home Screen');
    Log.i('--- TEST COMPLETE: Google Sign-In ---');
  });
}
