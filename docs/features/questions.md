# Feature: Relationship Questions

The `questions` feature provides a vast library of conversation starters designed to deepen partners' understanding of each other across various life stages and emotional depths.

## 📂 Directory Structure

```text
lib/features/questions/
├── models/         # QuestionModel
├── repository/     # QuestionRepository (Global list & User-done list)
├── screens/        # QuestionsScreen (Browser & Search)
└── (logic)         # Managed by QuestionProvider (global)
```

## ❓ Question Types & Categories

Questions are organized hierarchically:
- **Categories**: Foundation, Relationship Reflections, Aspirations, Emotional Landscape.
- **Sub-Categories**: Rooted Memories, Shared Milestones, Guiding Principles, Inner Depths, etc.

## 📅 Daily Question of the Day (QOTD)

The `QuestionProvider` implements a specialized QOTD system:
- **Daily Rotation**: A new question is randomly selected every 24 hours.
- **Persistence**: The selected ID is stored in `SharedPreferences` so both partners can see and discuss the same question throughout the day.
- **Tracking**: Once answered, the question is added to the user's `doneQuestions` list in Firestore to prevent repetition.

## 📈 RHM Integration

Answering the Daily Question is a key ritual in the app:
- **Daily Reward**: Answering the QOTD grants **+1 RHM point** per user.
- **Frequency Guard**: This reward is limited to once per 24 hours per user to encourage genuine daily interaction rather than spamming.

## ⚙️ Logic Layer (`QuestionProvider`)

- **State Management**: Tracks available vs. completed questions.
- **Randomization**: Provides logic for fetching random questions from specific categories.
- **Real-time UI**: Notifications are sent to the `DynamicActionsProvider` whenever a question is asked, potentially triggering other app behaviors.
