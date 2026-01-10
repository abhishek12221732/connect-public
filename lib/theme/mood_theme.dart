import 'package:flutter/material.dart';

@immutable
class MoodTheme extends ThemeExtension<MoodTheme> {
  // 12 Distinct Categories
  final Color joy;
  final Color playful;
  final Color love;
  final Color warmth;
  final Color peace;
  final Color focus;
  final Color sadness;
  final Color anger;
  final Color anxiety;
  final Color malaise;
  final Color fatigue;
  final Color ennui;

  const MoodTheme({
    required this.joy,
    required this.playful,
    required this.love,
    required this.warmth,
    required this.peace,
    required this.focus,
    required this.sadness,
    required this.anger,
    required this.anxiety,
    required this.malaise,
    required this.fatigue,
    required this.ennui,
  });

  @override
  MoodTheme copyWith({
    Color? joy,
    Color? playful,
    Color? love,
    Color? warmth,
    Color? peace,
    Color? focus,
    Color? sadness,
    Color? anger,
    Color? anxiety,
    Color? malaise,
    Color? fatigue,
    Color? ennui,
  }) {
    return MoodTheme(
      joy: joy ?? this.joy,
      playful: playful ?? this.playful,
      love: love ?? this.love,
      warmth: warmth ?? this.warmth,
      peace: peace ?? this.peace,
      focus: focus ?? this.focus,
      sadness: sadness ?? this.sadness,
      anger: anger ?? this.anger,
      anxiety: anxiety ?? this.anxiety,
      malaise: malaise ?? this.malaise,
      fatigue: fatigue ?? this.fatigue,
      ennui: ennui ?? this.ennui,
    );
  }

  @override
  MoodTheme lerp(ThemeExtension<MoodTheme>? other, double t) {
    if (other is! MoodTheme) {
      return this;
    }
    return MoodTheme(
      joy: Color.lerp(joy, other.joy, t)!,
      playful: Color.lerp(playful, other.playful, t)!,
      love: Color.lerp(love, other.love, t)!,
      warmth: Color.lerp(warmth, other.warmth, t)!,
      peace: Color.lerp(peace, other.peace, t)!,
      focus: Color.lerp(focus, other.focus, t)!,
      sadness: Color.lerp(sadness, other.sadness, t)!,
      anger: Color.lerp(anger, other.anger, t)!,
      anxiety: Color.lerp(anxiety, other.anxiety, t)!,
      malaise: Color.lerp(malaise, other.malaise, t)!,
      fatigue: Color.lerp(fatigue, other.fatigue, t)!,
      ennui: Color.lerp(ennui, other.ennui, t)!,
    );
  }

  // Define Standard Palettes
  static const light = MoodTheme(
    joy: Color(0xFFFFA900),     // Amber/Orange
    playful: Color(0xFFFF69B4), // Hot Pink
    love: Color(0xFFFF4081),    // Pink Accent
    warmth: Color(0xFFFF8A65),  // Deep Orange Light
    peace: Color(0xFF4DB6AC),   // Teal Light
    focus: Color(0xFF5C6BC0),   // Indigo Light
    sadness: Color(0xFF64B5F6), // Blue Light
    anger: Color(0xFFE57373),   // Red Light
    anxiety: Color(0xFFBA68C8), // Purple Light
    malaise: Color(0xFFAED581), // Light Green
    fatigue: Color(0xFFA1887F), // Brown Light
    ennui: Color(0xFF90A4AE),   // Blue Grey
  );

  static const dark = MoodTheme(
    joy: Color(0xFFFFD54F),     // Amber 300
    playful: Color(0xFFF48FB1), // Pink 200
    love: Color(0xFFFF80AB),    // Pink Accent 100
    warmth: Color(0xFFFFCC80),  // Orange 200
    peace: Color(0xFF80CBC4),   // Teal 200
    focus: Color(0xFF9FA8DA),   // Indigo 200
    sadness: Color(0xFF90CAF9), // Blue 200
    anger: Color(0xFFEF9A9A),   // Red 200
    anxiety: Color(0xFFCE93D8), // Purple 200
    malaise: Color(0xFFC5E1A5), // Light Green 200
    fatigue: Color(0xFFBCAAA4), // Brown 200
    ennui: Color(0xFFB0BEC5),   // Blue Grey 200
  );
  
