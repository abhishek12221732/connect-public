import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// A class that holds all the text styles for the application.
class AppTextStyles {
  AppTextStyles._();

  /// The main text theme for the light theme.
  /// We are using Google Fonts' 'nunito' as the default font.
  static final TextTheme textTheme = TextTheme(
    displayLarge: GoogleFonts.nunito(
        fontSize: 57, fontWeight: FontWeight.w400, color: AppColors.textPrimary),
    displayMedium: GoogleFonts.nunito(
        fontSize: 45, fontWeight: FontWeight.w400, color: AppColors.textPrimary),
    displaySmall: GoogleFonts.nunito(
        fontSize: 36, fontWeight: FontWeight.w400, color: AppColors.textPrimary),
    headlineLarge: GoogleFonts.nunito(
        fontSize: 32, fontWeight: FontWeight.w400, color: AppColors.textPrimary),
    headlineMedium: GoogleFonts.nunito(
        fontSize: 28, fontWeight: FontWeight.w400, color: AppColors.textPrimary),
    headlineSmall: GoogleFonts.nunito(
        fontSize: 24, fontWeight: FontWeight.w400, color: AppColors.textPrimary),
    titleLarge: GoogleFonts.nunito(
        fontSize: 22, fontWeight: FontWeight.w500, color: AppColors.textPrimary),
    titleMedium: GoogleFonts.nunito(
        fontSize: 16, fontWeight: FontWeight.w500, letterSpacing: 0.15, color: AppColors.textPrimary),
    titleSmall: GoogleFonts.nunito(
        fontSize: 14, fontWeight: FontWeight.w500, letterSpacing: 0.1, color: AppColors.textPrimary),
    bodyLarge: GoogleFonts.nunito(
        fontSize: 16, fontWeight: FontWeight.w400, letterSpacing: 0.5, color: AppColors.textPrimary),
    bodyMedium: GoogleFonts.nunito(
        fontSize: 14, fontWeight: FontWeight.w400, letterSpacing: 0.25, color: AppColors.textPrimary),
    bodySmall: GoogleFonts.nunito(
        fontSize: 12, fontWeight: FontWeight.w400, letterSpacing: 0.4, color: AppColors.textSecondary),
    labelLarge: GoogleFonts.nunito(
        fontSize: 14, fontWeight: FontWeight.w500, letterSpacing: 1.25, color: AppColors.textPrimary),
    labelMedium: GoogleFonts.nunito(
        fontSize: 12, fontWeight: FontWeight.w400, letterSpacing: 1.5, color: AppColors.textSecondary),
    labelSmall: GoogleFonts.nunito(
        fontSize: 10, fontWeight: FontWeight.w400, letterSpacing: 1.5, color: AppColors.textSecondary),
  );

  /// The text theme for the dark theme.
  static final TextTheme darkTextTheme = TextTheme(
    displayLarge: GoogleFonts.nunito(
        fontSize: 57, fontWeight: FontWeight.w400, color: AppColors.darkTextPrimary),
    displayMedium: GoogleFonts.nunito(
        fontSize: 45, fontWeight: FontWeight.w400, color: AppColors.darkTextPrimary),
    displaySmall: GoogleFonts.nunito(
        fontSize: 36, fontWeight: FontWeight.w400, color: AppColors.darkTextPrimary),
    headlineLarge: GoogleFonts.nunito(
        fontSize: 32, fontWeight: FontWeight.w400, color: AppColors.darkTextPrimary),
    headlineMedium: GoogleFonts.nunito(
        fontSize: 28, fontWeight: FontWeight.w400, color: AppColors.darkTextPrimary),
    headlineSmall: GoogleFonts.nunito(
        fontSize: 24, fontWeight: FontWeight.w400, color: AppColors.darkTextPrimary),
    titleLarge: GoogleFonts.nunito(
        fontSize: 22, fontWeight: FontWeight.w500, color: AppColors.darkTextPrimary),
    titleMedium: GoogleFonts.nunito(
        fontSize: 16, fontWeight: FontWeight.w500, letterSpacing: 0.15, color: AppColors.darkTextPrimary),
    titleSmall: GoogleFonts.nunito(
        fontSize: 14, fontWeight: FontWeight.w500, letterSpacing: 0.1, color: AppColors.darkTextPrimary),
    bodyLarge: GoogleFonts.nunito(
        fontSize: 16, fontWeight: FontWeight.w400, letterSpacing: 0.5, color: AppColors.darkTextPrimary),
    bodyMedium: GoogleFonts.nunito(
        fontSize: 14, fontWeight: FontWeight.w400, letterSpacing: 0.25, color: AppColors.darkTextPrimary),
    bodySmall: GoogleFonts.nunito(
        fontSize: 12, fontWeight: FontWeight.w400, letterSpacing: 0.4, color: AppColors.darkTextSecondary),
    labelLarge: GoogleFonts.nunito(
        fontSize: 14, fontWeight: FontWeight.w500, letterSpacing: 1.25, color: AppColors.darkTextPrimary),
    labelMedium: GoogleFonts.nunito(
        fontSize: 12, fontWeight: FontWeight.w400, letterSpacing: 1.5, color: AppColors.darkTextSecondary),
    labelSmall: GoogleFonts.nunito(
        fontSize: 10, fontWeight: FontWeight.w400, letterSpacing: 1.5, color: AppColors.darkTextSecondary),
  );

  // You can also define specific text styles here if needed.
  static final TextStyle headline6 = textTheme.headlineSmall!;
  static final TextStyle darkHeadline6 = darkTextTheme.headlineSmall!;
}