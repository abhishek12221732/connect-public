import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:feelings/providers/calendar_provider.dart';
import 'package:feelings/features/calendar/screens/edit_event_screen.dart';
import 'enhanced_event_card.dart';
import '../screens/event_details_modal.dart';
import '../screens/upcoming_event_card.dart';

class UpcomingEventsList extends StatelessWidget {
  final List<UpcomingItem> items;
  final String coupleId;
  final DateTime? selectedDay;
  final Function(int?) onCancelReminder;
  final Function(dynamic) onEditMilestone;

  const UpcomingEventsList({
    super.key,
    required this.items,
    required this.coupleId,
    this.selectedDay,
    required this.onCancelReminder,
    required this.onEditMilestone,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Filter out milestones: only include items where isEvent is true
    final eventItems = items.where((item) => item.isEvent).toList();
    final groupedItems = <DateTime, List<UpcomingItem>>{};
    for (final item in eventItems) {
      final dayKey = DateTime(item.date.year, item.date.month, item.date.day);
      groupedItems.putIfAbsent(dayKey, () => []);
      groupedItems[dayKey]!.add(item);
    }
    final sortedKeys = groupedItems.keys.toList()..sort();

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: sortedKeys.length,
      itemBuilder: (context, index) {
        final dayKey = sortedKeys[index];
        final dayEvents = groupedItems[dayKey]!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                '${monthAbbr(dayKey)} ${dayKey.day}, ${dayKey.year}',
                style: theme.textTheme.titleLarge,
              ),
            ),
            ...dayEvents.map((item) => Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16.0, vertical: 4.0),
                  child: EnhancedEventCard(
                    event: item.event!,
                    onEdit: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => EditEventScreen(
                                event: item.event!, coupleId: coupleId))),
                    onDelete: () async {
                      await onCancelReminder(item.event!.notificationId);
                      await Provider.of<CalendarProvider>(context,
                              listen: false)
                          .deleteEvent(coupleId, item.event!.id);
                    },
                    onShare: () async => await Provider.of<CalendarProvider>(
                            context,
                            listen: false)
                        .updateEvent(coupleId, item.event!.id,
                            {'isPersonal': false, 'personalUserId': null}),
                    onTap: () => showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: theme.colorScheme.surface,
                        shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.vertical(
                                top: Radius.circular(24))),
                        builder: (context) => EventDetailsModal(
                            event: item.event!, coupleId: coupleId)),
                  ),
                )),
          ],
        );
      },
    );
  }
}