import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:feelings/providers/dynamic_actions_provider.dart'; // Ensure this path is correct

/// A new, taller, and more interactive RHM Meter widget.
///
/// This widget is designed to be a centerpiece of the home screen.
/// - Tapping the main meter area navigates to the details screen.
/// - The bottom section displays clear, always-visible call-to-action buttons.
/// - The card's styling (gradient and border) dynamically updates with the score.
class InteractiveRhmMeter extends StatelessWidget {
  final int score;
  final VoidCallback onNavigateToDetails;

  const InteractiveRhmMeter({
    super.key,
    required this.score,
    required this.onNavigateToDetails,
  });

  // Helper to get status color and text based on score
  ({String status, Color color}) _getStatus(int score) {
    if (score >= 85) {
      return (status: 'Thriving', color: Colors.green.shade600);
    } else if (score >= 65) {
      return (status: 'Connected', color: Colors.blue.shade600);
    } else if (score >= 40) {
      return (status: 'Steady', color: Colors.yellow.shade800);
    } else if (score >= 20) {
      return (status: 'Needs Nurturing', color: Colors.orange.shade600);
    } else {
      return (status: 'Needs Care', color: Colors.red.shade600);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusInfo = _getStatus(score);
    final startColor = statusInfo.color.withOpacity(0.1);
    final endColor = theme.colorScheme.surface;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [startColor, endColor, endColor],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: const [0.0, 0.4, 1.0], // Gradient fades quickly in the top half
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: statusInfo.color.withOpacity(0.25)),
        boxShadow: [
          BoxShadow(
            color: statusInfo.color.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      // ClipRRect ensures the ripple effect from InkWell respects the border radius
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Column(
          children: [
            // --- 1. Main Meter & Navigation Section ---
            _buildMeterSection(context, statusInfo),
            
            // --- 2. Dynamic Actions Section ---
            _buildActionsSection(context, statusInfo),
          ],
        ),
      ),
    );
  }

  /// Builds the top, tappable section that shows the score and navigates to details.
  Widget _buildMeterSection(BuildContext context, ({String status, Color color}) statusInfo) {
    final theme = Theme.of(context);
    final double progress = score / 100.0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onNavigateToDetails,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
          child: Row(
            children: [
              // The Text Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Relationship Health',
                      style: theme.textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Status: ${statusInfo.status}',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: statusInfo.color,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Tap for details & ways to boost',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              // The Dial
              SizedBox(
                width: 85,
                height: 85,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CircularProgressIndicator(
                      value: 1.0,
                      strokeWidth: 9,
                      valueColor:
                          AlwaysStoppedAnimation(statusInfo.color.withOpacity(0.15)),
                    ),
                    CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 9,
                      valueColor: AlwaysStoppedAnimation(statusInfo.color),
                      strokeCap: StrokeCap.round,
                    ),
                    Center(
                      child: Text(
                        '$score%',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: statusInfo.color,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Builds the bottom section containing the list of dynamic actions.
  Widget _buildActionsSection(BuildContext context, ({String status, Color color}) statusInfo) {
    final actionsProvider = context.watch<DynamicActionsProvider>();
    // Take the top 3 actions to ensure the widget has a consistent, tall height
    final suggestedActions = actionsProvider.getDynamicActions().take(3).toList();
    final theme = Theme.of(context);

    if (suggestedActions.isEmpty) return const SizedBox.shrink();

    return Container(
      // A slightly different background to differentiate the action panel
      color: theme.colorScheme.onSurface.withOpacity(0.03),
      child: Column(
        children: [
          // Generate the list of actions with dividers
          for (int i = 0; i < suggestedActions.length; i++) ...[
            // Divider on top of the first item
            if (i == 0)
              Divider(
                height: 1,
                thickness: 1,
                color: theme.dividerColor.withOpacity(0.05),
              ),
            _buildActionButton(
              context:context,
              icon: suggestedActions[i].icon,
              label: suggestedActions[i].label,
              color: statusInfo.color,
              onPressed: suggestedActions[i].actionBuilder(context),
            ),
            // Divider between items
            if (i < suggestedActions.length - 1)
              Divider(
                height: 1,
                thickness: 1,
                indent: 68, // Indent past the icon
                color: theme.dividerColor.withOpacity(0.05),
              ),
          ]
        ],
      ),
    );
  }

  /// Builds a single, stylish action button row (like a ListTile).
  Widget _buildActionButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Row(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(width: 20),
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: theme.colorScheme.onSurface.withOpacity(0.4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
