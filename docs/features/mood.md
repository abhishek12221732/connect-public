# Feature: Mood Tracker

The `mood` feature allows partners to share their current emotional state in real-time. It moves beyond simple statuses by adding visual flair and integrating mood signals into other features like "Relationship Tips."

## 📂 Directory Structure

```text
lib/features/mood/
├── utils/          # MoodCategories (The emoji/label mapping)
└── widgets/        # MoodBox (The complex Home screen component)
```

## 🎭 The MoodBox Widget

The Home screen features a prominent `MoodBox` that serves as the visual anchor:
- **Dual Display**: Shows both the user's and the partner's current mood side-by-side.
- **Fluid Visuals**: Uses custom `FluidWave` painters to create an "emotional tide" effect around the avatars.
- **Adaptive Coloring**: UI colors (gradients, shadows) adapt based on the selected mood using the `MoodTheme` extension.

## ⚙️ State Management (`UserProvider`)

Mood logic is integrated directly into the `UserProvider` for maximum speed:
- **Optimistic Updates**: When a user selects a new mood, the UI updates instantly (`updateUserMood`). The change is then sent to Firestore in the background.
- **Real-time Sync**: A listener (`listenToPartnerMood`) ensures the partner's mood updates on the user's screen without a refresh.
- **History**: Mood changes are timestamped (`moodLastUpdated`), allowing the app to determine how "fresh" a status is.

## 🧩 Emotional Intelligence Integration

The user's mood is an input for other systems:
- **Personalized Tips**: The `TipService` uses the specific mood pair (e.g., Stressed/Happy) to generate tailored advice.
- **Mood History**: (Related features) Track trends over time to provide deeper relationship insights.

## 🛠️ Utils: `MoodCategories`

Defines the dictionary of 10+ supported moods, each with an associated emoji, label, and specialized color mapping for the `MoodTheme`.
