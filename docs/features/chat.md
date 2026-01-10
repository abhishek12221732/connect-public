# Feature: Real-Time Chat

The `chat` feature is the core communication engine of the Feelings app, supporting real-time messaging, end-to-end encryption, and rich media sharing.

## 📂 Directory Structure

```text
lib/features/chat/
├── models/         # MessageModel (Rich data structure)
├── repositories/   # ChatRepository (Sync, Typing, Persistence)
├── screens/        # ChatScreen (The main conversation UI)
└── widgets/        # Specialized bubbles (Text, Voice, Image) and Input
```

## 🏗️ Data Architecture

### `MessageModel`
A versatile model that handles:
- **Types**: `text`, `image`, `voice`.
- **States**: `sending`, `sent`, `seen`.
- **E2EE**: Stores `ciphertext`, `mac`, `nonce` for captions, and specialized "OTK" (One-Time Key) fields for audio files.
- **Replies**: Contextual metadata for nested replies, including image thumbnails.

### `ChatRepository`
Manages the Firestore "Chat Room" located at `chats/{chatId}/messages`.
- **`listenToMessages`**: Provides a real-time stream of the latest messages, ordered by timestamp.
- **`updateTypingStatus`**: Manages a transient `typing` field in the chat metadata to show real-time "Partner is typing..." indicators.
- **`sendMessage`**: Orchestrates the multi-step process of sending a message (Local sync -> Encryption -> Media Upload -> Firestore Write).

---

## 🔒 Encryption in Chat

Chat uses the **Couple Master Key (CMK)** to secure all standard communications.

- **Text**: Encrypted using Chacha20-Poly1305. The CMK is used with a unique nonce per message.
- **Media (Images/Voice)**: 
    1. A random **One-Time Key (OTK)** is generated for the file.
    2. The file is encrypted using the OTK.
    3. The OTK is encrypted using the CMK and stored in the message document (`audioGlobalOtk`).
    4. Only a partner with the CMK can decrypt the OTK, and thus the file.

---

## 🎙️ Rich Media Support

### Voice Messages
- **Recording**: Uses `path_provider` for temporary storage.
- **Spectrum Visualization**: Real-time waveform rendering during playback.
- **Decryption-on-the-fly**: Voice files are decrypted as they are streamed/played to ensure they never sit unencrypted on the device storage for long.

### Image Sharing
- **Cloudinary Integration**: Images are optimized and hosted via Cloudinary.
- **Thumbnails**: In-thread thumbnails are provided for quick browsing.

## 🛠️ Advanced UI Components

- **`EnhancedMessageBubble`**: A complex widget that handles context menus (Reply, Edit, Delete), message grouping by time, and delivery status icons.
- **`VoiceMessageBubble`**: specialized for playback with seeking and duration display.
- **`EnhancedChatInput`**: Supports multi-line text, voice recording toggle, image picking, and a reply-preview overlay.
