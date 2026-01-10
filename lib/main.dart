import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:feelings/utils/crashlytics_helper.dart';
import 'dart:ui';
import 'package:flutter/foundation.dart';


// App's Providers
import 'package:feelings/providers/user_provider.dart';
import 'package:feelings/providers/app_status_provider.dart';
import 'package:feelings/providers/dynamic_actions_provider.dart';
import 'package:feelings/providers/chat_provider.dart';
import 'package:feelings/providers/couple_provider.dart';
import 'package:feelings/providers/journal_provider.dart';
import 'package:feelings/providers/calendar_provider.dart';
import 'package:feelings/providers/question_provider.dart';
import 'package:feelings/providers/done_dates_provider.dart';
import 'package:feelings/providers/bucket_list_provider.dart';
import 'package:feelings/providers/media_provider.dart';
import 'package:feelings/providers/tips_provider.dart';
import 'package:feelings/providers/date_idea_provider.dart';
import 'package:feelings/providers/check_in_provider.dart';
import 'package:feelings/providers/theme_provider.dart';
import 'package:feelings/providers/rhm_detail_provider.dart';
import 'package:feelings/providers/secret_note_provider.dart';
import 'package:feelings/features/chat/repositories/chat_repository.dart'; // Need this for SecretNoteProvider
import 'package:feelings/features/media/repository/media_repository.dart'; // Need this for SecretNoteProvider
import 'package:feelings/features/secret_note/repositories/secret_note_repository.dart';

// App's Screens
import 'package:feelings/features/auth/screens/login_screen.dart';
import 'package:feelings/features/auth/screens/register_screen.dart';
import 'package:feelings/features/home/screens/home_screen.dart';
import 'package:feelings/features/journal/screens/journal_screen.dart';
import 'package:feelings/features/chat/screens/chat_screen.dart';
import 'package:feelings/features/calendar/screens/calendar_screen.dart';
import 'package:feelings/features/auth/screens/profile_screen.dart';
import 'package:feelings/features/connectCouple/screens/connect_couple_screen.dart';
import 'package:feelings/features/discover/screens/discover_screen.dart';
import 'package:feelings/features/questions/screens/questions_screen.dart';
import 'package:feelings/features/home/screens/bottom_nav_bar.dart';
import 'package:feelings/features/onboarding/onboarding_screen.dart';

// Your App's Repositories & Services
import 'package:feelings/features/auth/services/user_repository.dart';
import 'package:feelings/features/auth/services/auth_service.dart';
import 'package:feelings/features/connectCouple/repository/couple_repository.dart';
import 'package:feelings/services/notification_services.dart';
import 'package:feelings/features/calendar/repository/calendar_repository.dart';
import 'package:feelings/features/rhm/repository/rhm_repository.dart';
import 'package:feelings/features/journal/repository/journal_repository.dart';
import 'package:feelings/features/check_in/repository/check_in_repository.dart';
import 'package:feelings/features/questions/repository/questions_repository.dart';
import 'package:feelings/widgets/rhm_points_animation_overlay.dart';
import 'package:feelings/utils/globals.dart';
import 'package:feelings/services/review_service.dart';
import 'package:feelings/services/review_service.dart';
import 'package:feelings/services/encryption_service.dart';
import 'package:feelings/features/encryption/widgets/encryption_setup_dialog.dart';
import 'package:feelings/features/app_config/services/app_config_service.dart';
import 'package:feelings/features/app_config/widgets/global_alert_wrapper.dart';

// Other Imports
import 'firebase_options.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();



@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

void main({bool isTesting = false}) async {
  await dotenv.load();
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  // ✨ Enable Offline Persistence Explicitly
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  // ✨ OPTIMIZATION: Fire-and-forget or Parallelize non-critical inits
  // We do NOT await these to unblock the UI thread aggressively.
  
  // 1. Start Critical Services (Parallel)
  final initFutures = <Future>[
     CrashlyticsHelper.initialize(),
     EncryptionService.instance.init(),
     NotificationService.initialize(),
     ReviewService().init(),
  ];

  // 2. Setup Error Handling (Sync)
  if (!kIsWeb && !isTesting) {
    FlutterError.onError = (details) {
      CrashlyticsHelper.recordFlutterFatalError(details);
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      CrashlyticsHelper.recordError(error, stack, fatal: true);
      return true;
    };
  }
  
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  NotificationService.onNotificationClick = () {
    navigatorKey.currentState?.pushNamed('/chat');
  };

  // 3. Theme Loading (We can start rendering with default while this loads)
  final themeProvider = ThemeProvider();
  // Don't await, let it update the UI when ready.
  themeProvider.loadThemeFromPrefs();

  // 4. Run App Immediately
  runApp(MyApp(themeProvider: themeProvider));
  
  // 5. Cleanup Futures (Optional, just ensuring they run)
  Future.wait(initFutures).then((_) {
    debugPrint("🚀 [Main] Background services initialized.");
  });
}

