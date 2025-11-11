import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:feelings/utils/crashlytics_helper.dart';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'dart:math';

// Your App's Providers
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
// ✨ --- NEW IMPORT --- ✨
import 'package:feelings/providers/secret_note_provider.dart';
import 'package:feelings/features/chat/repositories/chat_repository.dart'; // Need this for SecretNoteProvider
import 'package:feelings/features/media/repository/media_repository.dart'; // Need this for SecretNoteProvider
import 'package:feelings/features/secret_note/repositories/secret_note_repository.dart';

// Your App's Screens
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
import 'package:feelings/features/auth/services/auth_service.dart';
import 'package:feelings/features/connectCouple/repository/couple_repository.dart';
import 'package:feelings/services/notification_services.dart';
import 'package:feelings/features/calendar/repository/calendar_repository.dart';
import 'package:feelings/features/rhm/repository/rhm_repository.dart';
import 'package:feelings/features/journal/repository/journal_repository.dart';
import 'package:feelings/features/check_in/repository/check_in_repository.dart';
import 'package:feelings/features/questions/repository/questions_repository.dart';
import 'package:feelings/widgets/rhm_points_animation_overlay.dart';

// Other Imports
import 'firebase_options.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

void main() async {
  await dotenv.load();
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await CrashlyticsHelper.initialize();

  if (!kIsWeb) {
    // 2. Use the static methods from the helper
    FlutterError.onError = (details) {
      CrashlyticsHelper.recordFlutterFatalError(details);
    };
    
    PlatformDispatcher.instance.onError = (error, stack) {
      CrashlyticsHelper.recordError(error, stack, fatal: true);
      return true;
    };
    
  }

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  await NotificationService.initialize();
  NotificationService.onNotificationClick = () {
    navigatorKey.currentState?.pushNamed('/chat');
  };

  final themeProvider = ThemeProvider();
  await themeProvider.loadThemeFromPrefs();

  runApp(MyApp(themeProvider: themeProvider));
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
        // ✨ Add repositories for SecretNoteProvider
        Provider(create: (_) => MediaRepository()),
        Provider(create: (_) => ChatRepository()),
        Provider(create: (_) => SecretNoteRepository()),

        // --- App-wide Providers (Can now safely read repositories) ---
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
            create: (context) => BucketListProvider(context.read<DynamicActionsProvider>())),
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
            return dateIdeaProvider ?? DateIdeaProvider(doneDatesProvider: doneDatesProvider);
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
        // ✨ --- ADD THE NEW PROVIDER --- ✨
        ChangeNotifierProvider(
          create: (context) => SecretNoteProvider(
            mediaRepository: context.read<MediaRepository>(),
            chatRepository: context.read<ChatRepository>(),
            rhmRepository: context.read<RhmRepository>(),
            // ✨ Inject the new repository
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
                title: 'Feelings App',
                debugShowCheckedModeBanner: false,
                theme: themeProvider.currentTheme,
                builder: (context, child) {
                  return RhmPointsAnimationOverlay(
                    child: child ?? const SizedBox.shrink(),
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

  // This stream is now persistent, which is correct.
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

        if (user == null && _previousUser != null && !_isCleaningUp) {
          // A logout just happened.
          _isCleaningUp = true;
          
          // ✨ --- THIS IS THE FIX --- ✨
          // 1. DO NOT call context.read() here.
          // 2. Just call the cleanup function.
          //    We will get the context *safely* inside the post-frame callback.
          _performCleanupAsync();
        }

        _previousUser = user;

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LoadingScreen();
        }

        if (_isCleaningUp) {
          // If cleanup is in progress, show a loading screen.
          return const LoadingScreen();
        }

        if (user == null) {
          // Cleanup is finished, so it's safe to show LoginScreen.
          return const LoginScreen();
        }

        // User is non-null, show the data loader.
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
          final journalProvider = context.read<JournalProvider>(); // <- Got provider
          final checkInProvider = context.read<CheckInProvider>();
          final dateIdeaProvider = context.read<DateIdeaProvider>();
          final doneDatesProvider = context.read<DoneDatesProvider>();
          final mediaProvider = context.read<MediaProvider>();
          final questionProvider = context.read<QuestionProvider>();
          final rhmDetailProvider = context.read<RhmDetailProvider>();
          final tipsProvider = context.read<TipsProvider>();
          final dynamicActionsProvider = context.read<DynamicActionsProvider>();
          // ✨ Get the new provider
          final secretNoteProvider = context.read<SecretNoteProvider>();

          // ✨ --- THIS IS THE FIX --- ✨
          // 2. Clear all providers with SYNCHRONOUS clear methods FIRST.
          // This immediately cancels all active stream listeners (Journal, Chat, etc.)
          // before we hit any 'await'.
          coupleProvider.clear();
          chatProvider.clear();
          calendarProvider.clear();
          bucketListProvider.clear();
          journalProvider.clear(); // <- Moved UP
          checkInProvider.clear();
          dateIdeaProvider.clear();
          doneDatesProvider.clear();
          mediaProvider.clear();
          questionProvider.clear();
          rhmDetailProvider.clear();
          tipsProvider.clear();
          secretNoteProvider.clear(); // ✨ Clear the new provider
           

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
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Ensure the context is still valid
      if (!mounted) return;

      final userProvider = context.read<UserProvider>();
      final coupleProvider = context.read<CoupleProvider>();
      
      final currentUserId = userProvider.currentUser?.id;
      final coupleId = coupleProvider.coupleId;

      if (currentUserId != null && coupleId != null) {
        // We have all the data. Start the listener.
        context
            .read<SecretNoteProvider>()
            .listenForUnreadNotes(coupleId, currentUserId);
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
        
        // PATH 1: Still loading data from providers.
        if (userProvider.isLoading || coupleProvider.isLoading) {
          return const LoadingScreen();
        } 
        
        // PATH 2: ✨ [FIX] No Firebase auth user.
        // This check must come *after* the loading check.
        // This path is mostly a safety, as AuthWrapper should catch this.
        else if (authUser == null) { 
          return const LoginScreen();
        } 
        
        // PATH 3: ✨ [FIX] Firebase auth user *exists*, but Firestore data (`userData`) is *null*.
        // This is the new Google Sign-In user. RETURN the RegisterScreen.
        else if (userProvider.userData == null) {
          // We have a logged-in user with no database entry.
          // Return them to the RegisterScreen to "Complete Profile".
          // We pass the authUser directly to the constructor.
          return RegisterScreen(prefilledUser: authUser);
        }
        
        // PATH 4: ✨ [FIX] Firebase user exists AND Firestore data exists.
        // This is an existing user. Check their onboarding status.
        else {
          // This also fixes a potential crash if onboardingCompleted is null.
          final bool hasOnboarded = userProvider.userData!['onboardingCompleted'] ?? false;
    
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
              name: userProvider.currentUser?.name ?? authUser.displayName ?? '',
              // Get photoURL from userData map, fallback to authUser
              photoURL: userProvider.userData!['profileImageUrl'] ?? authUser.photoURL ?? '',
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
    _controller =
        AnimationController(vsync: this, duration: widget.duration)..forward();

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
// SMOOTH WIGGLING TEXT
// ----------------------------------------------------------------------
class WigglingText extends StatefulWidget {
  final String text;
  final TextStyle style;
  final Duration animationDuration;
  final double amplitude;

  const WigglingText({
    super.key,
    required this.text,
    required this.style,
    this.animationDuration = const Duration(seconds: 3),
    this.amplitude = 0.6,  // Reduced amplitude for more subtle movement
  });

  @override
  State<WigglingText> createState() => _WigglingTextState();
}

class _WigglingTextState extends State<WigglingText>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late List<double> _phaseOffsets;
  final Random _random = Random();

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: widget.animationDuration,
    )..repeat(reverse: false);

    _phaseOffsets =
        List.generate(widget.text.length, (_) => _random.nextDouble() * 2 * pi);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final double t = _controller.value * 2 * pi;

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(widget.text.length, (index) {
            final double dx =
                sin(t + _phaseOffsets[index]) * widget.amplitude;
            final double dy =
                cos(t + _phaseOffsets[index]) * widget.amplitude;

            return Transform.translate(
              offset: Offset(dx, dy),
              child: Text(widget.text[index], style: widget.style),
            );
          }),
        );
      },
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
        child: WigglingText(
          text: 'Feelings',
          style: textStyle,
          animationDuration: const Duration(milliseconds: 1200),
        ),
      ),
    );
  }
}