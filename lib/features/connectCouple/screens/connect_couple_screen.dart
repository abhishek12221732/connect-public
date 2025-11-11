// lib/features/connectCouple/screens/connect_couple_screen.dart

import 'dart:async'; 
import 'package:firebase_auth/firebase_auth.dart'; 
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/couple_provider.dart';
import 'package:feelings/providers/user_provider.dart';
// ✨ [ADD] Import RhmRepository
import 'package:feelings/features/rhm/repository/rhm_repository.dart'; 
import 'package:qr_flutter/qr_flutter.dart';
import 'package:flutter/services.dart'; // For Clipboard
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:feelings/providers/date_idea_provider.dart';
import 'package:feelings/providers/bucket_list_provider.dart';
import 'package:feelings/providers/calendar_provider.dart';
import 'package:feelings/providers/tips_provider.dart';
import 'package:feelings/widgets/pulsing_dots_indicator.dart'; 

class ConnectCoupleScreen extends StatefulWidget {
  // ... (unchanged)
  const ConnectCoupleScreen({super.key});

  @override
  _ConnectCoupleScreenState createState() => _ConnectCoupleScreenState();
}

class _ConnectCoupleScreenState extends State<ConnectCoupleScreen> {
  // ... (state variables _partnerCodeController, _isLoading, _myCoupleCode are unchanged) ...
  final TextEditingController _partnerCodeController = TextEditingController();
  bool _isLoading = false;
  String? _myCoupleCode;

  // ... (state variables _isVerified, _verificationCheckTimer, _canResendEmail, _cooldownTimer are unchanged) ...
  bool _isVerified = false;
  Timer? _verificationCheckTimer;
  bool _canResendEmail = true;
  Timer? _cooldownTimer;

  @override
  void initState() {
    // ... (unchanged)
    super.initState();
    _loadMyCoupleCode();
    _checkVerificationStatus(); 
    _partnerCodeController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    // ... (unchanged)
    _partnerCodeController.dispose();
    _verificationCheckTimer?.cancel(); 
    _cooldownTimer?.cancel(); 
    super.dispose();
  }

