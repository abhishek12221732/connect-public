// lib/features/home/screens/bottom_nav_bar.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_nav_bar/google_nav_bar.dart';

// Import ViewModel and all necessary providers
import 'package:feelings/features/home/view_models/home_screen_view_model.dart';
import 'package:feelings/providers/user_provider.dart';
import 'package:feelings/providers/calendar_provider.dart';
import 'package:feelings/providers/bucket_list_provider.dart';
import 'package:feelings/providers/date_idea_provider.dart';
import 'package:feelings/providers/tips_provider.dart';
import 'package:feelings/providers/question_provider.dart';
import 'package:feelings/providers/journal_provider.dart';
import 'package:feelings/providers/done_dates_provider.dart';
import 'package:feelings/providers/app_status_provider.dart';
import 'package:feelings/main.dart'; // Import main.dart for LoadingScreen
import 'package:feelings/providers/check_in_provider.dart';
import 'package:feelings/features/discover/screens/discover_screen.dart';
import 'package:feelings/features/rhm/repository/rhm_repository.dart';

// Import your screens
import 'package:feelings/features/home/screens/home_screen.dart';
import 'package:feelings/features/journal/screens/journal_screen.dart';
import 'package:feelings/features/chat/screens/chat_screen.dart';
import 'package:feelings/features/calendar/screens/calendar_screen.dart';
import 'package:feelings/providers/chat_provider.dart';

// ✨ --- REMOVED --- ✨
// import 'package:feelings/features/secret_note/widgets/secret_note_overlay.dart';
// ✨ --- END OF REMOVAL --- ✨

class BottomNavBar extends StatelessWidget {
  final int initialTabIndex;
  final VoidCallback? onContentReady;

  const BottomNavBar({
    super.key,
    this.initialTabIndex = 0,
    this.onContentReady,
  });

  @override
  Widget build(BuildContext context) {
    // The ViewModel is provided here so descendants can access it.
    return ChangeNotifierProvider(
      create: (context) => HomeScreenViewModel(
        userProvider: context.read<UserProvider>(),
        questionProvider: context.read<QuestionProvider>(),
        calendarProvider: context.read<CalendarProvider>(),
        journalProvider: context.read<JournalProvider>(),
        bucketListProvider: context.read<BucketListProvider>(),
        doneDatesProvider: context.read<DoneDatesProvider>(),
        dateIdeaProvider: context.read<DateIdeaProvider>(),
        tipsProvider: context.read<TipsProvider>(),
        checkInProvider: context.read<CheckInProvider>(),
        rhmRepository: context.read<RhmRepository>(),
      ),
      child: _BottomNavBarContent(
        initialTabIndex: initialTabIndex,
        onContentReady: onContentReady,
      ),
    );
  }
}

class _BottomNavBarContent extends StatefulWidget {
  final int initialTabIndex;
  final VoidCallback? onContentReady;

  const _BottomNavBarContent({
    required this.initialTabIndex,
    this.onContentReady,
  });

  @override
  _BottomNavBarContentState createState() => _BottomNavBarContentState();
}

class _BottomNavBarContentState extends State<_BottomNavBarContent> {
  late int _currentIndex;

  // ✨ [MODIFIED] The ProfileScreen has been removed from the list.
  final List<Widget> _screens = const [
    HomeScreen(),
    JournalScreen(),
    ChatScreen(),
    CalendarScreen(),
    DiscoverScreen(),
  ];

  Widget _buildChatIconWithBadge(int count, int index) {
    final theme = Theme.of(context);
    // Check if this icon is the currently selected tab
    final bool isSelected = _currentIndex == index;

    // Get the correct icon color based on selection
    final iconColor = isSelected
        ? theme.colorScheme.onPrimary // GNav's activeColor
        : theme.colorScheme.onSurface; // GNav's color

    return Stack(
      clipBehavior: Clip.none, // Allow badge to show outside the icon's box
      children: [
        Icon(
          Icons.chat_bubble_outline_rounded,
          color: iconColor, // Manually apply the color
        ),
        if (count > 0)
          Positioned(
            top: -4,
            right: -8,
            child: Container(
              padding: EdgeInsets.all(count > 9 ? 4 : 5), // Adjust padding
              decoration: BoxDecoration(
                color: theme.colorScheme.error,
                shape: BoxShape.circle,
                // Add a border to make it stand out from the icon
                border: Border.all(width: 1.5, color: theme.colorScheme.surface),
              ),
              constraints: const BoxConstraints(
                minWidth: 18,
                minHeight: 18,
              ),
              child: Text(
                count > 9 ? '9+' : '$count', // Show '9+' if count is high
                style: TextStyle(
                  color: theme.colorScheme.onError,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialTabIndex;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<HomeScreenViewModel>(context, listen: false).initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final homeViewModel = context.watch<HomeScreenViewModel>();

    if (_currentIndex == 0 &&
        homeViewModel.status == HomeScreenStatus.loading &&
        !homeViewModel.isInitialized) {
      return const LoadingScreen();
    }

    if (homeViewModel.status == HomeScreenStatus.loaded &&
        widget.onContentReady != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onContentReady?.call();
      });
    }

    // ✨ --- MODIFICATION --- ✨
    // Removed the SecretNoteOverlay wrapper
    if (_currentIndex == 0 && homeViewModel.status == HomeScreenStatus.error) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text("Error: ${homeViewModel.errorMessage}",
                textAlign: TextAlign.center),
          ),
        ),
      );
    }

    // ✨ --- MODIFICATION --- ✨
    // Removed the SecretNoteOverlay wrapper
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          boxShadow: [
            BoxShadow(blurRadius: 20, color: Colors.black.withOpacity(.1))
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8),
            child: GNav(
              rippleColor: theme.colorScheme.primary.withOpacity(0.1),
              hoverColor: theme.colorScheme.primary.withOpacity(0.1),
              gap: 5,
              activeColor: theme.colorScheme.onPrimary,
              iconSize: 24,
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              duration: const Duration(milliseconds: 400),
              tabBackgroundColor: theme.colorScheme.primary,
              color: theme.colorScheme.onSurface,
              tabs: [
                const GButton(icon: Icons.home_outlined, text: 'Home'),
                const GButton(
                    icon: Icons.photo_library_outlined, text: 'Journey'),
                GButton(
                  icon: Icons.chat_bubble_outline_rounded,
                  leading: Selector<ChatProvider, int>(
                    selector: (context, provider) =>
                        provider.unreadMessageCount,
                    builder: (context, unreadCount, child) {
                      return _buildChatIconWithBadge(unreadCount, 2);
                    },
                  ),
                  text: 'Chat',
                ),
                const GButton(
                    icon: Icons.calendar_today_outlined, text: 'Calendar'),
                const GButton(
                    icon: Icons.favorite_border_rounded, text: 'Discover'),
              ],
              selectedIndex: _currentIndex,
              onTabChange: (index) {
                setState(() {
                  _currentIndex = index;
                });
              },
            ),
          ),
        ),
      ),
    );
  }
}