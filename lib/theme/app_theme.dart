import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'mood_theme.dart';
import 'app_text_styles.dart';
import 'button_theme.dart';
import 'text_field_theme.dart';
import 'card_theme.dart';

enum AppThemeType {
  defaultLight,
  sunset,
  midnight,
  eclipse,
  aurora,
  amethyst,
  oceanic,
  pastel,
  mint,
  oceanDark,
}

/// A class that holds the theme data for the application.
class AppTheme {
  AppTheme._();

  // --- Base Light Theme ---
  static final ThemeData defaultTheme = ThemeData(
    brightness: Brightness.light,
    primaryColor: AppColors.primary,
    scaffoldBackgroundColor: AppColors.background,
    colorScheme: const ColorScheme.light(
      primary: AppColors.primary,
      secondary: AppColors.secondary,
      surface: AppColors.surface,
      error: AppColors.error,
      onPrimary: AppColors.onPrimary,
      onSecondary: AppColors.onSecondary,
      onSurface: AppColors.onSurface,
      onError: AppColors.onError,
    ),
    textTheme: AppTextStyles.textTheme,
    elevatedButtonTheme: AppButtonTheme.elevatedButtonTheme,
    outlinedButtonTheme: AppButtonTheme.outlinedButtonTheme,
    textButtonTheme: AppButtonTheme.textButtonTheme,
    inputDecorationTheme: AppTextFieldTheme.inputDecorationTheme,
    cardTheme: AppCardTheme.cardTheme,
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.background,
      elevation: 0,
      iconTheme: const IconThemeData(color: AppColors.textPrimary),
      titleTextStyle: AppTextStyles.headline6,
    ),
    extensions: const [MoodTheme.light],
    useMaterial3: true,
  );

  // --- Base Dark Theme (Used as a template for other dark themes) ---
  static final ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    primaryColor: AppColors.darkPrimary,
    scaffoldBackgroundColor: AppColors.darkBackground,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.darkPrimary,
      secondary: AppColors.darkSecondary,
      surface: AppColors.darkSurface,
      error: AppColors.darkError,
      onPrimary: AppColors.onDarkPrimary,
      onSecondary: AppColors.onDarkSecondary,
      onSurface: AppColors.onDarkSurface,
      onError: AppColors.onDarkError,
    ),
    textTheme: AppTextStyles.darkTextTheme,
    elevatedButtonTheme: AppButtonTheme.darkElevatedButtonTheme,
    outlinedButtonTheme: AppButtonTheme.darkOutlinedButtonTheme,
    textButtonTheme: AppButtonTheme.darkTextButtonTheme,
    inputDecorationTheme: AppTextFieldTheme.darkInputDecorationTheme,
    cardTheme: AppCardTheme.darkCardTheme,
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.darkBackground,
      elevation: 0,
      iconTheme: const IconThemeData(color: AppColors.darkTextPrimary),
      titleTextStyle: AppTextStyles.darkHeadline6,
    ),
    extensions: const [MoodTheme.dark],
    useMaterial3: true,
  );

  // --- Theme Factory ---
  static ThemeData _createTheme({
    required ThemeData baseTheme,
    required Color primary,
    required Color secondary,
    required Color background,
    required Color surface,
    required Color onPrimary,
    required Color onSurface,
    required TextTheme baseTextTheme,
    required TextStyle baseHeadline6,
    required ElevatedButtonThemeData elevatedButtonTheme,
    required OutlinedButtonThemeData outlinedButtonTheme,
    required TextButtonThemeData textButtonTheme,
    required CardThemeData cardTheme,
    required InputDecorationTheme inputDecorationTheme,
    required MoodTheme moodTheme,
  }) {
    return baseTheme.copyWith(
      primaryColor: primary,
      scaffoldBackgroundColor: background,
      extensions: [moodTheme],
      colorScheme: baseTheme.colorScheme.copyWith(
        primary: primary,
        secondary: secondary,
        surface: surface,
        onPrimary: onPrimary,
        onSurface: onSurface,
      ),
      textTheme: baseTextTheme.apply(
        bodyColor: onSurface,
        displayColor: onSurface,
      ),
      elevatedButtonTheme: elevatedButtonTheme,
      outlinedButtonTheme: outlinedButtonTheme,
      textButtonTheme: textButtonTheme,
      cardTheme: cardTheme,
      inputDecorationTheme: inputDecorationTheme,
      appBarTheme: baseTheme.appBarTheme.copyWith(
        backgroundColor: background,
        iconTheme: IconThemeData(color: onSurface),
        titleTextStyle: baseHeadline6.copyWith(color: onSurface),
      ),
      floatingActionButtonTheme: baseTheme.floatingActionButtonTheme.copyWith(
        backgroundColor: primary,
        foregroundColor: onPrimary,
      ),
    );
  }

  // --- Theme Definitions ---

  static final sunsetTheme = _createTheme(
    baseTheme: darkTheme,
    primary: AppColors.sunsetPrimary,
    secondary: AppColors.sunsetSecondary,
    background: AppColors.sunsetBackground,
    surface: AppColors.sunsetSurface,
    onPrimary: AppColors.sunsetonPrimary,
    onSurface: AppColors.sunsetTextPrimary,
    baseTextTheme: AppTextStyles.darkTextTheme,
    baseHeadline6: AppTextStyles.darkHeadline6,
    elevatedButtonTheme: AppButtonTheme.sunsetElevatedButtonTheme,
    outlinedButtonTheme: AppButtonTheme.sunsetOutlinedButtonTheme,
    textButtonTheme: AppButtonTheme.sunsetTextButtonTheme,
    cardTheme: AppCardTheme.sunsetCardTheme,
    inputDecorationTheme: AppTextFieldTheme.sunsetInputDecorationTheme,
    moodTheme: MoodTheme.sunset,
  );

  static final oceanicTheme = _createTheme(
    baseTheme: defaultTheme,
    primary: AppColors.oceanicPrimary,
    secondary: AppColors.oceanicSecondary,
    background: AppColors.oceanicBackground,
    surface: AppColors.oceanicSurface,
    onPrimary: AppColors.oceaniconPrimary,
    onSurface: AppColors.oceanicTextPrimary,
    baseTextTheme: AppTextStyles.textTheme,
    baseHeadline6: AppTextStyles.headline6,
    elevatedButtonTheme: AppButtonTheme.oceanicElevatedButtonTheme,
    outlinedButtonTheme: AppButtonTheme.oceanicOutlinedButtonTheme,
    textButtonTheme: AppButtonTheme.oceanicTextButtonTheme,
    cardTheme: AppCardTheme.oceanicCardTheme,
    inputDecorationTheme: AppTextFieldTheme.oceanicInputDecorationTheme,
    moodTheme: MoodTheme.oceanic,
  );
  
  static final pastelTheme = _createTheme(
    baseTheme: defaultTheme,
    primary: AppColors.pastelPrimary,
    secondary: AppColors.pastelSecondary,
    background: AppColors.pastelBackground,
    surface: AppColors.pastelSurface,
    onPrimary: AppColors.pastelonPrimary,
    onSurface: AppColors.pastelTextPrimary,
    baseTextTheme: AppTextStyles.textTheme,
    baseHeadline6: AppTextStyles.headline6,
    elevatedButtonTheme: AppButtonTheme.pastelElevatedButtonTheme,
    outlinedButtonTheme: AppButtonTheme.pastelOutlinedButtonTheme,
    textButtonTheme: AppButtonTheme.pastelTextButtonTheme,
    cardTheme: AppCardTheme.pastelCardTheme,
    inputDecorationTheme: AppTextFieldTheme.pastelInputDecorationTheme,
    moodTheme: MoodTheme.pastel,
  );
  
  static final amethystTheme = _createTheme(
    baseTheme: darkTheme,
    primary: AppColors.amethystPrimary,
    secondary: AppColors.amethystSecondary,
    background: AppColors.amethystBackground,
    surface: AppColors.amethystSurface,
    onPrimary: AppColors.amethysOnPrimary,
    onSurface: AppColors.amethysTextPrimary,
    baseTextTheme: AppTextStyles.darkTextTheme,
    baseHeadline6: AppTextStyles.darkHeadline6,
    elevatedButtonTheme: AppButtonTheme.amethystElevatedButtonTheme,
    outlinedButtonTheme: AppButtonTheme.amethystOutlinedButtonTheme,
    textButtonTheme: AppButtonTheme.amethystTextButtonTheme,
    cardTheme: AppCardTheme.amethystCardTheme,
    inputDecorationTheme: AppTextFieldTheme.amethystInputDecorationTheme,
    moodTheme: MoodTheme.amethyst,
  );

  static final mintTheme = _createTheme(
    baseTheme: defaultTheme,
    primary: AppColors.mintPrimary,
    secondary: AppColors.mintSecondary,
    background: AppColors.mintBackground,
    surface: AppColors.mintSurface,
    onPrimary: AppColors.mintOnPrimary,
    onSurface: AppColors.mintTextPrimary,
    baseTextTheme: AppTextStyles.textTheme,
    baseHeadline6: AppTextStyles.headline6,
    elevatedButtonTheme: AppButtonTheme.mintElevatedButtonTheme,
    outlinedButtonTheme: AppButtonTheme.mintOutlinedButtonTheme,
    textButtonTheme: AppButtonTheme.mintTextButtonTheme,
    cardTheme: AppCardTheme.mintCardTheme,
    inputDecorationTheme: AppTextFieldTheme.mintInputDecorationTheme,
    moodTheme: MoodTheme.mint,
  );

  static final oceanDarkTheme = _createTheme(
    baseTheme: darkTheme,
    primary: AppColors.oceanDarkPrimary,
    secondary: AppColors.oceanDarkSecondary,
    background: AppColors.oceanDarkBackground,
    surface: AppColors.oceanDarkSurface,
    onPrimary: AppColors.oceanDarkOnPrimary,
    onSurface: AppColors.oceanDarkTextPrimary,
    baseTextTheme: AppTextStyles.darkTextTheme,
    baseHeadline6: AppTextStyles.darkHeadline6,
    elevatedButtonTheme: AppButtonTheme.oceanDarkElevatedButtonTheme,
    outlinedButtonTheme: AppButtonTheme.oceanDarkOutlinedButtonTheme,
    textButtonTheme: AppButtonTheme.oceanDarkTextButtonTheme,
    cardTheme: AppCardTheme.oceanDarkCardTheme,
    inputDecorationTheme: AppTextFieldTheme.oceanDarkInputDecorationTheme,
    moodTheme: MoodTheme.oceanDark,
  );

  // ✨ --- NEW: Midnight (OLED) Theme ---
  static final midnightTheme = _createTheme(
    baseTheme: darkTheme,
    primary: AppColors.midnightPrimary,
    secondary: AppColors.midnightSecondary,
    background: AppColors.midnightBackground,
    surface: AppColors.midnightSurface,
    onPrimary: AppColors.midnightOnPrimary,
    onSurface: AppColors.midnightTextPrimary,
    baseTextTheme: AppTextStyles.darkTextTheme,
    baseHeadline6: AppTextStyles.darkHeadline6,
    elevatedButtonTheme: AppButtonTheme.midnightElevatedButtonTheme,
    outlinedButtonTheme: AppButtonTheme.midnightOutlinedButtonTheme,
    textButtonTheme: AppButtonTheme.midnightTextButtonTheme,
    cardTheme: AppCardTheme.midnightCardTheme,
    inputDecorationTheme: AppTextFieldTheme.midnightInputDecorationTheme,
    moodTheme: MoodTheme.midnight,
  );

  // ✨ --- NEW: Eclipse (Luxury) Theme ---
  static final eclipseTheme = _createTheme(
    baseTheme: darkTheme,
    primary: AppColors.eclipsePrimary,
    secondary: AppColors.eclipseSecondary,
    background: AppColors.eclipseBackground,
    surface: AppColors.eclipseSurface,
    onPrimary: AppColors.eclipseOnPrimary,
    onSurface: AppColors.eclipseTextPrimary,
    baseTextTheme: AppTextStyles.darkTextTheme,
    baseHeadline6: AppTextStyles.darkHeadline6,
    elevatedButtonTheme: AppButtonTheme.eclipseElevatedButtonTheme,
    outlinedButtonTheme: AppButtonTheme.eclipseOutlinedButtonTheme,
    textButtonTheme: AppButtonTheme.eclipseTextButtonTheme,
    cardTheme: AppCardTheme.eclipseCardTheme,
    inputDecorationTheme: AppTextFieldTheme.eclipseInputDecorationTheme,
    moodTheme: MoodTheme.eclipse,
  );

  // ✨ --- NEW: Aurora (Nature) Theme ---
  static final auroraTheme = _createTheme(
    baseTheme: darkTheme,
    primary: AppColors.auroraPrimary,
    secondary: AppColors.auroraSecondary,
    background: AppColors.auroraBackground,
    surface: AppColors.auroraSurface,
    onPrimary: AppColors.auroraOnPrimary,
    onSurface: AppColors.auroraTextPrimary,
    baseTextTheme: AppTextStyles.darkTextTheme,
    baseHeadline6: AppTextStyles.darkHeadline6,
    elevatedButtonTheme: AppButtonTheme.auroraElevatedButtonTheme,
    outlinedButtonTheme: AppButtonTheme.auroraOutlinedButtonTheme,
    textButtonTheme: AppButtonTheme.auroraTextButtonTheme,
    cardTheme: AppCardTheme.auroraCardTheme,
    inputDecorationTheme: AppTextFieldTheme.auroraInputDecorationTheme,
    moodTheme: MoodTheme.aurora,
  );

  // The final map of all available themes
  static final Map<AppThemeType, ThemeData> themes = {
    AppThemeType.defaultLight: defaultTheme,
    AppThemeType.sunset: sunsetTheme,
    AppThemeType.midnight: midnightTheme,
    AppThemeType.eclipse: eclipseTheme,
    AppThemeType.aurora: auroraTheme,
    AppThemeType.amethyst: amethystTheme,
    AppThemeType.oceanic: oceanicTheme,
    AppThemeType.pastel: pastelTheme,
    AppThemeType.mint: mintTheme,
    AppThemeType.oceanDark: oceanDarkTheme,
  };
}