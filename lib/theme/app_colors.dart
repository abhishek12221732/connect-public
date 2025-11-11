import 'package:flutter/material.dart';

/// A class that holds all the colors for the application.
class AppColors {
  AppColors._(); // This class is not meant to be instantiated.

  // --- Brand Colors (Light Theme) ---
  static const Color primary = Color(0xFFFF6B6B); // Vibrant coral
  static const Color secondary = Color(0xFFFFD166); // Warm peach/apricot
  static const Color accent = Color(0xFF4ECDC4); // Complementary teal

  // --- Light Theme Colors ---
  static const Color background = Color(0xFFFFF8F0); // Very light cream
  static const Color surface = Color(0xFFFFFFFF); // White for cards, dialogs, etc.
  static const Color error = Color(0xFFD32F2F);

  // --- Text Colors (Light Theme) ---
  static const Color textPrimary = Color(0xFF333333); // Dark grey
  static const Color textSecondary = Color(0xFF757575); // Lighter grey
  static const Color textonPrimary = Color(0xFFFFFFFF); // On primary backgrounds

  // --- On-Color Tints (Light Theme) ---
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color onSecondary = Color(0xFF333333);
  static const Color onBackground = Color(0xFF333333);
  static const Color onSurface = Color(0xFF333333);
  static const Color onError = Color(0xFFFFFFFF);

  // --- Neutral Colors (Shared) ---
  static const Color border = Color(0xFFE0E0E0);
  static const Color divider = Color(0xFFBDBDBD);
  static const Color disabled = Color(0xFFBDBDBD);
  static const Color icon = Color(0xFF757575);

  // ===========================================================================
  // --- Dark Theme Colors ---
  // Enhanced romantic palette for couples app
  // ===========================================================================

  static const Color darkPrimary = Color(0xFFFF8C6B); // Soft Coral
  static const Color darkSecondary = Color(0xFFFFD1DC); // Glowing Pink
  static const Color darkAccent = Color(0xFFC5C6F0); // Light Periwinkle

  static const Color darkBackground = Color(0xFF14101F); // Deep Indigo
  static const Color darkSurface = Color(0xFF1F1A2A); // Midnight Purple
  static const Color darkError = Color(0xFFD32F2F); // Red error

  // --- Text Colors (Dark Theme) ---
  static const Color darkTextPrimary = Color(0xFFC5C6F0); // Light Periwinkle
  static const Color darkTextSecondary = Color(0xFF8F88A1); // Smoky Lavender

  // --- On-Color Tints (Dark Theme) ---
  static const Color onDarkPrimary = Color(0xFF14101F);
  static const Color onDarkSecondary = Color(0xFF14101F);
  static const Color onDarkBackground = Color(0xFFC5C6F0);
  static const Color onDarkSurface = Color(0xFFC5C6F0);
  static const Color onDarkError = Color(0xFF14101F);

  // ===========================================================================
  // --- Oceanic Theme Colors (Light Variant) ---
  // ===========================================================================
  static const Color oceanicPrimary = Color(0xFF006994);   // Sea Blue
  static const Color oceanicSecondary = Color(0xFF88D498);  // Seafoam Green
  static const Color oceanicBackground = Color(0xFFF0F7F4); // Very Light Cyan
  static const Color oceanicSurface = Color(0xFFFFFFFF);    // White
  static const Color oceanicTextPrimary = Color(0xFF1D3557);  // Dark Slate
  static const Color oceanicTextSecondary = Color(0xFF457B9D); // Lighter Blue
  static const Color oceaniconPrimary = Color(0xFFFFFFFF);

  // ===========================================================================
  // --- Sunset Theme Colors (Dark Variant) ---
  // ===========================================================================
  static const Color sunsetPrimary = Color(0xFFF28482);      // Warm Coral Pink
  static const Color sunsetSecondary = Color(0xFFF7B267);    // Mango Orange
  static const Color sunsetBackground = Color(0xFF2D3047);    // Deep Slate Blue
  static const Color sunsetSurface = Color(0xFF3C3F58);      // Darker Slate Blue
  static const Color sunsetTextPrimary = Color(0xFFEDF2F4);    // Light Cream
  static const Color sunsetTextSecondary = Color(0xFFB0B4DB);  // Muted Periwinkle
  static const Color sunsetonPrimary = Color(0xFF2D3047);

