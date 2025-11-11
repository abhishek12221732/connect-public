import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'common_feed_widgets.dart'; // Assuming AnswerChip, OtherAnswerChip, QuoteCard are here and are themed

class UserCheckInFeedCard extends StatelessWidget {
  final dynamic checkIn;
  
  const UserCheckInFeedCard({
    required this.checkIn, 
    super.key
  });

  @override
  Widget build(BuildContext context) {
    // THEME: Get theme and colorScheme from context
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final dateStr = DateFormat('EEE, MMM d, yyyy').format(checkIn.date);
    final answers = checkIn.answers;
    // NOTE: The colors in this list are semantic and intentionally preserved.
    // The AnswerChip widget itself is themed to handle them correctly.
    final keyMetrics = [
      {'key': 'overall_satisfaction', 'label': 'Satisfaction', 'icon': Icons.emoji_emotions, 'color': Colors.green},
      {'key': 'feeling_connected', 'label': 'Connection', 'icon': Icons.favorite, 'color': Colors.pink},
      {'key': 'stress_level', 'label': 'Stress', 'icon': Icons.bolt, 'color': Colors.orange},
      {'key': 'communication_quality', 'label': 'Communication', 'icon': Icons.chat_bubble_outline, 'color': Colors.blue},
      {'key': 'gratitude_score', 'label': 'Gratitude', 'icon': Icons.volunteer_activism, 'color': Colors.purple},
      {'key': 'physical_intimacy', 'label': 'Intimacy', 'icon': Icons.nightlife, 'color': Colors.deepPurple},
      {'key': 'emotional_support', 'label': 'Support', 'icon': Icons.handshake, 'color': Colors.teal},
      {'key': 'fun_together', 'label': 'Fun', 'icon': Icons.celebration, 'color': Colors.amber},
      {'key': 'shared_goals', 'label': 'Goals', 'icon': Icons.flag, 'color': Colors.indigo},
    ];

    // Original debug prints and defensive logic preserved
    print('UserCheckInFeedCard: checkIn type: ${checkIn.runtimeType}');
    print('UserCheckInFeedCard: sharedInsights runtimeType: ${checkIn.sharedInsights.runtimeType}, value: ${checkIn.sharedInsights}');
    
    List insightsList;
    try {
      insightsList = (checkIn.sharedInsights is List)
          ? checkIn.sharedInsights
          : (checkIn.sharedInsights == null
              ? []
              : [checkIn.sharedInsights]);
    } catch (e) {
      insightsList = [];
    }

    return Card(
      // THEME: Use a theme-aware background color
      color: colorScheme.primary.withOpacity(0.2),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      margin: const EdgeInsets.symmetric(vertical: 12),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.assignment_turned_in, color: colorScheme.primary, size: 22),
                const SizedBox(width: 8),
                Text(dateStr, style: theme.textTheme.titleMedium),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withOpacity(0.13),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Full Check-In', 
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colorScheme.primary, 
                      fontWeight: FontWeight.bold
                    )
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: keyMetrics.where((m) => answers[m['key']] != null).map((m) => AnswerChip(
                icon: m['icon'] as IconData,
                label: m['label'] as String,
                value: answers[m['key']].toString(),
                color: m['color'] as Color,
              )).toList(),
            ),
            const SizedBox(height: 12),
            if (answers.keys.any((k) => !keyMetrics.any((m) => m['key'] == k))) ...[
              const Divider(height: 24),
              Text('Other Answers:', style: theme.textTheme.titleSmall),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: answers.entries.where((entry) => !keyMetrics.any((m) => m['key'] == entry.key)).map((entry) => OtherAnswerChip(
                  label: entry.key,
                  value: entry.value.toString(),
                )).toList(),
              ),
            ],
            if (insightsList.isNotEmpty) ...[
              const Divider(height: 24),
              Text('Shared Insights:', style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              ...insightsList.map((insight) => QuoteCard(text: insight.toString())),
            ],
          ],
        ),
      ),
    );
  }
}