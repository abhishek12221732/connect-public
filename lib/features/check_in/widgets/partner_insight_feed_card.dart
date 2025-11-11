import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'common_feed_widgets.dart'; // Assuming QuoteCard is in here and is themed

class PartnerInsightFeedCard extends StatelessWidget {
  final dynamic group;
  
  const PartnerInsightFeedCard({
    required this.group, 
    super.key
  });

  @override
  Widget build(BuildContext context) {
    // THEME: Get theme and colorScheme from context
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final dateStr = DateFormat('EEE, MMM d, yyyy').format(group.date);

    // THEME: This Card is now styled by your global cardTheme
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 10),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // THEME: Use a distinct theme color for insights
                Icon(Icons.lightbulb, color: colorScheme.secondary, size: 22),
                const SizedBox(width: 8),
                // THEME: Use theme's text style
                Text(dateStr, style: theme.textTheme.titleMedium),
                const Spacer(),
                if (group.isFullCheckIn)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      // THEME: Use theme color for the tag background
                      color: colorScheme.secondary.withOpacity(0.13),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    // THEME: Use theme text style and color for the tag
                    child: Text(
                      'Full Check-In', 
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.secondary, 
                        fontWeight: FontWeight.bold
                      )
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            // Assuming QuoteCard is already themed
            ...group.sharedInsights.map((insight) => QuoteCard(text: insight)).toList(),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              // THEME: Use theme text style and color for the attribution
              child: Text(
                'From ${group.user}', 
                style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.secondary)
              ),
            ),
          ],
        ),
      ),
    );
  }
}