  // ===========================================================================
  // --- Pastel Theme Colors (Light Variant) ---
  // ===========================================================================
  static const Color pastelPrimary = Color(0xFFb5838d);      // Muted Rose
  static const Color pastelSecondary = Color(0xFFe5989b);    // Soft Pink
  static const Color pastelBackground = Color(0xFFfff1e6); // Creamy Peach
  static const Color pastelSurface = Color(0xFFFFFFFF);      // White
  static const Color pastelTextPrimary = Color(0xFF6d6875);  // Soft Charcoal
  static const Color pastelTextSecondary = Color(0xFF9d8189); // Muted Taupe
  static const Color pastelonPrimary = Color(0xFFFFFFFF);

  // ===========================================================================
  // --- Nebula Theme Colors (Dark Variant) ---
  // ===========================================================================
  static const Color nebulaPrimary = Color(0xFFF000B8);      // Vibrant Magenta
  static const Color nebulaSecondary = Color(0xFF00F0F0);    // Electric Cyan
  static const Color nebulaBackground = Color(0xFF0D0221);    // Near Black
  static const Color nebulaSurface = Color(0xFF261447);      // Deep Purple
  static const Color nebulaTextPrimary = Color(0xFFF0EFF4);    // Light Silver
  static const Color nebulaTextSecondary = Color(0xFFA499B3);  // Muted Lilac
  static const Color nebulaonPrimary = Color(0xFFFFFFFF);

  // ===========================================================================
  // ✨ --- NEW: Royal Amethyst Theme (Dark Variant) --- ✨
  // A luxurious and modern theme with deep purples and gold accents.
  // ===========================================================================
  static const Color amethystPrimary = Color(0xFF9b5de5);    // Rich Amethyst
  static const Color amethystSecondary = Color(0xFFf15bb5);  // Bright Magenta
  static const Color amethystBackground = Color(0xFF141318);  // Deep Space Purple
  static const Color amethystSurface = Color(0xFF23212a);    // Darker Purple
  static const Color amethysTextPrimary = Color(0xFFf7f7f7);  // Off-White
  static const Color amethysTextSecondary = Color(0xFFa09db0); // Muted Lavender
  static const Color amethysOnPrimary = Color(0xFFFFFFFF);

  // ===========================================================================
  // ✨ --- NEW: Serene Mint Theme (Light Variant) --- ✨
  // A clean, fresh, and calming theme with soft greens and peach.
  // ===========================================================================
  static const Color mintPrimary = Color(0xFF00b894);      // Fresh Mint
  static const Color mintSecondary = Color(0xFFff7675);    // Soft Coral
  static const Color mintBackground = Color(0xFFf5fcfb); // Almost White Mint
  static const Color mintSurface = Color(0xFFFFFFFF);      // White
  static const Color mintTextPrimary = Color(0xFF2d3436);  // Dark Slate
  static const Color mintTextSecondary = Color(0xFF636e72); // Lighter Grey
  static const Color mintOnPrimary = Color(0xFFFFFFFF);

  // ===========================================================================
  // ✨ --- NEW: Midnight Ocean Theme (Dark Variant) --- ✨
  // A deep, calm, and focused theme with strong blues and bright accents.
  // ===========================================================================
  static const Color oceanDarkPrimary = Color(0xFF0077b6);    // Strong Ocean Blue
  static const Color oceanDarkSecondary = Color(0xFF00b4d8);  // Bright Cyan
  static const Color oceanDarkBackground = Color(0xFF03045e);  // Midnight Blue
  static const Color oceanDarkSurface = Color(0xFF023e8a);    // Darker Ocean Blue
  static const Color oceanDarkTextPrimary = Color(0xFFcaf0f8);  // Light Sky Blue
  static const Color oceanDarkTextSecondary = Color(0xFF90e0ef); // Muted Cyan
  static const Color oceanDarkOnPrimary = Color(0xFFFFFFFF);
}