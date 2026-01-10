# Core Components: Deep Dive

## 🎨 Advanced Theming (`lib/theme/`)

The Feelings app uses a sophisticated theme engine that goes beyond standard `ThemeData`.

### `MoodTheme` (Theme Extension)
We use `ThemeExtension<MoodTheme>` to inject custom, mood-specific color palettes into the standard `Theme`. This allows UI components to access mood colors safely:
```dart
final moodTheme = Theme.of(context).extension<MoodTheme>()!;
Color joyColor = moodTheme.joy;
```
- **Lerp Support**: Implements `lerp` for smooth transitions between different theme categories (e.g., switching from "Oceanic" to "Sunset").
- **12 Categories**: Defines semantic colors for 12 standard moods (Joy, Playful, Love, Focus, Sadness, etc.).

### Theme Factory Logic
The `AppTheme` class uses a private factory `_createTheme` to generate consistent looks for 10+ available themes. It configures:
- **Google Fonts**: Inter/Roboto integration.
- **Component Themes**: Standardized `ElevatedButtonThemeData`, `CardThemeData`, and `InputDecorationTheme`.
- **Brightness Awareness**: Distinct templates for Light and Dark modes.

---

## 🛠️ Global Utilities & Widgets

### `CrashlyticsHelper` (`lib/utils/crashlytics_helper.dart`)
A robust wrapper around Firebase Crashlytics:
- **Fatal Error Mapping**: Correctly handles Flutter fatal errors and platform-level exceptions.
- **Custom Context**: Automatically attaches `userId` and `coupleId` to every crash report.
- **breadcrumb Logging**: Provides a `log()` method to trace user actions before a crash.

### `RhmPointsAnimationOverlay` (`lib/widgets/`)
An app-wide overlay logic that listens to `RhmRepository` events.
- **Visual Feedback**: Triggers floating point animations when users perform positive relationship actions (sending a chat, completing a date).
- **Concurrency**: Manages a queue of animations to ensure they don't overlap or clutter the UI.

### `Globals` (`lib/utils/globals.dart`)
Contains the `rootScaffoldMessengerKey`. This is critical because it allows any service or provider to show a `SnackBar` without needing a `BuildContext` (e.g., showing an error from a background repository task).
