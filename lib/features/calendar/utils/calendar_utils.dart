import 'package:flutter/material.dart';
import 'package:feelings/features/calendar/models/calendar_event.dart';
import 'package:feelings/features/calendar/calendar_types.dart';

// Moved from the top of calendar_screen.dart
Color eventTypeColor(CalendarEvent event) => getCalendarCategoryColor(event.category);
IconData eventTypeIcon(String category) => getCalendarCategoryIcon(category);
IconData milestoneTypeIcon(String? type) => getCalendarCategoryIcon(type);

String weekdayAbbr(DateTime date) {
  const days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
  return days[date.weekday % 7];
}

// String monthAbbr(DateTime date) {
//   const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
//   return months[date.month - 1];
// }

String formatTime(DateTime date) {
  final hour = date.hour;
  final minute = date.minute.toString().padLeft(2, '0');
  final ampm = hour < 12 ? 'AM' : 'PM';
  final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
  return '$displayHour:$minute $ampm';
}

int calculateDaysUntilMilestone(DateTime date) {
  final now = DateTime.now();
  final thisYear = DateTime(now.year, date.month, date.day);
  if (thisYear.isBefore(now) && (thisYear.month != now.month || thisYear.day != now.day)) {
    final nextYear = DateTime(now.year + 1, date.month, date.day);
    return nextYear.difference(now).inDays + 1;
  }
  return thisYear.difference(now).inDays + 1;
}

// You can also move modals that are used in multiple places here. For example:
void showMilestoneDetailModal(BuildContext context, milestone, Function(dynamic) onEdit) {
  // Logic for showing the milestone detail dialog
}