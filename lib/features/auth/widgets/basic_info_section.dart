// lib/features/profile/widgets/basic_info_section.dart

import 'package:flutter/material.dart';
import 'package:feelings/features/auth/models/user_model.dart'; // For Gender enum
import 'section_helpers.dart';

class BasicInfoSection extends StatelessWidget {
  final TextEditingController nameController;
  final String? currentMood;
  final String? selectedLoveLanguage;
  final Gender? selectedGender;
  final VoidCallback onSelectMood;
  final VoidCallback onSelectLoveLanguage;
  final ValueChanged<Gender?> onGenderChanged;
  final String Function(Gender) getGenderDisplayName;

  const BasicInfoSection({
    super.key,
    required this.nameController,
    this.currentMood,
    this.selectedLoveLanguage,
    this.selectedGender,
    required this.onSelectMood,
    required this.onSelectLoveLanguage,
    required this.onGenderChanged,
    required this.getGenderDisplayName,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        buildSectionTitle(context, 'Basic Information', icon: Icons.info_outline, color: theme.colorScheme.secondary),
        buildInfoCard(
          Column(
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.sentiment_satisfied_alt_outlined, color: theme.colorScheme.secondary),
                title: const Text('Current Mood'),
                subtitle: Text(
                  currentMood ?? 'Not set',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
                trailing: const Icon(Icons.edit_outlined),
                onTap: onSelectMood,
              ),
              const Divider(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.favorite_outline, color: theme.colorScheme.secondary),
                title: const Text('Love Language'),
                subtitle: Text(
                  selectedLoveLanguage ?? 'Not set',
                  style: theme.textTheme.bodyLarge,
                ),
                trailing: const Icon(Icons.arrow_drop_down_circle_outlined),
                onTap: onSelectLoveLanguage,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<Gender>(
                initialValue: selectedGender,
                decoration: const InputDecoration(
                  labelText: 'Gender',
                  prefixIcon: Icon(Icons.wc_outlined),
                ),
                items: Gender.values.map((gender) {
                  return DropdownMenuItem(
                    value: gender,
                    child: Text(getGenderDisplayName(gender)),
                  );
                }).toList(),
                onChanged: onGenderChanged,
              ),
            ],
          ),
        ),
      ],
    );
  }
}