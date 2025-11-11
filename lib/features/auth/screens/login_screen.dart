// lib/features/auth/screens/login_screen.dart

import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'package:feelings/providers/user_provider.dart';
import 'package:provider/provider.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:feelings/features/auth/services/user_repository.dart';
import 'package:feelings/widgets/pulsing_dots_indicator.dart';
import 'package:feelings/utils/crashlytics_helper.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final AuthService _authService = AuthService();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  bool _emailValid = false;
  bool _isLoginButtonEnabled = false;
  bool _passwordValid = false;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = CurvedAnimation(parent: _fadeController, curve: Curves.easeIn);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fadeController.forward();
    });
    
    _emailController.addListener(_updateLoginButtonState);
    _passwordController.addListener(_updateLoginButtonState);
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _emailController.removeListener(_updateLoginButtonState);
    _passwordController.removeListener(_updateLoginButtonState);
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _updateLoginButtonState() {
    if (mounted) {
      final email = _emailController.text;
      final password = _passwordController.text;
      final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
      
      setState(() {
        _emailValid = emailRegex.hasMatch(email);
        _passwordValid = password.length >= 6;
        _isLoginButtonEnabled = email.isNotEmpty && password.isNotEmpty;
      });
    }
  }

  Future<bool> _checkConnectivity() async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      return connectivityResult != ConnectivityResult.none;
    } catch (_) {
      return false;
    }
  }

  String _getUserFriendlyMessage(String error) {
    // ... (This method is unchanged)
    error = error.toLowerCase();
    if (error.contains('user-not-found') || error.contains('no account found')) {
      return 'No account found for that email.';
    } else if (error.contains('wrong-password')) {
      return 'Incorrect password. Please try again.';
    } else if (error.contains('invalid-credential') || error.contains('the supplied auth credential is incorrect')) {
      return 'Incorrect email or password. Please try again.';
    } else if (error.contains('email-already-in-use')) {
      return 'An account with this email already exists. Please login instead.';
    } else if (error.contains('weak-password')) {
      return 'Password is too weak. Please choose a password with at least 6 characters.';
    } else if (error.contains('invalid-email')) {
      return 'Please enter a valid email address.';
    } else if (error.contains('network')) {
      return 'Network error. Please check your connection and try again.';
    } else if (error.contains('too-many-requests')) {
      return 'Too many failed attempts. Please try again later.';
    } else if (error.contains('user-disabled')) {
      return 'This account has been disabled. Please contact support.';
    } else if (error.contains('operation-not-allowed')) {
      return 'This sign-in method is not enabled. Please contact support.';
    } else if (error.contains('password should be at least 6 characters')) {
      return 'Password must be at least 6 characters long.';
    } else {
      return 'An unexpected error occurred. Please try again.'; 
    }
  }

  void _showError(String message) {
    if (mounted) {
      setState(() {
        _errorMessage = _getUserFriendlyMessage(message);
      });
    }
  }

  // **[MODIFICATION START]** - Final corrected version of the dialog logic.
  void _showForgotPasswordDialog() {
    final resetEmailController = TextEditingController(text: _emailController.text);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter your email and we will send you a link to get back into your account.'),
            const SizedBox(height: 16),
            TextField(
              controller: resetEmailController,
              keyboardType: TextInputType.emailAddress,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(Icons.email_outlined),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final email = resetEmailController.text.trim();
              if (email.isEmpty) return;

              // 1. Get references to ScaffoldMessenger and Theme BEFORE the await call.
              final scaffoldMessenger = ScaffoldMessenger.of(context);
              final theme = Theme.of(context);

              // 2. Close the dialog. The original `context` is now invalid.
              Navigator.pop(context);
              setState(() => _isLoading = true);
              _clearError();

              try {
                // 3. Perform the async operation.
                await _authService.sendPasswordResetEmail(email);
                
                // 4. Use the saved reference to show the success SnackBar. This is safe.
                scaffoldMessenger.showSnackBar(
                  SnackBar(
                    content: Text('Password reset link sent to $email'),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e, stack) {
                // Report the error to Crashlytics and show the error SnackBar.
                final crashlytics = CrashlyticsHelper();
                crashlytics.reportError(
                  e,
                  stack,
                  reason: 'Password reset failed',
                  keys: {'email': email},
                );
                crashlytics.log('Password reset error: ${e.toString()}');

                // 5. Use the saved references to show the error SnackBar. This is also safe.
                scaffoldMessenger.showSnackBar(
                  SnackBar(
                    content: Text(_getUserFriendlyMessage(e.toString())),
                    backgroundColor: theme.colorScheme.error,
                  ),
                );
              } finally {
                if (mounted) {
                  setState(() => _isLoading = false);
                }
              }
            },
            child: const Text('Send Link'),
          ),
        ],
      ),
    );
  }
  // **[MODIFICATION END]**

  Future<void> _loginUser() async {
    if (!_isLoginButtonEnabled) return;

    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      if (!await _checkConnectivity()) {
        _showError('No internet connection. Please check your network and try again.');
        if (mounted) { // Handle error
          setState(() { _isLoading = false; });
        }
        return;
      }
      
      // 1. Await the login.
      await _authService.login(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );
      
      // 2. If successful, DO NOTHING.
      // The AuthWrapper listener above this widget will
      // handle navigation and unmount this screen.

    } catch (e, stack) {
      String errorMessage = e.toString().replaceFirst('Exception: ', '');
      // ... (Your Crashlytics logging) ...
      print('Login error: $errorMessage');
      _showError(errorMessage);

      // 3. ONLY set isLoading = false if an error occurs.
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
    // 4. NO finally block and NO popUntil.
  }

  Future<void> _handleGoogleSignIn() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }
    
    try {
      if (!await _checkConnectivity()) {
         _showError('No internet connection. Please check your network and try again.');
        if (mounted) { // Handle error
          setState(() { _isLoading = false; });
        }
        return;
      }
      
      // 1. Await the sign-in.
      await _authService.signInWithGoogle();

      // 2. If successful, DO NOTHING.
      // The AuthWrapper will handle it.

    } catch (e, stack) {
      String errorMessage = e.toString().replaceFirst('Exception: ', '');
      // ... (Your Crashlytics logging) ...
      print('Google Sign-In error: $errorMessage');
      _showError(errorMessage);

      // 3. ONLY set isLoading = false if an error occurs.
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
    // 4. NO finally block and NO popUntil.
  }




  void _clearError() {
    if (mounted) {
      setState(() {
        _errorMessage = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // ✨ [ADD] Get screen height for compact layout
    final screenHeight = MediaQuery.of(context).size.height;
    final bool isSmallScreen = screenHeight < 700;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Center(
        child: SingleChildScrollView(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // ✨ [MODIFY] Conditionally hide logo
                if (!isSmallScreen)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 18),
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
                  // ✨ [MODIFY] Reduce vertical padding on small screens
                  padding: EdgeInsets.symmetric(
                      horizontal: 24, vertical: isSmallScreen ? 16 : 32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Sign In',
                        style: theme.textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Sign in to continue',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurface.withOpacity(0.7),
                        ),
                      ),
                      const SizedBox(height: 24),
                      if (_errorMessage != null)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: colorScheme.error.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: colorScheme.error.withOpacity(0.3)),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.error_outline, color: colorScheme.error, size: 20),
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
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        onChanged: (_) => _clearError(),
                        decoration: InputDecoration(
                          labelText: 'Email',
                          prefixIcon: Icon(
                            Icons.email,
                            color: _emailValid ? Colors.green : colorScheme.primary,
                          ),
                          errorText: !_emailValid && _emailController.text.isNotEmpty ? 'Enter a valid email address' : null,
                          suffixIcon: _emailController.text.isNotEmpty
                              ? Icon(
                                  _emailValid ? Icons.check_circle : Icons.error,
                                  color: _emailValid ? Colors.green : colorScheme.error,
                                  size: 20,
                                )
                              : null,
                        ),
                      ),
                      // ✨ [MODIFY] Reduced spacing
                      const SizedBox(height: 12),
                      TextField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_isLoginButtonEnabled && !_isLoading) ? (_) => _loginUser() : null,
                        onChanged: (_) => _clearError(),
                        decoration: InputDecoration(
                          labelText: 'Password',
                          prefixIcon: Icon(Icons.lock, color: colorScheme.primary),
                          errorText: !_passwordValid && _passwordController.text.isNotEmpty ? 'Password must be at least 6 characters' : null,
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword ? Icons.visibility_off : Icons.visibility,
                              color: colorScheme.onSurface.withOpacity(0.6),
                            ),
                            onPressed: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                            tooltip: _obscurePassword ? 'Show password' : 'Hide password',
                          ),
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _showForgotPasswordDialog,
                          child: const Text('Forgot Password?'),
                        ),
                      ),
                      // ✨ [MODIFY] Reduced spacing (was 12, kept 12)
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: (_isLoginButtonEnabled && !_isLoading) ? _loginUser : null,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            minimumSize: const Size.fromHeight(52),
                          ),
                          child: _isLoading
                              ? PulsingDotsIndicator(
                                  size: 20,
                                  colors: [
                                    colorScheme.onPrimary,
                                    colorScheme.onPrimary.withOpacity(0.8),
                                    colorScheme.onPrimary.withOpacity(0.6),
                                  ],
                                )
                              : const Text('Login'),
                        ),
                      ),
                      // ✨ [MODIFY] Reduced spacing
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: OutlinedButton.icon(
                          onPressed: _isLoading ? null : _handleGoogleSignIn,
                          icon: Image.asset('assets/images/google_logo.png', height: 22),
                          label: const Text('Sign in with Google'),
                          style: OutlinedButton.styleFrom(
                            backgroundColor: colorScheme.surface,
                            foregroundColor: colorScheme.onSurface,
                            side: BorderSide(color: theme.dividerColor),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            minimumSize: const Size.fromHeight(52),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // ✨ [MODIFY] Reduced spacing
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: TextButton(
                    onPressed: () {
                      Navigator.pushNamed(context, '/register');
                    },
                    child: const Text('Don’t have an account? Register here'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}