class MyApp extends StatelessWidget {
  final ThemeProvider themeProvider;
  const MyApp({super.key, required this.themeProvider});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // --- Single Instance Services and Repositories (Provide these FIRST) ---
        Provider(create: (_) => AuthService()),
        Provider(create: (_) => RhmRepository()),
        Provider(create: (_) => JournalRepository()),
        Provider(create: (_) => CheckInRepository()),
        Provider(create: (_) => QuestionRepository()),
        Provider(create: (_) => CalendarRepository()),
        Provider(create: (_) => CoupleRepository()),
        Provider(create: (_) => MediaRepository()),
        Provider(create: (_) => ChatRepository()),
        Provider(create: (_) => SecretNoteRepository()),

        // --- App-wide Providers (Can now safely read repositories) ---
        ChangeNotifierProvider(create: (_) => AppConfigService()..initialize()),
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProvider(
          create: (context) => CoupleProvider(
            coupleRepository: context.read<CoupleRepository>(),
            rhmRepository: context.read<RhmRepository>(),
          ),
        ),
        ChangeNotifierProvider(create: (_) => AppStatusProvider()),
        ChangeNotifierProvider(create: (context) => DynamicActionsProvider()),
        ChangeNotifierProvider(
          create: (context) => ChatProvider(
            context.read<DynamicActionsProvider>(),
            rhmRepository: context.read<RhmRepository>(),
            chatRepository: context.read<ChatRepository>(),
          ),
        ),
        ChangeNotifierProvider(
          create: (context) => JournalProvider(
            context.read<DynamicActionsProvider>(),
            journalRepository: context.read<JournalRepository>(),
            rhmRepository: context.read<RhmRepository>(),
          ),
        ),
        ChangeNotifierProvider(
          create: (context) => CalendarProvider(
            context.read<DynamicActionsProvider>(),
            calendarRepository: context.read<CalendarRepository>(),
            rhmRepository: context.read<RhmRepository>(),
          ),
        ),
        ChangeNotifierProvider(
          create: (context) => QuestionProvider(
            context.read<DynamicActionsProvider>(),
            questionRepository: context.read<QuestionRepository>(),
            rhmRepository: context.read<RhmRepository>(),
          ),
        ),
        ChangeNotifierProvider(
          create: (context) => DoneDatesProvider(
            context.read<DynamicActionsProvider>(),
            calendarRepository: context.read<CalendarRepository>(),
            rhmRepository: context.read<RhmRepository>(),
          ),
        ),
        ChangeNotifierProvider(
            create: (context) =>
                BucketListProvider(context.read<DynamicActionsProvider>())),
        ChangeNotifierProvider(
            create: (context) => MediaProvider(
                  context.read<DynamicActionsProvider>(),
                )),
        ChangeNotifierProvider(create: (_) => TipsProvider()),
        ChangeNotifierProxyProvider<DoneDatesProvider, DateIdeaProvider>(
          create: (context) => DateIdeaProvider(
            doneDatesProvider: context.read<DoneDatesProvider>(),
          ),
          update: (context, doneDatesProvider, dateIdeaProvider) {
            dateIdeaProvider?.updateDependencies(doneDatesProvider);
            return dateIdeaProvider ??
                DateIdeaProvider(doneDatesProvider: doneDatesProvider);
          },
        ),
        ChangeNotifierProvider(
          create: (context) => CheckInProvider(
            context.read<DynamicActionsProvider>(),
            checkInRepository: context.read<CheckInRepository>(),
            rhmRepository: context.read<RhmRepository>(),
          ),
        ),
        ChangeNotifierProvider.value(value: themeProvider),
        ChangeNotifierProvider(
          create: (context) => RhmDetailProvider(
            rhmRepository: context.read<RhmRepository>(),
          ),
        ),

