import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_text_styles.dart';

class AppButtonTheme {
  AppButtonTheme._();

  // --- Base Light Theme Button Themes ---
  static final ElevatedButtonThemeData elevatedButtonTheme = ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: AppColors.primary,
      foregroundColor: AppColors.onPrimary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30.0)),
      padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 24.0),
      textStyle: AppTextStyles.textTheme.labelLarge,
      elevation: 4,
      shadowColor: AppColors.primary.withOpacity(0.4),
    ),
  );

  static final OutlinedButtonThemeData outlinedButtonTheme = OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: AppColors.primary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30.0)),
      side: const BorderSide(color: AppColors.primary, width: 1.5),
      padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 24.0),
      textStyle: AppTextStyles.textTheme.labelLarge,
    ),
  );

  static final TextButtonThemeData textButtonTheme = TextButtonThemeData(
    style: TextButton.styleFrom(
      foregroundColor: AppColors.primary,
      textStyle: AppTextStyles.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold),
    ),
  );

  // --- Base Dark Theme Button Themes ---
  static final ElevatedButtonThemeData darkElevatedButtonTheme = ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: AppColors.darkPrimary,
      foregroundColor: AppColors.onDarkPrimary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30.0)),
      padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 24.0),
      textStyle: AppTextStyles.darkTextTheme.labelLarge,
      elevation: 4,
      shadowColor: AppColors.darkPrimary.withOpacity(0.4),
    ),
  );

  static final OutlinedButtonThemeData darkOutlinedButtonTheme = OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: AppColors.darkPrimary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30.0)),
      side: const BorderSide(color: AppColors.darkPrimary, width: 1.5),
      padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 24.0),
      textStyle: AppTextStyles.darkTextTheme.labelLarge,
    ),
  );

  static final TextButtonThemeData darkTextButtonTheme = TextButtonThemeData(
    style: TextButton.styleFrom(
      foregroundColor: AppColors.darkPrimary,
      textStyle: AppTextStyles.darkTextTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold),
    ),
  );

  // ✨ --- THEME GENERATORS ---

  static TextButtonThemeData _createTextButtonTheme(Color color) =>
      TextButtonThemeData(style: textButtonTheme.style?.copyWith(foregroundColor: WidgetStateProperty.all(color)));
  static OutlinedButtonThemeData _createOutlinedButtonTheme(Color color) =>
      OutlinedButtonThemeData(style: outlinedButtonTheme.style?.copyWith(foregroundColor: WidgetStateProperty.all(color), side: WidgetStateProperty.all(BorderSide(color: color, width: 1.5))));
  static ElevatedButtonThemeData _createElevatedButtonTheme(Color bgColor, Color fgColor, bool isLight) =>
      ElevatedButtonThemeData(style: (isLight ? elevatedButtonTheme.style : darkElevatedButtonTheme.style)?.copyWith(backgroundColor: WidgetStateProperty.all(bgColor), foregroundColor: WidgetStateProperty.all(fgColor), shadowColor: WidgetStateProperty.all(bgColor.withOpacity(0.4))));

  // --- EXISTING THEMES ---

  // Oceanic
  static final oceanicElevatedButtonTheme = _createElevatedButtonTheme(AppColors.oceanicPrimary, AppColors.oceaniconPrimary, true);
  static final oceanicOutlinedButtonTheme = _createOutlinedButtonTheme(AppColors.oceanicPrimary);
  static final oceanicTextButtonTheme = _createTextButtonTheme(AppColors.oceanicPrimary);

  // Sunset
  static final sunsetElevatedButtonTheme = _createElevatedButtonTheme(AppColors.sunsetPrimary, AppColors.sunsetonPrimary, false);
  static final sunsetOutlinedButtonTheme = _createOutlinedButtonTheme(AppColors.sunsetPrimary);
  static final sunsetTextButtonTheme = _createTextButtonTheme(AppColors.sunsetPrimary);

  // Pastel
  static final pastelElevatedButtonTheme = _createElevatedButtonTheme(AppColors.pastelPrimary, AppColors.pastelonPrimary, true);
  static final pastelOutlinedButtonTheme = _createOutlinedButtonTheme(AppColors.pastelPrimary);
  static final pastelTextButtonTheme = _createTextButtonTheme(AppColors.pastelPrimary);

  // Nebula
  static final nebulaElevatedButtonTheme = _createElevatedButtonTheme(AppColors.nebulaPrimary, AppColors.nebulaonPrimary, false);
  static final nebulaOutlinedButtonTheme = _createOutlinedButtonTheme(AppColors.nebulaPrimary);
  static final nebulaTextButtonTheme = _createTextButtonTheme(AppColors.nebulaPrimary);

  // ✨ --- NEW THEMES START HERE ---

  // Royal Amethyst
  static final amethystElevatedButtonTheme = _createElevatedButtonTheme(AppColors.amethystPrimary, AppColors.amethysOnPrimary, false);
  static final amethystOutlinedButtonTheme = _createOutlinedButtonTheme(AppColors.amethystPrimary);
  static final amethystTextButtonTheme = _createTextButtonTheme(AppColors.amethystPrimary);

  // Serene Mint
  static final mintElevatedButtonTheme = _createElevatedButtonTheme(AppColors.mintPrimary, AppColors.mintOnPrimary, true);
  static final mintOutlinedButtonTheme = _createOutlinedButtonTheme(AppColors.mintPrimary);
  static final mintTextButtonTheme = _createTextButtonTheme(AppColors.mintPrimary);

  // Midnight Ocean
  static final oceanDarkElevatedButtonTheme = _createElevatedButtonTheme(AppColors.oceanDarkPrimary, AppColors.oceanDarkOnPrimary, false);
  static final oceanDarkOutlinedButtonTheme = _createOutlinedButtonTheme(AppColors.oceanDarkPrimary);
  static final oceanDarkTextButtonTheme = _createTextButtonTheme(AppColors.oceanDarkPrimary);

  // ✨ --- NEW: Midnight (OLED) Buttons ---
  static final midnightElevatedButtonTheme = _createElevatedButtonTheme(AppColors.midnightPrimary, AppColors.midnightOnPrimary, false);
  static final midnightOutlinedButtonTheme = _createOutlinedButtonTheme(AppColors.midnightPrimary);
  static final midnightTextButtonTheme = _createTextButtonTheme(AppColors.midnightPrimary);

  // ✨ --- NEW: Eclipse (Luxury) Buttons ---
  static final eclipseElevatedButtonTheme = _createElevatedButtonTheme(AppColors.eclipsePrimary, AppColors.eclipseOnPrimary, false);
  static final eclipseOutlinedButtonTheme = _createOutlinedButtonTheme(AppColors.eclipsePrimary);
  static final eclipseTextButtonTheme = _createTextButtonTheme(AppColors.eclipsePrimary);

  // ✨ --- NEW: Aurora (Nature) Buttons ---
  static final auroraElevatedButtonTheme = _createElevatedButtonTheme(AppColors.auroraPrimary, AppColors.auroraOnPrimary, false);
  static final auroraOutlinedButtonTheme = _createOutlinedButtonTheme(AppColors.auroraPrimary);
  static final auroraTextButtonTheme = _createTextButtonTheme(AppColors.auroraPrimary);
}