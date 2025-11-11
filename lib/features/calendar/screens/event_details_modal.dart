import 'package:flutter/material.dart';
import 'package:feelings/features/calendar/models/calendar_event.dart';
import '../calendar_types.dart'; // Import the new centralized types
import 'edit_event_screen.dart';

class EventDetailsModal extends StatelessWidget {
  String _repeatLabel(String? repeat) {
    switch (repeat) {
      case 'daily':
        return 'Repeats daily';
      case 'weekly':
        return 'Repeats weekly';
      case 'monthly':
        return 'Repeats monthly';
      case 'yearly':
        return 'Repeats yearly';
      case 'none':
      case null:
        return 'No repeat';
      default:
        return 'Repeats: $repeat';
    }
  }
  final CalendarEvent event;
  final String coupleId;
  final VoidCallback? onEdit;
  final VoidCallback? onShare;

  const EventDetailsModal({
    super.key,
    required this.event,
    required this.coupleId,
    this.onEdit,
    this.onShare,
  });

  String _reminderLabel(String preset) {
    switch (preset) {
      case '15min':
        return '15 minutes before';
      case '1hr':
        return '1 hour before';
      case '1day':
        return '1 day before';
      default:
        return preset;
    }
  }

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

  String _formatDateTime(DateTime dateTime) {
    final hour = dateTime.hour;
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final ampm = hour < 12 ? 'AM' : 'PM';
    final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    return '$displayHour:$minute $ampm';
  }

  String _formatDate(DateTime date) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final color = _getEventColor(event);
    final icon = getCalendarCategoryIcon(event.category);
    final hasReminder = event.reminderTime != null ||
        (event.reminderPreset != null && event.reminderPreset != 'none');

  return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: colorScheme.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: color.withOpacity(0.05),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: color.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Icon(icon, color: color, size: 24),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            event.title,
                            style: theme.textTheme.titleLarge,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            getCalendarCategoryLabel(event.category),
                            style:
                                theme.textTheme.labelLarge?.copyWith(color: color),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: colorScheme.onSurfaceVariant),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),

                // Personal event indicator
                if (event.isPersonal == true) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: colorScheme.outline, width: 1),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.person, size: 16, color: colorScheme.onSurfaceVariant),
                        const SizedBox(width: 6),
                        Text('Personal Event', style: theme.textTheme.labelMedium),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Content
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                _buildInfoRow(
                  context: context,
                  icon: Icons.calendar_today,
                  title: 'Date & Time',
                  content: '${_formatDate(event.startDate)} at ${_formatDateTime(event.startDate)}',
                  color: color,
                ),

                // Repeat info
                if (event.repeat != null && event.repeat != 'none') ...[
                  const SizedBox(height: 16),
                  _buildInfoRow(
                    context: context,
                    icon: Icons.repeat,
                    title: 'Repeat',
                    content: _repeatLabel(event.repeat),
                    color: color,
                  ),
                ],

                // Personal/shared info
                if (event.isPersonal == true) ...[
                  const SizedBox(height: 16),
                  _buildInfoRow(
                    context: context,
                    icon: Icons.lock,
                    title: 'Visibility',
                    content: 'Personal (only you can see)',
                    color: color,
                  ),
                ] else ...[
                  const SizedBox(height: 16),
                  _buildInfoRow(
                    context: context,
                    icon: Icons.group,
                    title: 'Visibility',
                    content: 'Shared with partner',
                    color: color,
                  ),
                ],

                // Reminder info
                if (hasReminder) ...[
                  const SizedBox(height: 16),
                  _buildInfoRow(
                    context: context,
                    icon: Icons.alarm,
                    title: 'Reminder',
                    content: _reminderLabel(event.reminderPreset ?? ''),
                    color: color,
                  ),
                ],

                if (event.endDate != null) ...[
                  const SizedBox(height: 16),
                  _buildInfoRow(
                    context: context,
                    icon: Icons.schedule,
                    title: 'Ends',
                    content: '${_formatDate(event.endDate!)} at ${_formatDateTime(event.endDate!)}',
                    color: color,
                  ),
                ],

                if (event.location != null && event.location!.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _buildInfoRow(
                    context: context,
                    icon: Icons.location_on,
                    title: 'Location',
                    content: event.location!,
                    color: color,
                  ),
                ],

                if (hasReminder) ...[
                  const SizedBox(height: 16),
                  _buildInfoRow(
                    context: context,
                    icon: Icons.alarm,
                    title: 'Reminder',
                    content: _reminderLabel(event.reminderPreset ?? ''),
                    color: color,
                  ),
                ],

                if (event.description.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Text(
                    'Description',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(color: color, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: color.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      event.description,
                      style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurface, height: 1.4),
                    ),
                  ),
                ],

                const SizedBox(height: 24),

                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => EditEventScreen(event: event, coupleId: coupleId),
                            ),
                          );
                        },
                        icon: const Icon(Icons.edit, size: 18),
                        label: const Text('Edit'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: color,
                          side: BorderSide(color: color),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    if (event.isPersonal == true) ...[
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            _showShareWithPartnerDialog(context);
                          },
                          icon: const Icon(Icons.share, size: 18),
                          label: const Text('Share'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: color,
                            foregroundColor:
                                ThemeData.estimateBrightnessForColor(color) ==
                                        Brightness.dark
                                    ? Colors.white
                                    : Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String content,
    required Color color,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.labelMedium
                    ?.copyWith(color: color, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 2),
              Text(
                content,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: colorScheme.onSurface),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showShareWithPartnerDialog(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Share with Partner'),
        content: Text(
          'This will make your personal event visible to your partner. Continue?',
          style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              if (onShare != null) {
                onShare!();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Event shared with partner!'),
                    backgroundColor: colorScheme.secondary,
                  ),
                );
              }
            },
            style: TextButton.styleFrom(foregroundColor: colorScheme.secondary),
            child: const Text('Share'),
          ),
        ],
      ),
    );
  }
}