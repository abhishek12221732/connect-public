import 'package:flutter/material.dart';
import '../calendar_types.dart';
import '../models/milestone.dart';
import 'package:feelings/widgets/pulsing_dots_indicator.dart';

class EnhancedMilestonesSection extends StatelessWidget {
  final List milestones;
  final bool loading;
  final String? error;
  final VoidCallback onAdd;
  final Function(BuildContext, dynamic) onShowDetail;
  final void Function(Milestone) onEdit;
  final void Function(Milestone) onDelete;


  

  const EnhancedMilestonesSection({
    super.key,
    required this.milestones,
    required this.loading,
    required this.error,
    required this.onAdd,
    required this.onShowDetail,
    required this.onEdit,
    required this.onDelete,
  });


  void _showMilestoneOptions(BuildContext context, Milestone milestone) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: <Widget>[
            ListTile(
              leading: const Icon(Icons.visibility_outlined),
              title: const Text('View Details'),
              onTap: () {
                Navigator.pop(ctx);
                onShowDetail(context, milestone);
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Edit Milestone'),
              onTap: () {
                Navigator.pop(ctx);
                onEdit(milestone);
              },
            ),
            ListTile(
              leading: Icon(Icons.delete_outline, color: Theme.of(context).colorScheme.error),
              title: Text('Delete Milestone', style: TextStyle(color: Theme.of(context).colorScheme.error)),
              onTap: () {
                Navigator.pop(ctx);
                // Show a final confirmation before deleting
                _showDeleteConfirmation(context, milestone);
              },
            ),
          ],
        ),
      ),
    );
  }
  
  // ✨ [NEW] Shows a confirmation dialog before the final delete action.
  void _showDeleteConfirmation(BuildContext context, Milestone milestone) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Milestone?'),
        content: Text('Are you sure you want to delete "${milestone.title}"? This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              onDelete(milestone); // Call the final delete callback
            },
            style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (loading) {
      return Container(
        height: 140,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Card(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                PulsingDotsIndicator(
            size: 80,
            colors: [
              Theme.of(context).colorScheme.primary,
              Theme.of(context).colorScheme.primary,
              Theme.of(context).colorScheme.primary,
            ],
          ),
                const SizedBox(height: 12),
                Text('Loading milestones...',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: colorScheme.onSurfaceVariant)),
              ],
            ),
          ),
        ),
      );
    }

    if (error != null) {
      return Container(
        height: 140,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Card(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 32, color: colorScheme.error),
                const SizedBox(height: 8),
                Text(
                  'Failed to load milestones',
                  style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.error, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  'Pull to refresh',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child:
                    Icon(Icons.celebration, color: colorScheme.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Milestones & Anniversaries',
                      style: theme.textTheme.titleLarge?.copyWith(fontSize: 18),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Celebrate your special moments',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              FloatingActionButton.small(
                heroTag: 'addMilestone',
                onPressed: onAdd,
                tooltip: 'Add Milestone',
                elevation: 4,
                child: const Icon(Icons.add),
              ),
            ],
          ),
        ),

        // Content
        if (milestones.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                children: [
                  Icon(
                    Icons.celebration,
                    color: colorScheme.onSurfaceVariant.withOpacity(0.5),
                    size: 48,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No milestones yet',
                    style: theme.textTheme.bodyLarge
                        ?.copyWith(color: colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Add your first milestone to start celebrating',
                    style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant.withOpacity(0.8)),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: onAdd,
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Add First Milestone'),
                  ),
                ],
              ),
            ),
          )
        else
          SizedBox(
            height: 180,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: milestones.length, // +1 for add button
              itemBuilder: (context, index) {
                if (index == milestones.length) {
                  return _buildAddButton(context);
                }
                return _buildMilestoneCard(context, milestones[index]);
              },
            ),
          ),
      ],
    );
  }

  Widget _buildAddButton(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      width: 160,
      margin: const EdgeInsets.only(right: 16),
      child: Card(
        elevation: 3,
        shadowColor: colorScheme.primary.withOpacity(0.2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: colorScheme.primary.withOpacity(0.3), width: 2),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onAdd,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  colorScheme.primary.withOpacity(0.05),
                  colorScheme.primary.withOpacity(0.02),
                ],
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: colorScheme.primary.withOpacity(0.3),
                      width: 2,
                    ),
                  ),
                  child: Icon(Icons.add, color: colorScheme.primary, size: 28),
                ),
                const SizedBox(height: 12),
                Text(
                  'Add Milestone',
                  style: theme.textTheme.labelLarge
                      ?.copyWith(color: colorScheme.primary),
                ),
                const SizedBox(height: 4),
                Text(
                  'Celebrate special moments',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: colorScheme.onSurfaceVariant),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMilestoneCard(BuildContext context, dynamic milestone) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final color = getCalendarCategoryColor(milestone.type);
    final icon = getCalendarCategoryIcon(milestone.type);
    final daysUntil = _calculateDaysUntil(milestone.date);
    final isToday = daysUntil == 0;
    final isUpcoming = daysUntil >= 0 && daysUntil <= 30;

    return Container(
      width: 160,
      margin: const EdgeInsets.only(right: 16),
      child: Card(
        elevation: 3,
        shadowColor: color.withOpacity(0.2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: isToday ? color : Colors.transparent,
            width: isToday ? 2 : 1.5,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => onShowDetail(context, milestone),
          onLongPress: () => _showMilestoneOptions(context, milestone),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(icon, color: color, size: 18),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        getCalendarCategoryLabel(milestone.type),
                        style: theme.textTheme.labelMedium
                            ?.copyWith(color: color, fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  milestone.title,
                  style: theme.textTheme.titleSmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Text(
                  _formatDate(milestone.date),
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: colorScheme.onSurfaceVariant),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isToday
                        ? color.withOpacity(0.2)
                        : isUpcoming
                            ? colorScheme.primary.withOpacity(0.5)
                            : colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isToday
                            ? Icons.celebration
                            : isUpcoming
                                ? Icons.schedule
                                : Icons.history,
                        size: 12,
                        color: isToday
                            ? color
                            : isUpcoming
                                ? colorScheme.primary
                                : colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _getDaysText(daysUntil),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: isToday
                              ? color
                              : isUpcoming
                                  ? colorScheme.primary
                                  : colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }


  String _formatDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  int _calculateDaysUntil(DateTime date) {
    final now = DateTime.now();
    // Normalize dates to midnight to compare days accurately
    final today = DateTime(now.year, now.month, now.day);
    final anniversaryDateThisYear = DateTime(now.year, date.month, date.day);

    if (anniversaryDateThisYear.isBefore(today)) {
      // If it has passed this year, check for next year's anniversary
      final anniversaryDateNextYear = DateTime(now.year + 1, date.month, date.day);
      return anniversaryDateNextYear.difference(today).inDays;
    } else {
      // It's upcoming this year
      return anniversaryDateThisYear.difference(today).inDays;
    }
  }

  String _getDaysText(int days) {
    if (days == 0) {
      return 'Today!';
    } else if (days == 1) {
      return 'Tomorrow';
    } else if (days > 0) {
      return '$days days';
    } else {
      // This case should not be hit with the new logic, but as a fallback
      return '${days.abs()} days ago';
    }
  }
}