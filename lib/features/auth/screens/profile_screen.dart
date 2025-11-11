// lib/features/auth/screens/profile_screen.dart

import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:feelings/features/auth/models/user_model.dart';
import 'package:feelings/features/auth/services/auth_service.dart';
import 'package:feelings/features/auth/services/cloudinary_helper.dart';
import 'package:feelings/features/auth/services/image_cropper_helper.dart';
import 'package:feelings/features/auth/widgets/account_actions_section.dart';
import 'package:feelings/features/auth/widgets/basic_info_section.dart';
import 'package:feelings/features/auth/widgets/partner_connection_section.dart';
import 'package:feelings/features/auth/widgets/profile_avatar.dart';
import 'package:feelings/features/auth/widgets/support_section.dart';
import 'package:feelings/providers/couple_provider.dart';
import 'package:feelings/providers/theme_provider.dart';
import 'package:feelings/providers/user_provider.dart';
import 'package:feelings/theme/app_theme.dart';
import 'package:feelings/widgets/pulsing_dots_indicator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:feelings/providers/user_provider.dart';
import 'package:feelings/providers/couple_provider.dart';
import 'package:feelings/providers/dynamic_actions_provider.dart';
import 'package:feelings/providers/chat_provider.dart';
import 'package:feelings/providers/journal_provider.dart';
import 'package:feelings/providers/calendar_provider.dart';
import 'package:feelings/providers/question_provider.dart';
import 'package:feelings/providers/done_dates_provider.dart';
import 'package:feelings/providers/bucket_list_provider.dart';
import 'package:feelings/providers/media_provider.dart';
import 'package:feelings/providers/tips_provider.dart';
import 'package:feelings/providers/date_idea_provider.dart';
import 'package:feelings/providers/check_in_provider.dart';
import 'package:feelings/providers/rhm_detail_provider.dart';

