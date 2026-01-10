import 'package:flutter/material.dart';

enum MoodCategory {
  joy,      // Happy, Excited
  playful,  // Silly
  love,     // Loved, Romantic
  warmth,   // Grateful, Nostalgic, Hopeful
  peace,    // Peaceful, Content, Chill
  focus,    // Focused, Motivated
  sadness,  // Sad, Lonely
  anger,    // Angry, Jealous
  anxiety,  // Stressed, Anxious, Confused
  malaise,  // Sick
  fatigue,  // Tired, Sleepy
  ennui,    // Bored
}

class MoodModification {
  final double lightnessDelta; // 0.0 to 1.0 (additive)
  final double saturationDelta; // 0.0 to 1.0 (additive)
  final double hueDelta; // Degrees

  const MoodModification({
    this.lightnessDelta = 0.0,
    this.saturationDelta = 0.0,
    this.hueDelta = 0.0,
  });

  Color applyTo(Color baseColor) {
    HSLColor hsl = HSLColor.fromColor(baseColor);
    
    double newLightness = (hsl.lightness + lightnessDelta).clamp(0.1, 0.9);
    double newSaturation = (hsl.saturation + saturationDelta).clamp(0.0, 1.0);
    double newHue = (hsl.hue + hueDelta) % 360;

    return hsl.withLightness(newLightness).withSaturation(newSaturation).withHue(newHue).toColor();
  }
}

class MoodCategories {
  static MoodCategory getCategory(String mood) {
    switch (mood) {
      case 'Happy': return MoodCategory.joy;
      case 'Excited': return MoodCategory.joy;
      
      case 'Silly': return MoodCategory.playful;
      
      case 'Loved': return MoodCategory.love;
      case 'Romantic': return MoodCategory.love;
      
      case 'Grateful': return MoodCategory.warmth;
      case 'Nostalgic': return MoodCategory.warmth;
      case 'Hopeful': return MoodCategory.warmth;
      
      case 'Peaceful': return MoodCategory.peace;
      case 'Content': return MoodCategory.peace;
      case 'Chill': return MoodCategory.peace;
      
      case 'Focused': return MoodCategory.focus;
      case 'Motivated': return MoodCategory.focus;
      
      case 'Sad': return MoodCategory.sadness;
      case 'Lonely': return MoodCategory.sadness;
      
      case 'Angry': return MoodCategory.anger;
      case 'Jealous': return MoodCategory.anger;
      
      case 'Stressed': return MoodCategory.anxiety;
      case 'Anxious': return MoodCategory.anxiety;
      case 'Confused': return MoodCategory.anxiety;
      
      case 'Sick': return MoodCategory.malaise;
      
      case 'Tired': return MoodCategory.fatigue;
      case 'Sleepy': return MoodCategory.fatigue;
      
      case 'Bored': return MoodCategory.ennui;
      
      default: return MoodCategory.peace; // Default fallback
    }
  }

  static MoodModification getModification(String mood) {
    switch (mood) {
      // JOY: Happy (Base), Excited (Brighter/More Sat)
      case 'Excited': return const MoodModification(lightnessDelta: 0.05, saturationDelta: 0.1);
      
      // LOVE: Loved (Base), Romantic (Deeper)
      case 'Romantic': return const MoodModification(lightnessDelta: -0.05, saturationDelta: 0.05);
      
      // WARMTH: Grateful (Base), Nostalgic (Muted/Sepia shift), Hopeful (Brighter)
      case 'Nostalgic': return const MoodModification(saturationDelta: -0.2, lightnessDelta: -0.05);
      case 'Hopeful': return const MoodModification(lightnessDelta: 0.1);
      
      // PEACE: Peaceful (Base), Content (Slightly warmer), Chill (Cooler)
      case 'Content': return const MoodModification(hueDelta: -5.0);
      case 'Chill': return const MoodModification(hueDelta: 5.0, saturationDelta: -0.1);
      
      // FOCUS: Focused (Base), Motivated (More energetic/lighter)
      case 'Motivated': return const MoodModification(lightnessDelta: 0.1, saturationDelta: 0.1);
      
      // SADNESS: Sad (Base), Lonely (Darker/Muted)
      case 'Lonely': return const MoodModification(lightnessDelta: -0.1, saturationDelta: -0.2);
      
      // ANGER: Angry (Base), Jealous (Green-shift/Darker)
      case 'Jealous': return const MoodModification(hueDelta: 20.0, lightnessDelta: -0.05);
      
      // ANXIETY: Stressed (Base), Anxious (Lighter/Pale), Confused (Muted)
      case 'Anxious': return const MoodModification(lightnessDelta: 0.1, saturationDelta: -0.1);
      case 'Confused': return const MoodModification(saturationDelta: -0.3);
      
      // FATIGUE: Tired (Base), Sleepy (Darker/Purple shift)
      case 'Sleepy': return const MoodModification(lightnessDelta: -0.1, hueDelta: 10.0);
      
      default: return const MoodModification();
    }
  }
}
