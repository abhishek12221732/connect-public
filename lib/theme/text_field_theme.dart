import 'package:flutter/material.dart';
import 'app_colors.dart';

/// A class that holds the input decoration theme for the application.
class AppTextFieldTheme {
  AppTextFieldTheme._();

  /// The input decoration theme for text fields in light mode.
  static final InputDecorationTheme inputDecorationTheme = InputDecorationTheme(
    contentPadding: const EdgeInsets.symmetric(vertical: 18.0, horizontal: 20.0),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(15.0),
      borderSide: const BorderSide(color: AppColors.border, width: 1.0),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(15.0),
      borderSide: const BorderSide(color: AppColors.border, width: 1.0),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(15.0),
      borderSide: const BorderSide(color: AppColors.primary, width: 2.0),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(15.0),
      borderSide: const BorderSide(color: AppColors.error, width: 1.0),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(15.0),
      borderSide: const BorderSide(color: AppColors.error, width: 2.0),
    ),
    labelStyle: const TextStyle(color: AppColors.textSecondary),
    hintStyle: const TextStyle(color: AppColors.textSecondary),
    filled: true,
    fillColor: AppColors.surface,
  );

  /// The input decoration theme for text fields in dark mode.
  static final InputDecorationTheme darkInputDecorationTheme = InputDecorationTheme(
    contentPadding: const EdgeInsets.symmetric(vertical: 18.0, horizontal: 20.0),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(15.0),
      borderSide: BorderSide(color: AppColors.darkSurface.withOpacity(0.8), width: 1.0),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(15.0),
      borderSide: BorderSide(color: AppColors.darkSurface.withOpacity(0.8), width: 1.0),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(15.0),
      borderSide: const BorderSide(color: AppColors.darkPrimary, width: 2.0),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(15.0),
      borderSide: const BorderSide(color: AppColors.darkError, width: 1.0),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(15.0),
      borderSide: const BorderSide(color: AppColors.darkError, width: 2.0),
    ),
    labelStyle: const TextStyle(color: AppColors.darkTextSecondary),
    hintStyle: const TextStyle(color: AppColors.darkTextSecondary),
    filled: true,
    fillColor: AppColors.darkSurface,
  );

  // --- Theme-specific Input Decoration Themes ---
  static final InputDecorationTheme oceanicInputDecorationTheme = inputDecorationTheme.copyWith(
    fillColor: AppColors.oceanicSurface,
    focusedBorder: inputDecorationTheme.focusedBorder?.copyWith(
      borderSide: const BorderSide(color: AppColors.oceanicPrimary, width: 2.0),
    ),
  );

  static final InputDecorationTheme sunsetInputDecorationTheme = darkInputDecorationTheme.copyWith(
    fillColor: AppColors.sunsetSurface,
    focusedBorder: darkInputDecorationTheme.focusedBorder?.copyWith(
      borderSide: const BorderSide(color: AppColors.sunsetPrimary, width: 2.0),
    ),
  );
  
  static final InputDecorationTheme pastelInputDecorationTheme = inputDecorationTheme.copyWith(
    fillColor: AppColors.pastelSurface,
    focusedBorder: inputDecorationTheme.focusedBorder?.copyWith(
      borderSide: const BorderSide(color: AppColors.pastelPrimary, width: 2.0),
    ),
  );

  static final InputDecorationTheme nebulaInputDecorationTheme = darkInputDecorationTheme.copyWith(
    fillColor: AppColors.nebulaSurface,
    focusedBorder: darkInputDecorationTheme.focusedBorder?.copyWith(
      borderSide: const BorderSide(color: AppColors.nebulaPrimary, width: 2.0),
    ),
  );
  
  // ✨ --- NEW THEMES START HERE ---
  static final InputDecorationTheme amethystInputDecorationTheme = darkInputDecorationTheme.copyWith(
    fillColor: AppColors.amethystSurface,
    focusedBorder: darkInputDecorationTheme.focusedBorder?.copyWith(
      borderSide: const BorderSide(color: AppColors.amethystPrimary, width: 2.0),
    ),
  );

  static final InputDecorationTheme mintInputDecorationTheme = inputDecorationTheme.copyWith(
    fillColor: AppColors.mintSurface,
    focusedBorder: inputDecorationTheme.focusedBorder?.copyWith(
      borderSide: const BorderSide(color: AppColors.mintPrimary, width: 2.0),
    ),
  );

  static final InputDecorationTheme oceanDarkInputDecorationTheme = darkInputDecorationTheme.copyWith(
    fillColor: AppColors.oceanDarkSurface,
    focusedBorder: darkInputDecorationTheme.focusedBorder?.copyWith(
      borderSide: const BorderSide(color: AppColors.oceanDarkPrimary, width: 2.0),
    ),
  );

  // ✨ --- NEW THEMES ---
  static final InputDecorationTheme midnightInputDecorationTheme = darkInputDecorationTheme.copyWith(
    fillColor: AppColors.midnightSurface,
    focusedBorder: darkInputDecorationTheme.focusedBorder?.copyWith(
      borderSide: const BorderSide(color: AppColors.midnightPrimary, width: 2.0),
    ),
  );

  static final InputDecorationTheme eclipseInputDecorationTheme = darkInputDecorationTheme.copyWith(
    fillColor: AppColors.eclipseSurface,
    focusedBorder: darkInputDecorationTheme.focusedBorder?.copyWith(
      borderSide: const BorderSide(color: AppColors.eclipsePrimary, width: 2.0),
    ),
  );

  static final InputDecorationTheme auroraInputDecorationTheme = darkInputDecorationTheme.copyWith(
    fillColor: AppColors.auroraSurface,
    focusedBorder: darkInputDecorationTheme.focusedBorder?.copyWith(
      borderSide: const BorderSide(color: AppColors.auroraPrimary, width: 2.0),
    ),
  );
}