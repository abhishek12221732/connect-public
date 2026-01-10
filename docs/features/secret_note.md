# Feature: Secret Notes (Ephemeral Surprises)

The `secret_note` feature is designed to add a sense of playfulness and surprise to the relationship. It allows partners to leave "hidden" messages for each other that appear in unexpected places within the app.

## 📂 Directory Structure

```text
lib/features/secret_note/
├── repositories/   # SecretNoteRepository (CRUD & Logic)
├── screens/        # SecretNotesScreen (Creation & History)
└── widgets/        # SecretNoteIcon (The surprise icon), View Dialog
```

## 🕵️ How It Works: The Treasure Hunt

Secret notes are not shown in a standard list. Instead, the `SecretNoteProvider` dynamically places them in the UI:

1. **Unread Listening**: The app listens for any unread notes in `couples/{coupleId}/secret_notes/`.
2. **Random Assignment**: When a note is found, the `SecretNoteProvider` randomly assigns it to one of 7 locations:
   - `moodBox`, `rhmMeter`, `bucketList`, `journal`, `calendar`, `chatAppBar`, `tipCard`.
3. **The Discovery**: The user sees a small "Fluttering Envelope" icon in one of these locations.
4. **True Ephemerality**: Once the user opens the note and reads it, the document is **permanently deleted** from Firestore. This ensures that the message is truly a "one-time" surprise.

---

## 🔒 Security & Encryption

Secret notes leverage high-level E2EE, just like the Chat feature:

- **Encrypted Text**: The caption/text is encrypted using the Couple Master Key (CMK).
- **Encrypted Media**: 
  - **Images**: The Google Drive ID is encrypted before being stored.
  - **Voice**: Audio bytes are encrypted locally with a One-Time Key (OTK). The OTK itself is then encrypted with the CMK.
- **Decryption-on-the-fly**: Metadata is only decrypted when the user actually clicks the icon to view the note.

---

## 🎙️ Voice & Image Notes

Users can send more than just text:
- **Voice**: Recorded via the `SecretNotesScreen`, encrypted, and uploaded to Firebase Storage. Provides a custom playback UI inside the `SecretNoteViewDialog`.
- **Images**: Uploaded via the `MediaRepository` to Google Drive, ensuring high-quality, private storage.

## ⚙️ Logic & State (`SecretNoteProvider`)

The global provider is responsible for:
- **Stream Management**: Listening to the unread collection.
- **Animation Control**: Coordinating the "Appear" and "Disappear" animations of the envelope icons.
- **RHM Integration**: Sending a secret note logs relationship health points, encouraging partners to surprise each other frequently.
