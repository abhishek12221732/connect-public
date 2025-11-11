// lib/features/profile/widgets/app_settings_section.dart

import 'package:flutter/material.dart';
import 'package:feelings/theme/app_theme.dart';
import 'section_helpers.dart';

class AppSettingsSection extends StatelessWidget {
  final bool notificationsEnabled;
  final AppThemeType selectedTheme;
  final ValueChanged<bool> onNotificationsChanged;
  final ValueChanged<AppThemeType?> onThemeChanged;
  // ✨ 1. ADD THE NEW PROPERTY
  final String Function(AppThemeType) themeNameFormatter;

  const AppSettingsSection({
    super.key,
    required this.notificationsEnabled,
    required this.selectedTheme,
    required this.onNotificationsChanged,
    required this.onThemeChanged,
    // ✨ 2. ADD IT TO THE CONSTRUCTOR
    required this.themeNameFormatter,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        buildSectionTitle(context, 'App Settings', icon: Icons.settings),
        buildInfoCard(
          Column(
            children: [
              SwitchListTile(
                title: const Text('Push Notifications'),
                subtitle: const Text('Receive relationship updates'),
                value: notificationsEnabled,
                onChanged: onNotificationsChanged,
                activeThumbColor: theme.colorScheme.primary,
                contentPadding: const EdgeInsets.symmetric(horizontal: 4),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: DropdownButtonFormField<AppThemeType>(
                  value: selectedTheme, // Use value instead of initialValue
                  decoration: const InputDecoration(
                    labelText: 'App Theme',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                  ),
                  items: AppThemeType.values.map((AppThemeType themeType) {
                    final ThemeData themeData = AppTheme.themes[themeType]!;
                    final Color primaryColor = themeData.colorScheme.primary;
                    
                    // ✨ 3. USE THE FORMATTER FUNCTION
                    String themeName = themeNameFormatter(themeType);

                    return DropdownMenuItem<AppThemeType>(
                      value: themeType,
                      child: Row(
                        children: [
                          Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              color: primaryColor,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: theme.colorScheme.onSurface.withOpacity(0.4),
                                width: 1.5,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(themeName),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: onThemeChanged,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}