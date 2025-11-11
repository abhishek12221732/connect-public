// lib/features/home/widgets/daily_action_hub.dart

import 'package:auto_size_text/auto_size_text.dart';
import 'package:feelings/features/chat/screens/chat_screen.dart';
import 'package:feelings/features/questions/models/question_model.dart';
import 'package:feelings/providers/dynamic_actions_provider.dart';
import 'package:feelings/providers/question_provider.dart';
import 'package:feelings/providers/user_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class DailyActionHub extends StatefulWidget {
  final QuestionModel? question;

  const DailyActionHub({super.key, this.question});

  @override
  State<DailyActionHub> createState() => _DailyActionHubState();
}

class _DailyActionHubState extends State<DailyActionHub> {
  bool _isActionsExpanded = false;

  void _askQuestion(BuildContext context, QuestionModel? question) async {
    if (question == null) return;
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final userId = userProvider.getUserId();
    if (userId == null) return;

    final bool confirm = await showDialog(
          context: context,
          builder: (BuildContext context) => AlertDialog(
            title: const Text('Discuss in chat?'),
            content: Text('"${question.question}"'),
            actions: <Widget>[
              TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
              TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Ask')),
            ],
          ),
        ) ??
        false;

    if (confirm && context.mounted) {
      final questionProvider = Provider.of<QuestionProvider>(context, listen: false);
      await questionProvider.markQuestionAsDone(userId, question.id, userProvider.coupleId!);
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => ChatScreen(questionToAsk: question.question),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.question == null) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildQuestionCard(context),
          _buildActionsTray(context),
        ],
      ),
    );
  }

  // ✨ WIDGET RESTRUCTURED TO FIX HIT-TESTING
  Widget _buildQuestionCard(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final dailyQuestion = widget.question!;

    const double cardMaxHeight = 180.0;
    const double fabSize = NotchedCardShape.fabSize;
    final double fabPopOutAmount = fabSize / 2.2;

    // This SizedBox creates a larger canvas that includes the overflow area,
    // making the entire button tappable.
    return SizedBox(
      height: cardMaxHeight + fabPopOutAmount,
      child: Stack(
        children: [
          // The card is positioned at the top of the new, larger Stack area.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            // We still constrain the card's height inside its new parent.
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: 160,
                maxHeight: cardMaxHeight,
              ),
              child: Material(
                shape: const NotchedCardShape(),
                clipBehavior: Clip.antiAlias,
                elevation: 0.0,
                child: Container(
                  color: theme.cardTheme.color ?? colorScheme.surface,
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Icon(Icons.psychology_outlined, color: colorScheme.primary, size: 20),
                        const SizedBox(width: 8),
                        Text("Question of the Day", style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.primary, fontWeight: FontWeight.bold)),
                      ]),
                      const SizedBox(height: 8),
                      Expanded(
                        child: AutoSizeText(
                          dailyQuestion.question,
                          style: theme.textTheme.bodyLarge,
                          minFontSize: 14,
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Center(
                        child: ElevatedButton(
                          onPressed: () => _askQuestion(context, dailyQuestion),
                          style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8), textStyle: theme.textTheme.labelLarge),
                          child: const Text("Discuss"),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // The button is now positioned at the bottom of the larger SizedBox.
          Positioned(
            right: NotchedCardShape.fabMargin,
            bottom: 0,
            child: SizedBox(
              width: fabSize,
              height: fabSize,
              child: FloatingActionButton(
                heroTag: 'toggleActions',
                shape: const CircleBorder(),
                elevation: 0.0,
                backgroundColor: colorScheme.primary,
                onPressed: () => setState(() => _isActionsExpanded = !_isActionsExpanded),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  transitionBuilder: (child, animation) {
                    return ScaleTransition(scale: animation, child: child);
                  },
                  child: Icon(
                    _isActionsExpanded ? Icons.close : Icons.flash_on,
                    key: ValueKey<bool>(_isActionsExpanded),
                    color: colorScheme.onPrimary,
                    size: 28,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionsTray(BuildContext context) {
    final theme = Theme.of(context);
    final actionsProvider = context.watch<DynamicActionsProvider>();
    final suggestedActions = actionsProvider.getDynamicActions();

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      height: _isActionsExpanded ? 82.0 : 0.0,
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
      ),
      child: Padding(
        padding: const EdgeInsets.only(top: 16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(suggestedActions.length, (index) {
            final action = suggestedActions[index];
            return AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: _isActionsExpanded ? 1.0 : 0.0,
              child: AnimatedSlide(
                duration: Duration(milliseconds: 400 + (index * 100)),
                curve: Curves.easeOutCubic,
                offset: _isActionsExpanded ? Offset.zero : const Offset(1.5, 0.0),
                child: _buildShortcutIcon(
                  context,
                  icon: action.icon,
                  label: action.label,
                  onPressed: () => action.actionBuilder(context)(),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildShortcutIcon(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: colorScheme.primary, size: 24),
            const SizedBox(height: 4),
            Text(label, style: theme.textTheme.labelMedium),
          ],
        ),
      ),
    );
  }
}

/// A custom shape for the card that features a circular notch in the bottom right corner.
/// The notch is designed to perfectly accommodate a FloatingActionButton.
class NotchedCardShape extends ShapeBorder {
  const NotchedCardShape();

  // Define constants here to be accessed by the widget for perfect alignment
  static const double fabSize = 52.0;
  static const double fabMargin = 16.0;
  static const double cornerRadius = 20.0;
  // The notch radius is the FAB's radius plus a small gap for the "absorbed" look
  static const double notchRadius = (fabSize / 2) + 5;

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.zero;

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) {
    return getOuterPath(rect, textDirection: textDirection);
  }

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    final Path path = Path();

    // The center of the FAB along the x-axis
    final double fabCenterX = rect.right - fabMargin - (fabSize / 2);

    // Start from top-left, after the corner radius
    path.moveTo(rect.left, rect.top + cornerRadius);

    // Top-left corner
    path.quadraticBezierTo(rect.left, rect.top, rect.left + cornerRadius, rect.top);
    // Top edge
    path.lineTo(rect.right - cornerRadius, rect.top);
    // Top-right corner
    path.quadraticBezierTo(rect.right, rect.top, rect.right, cornerRadius);
    // Right edge
    path.lineTo(rect.right, rect.bottom - cornerRadius);
    // Bottom-right corner (leading into the notch)
    path.quadraticBezierTo(rect.right, rect.bottom, rect.right - cornerRadius, rect.bottom);
    // Bottom edge, from the corner to the start of the notch
    path.lineTo(fabCenterX + notchRadius, rect.bottom);

    // The circular notch is carved here
    path.arcToPoint(
      Offset(fabCenterX - notchRadius, rect.bottom),
      radius: const Radius.circular(notchRadius),
      clockwise: false, // This makes the arc go "into" the card
    );

    // Bottom edge, from the end of the notch to the bottom-left corner
    path.lineTo(rect.left + cornerRadius, rect.bottom);
    // Bottom-left corner
    path.quadraticBezierTo(rect.left, rect.bottom, rect.left, rect.bottom - cornerRadius);
    // Left edge
    path.lineTo(rect.left, rect.top + cornerRadius);
    path.close();

    return path;
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {}

  @override
  ShapeBorder scale(double t) => this;
}