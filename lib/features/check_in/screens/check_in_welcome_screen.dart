import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:feelings/providers/check_in_provider.dart';
import 'package:feelings/providers/user_provider.dart';
import 'check_in_questions_screen.dart'; // Next screen in the flow
import '../widgets/check_in_loading.dart';

class CheckInWelcomeScreen extends StatefulWidget {
  const CheckInWelcomeScreen({super.key});

  @override
  State<CheckInWelcomeScreen> createState() => _CheckInWelcomeScreenState();
}

class _CheckInWelcomeScreenState extends State<CheckInWelcomeScreen> {
  bool _isLoading = false;

  Future<void> _startCheckIn() async {
    setState(() {
      _isLoading = true;
    });

    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final checkInProvider = Provider.of<CheckInProvider>(context, listen: false);

    final String? userId = userProvider.getUserId();
    final String? coupleId = userProvider.coupleId;

    if (userId == null || coupleId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not find user or couple information. Please try again.')),
        );
      }
      setState(() {
        _isLoading = false;
      });
      return;
    }

    try {
      final String? newCheckInId = await checkInProvider.createCheckIn(userId, coupleId);
      
      if (newCheckInId != null && mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CheckInQuestionsScreen(
              userId: userId,
              checkInId: newCheckInId,
            ),
          ),
        );
      } else {
        throw Exception('Failed to create a check-in session.');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error starting check-in: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      // THEME: The AppBar is now styled by your global appBarTheme
      appBar: AppBar(
        title: const Text('Relationship Health Check-in'),
        centerTitle: true,
      ),
      body: Container(
        // THEME: The main content area uses the theme's surface color
        color: colorScheme.surface,
        child: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Accent icon badge
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      // THEME: Uses primary color and its corresponding 'on' color
                      color: colorScheme.primary,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: colorScheme.primary.withOpacity(0.10),
                          blurRadius: 14,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Icon(Icons.favorite, size: 38, color: colorScheme.onPrimary),
                  ),
                  const SizedBox(height: 24),
                  // Card with main content
                  Card(
                    // THEME: The Card now uses the global cardTheme for its appearance
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 22),
                      child: Column(
                        children: [
                          Text(
                            'Time for a Little Reflection!',
                            // THEME: Uses text styles from the theme
                            style: theme.textTheme.headlineSmall,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'This is a private space for you to reflect on your relationship. It\'s not a test, and there are no right or wrong answers. Be open and honest with yourself.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
                          ),
                          const SizedBox(height: 16),
                          // Privacy note in a soft box
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              // THEME: Uses a distinct surface color from the theme
                              color: colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(13),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(Icons.lock_outline, color: colorScheme.onSurfaceVariant, size: 17),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Your answers are personal and will not be shared with your partner unless you choose to do so later.',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      fontStyle: FontStyle.italic,
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 18),
                          _isLoading
                              ? const CheckInLoading()
                              : SizedBox(
                                  width: double.infinity,
                                  // THEME: The button is now styled by your global elevatedButtonTheme
                                  child: ElevatedButton(
                                    onPressed: _startCheckIn,
                                    child: const Text('Start Reflection'),
                                  ),
                                ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}