import 'change_password_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // --- STATE VARIABLES ---
  final TextEditingController _nameController = TextEditingController();
  bool _isLoading = false;
  bool _isUploadingImage = false;
  bool _notificationsEnabled = true;
  AppThemeType _selectedTheme = AppThemeType.defaultLight;
  String? _currentMood;
  String? _selectedLoveLanguage;
  Gender? _selectedGender;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadUserData();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  // --- LOGIC & DATA HANDLING METHODS ---

  void _loadUserData() {
    if (!mounted) return;
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);

    if (userProvider.userData != null) {
      final userData = userProvider.userData!;
      _nameController.text = userData['name'] ?? '';
      _notificationsEnabled = userData['notificationsEnabled'] ?? true;
      _currentMood = userData['mood'];
      _selectedLoveLanguage = userData['loveLanguage'];
      if (userData['gender'] != null &&
          (userData['gender'] as String).isNotEmpty) {
        try {
          _selectedGender = Gender.values.byName(userData['gender']);
        } catch (_) {
          _selectedGender = null;
        }
      } else {
        _selectedGender = null;
      }
    }

    SharedPreferences.getInstance().then((prefs) {
      final themeName = prefs.getString('app_theme') ?? 'light';
      if (mounted) {
        setState(() {
          _selectedTheme = AppThemeType.values.firstWhere(
            (e) => e.name == themeName,
            orElse: () => AppThemeType.defaultLight,
          );
        });
      }
      themeProvider.setTheme(_selectedTheme);
    });
  }

  Future<void> _pickAndUploadImage() async {
    debugPrint("--- 1. Starting Image Pick and Upload ---");

    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final user = userProvider.userData;
    if (user == null) {
      debugPrint("--- ERROR: User data is null. Aborting. ---");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Cannot upload: User not found.")));
      return;
    }

    final pickedFile = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );

    if (pickedFile == null) {
      debugPrint("--- 2. Image picking was cancelled by the user. ---");
      return;
    }
    debugPrint("--- 2. Image successfully picked: ${pickedFile.path} ---");

    setState(() => _isUploadingImage = true);

    try {
      Uint8List imageBytes;
      if (kIsWeb) {
        debugPrint("--- 3. Running on WEB. Reading bytes directly. ---");
        imageBytes = await pickedFile.readAsBytes();
      } else {
        debugPrint("--- 3. Running on MOBILE. Opening cropper... ---");
        final cropped = await cropImage(pickedFile.path, context);
        if (cropped == null) {
          debugPrint("--- 4. Cropping was cancelled by the user. ---");
          if (mounted) setState(() => _isUploadingImage = false);
          return;
        }
        debugPrint("--- 4. Image successfully cropped: ${cropped.path} ---");
        imageBytes = await cropped.readAsBytes();
      }

      debugPrint(
          "--- 5. Preparing to upload ${imageBytes.length} bytes to Cloudinary. ---");
      final cloudinaryHelper = CloudinaryHelper();
      final String fixedPublicId = 'profile_${user['userId']}';

      final String? newImageUrl = await cloudinaryHelper.uploadImageBytes(
        imageBytes,
        publicId: fixedPublicId,
        folder: 'profileImages',
      );

      if (newImageUrl == null) {
        debugPrint("--- 6. ERROR: Cloudinary returned a null URL. ---");
        throw Exception(
            "Failed to upload image. Cloudinary did not return a URL.");
      }
      debugPrint("--- 6. SUCCESS: Cloudinary returned URL: $newImageUrl ---");

      debugPrint("--- 7. Updating user data in Firestore... ---");
      await userProvider.updateUserData({'profileImageUrl': newImageUrl});

      debugPrint(
          "--- 8. Fetching latest user data (this will auto-update the cache)... ---");
      await userProvider.updateProfileImage(newImageUrl);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Profile picture updated!'),
          backgroundColor: Colors.green,
        ));
      }
      debugPrint("--- 9. Process complete. ---");
    } catch (e) {
      debugPrint("--- !!! CAUGHT AN ERROR: $e !!! ---");
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Error updating picture: $e")));
      }
    } finally {
      debugPrint(
          "--- 10. 'Finally' block reached. Hiding loading indicator. ---");
      if (mounted) {
        setState(() => _isUploadingImage = false);
      }
    }
  }

  Future<void> _saveProfile() async {
    if (!mounted) return;
    final userProvider = Provider.of<UserProvider>(context, listen: false);

    setState(() => _isLoading = true);
    try {
      final updateData = {
        'name': _nameController.text.trim(),
        'notificationsEnabled': _notificationsEnabled,
        'lastUpdated': FieldValue.serverTimestamp(),
        'mood': _currentMood,
        'loveLanguage': _selectedLoveLanguage,
        'gender': _selectedGender?.name,
      };

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('app_theme', _selectedTheme.name);

      await userProvider.updateUserData(updateData);
      await userProvider.fetchUserData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile updated successfully!')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error saving profile: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _updateLocation() async {
    if (!mounted) return;
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    setState(() => _isLoading = true);

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          await showDialog(
            context: context,
            builder: (BuildContext context) => AlertDialog(
              title: const Text('Location Services Disabled'),
              content: const Text(
                  'Please enable location services to update your location.'),
              actions: <Widget>[
                TextButton(
                  child: const Text('Cancel'),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                TextButton(
                  child: const Text('Open Settings'),
                  onPressed: () {
                    Geolocator.openLocationSettings();
                    Navigator.of(context).pop();
                  },
                ),
              ],
            ),
          );
        }
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text(
                    'Location permission is required to update your location.')));
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          await showDialog(
            context: context,
            builder: (BuildContext context) => AlertDialog(
              title: const Text('Location Permission Required'),
              content: const Text(
                  'Location permission is permanently denied. Please enable it from the app settings.'),
              actions: <Widget>[
                TextButton(
                  child: const Text('Cancel'),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                TextButton(
                  child: const Text('Open Settings'),
                  onPressed: () {
                    Geolocator.openAppSettings();
                    Navigator.of(context).pop();
                  },
                ),
              ],
            ),
          );
        }
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      await userProvider.updateUserLocation(
          position.latitude, position.longitude);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Location updated successfully!")));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("An error occurred: ${e.toString()}")));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ✨ --- MODIFIED: ACCOUNT DELETION FIX --- ✨
  void _handleDeleteAccount() async {
    if (!mounted) return;
    final userProvider = Provider.of<UserProvider>(context, listen: false);

    if (userProvider.coupleId != null) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Still Connected'),
          content: const Text(
              'Please disconnect from your partner before deleting your account.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context), child: const Text('OK')),
          ],
        ),
      );
      return;
    }

    // 1. Await the result from the dialog
    final didConfirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _DeleteAccountConfirmationDialog(
        userProvider: userProvider,
      ),
    );

    // 2. Check if the dialog confirmed success (data is deleted)
    if (didConfirm == true) {
      // --- THIS IS THE FIX ---
      // DO NOTHING.
      // The Cloud Function deleted the user.
      // The AuthWrapper detected this auth state change,
      // triggered the provider cleanup,
      // and is already navigating to the LoginScreen.
      // This function's job is done.
    }
  }



  void _showThemeSelector() {
    final theme = Theme.of(context);
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (bottomSheetContext) {
        return FutureBuilder<SharedPreferences>(
          future: SharedPreferences.getInstance(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const SizedBox(
                height: 200,
                child: Center(child: CircularProgressIndicator()),
              );
            }

            final prefs = snapshot.data!;
            final themeName = prefs.getString('app_theme') ?? 'light';
            AppThemeType currentTheme = AppThemeType.values.firstWhere(
              (e) => e.name == themeName,
              orElse: () => AppThemeType.defaultLight,
            );

            return StatefulBuilder(
              builder: (BuildContext context, StateSetter modalSetState) {
                return Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: Text(
                          'Select Theme',
                          style: theme.textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Flexible(
                        child: ListView(
                          shrinkWrap: true,
                          children: AppThemeType.values.map((themeType) {
                            return RadioListTile<AppThemeType>(
                              title: Text(_formatThemeName(themeType)),
                              value: themeType,
                              groupValue: currentTheme,
                              onChanged: (newTheme) async {
                                if (newTheme != null) {
                                  themeProvider.setTheme(newTheme);
                                  modalSetState(() {
                                    currentTheme = newTheme;
                                  });
                                  // Update the main profile screen state as well
                                  setState(() {
                                    _selectedTheme = newTheme;
                                  });
                                  await prefs.setString(
                                      'app_theme', newTheme.name);
                                }
                              },
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 48)),
                        onPressed: () => Navigator.pop(bottomSheetContext),
                        child: const Text('Done'),
                      )
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Future<void> _launchURL(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      debugPrint("Could not launch $url");
    }
  }

  void _showCustomAboutDialog() async {
    final packageInfo = await PackageInfo.fromPlatform();
    final String version = packageInfo.version;
    final theme = Theme.of(context);

    showAboutDialog(
      context: context,
      applicationName: 'Feelings',
      applicationVersion: 'Version $version',
      applicationIcon: Padding(
        padding: const EdgeInsets.only(top: 24, bottom: 12),
        child: Image.asset('assets/icon/app_icon.png', width: 60),
      ),
      applicationLegalese: 'Made with ❤️ by Team Hazelnut',
      children: <Widget>[
        const SizedBox(height: 24),
        const Text(
          'Feelings is a private space for couples to connect on a deeper level. Share your moods, understand each other\'s love language, and strengthen your bond through a shared journey.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        const Divider(),
        ListTile(
          leading: Icon(Icons.policy, color: theme.colorScheme.primary),
          title: const Text('Privacy Policy'),
          onTap: () => _launchURL(
              'https://teamhazelnut.github.io/feelings-legal/privacy-policy.html'),
        ),
        ListTile(
          leading: Icon(Icons.description, color: theme.colorScheme.primary),
          title: const Text('Terms & Conditions'),
          onTap: () => _launchURL(
              'https://teamhazelnut.github.io/feelings-legal/terms-and-conditions.html'),
        ),
        ListTile(
          leading: Icon(Icons.email, color: theme.colorScheme.primary),
          title: const Text('Contact & Feedback'),
          onTap: () {
            _launchURL(
                'mailto:reach.feelings@gmail.com?subject=Feedback: Feelings App');
          },
        ),
      ],
    );
  }

  Future<void> _handleDisconnect() async {
    if (!mounted) return;

    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final coupleProvider = Provider.of<CoupleProvider>(context, listen: false);

    final String? currentUserId = userProvider.getUserId();
    final String? coupleId = userProvider.coupleId;
    final String senderName = userProvider.userData?['name'] ?? 'Your Partner';

    if (currentUserId == null || coupleId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Error: Could not find couple information.')));
      return;
    }

    final bool isFirst = await coupleProvider.isFirstToDisconnect(coupleId);

    final didConfirm = await showDialog<bool>(
      context: context,
      builder: (context) =>
          _DisconnectConfirmationDialog(isFirstToDisconnect: isFirst),
    );

    if (didConfirm != true) return;

    setState(() => _isLoading = true);

    try {
      await coupleProvider.disconnectFromPartner(
        currentUserId: currentUserId,
        coupleId: coupleId,
        senderName: senderName,
      );

      await userProvider.fetchUserData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('You have successfully disconnected.'),
          backgroundColor: Colors.green,
        ));
        Navigator.pushNamedAndRemoveUntil(
            context, '/bottom_nav', (route) => false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('An error occurred: ${e.toString()}')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // ✨ --- REMOVED: This function is no longer needed as logic is inlined --- ✨
  // Future<void> _performLogoutCleanup(BuildContext context) async { ... }

  // ✨ --- MODIFIED: LOGOUT FIX --- ✨
  // lib/features/auth/screens/profile_screen.dart

// In profile_screen.dart

void _showLogoutConfirmationDialog() {
    final theme = Theme.of(context);
    final mainContext = context;

    showDialog(
      context: context,
      builder: (dialogContext) {
        bool isLoggingOut = false;
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              // ... (your existing dialog setup)
              title: const Text('Log Out'),
              content: const Text('Are you sure you want to log out?'),
              actions: [
                TextButton(
                  onPressed: isLoggingOut ? null : () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  // ... (style)
                  onPressed: isLoggingOut
                      ? null
                      : () { // 1. REMOVE 'async'
                          setState(() => isLoggingOut = true);
                          Navigator.of(dialogContext).pop();
                          
                          // 2. DO NOT AWAIT. Just call the function.
                          //    The AuthWrapper will handle the navigation.
                          mainContext.read<AuthService>().logout().catchError((e) {
                            // 3. Add a catchError in case the logout() itself fails
                            //    before the signOut() call.
                            if (mainContext.mounted) {
                              ScaffoldMessenger.of(mainContext).showSnackBar(
                                SnackBar(
                                  content: Text('Logout failed: $e'),
                                  backgroundColor: Theme.of(mainContext).colorScheme.error,
                                ),
                              );
                            }
                          });
                        },
                  child: isLoggingOut
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Log Out'),
                ),
              ],
            );
          },
        );
      },
    );
  }



  void _showChangePasswordDialog() {
    Navigator.push(context,
        MaterialPageRoute(builder: (context) => const ChangePasswordScreen()));
  }

  void _showDeleteAccountDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Delete Account'),
        content: const Text(
            'Are you sure you want to delete your account? This action cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showMoodSelectorDialog() {
    final Map<String, String> moods = const {
      'Happy': '😄', 'Excited': '😆', 'Loved': '🥰', 'Grateful': '🙏',
      'Peaceful': '😌', 'Content': '😊', 'Sad': '😢', 'Stressed': '😰',
      'Lonely': '😔', 'Angry': '😡', 'Anxious': '😨', 'Confused': '😕',
    };

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('How are you feeling?'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView(
              shrinkWrap: true,
              children: moods.entries.map((entry) {
                return ListTile(
                  leading:
                      Text(entry.value, style: const TextStyle(fontSize: 24)),
                  title: Text(entry.key),
                  onTap: () {
                    setState(() => _currentMood = entry.key);
                    context.read<UserProvider>().updateUserMood(entry.key);
                    Navigator.of(context).pop();
                  },
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }

  void _showLoveLanguageSelectorDialog() {
    final loveLanguages = {
      'Words of Affirmation': 'Verbal compliments and words of encouragement.',
      'Acts of Service': 'Actions that ease the burden of responsibilities.',
      'Receiving Gifts': 'Visual symbols of love and thoughtfulness.',
      'Quality Time': 'Giving undivided attention and presence.',
      'Physical Touch': 'Hugs, holding hands, and affection.',
    };
    showDialog(
        context: context,
        builder: (context) => AlertDialog(
              title: const Text('What\'s Your Love Language?'),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView(
                  shrinkWrap: true,
                  children: loveLanguages.entries
                      .map((entry) => ListTile(
                            title: Text(entry.key),
                            subtitle: Text(entry.value,
                                style: Theme.of(context).textTheme.bodySmall),
                            onTap: () {
                              setState(() => _selectedLoveLanguage = entry.key);
                              Navigator.of(context).pop();
                            },
                          ))
                      .toList(),
                ),
              ),
            ));
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

  // ✨ --- NEW HELPER FUNCTION TO FORMAT THEME NAMES --- ✨
  String _formatThemeName(AppThemeType theme) {
    if (theme.name.isEmpty) return '';
    // Handles cases like 'defaultLight' -> 'default Light'
    String spacedName = theme.name.replaceAllMapped(
      RegExp(r'(?<=[a-z])(?=[A-Z])'),
      (Match m) => ' ${m.group(0)}',
    );
    // Capitalizes the first letter -> 'Default Light'
    return spacedName[0].toUpperCase() + spacedName.substring(1);
  }

  // --- BUILD METHOD ---
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final showLoadingIndicator = _isLoading || _isUploadingImage;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Log Out',
            onPressed: _showLogoutConfirmationDialog,
          ),
        ],
      ),
      body: showLoadingIndicator
          ? Center(
              child: PulsingDotsIndicator(
                size: 80,
                colors: [
                  theme.colorScheme.primary,
                  theme.colorScheme.primary,
                  theme.colorScheme.primary,
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ProfileAvatar(onPickImage: _pickAndUploadImage),
                  BasicInfoSection(
                    nameController: _nameController,
                    currentMood: _currentMood,
                    selectedLoveLanguage: _selectedLoveLanguage,
                    selectedGender: _selectedGender,
                    onSelectMood: _showMoodSelectorDialog,
                    onSelectLoveLanguage: _showLoveLanguageSelectorDialog,
                    onGenderChanged: (gender) =>
                        setState(() => _selectedGender = gender),
                    getGenderDisplayName: _getGenderDisplayName,
                  ),

                  PartnerConnectionSection(onDisconnect: _handleDisconnect),

                  // ✨ --- PASSING THE NEW FORMATTER FUNCTION --- ✨
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 24),
                      Text(
                        'App Settings',
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Card(
                        margin: EdgeInsets.zero,
                        child: Column(
                          children: [
                            SwitchListTile(
                              title: const Text('Enable Notifications'),
                              value: _notificationsEnabled,
                              onChanged: (value) =>
                                  setState(() => _notificationsEnabled = value),
                              secondary:
                                  const Icon(Icons.notifications_outlined),
                            ),
                            const Divider(height: 1, indent: 16, endIndent: 16),
                            ListTile(
                              leading: const Icon(Icons.palette_outlined),
                              title: const Text('App Theme'),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    _formatThemeName(_selectedTheme),
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Icon(Icons.chevron_right),
                                ],
                              ),
                              onTap: _showThemeSelector,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  AccountActionsSection(
                    onUpdateLocation: _updateLocation,
                    onChangePassword: _showChangePasswordDialog,
                    onDeleteAccount: _handleDeleteAccount,
                    onShowAbout: _showCustomAboutDialog,
                  ),

                  const SupportSection(),

                  const SizedBox(height: 24),

                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 54)),
                    onPressed: _saveProfile,
                    child: const Text('Save Changes'),
                  ),

                  const SizedBox(height: 16),
                ],
              ),
            ),
    );
  }
}

// ... (rest of the file with dialog widgets remains the same) ...

class _DisconnectConfirmationDialog extends StatefulWidget {
  final bool isFirstToDisconnect;
  const _DisconnectConfirmationDialog({required this.isFirstToDisconnect});

  @override
  State<_DisconnectConfirmationDialog> createState() =>
      _DisconnectConfirmationDialogState();
}

class _DisconnectConfirmationDialogState
    extends State<_DisconnectConfirmationDialog> {
  final _passwordController = TextEditingController();
  String? _errorMessage;
  bool _isLoading = false;

  Future<void> _reauthenticateAndProceed() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.email == null) {
      setState(() => _errorMessage = "Could not find user information.");
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final cred = EmailAuthProvider.credential(
        email: user.email!,
        password: _passwordController.text.trim(),
      );
      await user.reauthenticateWithCredential(cred);

      if (mounted) Navigator.pop(context, true);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        setState(() => _errorMessage = 'Incorrect password. Please try again.');
      } else {
        setState(
            () => _errorMessage = 'An error occurred. Please try again later.');
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
  final media = MediaQuery.of(context);

  final titleText = widget.isFirstToDisconnect
      ? 'Disconnect from Partner?'
      : 'Delete Shared Journey?';

  final contentText = widget.isFirstToDisconnect
      ? 'You will lose access to this shared journey immediately. Your partner will retain access until they also disconnect.'
      : 'You are the last person in this relationship. This will permanently delete all shared data. This action cannot be undone.';

  // Allow up to 70–75% of usable height; remaining space keeps it comfortable
  final maxDialogHeight = (media.size.height - media.viewInsets.bottom) * 0.72;

  // ✨ --- FIX: REMOVED AnimatedPadding WRAPPER --- ✨
  return AlertDialog(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
    scrollable: true,
    title: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.warning_amber_rounded, color: theme.colorScheme.error),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            titleText,
            softWrap: true,
            maxLines: 3,
            overflow: TextOverflow.visible,
            textAlign: TextAlign.start,
          ),
        ),
      ],
    ),
    content: ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: maxDialogHeight,
        minWidth: 280,
      ),
      child: Scrollbar(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(contentText),
              const SizedBox(height: 20),
              Text(
                'For your security, please confirm your password to continue.',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _passwordController,
                obscureText: true,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) {
                  if (!_isLoading) _reauthenticateAndProceed();
                },
                decoration: InputDecoration(
                  labelText: 'Password',
                  errorText: _errorMessage,
                ),
                onChanged: (_) {
                  if (_errorMessage != null) {
                    setState(() => _errorMessage = null);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    ),
    actionsOverflowDirection: VerticalDirection.down,
    actionsOverflowAlignment: OverflowBarAlignment.end,
    actionsOverflowButtonSpacing: 8,
    actionsPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
    actions: [
      TextButton(
        onPressed: _isLoading ? null : () => Navigator.pop(context, false),
        child: const Text('Cancel'),
      ),
      ElevatedButton(
        onPressed: _isLoading ? null : _reauthenticateAndProceed,
        style: ElevatedButton.styleFrom(
          backgroundColor: theme.colorScheme.error,
          foregroundColor: theme.colorScheme.onError,
        ),
        child: _isLoading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Text(widget.isFirstToDisconnect ? 'Disconnect' : 'Delete Forever'),
      ),
    ],
  );
}


}

