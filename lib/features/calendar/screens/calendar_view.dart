// lib/features/calendar/screens/calendar_view.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:feelings/providers/calendar_provider.dart';
import 'package:feelings/features/calendar/screens/add_event_wizard_screen.dart';
import '../widgets/calendar_filter_section.dart';
import 'calendar_grid.dart';
import 'calendar_header.dart';
import '../widgets/calendar_legend.dart';
import '../widgets/empty_state_widget.dart';
import '../widgets/enhanced_milestones_section.dart';
import 'fab_menu.dart';
import '../widgets/upcoming_events_list.dart';
import '../utils/calendar_utils.dart';
import 'upcoming_event_card.dart';
import '../models/calendar_event.dart';
import '../models/milestone.dart';
import '../calendar_types.dart';
import 'package:intl/intl.dart';
import 'package:feelings/providers/couple_provider.dart';

// ✨ --- NEW IMPORTS --- ✨
import 'package:feelings/providers/secret_note_provider.dart';
import 'package:feelings/features/secret_note/widgets/secret_note_view_dialog.dart';
import 'package:animate_do/animate_do.dart';
// ✨ --- END NEW IMPORTS --- ✨

class CalendarView extends StatelessWidget {
  final String coupleId;
  final DateTime focusedDay;
  final DateTime? selectedDay;
  final String activeCategory;
  final String searchQuery;
  final bool showSearchBar;
  final List Function(List) getSortedMilestones;
  final VoidCallback onAddMilestone;
  final Function(dynamic) onEditMilestone;
  final Function(DateTime) onFocusDayChanged;
  final Function(DateTime) onSelectDayChanged;
  final Function(String) onCategoryChanged;
  final Function(String) onSearchChanged;
  final VoidCallback onSearchToggle;
  final VoidCallback onShowAll;
  final Function(int?) onCancelReminder;
  final VoidCallback onGenerateDateIdea;

  const CalendarView({
    super.key,
    required this.coupleId,
    required this.focusedDay,
    this.selectedDay,
    required this.activeCategory,
    required this.searchQuery,
    required this.showSearchBar,
    required this.getSortedMilestones,
    required this.onAddMilestone,
    required this.onEditMilestone,
    required this.onFocusDayChanged,
    required this.onSelectDayChanged,
    required this.onCategoryChanged,
    required this.onSearchChanged,
    required this.onSearchToggle,
    required this.onShowAll,
    required this.onCancelReminder,
    required this.onGenerateDateIdea,
  });

