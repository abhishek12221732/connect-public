import 'package:flutter/material.dart';

/// Unified categories for both events and milestones in the relationship app.
enum CalendarCategory {
  event,
  dateIdea,
  anniversary,
  birthday,
  holiday,
  trip,
  goal,
  appointment,
  celebration,
  engagement,
  wedding,
  firstDate,
  firstKiss,
  movedIn,
  gotPet,
  baby,
  checkIn,
  custom,
  other,
}

/// Human-readable labels for each category.
const Map<CalendarCategory, String> calendarCategoryLabels = {
  CalendarCategory.event: 'Event',
  CalendarCategory.dateIdea: 'Date Idea',
  CalendarCategory.anniversary: 'Anniversary',
  CalendarCategory.birthday: 'Birthday',
  CalendarCategory.holiday: 'Holiday',
  CalendarCategory.trip: 'Trip',
  CalendarCategory.goal: 'Goal',
  CalendarCategory.appointment: 'Appointment',
  CalendarCategory.celebration: 'Celebration',
  CalendarCategory.engagement: 'Engagement',
  CalendarCategory.wedding: 'Wedding',
  CalendarCategory.firstDate: 'First Date',
  CalendarCategory.firstKiss: 'First Kiss',
  CalendarCategory.movedIn: 'Moved In',
  CalendarCategory.gotPet: 'Got a Pet',
  CalendarCategory.baby: 'Baby',
  CalendarCategory.checkIn: 'Check-In',
  CalendarCategory.custom: 'Custom',
  CalendarCategory.other: 'Other',
};

/// Color mapping for each category - using consistent, relationship-focused colors.
const Map<CalendarCategory, Color> calendarCategoryColors = {
  // Primary relationship events (warm colors)
  CalendarCategory.dateIdea: Color(0xFFE91E63), // Pink 500 - romantic date ideas
  CalendarCategory.anniversary: Color(0xFF9C27B0), // Purple 500 - special anniversaries
  CalendarCategory.engagement: Color(0xFFF44336), // Red 500 - engagement
  CalendarCategory.wedding: Color(0xFF673AB7), // Deep Purple 500 - wedding
  CalendarCategory.firstDate: Color(0xFF2196F3), // Blue 500 - first date
  CalendarCategory.firstKiss: Color(0xFFE91E63), // Pink 500 - romantic moment
  
  // Life milestones (earthy/neutral colors)
  CalendarCategory.movedIn: Color(0xFF795548), // Brown 500 - moving in together
  CalendarCategory.gotPet: Color(0xFF4CAF50), // Green 500 - getting a pet
  CalendarCategory.baby: Color(0xFFFF9800), // Orange 500 - baby
  
  // Regular events (cool colors)
  CalendarCategory.event: Color(0xFF00BCD4), // Cyan 500 - general events
  CalendarCategory.appointment: Color(0xFF607D8B), // Blue Grey 500 - appointments
  CalendarCategory.trip: Color(0xFF009688), // Teal 500 - trips
  
  // Special occasions (bright colors)
  CalendarCategory.birthday: Color(0xFFFF5722), // Deep Orange 500 - birthdays
  CalendarCategory.holiday: Color(0xFF4CAF50), // Green 500 - holidays
  CalendarCategory.celebration: Color(0xFFFFC107), // Amber 500 - celebrations
  CalendarCategory.goal: Color(0xFF9C27B0), // Purple 500 - goals
  
  // Relationship health (distinctive colors)
  CalendarCategory.checkIn: Color.fromARGB(255, 199, 30, 233), // Pink 500 - relationship check-ins
  
  // Fallback colors
  CalendarCategory.custom: Color(0xFF757575), // Grey 500 - custom
  CalendarCategory.other: Color(0xFF9E9E9E), // Grey 400 - other
};

