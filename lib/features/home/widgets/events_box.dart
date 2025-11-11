// lib/features/home/widgets/events_box.dart

import 'package:flutter/material.dart';
import 'dart:math';
import 'package:intl/intl.dart';
// Removed unused provider imports; navigation now uses named routes.
import 'package:feelings/features/calendar/screens/add_event_wizard_screen.dart';
import 'package:feelings/features/calendar/models/calendar_event.dart';
import 'package:animate_do/animate_do.dart';
import 'package:feelings/features/calendar/screens/calendar_screen.dart';

// --- Constants for calculating animation heights ---
const double _kCardHeight = 85.0;
const double _kCardSpacing = 16.0;
const double _kActionsHeight = 50.0;

class EventsBox extends StatefulWidget {
  // This widget no longer fetches its own data.
  // It receives the events to display directly from the ViewModel.
  final List<CalendarEvent> events;

  const EventsBox({super.key, required this.events});

  @override
  State<EventsBox> createState() => _EventsBoxState();
}

class _EventsBoxState extends State<EventsBox> {
  bool _isExpanded = false;

  // Note: For better separation of concerns, these helper methods could be
  // moved into the CalendarEvent model itself as getters.
  int _getDaysUntilEvent(DateTime eventDate) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final eventDay = DateTime(eventDate.year, eventDate.month, eventDate.day);
    return eventDay.difference(today).inDays;
  }

  String _formatDaysText(int days) {
    if (days == 0) return 'Today';
    if (days == 1) return 'Tomorrow';
    if (days == -1) return 'Yesterday';
    if (days < -1) return '${days.abs()} days ago';
    return 'In $days days';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Filter out past events and sort by start date
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final upcomingEvents = widget.events
        .where((event) {
          final eventDay = DateTime(event.startDate.year, event.startDate.month, event.startDate.day);
          return eventDay.compareTo(today) >= 0;
        })
        .toList()
      ..sort((a, b) => a.startDate.compareTo(b.startDate));
    final hasEvents = upcomingEvents.isNotEmpty;

    double calculateHeight() {
      if (!hasEvents) {
        return 90.0; // Reduced from 120.0 for a more compact empty state
      }
      if (!_isExpanded) {
        return _kCardHeight;
      }
      final eventsHeight = upcomingEvents.length * (_kCardHeight + _kCardSpacing);
      final actionsHeight = _kActionsHeight;
      return eventsHeight + actionsHeight + 16;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: theme.colorScheme.outline.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          _CustomHeader(
            isExpanded: _isExpanded,
            onTap: hasEvents ? () => setState(() => _isExpanded = !_isExpanded) : null,
          ),
          const SizedBox(height: 16),
          AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeInOutCubic,
            height: calculateHeight(),
            child: hasEvents
                ? Stack(
                    children: [
                      ...List.generate(min(upcomingEvents.length, 3), (index) {
                        final event = upcomingEvents[index];
                        return _AnimatedEventCard(
                          isExpanded: _isExpanded,
                          index: index,
                          event: event,
                          daysUntilText: _formatDaysText(_getDaysUntilEvent(event.startDate)),
                        );
                      }),
                      _AnimatedActions(
                        isExpanded: _isExpanded,
                        topPosition: upcomingEvents.length * (_kCardHeight + _kCardSpacing),
                      ),
                    ],
                  )
                : const _EmptyState(),
          ),
        ],
      ),
    );
  }
}


// --- All sub-widgets below this line remain unchanged ---

class _CustomHeader extends StatelessWidget {
  final bool isExpanded;
  final VoidCallback? onTap;

  const _CustomHeader({required this.isExpanded, this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasTapAction = onTap != null;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            "Coming Up",
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
          if (hasTapAction)
            AnimatedRotation(
              turns: isExpanded ? 0.5 : 0.0,
              duration: const Duration(milliseconds: 300),
              child: Icon(Icons.keyboard_arrow_down, color: theme.colorScheme.secondary, size: 28),
            ),
        ],
      ),
    );
  }
}