  // ... (_checkVerificationStatus, _resendVerificationEmail, _loadMyCoupleCode methods are unchanged) ...
  Future<void> _checkVerificationStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() {
      _isVerified = user.emailVerified;
    });

    if (!user.emailVerified) {
      _verificationCheckTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
        await FirebaseAuth.instance.currentUser?.reload();
        final updatedUser = FirebaseAuth.instance.currentUser;
        if (updatedUser?.emailVerified ?? false) {
          timer.cancel();
          if (mounted) {
            setState(() {
              _isVerified = true;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Email successfully verified!'),
                backgroundColor: Colors.green,
              ),
            );
          }
        }
      });
    }
  }

  Future<void> _resendVerificationEmail() async {
    if (!_canResendEmail) return;

    setState(() {
      _canResendEmail = false;
    });

    try {
      await FirebaseAuth.instance.currentUser?.sendEmailVerification();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('A new verification email has been sent.')),
        );
      }
      _cooldownTimer = Timer(const Duration(seconds: 60), () {
        if (mounted) {
          setState(() => _canResendEmail = true);
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
      setState(() {
        _canResendEmail = true;
      });
    }
  }

  Future<void> _loadMyCoupleCode() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final user = userProvider.userData;
    if (user != null && user['userId'] != null) {
      if (user['coupleCode'] != null) {
        setState(() {
          _myCoupleCode = user['coupleCode'];
        });
      } else {
        final code = await userProvider.generateAndAssignCoupleCode(user['userId']);
        setState(() {
          _myCoupleCode = code;
        });
      }
    }
  }


  // ✨ [MODIFY] Update _connectUsers
  void _connectUsers() async {
    final theme = Theme.of(context);
    final partnerCode = _partnerCodeController.text.trim().toUpperCase();

    // ... (unchanged validation) ...
    if (partnerCode.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Partner code is required.')),
      );
      return;
    }
    
    setState(() => _isLoading = true);

    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final coupleProvider = Provider.of<CoupleProvider>(context, listen: false);
      final userId = userProvider.getUserId();

      if (userId == null) {
        throw Exception('Could not identify current user. Please restart the app.');
      }

      final bool isNewConnection = userProvider.coupleId == null;

      await coupleProvider.connectWithPartnerCode(userId, partnerCode, userProvider.userData?['name'] ?? 'Your partner');
      await userProvider.fetchUserData(); 

      if (isNewConnection && mounted) {
        // ✨ [ADD] Read RhmRepository here
        final rhmRepository = context.read<RhmRepository>(); 
        final newCoupleId = Provider.of<UserProvider>(context, listen: false).coupleId;
        
        if (newCoupleId != null) {
          Provider.of<DateIdeaProvider>(context, listen: false).listenToSuggestions(newCoupleId);
          final bucketListProvider = Provider.of<BucketListProvider>(context, listen: false);
          if (!bucketListProvider.isInitialized) {
            // ✨ [MODIFY] Pass rhmRepository here
            await bucketListProvider.initialize(
              coupleId: newCoupleId, 
              userId: userId,
              rhmRepository: rhmRepository, // Pass it
            );
          }
          Provider.of<CalendarProvider>(context, listen: false).listenToEvents(newCoupleId);
          await Provider.of<TipsProvider>(context, listen: false).initialize(
            userId: userId, 
            coupleId: newCoupleId, 
            userData: userProvider.userData!, 
            partnerData: userProvider.partnerData,
          );
        }
      }
      
      // ... (rest of the method unchanged) ...
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Successfully connected with your partner!'),
            backgroundColor: Colors.green,
          ),
        );
        if (isNewConnection) {
          Future.delayed(const Duration(seconds: 1), () {
            if (mounted) {
              Navigator.pushNamedAndRemoveUntil(context, '/bottom_nav', (route) => false);
            }
          });
        }
      }
      _partnerCodeController.clear();
      
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: theme.colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _copyCode() {
    // ... (unchanged)
    if (_myCoupleCode != null) {
      Clipboard.setData(ClipboardData(text: _myCoupleCode!));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Code copied!')),
      );
    }
  }

  void _scanQrCode() async {
    // ... (unchanged)
    final code = await showDialog<String>(
      context: context,
      builder: (context) => const _QrScannerDialog(),
    );
    if (code != null && code.isNotEmpty) {
      setState(() {
        _partnerCodeController.text = code;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Code scanned!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // ... (build method logic is unchanged) ...
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Connect with Partner'),
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_myCoupleCode != null) ...[
                  Card(
                    color: colorScheme.surfaceContainerHighest,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                      child: Column(
                        children: [
                          Text(
                            'Your Couple Code', 
                            style: theme.textTheme.titleMedium?.copyWith(color: colorScheme.primary)
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SelectableText(
                                _myCoupleCode!,
                                style: theme.textTheme.displaySmall?.copyWith(letterSpacing: 2),
                              ),
                              IconButton(
                                icon: Icon(Icons.copy, color: colorScheme.primary),
                                onPressed: _copyCode,
                                tooltip: 'Copy',
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          QrImageView(
                            data: _myCoupleCode!,
                            version: QrVersions.auto,
                            size: 120.0,
                            eyeStyle: QrEyeStyle(eyeShape: QrEyeShape.square, color: colorScheme.onSurfaceVariant),
                            dataModuleStyle: QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                ],

                if (!_isVerified)
                  Card(
                    color: colorScheme.errorContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Icon(Icons.warning_amber_rounded, color: colorScheme.error),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Your email is not verified.',
                                  style: theme.textTheme.titleMedium?.copyWith(color: colorScheme.onErrorContainer),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Please check your inbox to verify your account before connecting with a partner.',
                             style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onErrorContainer),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: TextButton(
                              onPressed: _canResendEmail ? _resendVerificationEmail : null,
                              style: TextButton.styleFrom(
                                foregroundColor: colorScheme.onErrorContainer,
                                backgroundColor: colorScheme.error.withOpacity(0.2),
                              ),
                              child: const Text('Resend verification email'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 8),

                Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          "Enter your partner's code or scan their QR code:", 
                          style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface.withOpacity(0.7))
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _partnerCodeController,
                                textCapitalization: TextCapitalization.characters,
                                decoration: const InputDecoration(
                                  labelText: 'Partner Code',
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.paste),
                              tooltip: 'Paste',
                              onPressed: () async {
                                final data = await Clipboard.getData('text/plain');
                                if (data?.text != null) {
                                  setState(() {
                                    _partnerCodeController.text = data!.text!.trim().toUpperCase();
                                  });
                                }
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.qr_code_scanner),
                              tooltip: 'Scan QR',
                              onPressed: _scanQrCode,
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: (_isLoading || _partnerCodeController.text.trim().isEmpty || !_isVerified) 
                                ? null 
                                : _connectUsers,
                            style: theme.elevatedButtonTheme.style?.copyWith(
                              padding: WidgetStateProperty.all(const EdgeInsets.symmetric(vertical: 16)),
                            ),
                            child: _isLoading
                                ? PulsingDotsIndicator(
                                  size: 30,
                                  colors: [
                                    colorScheme.onPrimary,
                                    colorScheme.onPrimary.withOpacity(0.8),
                                    colorScheme.onPrimary.withOpacity(0.6),
                                  ],
                                )
                                : const Text('Connect Partner'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ... (_QrScannerDialog widget is unchanged) ...
class _QrScannerDialog extends StatelessWidget {
  const _QrScannerDialog();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      child: SizedBox(
        width: 300,
        height: 400,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text('Scan Partner QR Code', style: theme.textTheme.titleLarge),
            ),
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.all(Radius.circular(16)),
                child: MobileScanner(
                  onDetect: (capture) {
                    final String? code = capture.barcodes.first.rawValue;
                    if (code != null && code.isNotEmpty) {
                      Navigator.of(context).pop(code);
                    }
                  },
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }
}