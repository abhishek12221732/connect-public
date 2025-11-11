import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:feelings/features/calendar/models/calendar_event.dart';
import 'package:feelings/providers/calendar_provider.dart';
import 'package:feelings/features/calendar/services/reminder_service.dart';
import '../calendar_types.dart';
import './edit_event_view.dart'; // Import the new UI file

class EditEventScreen extends StatefulWidget {
  final CalendarEvent event;
  final String coupleId;

  const EditEventScreen({super.key, required this.event, required this.coupleId});

  @override
  _EditEventScreenState createState() => _EditEventScreenState();
}

class _EditEventScreenState extends State<EditEventScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late TextEditingController _locationController;

  DateTime? _startDate;
  DateTime? _endDate;
  DateTime? _reminderTime;
  bool _isSubmitting = false;
  bool _hasReminder = false;
  String _category = 'event';
  String _repeat = 'none';

  final List<Map<String, dynamic>> _allCategoryOptions = [
    {'label': 'Event', 'value': 'event', 'icon': getCalendarCategoryIcon('event'), 'color': getCalendarCategoryColor('event')},
    {'label': 'Date Idea', 'value': 'date_idea', 'icon': getCalendarCategoryIcon('date_idea'), 'color': getCalendarCategoryColor('date_idea')},
    {'label': 'Anniversary', 'value': 'anniversary', 'icon': getCalendarCategoryIcon('anniversary'), 'color': getCalendarCategoryColor('anniversary')},
    {'label': 'Birthday', 'value': 'birthday', 'icon': getCalendarCategoryIcon('birthday'), 'color': getCalendarCategoryColor('birthday')},
    {'label': 'Holiday', 'value': 'holiday', 'icon': getCalendarCategoryIcon('holiday'), 'color': getCalendarCategoryColor('holiday')},
    {'label': 'Trip', 'value': 'trip', 'icon': getCalendarCategoryIcon('trip'), 'color': getCalendarCategoryColor('trip')},
    {'label': 'Goal', 'value': 'goal', 'icon': getCalendarCategoryIcon('goal'), 'color': getCalendarCategoryColor('goal')},
    {'label': 'Appointment', 'value': 'appointment', 'icon': getCalendarCategoryIcon('appointment'), 'color': getCalendarCategoryColor('appointment')},
    {'label': 'Celebration', 'value': 'celebration', 'icon': getCalendarCategoryIcon('celebration'), 'color': getCalendarCategoryColor('celebration')},
    {'label': 'Engagement', 'value': 'engagement', 'icon': getCalendarCategoryIcon('engagement'), 'color': getCalendarCategoryColor('engagement')},
    {'label': 'Wedding', 'value': 'wedding', 'icon': getCalendarCategoryIcon('wedding'), 'color': getCalendarCategoryColor('wedding')},
    {'label': 'First Date', 'value': 'first_date', 'icon': getCalendarCategoryIcon('first_date'), 'color': getCalendarCategoryColor('first_date')},
    {'label': 'First Kiss', 'value': 'first_kiss', 'icon': getCalendarCategoryIcon('first_kiss'), 'color': getCalendarCategoryColor('first_kiss')},
    {'label': 'Moved In', 'value': 'moved_in', 'icon': getCalendarCategoryIcon('moved_in'), 'color': getCalendarCategoryColor('moved_in')},
    {'label': 'Got a Pet', 'value': 'got_pet', 'icon': getCalendarCategoryIcon('got_pet'), 'color': getCalendarCategoryColor('got_pet')},
    {'label': 'Baby', 'value': 'baby', 'icon': getCalendarCategoryIcon('baby'), 'color': getCalendarCategoryColor('baby')},
    {'label': 'Check-In', 'value': 'check_in', 'icon': getCalendarCategoryIcon('check_in'), 'color': getCalendarCategoryColor('check_in')},
    {'label': 'Custom', 'value': 'custom', 'icon': getCalendarCategoryIcon('custom'), 'color': getCalendarCategoryColor('custom')},
    {'label': 'Other', 'value': 'other', 'icon': getCalendarCategoryIcon('other'), 'color': getCalendarCategoryColor('other')},
  ];


  List<Map<String, dynamic>> get _categoryOptions {
    final milestoneCategories = getMilestoneCategories();
    final isCurrentCategoryMilestone = milestoneCategories.contains(_category);

    if (isCurrentCategoryMilestone) {
      return _allCategoryOptions
          .where((cat) => milestoneCategories.contains(cat['value']))
          .toList();
    } else {
      final eventCategories = getEventCategories();
      return _allCategoryOptions
          .where((cat) => eventCategories.contains(cat['value']))
          .toList();
    }
  }

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.event.title);
    _descriptionController =
        TextEditingController(text: widget.event.description);
    _locationController = TextEditingController(text: widget.event.location ?? '');
    _startDate = widget.event.startDate;
    _endDate = widget.event.endDate;
    _reminderTime = widget.event.reminderTime;
    _category = widget.event.category;
    _repeat = widget.event.repeat ?? 'none';
    _hasReminder = widget.event.reminderTime != null ||
        (widget.event.reminderPreset != null &&
            widget.event.reminderPreset != 'none');
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime(
      {bool pickDate = true, bool isStart = true, bool isReminder = false}) async {
    DateTime initialDate = isReminder
        ? (_reminderTime ?? _startDate ?? DateTime.now())
        : (isStart
            ? (_startDate ?? DateTime.now())
            : (_endDate ?? _startDate ?? DateTime.now()));

    DateTime? pickedDate;
    if (pickDate) {
      pickedDate = await showDatePicker(
        context: context,
        initialDate: initialDate,
        firstDate: DateTime(2000),
        lastDate: DateTime(2100),
      );
    }

    TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initialDate),
    );

    if (pickedDate == null && pickedTime == null) return; // User cancelled both

    setState(() {
      final pDate = pickedDate ?? initialDate;
      final pTime = pickedTime ?? TimeOfDay.fromDateTime(initialDate);
      final finalDateTime =
          DateTime(pDate.year, pDate.month, pDate.day, pTime.hour, pTime.minute);

      if (isReminder) {
        _reminderTime = finalDateTime;
      } else if (isStart) {
        _startDate = finalDateTime;
      } else {
        _endDate = finalDateTime;
      }
    });
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate() || _startDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please fill all required fields")));
      return;
    }

    setState(() => _isSubmitting = true);

    final notificationService = ReminderService();
    final theme = Theme.of(context);

    final updatedData = {
      "title": _titleController.text,
      "description": _descriptionController.text,
      "location":
          _locationController.text.isNotEmpty ? _locationController.text : null,
      "category": _category,
      "repeat": _repeat,
      "startDate": Timestamp.fromDate(_startDate!),
      "endDate": _endDate != null ? Timestamp.fromDate(_endDate!) : null,
      "reminderTime": _hasReminder && _reminderTime != null
          ? Timestamp.fromDate(_reminderTime!)
          : null,
      "reminderPreset": _hasReminder ? 'custom' : 'none',
      "notificationId": null,
    };

    try {
      if (widget.event.notificationId != null) {
        await notificationService.cancelNotification(widget.event.notificationId!);
      }

      await Provider.of<CalendarProvider>(context, listen: false)
          .updateEvent(widget.coupleId, widget.event.id, updatedData);

      if (_hasReminder && _reminderTime != null) {
        int newNotificationId =
            DateTime.now().millisecondsSinceEpoch.remainder(100000);
        await notificationService.scheduleNotification(
          id: newNotificationId,
          title: _titleController.text,
          body: _descriptionController.text,
          scheduledDate: _reminderTime!,
        );
        await Provider.of<CalendarProvider>(context, listen: false).updateEvent(
            widget.coupleId, widget.event.id, {'notificationId': newNotificationId});
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Event updated successfully!', style: TextStyle(color: theme.colorScheme.onSecondary)),
          backgroundColor: theme.colorScheme.secondary,
        ));
      }
    } catch (error) {
      debugPrint("Error updating event: $error");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Failed to update event: $error", style: TextStyle(color: theme.colorScheme.onError)),
          backgroundColor: theme.colorScheme.error,
        ));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Event'),
      ),
      body: EditEventView(
        formKey: _formKey,
        titleController: _titleController,
        descriptionController: _descriptionController,
        locationController: _locationController,
        startDate: _startDate,
        endDate: _endDate,
        reminderTime: _reminderTime,
        isSubmitting: _isSubmitting,
        hasReminder: _hasReminder,
        category: _category,
        repeat: _repeat,
        categoryOptions: _categoryOptions,
        onCategoryChanged: (value) =>
            setState(() => _category = value ?? _category),
        onRepeatChanged: (value) =>
            setState(() => _repeat = value ?? _repeat),
        onReminderChanged: (value) {
          setState(() {
            _hasReminder = value;
            if (!_hasReminder) _reminderTime = null;
          });
        },
        pickStartDate: () => _pickDateTime(isStart: true, pickDate: true),
        pickStartTime: () => _pickDateTime(isStart: true, pickDate: false),
        pickEndDate: () => _pickDateTime(isStart: false, pickDate: true),
        pickEndTime: () => _pickDateTime(isStart: false, pickDate: false),
        pickReminderTime: () => _pickDateTime(isReminder: true, pickDate: true),
        handleSubmit: _handleSubmit,
      ),
    );
  }
}