import 'package:flutter/material.dart';
import '../calendar_types.dart';

class CalendarLegend extends StatelessWidget {
  const CalendarLegend({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      elevation: 2,
      shadowColor: colorScheme.primary.withOpacity(0.1),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Event Categories:',
              style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 6,
              children: [
                _buildLegendItem(context, 'Events', getCalendarCategoryColor('event')),
                _buildLegendItem(context, 'Date Ideas', getCalendarCategoryColor('date_idea')),
                _buildLegendItem(context, 'Anniversaries', getCalendarCategoryColor('anniversary')),
                _buildLegendItem(context, 'Check-ins', getCalendarCategoryColor('check_in')),
                // Note: 'milestone' is not a defined category in calendar_types, using 'goal' as an example.
                // _buildLegendItem(context, 'Milestones', getCalendarCategoryColor('goal')),
                _buildLegendItem(context, 'Birthdays', getCalendarCategoryColor('birthday')),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  'Reminders: ',
                  style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurfaceVariant),
                ),
                const SizedBox(width: 4),
                Icon(Icons.alarm, size: 12, color: colorScheme.secondary),
                const SizedBox(width: 4),
                Text(
                  'Events with reminders',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(BuildContext context, String label, Color color) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: colorScheme.surface, width: 1),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}