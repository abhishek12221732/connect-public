// lib/features/auth/screens/register_screen.dart

import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../../onboarding/onboarding_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:feelings/providers/user_provider.dart';
import 'package:provider/provider.dart';
import 'package:feelings/widgets/pulsing_dots_indicator.dart';
import 'package:feelings/utils/crashlytics_helper.dart';

// ✨ [ADD] Imports for handling gestures (links) and launching URLs.
import 'package:flutter/gestures.dart';
import 'package:url_launcher/url_launcher.dart';

import 'dart:async';

class RegisterScreen extends StatefulWidget {
  // ✨ [ADD] Accepts a prefilled user from UserDataLoader
  final User? prefilledUser;

  const RegisterScreen({
    super.key,
    this.prefilledUser, // Make it optional
  });

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with SingleTickerProviderStateMixin {
  // ✨ [ADD] AuthService instance
  final AuthService _authService = AuthService();

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final TextEditingController _nameController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String? _errorMessage;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  // Validation states
  bool _passwordValid = false;
  bool _confirmPasswordValid = false;
  String _passwordStrength = '';
  bool _emailValid = false;
  bool _isRegisterButtonEnabled = false;

  // ✨ [ADD] State for the terms and conditions checkbox.
  bool _termsAccepted = false;

  // State to track if this is a Google sign-up flow
  bool _isGoogleSignUp = false;
  User? _googleUser;
  StreamSubscription<User?>? _authSub;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // ✨ [MODIFY] This logic now checks the new widget property *first*,
    // and falls back to ModalRoute arguments.

    // 1. Try to get the user from the new `widget.prefilledUser`
    final User? userFromWidget = widget.prefilledUser;

    // 2. Fallback to getting user from ModalRoute (for old navigation methods)
    User? userFromRoute;
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is User) {
      userFromRoute = args;
    }

    final userToProcess = userFromWidget ?? userFromRoute;

    if (userToProcess != null && _googleUser == null) {
      // Check for null to prevent re-running
      setState(() {
        _googleUser = userToProcess;
        _isGoogleSignUp = true;
        _emailController.text = userToProcess.email ?? '';
        _nameController.text = userToProcess.displayName ?? '';
        _validateEmail(); // Validate pre-filled email
        _updateRegisterButtonState();
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _authSub = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (!mounted) return;
      if (user != null) {
        // User is authenticated; reveal the AuthWrapper-driven screen underneath
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    });
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation =
        CurvedAnimation(parent: _fadeController, curve: Curves.easeIn);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fadeController.forward();
    });

