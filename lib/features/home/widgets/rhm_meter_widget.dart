import 'package:flutter/material.dart';

class RhmMeterWidget extends StatelessWidget {
  final int score;
  final VoidCallback onTap;

  const RhmMeterWidget({
    super.key,
    required this.score,
    required this.onTap,
  });

  // ✨ [MODIFIED] Helper to get the status text and color based on the score
  // Removed the 'theme' parameter and now uses constant colors.
  ({String status, Color color, Color progressColor}) _getStatus(int score) {
    if (score >= 85) {
      return (
        status: 'Thriving',
        color: Colors.green, // Vibrant Green
        progressColor: Colors.green.withOpacity(0.2),
      );
    } else if (score >= 65) {
      return (
        status: 'Connected',
        color: Colors.blue, // Bright Blue
        progressColor: Colors.blue.withOpacity(0.2),
      );
    } else if (score >= 40) {
      return (
        status: 'Steady',
        color: Colors.yellow[700] ?? Colors.yellow, // Neutral Yellow
        progressColor: (Colors.yellow[700] ?? Colors.yellow).withOpacity(0.2),
      );
    } else if (score >= 20) {
      return (
        status: 'Needs Nurturing',
        color: Colors.orange, // Warning Orange
        progressColor: Colors.orange.withOpacity(0.2),
      );
    } else {
      return (
        status: 'Needs Care',
        color: Colors.red, // Soft Red
        progressColor: Colors.red.withOpacity(0.2),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // We still need the theme for the widget's container, shadow, and non-status text
    final theme = Theme.of(context); 
    
    // ✨ [MODIFIED] Call _getStatus without the theme
    final statusInfo = _getStatus(score); 
    final double progress = score / 100.0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20.0),
        decoration: BoxDecoration(
          // These colors still use the theme to adapt to light/dark mode
          color: theme.colorScheme.surface, 
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: theme.colorScheme.onSurface.withOpacity(0.05),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: theme.colorScheme.shadow.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // The Dial
            SizedBox(
              width: 70,
              height: 70,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Background track (uses main color with opacity)
                  CircularProgressIndicator(
                    value: 1.0,
                    strokeWidth: 8,
                    valueColor: AlwaysStoppedAnimation<Color>(statusInfo.color.withOpacity(0.2)),
                  ),
                  // Foreground progress (uses full color)
                  CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 8,
                    valueColor: AlwaysStoppedAnimation<Color>(statusInfo.color),
                    strokeCap: StrokeCap.round,
                  ),
                  // Percentage Text (uses new constant color)
                  Center(
                    child: Text(
                      '$score%',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: statusInfo.color,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 20),
            // The Text Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Relationship Health',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface, // Still uses theme
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Status: ${statusInfo.status}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: statusInfo.color, // Uses new constant color
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Tap to see details and how to boost your score.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.6), // Still uses theme
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: theme.colorScheme.onSurface.withOpacity(0.4), // Still uses theme
              size: 28,
            ),
          ],
        ),
      ),
    );
  }
}
