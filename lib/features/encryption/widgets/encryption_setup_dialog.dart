import 'package:flutter/material.dart';
import 'package:feelings/services/encryption_service.dart';
import 'package:feelings/features/auth/services/user_repository.dart';
import 'package:provider/provider.dart';
import 'package:feelings/providers/user_provider.dart';
import 'package:feelings/providers/couple_provider.dart';
import 'package:feelings/providers/chat_provider.dart';
import 'package:feelings/widgets/pulsing_dots_indicator.dart';

/// Encryption Setup Dialog
/// Handles three states:
/// 1. Nag Screen (pending) - Prompt user to enable or disable E2EE
/// 2. Passphrase Setup (enabling) - Collect passphrase and create backup
/// 3. Key Recovery (backup exists) - Restore key from passphrase
class EncryptionSetupDialog extends StatefulWidget {
  const EncryptionSetupDialog({super.key});

  @override
  State<EncryptionSetupDialog> createState() => _EncryptionSetupDialogState();
}

class _EncryptionSetupDialogState extends State<EncryptionSetupDialog> {
  final _userRepository = UserRepository();
  final _passphraseController = TextEditingController();
  final _confirmPassphraseController = TextEditingController();
  
  String _currentState = 'loading'; // loading, nag, setup, recovery
  bool _isProcessing = false;
  bool _obscurePassphrase = true;
  bool _obscureConfirm = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _determineInitialState();
  }

  @override
  void dispose() {
    _passphraseController.dispose();
    _confirmPassphraseController.dispose();
    super.dispose();
  }

  Future<void> _determineInitialState() async {
    final userProvider = context.read<UserProvider>();
    final userId = userProvider.currentUser?.id;
    
    if (userId == null) {
      Navigator.of(context).pop();
      return;
    }

    final status = await _userRepository.getEncryptionStatus(userId);
    final hasBackup = await _userRepository.getKeyBackup(userId);
    
    setState(() {
      if (status == 'pending') {
        if (hasBackup != null && !EncryptionService.instance.isReady) {
          _currentState = 'recovery'; // Backup exists but not loaded
        } else {
          _currentState = 'nag'; // First time, ask if they want to enable
        }
      } else if (status == 'enabled') {
        if (!EncryptionService.instance.isReady) {
          _currentState = 'recovery'; // Key backup exists, need to restore
        } else {
          _currentState = 'manage'; // ✨ NEW: Manage existing encryption
        }
      } else if (status == 'disabled') {
        _currentState = 'nag'; // Allow enabling again
      } else {
        // Fallback
        _currentState = 'nag';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: _buildContent(),
        ),
      ),
    );
  }

  Widget _buildContent() {
    switch (_currentState) {
      case 'loading':
        return const SizedBox(
          height: 200,
          child: Center(
            child: PulsingDotsIndicator(
              size: 40,
              colors: [Colors.pink, Colors.pinkAccent], // Assuming primary is pinkish based on PulsingDots usage usually
            ),
          ),
        );
      case 'nag':
        return _buildNagScreen();
      case 'setup':
        return _buildPassphraseSetup();
      case 'recovery':
        return _buildKeyRecovery();
      case 'manage':
        return _buildManageScreen(); // ✨ NEW
      default:
        return const SizedBox.shrink();
    }
  }

  // ==================== MANAGE SCREEN (NEW) ====================

  Widget _buildManageScreen() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.lock, color: Colors.green, size: 28),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Encryption Enabled',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const Text(
          'Your messages and data are currently secured with End-to-End Encryption.',
          style: TextStyle(fontSize: 14),
        ),
        const SizedBox(height: 24),
        if (_errorMessage != null)
           Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              _errorMessage!,
              style: const TextStyle(color: Colors.red, fontSize: 12),
            ),
          ),
        
        // Option 1: Change Passphrase
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.key),
          title: const Text('Change Backup Passphrase'),
          subtitle: const Text('Update the passphrase used to recover your key.'),
          onTap: _isProcessing ? null : () {
            setState(() {
              _currentState = 'setup';
              _passphraseController.clear();
              _confirmPassphraseController.clear();
              _errorMessage = null;
            });
          },
        ),
        const Divider(),
        
        // Option 2: Disable Encryption (Danger Zone?)
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.no_encryption_outlined, color: Colors.red),
          title: const Text('Disable Encryption', style: TextStyle(color: Colors.red)),
          onTap: _isProcessing ? null : _confirmDisableEncryption,
        ),
        
        const SizedBox(height: 16),
        Center(
          child: TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ),
      ],
    );
  }

  Future<void> _confirmDisableEncryption() async {
     final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Disable Encryption?'),
        content: const Text(
          'If you disable encryption, future messages will not be end-to-end encrypted. Your existing data remains accessible on this device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Disable'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _handleDisableEncryption();
    }
  }


  // ==================== NAG SCREEN ====================

  Widget _buildNagScreen() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '🔐 Enable End-to-End Encryption?',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        const Text(
          'Securing your shared history and future moments.',
          style: TextStyle(fontSize: 14),
        ),
        const SizedBox(height: 24),
        if (_errorMessage != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              _errorMessage!,
              style: const TextStyle(color: Colors.red, fontSize: 12),
            ),
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.end, // Align to right usually looks better, but user had spaceBetween
          children: [
            TextButton(
              onPressed: _isProcessing ? null : _handleDisableEncryption,
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                textStyle: const TextStyle(fontSize: 13),
              ),
              child: const Text('Keep Off'),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: _isProcessing ? null : () {
                setState(() {
                  _currentState = 'setup';
                });
              },
              style: ElevatedButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                textStyle: const TextStyle(fontSize: 13),
              ),
              child: _isProcessing
                  ? SizedBox(
                      width: 12,
                      child: Center(
                        child: PulsingDotsIndicator(
                          size: 16,
                          colors: [Colors.white, Colors.white.withOpacity(0.7)],
                        ),
                      ),
                    )
                  : const Text('Enable Encryption'),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _handleDisableEncryption() async {
    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      final userProvider = context.read<UserProvider>();
      final userId = userProvider.currentUser?.id;
      
      if (userId != null) {
        // ✨ [MODIFY] Use provider to update so local state refreshes immediately
        await userProvider.updateUserData({'encryptionStatus': 'disabled'});
        
        if (mounted) {
          // ✨ Close the dialog immediately
          Navigator.of(context).pop();
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Encryption disabled.'),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to update settings: $e';
          _isProcessing = false;
        });
      }
    }
  }

  // ==================== PASSPHRASE SETUP ====================

  Widget _buildPassphraseSetup() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '🔑 Create Encryption Passphrase',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.red.shade50,
            border: Border.all(color: Colors.red.shade200),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.red),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'You must remember this passphrase. If you lose it and your device, your encrypted data will be PERMANENTLY lost.',
                  style: TextStyle(fontSize: 12, color: Colors.red),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _passphraseController,
          obscureText: _obscurePassphrase,
          decoration: InputDecoration(
            labelText: 'Enter Strong Passphrase',
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(
              icon: Icon(_obscurePassphrase ? Icons.visibility : Icons.visibility_off),
              onPressed: () {
                setState(() {
                  _obscurePassphrase = !_obscurePassphrase;
                });
              },
            ),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _confirmPassphraseController,
          obscureText: _obscureConfirm,
          decoration: InputDecoration(
            labelText: 'Confirm Passphrase',
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(
              icon: Icon(_obscureConfirm ? Icons.visibility : Icons.visibility_off),
              onPressed: () {
                setState(() {
                  _obscureConfirm = !_obscureConfirm;
                });
              },
            ),
          ),
        ),
        if (_errorMessage != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              _errorMessage!,
              style: const TextStyle(color: Colors.red, fontSize: 12),
            ),
          ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton(
              onPressed: _isProcessing ? null : () {
                setState(() {
                   // Smart Back Navigation
                   if (EncryptionService.instance.isReady) {
                      _currentState = 'manage';
                   } else {
                      _currentState = 'nag';
                   }
                  _errorMessage = null;
                });
              },
              child: const Text('Back'),
            ),
            ElevatedButton(
              onPressed: _isProcessing ? null : _handleCreateBackup,
              child: _isProcessing
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: Center(
                        child: PulsingDotsIndicator(
                          size: 16,
                          colors: [Colors.white, Colors.white.withOpacity(0.7)],
                        ),
                      ),
                    )
                  : const Text('Create Backup'),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _handleCreateBackup() async {
    final passphrase = _passphraseController.text;
    final confirm = _confirmPassphraseController.text;

    if (passphrase.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter a passphrase';
      });
      return;
    }

    if (passphrase.length < 8) {
      setState(() {
        _errorMessage = 'Passphrase must be at least 8 characters';
      });
      return;
    }

    if (passphrase != confirm) {
      setState(() {
        _errorMessage = 'Passphrases do not match';
      });
      return;
    }

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      final userProvider = context.read<UserProvider>();
      final coupleProvider = context.read<CoupleProvider>(); // ✨ Need this for regeneration
      final userId = userProvider.currentUser?.id;
      final coupleId = coupleProvider.coupleId; // ✨ Need this
      
      if (userId == null) throw Exception('User not logged in');

      // ✨ CHECK: Do we actually have a key to backup?
      if (!EncryptionService.instance.isReady) {
        // If status is pending, it means we probably never generated one.
        // OR we are waiting for sync. 
        // Force generation now to resolve "deadlock".
        if (coupleId != null) {
          debugPrint("⚠️ [Setup] Key missing during backup. Auto-generating new CMK...");
          await coupleProvider.regenerateMasterKey();
        } else {
           throw Exception('Cannot generate key: No Couple ID found.');
        }
      }
      
      // Double check availability
      if (!EncryptionService.instance.isReady) {
         throw Exception('Failed to generate or load encryption key.');
      }

      // Create encrypted backup
      final backupBlob = await EncryptionService.instance.backupMasterKey(passphrase);
      
      // Upload to Firestore (also sets status to 'enabled')
      await _userRepository.uploadKeyBackup(userId, backupBlob);

      // ✨ [ADD] Externally update local provider state to reflect 'enabled' immediately
      await userProvider.updateUserData({'encryptionStatus': 'enabled'});

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Encryption enabled! Your backup is secure.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to create backup: $e';
        _isProcessing = false;
      });
    }
  }

  // ==================== KEY RECOVERY ====================

  Widget _buildKeyRecovery() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '🔓 Restore Encryption Key',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        const Text(
          'Enter your passphrase to restore your encryption key.',
          style: TextStyle(fontSize: 14),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _passphraseController,
          obscureText: _obscurePassphrase,
          decoration: InputDecoration(
            labelText: 'Enter Passphrase',
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(
              icon: Icon(_obscurePassphrase ? Icons.visibility : Icons.visibility_off),
              onPressed: () {
                setState(() {
                  _obscurePassphrase = !_obscurePassphrase;
                });
              },
            ),
          ),
        ),
        if (_errorMessage != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              _errorMessage!,
              style: const TextStyle(color: Colors.red, fontSize: 12),
            ),
          ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isProcessing ? null : _handleRestoreKey,
            child: _isProcessing
                ? SizedBox(
                      width: 16,
                      height: 16,
                      child: Center(
                        child: PulsingDotsIndicator(
                          size: 16,
                          colors: [Colors.white, Colors.white.withOpacity(0.7)],
                        ),
                      ),
                    )
                : const Text('Restore'),
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: TextButton(
            onPressed: _isProcessing ? null : _confirmResetKeys,
            style: TextButton.styleFrom(foregroundColor: Colors.grey),
            child: const Text('Forgot Passphrase? Reset Keys'),
          ),
        ),
      ],
    );
  }

  Future<void> _confirmResetKeys() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Encryption Keys?'),
        content: const Text(
          '⚠️ WARNING: If you reset your keys, you will lose access to ALL your previous encrypted history forever.\n\n'
          'This action cannot be undone. A new key will be generated for future messages.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Reset Everything'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      _handleResetKeys();
    }
  }

  Future<void> _handleResetKeys() async {
    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      final coupleProvider = context.read<CoupleProvider>();
      
      // 1. Regenerate the master key (this saves it locally)
      await coupleProvider.regenerateMasterKey();

      // 2. Move to setup state to force a NEW backup immediately
      setState(() {
        _isProcessing = false;
        _currentState = 'setup';
        _passphraseController.clear();
        _confirmPassphraseController.clear();
        _errorMessage = null; 
        
        // Explain what happened
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Keys reset. Please create a new backup passphrase now.'),
            duration: Duration(seconds: 4),
          ),
        );
      });

    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to reset keys: $e';
        _isProcessing = false;
      });
    }
  }

  Future<void> _handleRestoreKey() async {
    final passphrase = _passphraseController.text;

    if (passphrase.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter your passphrase';
      });
      return;
    }

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      final userProvider = context.read<UserProvider>();
      final coupleProvider = context.read<CoupleProvider>();
      final userId = userProvider.currentUser?.id;
      final coupleId = coupleProvider.coupleId;
      
      if (userId == null) throw Exception('User not logged in');
      if (coupleId == null) throw Exception('No couple found');

      // Get backup from Firestore
      final backupBlob = await _userRepository.getKeyBackup(userId);
      if (backupBlob == null) throw Exception('No backup found');

      // Restore key
      await EncryptionService.instance.restoreMasterKey(coupleId, passphrase, backupBlob);

      // ✨ Notify ChatProvider to retry decryption immediately
      if (mounted) {
         context.read<ChatProvider>().reloadMessages();
      }

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Encryption key restored!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Incorrect passphrase or restore failed: $e';
        _isProcessing = false;
      });
    }
  }
}