    _emailController.addListener(_validateEmail);
    _passwordController.addListener(_validatePassword);
    _confirmPasswordController.addListener(_validateConfirmPassword);
    _nameController.addListener(_updateRegisterButtonState);
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _nameController.dispose();
    _authSub?.cancel();
    super.dispose();
  }

  // ✨ [ADD] A helper function to launch URLs for the legal documents.
  Future<void> _launchURL(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      _showError('Could not open the link. Please try again later.');
    }
  }

  void _validateEmail() {
    final email = _emailController.text;
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (mounted) {
      setState(() {
        _emailValid = emailRegex.hasMatch(email);
      });
    }
    _updateRegisterButtonState();
  }

  void _validatePassword() {
    final password = _passwordController.text;
    if (mounted) {
      setState(() {
        _passwordValid = password.length >= 6;
        _passwordStrength = _getPasswordStrength(password);
      });
    }
    _validateConfirmPassword();
    _updateRegisterButtonState();
  }

  void _validateConfirmPassword() {
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;
    if (mounted) {
      setState(() {
        _confirmPasswordValid =
            confirmPassword.isNotEmpty && password == confirmPassword;
      });
    }
    _updateRegisterButtonState();
  }

  void _updateRegisterButtonState() {
    if (!mounted) return;
    final hasName = _nameController.text.trim().length >= 2;
    final emailOk = _emailValid;
    final termsOk = _termsAccepted;

    if (_isGoogleSignUp) {
      // For Google sign-up, we only need name, valid email (pre-filled), and terms acceptance
      setState(() {
        _isRegisterButtonEnabled = hasName && emailOk && termsOk;
      });
    } else {
      // For regular sign-up, we need all validations
      final passwordOk = _passwordValid;
      final confirmOk = _confirmPasswordValid;
      setState(() {
        _isRegisterButtonEnabled =
            hasName && emailOk && passwordOk && confirmOk && termsOk;
      });
    }
  }

  String _getPasswordStrength(String password) {
    if (password.isEmpty) return '';
    if (password.length < 6) return 'Too short';

    bool hasLetter = password.contains(RegExp(r'[a-zA-Z]'));
    bool hasDigit = password.contains(RegExp(r'[0-9]'));
    bool hasSpecial = password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));

    if (hasLetter && hasDigit && hasSpecial) return 'Strong';
    if ((hasLetter && hasDigit) ||
        (hasLetter && hasSpecial) ||
        (hasDigit && hasSpecial)) return 'Medium';
    return 'Weak';
  }

  Color _getPasswordStrengthColor(ColorScheme colorScheme) {
    switch (_passwordStrength) {
      case 'Strong':
        return Colors.green;
      case 'Medium':
        return Colors.orange;
      case 'Weak':
      case 'Too short':
        return colorScheme.error;
      default:
        return colorScheme.onSurface.withOpacity(0.4);
    }
  }

  void _showError(String message) {
    if (mounted) {
      setState(() {
        _errorMessage = _getUserFriendlyMessage(message);
      });
    }
  }

  String _getUserFriendlyMessage(String error) {
    error = error.toLowerCase();
    if (error.contains('account-exists-with-different-credential')) {
      return 'An account with this email already exists. Please login instead.';
    } else if (error.contains('email-already-in-use')) {
      return 'An account with this email already exists. Please login instead.';
    } else if (error.contains('weak-password')) {
      return 'Password is too weak. Please choose a password with at least 6 characters.';
    } else if (error.contains('invalid-email')) {
      return 'Please enter a valid email address.';
    } else if (error.contains('network')) {
      return 'Network error. Please check your connection and try again.';
    } else if (error.contains('popup_closed') || error.contains('cancelled')) {
      return 'Google sign-in was cancelled.';
    } else {
      return error;
    }
  }

  Future<void> _showExistingAccountDialog(
      {required String? email, required String via}) async {
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Account already exists'),
        content: Text(
          email == null || email.isEmpty
              ? 'This email is already registered via $via. Please login instead.'
              : 'The email $email is already registered via $via. Please login instead.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // stay on Register
              // Next tap on “Sign Up with Google” will reprompt (service pre-signOut)
            },
            child: const Text('Try another Google'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context); // go back to Login (Register was pushed from Login)
            },
            child: const Text('Go to Login'),
          ),
        ],
      ),
    );
  }

  Future<bool> _checkConnectivity() async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      return connectivityResult != ConnectivityResult.none;
    } catch (_) {
      return false;
    }
  }

  void _clearError() {
    if (mounted) {
      setState(() {
        _errorMessage = null;
      });
    }
  }

  Future<void> _registerUser() async {
    if (!_isRegisterButtonEnabled) return;

    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      if (!await _checkConnectivity()) {
        _showError('No internet connection.');
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      // 1. Register the user (creates auth user AND saves to Firestore)
      await _authService.register(
        _emailController.text.trim(),
        _passwordController.text.trim(),
        _nameController.text.trim(),
      );

      // 2. DO NOTHING ELSE.
      // The AuthWrapper will detect the new user and handle navigation.
    } catch (e, stack) {
      String errorMessage = e.toString().replaceFirst('Exception: ', '');

      final crashlytics = CrashlyticsHelper();
      crashlytics.reportError(
        e,
        stack,
        reason: 'Registration failed for ${_emailController.text.trim()}',
        keys: {'email': _emailController.text.trim()},
      );
      crashlytics.log('Register error: $errorMessage');

      if (mounted) {
        _showError(errorMessage);
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // ✨ [ADD] This new function, copied from LoginScreen
  Future<void> _handleGoogleSignIn() async {
    if (mounted) setState(() { _isLoading = true; _errorMessage = null; });
    try {
      if (!await _checkConnectivity()) {
        _showError('No internet connection. Please check your network and try again.');
        if (mounted) setState(() => _isLoading = false);
        return;
      }
      await _authService.signInWithGoogle();
      // Success path: Auth state changes, AuthWrapper/UserDataLoader will navigate.
    } catch (e) {
      final raw = e.toString().replaceFirst('Exception: ', '');
      if (raw.startsWith('account-exists-with-different-credential')) {
        String? email;
        String via = 'another sign-in method';
        for (final part in raw.split('|')) {
          if (part.startsWith('email=')) email = part.substring('email='.length);
          if (part.startsWith('method=')) {
            final m = part.substring('method='.length);
            via = (m == 'password') ? 'email & password' : m;
          }
        }
        await _showExistingAccountDialog(email: email, via: via);
      } else {
        _showError(raw);
      }
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _completeGoogleRegistration() async {
    if (!_isRegisterButtonEnabled) return;

    if (_nameController.text.trim().isEmpty) {
      _showError('Please confirm your name');
      return;
    }
    if (_googleUser == null) {
      _showError('User information is missing. Please try signing in again.');
      return;
    }

    setState(() => _isLoading = true);
    _clearError();

    try {
      if (!await _checkConnectivity()) {
        _showError('No internet connection.');
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      // 1. Create the user document in Firestore
      await _authService.userRepository.saveUserData(
            userId: _googleUser!.uid,
            email: _emailController.text.trim(),
            name: _nameController.text.trim(),
            profileImageUrl: _googleUser!.photoURL,
          );

      final userProvider = Provider.of<UserProvider>(context, listen: false);

      // 2. Fetch the data into the provider.
      await userProvider.fetchUserData();

      // 3. Save the session
      await userProvider.saveUserIdToSharedPreferences(_googleUser!.uid);

      // 4. Navigate to Onboarding AND clear the stack.
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) => OnboardingScreen(
              email: _googleUser!.email ?? '',
              name: _nameController.text.trim(),
              photoURL: _googleUser!.photoURL ?? '',
            ),
          ),
          (route) => route
              .isFirst, // This clears everything until the root (AuthWrapper)
        );
      }
    } catch (e, stack) {
      final crashlytics = CrashlyticsHelper();
      crashlytics.reportError(
        e,
        stack,
        reason: 'Google registration completion failed',
        keys: {
          'email': _googleUser?.email ?? 'unknown',
          'name': _nameController.text.trim(),
        },
      );
      crashlytics.log('Google registration error: ${e.toString()}');

      _showError(e.toString());
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final passwordStrengthColor = _getPasswordStrengthColor(colorScheme);

    // ✨ [ADD] Get the screen height
    final screenHeight = MediaQuery.of(context).size.height;
    // ✨ [ADD] Define a threshold (tune this as needed)
    final bool isSmallScreen = screenHeight < 700;

    // ✨ [ADD] A reusable text style for the legal links.
    final linkStyle = theme.textTheme.bodySmall!.copyWith(
      color: colorScheme.primary,
      decoration: TextDecoration.underline,
    );

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // ✨ [MODIFY] Only show the logo if the screen is not small
                  if (!isSmallScreen)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        'Feelings',
                        style: theme.textTheme.displaySmall?.copyWith(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                  Padding(
                    // ✨ [MODIFY] Reduce vertical padding on small screens too
                    padding: EdgeInsets.symmetric(
                        horizontal: 20, vertical: isSmallScreen ? 12 : 20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                            _isGoogleSignUp
                                ? 'Complete Your Profile'
                                : 'Create Account',
                            style: theme.textTheme.headlineSmall),
                        const SizedBox(height: 4),
                        Text(
                          _isGoogleSignUp
                              ? 'Confirm your details to get started'
                              : 'Join to get started',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurface.withOpacity(0.7),
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (_errorMessage != null)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: colorScheme.error.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: colorScheme.error.withOpacity(0.3)),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.error_outline,
                                    color: colorScheme.error, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _errorMessage!,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: colorScheme.error,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        TextField(
                          controller: _nameController,
                          textInputAction: TextInputAction.next,
                          onChanged: (_) {
                            _clearError();
                            _updateRegisterButtonState();
                          },
                          decoration: InputDecoration(
                            labelText: 'Name',
                            prefixIcon:
                                Icon(Icons.person, color: colorScheme.primary),
                            errorText: _nameController.text.isNotEmpty &&
                                    _nameController.text.length < 2
                                ? 'Name must be at least 2 characters'
                                : null,
                          ),
                        ),
                        // ✨ [MODIFY] Reduced spacing
                        const SizedBox(height: 8),
                        TextField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          onChanged: (_) {
                            _clearError();
                          },
                          readOnly: _isGoogleSignUp,
                          decoration: InputDecoration(
                            labelText: 'Email',
                            prefixIcon: Icon(Icons.email,
                                color: _emailValid
                                    ? Colors.green
                                    : colorScheme.primary),
                            errorText:
                                !_emailValid && _emailController.text.isNotEmpty
                                    ? 'Enter a valid email address'
                                    : null,
                            suffixIcon: _emailController.text.isNotEmpty
                                ? Icon(
                                    _emailValid
                                        ? Icons.check_circle
                                        : Icons.error,
                                    color: _emailValid
                                        ? Colors.green
                                        : colorScheme.error,
                                    size: 20,
                                  )
                                : null,
                          ),
                        ),
                        if (!_isGoogleSignUp) ...[
                          // ✨ [MODIFY] Reduced spacing
                          const SizedBox(height: 8),
                          TextField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            textInputAction: TextInputAction.next,
                            onChanged: (_) {
                              _clearError();
                            },
                            decoration: InputDecoration(
                              labelText: 'Password',
                              prefixIcon:
                                  Icon(Icons.lock, color: colorScheme.primary),
                              errorText: !_passwordValid &&
                                      _passwordController.text.isNotEmpty
                                  ? 'Password must be at least 6 characters'
                                  : null,
                              suffixIcon: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (_passwordController.text.isNotEmpty)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: passwordStrengthColor
                                            .withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        _passwordStrength,
                                        style: theme.textTheme.labelSmall
                                            ?.copyWith(
                                          color: passwordStrengthColor,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  IconButton(
                                    icon: Icon(
                                      _obscurePassword
                                          ? Icons.visibility_off
                                          : Icons.visibility,
                                      color: colorScheme.onSurface
                                          .withOpacity(0.6),
                                    ),
                                    onPressed: () => setState(() =>
                                        _obscurePassword = !_obscurePassword),
                                    tooltip: _obscurePassword
                                        ? 'Show password'
                                        : 'Hide password',
                                  ),
                                ],
                              ),
                            ),
                          ),
                          // ✨ [MODIFY] Reduced spacing
                          const SizedBox(height: 8),
                          TextField(
                            controller: _confirmPasswordController,
                            obscureText: _obscureConfirmPassword,
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) => _registerUser(),
                            onChanged: (_) => _clearError(),
                            decoration: InputDecoration(
                              labelText: 'Confirm Password',
                              errorText: !_confirmPasswordValid &&
                                      _confirmPasswordController.text.isNotEmpty
                                  ? 'Passwords do not match'
                                  : null,
                              prefixIcon: Icon(Icons.lock,
                                  color: _confirmPasswordController.text.isEmpty
                                      ? colorScheme.primary
                                      : _confirmPasswordValid
                                          ? Colors.green
                                          : colorScheme.error),
                              suffixIcon: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (_confirmPasswordController
                                      .text.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(right: 8),
                                      child: Icon(
                                        _confirmPasswordValid
                                            ? Icons.check_circle
                                            : Icons.error,
                                        color: _confirmPasswordValid
                                            ? Colors.green
                                            : colorScheme.error,
                                        size: 20,
                                      ),
                                    ),
                                  IconButton(
                                    icon: Icon(
                                      _obscureConfirmPassword
                                          ? Icons.visibility_off
                                          : Icons.visibility,
                                      color: colorScheme.onSurface
                                          .withOpacity(0.6),
                                    ),
                                    onPressed: () => setState(() =>
                                        _obscureConfirmPassword =
                                            !_obscureConfirmPassword),
                                    tooltip: _obscureConfirmPassword
                                        ? 'Show password'
                                        : 'Hide password',
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                        // ✨ [ADD] The terms and conditions checkbox widget.
                        // ✨ [MODIFY] Reduced spacing
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                height: 24.0,
                                width: 24.0,
                                child: Checkbox(
                                  value: _termsAccepted,
                                  onChanged: (bool? value) {
                                    setState(() {
                                      _termsAccepted = value ?? false;
                                      _updateRegisterButtonState();
                                    });
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.only(top: 2.0),
                                  child: RichText(
                                    text: TextSpan(
                                      style: theme.textTheme.bodySmall,
                                      children: [
                                        const TextSpan(text: 'I agree to the '),
                                        TextSpan(
                                          text: 'Privacy Policy',
                                          style: linkStyle,
                                          recognizer: TapGestureRecognizer()
                                            ..onTap = () => _launchURL(
                                                'https://teamhazelnut.github.io/feelings-legal/privacy-policy.html'),
                                        ),
                                        const TextSpan(text: ', '),
                                        TextSpan(
                                          text: 'Terms & Conditions',
                                          style: linkStyle,
                                          recognizer: TapGestureRecognizer()
                                            ..onTap = () => _launchURL(
                                                'https://teamhazelnut.github.io/feelings-legal/terms-and-conditions.html'),
                                        ),
                                        const TextSpan(
                                            text:
                                                ', and I confirm I am over the age of 13.'),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // ✨ [MODIFY] Reduced spacing
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              minimumSize: const Size.fromHeight(52),
                            ),
                            onPressed: (_isLoading || !_isRegisterButtonEnabled)
                                ? null
                                : (_isGoogleSignUp
                                    ? _completeGoogleRegistration
                                    : _registerUser),
                            child: _isLoading
                                ? PulsingDotsIndicator(
                                    size: 20, // Adjusted size
                                    colors: [
                                      colorScheme.onPrimary,
                                      colorScheme.onPrimary.withOpacity(0.8),
                                      colorScheme.onPrimary.withOpacity(0.6),
                                    ],
                                  )
                                : Text(_isGoogleSignUp
                                    ? 'Complete Profile'
                                    : 'Register'),
                          ),
                        ),
                        // ✨ [MODIFY] Show Google Sign Up *unless* user is
                        // already in the Google "Complete Profile" flow.
                        if (!_isGoogleSignUp) ...[
                          // ✨ [MODIFY] Reduced spacing
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: OutlinedButton.icon(
                              onPressed:
                                  _isLoading ? null : _handleGoogleSignIn, // ✨ [CHANGE] Call the new handler
                              icon: Image.asset('assets/images/google_logo.png',
                                  height: 22),
                              label: const Text('Sign Up with Google'),
                              style: OutlinedButton.styleFrom(
                                backgroundColor: colorScheme.surface,
                                foregroundColor: colorScheme.onSurface,
                                side: BorderSide(color: theme.dividerColor),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                minimumSize: const Size.fromHeight(52),
                              ),
                            ),
                          ),
                        ],
                        // ✨ [MODIFY] Reduced spacing
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: TextButton(
                            onPressed: _isLoading
                                ? null
                                : () async {
                                    // Check if this is the Google "Complete Profile" flow
                                    if (_isGoogleSignUp) {
                                      // If so, we must log the user out to "go back".
                                      if (mounted) {
                                        setState(() => _isLoading = true);
                                      }
                                      try {
                                        await _authService.logout();
                                        // No navigation needed. AuthWrapper will detect
                                        // the logout and handle everything.
                                      } catch (e) {
                                        if (mounted) {
                                          setState(() => _isLoading = false);
                                          _showError(
                                              "Failed to log out: ${e.toString()}");
                                        }
                                      }
                                    } else {
                                      // If this is the normal email/pass register, just pop.
                                      Navigator.pop(context);
                                    }
                                  },
                            child: const Text(
                                'Already have an account? Login here'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}