        ChangeNotifierProvider(
          create: (context) => SecretNoteProvider(
            mediaRepository: context.read<MediaRepository>(),
            chatRepository: context.read<ChatRepository>(),
            rhmRepository: context.read<RhmRepository>(),
            secretNoteRepository: context.read<SecretNoteRepository>(),
          ),
        ),
      ],
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: Consumer<ThemeProvider>(
            builder: (context, themeProvider, child) {
              if (!themeProvider.isLoaded) {
                return const MaterialApp(
                    home: LoadingScreen(), debugShowCheckedModeBanner: false);
              }

              return MaterialApp(
                navigatorKey: navigatorKey,
                scaffoldMessengerKey: rootScaffoldMessengerKey,
                title: 'Feelings App',
                debugShowCheckedModeBanner: false,
                theme: themeProvider.currentTheme,
                builder: (context, child) {
                  return GlobalAlertHandler(
                    child: RhmPointsAnimationOverlay(
                      child: child ?? const SizedBox.shrink(),
                    ),
                  );
                },
                home: const AuthWrapper(),
                routes: {
                  '/login': (context) => const LoginScreen(),
                  '/register': (context) => const RegisterScreen(),
                  '/home': (context) => const HomeScreen(),
                  '/journal': (context) => const JournalScreen(),
                  '/chat': (context) => const ChatScreen(),
                  '/calendar': (context) => const CalendarScreen(),
                  '/profile': (context) => const ProfileScreen(),
                  '/connect-couple': (context) => ConnectCoupleScreen(),
                  '/discover': (context) => const DiscoverScreen(),
                  '/bottom_nav': (context) => const BottomNavBar(),
                  '/questions': (context) => QuestionsScreen(),
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

// --- AUTH WRAPPER ---
class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});
  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  User? _previousUser;
  bool _isCleaningUp = false;

  late final Stream<User?> _authStream;

  @override
  void initState() {
    super.initState();
    _authStream = FirebaseAuth.instance.authStateChanges();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _authStream,
      builder: (context, snapshot) {
        final user = snapshot.data;
        final userProvider = context.watch<UserProvider>(); // Watch for error updates

        if (user == null && _previousUser != null && !_isCleaningUp) {
          _isCleaningUp = true;
          _performCleanupAsync();
        }

        _previousUser = user;

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LoadingScreen();
        }

        if (_isCleaningUp) {
          return const LoadingScreen();
        }

        if (user == null) {
          return const LoginScreen();
        }

        // ✨ ERROR HANDLING: If Provider failed to load data (e.g. offline & no cache)
        if (userProvider.hasError) {
           return Scaffold(
             body: Center(
               child: Column(
                 mainAxisAlignment: MainAxisAlignment.center,
                 children: [
                   const Icon(Icons.cloud_off, size: 60, color: Colors.grey),
                   const SizedBox(height: 16),
                   const Text("Unable to connect", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                   const SizedBox(height: 8),
                   const Text("Please check your internet connection.", style: TextStyle(color: Colors.grey)),
                   const SizedBox(height: 24),
                   ElevatedButton(
                     onPressed: () {
                        // Retry fetching
                        context.read<UserProvider>().fetchUserData();
                     },
                     child: const Text("Retry"),
                   )
                 ],
               ),
             ),
           );
        }

        return const UserDataLoader();
      },
    );
  }

  /// Performs a full cleanup of all providers.
  Future<void> _performCleanupAsync() async {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (mounted) {
        try {
          // 1. Get all provider references SAFELY inside the callback.
          final userProvider = context.read<UserProvider>();
          final coupleProvider = context.read<CoupleProvider>();
          final chatProvider = context.read<ChatProvider>();
          final calendarProvider = context.read<CalendarProvider>();
          final bucketListProvider = context.read<BucketListProvider>();
          final journalProvider = context.read<JournalProvider>();
          final checkInProvider = context.read<CheckInProvider>();
          final dateIdeaProvider = context.read<DateIdeaProvider>();
          final doneDatesProvider = context.read<DoneDatesProvider>();
          final mediaProvider = context.read<MediaProvider>();
          final questionProvider = context.read<QuestionProvider>();
          final rhmDetailProvider = context.read<RhmDetailProvider>();
          final tipsProvider = context.read<TipsProvider>();
          final dynamicActionsProvider = context.read<DynamicActionsProvider>();
          final secretNoteProvider = context.read<SecretNoteProvider>();

          coupleProvider.clear();
          chatProvider.clear();
          calendarProvider.clear();
          bucketListProvider.clear();
          journalProvider.clear();
          checkInProvider.clear();
          dateIdeaProvider.clear();
          doneDatesProvider.clear();
          mediaProvider.clear();
          questionProvider.clear();
          rhmDetailProvider.clear();
          tipsProvider.clear();
          secretNoteProvider.clear();

          // 3. NOW, await the async cleanup (which has I/O operations).
          //    It's now safe for this to pause, as all listeners are dead.
          await dynamicActionsProvider.clear();
          await userProvider.clear(); // <- Moved to the end of the line
        } catch (e) {
          // Report any errors during cleanup
          // CrashlyticsHelper.recordError(e, stack, reason: "AuthWrapper cleanup failed");
          debugPrint("AuthWrapper cleanup failed: $e");
        } finally {
          // 4. AFTER cleanup is done, pop the stack and set state.
          if (mounted) {
            navigatorKey.currentState?.popUntil((route) => route.isFirst);
            setState(() => _isCleaningUp = false);
          }
        }
      }
    });
  }
}

