import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:animate_do/animate_do.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:feelings/features/auth/models/user_model.dart';
import 'package:feelings/features/auth/services/auth_service.dart';
import 'package:feelings/features/auth/services/cloudinary_helper.dart';
import 'package:feelings/features/auth/services/image_cropper_helper.dart';
import 'package:feelings/providers/couple_provider.dart';
import 'package:feelings/providers/user_provider.dart';
import 'package:feelings/widgets/pulsing_dots_indicator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

class OnboardingScreen extends StatefulWidget {
  final String email;
  final String name;
  final String photoURL;

  const OnboardingScreen({
    super.key,
    required this.email,
    required this.name,
    required this.photoURL,
  });

  @override
  _OnboardingScreenState createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final AuthService _authService = AuthService();
  final PageController _pageController = PageController();
  int _currentPage = 0;
  File? _profileImage;
  Uint8List? _webImageBytes;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _partnerIdController = TextEditingController();
  String _selectedMood = 'Excited';
  bool _isLoading = false;
  bool _locationPermissionGranted = false;
  bool _hasSharedLocation = false;
  Position? _currentPosition;
  String? _userId;
  String? _myCoupleCode;
  final TextEditingController _partnerCodeController = TextEditingController();
  Timer? _verificationTimer;
  bool _isEmailVerified = false;
  bool _showVerificationPage = false;
  bool _canResendEmail = true;
  int _resendCooldown = 60;
  Timer? _cooldownTimer;

  String? _selectedLoveLanguage;
  Gender? _selectedGender;

