import 'package:flutter/material.dart';

enum JournalSortOption {
  newest,
  oldest,
  titleAZ,
  titleZA,
}

class JournalSortButton extends StatelessWidget {
  final JournalSortOption currentSort;
  final Function(JournalSortOption) onSortChanged;

  const JournalSortButton({
    super.key,
    required this.currentSort,
    required this.onSortChanged,
  });

  @override
  Widget build(BuildContext context) {
    // THEME: Get theme from context
    final theme = Theme.of(context);

    return PopupMenuButton<JournalSortOption>(
      // THEME: The icon and text color will be inherited from the parent context (e.g., an AppBar's iconTheme/foregroundColor)
      icon: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.sort, size: 20),
          const SizedBox(width: 4),
          Text(
            _getSortLabel(currentSort),
            style: theme.textTheme.labelLarge,
          ),
        ],
      ),
      onSelected: onSortChanged,
      itemBuilder: (context) => [
        _buildSortMenuItem(
          context,
          JournalSortOption.newest,
          'Newest First',
          Icons.arrow_downward,
        ),
        _buildSortMenuItem(
          context,
          JournalSortOption.oldest,
          'Oldest First',
          Icons.arrow_upward,
        ),
        _buildSortMenuItem(
          context,
          JournalSortOption.titleAZ,
          'Title A-Z',
          Icons.sort_by_alpha,
        ),
        _buildSortMenuItem(
          context,
          JournalSortOption.titleZA,
          'Title Z-A',
          Icons.sort_by_alpha,
        ),
      ],
    );
  }

  PopupMenuItem<JournalSortOption> _buildSortMenuItem(
    BuildContext context,
    JournalSortOption option,
    String label,
    IconData icon,
  ) {
    // THEME: Get theme and colorScheme from context
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final bool isSelected = currentSort == option;

    // THEME: Use theme-aware colors
    final Color activeColor = colorScheme.primary;
    final Color inactiveColor = colorScheme.onSurface.withOpacity(0.7);
    final Color itemColor = isSelected ? activeColor : inactiveColor;

    return PopupMenuItem<JournalSortOption>(
      value: option,
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: itemColor,
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: itemColor,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
          if (isSelected) ...[
            const Spacer(),
            Icon(
              Icons.check,
              color: activeColor,
              size: 18,
            ),
          ],
        ],
      ),
    );
  }

  String _getSortLabel(JournalSortOption option) {
    switch (option) {
      case JournalSortOption.newest:
        return 'Newest';
      case JournalSortOption.oldest:
        return 'Oldest';
      case JournalSortOption.titleAZ:
        return 'A-Z';
      case JournalSortOption.titleZA:
        return 'Z-A';
    }
  }
}