  // ✨ --- NEW HELPER METHOD --- ✨
  void _openSecretNote(BuildContext context, SecretNoteProvider provider) {
    final note = provider.activeSecretNote;
    if (note == null) return;

    // Show the dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => SecretNoteViewDialog(note: note),
    );
    // Mark the note as read
    provider.markNoteAsRead(note.id);
  }
  // ✨ --- END NEW HELPER METHOD --- ✨

  void _handleMilestoneDelete(BuildContext context, Milestone milestone) async {
    // ... (This function is unchanged) ...
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final coupleId = this.coupleId;

    final bool? confirmDelete = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Milestone?'),
        content: Text('Are you sure you want to delete "${milestone.title}"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: colorScheme.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmDelete ?? false) {
      await Provider.of<CalendarProvider>(context, listen: false).deleteMilestone(coupleId, milestone.id);
    }
  }

  void showMilestoneDetailModal(
    BuildContext context,
    Milestone milestone,
    void Function(Milestone) onEdit,
    void Function(Milestone) onDelete,
  ) {
    // ... (This function is unchanged) ...
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final color = getCalendarCategoryColor(milestone.type);
    final icon = getCalendarCategoryIcon(milestone.type);
    final dateStr = DateFormat('EEEE, MMMM d, yyyy').format(milestone.date);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.5,
          minChildSize: 0.3,
          maxChildSize: 0.8,
          expand: false,
          builder: (context, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.all(24),
              child: ListView(
                controller: scrollController,
                children: [
                  // Header
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(icon, color: color, size: 24),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(milestone.title, style: theme.textTheme.headlineSmall),
                            const SizedBox(height: 4),
                            Text(dateStr, style: theme.textTheme.bodyLarge?.copyWith(color: colorScheme.onSurfaceVariant)),
                          ],
                        ),
                      ),
                    ],
                  ),

                  // Description
                  if (milestone.description != null && milestone.description!.isNotEmpty) ...[
                    const Divider(height: 32),
                    Text('Notes', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Text(milestone.description!, style: theme.textTheme.bodyLarge?.copyWith(color: colorScheme.onSurfaceVariant, height: 1.5)),
                  ],

                  const Divider(height: 32),

                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.edit_outlined),
                          label: const Text('Edit'),
                          onPressed: () {
                            Navigator.pop(context); // Close this modal first
                            onEdit(milestone);
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: Icon(Icons.delete_outline, color: colorScheme.error),
                          label: Text('Delete', style: TextStyle(color: colorScheme.error)),
                          style: OutlinedButton.styleFrom(side: BorderSide(color: colorScheme.error)),
                          onPressed: () {
                            Navigator.pop(context); // Close this modal first
                            onDelete(milestone);
                          },
                        ),
                      ),
                    ],
                  )
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        // ✨ --- WATCH 3 PROVIDERS --- ✨
        child: Consumer3<CalendarProvider, CoupleProvider, SecretNoteProvider>(
          builder: (context, calendarProvider, coupleProvider, secretNoteProvider, child) {
            // ✨ --- NEW: CHECK FOR SECRET NOTE --- ✨
            final bool hasSecretNote =
                secretNoteProvider.activeNoteLocation == SecretNoteLocation.calendar &&
                secretNoteProvider.activeSecretNote != null;
            // ✨ --- END NEW --- ✨
            
            final now = DateTime.now();

            final allItems = [
              ...calendarProvider.events.map((e) => UpcomingItem.event(e)),
              ...calendarProvider.milestones.map((m) => UpcomingItem.milestone(m))
            ];
            allItems.sort((a, b) => a.date.compareTo(b.date));

            List<UpcomingItem> displayList;
            if (selectedDay == null) {
              displayList = allItems.where((item) {
                final DateTime endTime = item.isEvent ? (item.event!.endDate ?? item.event!.startDate) : item.milestone!.date;
                return endTime.isAfter(now);
              }).toList();
            } else {
              displayList = allItems.where((item) {
                return item.date.year == selectedDay!.year && item.date.month == selectedDay!.month && item.date.day == selectedDay!.day;
              }).toList();
            }

            final categoryFiltered = activeCategory == 'all'
                ? displayList
                : displayList.where((item) => (item.isEvent && item.event!.category == activeCategory) || (!item.isEvent && activeCategory == 'anniversary')).toList();

            final finalList = searchQuery.trim().isEmpty
                ? categoryFiltered
                : categoryFiltered.where((item) {
                    final text = item.isEvent
                        ? ('${item.event!.title} ${item.event!.description} ${item.event!.location ?? ''}')
                        : (item.milestone!.title + ' ' + (item.milestone!.description ?? ''));
                    return text.toLowerCase().contains(searchQuery.toLowerCase());
                  }).toList();

            return RefreshIndicator(
              onRefresh: () async {
                calendarProvider.notifyListeners();
                await Future.delayed(const Duration(milliseconds: 500));
              },
              color: theme.colorScheme.primary,
              backgroundColor: theme.colorScheme.surface,
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  _buildInactiveRelationshipWarning(coupleId, coupleProvider),
                  EnhancedMilestonesSection(
                    milestones: getSortedMilestones(calendarProvider.milestones),
                    loading: calendarProvider.milestonesLoading,
                    error: calendarProvider.milestoneError,
                    onAdd: onAddMilestone,
                    onShowDetail: (context, milestone) => showMilestoneDetailModal(
                      context,
                      milestone,
                      onEditMilestone,
                      (milestoneToDelete) => _handleMilestoneDelete(context, milestoneToDelete),
                    ),
                    onEdit: (milestone) => onEditMilestone(milestone),
                    onDelete: (milestone) async => await Provider.of<CalendarProvider>(context, listen: false).deleteMilestone(coupleId, milestone.id),
                  ),
                  const SizedBox(height: 24.0),
                  CalendarHeader(
                    monthYearLabel: '${monthAbbr(focusedDay)} ${focusedDay.year}',
                    onPrevMonth: () => onFocusDayChanged(DateTime(focusedDay.year, focusedDay.month - 1, 1)),
                    onNextMonth: () => onFocusDayChanged(DateTime(focusedDay.year, focusedDay.month + 1, 1)),
                    onToday: () => onSelectDayChanged(DateTime.now()),
                    onMonthYearTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: focusedDay,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) {
                        onFocusDayChanged(DateTime(picked.year, picked.month, 1));
                      }
                    },
                  ),
                  SizedBox(
                    height: 180,
                    child: SingleChildScrollView(
                      child: CalendarGrid(
                        focusedDay: focusedDay,
                        selectedDay: selectedDay,
                        onDaySelected: onSelectDayChanged,
                        events: calendarProvider.events,
                        // ✨ --- TODO: Pass note to CalendarGrid --- ✨
                        // We can't do this yet as we don't have the file.
                        // For now, the note will only appear in the list below.
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  const CalendarLegend(),
                  
                  const SizedBox(height: 24.0),

                  // ✨ --- NEW: RENDER THE SECRET NOTE BANNER --- ✨
                  if (hasSecretNote)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: _SecretNoteCalendarBanner(
                        onTap: () => _openSecretNote(context, secretNoteProvider),
                      ),
                    ),
                  // ✨ --- END NEW --- ✨

                  CalendarFilterSection(
                    activeCategory: activeCategory,
                    searchQuery: searchQuery,
                    showSearchBar: showSearchBar,
                    onCategoryChanged: onCategoryChanged,
                    onSearchChanged: onSearchChanged,
                    onSearchToggle: onSearchToggle,
                    onShowAll: onShowAll,
                    selectedDay: selectedDay,
                  ),
                  const SizedBox(height: 16.0),
                  if (finalList.isEmpty)
                    EmptyStateWidget(
                      title: selectedDay == null ? 'No Plans Yet!' : 'No Events on This Day',
                      subtitle: selectedDay == null ? 'Start planning your special moments.' : 'Tap the + button to add something!',
                      icon: selectedDay == null ? Icons.calendar_today : Icons.event_busy,
                      actionText: 'Add Event',
                      onAction: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddEventWizardScreen())),
                    )
                  else
                    UpcomingEventsList(
                      items: finalList,
                      coupleId: coupleId,
                      selectedDay: selectedDay,
                      onCancelReminder: onCancelReminder,
                      onEditMilestone: (milestone) => onEditMilestone(milestone),
                    ),
                ],
              ),
            );
          },
        ),
      ),
      floatingActionButton: FabMenu(
        onAddEvent: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddEventWizardScreen())),
        onGenerateDateIdea: onGenerateDateIdea,
      ),
    );
  }

  Widget _buildInactiveRelationshipWarning(String coupleId, CoupleProvider coupleProvider) {
    // ... (This function is unchanged) ...
    return FutureBuilder<bool>(
      future: coupleProvider.isRelationshipInactive(coupleId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done && snapshot.data == true) {
          final theme = Theme.of(context);
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: theme.colorScheme.errorContainer.withOpacity(0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: theme.colorScheme.onErrorContainer),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Your partner has disconnected. You can still see old.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onErrorContainer,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          );
        }
        return const SizedBox.shrink(); 
      },
    );
  }
}

// ✨ --- NEW WIDGET: SECRET NOTE BANNER --- ✨
class _SecretNoteCalendarBanner extends StatefulWidget {
  final VoidCallback onTap;
  const _SecretNoteCalendarBanner({required this.onTap});

  @override
  State<_SecretNoteCalendarBanner> createState() => _SecretNoteCalendarBannerState();
}

class _SecretNoteCalendarBannerState extends State<_SecretNoteCalendarBanner> with SingleTickerProviderStateMixin {
  late final AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FadeIn(
      duration: const Duration(milliseconds: 500),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer.withOpacity(0.4),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: theme.colorScheme.primary.withOpacity(0.3),
            ),
          ),
          child: Row(
            children: [
              ScaleTransition(
                scale: Tween<double>(begin: 1.0, end: 1.15)
                    .animate(_animationController),
                child: Icon(
                  Icons.mail_lock_rounded,
                  color: theme.colorScheme.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  "You have a secret note!",
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: theme.colorScheme.primary.withOpacity(0.7),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
// ✨ --- END NEW WIDGET --- ✨