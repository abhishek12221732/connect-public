import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:feelings/providers/date_idea_provider.dart';
import 'package:feelings/providers/user_provider.dart';
import 'package:feelings/providers/couple_provider.dart'; 
import 'package:feelings/providers/bucket_list_provider.dart';
// ✨ [ADD] Import RhmRepository
import 'package:feelings/features/rhm/repository/rhm_repository.dart'; 
import 'package:feelings/features/calendar/screens/add_event_wizard_screen.dart';
import 'package:feelings/features/date_night/models/date_idea.dart';
import 'package:feelings/widgets/pulsing_dots_indicator.dart'; 

class GeneratedDateIdeaScreen extends StatefulWidget {
  // ... (unchanged)
  const GeneratedDateIdeaScreen({super.key});

  @override
  State<GeneratedDateIdeaScreen> createState() => _GeneratedDateIdeaScreenState();
}

class _GeneratedDateIdeaScreenState extends State<GeneratedDateIdeaScreen> {
  // ... (state variables _dateIdeaProvider are unchanged) ...
  DateIdeaProvider? _dateIdeaProvider;

  @override
  void initState() {
    // ... (unchanged)
    super.initState();
  }

  @override
  void didChangeDependencies() {
    // ... (unchanged)
    super.didChangeDependencies();
    _dateIdeaProvider = Provider.of<DateIdeaProvider>(context, listen: false);
  }

  @override
  void dispose() {
    // ... (unchanged)
    super.dispose();
  }

