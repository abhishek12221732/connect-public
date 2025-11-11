import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:feelings/providers/calendar_provider.dart';
import '../calendar_types.dart';
import 'package:feelings/widgets/pulsing_dots_indicator.dart';

// Local date formatting helper
String formatDate(DateTime date) {
  // Example: 21 August 2025
  final months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];
  return '${date.day} ${months[date.month - 1]} ${date.year}';
}

class EditMilestoneForm extends StatefulWidget {
  final String coupleId;
  final dynamic milestone;
  const EditMilestoneForm(
      {super.key, required this.coupleId, required this.milestone});

  @override
  State<EditMilestoneForm> createState() => _EditMilestoneFormState();
}

class _EditMilestoneFormState extends State<EditMilestoneForm> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _descController;
  late DateTime _date;
  late String _type;
  bool _submitting = false;
  String? _error;

  final List<Map<String, dynamic>> _types = getMilestoneCategories()
      .map((catValue) => {
            'label': getCalendarCategoryLabel(catValue),
            'value': catValue,
            'icon': getCalendarCategoryIcon(catValue),
            'color': getCalendarCategoryColor(catValue),
          })
      .toList();

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.milestone.title);
    _descController =
        TextEditingController(text: widget.milestone.description ?? '');
    _date = widget.milestone.date;
    _type = widget.milestone.type;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(1950),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _date = picked);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final provider = Provider.of<CalendarProvider>(context, listen: false);
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await provider.updateMilestone(widget.coupleId, widget.milestone.id, {
        'title': _titleController.text.trim(),
        'date': Timestamp.fromDate(_date),
        'type': _type,
        'description': _descController.text.trim(),
      });
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Container(
        padding:
            EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.edit, color: colorScheme.primary, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Edit Milestone',
                        style: theme.textTheme.headlineSmall,
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: colorScheme.onSurfaceVariant),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              // Form Content
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFormField(
                        controller: _titleController,
                        decoration: const InputDecoration(
                          labelText: 'Milestone Title',
                        ),
                        validator: (value) =>
                            (value == null || value.trim().isEmpty)
                                ? 'Please enter a title'
                                : null,
                      ),
                      const SizedBox(height: 20),
                      DropdownButtonFormField<String>(
                        initialValue: _type,
                        decoration: const InputDecoration(
                          labelText: 'Milestone Type',
                        ),
                        items: _types
                            .map((type) => DropdownMenuItem<String>(
                                  value: type['value'],
                                  child: Row(
                                    children: [
                                      Icon(type['icon'],
                                          size: 20, color: type['color']),
                                      const SizedBox(width: 12),
                                      Text(type['label'],
                                          style: theme.textTheme.bodyLarge),
                                    ],
                                  ),
                                ))
                            .toList(),
                        onChanged: (value) {
                          if (value != null) setState(() => _type = value);
                        },
                      ),
                      const SizedBox(height: 20),
                      GestureDetector(
                        onTap: _pickDate,
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: 'Date',
                            prefixIcon: Icon(Icons.calendar_today,
                                color: colorScheme.primary, size: 20),
                          ),
                          child: Text(
                            formatDate(_date),
                            style: theme.textTheme.bodyLarge,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      TextFormField(
                        controller: _descController,
                        decoration: const InputDecoration(
                          labelText: 'Description (Optional)',
                        ),
                        maxLines: 3,
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 16),
                        Text(_error!,
                            style: theme.textTheme.bodyLarge
                                ?.copyWith(color: colorScheme.error)),
                      ],
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _submitting ? null : _submit,
                          child: _submitting
                             ? PulsingDotsIndicator(
                                  size: 30,
                                  colors: [
                                    colorScheme.onPrimary,
                                    colorScheme.onPrimary.withOpacity(0.8),
                                    colorScheme.onPrimary.withOpacity(0.6),
                                  ],
                                )
                              : const Text('Update Milestone'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}