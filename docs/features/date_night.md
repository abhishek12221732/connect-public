# Feature: Date Nights

The `date_night` feature helps couples break out of routines by generating creative date ideas and facilitating real-time planning via suggestions.

## 📂 Directory Structure

```text
lib/features/date_night/
├── models/         # DateIdea model
├── repository/     # DoneDatesRepository (Historical tracking)
├── services/       # DateIdeaService (The generation engine)
└── screens/        # Generator, Suggested Idea, Done Dates History
```

## 🎲 The Generation Engine (`DateIdeaService`)

The core of this feature is a "Smart Fallback" generation strategy:
1. **Perfect Match**: Attempts to find an idea matching all user filters (Vibe, Budget, Time, Location).
2. **Loosened Constraints**: If no match is found, it drops Budget/Time constraints but keeps Location.
3. **Location Only**: Drops all filters except Location.
4. **Any Idea**: Returns a random date idea from the entire database as a last resort.

## 🤝 Suggestion & Sync

Users don't just see ideas; they can "Suggest" them to their partner:
- **Real-time Sync**: Uses a specific document `couples/{id}/suggestedDateIdeas/suggestion` to track the "active" suggestion.
- **Push Notifications**: Suggesting an idea triggers an immediate FCM notification to the partner.
- **Decision Phase**: Partners can see the suggestion on their Discover hub and choose to accept, cancel, or mark it as done.

## 🏆 Done Dates & History

Once a date is completed, it is moved to the **Done Dates** repository:
- **Tracking**: Logs who completed it, when, and links it back to the original `dateIdeaId`.
- **RHM Points**: Completing a suggested date idea typically grants highly-weighted RHM points (+10 or more) via the `DoneDatesProvider`.
