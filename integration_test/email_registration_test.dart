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
import 'package_helpers/google_sign_in_mock.dart';

// Import the shared helper functions
import 'test_helpers.dart'; 

// Import Firebase mocks
import 'package_helpers/firebase_core_mock.dart';


const String _emulatorHost = '127.0.0.1';
const int _authEmulatorPort = 9099;
const int _firestoreEmulatorPort = 8080;


void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late ThemeProvider themeProvider;

  setUpAll(() async {
    Log.i('╔═══════════════════════════════════════════════╗');
    Log.i('║  🧪 INTEGRATION TEST SETUP                   ║');
    Log.i('╚═══════════════════════════════════════════════╝');

    WidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    Log.i('✅ SharedPreferences mocked');

    // ✨ --- 2. SET UP THE GOOGLE SIGN-IN MOCK --- ✨
    setupGoogleSignInMocks();
    Log.i('✅ Google Sign-In mocked');

    // Initialize Firebase
    await Firebase.initializeApp();
    Log.i('✅ Firebase initialized');

    // ✨ CRITICAL: Connect to emulators IMMEDIATELY after initialization
    try {
      await FirebaseAuth.instance
          .useAuthEmulator(_emulatorHost, _authEmulatorPort);
      Log.i('✅ Auth Emulator: $_emulatorHost:$_authEmulatorPort');

      FirebaseFirestore.instance
          .useFirestoreEmulator(_emulatorHost, _firestoreEmulatorPort);
      Log.i('✅ Firestore Emulator: $_emulatorHost:$_firestoreEmulatorPort');
    } catch (e) {
      Log.i('❌ EMULATOR CONNECTION FAILED: $e');
      Log.i('⚠️  Make sure emulators are running: firebase emulators:start');
      rethrow;
    }

    themeProvider = ThemeProvider();
    await themeProvider.loadThemeFromPrefs();

    Log.i('╔═══════════════════════════════════════════════╗');
    Log.i('║  ✅ TEST SETUP COMPLETE                      ║');
    Log.i('║  📊 Emulator UI: http://127.0.0.1:4000/      ║');
    Log.i('╚═══════════════════════════════════════════════╝');
  });

  group('Full Auth E2E Flow', () {
    // --- THIS IS YOUR EXISTING EMAIL/PASSWORD TEST ---
    // (No changes needed here)
    final String uniqueEmail =
        'testuser_${DateTime.now().millisecondsSinceEpoch}@example.com';
    const String testPassword = 'password123';
    const String testName = 'E2E Test User';

    testWidgets(
        'Full user flow: Register -> Onboarding -> Logout -> Login -> Home',
        (WidgetTester tester) async {
      Log.i('╔═══════════════════════════════════════════════╗');
      Log.i('║  🚀 STARTING E2E TEST (Email/Password)      ║');
      Log.i('╚═══════════════════════════════════════════════╝');
      Log.i('Test Email: $uniqueEmail');

      // 1. --- Start the App ---
      await tester.pumpWidget(app.MyApp(themeProvider: themeProvider));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();
      await tester.pump();

      // --- 2. REGISTRATION ---
      Log.i('');
      Log.i('═══════════════════════════════════════════════');
      Log.i('Phase 1: REGISTRATION');
      Log.i('═══════════════════════════════════════════════');

      await waitForWidget(tester, find.text('Sign In'));
      expect(find.text('Sign In'), findsOneWidget);

      await tapWithRetry(
        tester,
        find.text('Don’t have an account? Register here'),
      );

      await waitForWidget(
        tester,
        find.text('Create Account'),
        timeout: const Duration(seconds: 10),
      );
      expect(find.text('Create Account'), findsOneWidget);

      // Find fields
      final nameField = find.widgetWithText(TextField, 'Name');
      final emailField = find.widgetWithText(TextField, 'Email');
      final passwordField = find.widgetWithText(TextField, 'Password');
      final confirmField = find.widgetWithText(TextField, 'Confirm Password');

      // Wait for fields to be ready
      await waitForWidget(tester, nameField);

      // Fill form
      Log.i('  ✏️  Filling registration form...');
      await tester.enterText(nameField, testName);
      await tester.pump(const Duration(milliseconds: 100));

      await tester.enterText(emailField, uniqueEmail);
      await tester.pump(const Duration(milliseconds: 100));

      await tester.enterText(passwordField, testPassword);
      await tester.pump(const Duration(milliseconds: 100));

      await tester.enterText(confirmField, testPassword);
      await tester.pump(const Duration(milliseconds: 100));

      // ✨ DISMISS THE KEYBOARD
      Log.i('  ⌨️  Dismissing keyboard...');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      Log.i('  ✓ Keyboard dismissed');

      // Tap Terms checkbox
      Log.i('  📝 Tapping terms checkbox...');
      final termsCheckbox = find.byType(Checkbox);
      await waitForWidget(tester, termsCheckbox);
      await tester.tap(termsCheckbox, warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 300));
      Log.i('  ✓ Checkbox checked');

      // Tap Register
      Log.i('  👆 Tapping Register button...');
      await tapWithRetry(
        tester,
        find.widgetWithText(ElevatedButton, 'Register'),
      );

      Log.i('⏳ Waiting for registration and navigation...');
      Log.i('⏰ Starting 15-second wait timer...');
      await Future.delayed(const Duration(seconds: 15));
      Log.i('✅ 15-second wait complete');

      // Pump frames
      await tester.pump();
      await tester.pump();
      await tester.pump();

      // --- 3. ONBOARDING (Updated Flow) ---
      Log.i('');
      Log.i('═══════════════════════════════════════════════');
      Log.i('Phase 2: ONBOARDING');
      Log.i('═══════════════════════════════════════════════');

      // Page 1: Welcome
      Log.i('📍 Onboarding Step 1: Welcome');
      final getStartedButton =
          find.widgetWithText(ElevatedButton, 'Get Started');

      await waitForWidget(
        tester,
        getStartedButton,
        timeout: const Duration(seconds: 10),
      );

      expect(getStartedButton, findsOneWidget,
          reason: "Could not find 'Get Started' button on Welcome page.");

      await tester.tap(getStartedButton, warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 500));

      // Wait for page transition
      for (int i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      // Page 2: Email Verification (SKIPPED)
      Log.i('📍 Onboarding Step 2: Verification (SKIPPED)');

      // Page 3: Profile
      Log.i('📍 Onboarding Step 3: Profile');

      await waitForWidget(
        tester,
        find.text('Your Profile'),
        timeout: const Duration(seconds: 10),
      );

      expect(find.text('Your Profile'), findsOneWidget,
          reason: "Could not find 'Your Profile' page.");

      expect(find.text(testName), findsOneWidget);

      // Select a Gender
      final genderDropdown = find.text('Select your gender');
      await waitForWidget(tester, genderDropdown);
      await tester.tap(genderDropdown, warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();

      await tapWithRetry(tester, find.text('Male').last, warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 300));

      // Select a Love Language
      final loveLanguageDropdown =
          find.text('Select your love language (Optional)');
      await waitForWidget(tester, loveLanguageDropdown);
      await tester.tap(loveLanguageDropdown, warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();

      await tapWithRetry(tester, find.text('Quality Time').last,
          warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 300));

      await tapWithRetry(
        tester,
        find.widgetWithText(ElevatedButton, 'Next'),
        warnIfMissed: false,
      );

      // Wait for page transition
      for (int i = 0; i < 15; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      // Page 4: Partner
      Log.i('📍 Onboarding Step 4: Partner');

      await waitForWidget(
        tester,
        find.text('Connect with Partner'),
        timeout: const Duration(seconds: 10),
      );

      expect(find.text('Connect with Partner'), findsOneWidget,
          reason: "Could not find 'Connect with Partner' page.");

      await tapWithRetry(
        tester,
        find.widgetWithText(TextButton, 'Skip for now'),
        warnIfMissed: false,
      );

      // Wait for page transition
      Log.i('  ⏳ Waiting for page transition to Location...');
      for (int i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      // Page 5: Location
      Log.i('📍 Onboarding Step 5: Location');

      await waitForWidget(
        tester,
        find.text('Your Location'),
        timeout: const Duration(seconds: 15),
      );

      expect(find.text('Your Location'), findsOneWidget,
          reason: "Could not find 'Your Location' page.");

      await tapWithRetry(
        tester,
        find.widgetWithText(ElevatedButton, 'Next'),
        warnIfMissed: false,
      );

      // Wait for page transition
      for (int i = 0; i < 15; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      // Page 6: Mood
      Log.i('📍 Onboarding Step 6: Mood');

      await waitForWidget(
        tester,
        find.text('How Are You Feeling?'),
        timeout: const Duration(seconds: 10),
      );

      expect(find.text('How Are You Feeling?'), findsOneWidget,
          reason: "Could not find 'How Are You Feeling?' page.");

      await tapWithRetry(
        tester,
        find.widgetWithText(ElevatedButton, 'Finish'),
        warnIfMissed: false,
      );

      Log.i('⏳ Finishing onboarding...');
      await tester.pump(const Duration(seconds: 2));
      await tester.pump();

      await waitForWidget(
        tester,
        find.byType(BottomNavBar),
        timeout: const Duration(seconds: 10),
      );

      expect(find.byType(BottomNavBar), findsOneWidget,
          reason: "App did not navigate to BottomNavBar after onboarding.");
      Log.i('✅ Landed on Home Screen');

      // --- 4. LOGOUT ---
      // This is the deterministic 4-part fix
      Log.i('');
      Log.i('═══════════════════════════════════════════════');
      Log.i('Phase 3: LOGOUT');
      Log.i('═══════════════════════════════════════════════');

      // Step 1: Navigate to Profile
      Log.i('  🔍 Looking for profile avatar...');
      final profileAvatar = find.byType(CircleAvatar).first;
      await waitForWidget(tester, profileAvatar,
          timeout: const Duration(seconds: 10));
      Log.i('  ✓ Profile avatar found');

      await tester.tap(profileAvatar, warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();

      Log.i('  ⏳ Waiting for profile screen...');
      await waitForWidget(
        tester,
        find.text('Edit Profile'),
        timeout: const Duration(seconds: 10),
      );
      expect(find.text('Edit Profile'), findsOneWidget);
      Log.i('  ✓ Profile screen loaded');

      // Step 2: Tap the logout icon
      Log.i('  👆 Tapping logout icon in AppBar...');
      final logoutIcon = find.byIcon(Icons.logout);
      await waitForWidget(tester, logoutIcon);
      await tester.tap(logoutIcon, warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();

      // Step 3: Confirm logout in the dialog
      Log.i('  ⏳ Waiting for logout confirmation dialog...');
      final logoutButton = find.widgetWithText(ElevatedButton, 'Log Out');
      await waitForWidget(tester, logoutButton);
      Log.i('  👆 Confirming logout...');

      // This tap now awaits the *entire* logout, cleanup, and navigation
      // because of the logic we added to profile_screen.dart
      await tester.tap(logoutButton, warnIfMissed: false);

      // Step 4: Wait for the app to handle the manual cleanup and navigation.
      Log.i('  ⏳ Waiting for manual cleanup and navigation to LoginScreen...');
      await tester.pumpAndSettle(
        const Duration(seconds: 15), // A generous timeout
      );
      Log.i('  ✅ UI settled.');

      // Step 5: Verify we are on the Login Screen
      await waitForWidget(
        tester,
        find.text('Sign In'),
        timeout: const Duration(seconds: 10),
      );

      expect(find.text('Sign In'), findsOneWidget);
      Log.i('✅ Successfully logged out');

      // --- 5. LOGIN ---
      Log.i('');
      Log.i('═══════════════════════════════════════════════');
      Log.i('Phase 4: LOGIN');
      Log.i('═══════════════════════════════════════════════');

      final loginEmailField = find.widgetWithText(TextField, 'Email');
      final loginPasswordField = find.widgetWithText(TextField, 'Password');

      await waitForWidget(tester, loginEmailField);

      await tester.enterText(loginEmailField, uniqueEmail);
      await tester.pump(const Duration(milliseconds: 100));

      await tester.enterText(loginPasswordField, testPassword);
      await tester.pump(const Duration(milliseconds: 100));

      await tapWithRetry(
        tester,
        find.widgetWithText(ElevatedButton, 'Login'),
        warnIfMissed: false,
      );

      Log.i('⏳ Logging in...');
      await tester.pump(const Duration(seconds: 2));
      await tester.pump();

      await waitForWidget(
        tester,
        find.byType(BottomNavBar),
        timeout: const Duration(seconds: 15),
      );

      // --- 6. FINAL VERIFICATION ---
      Log.i('');
      Log.i('═══════════════════════════════════════════════');
      Log.i('Phase 5: FINAL VERIFICATION');
      Log.i('═══════════════════════════════════════════════');
      expect(find.byType(BottomNavBar), findsOneWidget,
          reason: "Could not log back in and land on Home.");

      Log.i('');
      Log.i('╔═══════════════════════════════════════════════╗');
      Log.i('║  ✅ TEST COMPLETE (Email)                    ║');
      Log.i('╚═══════════════════════════════════════════════╝');
  });
  });

}
