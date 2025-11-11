import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:feelings/providers/calendar_provider.dart';
import 'package:feelings/providers/user_provider.dart';
import '../calendar_types.dart';
import 'package:feelings/widgets/pulsing_dots_indicator.dart';

class AddMilestoneForm extends StatefulWidget {
  final String coupleId;
  const AddMilestoneForm({super.key, required this.coupleId});

  @override
  State<AddMilestoneForm> createState() => _AddMilestoneFormState();
}

class _AddMilestoneFormState extends State<AddMilestoneForm> {
  String formatDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${date.day.toString().padLeft(2, '0')} ${months[date.month - 1]} ${date.year}';
  }

  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  DateTime? _date;
  String _type = 'goal';
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
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? DateTime.now(),
      firstDate: DateTime(1950),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _date = picked);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _date == null) return;
    final provider = Provider.of<CalendarProvider>(context, listen: false);
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    String? userId = userProvider.currentUser?.id ?? userProvider.getUserId();

    if (userId == null || userId.isEmpty) {
      if (mounted) {
        setState(() => _error = 'Could not determine user ID. Please re-login.');
      }
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await provider.addMilestone(widget.coupleId, {
        'title': _titleController.text.trim(),
        'date': Timestamp.fromDate(_date!),
        'type': _type,
        'description': _descController.text.trim(),
        'createdBy': userId,
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
                      child: Icon(Icons.add_circle,
                          color: colorScheme.primary, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Add Milestone',
                        style: theme.textTheme.titleLarge,
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
                          hintText: 'e.g., Our First Anniversary',
                        ),
                        validator: (value) => (value == null ||
                                value.trim().isEmpty)
                            ? 'Please enter a title'
                            : null,
                      ),
                      const SizedBox(height: 20),
                      DropdownButtonFormField<String>(
                        initialValue: _type,
                        decoration: const InputDecoration(
                          labelText: 'Milestone Type',
                        ),
                        items: _types.map((type) => DropdownMenuItem<String>(
                                  value: type['value'],
                                  child: Row(
                                    children: [
                                      Icon(type['icon'],
                                          size: 20, color: type['color']),
                                      const SizedBox(width: 12),
                                      Text(type['label'],
                                          style: theme.textTheme.bodyMedium),
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
                            _date != null
                                ? formatDate(_date!)
                                : 'Select Date',
                            style: theme.textTheme.bodyLarge?.copyWith(
                                color: _date != null
                                    ? colorScheme.onSurface
                                    : colorScheme.onSurfaceVariant),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      TextFormField(
                        controller: _descController,
                        decoration: const InputDecoration(
                          labelText: 'Description (Optional)',
                          hintText: 'Add details about this milestone...',
                        ),
                        maxLines: 3,
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 16),
                        Text(_error!,
                            style: theme.textTheme.bodyMedium
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
                              : const Text('Save Milestone'),
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