class _DeleteAccountConfirmationDialog extends StatefulWidget {
  // Add this
  final UserProvider userProvider;

  const _DeleteAccountConfirmationDialog({
    // Add this
    required this.userProvider,
  });

  @override
  State<_DeleteAccountConfirmationDialog> createState() =>
      _DeleteAccountConfirmationDialogState();
}

class _DeleteAccountConfirmationDialogState
    extends State<_DeleteAccountConfirmationDialog> {
  final _passwordController = TextEditingController();
  String? _errorMessage;
  bool _isLoading = false;

// lib/features/auth/screens/profile_screen.dart
// Inside _DeleteAccountConfirmationDialogState

  Future<void> _reauthenticateAndProceedWithDeletion() async {
    if (!mounted) return;

    if (_passwordController.text.trim().isEmpty) {
      setState(() => _errorMessage = "Password is required.");
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    // ✨ --- THIS IS THE FIX --- ✨
    // 1. Get the navigator for the DIALOG.
    final dialogNavigator = Navigator.of(context);

    try {
      // 2. Call the delete function
      await widget.userProvider
          .deleteCurrentUserAccount(_passwordController.text.trim());
      
      // 3. If successful, pop the dialog
      if (dialogNavigator.canPop()) {
        dialogNavigator.pop(true); // Pop with `true` on success.
      }
      
    } catch (e) {
      // 4. If it fails, *don't* pop. Just show the error.
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
    // No finally block, we only close the dialog on success.
  }


  @override
Widget build(BuildContext context) {
  final theme = Theme.of(context);
  final media = MediaQuery.of(context);
  final maxDialogHeight = (media.size.height - media.viewInsets.bottom) * 0.72;

  // ✨ --- FIX: REMOVED AnimatedPadding WRAPPER --- ✨
  return AlertDialog(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
    scrollable: true,
    title: Row(
      children: [
        Icon(Icons.warning_amber_rounded, color: theme.colorScheme.error),
        const SizedBox(width: 8),
        const Text('Delete Account?'),
      ],
    ),
    content: ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: maxDialogHeight,
        minWidth: 280,
      ),
      child: Scrollbar(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'This action is permanent and cannot be undone. All your personal data will be deleted.',
              ),
              const SizedBox(height: 20),
              Text(
                'To confirm, please enter your password.',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _passwordController,
                obscureText: true,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) {
                  if (!_isLoading) _reauthenticateAndProceedWithDeletion();
                },
                decoration: InputDecoration(
                  labelText: 'Password',
                  errorText: _errorMessage,
                ),
                onChanged: (_) {
                  if (_errorMessage != null) {
                    setState(() => _errorMessage = null);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    ),
    actionsOverflowDirection: VerticalDirection.down,
    actionsOverflowAlignment: OverflowBarAlignment.end,
    actionsOverflowButtonSpacing: 8,
    actionsPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
    actions: [
      TextButton(
        onPressed: _isLoading ? null : () => Navigator.pop(context, false),
        child: const Text('Cancel'),
      ),
      ElevatedButton(
        onPressed: _isLoading ? null : _reauthenticateAndProceedWithDeletion,
        style: ElevatedButton.styleFrom(
          backgroundColor: theme.colorScheme.error,
          foregroundColor: theme.colorScheme.onError,
        ),
        child: _isLoading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Text('Delete My Account'),
      ),
    ],
  );
}
}