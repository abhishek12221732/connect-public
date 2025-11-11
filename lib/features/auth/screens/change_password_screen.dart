import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:feelings/widgets/pulsing_dots_indicator.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  _ChangePasswordScreenState createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  bool _obscureCurrentPassword = true;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  // ✨ [ADDITION] Flag to determine if the user has an existing password (email/password provider)
  bool _isPasswordProvider = false; 

  @override
  void initState() {
    super.initState();
    _checkAuthProviders();
  }

  // ✨ [ADDITION] Method to check the user's sign-in provider
  void _checkAuthProviders() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      // Check if the user has the 'password' provider ID, which means they
      // either signed up with email/password or have previously set one.
      final isEmailPassword = user.providerData.any(
        (info) => info.providerId == 'password',
      );

      setState(() {
        _isPasswordProvider = isEmailPassword;
      });
    }
  }

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _changePassword() async {
    // Only validate fields that are currently visible/relevant
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null || user.email == null) {
        // Use a generic error message for security
        throw Exception("Authentication session expired. Please log in again."); 
      }

      // ✨ [MODIFICATION] Conditional re-authentication logic
      if (_isPasswordProvider) {
        // Step 1: Re-authenticate for users who have a password set
        final cred = EmailAuthProvider.credential(
          email: user.email!,
          password: _currentPasswordController.text.trim(),
        );
        await user.reauthenticateWithCredential(cred);
      } 
      // NOTE: If !_isPasswordProvider (e.g., Google user), we skip re-authentication,
      // as their current authenticated session is proof of identity.

      // Step 2: If re-authentication is successful (or skipped), update the password
      await user.updatePassword(_newPasswordController.text.trim());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Password changed successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage;
      if (e.code == 'wrong-password') {
        errorMessage = 'The current password you entered is incorrect.';
      } else if (e.code == 'weak-password') {
        errorMessage = 'The new password is too weak.';
      } else if (e.code == 'requires-recent-login') {
         errorMessage = 'Please log in again before changing your password.';
      } else {
        errorMessage = 'An error occurred: ${e.message}';
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('An unexpected error occurred. Please try again.'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Change Password'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ✨ [MODIFICATION] Conditionally show the current password field and prompt
              if (_isPasswordProvider) ...[
                Text(
                  'For your security, please enter your current password before choosing a new one.',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _currentPasswordController,
                  obscureText: _obscureCurrentPassword,
                  decoration: InputDecoration(
                    labelText: 'Current Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(_obscureCurrentPassword ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setState(() => _obscureCurrentPassword = !_obscureCurrentPassword),
                    ),
                  ),
                  // Only validate the current password if it is required
                  validator: (value) {
                    if (_isPasswordProvider && (value == null || value.isEmpty)) {
                      return 'Please enter your current password';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
              ] else ...[
                 // Prompt for social sign-in users who are setting a password for the first time
                 Text(
                  'You signed in with a social account. Set a password here to enable email/password login.',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 24),
              ],
              
              TextFormField(
                controller: _newPasswordController,
                obscureText: _obscureNewPassword,
                decoration: InputDecoration(
                  labelText: 'New Password',
                  prefixIcon: const Icon(Icons.lock),
                  suffixIcon: IconButton(
                    icon: Icon(_obscureNewPassword ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _obscureNewPassword = !_obscureNewPassword),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a new password';
                  }
                  if (value.length < 6) {
                    return 'Password must be at least 6 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _confirmPasswordController,
                obscureText: _obscureConfirmPassword,
                decoration: InputDecoration(
                  labelText: 'Confirm New Password',
                  prefixIcon: const Icon(Icons.lock),
                    suffixIcon: IconButton(
                    icon: Icon(_obscureConfirmPassword ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                  ),
                ),
                validator: (value) {
                  if (value != _newPasswordController.text) {
                    return 'Passwords do not match';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                onPressed: _isLoading ? null : _changePassword,
                child: _isLoading
                    ? PulsingDotsIndicator(
                        size: 20,
                        colors: [
                          Theme.of(context).colorScheme.onPrimary,
                          Theme.of(context).colorScheme.onPrimary.withOpacity(0.8),
                          Theme.of(context).colorScheme.onPrimary.withOpacity(0.6),
                        ],
                      )
                    : const Text('Update Password'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}