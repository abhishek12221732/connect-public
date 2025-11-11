import 'package:flutter/material.dart';

class CalendarHeader extends StatelessWidget {
  final String monthYearLabel;
  final VoidCallback onPrevMonth;
  final VoidCallback onNextMonth;
  final VoidCallback onToday;
  final VoidCallback? onMonthYearTap;

  const CalendarHeader({
    required this.monthYearLabel,
    required this.onPrevMonth,
    required this.onNextMonth,
    required this.onToday,
    this.onMonthYearTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: colorScheme.primary.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Previous month button
          Container(
            decoration: BoxDecoration(
              color: colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: IconButton(
              icon: Icon(Icons.chevron_left,
                  size: 20, color: colorScheme.primary),
              onPressed: onPrevMonth,
              tooltip: 'Previous Month',
              padding: const EdgeInsets.all(6),
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
          ),

          const SizedBox(width: 8),

          // Month/Year display with tap to change
          Expanded(
            child: GestureDetector(
              onTap: onMonthYearTap,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: colorScheme.primary.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      monthYearLabel,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: colorScheme.primary,
                      ),
                    ),
                    if (onMonthYearTap != null) ...[
                      const SizedBox(width: 6),
                      Icon(
                        Icons.arrow_drop_down,
                        color: colorScheme.primary.withOpacity(0.7),
                        size: 16,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(width: 8),

          // Next month button
          Container(
            decoration: BoxDecoration(
              color: colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: IconButton(
              icon: Icon(Icons.chevron_right,
                  size: 20, color: colorScheme.primary),
              onPressed: onNextMonth,
              tooltip: 'Next Month',
              padding: const EdgeInsets.all(6),
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
          ),

          const SizedBox(width: 6),

          // Today button
          Container(
            decoration: BoxDecoration(
              color: colorScheme.primary,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: colorScheme.primary.withOpacity(0.3),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: IconButton(
              icon: Icon(Icons.today, color: colorScheme.onPrimary, size: 16),
              tooltip: 'Go to Today',
              onPressed: onToday,
              padding: const EdgeInsets.all(6),
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
          ),
        ],
      ),
    );
  }
}