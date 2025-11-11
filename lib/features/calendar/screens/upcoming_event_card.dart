// Not being used
import 'package:flutter/material.dart';
import 'package:feelings/features/calendar/models/calendar_event.dart';
import 'event_details_modal.dart';
import '../calendar_types.dart';

// Helper functions
String weekdayAbbr(DateTime date) {
  const days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
  return days[date.weekday % 7];
}

String monthAbbr(DateTime date) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec'
  ];
  return months[date.month - 1];
}

String formatTime(DateTime date) {
  final hour = date.hour;
  final minute = date.minute.toString().padLeft(2, '0');
  final ampm = hour < 12 ? 'AM' : 'PM';
  final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
  return '$displayHour:$minute $ampm';
}

class UpcomingItem {
  final CalendarEvent? event;
  final dynamic milestone;
  UpcomingItem.event(this.event) : milestone = null;
  UpcomingItem.milestone(this.milestone) : event = null;
  bool get isEvent => event != null;
  DateTime get date => isEvent ? event!.startDate : milestone.date;
}

class UpcomingEventCard extends StatefulWidget {
  final UpcomingItem item;
  final String coupleId;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onShare;
  const UpcomingEventCard(
      {required this.item,
      required this.coupleId,
      required this.onEdit,
      required this.onDelete,
      this.onShare,
      super.key});
  @override
  State<UpcomingEventCard> createState() => _UpcomingEventCardState();
}

class _UpcomingEventCardState extends State<UpcomingEventCard> {
  bool _expanded = false;

  Color _getEventColor(CalendarEvent event) {
    final hasReminder = event.reminderTime != null ||
        (event.reminderPreset != null && event.reminderPreset != 'none');

    if (hasReminder) {
      return getCalendarCategoryColor(event.category);
    } else {
      final baseColor = getCalendarCategoryColor(event.category);
      return HSLColor.fromColor(baseColor)
          .withLightness(HSLColor.fromColor(baseColor).lightness * 0.7)
          .toColor();
    }
  }

  bool _hasReminder(CalendarEvent event) {
    return event.reminderTime != null ||
        (event.reminderPreset != null && event.reminderPreset != 'none');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final item = widget.item;
    final isEvent = item.isEvent;
    final date = item.date;
    final title =
        isEvent ? item.event!.title : (item.milestone.title as String? ?? '');
    final description = isEvent
        ? item.event!.description
        : (item.milestone.description as String? ?? '');
    final location =
        isEvent ? (item.event!.toMap()['location']?.toString() ?? '') : '';
    final icon = isEvent
        ? getCalendarCategoryIcon(item.event!.category)
        : getCalendarCategoryIcon(item.milestone.type as String?);
    final color = isEvent
        ? _getEventColor(item.event!)
        : getCalendarCategoryColor(item.milestone.type as String?);
    final isPersonal = isEvent && (item.event!.isPersonal == true);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          if (item.isEvent) {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: colorScheme.surface,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              builder: (context) => EventDetailsModal(
                event: item.event!,
                coupleId: widget.coupleId,
                onShare: widget.onShare,
                onEdit: widget.onEdit,
              ),
            );
          } else {
            setState(() => _expanded = !_expanded);
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, color: color, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                title,
                                style: theme.textTheme.titleMedium,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isPersonal) ...[
                              const SizedBox(width: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 4, vertical: 1),
                                decoration: BoxDecoration(
                                  color: colorScheme.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                      color: colorScheme.outline, width: 1),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.person,
                                        size: 10,
                                        color: colorScheme.onSurfaceVariant),
                                    const SizedBox(width: 2),
                                    Text(
                                      'Personal',
                                      style: theme.textTheme.labelSmall
                                          ?.copyWith(
                                              color: colorScheme
                                                  .onSurfaceVariant),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Text(
                              '${weekdayAbbr(date)} ${date.day} ${monthAbbr(date)} at ${formatTime(date)}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant),
                            ),
                            if (isEvent && _hasReminder(item.event!)) ...[
                              const SizedBox(width: 4),
                              Icon(Icons.alarm,
                                  size: 10, color: colorScheme.error),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon:
                        Icon(Icons.more_vert, color: colorScheme.onSurfaceVariant),
                    onSelected: (value) {
                      if (value == 'edit') {
                        widget.onEdit();
                      } else if (value == 'delete') {
                        widget.onDelete();
                      } else if (value == 'share' && widget.onShare != null) {
                        widget.onShare!();
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit, size: 16),
                            SizedBox(width: 8),
                            Text('Edit'),
                          ],
                        ),
                      ),
                      if (isPersonal && widget.onShare != null)
                        const PopupMenuItem(
                          value: 'share',
                          child: Row(
                            children: [
                              Icon(Icons.share, size: 16),
                              SizedBox(width: 8),
                              Text('Share with Partner'),
                            ],
                          ),
                        ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete,
                                size: 16, color: colorScheme.error),
                            const SizedBox(width: 8),
                            Text('Delete',
                                style: TextStyle(color: colorScheme.error)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              if (description.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  description,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: colorScheme.onSurfaceVariant),
                  maxLines: _expanded ? 100 : 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              if (location.isNotEmpty) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.location_on,
                        size: 12, color: colorScheme.onSurfaceVariant),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        location,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: colorScheme.onSurfaceVariant),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
              if (_expanded && !isEvent)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if ((item.milestone.type as String? ?? '').isNotEmpty)
                        Text(
                            'Type: ${(item.milestone.type as String? ?? '')}',
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: colorScheme.secondary)),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}