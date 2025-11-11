import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:feelings/providers/question_provider.dart';
// ✨ [ADD] Import UserProvider to get coupleId
import 'package:feelings/providers/user_provider.dart';
import 'package:feelings/features/questions/models/question_model.dart';
import 'package:feelings/features/questions/screens/questions_screen.dart';
import 'package:feelings/features/chat/screens/chat_screen.dart';
import 'dart:async';

class KnowEachOtherSection extends StatefulWidget {
  // ... (unchanged)
  const KnowEachOtherSection({super.key});

  @override
  State<KnowEachOtherSection> createState() => _KnowEachOtherSectionState();
}

class _KnowEachOtherSectionState extends State<KnowEachOtherSection> with TickerProviderStateMixin {
  // ... (state variables _auth, _authSubscription, _userId, _fadeController, _fadeAnimation are unchanged) ...
  final FirebaseAuth _auth = FirebaseAuth.instance;
  StreamSubscription<User?>? _authSubscription;
  String? _userId;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    // ... (unchanged)
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));
    
    final authStream = _auth.authStateChanges();
    _authSubscription = authStream.listen((User? user) {
      if (!mounted) return;

      setState(() {
        _userId = user?.uid;
      });

      if (user != null) {
        _fetchDailyQuestion();
      }
    });
  }

  @override
  void dispose() {
    // ... (unchanged)
    _authSubscription?.cancel();
    _fadeController.dispose();
    super.dispose();
  }

  void _showAuthWarning(BuildContext context) {
    // ... (unchanged)
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Authentication not ready. Please wait a moment.'),
      ),
    );
  }

  // ✨ [MODIFY] Update _askQuestion
  void _askQuestion(QuestionModel question) async {
    if (_userId == null) {
      _showAuthWarning(context);
      return;
    }
    // ✨ [ADD] Get UserProvider and coupleId
    final userProvider = context.read<UserProvider>();
    final coupleId = userProvider.coupleId; 
    
    // ✨ [ADD] Check if coupleId exists
    if (coupleId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Cannot mark question as done. Couple connection not found.'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return;
    }

    final bool confirm = await showDialog(
          context: context,
          builder: (BuildContext context) {
            // ... (Dialog unchanged) ...
            return AlertDialog(
              title: const Text('Ask in chat?'),
              content: Text('"${question.question}"'),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Ask'),
                ),
              ],
            );
          },
        ) ??
        false;

    if (confirm && mounted) {
      final questionProvider = Provider.of<QuestionProvider>(context, listen: false);
      // ✨ [MODIFY] Pass coupleId here
      await questionProvider.markQuestionAsDone(_userId!, question.id, coupleId); 
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => ChatScreen(
            questionToAsk: question.question,
          ),
        ),
      );
    }
  }

  Future<void> _fetchDailyQuestion() async {
    // ... (unchanged)
    if (_userId == null) return;
    
    final questionProvider = Provider.of<QuestionProvider>(context, listen: false);
    await questionProvider.fetchDailyQuestion(_userId!);
    
    if (mounted) {
      _fadeController.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    // ... (build method logic is unchanged) ...
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final questionProvider = Provider.of<QuestionProvider>(context);
    final dailyQuestion = questionProvider.dailyQuestion;
    final isLoadingDailyQuestion = questionProvider.isLoadingDailyQuestion;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Know Each Other Better",
          style: theme.textTheme.headlineSmall,
        ),
        const SizedBox(height: 12),

        GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const QuestionsScreen(initialTabIndex: 0),
              ),
            );
          },
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.help_outline, color: colorScheme.primary, size: 20),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "Daily Question",
                        style: theme.textTheme.titleMedium,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: isLoadingDailyQuestion
                        ? SizedBox(
                            key: const ValueKey('loading'),
                            height: 60,
                            child: Center(
                              child: Text(
                                "Loading today's question...",
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  color: colorScheme.onSurface.withOpacity(0.7),
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                          )
                        : FadeTransition(
                            key: const ValueKey('question'),
                            opacity: _fadeAnimation,
                            child: Text(
                              dailyQuestion?.question ?? "Tap to get a question!",
                              style: theme.textTheme.bodyLarge?.copyWith(height: 1.3),
                            ),
                          ),
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: ElevatedButton(
                      onPressed: dailyQuestion == null ? null : () => _askQuestion(dailyQuestion),
                      child: const Text("Discuss"),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),

        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildNavigableCategoryIcon(
                      icon: Icons.child_care,
                      label: "Childhood",
                      targetCategory: "Foundation",
                      targetSubCategory: "Rooted Memories",
                    ),
                    _buildNavigableCategoryIcon(
                      icon: Icons.travel_explore,
                      label: "Future",
                      targetCategory: "Relationship Reflections",
                      targetSubCategory: "Shared Milestones",
                    ),
                    _buildNavigableCategoryIcon(
                      icon: Icons.favorite,
                      label: "Values",
                      targetCategory: "Aspirations",
                      targetSubCategory: "Guiding Principles",
                    ),
                    _buildNavigableCategoryIcon(
                      icon: Icons.psychology,
                      label: "Deep",
                      targetCategory: "Emotional Landscape",
                      targetSubCategory: "Inner Depths",
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Center(
                  child: TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const QuestionsScreen(initialTabIndex: 1),
                        ),
                      );
                    },
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text("View All"),
                        SizedBox(width: 4),
                        Icon(Icons.arrow_forward, size: 16),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNavigableCategoryIcon({
    required IconData icon,
    required String label,
    required String targetCategory,
    required String targetSubCategory,
  }) {
    // ... (unchanged)
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => QuestionsScreen(
              initialTabIndex: 1,
              initialCategory: targetCategory,
              initialSubCategory: targetSubCategory,
            ),
          ),
        );
      },
      child: Column(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: colorScheme.primary,
              size: 20,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}