  // Sunset: Warm, Energetic, Romantic
  static const sunset = MoodTheme(
    joy: Color(0xFFFFC107),     // Amber
    playful: Color(0xFFFF80AB), // Pink Accent
    love: Color(0xFFFF5252),    // Red Accent
    warmth: Color(0xFFFF9E80),  // Deep Orange Accent
    peace: Color(0xFF26A69A),   // Teal
    focus: Color(0xFF7986CB),   // Indigo
    sadness: Color(0xFF4FC3F7), // Light Blue
    anger: Color(0xFFD32F2F),   // Red 700
    anxiety: Color(0xFFAB47BC), // Purple
    malaise: Color(0xFF9CCC65), // Light Green
    fatigue: Color(0xFF8D6E63), // Brown
    ennui: Color(0xFF78909C),   // Blue Grey
  );

  // Oceanic: Cool, Calm, Serene
  static const oceanic = MoodTheme(
    joy: Color(0xFFFFB74D),     // Orange 300 (Subtle pop)
    playful: Color(0xFF4DD0E1), // Cyan 300
    love: Color(0xFFF06292),    // Pink 300
    warmth: Color(0xFF81C784),  // Green 300
    peace: Color(0xFF009688),   // Teal
    focus: Color(0xFF1E88E5),   // Blue 600
    sadness: Color(0xFF1565C0), // Blue 800
    anger: Color(0xFFC62828),   // Red 800
    anxiety: Color(0xFF7E57C2), // Deep Purple 400
    malaise: Color(0xFF80CBC4), // Teal 200
    fatigue: Color(0xFF546E7A), // Blue Grey 600
    ennui: Color(0xFFB0BEC5),   // Blue Grey 200
  );

  // Pastel: Soft, Muted, dreamy
  static const pastel = MoodTheme(
    joy: Color(0xFFFFE082),     // Amber 200
    playful: Color(0xFFF8BBD0), // Pink 100
    love: Color(0xFFFFCDD2),    // Red 100
    warmth: Color(0xFFFFCCBC),  // Deep Orange 100
    peace: Color(0xFFB2DFDB),   // Teal 100
    focus: Color(0xFFC5CAE9),   // Indigo 100
    sadness: Color(0xFFBBDEFB), // Blue 100
    anger: Color(0xFFFFCDD2),   // Red 100
    anxiety: Color(0xFFE1BEE7), // Purple 100
    malaise: Color(0xFFDCEDC8), // Light Green 100
    fatigue: Color(0xFFD7CCC8), // Brown 100
    ennui: Color(0xFFCFD8DC),   // Blue Grey 100
  );

  // Amethyst: Royal, Deep, Purple-centric
  // Amethyst: Royal, Deep, Jewel Tones
  static const amethyst = MoodTheme(
    joy: Color(0xFFFFD54F),     // Soft Gold (Amber 300)
    playful: Color(0xFFE040FB), // Vivid Purple (Purple Accent 200)
    love: Color(0xFFD500F9),    // Deep Magenta (Purple Accent 400)
    warmth: Color(0xFFFF6E40),  // Deep Coral (Deep Orange Accent 200)
    peace: Color(0xFFB388FF),   // Soft Lavender (Deep Purple Accent 100)
    focus: Color(0xFF6200EA),   // Royal Violet (Deep Purple Accent 700)
    sadness: Color(0xFF304FFE), // Deep Indigo (Indigo Accent 700)
    anger: Color(0xFFA1054C),   // Dark Ruby
    anxiety: Color(0xFF7B1FA2), // Plum (Purple 700)
    malaise: Color(0xFF5E35B1), // Muted Violet (Deep Purple 600)
    fatigue: Color(0xFF4527A0), // Dark Purple (Deep Purple 800)
    ennui: Color(0xFF9575CD),   // Muted Lavender (Deep Purple 300)
  );
  
