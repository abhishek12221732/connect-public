import 'package:flutter/material.dart';

class ConnectWithPartnerCard extends StatelessWidget {
  final String title;
  final String message;
  final IconData icon;
  final String? buttonLabel;
  final VoidCallback? onButtonPressed;

  const ConnectWithPartnerCard({
    super.key,
    required this.title,
    required this.message,
    required this.icon,
    this.buttonLabel,
    this.onButtonPressed,
  });

  @override
  Widget build(BuildContext context) {
    // THEME: Get theme and colorScheme from context
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // THEME: Replaced the main Container with a Card for better theme consistency.
    // It will automatically use the shape, elevation, shadowColor, and color from your global cardTheme.
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon with a theme-aware background
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                // THEME: Use a theme-aware color
                color: colorScheme.primary.withOpacity(0.06),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                size: 24,
                // THEME: Use theme's primary color
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: 16),
            
            // Title text
            Text(
              title,
              textAlign: TextAlign.center,
              // THEME: Use text style from the theme
              style: theme.textTheme.titleMedium?.copyWith(
                height: 1.3,
              ),
            ),
            const SizedBox(height: 8),
            
            // Message text
            Text(
              message,
              textAlign: TextAlign.center,
              // THEME: Use text style and a subtle, theme-aware color
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface.withOpacity(0.7),
                height: 1.4,
              ),
            ),
            
            // Button
            if (buttonLabel != null && onButtonPressed != null) ...[
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                // THEME: This button is now styled by your global elevatedButtonTheme
                child: ElevatedButton(
                  onPressed: onButtonPressed,
                  child: Text(buttonLabel!),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}