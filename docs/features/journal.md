# Feature: Personal & Shared Journals

The `journal` feature allows users to document their personal thoughts and collaborate on shared memories with their partner.

## 📂 Directory Structure

```text
lib/features/journal/
├── repository/     # JournalRepository (Personal & Shared logic)
├── screens/        # JournalScreen (History), JournalEditingScreen
└── widgets/        # Segment editors, entry tiles, sort buttons
```

## 📝 Entry Types

### 1. Personal Journal
Stored under `users/{userId}/personalJournals/`. These are private to the individual user and are not shared with the partner.
- **Privacy**: Encrypted using the user's local encryption keys (if enabled).

### 2. Shared Journal
Stored under `couples/{coupleId}/sharedJournals/`. These are collaborative entries that both partners can view and edit.
- **Segmented Writing**: Shared journals are composed of "Segments." Each segment tracks its author and timestamp, allowing for a back-and-forth collaborative writing experience.
- **Encryption**: Strictly uses the **Couple Master Key (CMK)** to ensure only the two partners can read the shared entries.

---

## 🏗️ Data Structure: Segments

Unlike standard text blocks, a journal entry in Feelings is a list of segments:

```json
{
  "title": "Encrypted Title",
  "segments": [
    {
      "authorId": "user1",
      "content": "Encrypted text from User 1",
      "timestamp": "..."
    },
    {
      "authorId": "user2",
      "content": "Encrypted response from User 2",
      "timestamp": "..."
    }
  ]
}
```

## ⚙️ Logic & State (`JournalProvider`)

The global `JournalProvider` manages the lifecycle of these entries:
- **Streaming**: Provides `Stream<List<JournalEntry>>` for both personal and shared collections.
- **Optimistic Updates**: When a user adds a segment, the UI updates immediately while the encrypted write is sent to Firestore.
- **Migration**: Automatically handles "Legacy to E2EE" migration. If an old plaintext journal is opened, the provider encrypts it using the CMK and saves it back to the server.

## 🎨 UI Components

- **`JournalTile`**: A summary card showing the title, date, and a "Shared" icon if applicable.
- **`EditableSegment`**: A specialized widget in the `JournalEditingScreen` that allows users to focus on their part of a shared story.
- **`JournalFabMenu`**: An animated Floating Action Button that allows users to quickly choose between starting a "Personal" or "Shared" entry.
