# Feelings - Project Documentation Structure

This directory contains the comprehensive documentation for the "Feelings" Flutter project.

## 🗺️ Documentation Map

### 1. [Global Overview](../OVERVIEW.md)
*High-level architecture, tech stack, and application boot sequence.*

### 2. [Core Components](../CORE_COMPONENTS.md)
*Global themes, utilities, and high-frequency reusable widgets.*

### 3. [Services](../SERVICES.md)
*Deep dive into infrastructure: Encryption (E2EE), Notifications (FCM), and Data Persistence.*

### 4. [State Management](../STATE_MANAGEMENT.md)
*Explanation of global providers and the "Stale-While-Revalidate" caching strategy.*

---

## 🚀 Feature-Specific Deep Dives

Each major module in `lib/features/` is documented with its own logic and data structures:

| Feature | Description | Link |
| :--- | :--- | :--- |
| **Authentication** | Google Sign-in, User models, and Account deletion. | [auth.md](features/auth.md) |
| **Home Dashboard** | Data aggregation, RHM meter, and quick-action hubs. | [home.md](features/home.md) |
| **Real-time Chat** | E2EE messaging, Voice/Image sharing, and Typing status. | [chat.md](features/chat.md) |
| **Journaling** | Personal & Shared segmented entries with collaborative logic. | [journal.md](features/journal.md) |
| **Calendar** | Shared events, Milestones, and Local Notification scheduling. | [calendar.md](features/calendar.md) |
| **Check-ins** | Intentional reflections, AI insights, and granular sharing. | [check_in.md](features/check_in.md) |
| **Secret Notes** | Ephemeral surprises hidden throughout the UI with unread badges. | [secret_note.md](features/secret_note.md) |
| **Bucket List** | Shared goals and RHM-integrated achievement tracking. | [bucket_list.md](features/bucket_list.md) |
| **Discover Hub** | Gateways to date ideas, insights, and quick relationship actions. | [discover.md](features/discover.md) |
| **Date Nights** | Generator with fallback logic and real-time suggestion sync. | [date_night.md](features/date_night.md) |
| **Relationship Tips** | Personalized, context-aware advice via dynamic signals. | [tips.md](features/tips.md) |
| **Daily Questions** | Deep conversation starters with RHM point rewards. | [questions.md](features/questions.md) |
| **Mood Tracker** | Shared emotional status with adaptive themes and fluid visuals. | [mood.md](features/mood.md) |
| **RHM Meter** | Gamified momentum tracker with rolling 7-day scoring. | [rhm.md](features/rhm.md) |
| **Media Systems**| Cloudinary and E2EE Google Drive storage integration. | [media_encryption.md](features/media_encryption.md) |
| **Connect Couple** | Partner invitation, handshake, and lifecycle management. | [connect_couple.md](features/connect_couple.md) |
| **Onboarding** | Multi-step setup, verification, and connection flow. | [onboarding.md](features/onboarding.md) |
| **App Status** | Global maintenance modes and emergency priority messaging. | [app_config.md](features/app_config.md) |

---

## 🏗️ Technical Directory Map

```text
lib/
├── features/         # Modular feature-based architecture
├── providers/        # Global state management
├── services/         # Core infrastructure (E2EE, Notifs)
├── theme/            # Multi-theme system extensions
├── utils/            # Shared logic (Crashlytics, Globals)
└── widgets/          # Global reusable UI
```