// --- USER DATA LOADER ---
class UserDataLoader extends StatefulWidget {
  const UserDataLoader({super.key});
  @override
  State<UserDataLoader> createState() => _UserDataLoaderState();
}

class _UserDataLoaderState extends State<UserDataLoader> {
  // Flag to prevent duplicate dialogs
  bool _isRecoveryInProgress = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // These fetches are correct.
        context.read<UserProvider>().fetchUserData();
        context.read<CoupleProvider>().fetchCoupleAndPartnerData(user.uid);
      }
    });
  }

  // ✨ --- NEW HELPER METHOD --- ✨
  void _startListeners(BuildContext context) {
    // This helper ensures listeners are only started when all data is ready.
    // It's called from the build method, but `addPostFrameCallback` ensures
    // it runs *after* the build is complete, preventing state errors.

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Ensure the context is still valid
      if (!mounted) return;

      // ✨ DEBOUNCE: If we are already running this check (or dialog is open), exit.
      if (_isRecoveryInProgress) return;
      _isRecoveryInProgress = true;

      try {
        debugPrint("🔍 [Main] _startListeners triggered");
        final userProvider = context.read<UserProvider>();
        final coupleProvider = context.read<CoupleProvider>();

        final currentUserId = userProvider.currentUser?.id;
        final coupleId = coupleProvider.coupleId;

        debugPrint("🔍 [Main] UserId: $currentUserId, CoupleId: $coupleId");

        if (currentUserId != null && coupleId != null) {
          // We have all the data. Start the listener.
          debugPrint("🔍 [Main] Attempting to load master key for couple: $coupleId");
          final hasKey = await EncryptionService.instance.loadMasterKey(coupleId);
          
          if (hasKey) {
             debugPrint("✅ Encryption Ready for Couple: $coupleId");
          } else {
             debugPrint("⚠️ Encryption Key Missing for Couple: $coupleId");
             
             // ✨ AUTO-PROMPT RECOVERY IF NEEDED
             // Check if we *expect* to have a key (encryption enabled + backup exists)
             try {
               final userRepository = UserRepository();
               final status = await userRepository.getEncryptionStatus(currentUserId);
               debugPrint("🔍 [Main] Encryption Status for $currentUserId: $status");
               
               if (status == 'enabled') {
                  final hasBackup = await userRepository.getKeyBackup(currentUserId);
                  debugPrint("🔍 [Main] Backup found: ${hasBackup != null}");
                  
                  if (hasBackup != null) {
                     debugPrint("🚨 [Main] User Enabled + Backup Exists + No Key = PROMPT RECOVERY");
                     // NOTE: UI Prompt moved to BottomNavBar to show over App UI.
                  } else {
                     debugPrint("⚠️ [Main] Encryption enabled but NO BACKUP found.");
                  }
               } else {
                 debugPrint("ℹ️ [Main] Encryption status is '$status', skipping prompt.");
               }
             } catch (e) {
                debugPrint("⚠️ [Main] Failed to check encryption status for auto-prompt: $e");
             }
          }
          if (mounted) {
            context
              .read<SecretNoteProvider>()
              .listenForUnreadNotes(coupleId, currentUserId);
          }
        } else {
          debugPrint("⚠️ [Main] Listener start skipped: Missing UserId or CoupleId");
        }
      
      } finally {
        // Always release the lock when done, even if errors occur.
        if (mounted) {
          _isRecoveryInProgress = false;
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // ✨ [FIX] Get the Firebase Auth user *directly* to check auth state.
    // This is the source of truth for "is someone logged in?"
    final authUser = FirebaseAuth.instance.currentUser;

    return Consumer2<UserProvider, CoupleProvider>(
      builder: (context, userProvider, coupleProvider, child) {
        // PATH 1: Still loading PRIMARY data.
        if ((userProvider.isLoading && userProvider.userData == null) ||
            (coupleProvider.isLoading && userProvider.userData == null)) {
          return const LoadingScreen();
        }
 
        // PATH 2: ✨ [FIX] No Firebase auth user.
        else if (authUser == null) {
          return const LoginScreen();
        }

        // PATH 3: ✨ [FIX] Handle new users (Google vs Email).
        else if (userProvider.userData == null) {
          // Check if the user signed in with Email/Password
          final isEmailUser = authUser.providerData.any((p) => p.providerId == 'password');

          if (isEmailUser) {
            // CASE A: Email User + No Data = Race Condition / Loading.
            // Do NOT show RegisterScreen. Just keep loading or retry.
            
            // If the provider stopped loading but data is still null, force a retry.
            if (!userProvider.isLoading) {
               WidgetsBinding.instance.addPostFrameCallback((_) {
                 userProvider.fetchUserData(); 
               });
            }
            return const LoadingScreen();
          } else {
            // CASE B: Google/Apple User + No Data = Needs to Complete Profile.
            // This is the ONLY case where we show the screen.
            return RegisterScreen(prefilledUser: authUser);
          }
        }

        // PATH 4: ✨ [FIX] Firebase user exists AND Firestore data exists.
        // This is an existing user. Check their onboarding status.
        else {
          // This also fixes a potential crash if onboardingCompleted is null.
          final bool hasOnboarded =
              userProvider.userData!['onboardingCompleted'] ?? false;

          if (hasOnboarded) {
            // User is fully onboarded.

            // ✨ --- START THE LISTENER --- ✨
            // We have all the data we need to start the listeners.
            _startListeners(context);

            return const BottomNavBarWithFade();
          } else {
            // User is logged in but has not onboarded.
            // RETURN the OnboardingScreen, DON'T navigate.
            return OnboardingScreen(
              // ✨ [FIX] Safely get data, preferring Firestore data
              // but falling back to the auth object.
              email: userProvider.currentUser?.email ?? authUser.email ?? '',
              name:
                  userProvider.currentUser?.name ?? authUser.displayName ?? '',
              // Get photoURL from userData map, fallback to authUser
              photoURL: userProvider.userData!['profileImageUrl'] ??
                  authUser.photoURL ??
                  '',
            );
          }
        }
      },
    );
  }
}

class BottomNavBarWithFade extends StatefulWidget {
  const BottomNavBarWithFade({super.key});

  @override
  State<BottomNavBarWithFade> createState() => _BottomNavBarWithFadeState();
}

class _BottomNavBarWithFadeState extends State<BottomNavBarWithFade>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  bool _isReadyToShow = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );
  }

  void _onReady() {
    if (!_isReadyToShow) {
      setState(() => _isReadyToShow = true);
      _controller.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Your BottomNavBar
        Opacity(
          opacity: _isReadyToShow ? 1.0 : 0.0,
          child: BottomNavBar(onContentReady: _onReady),
        ),

        // Fallback LoadingScreen while BottomNavBar (HomeScreenViewModel) is initializing
        if (!_isReadyToShow)
          const Scaffold(
            body: Center(child: LoadingScreen()),
          ),

        // Fade animation when ready
        if (_isReadyToShow)
          FadeTransition(
            opacity: _fadeAnimation,
            child: const SizedBox.expand(),
          ),
      ],
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

// ----------------------------------------------------------------------
// SMOOTH TRANSITION WRAPPER
// ----------------------------------------------------------------------
class FadeScaleTransitionWrapper extends StatefulWidget {
  final Widget child;
  final Duration duration;
  const FadeScaleTransitionWrapper({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 600),
  });

  @override
  State<FadeScaleTransitionWrapper> createState() =>
      _FadeScaleTransitionWrapperState();
}

class _FadeScaleTransitionWrapperState extends State<FadeScaleTransitionWrapper>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration)
      ..forward();

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );

    _scaleAnimation = Tween<double>(begin: 0.98, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
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
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: widget.child,
      ),
    );
  }
}



// ----------------------------------------------------------------------
// LOADING SCREEN with SMOOTH WIGGLING TEXT
// ----------------------------------------------------------------------
class LoadingScreen extends StatelessWidget {
  const LoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final textStyle = theme.textTheme.headlineLarge?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w300,
          fontSize: 38,
          letterSpacing: 1.5,
        ) ??
        const TextStyle(fontSize: 38, fontWeight: FontWeight.w300);

    return Scaffold(
      body: Center(
        child: Text(
          'Feelings',
          style: textStyle,
        ),
      ),
    );
  }
}