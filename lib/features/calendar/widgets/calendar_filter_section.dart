import 'package:flutter/material.dart';

class CalendarFilterSection extends StatelessWidget {
  final String activeCategory;
  final String searchQuery;
  final bool showSearchBar;
  final ValueChanged<String> onCategoryChanged;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onSearchToggle;
  final VoidCallback onShowAll;
  final DateTime? selectedDay;

  const CalendarFilterSection({
    super.key,
    required this.activeCategory,
    required this.searchQuery,
    required this.showSearchBar,
    required this.onCategoryChanged,
    required this.onSearchChanged,
    required this.onSearchToggle,
    required this.onShowAll,
    required this.selectedDay,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      children: [
        if (selectedDay != null && !showSearchBar)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                Text(
                  'Showing events for: '
                  '${selectedDay!.day.toString().padLeft(2, '0')} '
                  '${_monthName(selectedDay!.month)} ${selectedDay!.year}',
                  style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.primary, fontWeight: FontWeight.w600),
                ),
                const SizedBox(width: 8),
                ActionChip(
                  label: Text('Show All', style: theme.textTheme.labelLarge?.copyWith(color: colorScheme.primary)),
                  avatar: Icon(Icons.clear, size: 16, color: colorScheme.primary),
                  onPressed: onShowAll,
                  backgroundColor: colorScheme.primary.withOpacity(0.1),
                ),
              ],
            ),
          ),
        // Search Bar
        if (showSearchBar)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Search events and milestones...',
                prefixIcon: Icon(Icons.search, color: colorScheme.primary),
                suffixIcon: IconButton(
                  icon: Icon(Icons.close, color: colorScheme.onSurfaceVariant),
                  onPressed: onSearchToggle,
                ),
                isDense: true,
              ),
              onChanged: onSearchChanged,
            ),
          ),

        // Category Filter Chips
        if (!showSearchBar)
          Container(
            height: 60,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _buildFilterChip(context, 'all', 'All', Icons.calendar_today),
                _buildFilterChip(context, 'event', 'Events', Icons.event),
                _buildFilterChip(
                    context, 'date_idea', 'Date Ideas', Icons.favorite),
                _buildFilterChip(
                    context, 'check_in', 'Check-ins', Icons.psychology),
                _buildFilterChip(
                    context, 'anniversary', 'Anniversaries', Icons.cake),
                _buildFilterChip(context, 'trip', 'Trip', Icons.flight), 
                _buildFilterChip(context, 'birthday', 'Birthday', Icons.cake), 
                
                const SizedBox(width: 16),
                IconButton(
                  icon: Icon(
                    Icons.search,
                    color: showSearchBar
                        ? colorScheme.primary
                        : colorScheme.onSurfaceVariant,
                  ),
                  tooltip: 'Search',
                  onPressed: onSearchToggle,
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildFilterChip(
      BuildContext context, String value, String label, IconData icon) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final selected = activeCategory == value;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 16,
                color: selected ? colorScheme.onPrimary : colorScheme.primary),
            const SizedBox(width: 4),
            Text(label),
          ],
        ),
        selected: selected,
        onSelected: (_) => onCategoryChanged(value),
        // Rely on the global ChipThemeData for consistent styling
        labelStyle: theme.chipTheme.labelStyle?.copyWith(
          color: selected ? colorScheme.onPrimary : colorScheme.onSurface,
          fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
    );
  }

  String _monthName(int month) {
    const months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return months[month];
  }
}