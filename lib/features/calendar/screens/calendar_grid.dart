import 'package:flutter/material.dart';
import 'package:feelings/features/calendar/models/calendar_event.dart';
import '../calendar_types.dart'; // Import the new centralized types

class CalendarGrid extends StatefulWidget {
  final DateTime focusedDay;
  final DateTime? selectedDay;
  final ValueChanged<DateTime> onDaySelected;
  final List<CalendarEvent> events;

  const CalendarGrid({
    required this.focusedDay,
    required this.selectedDay,
    required this.onDaySelected,
    required this.events,
    super.key,
  });

  @override
  State<CalendarGrid> createState() => _CalendarGridState();
}

class _CalendarGridState extends State<CalendarGrid> {
  // ✨ [REMOVED] The local _getEventColor method has been removed to avoid code duplication.
  // We will now use the centralized helper function from calendar_types.dart.

  List<DateTime> _getDaysInMonth(DateTime month) {
    final firstDay = DateTime(month.year, month.month, 1);
    final lastDay = DateTime(month.year, month.month + 1, 0);
    final daysInMonth = lastDay.day;

    List<DateTime> days = [];

    // Add days from previous month to fill first week
    final firstWeekday = firstDay.weekday % 7; // Sunday as 0
    for (int i = firstWeekday; i > 0; i--) {
      days.add(firstDay.subtract(Duration(days: i)));
    }

    // Add days of current month
    for (int i = 1; i <= daysInMonth; i++) {
      days.add(DateTime(month.year, month.month, i));
    }

    // Add days from next month to fill last week
    final lastWeekday = lastDay.weekday % 7;
    final daysToAdd = (lastWeekday == 6) ? 0 : 6 - lastWeekday;
    for (int i = 1; i <= daysToAdd; i++) {
      days.add(lastDay.add(Duration(days: i)));
    }

    return days;
  }

  List<CalendarEvent> _getEventsForDay(DateTime day) {
    return widget.events.where((event) {
      final eventDay = DateTime(
          event.startDate.year, event.startDate.month, event.startDate.day);
      return eventDay.year == day.year &&
          eventDay.month == day.month &&
          eventDay.day == day.day;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final days = _getDaysInMonth(widget.focusedDay);
    final currentMonth = widget.focusedDay.month;

    return Column(
      children: [
        // Weekday headers
        Row(
          children: ['S', 'M', 'T', 'W', 'T', 'F', 'S']
              .map((day) => Expanded(
                    child: Container(
                      height: 24,
                      alignment: Alignment.center,
                      child: Text(
                        day,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ))
              .toList(),
        ),
        const SizedBox(height: 4),

        // Calendar grid
        ...List.generate((days.length / 7).ceil(), (weekIndex) {
          final weekDays = days.skip(weekIndex * 7).take(7).toList();
          return Row(
            children: weekDays.map((day) {
              final isCurrentMonth = day.month == currentMonth;
              final now = DateTime.now();
              final isToday = day.year == now.year &&
                  day.month == now.month &&
                  day.day == now.day;
              final isSelected = widget.selectedDay != null &&
                  day.year == widget.selectedDay!.year &&
                  day.month == widget.selectedDay!.month &&
                  day.day == widget.selectedDay!.day;
              final events = _getEventsForDay(day);

              return Expanded(
                child: GestureDetector(
                  onTap: () => widget.onDaySelected(day),
                  child: Container(
                    height: 28,
                    margin: const EdgeInsets.all(1),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? colorScheme.primary
                          : isToday
                              ? colorScheme.primary.withOpacity(0.1)
                              : Colors.transparent,
                      borderRadius: BorderRadius.circular(4),
                      border: isToday && !isSelected
                          ? Border.all(color: colorScheme.primary, width: 1)
                          : null,
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Text(
                          '${day.day}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: isToday || isSelected
                                ? FontWeight.bold
                                : FontWeight.w500,
                            color: isSelected
                                ? colorScheme.onPrimary
                                : isToday
                                    ? colorScheme.primary
                                    : isCurrentMonth
                                        ? colorScheme.onSurface
                                        : colorScheme.onSurface
                                            .withOpacity(0.38),
                          ),
                        ),
                        if (events.isNotEmpty)
                          Positioned(
                            bottom: 1,
                            right: 1,
                            child: Container(
                              width: 4,
                              height: 4,
                              decoration: BoxDecoration(
                                // ✨ [FIX] This now calls the correct, centralized color function.
                                color: getEventColorWithReminder(
                                  events.first.category,
                                  events.first.reminderTime != null || (events.first.reminderPreset != null && events.first.reminderPreset != 'none')
                                ),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          );
        }),
      ],
    );
  }
}