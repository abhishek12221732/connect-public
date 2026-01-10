# Feature: Relationship Check-ins

The `check_in` feature provides a structured space for partners to reflect on their relationship, share insights, and track emotional trends over time.

## 📂 Directory Structure

```text
lib/features/check_in/
├── models/         # CheckInModel, CheckInQuestion
├── repository/     # CheckInRepository (Generation & Sharing logic)
├── screens/        # Welcome, Question flow, Summary, History
└── widgets/        # Question types (Slider, Multi-choice), Insight cards
```

## 📋 The Check-in Flow

A check-in is a private reflection session with several distinct phases:

1. **Question Selection**: The `CheckInRepository` generates a set of questions. These can be standard "Relationship Health" questions or dynamic "Trend-Based" questions if the system detects recurring themes in the user's mood.
2. **Interactive Session**: The user answers questions using various input types:
   - **Slider**: For quantitative metrics (e.g., "How connected do you feel? 1-10").
   - **Text Input**: For qualitative reflection.
   - **Yes/No & Multiple Choice**: For quick status updates.
3. **Insight Generation**: Upon completion, the system helps the user identify key "Insights" from their answers.
4. **Controlled Sharing**: Users can choose to:
   - Keep the session entirely private.
   - Share only specific **Insights** with their partner.
   - Share the **Full Check-in** results.

---

## 🏗️ Data Architecture: Privacy First

Check-ins follow a "Privacy by Design" principle:
- **Primary Storage**: Completed check-ins are stored in `users/{userId}/checkIns/`. These are NOT visible to the partner by default.
- **Shared Data**: Only when the user explicitly "Shares" does the data get copied to a location the partner can see. This ensures that users can be completely honest in their reflections without fear of immediate judgment.

## ⚙️ Logic & State (`CheckInProvider`)

The global `CheckInProvider` handles the complex state of the reflection engine:
- **Session Management**: Tracks progress through the multi-question wizard.
- **Partner Insight Listener**: Listens for new shared insights from the partner and triggers notifications/UI updates.
- **Analytics**: Calculates "Check-in Stats" (frequency, consistency) displayed on the user's profile and home dashboard.

## 🧱 Key Components

- **`QuestionWidget`**: A polymorphic widget that switches layouts based on the `QuestionType`.
- **`MetricCard` / `MiniLineChart`**: Visualizes trends in specific metrics (e.g., "Connection Score") over the last several check-ins.
- **`ShareInsightsDialog`**: A specialized UI for reviewing and selecting which specific points to share with the partner.
- **`PartnerInsightFeedCard`**: The visual representation of a shared reflection seen on the partner's Home Screen.
