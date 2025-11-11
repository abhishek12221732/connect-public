import 'package:flutter/material.dart';
import 'app_colors.dart';

/// A class that holds the card theme for the application.
class AppCardTheme {
  AppCardTheme._();

  /// The card theme for the light theme.
  static final CardThemeData cardTheme = CardThemeData(
    elevation: 2.0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16.0),
    ),
    color: AppColors.surface,
    shadowColor: Colors.black.withOpacity(0.1),
    margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
  );

  /// The card theme for the dark theme.
  static final CardThemeData darkCardTheme = CardThemeData(
    elevation: 4.0, // A bit more elevation for contrast
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16.0),
    ),
    color: AppColors.darkSurface,
    shadowColor: Colors.black.withOpacity(0.5),
    margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
  );

  // --- Theme-specific Card Themes ---
  static final CardThemeData oceanicCardTheme = cardTheme.copyWith(
    color: AppColors.oceanicSurface,
    shadowColor: Colors.black.withOpacity(0.1),
  );

  static final CardThemeData sunsetCardTheme = darkCardTheme.copyWith(
    color: AppColors.sunsetSurface,
  );

  static final CardThemeData pastelCardTheme = cardTheme.copyWith(
    color: AppColors.pastelSurface,
  );

  static final CardThemeData nebulaCardTheme = darkCardTheme.copyWith(
    color: AppColors.nebulaSurface,
  );
  
  // ✨ --- NEW THEMES START HERE ---
  static final CardThemeData amethystCardTheme = darkCardTheme.copyWith(
    color: AppColors.amethystSurface,
  );
  
  static final CardThemeData mintCardTheme = cardTheme.copyWith(
    color: AppColors.mintSurface,
  );

  static final CardThemeData oceanDarkCardTheme = darkCardTheme.copyWith(
    color: AppColors.oceanDarkSurface,
  );
}