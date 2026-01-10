# Feature: Relationship Tips

The `tips` feature provides hyper-personalized, context-aware advice to help couples navigate their daily emotional landscape and strengthen their connection.

## 📂 Directory Structure

```text
lib/features/tips/
├── data/           # static_tips.dart (The fallback content library)
├── models/         # TipModel, DailyTipModel
├── repository/     # TipsRepository, DailyTipRepository
└── services/       # TipService (The dynamic logic engine)
```

## 🧠 Dynamic Intelligence (`TipService`)

Unlike static advice apps, "Feelings" generates tips dynamically based on several real-time signals:

- **Mood Matching**: Compares the current user's mood with their partner's mood (e.g., if User is "Stressed" and Partner is "Happy," it suggests ways for the partner to provide support).
- **Check-in Insights**: Scans the most recent `check_in` sessions. If a recurring theme (like "Lack of Connection") is detected, the engine prioritizes tips related to quality time.
- **Relational Metadata**: Can even calculate physical distance (via latitude/longitude) to suggest "Long Distance" tips if the couple is currently separated.
- **Static Library**: A curated collection of ~100+ static tips serves as the baseline content.

## 📅 Daily Tip of the Day

Each day, the `DailyTipRepository` selects and persists a specific tip for the couple:
- **Consistency**: Both partners see the same "Daily Tip" on their dashboard.
- **Caching**: The tip is cached locally to ensure it is available immediately upon app boot.

## ⚙️ Logic Layer (`TipsProvider`)

The global `TipsProvider` orchestrates the engine:
- **Auto-Refresh**: Triggers tip regeneration whenever a new mood is logged or a check-in is completed.
- **Priority System**: Ranks tips (High, Medium, Low) based on the severity of the signals (e.g., a "Conflict" signal triggers a High-priority resolution tip).
