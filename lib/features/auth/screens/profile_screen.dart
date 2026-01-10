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
import 'package:feelings/services/review_service.dart';
import 'package:feelings/services/encryption_service.dart';
import 'package:feelings/features/encryption/widgets/encryption_setup_dialog.dart';

import 'change_password_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // --- STATE VARIABLES ---
  final TextEditingController _nameController = TextEditingController();
  late FocusNode _nameFocusNode; // ✨ [ADDED]
  bool _isLoading = false;
  bool _isUploadingImage = false;
  bool _notificationsEnabled = true;
  String? _email;
  AppThemeType _selectedTheme = AppThemeType.defaultLight;
  String? _currentMood;
  String? _selectedLoveLanguage;
  Gender? _selectedGender;

  @override
  void initState() {
    super.initState();
    _nameFocusNode = FocusNode(); // ✨ [ADDED]
    _nameFocusNode.addListener(_onNameFocusChange); // ✨ [ADDED]
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadUserData();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _nameFocusNode.dispose(); // ✨ [ADDED]
    super.dispose();
  }
  
  // ✨ [ADDED] Capture blur event
  void _onNameFocusChange() {
    if (!_nameFocusNode.hasFocus) {
      _updateName();
    }
  }

  // ✨ [ADDED] Specific update for name
  void _updateName() {
    final newName = _nameController.text.trim();
    if (newName.isNotEmpty) {
      _updateUserData({'name': newName});
    }
  }

  // ✨ [ADDED] Generic Auto-Save Helper
  Future<void> _updateUserData(Map<String, dynamic> updates) async {
    if (!mounted) return;
    final userProvider = Provider.of<UserProvider>(context, listen: false);

    try {
      // Optimistic local update (Provider handles this too, but we update local state for UI consistency if needed)
      // Actually, relying on Provider notifyListeners is best.
      
      await userProvider.updateUserData(updates);
      
      // Optional: Add a subtle indicator or just remain silent.
      // debugPrint("✅ Auto-saved: $updates"); 

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save changes: $e')),
        );
      }
    }
  }

  // --- LOGIC & DATA HANDLING METHODS ---

  void _loadUserData() {
    if (!mounted) return;
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);

    if (userProvider.userData != null) {
      final userData = userProvider.userData!;
      _nameController.text = userData['name'] ?? '';
      _email = userData['email'] ?? FirebaseAuth.instance.currentUser?.email;
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
    // ... (Keep existing implementation)
     debugPrint("--- 1. Starting Image Pick and Upload ---");

    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final user = userProvider.userData;
    if (user == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Cannot upload: User not found.")));
      return;
    }

    final pickedFile = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );

    if (pickedFile == null) return;

    setState(() => _isUploadingImage = true);

    try {
      Uint8List imageBytes;
      if (kIsWeb) {
        imageBytes = await pickedFile.readAsBytes();
      } else {
        final cropped = await cropImage(pickedFile.path, context);
        if (cropped == null) {
          if (mounted) setState(() => _isUploadingImage = false);
          return;
        }
        imageBytes = await cropped.readAsBytes();
      }

      final cloudinaryHelper = CloudinaryHelper();
      final String fixedPublicId = 'profile_${user['userId']}';

      final String? newImageUrl = await cloudinaryHelper.uploadImageBytes(
        imageBytes,
        publicId: fixedPublicId,
        folder: 'profileImages',
      );

      if (newImageUrl == null) {
        throw Exception("Failed to upload image.");
      }

      await userProvider.updateUserData({'profileImageUrl': newImageUrl});
      await userProvider.updateProfileImage(newImageUrl);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Profile picture updated!'),
          backgroundColor: Colors.green,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Error updating picture: $e")));
      }
    } finally {
      if (mounted) {
        setState(() => _isUploadingImage = false);
      }
    }
  }

  // ✨ [_saveProfile REMOVED] - Replaced by auto-save

  Future<void> _updateLocation() async {
    // ... (Keep existing implementation)
    if (!mounted) return;
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    setState(() => _isLoading = true);

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Location services are disabled.')));
        }
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }

      if (permission == LocationPermission.deniedForever) return;

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

    await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _DeleteAccountConfirmationDialog(
        userProvider: userProvider,
      ),
    );
  }

  // ✨ THEME SELECTOR (FROM PREVIOUS STEP)
  void _showThemeSelector() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (bottomSheetContext) {
        return Consumer<ThemeProvider>(
          builder: (context, themeProvider, child) {
            final theme = Theme.of(context);
            return Container(
              color: theme.scaffoldBackgroundColor,
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: Text(
                      'Select Theme',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onBackground,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Flexible(
                    child: ListView(
                      shrinkWrap: true,
                      children: AppThemeType.values.map((themeType) {
                        final isSelected = themeProvider.currentThemeType == themeType;
                        return RadioListTile<AppThemeType>(
                          title: Text(
                            _formatThemeName(themeType),
                            style: theme.textTheme.bodyLarge?.copyWith(
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                          activeColor: theme.colorScheme.primary,
                          value: themeType,
                          groupValue: themeProvider.currentThemeType,
                          onChanged: (newTheme) async {
                            if (newTheme != null) {
                              themeProvider.setTheme(newTheme);
                              setState(() {
                                _selectedTheme = newTheme;
                              });
                            }
                          },
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 48),
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: theme.colorScheme.onPrimary,
                    ),
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
  }

  // ✨ GENDER SELECTOR (FROM PREVIOUS STEP)
  void _showGenderSelector() {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
               Padding(
                padding: const EdgeInsets.only(left: 8.0, bottom: 16),
                child: Text(
                  'Select Gender',
                  style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              ...Gender.values.asMap().entries.map((entry) {
                final index = entry.key;
                final gender = entry.value;
                final isSelected = _selectedGender == gender;
                
                // Add animation to gender items too
                return _StaggeredItem(
                  index: index,
                  child: ListTile(
                    leading: Icon(
                      isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                      color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
                    ),
                    title: Text(
                      _getGenderDisplayName(gender),
                      style: TextStyle(
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface,
                      ),
                    ),
                    onTap: () {
                      setState(() => _selectedGender = gender);
                      _updateUserData({'gender': gender.name}); // ✨ AUTO-SAVE
                      Navigator.pop(context);
                    },
                  ),
                );
              }).toList(),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  // ✨✨ --- ANIMATED MOOD SELECTOR (GRID) --- ✨✨
  void _showMoodSelectorDialog() {
    final theme = Theme.of(context);
    final Map<String, String> moods = const {
      'Happy': '😄', 'Excited': '😆', 'Loved': '🥰', 'Grateful': '🙏',
      'Peaceful': '😌', 'Content': '😊', 'Sad': '😢', 'Stressed': '😰',
      'Lonely': '😔', 'Angry': '😡', 'Anxious': '😨', 'Confused': '😕',
    };

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.70,
          minChildSize: 0.5,
          maxChildSize: 0.8,
          expand: false,
          builder: (context, scrollController) {
            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: theme.dividerColor,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'How are you feeling?',
                    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: GridView.builder(
                      controller: scrollController,
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 1.0,
                      ),
                      itemCount: moods.length,
                      itemBuilder: (context, index) {
                        final entry = moods.entries.elementAt(index);
                        final isSelected = _currentMood == entry.key;

                        return _StaggeredItem(
                          index: index,
                          child: Material(
                            // ✨ CHANGED: Always keep the neutral background
                            color: theme.colorScheme.surfaceContainerHighest,
                            // ✨ CHANGED: Add border only when selected
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: isSelected
                                  ? BorderSide(color: theme.colorScheme.primary, width: 2.5)
                                  : BorderSide.none,
                            ),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () {
                                setState(() => _currentMood = entry.key);
                                context.read<UserProvider>().updateUserMood(entry.key);
                                Navigator.of(context).pop();
                              },
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    entry.value,
                                    style: const TextStyle(fontSize: 36),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    entry.key,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                      // Optional: You can keep the text red or make it black. 
                                      // Keeping it red usually looks better with the red border.
                                      color: isSelected 
                                        ? theme.colorScheme.primary 
                                        : theme.colorScheme.onSurface,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }



  // ✨✨ --- ANIMATED LOVE LANGUAGE SELECTOR (CARDS) --- ✨✨
  void _showLoveLanguageSelectorDialog() {
    final theme = Theme.of(context);
    final loveLanguages = {
      'Words of Affirmation': 'Verbal compliments and words of encouragement.',
      'Acts of Service': 'Actions that ease the burden of responsibilities.',
      'Receiving Gifts': 'Visual symbols of love and thoughtfulness.',
      'Quality Time': 'Giving undivided attention and presence.',
      'Physical Touch': 'Hugs, holding hands, and affection.',
    };

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          // ✨ CHANGED: Increased from 0.6 to 0.75 to show all items
          initialChildSize: 0.70,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: theme.dividerColor,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: Text(
                      'What\'s Your Love Language?',
                      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      itemCount: loveLanguages.length,
                      itemBuilder: (context, index) {
                        final entry = loveLanguages.entries.elementAt(index);
                        final isSelected = _selectedLoveLanguage == entry.key;

                        return _StaggeredItem(
                          index: index,
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              // Slight background tint when selected, but mostly relies on border/icon
                              color: isSelected 
                                ? theme.colorScheme.primaryContainer.withOpacity(0.1) 
                                : theme.colorScheme.surface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected 
                                  ? theme.colorScheme.primary 
                                  : theme.dividerColor.withOpacity(0.5),
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () {
                                setState(() => _selectedLoveLanguage = entry.key);
                                _updateUserData({'loveLanguage': entry.key}); // ✨ AUTO-SAVE
                                Navigator.of(context).pop();
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            entry.key,
                                            style: theme.textTheme.titleMedium?.copyWith(
                                              fontWeight: FontWeight.bold,
                                              color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            entry.value,
                                            style: theme.textTheme.bodySmall?.copyWith(
                                              color: theme.colorScheme.onSurfaceVariant,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (isSelected)
                                      Icon(Icons.check_circle, color: theme.colorScheme.primary),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }


  // ... (Existing Helper Methods)
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
    // ... (Existing Logic)
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

  void _showLogoutConfirmationDialog() {
    // ... (Existing Logic)
    final mainContext = context;

    showDialog(
      context: context,
      builder: (dialogContext) {
        bool isLoggingOut = false;
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Log Out'),
              content: const Text('Are you sure you want to log out?'),
              actions: [
                TextButton(
                  onPressed: isLoggingOut ? null : () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isLoggingOut
                      ? null
                      : () { 
                          setState(() => isLoggingOut = true);
                          Navigator.of(dialogContext).pop();
                          
                          mainContext.read<AuthService>().logout().catchError((e) {
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

  String _getGenderDisplayName(Gender gender) {
    switch (gender) {
      case Gender.male: return 'Male';
      case Gender.female: return 'Female';
      case Gender.other: return 'Other';
      case Gender.preferNotToSay: return 'Prefer Not To Say';
    }
  }

  String _formatThemeName(AppThemeType theme) {
    if (theme.name.isEmpty) return '';
    String spacedName = theme.name.replaceAllMapped(
      RegExp(r'(?<=[a-z])(?=[A-Z])'),
      (Match m) => ' ${m.group(0)}',
    );
    return spacedName[0].toUpperCase() + spacedName.substring(1);
  }

  Widget _buildModernTile({
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
    Color? iconColor,
    bool isDestructive = false,
  }) {
    final theme = Theme.of(context);
    final color = isDestructive ? theme.colorScheme.error : (iconColor ?? theme.colorScheme.primary);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: theme.colorScheme.outlineVariant.withOpacity(0.5)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
            child: ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              title: Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: isDestructive ? color : theme.colorScheme.onSurface,
                ),
              ),
              subtitle: subtitle != null
                  ? Text(subtitle, style: theme.textTheme.bodySmall)
                  : null,
              trailing: trailing ?? (onTap != null 
                  ? Icon(Icons.chevron_right_rounded, color: theme.colorScheme.onSurfaceVariant) 
                  : null),
            ),
          ),
        ),
      ),
    );
  }

  // --- BUILD METHOD ---
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final showLoadingIndicator = _isLoading || _isUploadingImage;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        centerTitle: true,
        backgroundColor: Colors.transparent, // ✨ Modern look
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Log Out',
            onPressed: _showLogoutConfirmationDialog,
          ),
        ],
      ),
      body: showLoadingIndicator
          ? const Center(child: PulsingDotsIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 20),
                  ProfileAvatar(
                    onPickImage: _pickAndUploadImage,
                  ),
                  const SizedBox(height: 24),
                  BasicInfoSection(
                    nameController: _nameController,
                    nameFocusNode: _nameFocusNode,
                    onNameSubmitted: (_) => _updateName(),
                    email: _email,
                    currentMood: _currentMood,
                    selectedLoveLanguage: _selectedLoveLanguage,
                    selectedGender: _selectedGender,
                    onSelectMood: _showMoodSelectorDialog,
                    onSelectLoveLanguage: _showLoveLanguageSelectorDialog,
                    onSelectGender: _showGenderSelector,
                    getGenderDisplayName: _getGenderDisplayName,
                  ),

                  PartnerConnectionSection(
                     onDisconnect: _handleDisconnect,
                  ),

                  // ✨ SETTINGS SECTION (With Auto-Save Notifications)
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
                      Column(
                        children: [
                          _buildModernTile(
                            icon: Icons.notifications_outlined,
                            title: 'Enable Notifications',
                            trailing: Switch(
                              value: _notificationsEnabled,
                              onChanged: (value) {
                                setState(() => _notificationsEnabled = value);
                                _updateUserData({'notificationsEnabled': value}); // ✨ AUTO-SAVE
                              },
                            ),
                          ),
                             // ✨ E2EE SETTINGS TILE
                             Consumer<UserProvider>(
                              builder: (context, provider, child) {
                                final status = provider.currentUser?.encryptionStatus ?? 'pending';
                                
                                String statusText = 'Pending';
                                Color statusColor = Colors.orange;
                                
                                if (status == 'enabled') {
                                  if (EncryptionService.instance.isReady) {
                                    statusText = 'Secure';
                                    statusColor = Colors.green;
                                  } else {
                                    statusText = 'Key Missing';
                                    statusColor = Colors.red;
                                  }
                                } else if (status == 'disabled') {
                                  statusText = 'Disabled';
                                  statusColor = Colors.grey;
                                }

                              return _buildModernTile(
                                icon: Icons.lock_outline,
                                title: 'End-to-End Encryption',
                                subtitle: statusText,
                                iconColor: statusColor,
                                onTap: () {
                                    showDialog(
                                      context: context,
                                      builder: (context) => const EncryptionSetupDialog(),
                                    );
                                  },
                                );
                              },
                            ),

                          _buildModernTile(
                            icon: Icons.palette_outlined,
                            title: 'App Theme',
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
                                Icon(Icons.chevron_right_rounded, color: theme.colorScheme.onSurfaceVariant),
                              ],
                            ),
                            onTap: _showThemeSelector,
                          ),
                          _buildModernTile(
                            icon: Icons.star_rounded,
                            title: 'Rate Feelings',
                            subtitle: 'Love the app? Let us know!',
                            iconColor: Colors.amber,
                            onTap: () => ReviewService().openStoreListing(),
                          ),
                          ],
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

                  // ✨ [REMOVED] Save Button
                  // ElevatedButton(
                  //   style: ElevatedButton.styleFrom(
                  //       minimumSize: const Size(double.infinity, 54)),
                  //   onPressed: _saveProfile,
                  //   child: const Text('Save Changes'),
                  // ),

                  const SizedBox(height: 16),
                ],
              ),
            ),
    );
  }
}

// ... (Keep _DisconnectConfirmationDialog and _DeleteAccountConfirmationDialog classes here, unchanged)

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

    final maxDialogHeight = (media.size.height - media.viewInsets.bottom) * 0.72;

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
  final UserProvider userProvider;
  const _DeleteAccountConfirmationDialog({required this.userProvider});

  @override
  State<_DeleteAccountConfirmationDialog> createState() =>
      _DeleteAccountConfirmationDialogState();
}

class _DeleteAccountConfirmationDialogState
    extends State<_DeleteAccountConfirmationDialog> {
  final _passwordController = TextEditingController();
  String? _errorMessage;
  bool _isLoading = false;

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

    final dialogNavigator = Navigator.of(context);

    try {
      await widget.userProvider
          .deleteCurrentUserAccount(_passwordController.text.trim());
      
      if (dialogNavigator.canPop()) {
        dialogNavigator.pop(true);
      }
      
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final media = MediaQuery.of(context);
    final maxDialogHeight = (media.size.height - media.viewInsets.bottom) * 0.72;

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

// ✨✨ --- NEW ANIMATION HELPER CLASS --- ✨✨
class _StaggeredItem extends StatefulWidget {
  final int index;
  final Widget child;
  final Duration duration;
  final double offset;

  const _StaggeredItem({
    required this.index,
    required this.child,
    this.duration = const Duration(milliseconds: 400),
    this.offset = 50.0,
  });

  @override
  State<_StaggeredItem> createState() => _StaggeredItemState();
}

class _StaggeredItemState extends State<_StaggeredItem> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    
    _fadeAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slideAnimation = Tween<Offset>(
      begin: Offset(0, 0.5), // Start slightly below
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    // Stagger effect: Delay start based on index
    Future.delayed(Duration(milliseconds: widget.index * 50), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: widget.child,
      ),
    );
  }
}