# Feature: Home Dashboard & Navigation

The `home` feature acts as the central hub of the Feelings app, providing a high-level overview of the relationship and quick access to all major features.

## 📂 Directory Structure

```text
lib/features/home/
├── screens/        # HomeScreen, BottomNavBar, RhmDetailScreen
├── view_models/    # HomeScreenViewModel (Logic)
└── widgets/        # Specialized dashboard components (RHM Meter, Events, Stats)
```

## 🧭 Navigation: `BottomNavBar`

The `BottomNavBar` uses the `google_nav_bar` package for a premium, animated feel.

- **Centralized Routing**: Manages transitions between `HomeScreen`, `JournalScreen`, `ChatScreen`, and `CalendarScreen`.
- **Badges**: Displays real-time unread message counts on the Chat icon by listening to the `ChatProvider`.
- **Security Guard**: It is responsible for triggering the `EncryptionSetupDialog` if it detects that the user has encryption enabled but the local master key is missing.

## 🏠 Dashboard: `HomeScreen`

The dashboard is designed to be informative and "at-a-glance."

### Data Aggregation (`HomeScreenViewModel`)
The `HomeScreenViewModel` is a feature-specific provider that aggregates data from multiple sources:
- **Relationship Health**: Fetches current points from `RhmRepository`.
- **Engagement Stats**: Calculates counts for shared notes, photos, and messages.
- **Partner Insight**: Displays the partner's current mood and last updated time.
- **Syncing**: Coordinates with `UserProvider` and `CoupleProvider` to ensured data is loaded before rendering.

---

## 📈 Relationship Health Meter (RHM)

The RHM is a gamified representation of the couple's interaction frequency and quality.

- **`RhmMeterWidget`**: A custom circular/arc painter that visualizes the current point total.
- **`RhmDetailScreen`**: Provides a breakdown of "Point History," showing exactly which actions (e.g., "Sent a sweet note") contributed to the score.
- **Point Categories**: Interactions are categorized (Communication, Quality Time, Appreciation) to help couples see where they are strongest.

## 🧱 Key Dashboard Widgets

- **`EventsBox`**: A horizontal list of upcoming anniversaries or milestones from the `CalendarProvider`.
- **`StatsGrid`**: Displays numerical achievements (e.g., "150 Days Together," "42 Shared Photos").
- **`SuggestionCard`**: Uses the `DateIdeaProvider` to recommend activities based on the couple's history and current mood.
- **`DailyActionHub`**: Quick-action buttons to "Log a Mood," "Send a Note," or "Plan a Date."