/// Icon mapping for each category.
const Map<CalendarCategory, IconData> calendarCategoryIcons = {
  CalendarCategory.event: Icons.event,
  CalendarCategory.dateIdea: Icons.favorite,
  CalendarCategory.anniversary: Icons.cake,
  CalendarCategory.birthday: Icons.cake,
  CalendarCategory.holiday: Icons.card_giftcard,
  CalendarCategory.trip: Icons.flight,
  CalendarCategory.goal: Icons.flag,
  CalendarCategory.appointment: Icons.calendar_today,
  CalendarCategory.celebration: Icons.celebration,
  CalendarCategory.engagement: Icons.ring_volume,
  CalendarCategory.wedding: Icons.cake,
  CalendarCategory.firstDate: Icons.emoji_emotions,
  CalendarCategory.firstKiss: Icons.favorite,
  CalendarCategory.movedIn: Icons.home,
  CalendarCategory.gotPet: Icons.pets,
  CalendarCategory.baby: Icons.child_friendly,
  CalendarCategory.checkIn: Icons.psychology,
  CalendarCategory.custom: Icons.star,
  CalendarCategory.other: Icons.star_border,
};

/// Utility to get category from string (for model compatibility).
CalendarCategory calendarCategoryFromString(String? value) {
  if (value == null) return CalendarCategory.other;
  switch (value.toLowerCase()) {
    case 'event':
      return CalendarCategory.event;
    case 'date_idea':
      return CalendarCategory.dateIdea;
    case 'anniversary':
      return CalendarCategory.anniversary;
    case 'birthday':
      return CalendarCategory.birthday;
    case 'holiday':
      return CalendarCategory.holiday;
    case 'trip':
      return CalendarCategory.trip;
    case 'goal':
      return CalendarCategory.goal;
    case 'appointment':
      return CalendarCategory.appointment;
    case 'celebration':
      return CalendarCategory.celebration;
    case 'engagement':
      return CalendarCategory.engagement;
    case 'wedding':
      return CalendarCategory.wedding;
    case 'first_date':
      return CalendarCategory.firstDate;
    case 'first_kiss':
      return CalendarCategory.firstKiss;
    case 'moved_in':
      return CalendarCategory.movedIn;
    case 'got_pet':
      return CalendarCategory.gotPet;
    case 'baby':
      return CalendarCategory.baby;
    case 'check_in':
      return CalendarCategory.checkIn;
    case 'custom':
      return CalendarCategory.custom;
    default:
      return CalendarCategory.other;
  }
}

/// Utility to get string from category (for model compatibility).
String calendarCategoryToString(CalendarCategory category) {
  return category.toString().split('.').last;
}

/// Get color for a category (with fallback).
Color getCalendarCategoryColor(String? value) {
  final cat = calendarCategoryFromString(value);
  return calendarCategoryColors[cat] ?? Colors.grey;
}

/// Get icon for a category (with fallback).
IconData getCalendarCategoryIcon(String? value) {
  final cat = calendarCategoryFromString(value);
  return calendarCategoryIcons[cat] ?? Icons.star_border;
}

/// Get label for a category (with fallback).
String getCalendarCategoryLabel(String? value) {
  final cat = calendarCategoryFromString(value);
  return calendarCategoryLabels[cat] ?? 'Other';
}

/// Get color for an event based on whether it has a reminder
/// Events with reminders get vibrant colors, events without get muted colors
Color getEventColorWithReminder(String? category, bool hasReminder) {
  final baseColor = getCalendarCategoryColor(category);
  if (hasReminder) {
    return baseColor; // Use vibrant color for events with reminders
  } else {
    return baseColor.withOpacity(0.4); // Use muted color for events without reminders
  }
}

/// Get categories appropriate for regular events (not milestones)
List<String> getEventCategories() {
  return [
    'event',
    'date_idea',
    'anniversary',
    'birthday',
    'holiday',
    'trip',
    'appointment',
    'celebration',
    'check_in',
    'custom',
    'other',
  ];
}

/// Get categories appropriate for milestones (focused on important couple milestones)
List<String> getMilestoneCategories() {
  return [
    'engagement',
    'wedding',
    'anniversary',
    'first_date',
    'first_kiss',
    'moved_in',
    'got_pet',
    'baby',
    'birthday',
    'celebration',
    'custom',
    'goal',
  ];
}