  final List<String> _moods = [
    'Happy',
    'Excited',
    'Sad',
    'Angry',
    'Relaxed',
    'Neutral'
  ];
  final Map<String, String> _moodEmojis = {
    'Relaxed': '😌',
    'Happy': '😊',
    'Excited': '😆',
    'Sad': '😢',
    'Neutral': '😐',
    'Angry': '😡',
  };
  final Map<String, Color> _moodColors = const {
    'Happy': Colors.yellow,
    'Excited': Colors.orange,
    'Sad': Colors.blue,
    'Angry': Colors.red,
    'Relaxed': Colors.green,
    'Neutral': Colors.grey,
  };

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.name;
    _checkInitialLocationPermissionStatus();
    _loadMyCoupleCode();
    _checkIfVerificationIsNeeded();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _partnerIdController.dispose();
    _partnerCodeController.dispose();
    _verificationTimer?.cancel();
    _cooldownTimer?.cancel();
    super.dispose();
  }

  void _checkIfVerificationIsNeeded() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && !user.emailVerified) { 
      setState(() {
        _showVerificationPage = true;
      });
      _startVerificationTimer(); // You can comment this out too

      setState(() {
        _canResendEmail = false;
      });
      _startCooldownTimer();
    } else {
      setState(() {
        _isEmailVerified = true;
      });
    }
  }

  void _startVerificationTimer() {
    _verificationTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      await FirebaseAuth.instance.currentUser?.reload();
      final user = FirebaseAuth.instance.currentUser;
      if (user?.emailVerified ?? false) {
        _verificationTimer?.cancel();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Email successfully verified!'),
              backgroundColor: Colors.green,
            ),
          );
          _pageController.nextPage(
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOut,
          );
        }
      }
    });
  }

  Future<void> _resendVerificationEmail() async {
    if (!_canResendEmail) return;

    setState(() {
      _canResendEmail = false;
    });

    try {
      await _authService.sendVerificationEmail();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('A new verification email has been sent.')),
        );
      }
      _startCooldownTimer();
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

  void _startCooldownTimer() {
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendCooldown <= 1) {
        timer.cancel();
        if (mounted) {
          setState(() {
            _canResendEmail = true;
            _resendCooldown = 60;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _resendCooldown--;
          });
        }
      }
    });
  }

  Future<void> _loadMyCoupleCode() async {
    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);

      if (userProvider.userData == null) {
        await userProvider.fetchUserData();
      }

      final user = userProvider.userData;

      if (user != null && user['userId'] != null) {
        if (user['coupleCode'] != null) {
          if (mounted) setState(() => _myCoupleCode = user['coupleCode']);
        } else {
          final code =
              await userProvider.generateAndAssignCoupleCode(user['userId']);
          if (mounted) setState(() => _myCoupleCode = code);
        }
      } else {
        if (mounted) setState(() => _myCoupleCode = 'ERROR');
      }
    } catch (e) {
      if (mounted) setState(() => _myCoupleCode = 'ERROR');
    }
  }

  void _copyCode() {
    if (_myCoupleCode != null) {
      Clipboard.setData(ClipboardData(text: _myCoupleCode!));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Code copied!')),
      );
    }
  }

  void _scanQrCode() async {
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

  void _connectUsersByCode() async {
    final theme = Theme.of(context);
    final partnerCode = _partnerCodeController.text.trim().toUpperCase();
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
        throw Exception(
            'Could not identify current user. Please restart the app.');
      }

      await coupleProvider.connectWithPartnerCode(userId, partnerCode, userProvider.userData?['name'] ?? 'Your partner');
      await userProvider.fetchUserData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Successfully connected with your partner!'),
            backgroundColor: Colors.green,
          ),
        );
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

  Future<void> _checkInitialLocationPermissionStatus() async {
    final status = await Permission.location.status;
    if (mounted) setState(() => _locationPermissionGranted = status.isGranted);
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isLoading = true);
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Location services are disabled. Please enable them.')),
        );
        return;
      }

      final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      setState(() {
        _currentPosition = position;
        _hasSharedLocation = true;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Couldn't get location: $e")));
      }
      setState(() => _hasSharedLocation = false);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _requestPermissionAndShareLocation() async {
    final status = await Permission.location.request();
    setState(() => _locationPermissionGranted = status.isGranted);

    if (status.isGranted) {
      await _getCurrentLocation();
    } else if (status.isDenied && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Location permission denied.")));
    } else if (status.isPermanentlyDenied) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  "Location permission permanently denied. Please enable it from app settings.")),
        );
      }
      await openAppSettings();
    }
  }

  Future<void> _pickImage() async {
    final pickedFile = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );

    if (pickedFile == null) return;

    if (kIsWeb) {
      _webImageBytes = await pickedFile.readAsBytes();
      _profileImage = null;
    } else {
      final cropped = await cropImage(pickedFile.path, context);
      if (cropped == null) return;
      _profileImage = cropped;
      _webImageBytes = null;
    }

    setState(() {});
  }

  Future<void> _completeOnboarding() async {
    if (_nameController.text.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Please enter your name')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final userId = userProvider.userData?['userId'];
      if (userId == null) {
        throw Exception("User ID not found. Please restart the app.");
      }

      String? imageUrl;
      bool imageUploadAttempted = _profileImage != null || _webImageBytes != null;

      if (imageUploadAttempted) {
        final cloudinaryHelper = CloudinaryHelper();
        final String uniquePublicId = 'profile_$userId';

        // ✨ FIX: Unified upload logic for web and mobile
        Uint8List? imageBytes;
        if (kIsWeb) {
          imageBytes = _webImageBytes;
        } else if (_profileImage != null) {
          imageBytes = await _profileImage!.readAsBytes();
        }

        if (imageBytes != null) {
          imageUrl = await cloudinaryHelper.uploadImageBytes(
            imageBytes,
            publicId: uniquePublicId,
            folder: 'profileImages',
          );
        }
        // ✨ END FIX

        if (imageUrl == null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content:
                      const Text('Error: Could not upload image. Please try again.'),
                  backgroundColor: Theme.of(context).colorScheme.error),
            );
          }
          setState(() => _isLoading = false);
          return;
        }
      }

      final updateData = <String, dynamic>{
        'name': _nameController.text.trim(),
        'onboardingCompleted': true,
        'mood': _selectedMood,
        'lastUpdated': FieldValue.serverTimestamp(),
        'loveLanguage': _selectedLoveLanguage,
        'gender': _selectedGender?.name,
      };

      if (imageUrl != null) updateData['profileImageUrl'] = imageUrl;
      if (_currentPosition != null && _hasSharedLocation) {
        updateData['latitude'] = _currentPosition!.latitude;
        updateData['longitude'] = _currentPosition!.longitude;
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .update(updateData);
      await userProvider.fetchUserData();

      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(
            context, '/bottom_nav', (route) => false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error completing onboarding: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- WIDGET BUILDERS ---
  // (All _build... methods remain the same)
  Widget buildWelcomeStep() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return FadeIn(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 40),
          ElasticIn(
            // ✨ [MODIFY] Replaced the heart icon with your app icon
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16.0), // Adds nice rounded corners
              child: Image.asset(
                'assets/icon/app_icon_foreground.png', // This path must be in your pubspec.yaml
                height: 100,
                width: 100,
              ),
            ),
          ),
          const SizedBox(height: 30),
          Text(
            'Welcome to Feelings!',
            style: theme.textTheme.displaySmall?.copyWith(
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30),
            // ✨ [MODIFY] Updated the welcome text to be more engaging
            child: Text(
              'Your new space to share, connect, and grow closer.\nLet\'s get your profile ready in just a few steps.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
          ),
          const SizedBox(height: 50),
          BounceInUp(
            child: ElevatedButton(
              key: const Key('get_started_button'),
              onPressed: () {
                _pageController.nextPage(
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeInOut,
                );
              },
              child: const Text('Get Started'),
            ),
          ),
        ],
      ),
    );
  }



  Widget _buildVerificationStep() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return FadeIn(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElasticIn(
              child: Icon(Icons.mark_email_read_outlined,
                  size: 80, color: colorScheme.primary),
            ),
            const SizedBox(height: 30),
            Text('Verify Your Email',
                style: theme.textTheme.displaySmall
                    ?.copyWith(color: colorScheme.primary)),
            const SizedBox(height: 20),
            Text(
              "We've sent a verification link to:\n${widget.email}\n\nPlease check your inbox (and spam folder!) to continue.",
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge
                  ?.copyWith(color: colorScheme.onSurface.withOpacity(0.7)),
            ),
            const SizedBox(height: 40),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Waiting for verification...',
                    style: theme.textTheme.bodyMedium),
              ],
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: _canResendEmail ? _resendVerificationEmail : null,
              child: Text(_canResendEmail
                  ? 'Resend Email'
                  : 'Resend in $_resendCooldown s'),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () {
                _authService.logout();
                Navigator.pushNamedAndRemoveUntil(
                    context, '/register', (route) => false);
              },
              child: Text('Use a different email',
                  style: TextStyle(
                      color: colorScheme.onSurface.withOpacity(0.6))),
            ),
          ],
        ),
      ),
    );
  }

  String _getGenderDisplayName(Gender gender) {
    switch (gender) {
      case Gender.male:
        return 'Male';
      case Gender.female:
        return 'Female';
      case Gender.other:
        return 'Other';
      case Gender.preferNotToSay:
        return 'Prefer Not To Say';
    }
  }

  Widget _buildProfileStep() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    ImageProvider? newImageProvider = _webImageBytes != null
        ? MemoryImage(_webImageBytes!)
        : (_profileImage != null ? FileImage(_profileImage!) : null);
    ImageProvider? existingImageProvider =
        widget.photoURL.isNotEmpty ? NetworkImage(widget.photoURL) : null;

    final loveLanguages = [
      'Words of Affirmation',
      'Acts of Service',
      'Receiving Gifts',
      'Quality Time',
      'Physical Touch',
    ];

    return FadeIn(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            children: [
              const SizedBox(height: 80),
              Text('Your Profile',
                  style: theme.textTheme.headlineMedium
                      ?.copyWith(color: colorScheme.primary)),
              const SizedBox(height: 20),
              GestureDetector(
                onTap: _pickImage,
                child: CircleAvatar(
                  radius: 60,
                  backgroundColor: colorScheme.surfaceContainerHighest,
                  backgroundImage: newImageProvider ?? existingImageProvider,
                  child: (newImageProvider == null && existingImageProvider == null)
                      ? Icon(Icons.camera_alt,
                          size: 40, color: colorScheme.onSurfaceVariant)
                      : null,
                ),
              ),
              const SizedBox(height: 30),
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                    labelText: 'Your Name', prefixIcon: Icon(Icons.person)),
              ),
              const SizedBox(height: 20),
              TextField(
                readOnly: true,
                decoration: InputDecoration(
                    labelText: 'Email',
                    prefixIcon: const Icon(Icons.email),
                    filled: true,
                    fillColor: colorScheme.surfaceContainerHighest.withOpacity(0.5)),
                controller: TextEditingController(text: widget.email),
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField<Gender>(
                initialValue: _selectedGender,
                hint: const Text('Select your gender'),
                decoration: const InputDecoration(
                  labelText: 'Gender',
                  prefixIcon: Icon(Icons.wc_outlined),
                ),
                items: Gender.values.map((gender) {
                  return DropdownMenuItem(
                    value: gender,
                    child: Text(_getGenderDisplayName(gender)),
                  );
                }).toList(),
                onChanged: (Gender? newValue) {
                  setState(() {
                    _selectedGender = newValue;
                  });
                },
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                initialValue: _selectedLoveLanguage,
                hint: const Text('Select your love language (Optional)'),
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Love Language',
                  prefixIcon: Icon(Icons.favorite_outline),
                ),
                items: loveLanguages.map((language) {
                  return DropdownMenuItem(
                    value: language,
                    child: Text(language, overflow: TextOverflow.ellipsis),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  setState(() {
                    _selectedLoveLanguage = newValue;
                  });
                },
              ),
              const SizedBox(height: 40),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  OutlinedButton(
                    onPressed: () {
                      FocusScope.of(context).unfocus();
                      _pageController.previousPage(
                          duration: const Duration(milliseconds: 500),
                          curve: Curves.easeInOut);
                    },
                    child: const Text('Back'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      FocusScope.of(context).unfocus();
                      _pageController.nextPage(
                          duration: const Duration(milliseconds: 500),
                          curve: Curves.easeInOut);
                    },
                    child: const Text('Next'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPartnerStep() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final coupleProvider = Provider.of<CoupleProvider>(context);
    final isConnected = coupleProvider.partnerData != null;
    final partnerName = coupleProvider.partnerData?['name'] ?? 'your partner';

    return FadeIn(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
            24, 80, 24, MediaQuery.of(context).viewInsets.bottom + 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Connect with Partner',
                style: theme.textTheme.headlineMedium
                    ?.copyWith(color: colorScheme.primary)),
            const SizedBox(height: 20),
            if (_myCoupleCode != null && _myCoupleCode != 'ERROR') ...[
              Card(
                color: colorScheme.surfaceContainerHighest,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  child: Column(
                    children: [
                      Text('Your Couple Code',
                          style: theme.textTheme.titleMedium
                              ?.copyWith(color: colorScheme.primary)),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SelectableText(_myCoupleCode!,
                              style: theme.textTheme.displaySmall),
                          IconButton(
                              icon:
                                  Icon(Icons.copy, color: colorScheme.primary),
                              onPressed: _copyCode,
                              tooltip: 'Copy'),
                        ],
                      ),
                      const SizedBox(height: 8),
                      QrImageView(
                        data: _myCoupleCode!,
                        version: QrVersions.auto,
                        size: 120.0,
                        eyeStyle: QrEyeStyle(
                            eyeShape: QrEyeShape.square,
                            color: colorScheme.onSurfaceVariant),
                        dataModuleStyle: QrDataModuleStyle(
                            dataModuleShape: QrDataModuleShape.square,
                            color: colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ),
            ] else if (_myCoupleCode == 'ERROR') ...[
              Card(
                color: colorScheme.errorContainer,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  child: Column(
                    children: [
                      Text('Your Couple Code',
                          style: theme.textTheme.titleMedium
                              ?.copyWith(color: colorScheme.onErrorContainer)),
                      const SizedBox(height: 20),
                      Icon(Icons.error_outline,
                          color: colorScheme.error, size: 40),
                      const SizedBox(height: 12),
                      Text('Failed to load couple code',
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(color: colorScheme.onErrorContainer)),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: _loadMyCoupleCode,
                        style: ElevatedButton.styleFrom(
                            backgroundColor: colorScheme.error,
                            foregroundColor: colorScheme.onError),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
            ] else ...[
              Card(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  child: Column(
                    children: [
                      Text('Your Couple Code',
                          style: theme.textTheme.titleMedium
                              ?.copyWith(color: colorScheme.primary)),
                      const SizedBox(height: 20),
                      PulsingDotsIndicator(
                        size: 80,
                        colors: [
                          Theme.of(context).colorScheme.primary,
                          Theme.of(context).colorScheme.secondary,
                          Theme.of(context).colorScheme.onSurface,
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text('Generating your couple code...',
                          style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurface.withOpacity(0.7))),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 28),
            Card(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                        "Enter your partner's code or scan their QR code:",
                        style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurface.withOpacity(0.7))),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                            child: TextField(
                                controller: _partnerCodeController,
                                textCapitalization:
                                    TextCapitalization.characters,
                                decoration: const InputDecoration(
                                    labelText: 'Partner Code'))),
                        IconButton(
                            icon: const Icon(Icons.paste),
                            tooltip: 'Paste',
                            onPressed: () async {
                              final data =
                                  await Clipboard.getData('text/plain');
                              if (data?.text != null) {
                                setState(() => _partnerCodeController.text =
                                    data!.text!.trim().toUpperCase());
                              }
                            }),
                        IconButton(
                            icon: const Icon(Icons.qr_code_scanner),
                            tooltip: 'Scan QR',
                            onPressed: _scanQrCode),
                      ],
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                            onPressed: _isLoading ? null : _connectUsersByCode,
                            child: _isLoading
                                ? SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: PulsingDotsIndicator(
                                      size: 30,
                                      colors: [
                                        Theme.of(context).colorScheme.onPrimary,
                                        Theme.of(context).colorScheme.onPrimary,
                                        Theme.of(context).colorScheme.onPrimary,
                                      ],
                                    ),
                                  )
                                : const Text('Connect Partner'))),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        OutlinedButton(
                            onPressed: () => _pageController.previousPage(
                                duration: const Duration(milliseconds: 500),
                                curve: Curves.easeInOut),
                            child: const Text('Back')),
                        TextButton(
                            onPressed: () => _pageController.nextPage(
                                duration: const Duration(milliseconds: 500),
                                curve: Curves.easeInOut),
                            child: const Text('Skip for now')),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            if (isConnected) ...[
              AnimatedContainer(
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeInOut,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20)),
                child: Column(
                  children: [
                    Icon(Icons.check_circle,
                        color: Colors.green.shade700, size: 60),
                    const SizedBox(height: 10),
                    Text("You're connected with $partnerName!",
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleMedium
                            ?.copyWith(color: Colors.green.shade800)),
                    const SizedBox(height: 18),
                    ElevatedButton(
                      onPressed: () async {
                        final userProvider =
                            Provider.of<UserProvider>(context, listen: false);
                        await userProvider.fetchUserData();
                        if (mounted) {
                          Navigator.pushNamedAndRemoveUntil(
                              context, '/bottom_nav', (route) => false);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade600,
                          foregroundColor: Colors.white),
                      child: const Text('Go to Home'),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLocationStep() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return FadeIn(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 20),
            Text('Your Location',
                style: theme.textTheme.headlineMedium
                    ?.copyWith(color: colorScheme.primary)),
            const SizedBox(height: 20),
            Image.asset('assets/images/location.png', height: 150),
            const SizedBox(height: 30),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Text(
                _hasSharedLocation && _currentPosition != null
                    ? "We've detected your location. Your partner will be able to see how far apart you are."
                    : _locationPermissionGranted
                        ? "Tap 'Share My Location' to share your distance with your partner."
                        : "Allow location permission to share your distance with your partner.",
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge
                    ?.copyWith(color: colorScheme.onSurface.withOpacity(0.7)),
              ),
            ),
            const SizedBox(height: 20),
            if (_currentPosition != null && _hasSharedLocation)
              Text(
                "Lat: ${_currentPosition!.latitude.toStringAsFixed(4)}, Lng: ${_currentPosition!.longitude.toStringAsFixed(4)}",
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: colorScheme.onSurface.withOpacity(0.7)),
              ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: _isLoading
                  ? null
                  : () async {
                      if (!_locationPermissionGranted) {
                        await _requestPermissionAndShareLocation();
                      } else {
                        await _getCurrentLocation();
                      }
                    },
              child: _isLoading
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: PulsingDotsIndicator(
                        size: 30,
                        colors: [
                          Theme.of(context).colorScheme.onPrimary,
                          Theme.of(context).colorScheme.onPrimary,
                          Theme.of(context).colorScheme.onPrimary,
                        ],
                      ),
                    )
                  : Text(!_locationPermissionGranted
                      ? 'Allow Location'
                      : (_hasSharedLocation
                          ? 'Refresh Location'
                          : 'Share My Location')),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                OutlinedButton(
                  onPressed: () => _pageController.previousPage(
                      duration: const Duration(milliseconds: 500),
                      curve: Curves.easeInOut),
                  child: const Text('Back'),
                ),
                ElevatedButton(
                  onPressed: () => _pageController.nextPage(
                      duration: const Duration(milliseconds: 500),
                      curve: Curves.easeInOut),
                  child: const Text('Next'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMoodStep() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final int selectedMoodIndex = _moods.indexOf(_selectedMood);
    final PageController moodPageController =
        PageController(viewportFraction: 0.25, initialPage: selectedMoodIndex);

    return FadeIn(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 20),
          Text('How Are You Feeling?',
              style: theme.textTheme.headlineMedium
                  ?.copyWith(color: colorScheme.primary)),
          const SizedBox(height: 20),
          FadeIn(
            child: Column(
              children: [
                Text('Selected:',
                    style: theme.textTheme.bodyLarge
                        ?.copyWith(color: colorScheme.onSurface.withOpacity(0.7))),
                const SizedBox(height: 10),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: _moodColors[_selectedMood]!.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _moodColors[_selectedMood]!, width: 2),
                  ),
                  child: Text(
                    '${_moodEmojis[_selectedMood]!} $_selectedMood',
                    style: theme.textTheme.titleLarge
                        ?.copyWith(color: _moodColors[_selectedMood]!),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
          SizedBox(
            height: 80,
            child: PageView.builder(
              controller: moodPageController,
              onPageChanged: (index) =>
                  setState(() => _selectedMood = _moods[index]),
              itemCount: _moods.length,
              itemBuilder: (context, index) {
                final mood = _moods[index];
                final isSelected = _selectedMood == mood;
                return Center(
                  child: GestureDetector(
                    onTap: () {
                      setState(() => _selectedMood = mood);
                      moodPageController.animateToPage(index,
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isSelected
                            ? _moodColors[mood]!.withOpacity(0.4)
                            : Colors.transparent,
                        border: isSelected
                            ? Border.all(color: _moodColors[mood]!, width: 2)
                            : null,
                      ),
                      child: Text(
                        _moodEmojis[mood]!,
                        style: TextStyle(fontSize: isSelected ? 48 : 36),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 40),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              OutlinedButton(
                onPressed: () => _pageController.previousPage(
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.easeInOut),
                child: const Text('Back'),
              ),
              ElevatedButton(
                onPressed: _completeOnboarding,
                child: _isLoading
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: PulsingDotsIndicator(
                          size: 10,
                          colors: [
                            Theme.of(context).colorScheme.onPrimary,
                            Theme.of(context).colorScheme.onPrimary,
                            Theme.of(context).colorScheme.onPrimary,
                          ],
                        ),
                      )
                    : const Text('Finish'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final List<Widget> pages = [
      buildWelcomeStep(),
      if (_showVerificationPage) _buildVerificationStep(),
      _buildProfileStep(),
      _buildPartnerStep(),
      _buildLocationStep(),
      _buildMoodStep(),
    ];
    int totalIndicatorPages = 4;
    int currentIndicatorIndex = -1;
    if (_currentPage == pages.indexOf(_buildProfileStep())) {
      currentIndicatorIndex = 0;
    }
    if (_currentPage == pages.indexOf(_buildPartnerStep())) {
      currentIndicatorIndex = 1;
    }
    if (_currentPage == pages.indexOf(_buildLocationStep())) {
      currentIndicatorIndex = 2;
    }
    if (_currentPage == pages.indexOf(_buildMoodStep())) {
      currentIndicatorIndex = 3;
    }

    // ✨ [ADD] Wrap the Scaffold in PopScope
    return PopScope(
      canPop: false,
      onPopInvoked: (bool didPop) {
        if (didPop) return; // This should not happen since canPop is false

        // Define the indices that trigger a logout
        const int welcomePageIndex = 0;
        int? verificationPageIndex;
        if (_showVerificationPage) {
          verificationPageIndex = 1;
        }

        if (_currentPage == welcomePageIndex ||
            (_currentPage == verificationPageIndex &&
                verificationPageIndex != null)) {
          // User is on the first or verification page, so log them out
          _authService.logout();
          // The AuthWrapper will handle navigation
        } else {
          // User is on a subsequent page, go to the previous page
          _pageController.previousPage(
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOut,
          );
        }
      },
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: Stack(
          children: [
            PageView(
              controller: _pageController,
              onPageChanged: (page) => setState(() => _currentPage = page),
              physics: const NeverScrollableScrollPhysics(),
              children: pages,
            ),
            if (currentIndicatorIndex != -1)
              Positioned(
                top: 50,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(totalIndicatorPages, (index) {
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: 10,
                      height: 10,
                      margin: const EdgeInsets.symmetric(horizontal: 5),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: currentIndicatorIndex == index
                            ? colorScheme.primary
                            : colorScheme.surfaceContainerHighest,
                      ),
                    );
                  }),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

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
              child:
                  Text('Scan Partner QR Code', style: theme.textTheme.titleLarge),
            ),
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
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