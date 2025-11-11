import 'package:flutter/material.dart';

class QuoteCard extends StatelessWidget {
  final String text;
  final bool selected;
  final IconData icon;
  
  const QuoteCard({
    required this.text, 
    this.selected = false, 
    this.icon = Icons.format_quote, 
    super.key
  });

  @override
  Widget build(BuildContext context) {
    // THEME: Get theme and colorScheme from context
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        // THEME: Use theme colors for selected and default states
        color: selected ? colorScheme.primary.withOpacity(0.5) : colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            // THEME: Use theme's shadow color
            color: theme.shadowColor.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          // THEME: Use theme colors for the border
          color: selected ? colorScheme.primary : theme.dividerColor,
          width: selected ? 2 : 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // THEME: Icon color is theme-aware
          Icon(icon, color: colorScheme.primary, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              // THEME: Text style and color are from the theme
              style: theme.textTheme.bodyMedium?.copyWith(
                fontStyle: FontStyle.italic, 
                color: selected ? colorScheme.onPrimary : colorScheme.onSurfaceVariant
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AnswerChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  
  const AnswerChip({
    required this.icon, 
    required this.label, 
    required this.value, 
    required this.color, 
    super.key
  });

  @override
  Widget build(BuildContext context) {
    // THEME: This chip is semantically colored by the 'color' property, which is correct.
    // We just ensure the text style comes from the theme.
    final theme = Theme.of(context);

    return Chip(
      avatar: Icon(icon, color: color, size: 18),
      label: Text('$label: $value'),
      // THEME: Use the global chip theme's label style as a base
      labelStyle: theme.chipTheme.labelStyle?.copyWith(fontWeight: FontWeight.w500),
      backgroundColor: color.withOpacity(0.13),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    );
  }
}

class OtherAnswerChip extends StatelessWidget {
  final String label;
  final String value;
  
  const OtherAnswerChip({
    required this.label, 
    required this.value, 
    super.key
  });

  @override
  Widget build(BuildContext context) {
    // THEME: Get theme from context
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Chip(
      label: Text('${label.replaceAll('_', ' ').toUpperCase()}: $value'),
      // THEME: Use the global chip theme's label style as a base
      labelStyle: theme.chipTheme.labelStyle?.copyWith(fontSize: 12),
      // THEME: Use a theme-aware background color
      backgroundColor: colorScheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    );
  }
}