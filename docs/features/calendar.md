# Feature: Couple Calendar & Milestones

The `calendar` feature helps couples organize their shared life, plan quality time, and remember significant milestones.

## 📂 Directory Structure

```text
lib/features/calendar/
├── models/         # CalendarEvent and Milestone definitions
├── repository/     # CalendarRepository (Firestore logic)
├── screens/        # CalendarScreen, AddEventWizard, EventDetails
└── widgets/        # Grid view, Header, Event cards
```

## 📅 Shared Calendar Events

Events are stored collaboratively in `couples/{coupleId}/events/`.

- **Event Metadata**: Includes `title`, `description`, `startDate`, `endDate`, `location`, and `category`.
- **Personal vs. Shared**: While most events are shared, the system supports an `isPersonal` flag for events only relevant to one partner.
- **Reminders**: Users can set `reminderTime` presets (e.g., "1 hour before"). The `CalendarProvider` uses the `NotificationService` to schedule local notifications on the hardware.

## 🎉 Milestones

Milestones are long-term markers of the relationship (e.g., "First Date," "Moving In").
- **Persistence**: Stored in `couples/{coupleId}/milestones/`.
- **Specialized UI**: Milestones are displayed with distinct styling to differentiate them from routine events.
- **Coupling**: Events can be linked to milestones via `milestoneId`.

---

## 🏗️ The Add Event Wizard

The `AddEventWizardScreen` is one of the most complex UI components in the app.
- **Step-by-Step Flow**: Guides the user through Category Selection -> Date/Time -> Reminders -> Additional Details.
- **Validation**: Ensures dates are logical (end after start) and required fields are populated before syncing to Firestore.

## ⚙️ Logic & State (`CalendarProvider`)

The global `CalendarProvider` orchestrates the calendar experience:
- **Real-time Streaming**: Listens to the `events` and `milestones` subcollections, providing a unified view of the month.
- **Notification Scheduling**: When an event is added/updated, the provider automatically schedules or cancels local notifications based on the `reminderTime`.
- **Filtering**: Supports filtering events by category or "Personal" status.

## 🎨 UI Components

- **`CalendarGrid`**: A custom-built grid that highlights days with events.
- **`UpcomingEventCard`**: Featured on the Home Dashboard, showing the next 3 imminent events.
- **`EventDetailsModal`**: A rich bottom sheet providing full event context and quick "Edit" or "Delete" actions.
