import 'package:flutter/material.dart';
import 'package:feelings/widgets/pulsing_dots_indicator.dart';

class EditEventView extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController titleController;
  final TextEditingController descriptionController;
  final TextEditingController locationController;
  final DateTime? startDate;
  final DateTime? endDate;
  final DateTime? reminderTime;
  final bool isSubmitting;
  final bool hasReminder;
  final String category;
  final String repeat;
  final List<Map<String, dynamic>> categoryOptions;
  final ValueChanged<String?> onCategoryChanged;
  final ValueChanged<String?> onRepeatChanged;
  final ValueChanged<bool> onReminderChanged;
  final VoidCallback pickStartDate;
  final VoidCallback pickStartTime;
  final VoidCallback pickEndDate;
  final VoidCallback pickEndTime;
  final VoidCallback pickReminderTime;
  final VoidCallback handleSubmit;

  const EditEventView({
    super.key,
    required this.formKey,
    required this.titleController,
    required this.descriptionController,
    required this.locationController,
    this.startDate,
    this.endDate,
    this.reminderTime,
    required this.isSubmitting,
    required this.hasReminder,
    required this.category,
    required this.repeat,
    required this.categoryOptions,
    required this.onCategoryChanged,
    required this.onRepeatChanged,
    required this.onReminderChanged,
    required this.pickStartDate,
    required this.pickStartTime,
    required this.pickEndDate,
    required this.pickEndTime,
    required this.pickReminderTime,
    required this.handleSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Stack(
      children: [
        Form(
          key: formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildSection(
                context,
                icon: Icons.edit,
                title: 'Event Details',
                child: Column(
                  children: [
                    _buildCategoryDropdown(),
                    const SizedBox(height: 16),
                    _buildTitleField(),
                    const SizedBox(height: 16),
                    _buildDescriptionField(),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _buildSection(
                context,
                icon: Icons.schedule,
                title: 'Date & Time',
                child: Row(
                  children: [
                    Expanded(child: _buildDateTimePicker(context, isStart: true, isDate: true)),
                    const SizedBox(width: 12),
                    Expanded(child: _buildDateTimePicker(context, isStart: true, isDate: false)),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _buildSection(
                context,
                icon: Icons.settings,
                title: 'Additional Details',
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(child: _buildDateTimePicker(context, isStart: false, isDate: true)),
                        const SizedBox(width: 12),
                        Expanded(child: _buildDateTimePicker(context, isStart: false, isDate: false)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildLocationField(context),
                    const SizedBox(height: 16),
                    _buildRepeatDropdown(context),
                    const SizedBox(height: 16),
                    _buildReminderSection(context),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _buildSubmitButton(context),
            ],
          ),
        ),
        if (isSubmitting)
          Container(
            color: theme.colorScheme.surface.withOpacity(0.7),
            child:  Center(child:PulsingDotsIndicator(
            size: 80,
            colors: [
              Theme.of(context).colorScheme.primary,
              Theme.of(context).colorScheme.primary,
              Theme.of(context).colorScheme.primary,
            ],
          ),),
          ),
      ],
    );
  }

  Widget _buildSection(BuildContext context, {required IconData icon, required String title, required Widget child}) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Card(
      elevation: 2,
      shadowColor: colorScheme.primary.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      color: colorScheme.primary.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(8)),
                  child: Icon(icon, color: colorScheme.primary, size: 20),
                ),
                const SizedBox(width: 12),
                Text(title, style: theme.textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryDropdown() => DropdownButtonFormField<String>(
        initialValue: category,
        decoration: const InputDecoration(labelText: 'Category'),
        items: categoryOptions
            .map((cat) => DropdownMenuItem<String>(
                  value: cat['value'],
                  child: Row(children: [
                    Icon(cat['icon'], color: cat['color'], size: 20),
                    const SizedBox(width: 8),
                    Text(cat['label']),
                  ]),
                ))
            .toList(),
        onChanged: onCategoryChanged,
      );

  Widget _buildTitleField() => TextFormField(
        controller: titleController,
        decoration: const InputDecoration(labelText: 'Title'),
        validator: (value) =>
            (value == null || value.trim().isEmpty) ? 'Please enter a title' : null,
      );

  Widget _buildDescriptionField() => TextFormField(
        controller: descriptionController,
        decoration: const InputDecoration(labelText: 'Description (Optional)'),
        maxLines: 3,
      );

  Widget _buildLocationField(BuildContext context) => TextFormField(
        controller: locationController,
        decoration: InputDecoration(
          labelText: 'Location (Optional)',
          prefixIcon: Icon(Icons.location_on, color: Theme.of(context).colorScheme.primary),
        ),
      );

  Widget _buildRepeatDropdown(BuildContext context) => DropdownButtonFormField<String>(
        initialValue: repeat,
        decoration: InputDecoration(
          labelText: 'Repeat',
          prefixIcon: Icon(Icons.repeat, color: Theme.of(context).colorScheme.primary),
        ),
        items: const [
          DropdownMenuItem(value: 'none', child: Text('No Repeat')),
          DropdownMenuItem(value: 'daily', child: Text('Daily')),
          DropdownMenuItem(value: 'weekly', child: Text('Weekly')),
          DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
          DropdownMenuItem(value: 'yearly', child: Text('Yearly')),
        ],
        onChanged: onRepeatChanged,
      );

  Widget _buildDateTimePicker(BuildContext context, {required bool isStart, required bool isDate}) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final dt = isStart ? startDate : endDate;
    final label = '${isStart ? "Start" : "End"} ${isDate ? "Date" : "Time"}';
    final text = dt == null
        ? (isStart ? 'Select ${isDate ? "Date" : "Time"}' : 'Optional')
        : (isDate
            ? '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}'
            : '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}');

    return InkWell(
      onTap: isStart ? (isDate ? pickStartDate : pickStartTime) : (isDate ? pickEndDate : pickEndTime),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        ),
        child: Text(
          text,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: dt != null ? colorScheme.onSurface : colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  Widget _buildReminderSection(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colorScheme.outline.withOpacity(0.5))
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Column(
          children: [
            Row(children: [
              Icon(Icons.alarm, color: colorScheme.primary, size: 20),
              const SizedBox(width: 8),
              Text('Reminder', style: theme.textTheme.titleMedium),
              const Spacer(),
              Switch(value: hasReminder, onChanged: onReminderChanged),
            ]),
            if (hasReminder) ...[
              const Divider(),
              InkWell(
                onTap: pickReminderTime,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  child: Row(children: [
                    Icon(Icons.schedule, color: colorScheme.primary, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      reminderTime != null
                          ? '${reminderTime!.day.toString().padLeft(2, '0')}/${reminderTime!.month.toString().padLeft(2, '0')}/${reminderTime!.year} ${reminderTime!.hour.toString().padLeft(2, '0')}:${reminderTime!.minute.toString().padLeft(2, '0')}'
                          : 'Select Reminder Time',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: reminderTime != null ? colorScheme.onSurface : colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ]),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSubmitButton(BuildContext context) => SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: isSubmitting ? null : handleSubmit,
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
          child: isSubmitting
              ? SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Theme.of(context).colorScheme.onPrimary,
                  ),
                )
              : const Text('Save Changes'),
        ),
      );
}