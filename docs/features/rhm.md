# Feature: Relationship Health Meter (RHM)

The RHM is the gamified heartbeat of the "Feelings" app. It quantifies the active effort both partners are putting into the relationship over a rolling 7-day window.

## 📂 Directory Structure

```text
lib/features/rhm/
├── models/         # RhmAction
├── repository/     # RhmRepository (The scoring engine)
└── (services)      # RhmAnimationService (Global Pip/Award UI)
```

## 📐 The Scoring Algorithm

The RHM does not use a lifetime total. Instead, it measures "current momentum":

- **Rolling Window**: Only points earned in the **last 7 days** contribute to the score.
- **The Target**: A healthy, highly active couple is expected to earn **75 points** per week.
- **Percentage Formula**: `(Total Points in 7 Days / 75) * 100`.
- **Natural Decay**: Points automatically "expire" from the calculation after 7 days, meaning the meter will drop if the couple stops interacting.

## 💎 Point Economy

Points are awarded for positive relational actions:

| Action Type | Points | Frequency Limit |
| :--- | :--- | :--- |
| **Complete Date Idea** | +10 | None |
| **Complete Bucket List Item** | +5 | None |
| **Answer Daily Question** | +1 | 1 per Day / User |
| **Add Bucket List Item** | +1 | 1 per 7 Days / Couple |
| **Send Secret Note** | +1 | 1 per 7 Days / Couple |

## ⚙️ Repository Logic (`RhmRepository`)

- **`logAction`**: Records the action with a `createdAt` and matches it with an `expireAt` (8 days later) timestamp.
- **`getRhmScoreStream`**: A reactive stream that recalculates the percentage every time a new action is logged by either partner.
- **Frequency Checking**: Methods like `getLastActionTimestampForUser` allow providers to enforce the "Once per Day" or "Once per Week" rules.

## 🎨 Visual Feedback

- **RHM Hub**: A detailed screen showing the breakdown of points per partner (User vs. Partner).
- **`rhmAnimationService`**: A global service that triggers high-fidelity animations (like floating pips or fireworks) whenever points are awarded, providing immediate positive reinforcement.
