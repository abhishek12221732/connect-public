import 'package:google_sign_in_platform_interface/google_sign_in_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:mocktail/mocktail.dart';

// 1. Create a mock class that implements the platform interface
class MockGoogleSignInPlatform extends Mock
    with MockPlatformInterfaceMixin // <-- This is the important mixin!
    implements
        GoogleSignInPlatform {

  // --- THIS IS THE FIX ---
  // The google_sign_in package requires this override for all mocks.
  @override
  bool get isMock => true;
}

// 2. Create the fake user data that Google will "return"
final _fakeUserData = GoogleSignInUserData(
  email: 'google.user@test.com',
  id: '1234567890',
  displayName: 'Google User',
  photoUrl: 'https://mock.com/google-user-pic.png',
  idToken: 'mock-google-id-token', // This will be passed to Firebase Auth
  serverAuthCode: 'mock-server-auth-code',
);

// 3. Create the fake token data
final _fakeTokenData = GoogleSignInTokenData(
  idToken: _fakeUserData.idToken,
  accessToken: 'mock-google-access-token',
  serverAuthCode: _fakeUserData.serverAuthCode,
);

// 4. Create the setup function we will call from our test
void setupGoogleSignInMocks() {
  // Create the mock instance
  final mockGoogleSignIn = MockGoogleSignInPlatform();

  // Set this mock as the "live" instance for GoogleSignIn
  GoogleSignInPlatform.instance = mockGoogleSignIn;

  // Stub all the methods that GoogleSignIn might call
  when(() => mockGoogleSignIn.init(
        scopes: any(named: 'scopes'),
        clientId: any(named: 'clientId'),
      )).thenAnswer((_) async {});

  // This is the most important part!
  // When the app calls .signIn(), return our fake user
  when(() => mockGoogleSignIn.signIn()).thenAnswer((_) async => _fakeUserData);

  // When the app asks for tokens (which .authentication does), return them
  when(() => mockGoogleSignIn.getTokens(
        email: any(named: 'email'),
        shouldRecoverAuth: any(named: 'shouldRecoverAuth'),
      )).thenAnswer((_) async => _fakeTokenData);

  // Stub the sign-out methods as well
  when(() => mockGoogleSignIn.signOut()).thenAnswer((_) async => {});
  when(() => mockGoogleSignIn.disconnect()).thenAnswer((_) async => {});
}
