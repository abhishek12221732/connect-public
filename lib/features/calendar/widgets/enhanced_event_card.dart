import 'package:flutter/material.dart';
import 'package:feelings/features/calendar/models/calendar_event.dart';
import '../calendar_types.dart';

class EnhancedEventCard extends StatefulWidget {
  final CalendarEvent event;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onTap;
  final VoidCallback? onShare;
  final bool showQuickActions;

  const EnhancedEventCard({
    super.key,
    required this.event,
    required this.onEdit,
    required this.onDelete,
    required this.onTap,
    this.onShare,
    this.showQuickActions = true,
  });

  @override
  State<EnhancedEventCard> createState() => _EnhancedEventCardState();
}

class _EnhancedEventCardState extends State<EnhancedEventCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.02,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Color _getEventColor(CalendarEvent event) {
    final hasReminder = event.reminderTime != null ||
        (event.reminderPreset != null && event.reminderPreset != 'none');

    return getEventColorWithReminder(event.category, hasReminder);
  }

  bool _hasReminder(CalendarEvent event) {
    return event.reminderTime != null ||
        (event.reminderPreset != null && event.reminderPreset != 'none');
  }

  String _formatTime(DateTime date) {
    final hour = date.hour;
    final minute = date.minute.toString().padLeft(2, '0');
    final ampm = hour < 12 ? 'AM' : 'PM';
    final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    return '$displayHour:$minute $ampm';
  }

  String _formatDate(DateTime date) {
    const days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct',
      'Nov', 'Dec'
    ];
    return '${days[date.weekday % 7]} ${date.day} ${months[date.month - 1]}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final color = _getEventColor(widget.event);
    final icon = getCalendarCategoryIcon(widget.event.category);
    final isPersonal = widget.event.isPersonal == true;
    final hasReminder = _hasReminder(widget.event);

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Dismissible(
            key: Key(widget.event.id),
            direction: DismissDirection.endToStart,
            background: Container(
              decoration: BoxDecoration(
                color: colorScheme.error,
                borderRadius: BorderRadius.circular(16),
              ),
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.delete, color: colorScheme.onError, size: 30),
                  const SizedBox(height: 4),
                  Text(
                    'Delete',
                    style: TextStyle(
                        color: colorScheme.onError, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            confirmDismiss: (direction) => _showDeleteConfirmation(),
            onDismissed: (direction) {
              widget.onDelete();
            },
            child: Card(
              // 👇 THIS IS THE ADDED LINE TO MAKE THE CARD WIDER
              margin: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 6.0),
              elevation: _isHovered ? 8 : 4,
              shadowColor: colorScheme.primary.withOpacity(0.08),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: isPersonal ? colorScheme.outline : Colors.transparent,
                  width: isPersonal ? 1 : 0,
                ),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: widget.onTap,
                onLongPress: () {
                  _showQuickActionsMenu(context);
                },
                onHover: (hovered) {
                  setState(() {
                    _isHovered = hovered;
                  });
                  if (hovered) {
                    _animationController.forward();
                  } else {
                    _animationController.reverse();
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Row
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Category Icon
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: color.withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: Icon(icon, color: color, size: 24),
                          ),
                          const SizedBox(width: 12),

                          // Title and Date
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.event.title,
                                  style: theme.textTheme.titleMedium,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.calendar_today,
                                      size: 12,
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      _formatDate(widget.event.startDate),
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Icon(
                                      Icons.access_time,
                                      size: 12,
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      _formatTime(widget.event.startDate),
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          // Quick Actions
                          if (widget.showQuickActions)
                            PopupMenuButton<String>(
                              icon: Icon(Icons.more_vert,
                                  color: colorScheme.onSurfaceVariant),
                              onSelected: (value) {
                                switch (value) {
                                  case 'edit':
                                    widget.onEdit();
                                    break;
                                  case 'delete':
                                    _showDeleteConfirmation()
                                        .then((confirmed) {
                                      if (confirmed) {
                                        widget.onDelete();
                                      }
                                    });
                                    break;
                                  case 'share':
                                    _showShareDialog();
                                    break;
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
                                          style: TextStyle(
                                              color: colorScheme.error)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),

                      // Description
                      if (widget.event.description.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(
                          widget.event.description,
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(color: colorScheme.onSurfaceVariant),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],

                      // Location
                      if (widget.event.location != null &&
                          widget.event.location!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              Icons.location_on,
                              size: 14,
                              color: colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                widget.event.location!,
                                style: theme.textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],

                      // Category and Tags
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          _buildTag(
                            context,
                            icon: icon,
                            label:
                                getCalendarCategoryLabel(widget.event.category),
                            color: color,
                          ),
                          if (hasReminder)
                            _buildTag(
                              context,
                              icon: Icons.alarm,
                              label: 'Reminder',
                              color: colorScheme.secondary,
                            ),
                            if (isPersonal)
                              _buildTag(
                               context,
                               icon: Icons.person,
                               label: 'Personal',
                               color: colorScheme.tertiary,
                              ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTag(BuildContext context,
      {required IconData icon, required String label, required Color color}) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 12,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: theme.textTheme.labelSmall
                ?.copyWith(color: color, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Future<bool> _showDeleteConfirmation() async {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Event'),
        content: Text('Are you sure you want to delete this event?',
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: colorScheme.onSurfaceVariant)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: colorScheme.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  void _showShareDialog() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Share with Partner'),
        content: Text(
            'This will make your personal event visible to your partner. Continue?',
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: colorScheme.onSurfaceVariant)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              if (widget.onShare != null) {
                widget.onShare!();
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

  void _showQuickActionsMenu(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    showModalBottomSheet(
      context: context,
      backgroundColor: colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: Icon(Icons.edit, color: colorScheme.primary),
              title: const Text('Edit Event'),
              onTap: () {
                Navigator.pop(context);
                widget.onEdit();
              },
            ),
            if (widget.event.isPersonal == true && widget.onShare != null)
              ListTile(
                leading: Icon(Icons.share, color: colorScheme.secondary),
                title: const Text('Share Event'),
                onTap: () {
                  Navigator.pop(context);
                  _showShareDialog();
                },
              ),
            ListTile(
              leading: Icon(Icons.delete, color: colorScheme.error),
              title: Text('Delete Event', style: TextStyle(color: colorScheme.error)),
              onTap: () async {
                Navigator.pop(context);
                final shouldDelete = await _showDeleteConfirmation();
                if (shouldDelete) {
                  widget.onDelete();
                }
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}