  // Mint: Fresh, Clean, Nature
  static const mint = MoodTheme(
    joy: Color(0xFFFFB74D),     // Orange 300
    playful: Color(0xFFFF8A80), // Red Accent 100
    love: Color(0xFFF48FB1),    // Pink 200
    warmth: Color(0xFFFFAB91),  // Deep Orange 200
    peace: Color(0xFF00BFA5),   // Teal Accent 700 (Focus here)
    focus: Color(0xFF00897B),   // Teal 600
    sadness: Color(0xFF29B6F6), // Light Blue 400
    anger: Color(0xFFEF5350),   // Red 400
    anxiety: Color(0xFFAB47BC), // Purple 400
    malaise: Color(0xFFAED581), // Light Green 300
    fatigue: Color(0xFF8D6E63), // Brown 400
    ennui: Color(0xFF78909C),   // Blue Grey 400
  );
  
  // Ocean Dark: Deep Sea, Mysterious
  static const oceanDark = MoodTheme(
    joy: Color(0xFFFFAB40),     // Orange Accent (Contrast)
    playful: Color(0xFF00B0FF), // Light Blue Accent
    love: Color(0xFFE040FB),    // Purple Accent
    warmth: Color(0xFF40C4FF),  // Light Blue Accent 100
    peace: Color(0xFF64FFDA),   // Teal Accent
    focus: Color(0xFF2979FF),   // Blue Accent 400
    sadness: Color(0xFF2962FF), // Blue Accent 700
    anger: Color(0xFFFF5252),   // Red Accent 200
    anxiety: Color(0xFF7C4DFF), // Deep Purple Accent 200
    malaise: Color(0xFF69F0AE), // Green Accent 200
    fatigue: Color(0xFF546E7A), // Blue Grey 600
    ennui: Color(0xFF455A64),   // Blue Grey 700
  );
  // ✨ --- NEW: Midnight (OLED) Moods --- ✨
  // High contrast neons against black
  static const midnight = MoodTheme(
    joy: Color(0xFFFFFF00),      // Neon Yellow
    playful: Color(0xFFFF00FF),  // Neon Magenta
    love: Color(0xFFFF3D00),     // Neon Red
    warmth: Color(0xFFFF9100),   // Neon Orange
    peace: Color(0xFF00E5FF),    // Neon Cyan
    focus: Color(0xFF2979FF),    // Electric Blue
    sadness: Color(0xFF3D5AFE),  // Royal Blue
    anger: Color(0xFFD50000),    // Bright Red
    anxiety: Color(0xFFAA00FF),  // Neon Purple
    malaise: Color(0xFF76FF03),  // Neon Green
    fatigue: Color(0xFF9E9E9E),  // Grey
    ennui: Color(0xFFECEFF1),    // White
  );

  // ✨ --- NEW: Eclipse (Luxury) Moods --- ✨
  // Rich, deep, metallic tones
  static const eclipse = MoodTheme(
    joy: Color(0xFFFFD700),      // Gold
    playful: Color(0xFFF06292),  // Rose Goldish
    love: Color(0xFFC2185B),     // Ruby
    warmth: Color(0xFFE65100),   // Dark Orange/Bronze
    peace: Color(0xFFB2EBF2),    // Pale Cyan
    focus: Color(0xFF455A64),    // Blue Grey
    sadness: Color(0xFF1A237E),  // Navy
    anger: Color(0xFFB71C1C),    // Garnet
    anxiety: Color(0xFF4A148C),  // Deep Amethyst
    malaise: Color(0xFF827717),  // Olive
    fatigue: Color(0xFF795548),  // Brown
    ennui: Color(0xFF607D8B),    // Slate
  );

  // ✨ --- NEW: Aurora (Nature) Moods --- ✨
  // Bioluminescent and organic tones
  static const aurora = MoodTheme(
    joy: Color(0xFFFFEB3B),      // Sunlight
    playful: Color(0xFFE91E63),  // Berry
    love: Color(0xFFF48FB1),     // Soft Pink
    warmth: Color(0xFFFF7043),   // Sunset
    peace: Color(0xFF00BFA5),    // Teal
    focus: Color(0xFF0277BD),    // Ocean
    sadness: Color(0xFF81D4FA),  // Rain
    anger: Color(0xFFBF360C),    // Magma
    anxiety: Color(0xFF512DA8),  // Storm
    malaise: Color(0xFF33691E),  // Moss
    fatigue: Color(0xFF5D4037),  // Earth
    ennui: Color(0xFFCFD8DC),    // Cloud
  );
}
