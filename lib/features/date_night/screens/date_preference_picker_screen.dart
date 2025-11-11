// lib/features/date_night/screens/date_preference_picker_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:feelings/providers/user_provider.dart';
import 'package:feelings/providers/date_idea_provider.dart';
import 'package:feelings/features/date_night/screens/generated_date_idea_screen.dart';
import 'package:feelings/widgets/pulsing_dots_indicator.dart';

class OptionItem {
  final String value;
  final String label;
  final String? emoji;

  const OptionItem(this.value, this.label, {this.emoji});
}

class DatePreferencePickerScreen extends StatefulWidget {
  final String? preselectedLocation;
  final String? preselectedVibe;
  final String? preselectedBudget;
  final String? preselectedTime;

  const DatePreferencePickerScreen({
    super.key,
    this.preselectedLocation,
    this.preselectedVibe,
    this.preselectedBudget,
    this.preselectedTime,
  });

  @override
  State<DatePreferencePickerScreen> createState() => _DatePreferencePickerScreenState();
}

class _DatePreferencePickerScreenState extends State<DatePreferencePickerScreen> {
  bool _didPreselect = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_didPreselect) {
        final provider = Provider.of<DateIdeaProvider>(context, listen: false);
        if (widget.preselectedLocation != null) provider.toggleLocation(widget.preselectedLocation!);
        if (widget.preselectedVibe != null) provider.selectVibe(widget.preselectedVibe!);
        if (widget.preselectedBudget != null) provider.selectBudget(widget.preselectedBudget!);
        if (widget.preselectedTime != null) provider.selectTime(widget.preselectedTime!);
      }
      _didPreselect = true;
    });
  }

  List<OptionItem> get locationOptions => const [
        OptionItem('At Home', '🏡 At Home'),
        OptionItem('Outdoors', '🌳 Outdoors'),
        OptionItem('Out & About', '🏙️ Out & About'),
        OptionItem('Getaway', '✈️ Getaway'),
      ];

  List<OptionItem> get vibeOptions => const [
        OptionItem('Relaxing', '😌 Relaxing'),
        OptionItem('Adventurous', '✨ Adventurous'),
        OptionItem('Creative', '🎨 Creative'),
        OptionItem('Learning/Intellectual', '🧠 Learning/Intellectual'),
        OptionItem('Fun & Playful', '😂 Fun & Playful'),
        OptionItem('Romantic/Intimate', '🔥 Romantic/Intimate'),
      ];

  List<OptionItem> get budgetOptions => const [
        OptionItem('Free/Low Cost', '💲 Free/Low Cost'),
        OptionItem('Moderate', '💲💲 Moderate'),
        OptionItem('Splurge', '💲💲💲 Splurge'),
      ];

  List<OptionItem> get timeOptions => const [
        OptionItem('1-2 Hours', '⏰ 1-2 Hours'),
        OptionItem('2-4 Hours', '🕰️ 2-4 Hours'),
        OptionItem('Half Day+', '🗓️ Half Day+'),
      ];

  @override
  Widget build(BuildContext context) {
    // THEME: Get theme and colorScheme from context
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    final userProvider = Provider.of<UserProvider>(context);
    final userId = userProvider.getUserId() ?? '';
    final coupleId = userProvider.coupleId ?? '';

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      // THEME: AppBar is now styled by your global appBarTheme
      appBar: AppBar(
        title: const Text('Date Preferences'),
      ),
      body: Consumer<DateIdeaProvider>(
        builder: (context, provider, child) {
          if (userId.isEmpty || coupleId.isEmpty) {
            return Center( child: PulsingDotsIndicator(
                                  size: 30,
                                  colors: [
                                    colorScheme.onPrimary,
                                    colorScheme.onPrimary.withOpacity(0.8),
                                    colorScheme.onPrimary.withOpacity(0.6),
                                  ],
                                ));
          }
          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionTitle('Where do you want to go?'),
                      _buildChipSelection(
                        options: locationOptions,
                        selectedValues: provider.selectedLocations,
                        onSelected: (val) => provider.toggleLocation(val),
                        isSingleSelection: false,
                        // THEME: Pass a theme color to the chip selector
                        color: colorScheme.secondary,
                      ),
                      const SizedBox(height: 16),
                      _buildSectionTitle("What's the Vibe?"),
                      _buildChipSelection(
                        options: vibeOptions,
                        selectedValues: provider.selectedVibe != null ? [provider.selectedVibe!] : [],
                        onSelected: (val) => provider.selectVibe(val),
                        isSingleSelection: true,
                        color: colorScheme.primary,
                      ),
                      const SizedBox(height: 16),
                      _buildSectionTitle('Budget Level?'),
                      _buildChipSelection(
                        options: budgetOptions,
                        selectedValues: provider.selectedBudget != null ? [provider.selectedBudget!] : [],
                        onSelected: (val) => provider.selectBudget(val),
                        isSingleSelection: true,
                        color: colorScheme.tertiary, // Using another theme color for variety
                      ),
                      const SizedBox(height: 16),
                      _buildSectionTitle('Time Available?'),
                      _buildChipSelection(
                        options: timeOptions,
                        selectedValues: provider.selectedTime != null ? [provider.selectedTime!] : [],
                        onSelected: (val) => provider.selectTime(val),
                        isSingleSelection: true,
                        color: colorScheme.tertiary,
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: SafeArea(
                  child: ElevatedButton(
                    // THEME: Button is styled by the global elevatedButtonTheme
                    onPressed: provider.isLoading
                        ? null
                        : () async {
                            await provider.generateDateIdea(userId: userId, coupleId: coupleId, context: context);
                            if (provider.generatedIdea != null && context.mounted) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const GeneratedDateIdeaScreen(),
                                ),
                              );
                            } else if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('No ideas found with these preferences. Try broadening your search!'),
                                ),
                              );
                            }
                          },
                    // ✨ [MODIFIED] Replaced the custom heart animation with the PulsingDotsIndicator.
                    child: provider.isLoading
                        ? PulsingDotsIndicator(
                            size: 30,
                            colors: [
                              colorScheme.onPrimary,
                              colorScheme.onPrimary.withOpacity(0.8),
                              colorScheme.onPrimary.withOpacity(0.6),
                            ],
                          )
                        : const Text('Generate Idea'),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    // THEME: Uses theme's text styles
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, left: 4),
      child: Text(
        title,
        style: theme.textTheme.titleLarge,
      ),
    );
  }

  Widget _buildChipSelection({
    required List<OptionItem> options,
    required List<String> selectedValues,
    required Function(String) onSelected,
    bool isSingleSelection = false,
    required Color color,
  }) {
    // THEME: Uses theme's chip styles and colors
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Wrap(
      spacing: 4,
      runSpacing: 1,
      children: options.map((option) {
        final isSelected = selectedValues.contains(option.value);
        return ChoiceChip(
          key: ValueKey(option.value),
          label: Text(option.label),
          selected: isSelected,
          onSelected: (selected) {
            // Logic remains the same
            if (isSingleSelection) {
              if (isSelected) {
                onSelected(option.value);
              } else if (selected) {
                onSelected(option.value);
              }
            } else {
              onSelected(option.value);
            }
          },
          labelStyle: theme.chipTheme.labelStyle?.copyWith(
            color: isSelected ? colorScheme.onPrimary : colorScheme.onSurface,
          ),
          backgroundColor: colorScheme.surfaceContainerHighest,
          selectedColor: color, // Uses the theme color passed in
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(
              color: isSelected ? Colors.transparent : theme.dividerColor,
            ),
          ),
        );
      }).toList(),
    );
  }
}