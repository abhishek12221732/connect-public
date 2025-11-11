import 'package:flutter/material.dart';
import 'mini_line_chart.dart';

class MetricCard extends StatelessWidget {
  final dynamic metric;
  final List<dynamic> userCheckIns;
  final bool selected;
  final VoidCallback onTap;

  const MetricCard({
    required this.metric, 
    required this.userCheckIns, 
    required this.selected, 
    required this.onTap, 
    super.key
  });

  @override
  Widget build(BuildContext context) {
    // THEME: Get theme and colorScheme from context
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Original logic for calculating values remains the same
    final values = userCheckIns.map((c) => c.answers[metric.key]).where((v) => v != null).map((v) => (v as num).toDouble()).toList();
    final current = values.isNotEmpty ? values.first : 0.0;
    final best = values.isNotEmpty ? values.reduce((a, b) => a > b ? a : b) : 0.0;
    final prev = values.length > 1 ? values[1] : current;
    final change = current - prev;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        width: 160,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          // THEME: Use theme colors for background and border
          color: selected ? colorScheme.primary : colorScheme.surface,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              // THEME: Use theme colors for shadow
              color: colorScheme.primary.withOpacity(selected ? 0.18 : 0.07),
              blurRadius: selected ? 16 : 8,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(color: selected ? colorScheme.primary : theme.dividerColor, width: 2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // THEME: Use theme colors for icon
                Icon(_getMetricIcon(metric.label), color: selected ? colorScheme.onPrimary : colorScheme.primary, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    metric.label, 
                    // THEME: Use theme text styles and colors
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: selected ? colorScheme.onPrimary : colorScheme.primary
                    )
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Expanded(
              child: values.length > 1
                  // THEME: Pass theme colors to the chart
                  ? MiniLineChart(values: values, accent: selected ? colorScheme.onPrimary : colorScheme.primary, min: metric.min, max: metric.max)
                  : Center(child: Text('No data', style: TextStyle(color: selected ? colorScheme.onPrimary.withOpacity(0.7) : colorScheme.onSurface.withOpacity(0.5), fontSize: 13))),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Now', style: TextStyle(color: selected ? colorScheme.onPrimary.withOpacity(0.7) : colorScheme.onSurface.withOpacity(0.5), fontSize: 12)),
                Text(current.toStringAsFixed(1), style: TextStyle(fontWeight: FontWeight.bold, color: selected ? colorScheme.onPrimary : colorScheme.primary, fontSize: 16)),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Best', style: TextStyle(color: selected ? colorScheme.onPrimary.withOpacity(0.7) : colorScheme.onSurface.withOpacity(0.5), fontSize: 12)),
                Text(best.toStringAsFixed(1), style: TextStyle(fontWeight: FontWeight.bold, color: selected ? colorScheme.onPrimary : colorScheme.primary, fontSize: 14)),
                Text(
                  change == 0.0 ? '' : (change > 0 ? '+${change.toStringAsFixed(1)}' : change.toStringAsFixed(1)),
                  style: TextStyle(
                    // THEME: Use theme colors for status text
                    color: change > 0 
                      ? (selected ? colorScheme.onPrimary : Colors.green) 
                      : (change < 0 ? (selected ? colorScheme.onPrimary : colorScheme.error) 
                      : colorScheme.onSurface.withOpacity(0.5)),
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Helper function remains the same as it's not theme-related
  IconData _getMetricIcon(String label) {
    switch (label.toLowerCase()) {
      case 'satisfaction':
        return Icons.emoji_emotions;
      case 'connection':
        return Icons.favorite;
      case 'communication':
        return Icons.chat_bubble_outline;
      case 'gratitude':
        return Icons.volunteer_activism;
      case 'stress':
        return Icons.bolt;
      case 'intimacy':
        return Icons.nightlife;
      case 'support':
        return Icons.handshake;
      case 'fun':
        return Icons.celebration;
      case 'goals':
        return Icons.flag;
      default:
        return Icons.insights;
    }
  }
}