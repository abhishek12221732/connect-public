import 'package:flutter/material.dart';

class QuickStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const QuickStat({
    required this.icon,
    required this.label,
    required this.value,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    // THEME: Get theme and colorScheme from context
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            // THEME: Use theme's primary color
            color: colorScheme.primary.withOpacity(0.13),
            shape: BoxShape.circle,
          ),
          padding: const EdgeInsets.all(12),
          child: Icon(icon, color: colorScheme.primary, size: 26),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          // THEME: Use textTheme and a subtle onSurface color
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurface.withOpacity(0.7),
          ),
        ),
        Text(
          value,
          // THEME: Use a prominent text style from the theme
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}