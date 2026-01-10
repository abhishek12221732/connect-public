// lib/features/profile/widgets/basic_info_section.dart

import 'package:flutter/material.dart';
import 'package:feelings/features/auth/models/user_model.dart';
import 'section_helpers.dart';

class BasicInfoSection extends StatelessWidget {
  final TextEditingController nameController; // ✨ [RESTORED]
  final FocusNode? nameFocusNode;
  final ValueChanged<String>? onNameSubmitted;
  final String? email; // ✨ [RESTORED]
  final String? currentMood; // ✨ [RESTORED]
  final String? selectedLoveLanguage; // ✨ [RESTORED]
  final Gender? selectedGender; // ✨ [RESTORED]
  final VoidCallback onSelectMood; // ✨ [RESTORED]
  final VoidCallback onSelectLoveLanguage; // ✨ [RESTORED]
  final VoidCallback onSelectGender; // ✨ [RESTORED]
  final String Function(Gender) getGenderDisplayName; // ✨ [RESTORED]

  const BasicInfoSection({
    super.key,
    required this.nameController,
    this.nameFocusNode, // ✨ [ADDED]
    this.onNameSubmitted, // ✨ [ADDED]
    this.email,
    this.currentMood,
    this.selectedLoveLanguage,
    this.selectedGender,
    required this.onSelectMood,
    required this.onSelectLoveLanguage,
    required this.onSelectGender,
    required this.getGenderDisplayName,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Prepare the gender text
    final String genderText = selectedGender != null 
        ? getGenderDisplayName(selectedGender!) 
        : '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        buildSectionTitle(context, 'Basic Information', icon: Icons.info_outline, color: theme.colorScheme.secondary),
        buildInfoCard(
          Column(
            children: [
              TextField(
                controller: nameController,
                focusNode: nameFocusNode, // ✨ [ADDED]
                onSubmitted: onNameSubmitted, // ✨ [ADDED]
                textInputAction: TextInputAction.done, // ✨ [ADDED]
                decoration: const InputDecoration(
                  labelText: 'Name',
                  prefixIcon: Icon(Icons.person_outline),
                ),
              ),
              const SizedBox(height: 16),
              
              // ✨ [ADDED] Email Field (Read Only)
              InputDecorator(
                decoration: InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email_outlined, color: theme.colorScheme.secondary),
                  filled: true,
                  fillColor: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: theme.colorScheme.outline.withOpacity(0.2)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                ),
                child: Text(
                  email ?? 'Loading...',
                  style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.7)),
                ),
              ),
              const SizedBox(height: 16),
              
              // --- MOOD SELECTOR ---
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
              const SizedBox(height: 16),

              // --- LOVE LANGUAGE SELECTOR ---
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

              // --- REVISED GENDER SELECTOR (Matches TextField style) ---
              TextField(
                controller: TextEditingController(text: genderText),
                readOnly: true, // Prevents keyboard from opening
                onTap: onSelectGender, // Triggers the modal
                decoration: const InputDecoration(
                  labelText: 'Gender',
                  prefixIcon: Icon(Icons.wc_outlined),
                  suffixIcon: Icon(Icons.arrow_drop_down),
                  border: OutlineInputBorder(), // Matches your app theme defaults
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}