class _AnimatedEventCard extends StatelessWidget {
  final bool isExpanded;
  final int index;
  final CalendarEvent event;
  final String daysUntilText;

  const _AnimatedEventCard({
    required this.isExpanded,
    required this.index,
    required this.event,
    required this.daysUntilText,
  });

  @override
  Widget build(BuildContext context) {
    final bool isFirstItem = index == 0;
    final topPosition = index * (_kCardHeight + _kCardSpacing);

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOutCubic,
      top: isExpanded || isFirstItem ? topPosition : (12.0 * index),
      left: 0,
      right: 0,
      child: FadeInUp(
        animate: isExpanded || isFirstItem,
        duration: const Duration(milliseconds: 400),
        delay: Duration(milliseconds: isExpanded ? 100 * index : 0),
        from: 20,
        child: _EventCard(
          event: event,
          daysUntilText: daysUntilText,
        ),
      ),
    );
  }
}

class _TicketClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    const double radius = 12.0;

    path.moveTo(0, 0);
    path.lineTo(size.width, 0);
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.lineTo(0, 0);

    final cutoutPath = Path()
      ..addArc(
        Rect.fromCircle(center: Offset(0, size.height / 2), radius: radius),
        -pi / 2,
        pi,
      );

    return Path.combine(PathOperation.difference, path, cutoutPath);
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

class _DashedLinePainter extends CustomPainter {
  final Color color;
  _DashedLinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    double dashHeight = 5, dashSpace = 3, startY = 0;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    while (startY < size.height) {
      canvas.drawLine(Offset(0, startY), Offset(0, startY + dashHeight), paint);
      startY += dashHeight + dashSpace;
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

class _EventCard extends StatelessWidget {
  const _EventCard({
    required this.event,
    required this.daysUntilText,
  });

  final CalendarEvent event;
  final String daysUntilText;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final month = DateFormat('MMM').format(event.startDate).toUpperCase();
    final day = event.startDate.day.toString();

    return ClipPath(
      clipper: _TicketClipper(),
      child: Container(
        height: _kCardHeight,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [
              colorScheme.primary.withOpacity(0.05),
              colorScheme.secondary.withOpacity(0.05),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Row(
          children: [
            const SizedBox(width: 16),
            SizedBox(
              width: 55,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(day, style: theme.textTheme.headlineSmall?.copyWith(color: colorScheme.primary, fontWeight: FontWeight.bold)),
                  Text(month, style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.primary, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            const SizedBox(width: 12),
            CustomPaint(
              size: const Size(1, double.infinity),
              painter: _DashedLinePainter(color: colorScheme.primary.withOpacity(0.3)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    event.title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    daysUntilText,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.secondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnimatedActions extends StatelessWidget {
  final bool isExpanded;
  final double topPosition;

  const _AnimatedActions({
    required this.isExpanded,
    required this.topPosition,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOutCubic,
      top: isExpanded ? topPosition : 40,
      left: 0,
      right: 0,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 250),
        opacity: isExpanded ? 1.0 : 0.0,
        child: Container(
          height: _kActionsHeight,
          padding: const EdgeInsets.only(top: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: () {
                  // Push the CalendarScreen onto the navigation stack directly.
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const CalendarScreen()));
                },
                child: const Text("View All"),
              ),
              const _AddEventButton(),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          "No upcoming events.",
          style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.6)),
        ),
        const SizedBox(height: 16),
        const _AddEventButton(),
      ],
    );
  }
}

class _AddEventButton extends StatelessWidget {
  const _AddEventButton();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return OutlinedButton.icon(
      icon: const Icon(Icons.add, size: 18),
      label: const Text("Add"),
      onPressed: () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const AddEventWizardScreen()));
      },
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        side: BorderSide(color: theme.colorScheme.secondary.withOpacity(0.5)),
      ),
    );
  }
}