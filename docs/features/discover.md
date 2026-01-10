# Feature: Discover Hub

The `discover` feature is the exploratory heart of the "Feelings" app, acting as a gateway to new activities, relationship insights, and shared growth.

## 📂 Directory Structure

```text
lib/features/discover/
├── screens/        # DiscoverScreen (Combined view)
└── widgets/        # Specialized cards and sections
```

## 🧭 The Hub Concept

`DiscoverScreen` aggregates information from multiple features to encourage interaction:

- **Connected vs. Disconnected**: If a user isn't yet paired with a partner, the screen shows a "Locked" state, encouraging connection to reveal the full experience.
- **Dynamic Content**: Sections are rendered based on the couple's current activity levels and relationship status.

---

## 🎭 Date Night Engine (`DateIdeaProvider`)

The "Date Night" card is the primary interaction point in Discover:
- **Filtered Generation**: Users can generate date ideas based on **Vibe** (Romantic, Fun, Relaxing), **Budget** ($ to $$$), **Time**, and **Location**.
- **Suggest to Partner**: A user can "Suggest" a specific idea. This triggers a push notification to the partner and opens a real-time sync session.
- **Favorites**: Users can save ideas to their personal favorites list (stored in `users/{userId}/favorites`).

## 🧱 Discover Sections

- **Know Each Other**: Interactive cards powered by the `QuestionProvider` that prompt partners to answer deep or fun questions.
- **Relationship Insights**: Visualizes summaries from the `check_in` feature, showing emotional trends or shared growth milestones.
- **Bucket List Preview**: Shows the most recent 3 items from the collaborative bucket list.
- **Send Secret Note Shortcut**: A quick-access button to send an ephemeral surprise note.

## ⚙️ Logic & Integration

- **`DateIdeaProvider`**: Manages the complex state of filtered searching and real-time suggestion sync between partners.
- **Real-time Feedback**: When a partner suggests an idea, the Discover screen updates instantly via a Firestore stream listener.
- **RHM Integration**: Completing a suggested date idea results in significant RHM point gains via the `DoneDatesProvider`.
