import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:ui';
import 'package:animate_do/animate_do.dart';
import 'package:feelings/providers/date_idea_provider.dart';
import 'package:feelings/providers/user_provider.dart';
import 'package:feelings/features/date_night/screens/generated_date_idea_screen.dart';
import 'package:feelings/features/date_night/models/date_idea.dart';

class SuggestionCard extends StatefulWidget {
  final Map<String, dynamic> suggestion;
  final String userId;
  final String? coupleId;

  const SuggestionCard({
    super.key,
    required this.suggestion,
    required this.userId,
    this.coupleId,
  });

  @override
  State<SuggestionCard> createState() => _SuggestionCardState();
}

class _SuggestionCardState extends State<SuggestionCard> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    final isSender = widget.suggestion['suggestedBy'] == widget.userId;
    final userProvider = Provider.of<UserProvider>(context);
    final fullPartnerName = userProvider.partnerData?['name'] ?? 'Partner';
    final partnerName = _getFirstName(fullPartnerName);

    // Using theme container colors for a more integrated look.
    final cardBgColor = isSender ? colorScheme.secondary : colorScheme.tertiaryContainer;
    final onCardBgColor = isSender ? colorScheme.onSecondary : colorScheme.onTertiaryContainer;

    // Added a subtle fade-in animation for when the card appears.
    return FadeInUp(
      duration: const Duration(milliseconds: 500),
      from: 20,
      child: Card(
        // Using the defined container color and respecting the global CardTheme.
        color: cardBgColor,
        
        // --- THIS LINE WAS CHANGED ---
        // Changed from horizontal: 16 to horizontal: 12 to match EventsBox
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), 
        
        shape: theme.cardTheme.shape,
        elevation: 0, // Let the container color provide the visual lift.
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _openGeneratedDateIdeaScreen(context),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(context, isSender, partnerName, onCardBgColor),
                const SizedBox(height: 12),
                _buildTitleAndAction(context, onCardBgColor),
                if (widget.suggestion['timestamp'] != null) ...[
                  const SizedBox(height: 16),
                  _buildFooter(context, onCardBgColor),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Broke the build method into smaller, more readable parts.
  Widget _buildHeader(BuildContext context, bool isSender, String partnerName, Color textColor) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        // The chip color is a slightly transparent version of the text color.
        color: textColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        isSender ? 'You suggested this' : 'Suggested by $partnerName',
        style: theme.textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.bold,
          color: textColor,
        ),
      ),
    );
  }

  Widget _buildTitleAndAction(BuildContext context, Color textColor) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Text(
            widget.suggestion['ideaName'] ?? 'Date Idea',
            style: theme.textTheme.titleLarge?.copyWith(
              color: textColor,
              fontWeight: FontWeight.bold,
              height: 1.3,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 16),
        // Replaced IconButton with a more prominent FilledButton.tonal.
        FilledButton.tonal(
          onPressed: _markAsDone,
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.all(12),
            backgroundColor: colorScheme.surface,
          ),
          child: Icon(
            Icons.check_circle,
            color: colorScheme.primary,
          ),
        ),
      ],
    );
  }

  Widget _buildFooter(BuildContext context, Color textColor) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(Icons.access_time, size: 14, color: textColor.withOpacity(0.7)),
        const SizedBox(width: 6),
        Text(
          _formatTimestamp(widget.suggestion['timestamp']),
          style: theme.textTheme.bodySmall?.copyWith(
            color: textColor.withOpacity(0.7),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // Extracted logic into separate methods for clarity.
  void _markAsDone() async {
    if (widget.coupleId == null || !mounted) return;

    final provider = context.read<DateIdeaProvider>();
    await provider.markSuggestionAsDone(widget.coupleId!, widget.suggestion['id'], widget.userId);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Marked "${widget.suggestion['ideaName']}" as done!'),
          backgroundColor: Theme.of(context).colorScheme.primary,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _openGeneratedDateIdeaScreen(BuildContext context) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _buildScreenOpeningAnimation(context),
    );

    try {
      final provider = Provider.of<DateIdeaProvider>(context, listen: false);
      final dateIdeaId = widget.suggestion['dateIdeaId'] ?? '';
      
      DateIdea? dateIdea;
      if (dateIdeaId.isNotEmpty) {
        dateIdea = await provider.getDateIdeaById(dateIdeaId);
      }

      final completeDateIdea = dateIdea ?? DateIdea(
        id: dateIdeaId,
        ideaName: widget.suggestion['ideaName'] ?? '',
        description: widget.suggestion['description'] ?? '',
        category: 'Suggested',
        whatYoullNeed: [],
        preferences: {},
      );

      provider.generatedIdea = completeDateIdea;
      
      if (widget.coupleId != null) {
        provider.setCurrentSuggestion(widget.suggestion['id'], widget.coupleId!, dateIdeaId);
      }

      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const GeneratedDateIdeaScreen()),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading dialog on error
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Could not load date idea.")));
      }
    }
  }

  Widget _buildScreenOpeningAnimation(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 1200),
      builder: (context, value, child) {
        return Container(
          color: colorScheme.scrim.withOpacity(0.3 * value),
          child: Stack(
            children: [
              Positioned.fill(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 5 * value, sigmaY: 5 * value),
                  child: Container(color: Colors.transparent),
                ),
              ),
              Positioned(
                bottom: -MediaQuery.of(context).size.height * (1 - value),
                left: 0,
                right: 0,
                child: Transform.scale(
                  scale: 0.8 + (0.2 * value),
                  child: Container(
                    height: MediaQuery.of(context).size.height * 0.7,
                    decoration: BoxDecoration(
                      color: colorScheme.surface,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(20 * value),
                        topRight: Radius.circular(20 * value),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: theme.shadowColor.withOpacity(0.2 * value),
                          blurRadius: 20 * value,
                          offset: Offset(0, -10 * value),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Container(
                          margin: EdgeInsets.only(top: 12 * value),
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: colorScheme.onSurface.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        Expanded(
                          child: Padding(
                            padding: EdgeInsets.all(24 * value),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                TweenAnimationBuilder<double>(
                                  tween: Tween(begin: 0.0, end: 1.0),
                                  duration: const Duration(milliseconds: 800),
                                  builder: (context, iconValue, child) {
                                    return Transform.scale(
                                      scale: 0.3 + (0.7 * iconValue),
                                      child: Container(
                                        width: 80,
                                        height: 80,
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                            colors: [
                                              colorScheme.primary.withOpacity(0.1),
                                              colorScheme.error.withOpacity(0.1),
                                            ],
                                          ),
                                          borderRadius: BorderRadius.circular(40),
                                          boxShadow: [
                                            BoxShadow(
                                              color: colorScheme.primary.withOpacity(0.2 * iconValue),
                                              blurRadius: 15 * iconValue,
                                              offset: Offset(0, 5 * iconValue),
                                            ),
                                          ],
                                        ),
                                        child: Icon(Icons.favorite, color: colorScheme.error, size: 40 * iconValue),
                                      ),
                                    );
                                  },
                                ),
                                SizedBox(height: 24 * value),
                                TweenAnimationBuilder<double>(
                                  tween: Tween(begin: 0.0, end: 1.0),
                                  duration: const Duration(milliseconds: 600),
                                  builder: (context, textValue, child) {
                                    return Transform.translate(
                                      offset: Offset(0, 30 * (1 - textValue)),
                                      child: Opacity(
                                        opacity: textValue,
                                        child: Text(
                                          'Opening your date idea...',
                                          style: theme.textTheme.titleMedium,
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                SizedBox(height: 20 * value),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: List.generate(3, (index) => _buildAnimatedDot(index, value)),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAnimatedDot(int index, double parentValue) {
    final colorScheme = Theme.of(context).colorScheme;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 400 + (index * 200)),
      builder: (context, value, child) {
        return Transform.scale(
          scale: (0.5 + (0.5 * value)) * parentValue,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: colorScheme.primary.withOpacity(0.3 + (0.7 * value)),
              shape: BoxShape.circle,
            ),
          ),
        );
      },
    );
  }

  String _getFirstName(String fullName) {
    if (fullName.isEmpty) return 'Partner';
    final nameParts = fullName.trim().split(' ');
    return nameParts.first;
  }

  String _formatTimestamp(dynamic timestamp) {
    try {
      if (timestamp is Timestamp) {
        final now = DateTime.now();
        final date = timestamp.toDate();
        final difference = now.difference(date);
        
        if (difference.inDays > 0) {
          return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
        } else if (difference.inHours > 0) {
          return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
        } else if (difference.inMinutes > 0) {
          return '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ago';
        } else {
          return 'Just now';
        }
      }
    } catch (e) {
      // Handle any timestamp parsing errors
    }
    return '';
  }
}