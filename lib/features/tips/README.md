# Dynamic Tips System

This feature provides personalized relationship tips based on user mood and check-in data.

## Overview

The tips system generates dynamic, contextual advice for couples based on:
- Current user mood
- Partner's mood
- Recent check-in responses
- Relationship trends
- General relationship best practices

## Architecture

### Models
- `TipModel`: Represents a single tip with metadata
- `TipPriority`: Priority levels (low, medium, high, urgent)
- `TipCategory`: Categories for organizing tips

### Services
- `TipService`: Core logic for generating dynamic tips based on context

### Repository
- `TipsRepository`: Handles database operations (for future use)

### Provider
- `TipsProvider`: State management for tips across the app

### Widgets
- `TipCard`: Reusable tip display component
- `DynamicTipCard`: Auto-updating tip card that uses the provider

## How It Works

1. **Initialization**: The `TipsProvider` is initialized with user context (mood, check-in data, etc.)

2. **Tip Generation**: The `TipService` analyzes:
   - User's current mood (Happy, Sad, Angry, Stressed, etc.)
   - Partner's mood (if available)
   - Recent check-in responses and trends
   - Relationship metrics (satisfaction, communication, stress levels)

3. **Contextual Tips**: Based on the analysis, the system generates tips like:
   - Mood-specific advice (e.g., "When you're feeling sad, try sharing your feelings")
   - Trend-based insights (e.g., "Your satisfaction has been dropping")
   - General relationship tips (e.g., "Try to compliment your partner daily")

4. **Priority Sorting**: Tips are sorted by priority, with urgent/high-priority tips shown first

5. **Rotation**: Tips automatically rotate every 2 minutes, or users can manually refresh

## Usage

### In Home Screen
```dart
TipsWidget() // Shows tips in the home screen
```

### In Discover Screen
```dart
DynamicTipCard() // Shows tips in the relationship insights section
```

### Manual Tip Management
```dart
final tipsProvider = Provider.of<TipsProvider>(context, listen: false);
tipsProvider.nextTip(); // Get next tip
tipsProvider.refreshTips(); // Regenerate all tips
```

## Extensibility

The system is designed to be easily extensible:

1. **New Moods**: Add new mood cases in `TipService._generateMoodBasedTips()`
2. **New Check-in Questions**: Add analysis logic in `TipService._generateCheckInBasedTips()`
3. **New Categories**: Add new categories to `TipCategory` enum
4. **Custom Tips**: Add new tip generation methods in `TipService`

## Future Enhancements

- Save tip interactions for analytics
- A/B testing different tip strategies
- Machine learning for better tip personalization
- Tip effectiveness tracking
- Partner-specific tip sharing 