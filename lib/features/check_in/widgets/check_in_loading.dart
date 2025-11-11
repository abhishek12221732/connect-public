// lib/features/check_in/widgets/check_in_loading.dart

import 'package:flutter/material.dart';
// ✨ [ADD] Import for the custom loading indicator.
import 'package:feelings/widgets/pulsing_dots_indicator.dart';

class CheckInLoading extends StatelessWidget {
  const CheckInLoading({super.key});

  @override
  Widget build(BuildContext context) {
    // THEME: Get theme and colorScheme from context
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      // THEME: Use the theme's surface color for the background
      color: colorScheme.surface,
      alignment: Alignment.center,
      // ✨ [MODIFIED] Replaced the CircularProgressIndicator.
      child: PulsingDotsIndicator(
        size: 80,
        colors: [
          colorScheme.primary,
          colorScheme.primary,
          colorScheme.primary,
        ],
      ),
    );
  }
}