import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:feelings/providers/calendar_provider.dart';
import 'package:feelings/providers/user_provider.dart';
import '../calendar_types.dart';
import '../widgets/empty_state_widget.dart';
import 'package:feelings/widgets/pulsing_dots_indicator.dart';

class AddEventWizardScreen extends StatefulWidget {
  final String? initialTitle;
  final String? initialDescription;

  const AddEventWizardScreen({
    super.key,
    this.initialTitle,
    this.initialDescription,
  });

  @override
  _AddEventWizardScreenState createState() => _AddEventWizardScreenState();
}

class _AddEventWizardScreenState extends State<AddEventWizardScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();

  int _currentStep = 0;
  String? _coupleId;
  bool _isSubmitting = false;

  // Step 1: Basic Info
  DateTime? _startDate;
  DateTime? _startTime;
  String _category = 'event';

  // Step 2: Details
  DateTime? _endDate;
  DateTime? _endTime;
  String _repeat = 'none';

  // Step 3: Advanced
  bool _hasReminder = true;
  DateTime? _reminderTime;
  String _reminderPreset = 'on_time';
  bool _isPersonal = false;

  @override
  void initState() {
    super.initState();
    _initCoupleId();
    if (widget.initialTitle != null) {
      _titleController.text = widget.initialTitle!;
    }
    if (widget.initialDescription != null) {
      _descriptionController.text = widget.initialDescription!;
    }
    // Set default start date/time to now
    final now = DateTime.now();
    _startDate = DateTime(now.year, now.month, now.day);
    _startTime = DateTime(now.year, now.month, now.day, now.hour, now.minute);
  }

  Future<void> _initCoupleId() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final coupleId = userProvider.coupleId;
    setState(() {
      _coupleId = coupleId;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.initialTitle != null
            ? 'Schedule Date Event'
            : 'Add Event'),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Progress Indicator
          Container(
            padding: const EdgeInsets.all(16),
            color: colorScheme.primary.withOpacity(0.1),
            child: Row(
              children: [
                Text(
                  'Step ${_currentStep + 1} of 3',
                  style: theme.textTheme.labelLarge
                      ?.copyWith(color: colorScheme.primary),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: LinearProgressIndicator(
                    value: (_currentStep + 1) / 3,
                    backgroundColor: colorScheme.surfaceContainerHighest,
                    valueColor:
                        AlwaysStoppedAnimation<Color>(colorScheme.primary),
                  ),
                ),
              ],
            ),
          ),

          // Step Content
          Expanded(
            child: Form(
              key: _formKey,
              child: _buildCurrentStep(),
            ),
          ),

          // Navigation Buttons
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: theme.shadowColor.withOpacity(0.1),
                  spreadRadius: 1,
                  blurRadius: 3,
                  offset: const Offset(0, -1),
                ),
              ],
            ),
            child: Row(
              children: [
                if (_currentStep > 0)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _previousStep,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text('Previous'),
                    ),
                  ),
                if (_currentStep > 0) const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _nextStep,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: _isSubmitting
                        ? PulsingDotsIndicator(
                                  size: 30,
                                  colors: [
                                    colorScheme.onPrimary,
                                    colorScheme.onPrimary.withOpacity(0.8),
                                    colorScheme.onPrimary.withOpacity(0.6),
                                  ],
                                )
                        : Text(_currentStep == 2 ? 'Create Event' : 'Next'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case 0:
        return _buildBasicInfoStep();
      case 1:
        return _buildDetailsStep();
      case 2:
        return _buildAdvancedStep();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildBasicInfoStep() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Basic Information', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(
            'Let\'s start with the essentials',
            style: theme.textTheme.bodyLarge
                ?.copyWith(color: colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 32),

          // Title
          TextFormField(
            controller: _titleController,
            decoration: const InputDecoration(
              labelText: 'Event Title *',
              prefixIcon: Icon(Icons.title),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter a title';
              }
              return null;
            },
          ),
          const SizedBox(height: 24),

          // Category Selection
          Text('Category', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          _buildCategoryGrid(),
          const SizedBox(height: 24),

          // Date and Time
          Row(
            children: [
              Expanded(
                child: _buildDatePicker(
                  'Date',
                  _startDate,
                  (date) => setState(() => _startDate = date),
                  Icons.calendar_today,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildTimePicker(
                  'Time',
                  _startTime,
                  (time) => setState(() => _startTime = time),
                  Icons.access_time,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsStep() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Event Details', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(
            'Add more details to your event',
            style: theme.textTheme.bodyLarge
                ?.copyWith(color: colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 32),

          // Description
          TextFormField(
            controller: _descriptionController,
            decoration: const InputDecoration(
              labelText: 'Description',
              prefixIcon: Icon(Icons.description),
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 16),

          // Location
          TextFormField(
            controller: _locationController,
            decoration: const InputDecoration(
              labelText: 'Location',
              prefixIcon: Icon(Icons.location_on),
            ),
          ),
          const SizedBox(height: 24),

          // End Date and Time (Optional)
          Text('End Time (Optional)', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildDatePicker(
                  'End Date',
                  _endDate,
                  (date) => setState(() => _endDate = date),
                  Icons.event_available,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildTimePicker(
                  'End Time',
                  _endTime,
                  (time) => setState(() => _endTime = time),
                  Icons.schedule,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Repeat Options
          Text('Repeat', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          _buildRepeatOptions(),
        ],
      ),
    );
  }

  Widget _buildAdvancedStep() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Advanced Settings', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(
            'Customize your event settings',
            style: theme.textTheme.bodyLarge
                ?.copyWith(color: colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 32),

          // Reminder Settings
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.alarm, color: colorScheme.secondary),
                      const SizedBox(width: 8),
                      Text('Reminder', style: theme.textTheme.titleMedium),
                    ],
                  ),
                  const SizedBox(height: 12),
                  CheckboxListTile(
                    title: const Text('Set a reminder for this event'),
                    value: _hasReminder,
                    onChanged: (value) {
                      setState(() {
                        _hasReminder = value ?? false;
                        if (!_hasReminder) {
                          _reminderTime = null;
                          _reminderPreset = 'none';
                        } else if (_reminderPreset == 'none') {
                          _reminderPreset = 'on_time';
                        }
                      });
                    },
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                  ),
                  if (_hasReminder) ...[
                    const SizedBox(height: 8),
                    _buildReminderOptions(),
                  ],
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 8, left: 16, right: 16),
            child: Text(
              'Due to battery optimization on some devices, reminders may be delayed by a few minutes.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: colorScheme.onSurfaceVariant),
            ),
          ),
          const SizedBox(height: 16),

          // Personal Event Settings
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.person, color: colorScheme.primary),
                      const SizedBox(width: 8),
                      Text('Privacy', style: theme.textTheme.titleMedium),
                    ],
                  ),
                  const SizedBox(height: 12),
                  CheckboxListTile(
                    title: const Text('Make this event personal'),
                    subtitle: const Text('Only visible to you'),
                    value: _isPersonal,
                    onChanged: (value) {
                      setState(() {
                        _isPersonal = value ?? false;
                      });
                    },
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryGrid() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final categories = getEventCategories().map((catValue) {
      return {
        'label': getCalendarCategoryLabel(catValue),
        'value': catValue,
        'icon': getCalendarCategoryIcon(catValue),
        'color': getCalendarCategoryColor(catValue),
      };
    }).toList();

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 1.2,
      ),
      itemCount: categories.length,
      itemBuilder: (context, index) {
        final category = categories[index];
        final isSelected = _category == category['value'];
        final categoryColor = category['color'] as Color;

        return GestureDetector(
          onTap: () =>
              setState(() => _category = category['value'] as String),
          child: Container(
            decoration: BoxDecoration(
              color: isSelected
                  ? categoryColor.withOpacity(0.2)
                  : colorScheme.surfaceContainerHighest.withOpacity(0.5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? categoryColor : colorScheme.outline,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  category['icon'] as IconData,
                  color: categoryColor,
                  size: 24,
                ),
                const SizedBox(height: 4),
                Text(
                  category['label'] as String,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? categoryColor : colorScheme.onSurface,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDatePicker(String label, DateTime? selectedDate,
      ValueChanged<DateTime> onDateSelected, IconData icon) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: selectedDate ?? DateTime.now(),
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
        );
        if (picked != null) {
          onDateSelected(picked);
        }
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
        ),
        child: Text(
          selectedDate != null
              ? '${selectedDate.day.toString().padLeft(2, '0')}/${selectedDate.month.toString().padLeft(2, '0')}/${selectedDate.year}'
              : 'Select Date',
          style: theme.textTheme.bodyLarge,
        ),
      ),
    );
  }

  Widget _buildTimePicker(String label, DateTime? selectedTime,
      ValueChanged<DateTime> onTimeSelected, IconData icon) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: () async {
        final picked = await showTimePicker(
          context: context,
          initialTime: TimeOfDay.fromDateTime(selectedTime ?? DateTime.now()),
        );
        if (picked != null) {
          final now = DateTime.now();
          final newTime = DateTime(
            now.year,
            now.month,
            now.day,
            picked.hour,
            picked.minute,
          );
          onTimeSelected(newTime);
        }
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
        ),
        child: Text(
          selectedTime != null
              ? '${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}'
              : 'Select Time',
          style: theme.textTheme.bodyLarge,
        ),
      ),
    );
  }

  Widget _buildRepeatOptions() {
    final options = [
      {'value': 'none', 'label': 'No Repeat'},
      {'value': 'daily', 'label': 'Daily'},
      {'value': 'weekly', 'label': 'Weekly'},
      {'value': 'monthly', 'label': 'Monthly'},
      {'value': 'yearly', 'label': 'Yearly'},
    ];

    return DropdownButtonFormField<String>(
      initialValue: _repeat,
      decoration: const InputDecoration(
        prefixIcon: Icon(Icons.repeat),
      ),
      items: options.map((option) {
        return DropdownMenuItem<String>(
          value: option['value'] as String,
          child: Text(option['label'] as String),
        );
      }).toList(),
      onChanged: (value) {
        if (value != null) {
          setState(() => _repeat = value);
        }
      },
    );
  }

  Widget _buildReminderOptions() {
    final theme = Theme.of(context);
    final presets = [
      {'value': 'on_time', 'label': 'At time of event'},
      {'value': '5min', 'label': '5 minutes before'},
      {'value': '15min', 'label': '15 minutes before'},
      {'value': '1hr', 'label': '1 hour before'},
      {'value': '1day', 'label': '1 day before'},
      {'value': 'custom', 'label': 'Custom time'},
    ];

    return Column(
      children: [
        DropdownButtonFormField<String>(
          initialValue: _reminderPreset,
          decoration: const InputDecoration(
            labelText: 'Reminder Time',
            prefixIcon: Icon(Icons.alarm),
          ),
          items: presets.map((preset) {
            return DropdownMenuItem<String>(
              value: preset['value'] as String,
              child: Text(preset['label'] as String),
            );
          }).toList(),
          onChanged: (value) {
            if (value != null) {
              setState(() {
                _reminderPreset = value;
                if (value == 'custom' && _reminderTime == null) {
                  final startDateTime = DateTime(
                    _startDate!.year, _startDate!.month, _startDate!.day,
                    _startTime!.hour, _startTime!.minute,
                  );
                  _reminderTime = startDateTime.subtract(const Duration(minutes: 15));
                }
              });
            }
          },
        ),
        if (_reminderPreset == 'custom') ...[
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildDatePicker(
                  'Custom Date',
                  _reminderTime,
                  (date) {
                    setState(() {
                      final oldTime = TimeOfDay.fromDateTime(_reminderTime ?? DateTime.now());
                      _reminderTime = DateTime(date.year, date.month, date.day, oldTime.hour, oldTime.minute);
                    });
                  },
                  Icons.calendar_today,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildTimePicker(
                  'Custom Time',
                  _reminderTime,
                  (time) {
                    setState(() {
                      final oldDate = _reminderTime ?? DateTime.now();
                      _reminderTime = DateTime(oldDate.year, oldDate.month, oldDate.day, time.hour, time.minute);
                    });
                  },
                  Icons.access_time,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
      });
    }
  }

  void _nextStep() {
    if (_currentStep < 2) {
      if (_validateCurrentStep()) {
        setState(() {
          _currentStep++;
        });
      }
    } else {
      _submitEvent();
    }
  }

  bool _validateCurrentStep() {
    switch (_currentStep) {
      case 0:
        return _formKey.currentState!.validate() &&
            _startDate != null &&
            _startTime != null;
      case 1:
        return true; 
      case 2:
        return true;
      default:
        return false;
    }
  }

  Future<void> _submitEvent() async {
    if (!_validateCurrentStep()) {
      return;
    }

    setState(() => _isSubmitting = true);
    final theme = Theme.of(context);

    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final userId = userProvider.getUserId();

      final startDateTime = DateTime(
        _startDate!.year,
        _startDate!.month,
        _startDate!.day,
        _startTime!.hour,
        _startTime!.minute,
      );

      DateTime? endDateTime;
      if (_endDate != null && _endTime != null) {
        endDateTime = DateTime(
          _endDate!.year,
          _endDate!.month,
          _endDate!.day,
          _endTime!.hour,
          _endTime!.minute,
        );
      }

      DateTime? finalReminderTime;
      if (_hasReminder) {
        switch (_reminderPreset) {
          case 'on_time':
            finalReminderTime = startDateTime;
            break;
          case '5min':
            finalReminderTime = startDateTime.subtract(const Duration(minutes: 5));
            break;
          case '15min':
            finalReminderTime = startDateTime.subtract(const Duration(minutes: 15));
            break;
          case '1hr':
            finalReminderTime = startDateTime.subtract(const Duration(hours: 1));
            break;
          case '1day':
            finalReminderTime = startDateTime.subtract(const Duration(days: 1));
            break;
          case 'custom':
            finalReminderTime = _reminderTime;
            break;
          default:
            finalReminderTime = null;
        }
      }

      final eventData = {
        "title": _titleController.text,
        "description": _descriptionController.text,
        "startDate": Timestamp.fromDate(startDateTime),
        "endDate": endDateTime != null ? Timestamp.fromDate(endDateTime) : null,
        "reminderTime":
            finalReminderTime != null ? Timestamp.fromDate(finalReminderTime) : null,
        "createdBy": userId ?? "user",
        "category": _category,
        "location": _locationController.text,
        "repeat": _repeat,
        "reminderPreset": _reminderPreset,
        "isPersonal": _isPersonal,
        "personalUserId": _isPersonal ? userId : null,
      };

      await Provider.of<CalendarProvider>(context, listen: false)
          .addEvent(_coupleId!, eventData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                widget.initialTitle != null
                    ? 'Date event scheduled successfully!'
                    : 'Event added successfully!',
                style:
                    TextStyle(color: theme.colorScheme.onSecondary)),
            backgroundColor: theme.colorScheme.secondary,
            duration: const Duration(seconds: 2),
          ),
        );
        Navigator.pop(context);
      }
    } catch (error) {
      debugPrint("Error adding event: $error");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to add event: $error")),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }
}