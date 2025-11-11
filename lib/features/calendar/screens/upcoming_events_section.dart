import 'package:flutter/material.dart';
import 'package:feelings/features/calendar/models/calendar_event.dart';
import 'package:feelings/features/calendar/models/milestone.dart';
import 'upcoming_event_card.dart';

class UpcomingEventsSection extends StatelessWidget {
  final List<UpcomingItem> items;
  final String coupleId;
  final DateTime? selectedDay;
  final bool showSearchBar;
  final String searchQuery;
  final VoidCallback onShowAll;
  final VoidCallback onSearchToggle;
  final ValueChanged<String> onSearchChanged;
  final void Function(UpcomingItem) onEdit;
  final void Function(UpcomingItem) onDelete;
  final void Function(BuildContext, Milestone) onShowMilestoneDetail;
  const UpcomingEventsSection({
    required this.items,
    required this.coupleId,
    required this.selectedDay,
    required this.showSearchBar,
    required this.searchQuery,
    required this.onShowAll,
    required this.onSearchToggle,
    required this.onSearchChanged,
    required this.onEdit,
    required this.onDelete,
    required this.onShowMilestoneDetail,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Only return the header/search bar, not the event cards
    return showSearchBar
        ? Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText:
                          'Search events... (title, description, location)',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: onSearchToggle,
                      ),
                      isDense: true,
                    ),
                    onChanged: onSearchChanged,
                  ),
                ),
              ],
            ),
          )
        : Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Row(
              children: [
                Text('Upcoming Shared Events',
                    style: theme.textTheme.titleMedium),
                if (selectedDay != null) ...[
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.clear, size: 16),
                    label: const Text('Show All'),
                    // Let the default theme handle the style
                    onPressed: onShowAll,
                  ),
                ],
                const Spacer(),
                IconButton(
                  icon: Icon(Icons.search,
                      color: showSearchBar
                          ? colorScheme.primary
                          : colorScheme.onSurfaceVariant),
                  tooltip: 'Search',
                  onPressed: onSearchToggle,
                ),
              ],
            ),
          );
  }
}