  void _addToCalendar(BuildContext context, DateIdea idea) {
    // ... (unchanged)
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddEventWizardScreen(
          initialTitle: idea.ideaName,
          initialDescription: idea.description,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final userProvider = Provider.of<UserProvider>(context);
    final userId = userProvider.getUserId() ?? '';
    final coupleId = userProvider.coupleId ?? '';
    final partnerId = userProvider.getPartnerId() ?? '';
    
    return FutureBuilder<bool>(
      future: userProvider.coupleId != null
          ? Provider.of<CoupleProvider>(context, listen: false).isRelationshipInactive(userProvider.coupleId!)
          : Future.value(false), 
      builder: (context, snapshot) {
        // ... (rest of the build method until the Bucket List button) ...
        final bool isInactive = snapshot.data ?? false;

        return Scaffold(
          backgroundColor: theme.scaffoldBackgroundColor,
          appBar: AppBar(
             title: Consumer<DateIdeaProvider>(
               builder: (context, provider, _) {
                 final idea = provider.generatedIdea;
                 final isSuggestion = idea != null ? provider.isCurrentSuggestion(idea.id) : false;
                 return Text(isSuggestion ? 'Suggested Date Idea' : 'Your Date Idea');
               },
             ),
             actions: [
               Consumer<DateIdeaProvider>(
                 builder: (context, provider, _) {
                   final idea = provider.generatedIdea;
                   if (idea == null) return const SizedBox.shrink();
                   final isFav = provider.isFavorite(idea.id);
                   return IconButton(
                     icon: Icon(
                       isFav ? Icons.favorite : Icons.favorite_border,
                       color: isFav ? colorScheme.error : null,
                     ),
                     tooltip: isFav ? 'Remove from Favorites' : 'Add to Favorites',
                     onPressed: isInactive ? null : () async {
                       // ... (favorite logic unchanged)
                        if (isFav) {
                          await provider.removeFavorite(idea.id, userId);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: const Text('Removed from favorites'), backgroundColor: colorScheme.error),
                            );
                          }
                        } else {
                          await provider.addFavorite(idea, userId);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: const Text('Added to favorites'), backgroundColor: colorScheme.primary),
                            );
                          }
                        }
                     },
                   );
                 },
               ),
             ],
           ),
          body: Consumer<DateIdeaProvider>(
            builder: (context, provider, child) {
              final idea = provider.generatedIdea;

              if (provider.isLoading && idea == null) {
                return _buildLoadingScreen();
              }
              if (idea == null) {
                return _buildEmptyState(theme, colorScheme);
              }

              return CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // ... (Image Card unchanged) ...
                           SizedBox(
                             height: 300,
                             child: Card(
                               clipBehavior: Clip.antiAlias,
                               child: Stack(
                                 children: [
                                   Positioned.fill(
                                     child: CachedNetworkImage(
                                       imageUrl: _getCategoryImage(idea.category),
                                       fit: BoxFit.cover,
                                       placeholder: (context, url) => Container(color: colorScheme.surfaceContainerHighest),
                                       errorWidget: (context, url, error) => Container(color: colorScheme.surfaceContainerHighest),
                                     ),
                                   ),
                                   Positioned.fill(
                                     child: Container(
                                       decoration: BoxDecoration(
                                         gradient: LinearGradient(
                                           begin: Alignment.topCenter,
                                           end: Alignment.bottomCenter,
                                           colors: [
                                             colorScheme.surface.withOpacity(0.8),
                                             colorScheme.surface.withOpacity(0.7),
                                             colorScheme.surface.withOpacity(0.9),
                                           ],
                                           stops: const [0.0, 0.6, 1.0],
                                         ),
                                       ),
                                     ),
                                   ),
                                   Padding(
                                     padding: const EdgeInsets.all(16),
                                     child: Column(
                                       crossAxisAlignment: CrossAxisAlignment.center,
                                       children: [
                                         const SizedBox(height: 12),
                                         Text(
                                           idea.ideaName,
                                           style: theme.textTheme.headlineMedium?.copyWith(height: 1.2),
                                           textAlign: TextAlign.center,
                                         ),
                                         const Spacer(),
                                         Text(
                                           idea.description,
                                           style: theme.textTheme.bodyLarge?.copyWith(height: 1.5),
                                           textAlign: TextAlign.center,
                                         ),
                                       ],
                                     ),
                                   ),
                                 ],
                               ),
                             ),
                           ),
                          const SizedBox(height: 16),
                          // ... (What You'll Need section unchanged) ...
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.checklist, color: colorScheme.primary, size: 20),
                                    const SizedBox(width: 6),
                                    Text(
                                      "What You'll Need",
                                      style: theme.textTheme.titleMedium,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                ...idea.whatYoullNeed.map((item) => Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 2),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        margin: const EdgeInsets.only(top: 6),
                                        width: 4,
                                        height: 4,
                                        decoration: BoxDecoration(
                                          color: colorScheme.primary,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          item,
                                          style: theme.textTheme.bodyMedium?.copyWith(height: 1.3),
                                        ),
                                      ),
                                    ],
                                  ),
                                )),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          // ... (Action buttons container) ...
                          Container(
                             padding: const EdgeInsets.all(16),
                             decoration: BoxDecoration(
                               color: colorScheme.surfaceContainerHighest,
                               borderRadius: BorderRadius.circular(12),
                             ),
                             child: Column(
                               children: [
                                 Consumer<DateIdeaProvider>(
                                   builder: (context, provider, _) {
                                     // ... (Suggest/Done/Cancel logic unchanged) ...
                                      final isSuggestion = provider.isCurrentSuggestion(idea.id);
                                      if (isSuggestion) {
                                        return Column(
                                          children: [
                                            SizedBox(
                                              width: double.infinity,
                                              child: ElevatedButton.icon(
                                                onPressed: isInactive ? null : () async {
                                                  if (provider.currentSuggestionCoupleId != null && provider.currentSuggestionId != null) {
                                                    await provider.markSuggestionAsDone(
                                                      provider.currentSuggestionCoupleId!,
                                                      provider.currentSuggestionId!,
                                                      userId,
                                                    );
                                                    if (mounted) {
                                                      ScaffoldMessenger.of(context).showSnackBar(
                                                        SnackBar(content: const Text('Marked as done!'), backgroundColor: colorScheme.secondary),
                                                      );
                                                      Navigator.pop(context);
                                                    }
                                                  }
                                                },
                                                icon: const Icon(Icons.check_circle, size: 18),
                                                label: const Text('Mark as Done'),
                                                style: ElevatedButton.styleFrom(backgroundColor: colorScheme.secondary, foregroundColor: colorScheme.onSecondary),
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            SizedBox(
                                              width: double.infinity,
                                              child: OutlinedButton.icon(
                                                onPressed: isInactive ? null : () async {
                                                  if (provider.currentSuggestionCoupleId != null && provider.currentSuggestionId != null) {
                                                    await provider.cancelSuggestion(
                                                      coupleId: provider.currentSuggestionCoupleId!,
                                                      suggestionId: provider.currentSuggestionId!,
                                                      currentUserId: userId,
                                                      partnerId: partnerId,
                                                      sendPushNotification: userProvider.sendPushNotification,
                                                    );
                                                    if (mounted) {
                                                      ScaffoldMessenger.of(context).showSnackBar(
                                                        SnackBar(content: const Text('Date idea canceled'), backgroundColor: colorScheme.secondary),
                                                      );
                                                      Navigator.pop(context);
                                                    }
                                                  }
                                                },
                                                icon: const Icon(Icons.cancel, size: 18),
                                                label: const Text('Cancel Date'),
                                                style: OutlinedButton.styleFrom(foregroundColor: colorScheme.secondary, side: BorderSide(color: colorScheme.secondary)),
                                              ),
                                            ),
                                          ],
                                        );
                                      } else {
                                        return SizedBox(
                                          width: double.infinity,
                                          child: ElevatedButton.icon(
                                            onPressed: isInactive ? null : () async {
                                              await provider.suggestDateIdeaToPartner(idea: idea, coupleId: coupleId, currentUserId: userId, partnerId: partnerId, sendPushNotification: userProvider.sendPushNotification);
                                              if (mounted) {
                                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Suggested to your partner!')));
                                              }
                                            },
                                            icon: const Icon(Icons.chat, size: 18),
                                            label: const Text('Suggest to Partner'),
                                          ),
                                        );
                                      }
                                   },
                                 ),
                                 const SizedBox(height: 12),
                                 Row(
                                   children: [
                                     Expanded(child: OutlinedButton.icon(onPressed: isInactive ? null : () => _addToCalendar(context, idea), icon: const Icon(Icons.calendar_today, size: 16), label: const Text('Calendar'))),
                                     const SizedBox(width: 8),
                                     Expanded(
                                       child: OutlinedButton.icon(
                                         // ✨ [MODIFY] Update the onPressed handler
                                         onPressed: isInactive ? null : () async {
                                           final bucketListProvider = Provider.of<BucketListProvider>(context, listen: false);
                                           // ✨ [ADD] Read RhmRepository
                                           final rhmRepository = context.read<RhmRepository>(); 
                                           
                                           if (!bucketListProvider.isInitialized) {
                                              // ✨ [MODIFY] Pass rhmRepository here
                                              await bucketListProvider.initialize(
                                                 coupleId: coupleId, 
                                                 userId: userId, 
                                                 rhmRepository: rhmRepository, // Pass it
                                              );
                                           }
                                           await bucketListProvider.addItem(idea.ideaName, isDateIdea: true, dateId: idea.id, description: idea.description, category: idea.category, whatYoullNeed: idea.whatYoullNeed);
                                           if (mounted) {
                                             ScaffoldMessenger.of(context).showSnackBar(
                                               SnackBar(content: Text('Added "${idea.ideaName}" to your bucket list!'), backgroundColor: colorScheme.secondary),
                                             );
                                           }
                                         },
                                         icon: const Icon(Icons.list, size: 16),
                                         label: const Text('Bucket List', style: TextStyle(fontSize: 12)),
                                         style: OutlinedButton.styleFrom(foregroundColor: colorScheme.secondary, side: BorderSide(color: colorScheme.secondary)),
                                       ),
                                     ),
                                   ],
                                 ),
                                 const SizedBox(height: 12),
                                 // ... (Generate Another Idea button unchanged) ...
                                 Consumer<DateIdeaProvider>(
                                   builder: (context, provider, _) {
                                     return TextButton.icon(
                                       onPressed: () async {
                                         await provider.generateDateIdea(userId: userId, coupleId: coupleId, context: context);
                                       },
                                       icon: const Icon(Icons.refresh, size: 16),
                                       label: const Text('Generate Another Idea'),
                                     );
                                   },
                                 ),
                               ],
                             ),
                           ),
                          if (isInactive)
                            Padding(
                              padding: const EdgeInsets.only(top: 16.0),
                              child: Text(
                                'Actions are disabled because your relationship is inactive.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  // ... (_getCategoryImage, _buildLoadingScreen, _buildAnimatedDot, _buildEmptyState are unchanged) ...
   String _getCategoryImage(String category) {
    final categoryImageMap = {
      'At Home/Adventurous': 'https://cdn.jsdelivr.net/gh/abhishek-codebreaker/flutter-app-images@master/images/at_home_adventurous.png',
      'At Home/Creative': 'https://cdn.jsdelivr.net/gh/abhishek-codebreaker/flutter-app-images@master/images/at_home_creative.png',
      'At Home/Fun & Playful': 'https://cdn.jsdelivr.net/gh/abhishek-codebreaker/flutter-app-images@master/images/at_home_fun_playful.png',
      'At Home/Learning': 'https://cdn.jsdelivr.net/gh/abhishek-codebreaker/flutter-app-images@master/images/at_home_learning.png',
      'At Home/Relaxing': 'https://cdn.jsdelivr.net/gh/abhishek-codebreaker/flutter-app-images@master/images/at_home_relaxing.png',
      'At Home/Romantic': 'https://cdn.jsdelivr.net/gh/abhishek-codebreaker/flutter-app-images@master/images/at_home_romantic.png',
      'Getaway/Adventurous': 'https://cdn.jsdelivr.net/gh/abhishek-codebreaker/flutter-app-images@master/images/getaway_adventurous.png',
      'Getaway/Relaxing': 'https://cdn.jsdelivr.net/gh/abhishek-codebreaker/flutter-app-images@master/images/getaway_relaxing.png',
      'Getaway/Romantic': 'https://cdn.jsdelivr.net/gh/abhishek-codebreaker/flutter-app-images@master/images/getaway_romantic.png',
      'Out & About/Adventurous': 'https://cdn.jsdelivr.net/gh/abhishek-codebreaker/flutter-app-images@master/images/out_about_adventurous.png',
      'Out & About/Creative': 'https://cdn.jsdelivr.net/gh/abhishek-codebreaker/flutter-app-images@master/images/out_about_creative.png',
      'Out & About/Fun & Playful': 'https://cdn.jsdelivr.net/gh/abhishek-codebreaker/flutter-app-images@master/images/out_about_fun_playful.png',
      'Out & About/Learning': 'https://cdn.jsdelivr.net/gh/abhishek-codebreaker/flutter-app-images@master/images/out_about_learning.png',
      'Out & About/Relaxing': 'https://cdn.jsdelivr.net/gh/abhishek-codebreaker/flutter-app-images@master/images/out_about_relaxing.png',
      'Out & About/Romantic': 'https://cdn.jsdelivr.net/gh/abhishek-codebreaker/flutter-app-images@master/images/out_about_romantic.png',
      'Outdoors/Adventurous': 'https://cdn.jsdelivr.net/gh/abhishek-codebreaker/flutter-app-images@master/images/outdoors_adventurous.png',
      'Outdoors/Creative': 'https://cdn.jsdelivr.net/gh/abhishek-codebreaker/flutter-app-images@master/images/outdoors_creative.png',
      'Outdoors/Fun & Playful': 'https://cdn.jsdelivr.net/gh/abhishek-codebreaker/flutter-app-images@master/images/outdoors_fun_playful.png',
      'Outdoors/Learning': 'https://cdn.jsdelivr.net/gh/abhishek-codebreaker/flutter-app-images@master/images/outdoors_learning.png',
      'Outdoors/Relaxing': 'https://cdn.jsdelivr.net/gh/abhishek-codebreaker/flutter-app-images@master/images/outdoors_relaxing.png',
      'Outdoors/Romantic': 'https://cdn.jsdelivr.net/gh/abhishek-codebreaker/flutter-app-images@master/images/outdoors_romantic.png',
    };
    return categoryImageMap[category] ?? 'https://cdn.jsdelivr.net/gh/abhishek-codebreaker/flutter-app-images@master/images/couple.png';
  }

Widget _buildLoadingScreen() {
  final theme = Theme.of(context);
  final colorScheme = theme.colorScheme;
  
  return Container(
    color: theme.scaffoldBackgroundColor,
    child: Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          PulsingDotsIndicator(
            colors: [
              colorScheme.primary,
              colorScheme.primary,
              colorScheme.primary,
            ],
            size: 60.0, 
          ),
          
          const SizedBox(height: 24),
          
          Text(
            'Generating Date Idea', 
            style: theme.textTheme.titleMedium?.copyWith(
              color: colorScheme.onSurface.withOpacity(0.8),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
}
Widget _buildAnimatedDot(int index) {
  final colorScheme = Theme.of(context).colorScheme;

  return TweenAnimationBuilder<double>(
    tween: Tween(begin: 0.0, end: 1.0),
    duration: Duration(milliseconds: 800 + (index * 200)),
    builder: (context, value, child) {
      return Transform.scale(
        scale: 0.5 + (0.5 * value),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: colorScheme.primary.withOpacity(0.3 + (0.7 * value)),
            shape: BoxShape.circle,
          ),
        ),
      );
    },
    onEnd: () {
      if (mounted) {
        setState(() {});
      }
    },
  );
}
  Widget _buildEmptyState(ThemeData theme, ColorScheme colorScheme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.lightbulb_outline, size: 64, color: colorScheme.onSurface.withOpacity(0.5)),
          const SizedBox(height: 16),
          Text(
            'No idea generated yet',
            style: theme.textTheme.titleLarge?.copyWith(color: colorScheme.onSurface.withOpacity(0.7)),
          ),
        ],
      ),
    );
  }
}