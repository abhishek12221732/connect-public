import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../services/user_repository.dart';
import 'package:feelings/services/notification_services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';



class AuthService {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  late final GoogleSignIn _googleSignIn;
  final UserRepository _userRepository = UserRepository();
   UserRepository get userRepository => _userRepository;
   static bool isTestMode = false;

  AuthService() {
    // Initialize Google Sign-In with platform-specific configuration
    if (kIsWeb) {
      // For web, explicitly pass the client ID
      _googleSignIn = GoogleSignIn(
        clientId: '378934878895-bgq1rditmhfd98r5r9mj9c4gegljn2le.apps.googleusercontent.com',
        scopes: ['email', 'profile'],
      );
    } else {
      // For mobile, use default configuration
      _googleSignIn = GoogleSignIn();
    }
  }

    // ✨ **[NEW]** Securely deletes the current user after re-authenticating them.
  Future<void> deleteUserAccount(String password) async {
    try {
      final user = _firebaseAuth.currentUser;
      if (user == null || user.email == null) {
        throw Exception("No user is currently signed in to delete.");
      }

      // 1. Create a credential with the user's email and the password they provided.
      final cred = EmailAuthProvider.credential(
        email: user.email!,
        password: password,
      );

      // 2. Re-authenticate the user to confirm their identity. This is a critical security step.
      await user.reauthenticateWithCredential(cred);

      // 3. If re-authentication is successful, delete the user.
      await user.delete();
      
    } on FirebaseAuthException catch (e) {
      // Handle specific Firebase errors with user-friendly messages.
      if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        throw Exception('Incorrect password. Please try again.');
      } else if (e.code == 'requires-recent-login') {
        throw Exception('This action is sensitive and requires a recent login. Please log out and log back in before trying again.');
      } else {
        throw Exception('An error occurred during re-authentication.');
      }
    } catch (e, stack) {
      try {
        // FirebaseCrashlytics.instance.recordError(e, stack, reason: 'AuthService.deleteUserAccount failed');
        // FirebaseCrashlytics.instance.log('AuthService deleteUserAccount error: ${e.toString()}');
        print("please remove the comment before production");
      } catch (_) {}
      throw Exception('Failed to delete account: ${e.toString()}');
    }
  }







  // Login with Email and Password
  Future<User?> login(String email, String password) async {
    try {
      UserCredential userCredential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      User? user = userCredential.user;
      if (user != null) {
        // Set FCM token for the logged-in user
        NotificationService.setCurrentUserId(user.uid);

        return user;
      } else {
        throw Exception('Login failed: No user returned from Firebase');
      }
    } catch (e, stack) {
      // Convert Firebase Auth errors to user-friendly messages
      try {
        // FirebaseCrashlytics.instance.recordError(e, stack, reason: 'AuthService.login failed for $email');
        // FirebaseCrashlytics.instance.log('Login error for $email: ${e.toString()}');
        print('please remove the comment before production');
      } catch (_) {}
      String errorMessage = e.toString();
      if (errorMessage.contains('user-not-found')) {
        throw Exception('Account not found. Please check your email or register.');
      } else if (errorMessage.contains('wrong-password')) {
        throw Exception('Incorrect password. Please try again.');
      } else if (errorMessage.contains('invalid-email')) {
        throw Exception('Please enter a valid email address.');
      } else if (errorMessage.contains('user-disabled')) {
        throw Exception('This account has been disabled. Please contact support.');
      } else if (errorMessage.contains('too-many-requests')) {
        throw Exception('Too many failed attempts. Please try again later.');
      } else if (errorMessage.contains('network')) {
        throw Exception('Network error. Please check your connection and try again.');
      } else {
        throw Exception('Login failed: ${e.toString()}');
      }
    }
  }

  // Register with Email and Password
  Future<User?> register(String email, String password, String name) async {
    try {
      UserCredential userCredential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      User? user = userCredential.user;

      if (user != null) {
        // **[MODIFICATION START]**
        // 1. First, update the user's profile with their name.
        await user.updateProfile(displayName: name);

        // 2. THEN, send the verification email. Now %DISPLAY_NAME% will work.
        try {
          await user.sendEmailVerification();
        } catch (e) {
          print('Failed to send verification email: $e');
        }
        // **[MODIFICATION END]**

        // Save user data to Firestore
        await _userRepository.saveUserData(
          userId: user.uid,
          email: email,
          name: name, // This saves to your database, which is correct.
        );
        
        // Set FCM token for the new user
        NotificationService.setCurrentUserId(user.uid);
        
        return user;
      } else {
        throw Exception('Registration failed: No user returned from Firebase');
      }
    } catch (e, stack) {
      try {
        if (!isTestMode) {
        // await FirebaseCrashlytics.instance.recordError(e, stack);
        // await FirebaseCrashlytics.instance.log('Registration failed');
        print("please remove the comment before production");
      }
      } catch (_) {}
      // ... (your existing error handling)
      String errorMessage = e.toString();
      if (errorMessage.contains('email-already-in-use')) {
        throw Exception('An account with this email already exists. Please login instead.');
      } else if (errorMessage.contains('weak-password')) {
        throw Exception('Password is too weak. Please choose a stronger password.');
      } else if (errorMessage.contains('invalid-email')) {
        throw Exception('Please enter a valid email address.');
      } else if (errorMessage.contains('network')) {
        throw Exception('Network error. Please check your connection and try again.');
      } else {
        throw Exception('Registration failed: ${e.toString()}');
      }
    }
  }

