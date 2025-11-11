import 'dart:math';
import 'package:flutter/material.dart';
import 'package:feelings/features/date_night/screens/date_preference_picker_screen.dart';
import 'package:feelings/features/date_night/screens/favorites_screen.dart';
import 'package:feelings/features/date_night/screens/done_dates_screen.dart';
import 'package:feelings/features/date_night/screens/generated_date_idea_screen.dart';
import 'package:provider/provider.dart';
import 'package:feelings/providers/user_provider.dart';
import 'package:feelings/providers/date_idea_provider.dart';

class DateNightCard extends StatelessWidget {
  const DateNightCard({super.key});

  @override
  Widget build(BuildContext context) {
    // THEME: Get theme and colorScheme from context
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    final userProvider = Provider.of<UserProvider>(context);
    final userId = userProvider.getUserId() ?? '';
    final coupleId = userProvider.coupleId ?? '';
    final items = [
      {'label': 'At Home', 'icon': Icons.home, 'isAtHome': true},
      {'label': 'Random', 'icon': Icons.shuffle, 'isRandom': true},
      {'label': 'Done', 'icon': Icons.check_circle, 'isDoneDates': true},
      {'label': 'Favorites', 'icon': Icons.favorite, 'isFavorites': true},
    ];

    // THEME: This Card is now styled by your global cardTheme
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                Icon(Icons.local_fire_department, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  "Spice Up Date Night!",
                  // THEME: Use text styles and colors from the theme
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: items.map((item) {
                return GestureDetector(
                  onTap: () async {
                    if (item['isFavorites'] == true) {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const FavoritesScreen()));
                    } else if (item['isDoneDates'] == true) {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const DoneDatesScreen()));
                    } else if (item['isAtHome'] == true) {
                      await _generateAtHomeIdea(context, userId, coupleId);
                    } else if (item['isRandom'] == true) {
                      await _generateRandomIdea(context, userId, coupleId);
                    }
                  },
                  child: Column(
                    children: [
                      CircleAvatar(
                        // THEME: Use theme colors
                        backgroundColor: colorScheme.primary,
                        child: Icon(item['icon'] as IconData, color: colorScheme.onPrimary),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item['label'] as String,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            // THEME: This button is now styled by your global elevatedButtonTheme
            ElevatedButton(
              onPressed: () async {
                if (userId.isEmpty || coupleId.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please wait, loading your profile...')),
                  );
                  return;
                }
                Navigator.push(
                  context,
                  PageRouteBuilder(
                    pageBuilder: (context, animation, secondaryAnimation) =>
                        const DatePreferencePickerScreen(),
                    transitionsBuilder:
                        (context, animation, secondaryAnimation, child) {
                      const begin = Offset(0.0, 1.0);
                      const end = Offset(0.0, 0.0);
                      const curve = Curves.easeOutCubic;
                      var tween = Tween(begin: begin, end: end)
                          .chain(CurveTween(curve: curve));
                      return SlideTransition(
                        position: animation.drive(tween),
                        child: child,
                      );
                    },
                    transitionDuration: const Duration(milliseconds: 400),
                  ),
                );
              },
              child: const Text("Generate Idea"),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _generateAtHomeIdea(BuildContext context, String userId, String coupleId) async {
    if (userId.isEmpty || coupleId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please wait, loading your profile...')),
      );
      return;
    }

    final dateIdeaProvider = Provider.of<DateIdeaProvider>(context, listen: false);
    
    dateIdeaProvider.reset();
    dateIdeaProvider.toggleLocation('At Home');
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const GeneratedDateIdeaScreen(),
      ),
    );
    
    await dateIdeaProvider.generateDateIdea(userId: userId, coupleId: coupleId, context: context);
  }

  Future<void> _generateRandomIdea(BuildContext context, String userId, String coupleId) async {
    if (userId.isEmpty || coupleId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please wait, loading your profile...')),
      );
      return;
    }

    final dateIdeaProvider = Provider.of<DateIdeaProvider>(context, listen: false);
    final random = Random();

    dateIdeaProvider.reset();

    const allLocations = ['At Home', 'Outdoors', 'Out & About', 'Getaway'];
    final numLocations = random.nextInt(2) + 1;
    final shuffledLocations = List.from(allLocations)..shuffle();
    for (int i = 0; i < numLocations; i++) {
      dateIdeaProvider.toggleLocation(shuffledLocations[i]);
    }

    const allVibes = [
      'Relaxing',
      'Adventurous',
      'Creative',
      'Learning/Intellectual',
      'Fun & Playful',
      'Romantic/Intimate'
    ];
    dateIdeaProvider.selectVibe(allVibes[random.nextInt(allVibes.length)]);

    const allBudgets = ['Free/Low Cost', 'Moderate', 'Splurge'];
    dateIdeaProvider.selectBudget(allBudgets[random.nextInt(allBudgets.length)]);

    const allTimes = ['1-2 Hours', '2-4 Hours', 'Half Day+'];
    dateIdeaProvider.selectTime(allTimes[random.nextInt(allTimes.length)]);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const GeneratedDateIdeaScreen(),
      ),
    );
    
    await dateIdeaProvider.generateDateIdea(userId: userId, coupleId: coupleId, context: context);
  }
}