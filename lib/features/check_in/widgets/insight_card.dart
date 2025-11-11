import 'package:flutter/material.dart';

class InsightCard extends StatelessWidget {
  final String insight;
  final int index;

  const InsightCard({
    super.key,
    required this.insight,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    // THEME: Get theme and colorScheme from context
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // THEME: Using a Card widget allows it to be styled by the global cardTheme
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Insight number
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                // THEME: Use a theme-aware color
                color: colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(
                child: Text(
                  '${index + 1}',
                  // THEME: Use a text style and color from the theme
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: colorScheme.primary,
                  ),
                ),
              ),
            ),
            
            const SizedBox(width: 12),
            
            // Insight text
            Expanded(
              child: Text(
                insight,
                // THEME: Use a text style and color from the theme
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onSurface,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}