// Google Sign-In
// In AuthService class
Future<User?> signInWithGoogle() async {
  GoogleSignInAccount? googleUser;
  try {
    await _googleSignIn.signOut(); // force account picker every time
    googleUser = await _googleSignIn.signIn();
    if (googleUser == null) {
      throw Exception('Google sign-in was cancelled');
    }
    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    final userCred = await _firebaseAuth.signInWithCredential(credential);
    return userCred.user;
  } on FirebaseAuthException catch (e) {
    if (e.code == 'account-exists-with-different-credential') {
      final email = googleUser?.email ?? '';
      final methods = email.isNotEmpty
          ? await _firebaseAuth.fetchSignInMethodsForEmail(email)
          : const <String>[];
      final method = methods.isNotEmpty ? methods.first : 'unknown';
      throw Exception('account-exists-with-different-credential|email=$email|method=$method');
    }
    throw Exception('Google Sign-In failed: ${e.message ?? e.code}');
  } catch (e) {
    throw Exception('Google Sign-In failed: ${e.toString()}');
  }
}


  // Logout
 /// Logout - FIXED to properly await all operations
Future<void> logout() async {
  // --- DEBUG LOG ---
  debugPrint('[4] AuthService: Starting logout process...');
  
  try {
    final user = _firebaseAuth.currentUser;
    
    // --- DEBUG LOG ---
    debugPrint('[4a] AuthService: Current user is ${user?.uid}.');

    // 1. Clean up FCM token first while the user is still authenticated.
    if (user != null) {
      try {
        // --- DEBUG LOG ---
        debugPrint('[4b] AuthService: Removing FCM token for user ${user.uid}.');
        await NotificationService.removeFcmTokenForUser(user.uid);
        NotificationService.clearCurrentUserId();
        debugPrint('[4c] AuthService: FCM token cleanup successful.');
      } catch (e) {
        // --- DEBUG LOG ---
        debugPrint('[WARNING] AuthService: Error during FCM cleanup, but continuing logout. Error: $e');
      }
    }

    // 2. Sign out from Google Sign-In (if applicable).
    try {
      // --- DEBUG LOG ---
      debugPrint('[4d] AuthService: Attempting to sign out from Google...');
      await _googleSignIn.signOut();
      debugPrint('[4e] AuthService: Google sign out successful.');
    } catch (e) {
      // --- DEBUG LOG ---
      debugPrint('[WARNING] AuthService: Error signing out of Google, but continuing logout. Error: $e');
    }

    // 3. Sign out from Firebase Authentication (the most critical step).
    // --- DEBUG LOG ---
    debugPrint('[4f] AuthService: Signing out from FirebaseAuth...');
    await _firebaseAuth.signOut();
    
    // --- DEBUG LOG ---
    debugPrint('[5] AuthService: FirebaseAuth signOut() completed. Auth state will now change.');

  } catch (e, stack) {
    // --- DEBUG LOG ---
    debugPrint('[FATAL] AuthService: An unexpected error occurred during logout: $e');
    FirebaseCrashlytics.instance.recordError(e, stack, reason: 'AuthService.logout failed');
    // Re-throw the exception so the UI can be notified.
    throw Exception('Failed to logout: $e');
  }
}


// In AuthService class
Future<void> sendVerificationEmail() async {
  try {
    final user = _firebaseAuth.currentUser;
    if (user != null && !user.emailVerified) {
      await user.sendEmailVerification();
    }
  } catch (e, stack) {
    try {
      // FirebaseCrashlytics.instance.recordError(e, stack, reason: 'AuthService.sendVerificationEmail failed');
      // FirebaseCrashlytics.instance.log('sendVerificationEmail error: ${e.toString()}');
      print("please remove the comment before production");
    } catch (_) {}
    throw Exception('Failed to resend verification email: $e');
  }
}

 Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _firebaseAuth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      // Re-throw user-friendly exceptions to be caught by the UI
      if (e.code == 'user-not-found') {
        throw Exception('No account found for that email.');
      } else if (e.code == 'invalid-email') {
        throw Exception('Please enter a valid email address.');
      } 
      // **[MODIFICATION]** Add a specific check for this common error
      else if (e.code == 'operation-not-allowed') {
        throw Exception('Password reset is not enabled for this app. Please contact support.');
      } 
      else {
        // This will catch other specific Firebase errors
        throw Exception('An error occurred: ${e.message}');
      }
    } catch (e, stack) {
      try {
        // FirebaseCrashlytics.instance.recordError(e, stack, reason: 'AuthService.sendPasswordResetEmail failed for $email');
        // FirebaseCrashlytics.instance.log('sendPasswordResetEmail error for $email: ${e.toString()}');
        print("please remove the comment before production");
      } catch (_) {}
      throw Exception('An unexpected error occurred. Please try again.');
    }
  }
  // Get Current User
  User? get currentUser => _firebaseAuth.currentUser;
}
