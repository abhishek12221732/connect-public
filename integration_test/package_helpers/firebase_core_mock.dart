/*
 This is the updated helper file to mock Firebase Core.
 It uses 'mocktail' to mock the platform interface, which is the
 modern and stable way to do this.
*/
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/firebase_core_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart'; // We now use mocktail
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

// --- Mock Classes ---

// 1. Mock the Core platform (This is what Firebase.initializeApp uses)
class MockFirebasePlatform extends Mock
    with MockPlatformInterfaceMixin // <-- This was correct
    implements
        FirebasePlatform {}

// 2. Mock the App platform (This is what FirebaseApp uses)
class MockFirebaseAppPlatform extends Mock
    with MockPlatformInterfaceMixin // <-- FIX 1: Add the mixin here
    implements
        FirebaseAppPlatform {} // This interface is what FirebaseApp checks

// --- Mock Options ---
const FirebaseOptions mockOptions = FirebaseOptions(
  apiKey: 'mock-api-key',
  appId: 'mock-app-id',
  messagingSenderId: 'mock-sender-id',
  projectId: 'mock-project-id',
);

void setupFirebaseCoreMocks() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // 1. Create BOTH mocks
  final mockPlatform = MockFirebasePlatform();
  final mockAppPlatform = MockFirebaseAppPlatform();

  // 2. Set the static instance for the CORE platform.
  //    We CANNOT set the App platform instance.
  FirebasePlatform.instance = mockPlatform;

  // 3. Stub the mockAppPlatform's behavior
  //    This is what the high-level FirebaseApp will read from.
  when(() => mockAppPlatform.name).thenReturn(defaultFirebaseAppName);
  when(() => mockAppPlatform.options).thenReturn(mockOptions);

  // FIX 2: Add this stub. The FirebaseApp constructor tries to read this
  // property, and it will fail the test if it's not stubbed.
  when(() => mockAppPlatform.isAutomaticDataCollectionEnabled)
      .thenReturn(false);

  // 4. Stub the core platform's behavior to return the mockAppPlatform
  when(() => mockPlatform.initializeApp(
        name: any(named: 'name'),
        options: any(named: 'options'),
      )).thenAnswer(
          (_) async => mockAppPlatform); // <-- FIX 3: This is correct

  // 5. REMOVE the 'delegateFor' call, as it doesn't exist.
  // when(() => mockPlatform.delegateFor(app: any(named: 'app')))
  //     .thenReturn(mockAppPlatform);

  when(() => mockPlatform.apps)
      .thenReturn([mockAppPlatform]); // <-- FIX 4: This is correct
  when(() => mockPlatform.app(any()))
      .thenReturn(mockAppPlatform); // <-- FIX 5: This is correct
}

