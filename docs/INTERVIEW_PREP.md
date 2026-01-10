# Interview Preparation: Technical Deep Dive

This document provides detailed, **verified** answers to your technical interview checklist, based strictly on the current codebase implementation.

---

## 🏗️ Architecture & Structure

### **1. Map and document app folder structure and “why” behind it**
- **Structure**:
  - `lib/features/`: Vertical slices (e.g., `chat`, `auth`, `media`). Each contains its own `screens`, `repository`, `models`, and `services`.
  - `lib/providers/`: Global state (e.g., `UserProvider`, `CoupleProvider`).
  - `lib/services/`: App-wide singletons (e.g., `EncryptionService`, `NotificationService`).
  - `lib/utils/`: Shared logic (`CrashlyticsHelper`, `Globals`).
- **Why**: **Feature-First**. It ensures high cohesion. If you delete `lib/features/secret_note`, you remove the entire feature without leaving orphan files in a generic `controllers` folder.

### **2. Decide and justify feature-based vs layer-based architecture**
- **Decision**: **Feature-Based**.
- **Justification**: Scalability. In a Layer-Based approach, a simple feature modification requires touching files in 4 different folders (`views`, `models`, `controllers`, `services`). In Feature-Based, all related files are in `lib/features/{name}/`, reducing context switching and merge conflicts.

### **3. Document where state lives in the app**
- **Global Data**: `Provider` classes in `lib/providers` (e.g., `UserProvider`, `CoupleProvider`).
- **Infrastructure State**: Singletons (e.g., `EncryptionService` holds the loaded `SecretKey` in memory).
- **Ephemeral UI**: `StatefulWidget` (e.g., `BottomNavBarWithFade` for animation state).
- **Persisted State**: Firestore (Remote) and `SharedPreferences` (Local user ID/Theme).

### **4. Document where async logic lives**
- **Repositories**: Standard CRUD (e.g., `ChatRepository.sendMessage`, `MediaRepository.uploadToGoogleDrive`).
- **Services**: Complex system logic (e.g., `EncryptionService.deriveSharedSecret`, `DateIdeaService.generateDateIdeas`).
- **Providers**: Orchestrate calls (`await repository.doWork()`) and map results to state.

### **5. Document where data transformation happens**
- **Repository Layer**.
- **Example**: `ChatRepository.listenToMessages` receives a Firestore `QuerySnapshot`. It immediately maps it to `MessageModel.fromMap(doc.data())` before the logical layer ever sees it.

### **6. List what logic must never touch UI**
- **Direct Database Access**: No `FirebaseFirestore.instance` calls in Widgets (except `main.dart` setup).
- **Encryption Operations**: The UI should never handle raw `Chacha20` ciphers or keys.
- **DTO Conversion**: No manual `Map<String, dynamic>` parsing in build methods.

---

## ⚡ State Management

### **7. Review `ChangeNotifier` lifecycle and note examples from your app**
- **Lifecycle**: `init` (Provider create) -> `notifyListeners` (Update) -> `dispose` (Cleanup).
- **Example**: `ChatProvider` initializes `listenToMessages` in its method. On `dispose()`, it cancels `_messagesSubscription` and `_typingSubscription` to prevent memory leaks.

### **8. Trace how `notifyListeners()` propagates in your app**
- **Mechanism**: When `ChatProvider` calls `notifyListeners()`, it marks itself as dirty. Flutter schedules a rebuild for all `Consumer<ChatProvider>` and `context.watch<ChatProvider>` widgets in the next frame.
- **Specifics**: `ChatProvider` also syncs a `ValueNotifier<List<MessageModel>>` (`messagesNotifier`) for specialized direct listeners if needed.

### **9. Identify what rebuilds when a provider updates**
- **Broad Scope**: `Consumer<UserProvider>` rebuilds on *any* property change (mood, name, or points).
- **Optimization**: We use `Selector` or split widgets (e.g., `RhmPointsAnimationOverlay` listens to specific streams/providers) to avoid rebuilding the whole screen.

### **10. Compare `Consumer` vs `Selector` with examples**
- **Consumer**: `Consumer<ThemeProvider>` in `main.dart` rebuilds the entire `MaterialApp` on theme change (desired).
- **Selector**: `Selector<UserProvider, int>` (Hypothetical) matches only when the integer value changes.

### **11. Find places where Provider causes over-rebuilds**
- **Issue**: The `ChatScreen` list listens to `ChatProvider`. When `isPartnerTyping` changes, `notifyListeners()` fires, causing the *entire* message list to rebuild, not just the typing indicator.
- **Mitigation**: `TypingIndicator` should ideally listen to a separate stream or `Selector<ChatProvider, bool>`, allowing the list to remain static.

### **12. Add or refine patterns to mitigate rebuild cascades**
- **const Widgets**: Extracted `MessageBubble` to a separate class.
- **Leaf Consumers**: Instead of wrapping the Page, we wrap distinct sections (e.g., `Consumer` around only the `RhmMeter` widget).

---

## 💾 Data Layer

### **13. Write notes on why UI must not call Firestore directly**
- **Coupling**: Hard coupling to Firebase SDK makes it impossible to switch backends.
- **Testing**: Requires complex mocking of `FirebaseFirestore` instance.
- **Duplication**: Same query logic would be repeated across multiple screens.

### **14. Document how repositories improve testability in your codebase**
- **Interface**: We can swap `ChatRepository` with `MockChatRepository`.
- **Unit Tests**: `ChatProvider` tests can assert state changes without making real network calls.

### **15. Document how repositories isolate backend changes**
- **Schema Safety**: If Firestore field `is_typing` changes to `typing_status`, we only update `ChatRepository.listenToTypingStatus`. The Provider still consumes a boolean `isTyping`.

### **16. Describe what happens in your app if backend schema changes**
- **Robustness**: `fromMap` methods use `?? defaults` (e.g., `uploadStatus: map['uploadStatus'] ?? 'success'`).
- **Crash Prevention**: If a new field is missing, the app defaults gracefully rather than throwing a `NullPointerException`.

### **17. Decide and document where caching belongs (repo vs provider)**
- **Repository**: For data fetching (`UserRepository` checks `Source.cache`).
- **Provider**: For application state (e.g., `ChatProvider` holds `_messages` list in memory).

---

## 🔮 Chat & Real-time

### **18. Document Firestore listeners vs polling in your chat flow**
- **Flow**: `ChatRepository.listenToMessages` uses `collection.snapshots()`.
- **Why**: WebSockets (Listeners) provide <100ms latency. Polling is too slow for chat.

### **19. Clarify message ordering guarantees in your implementation**
- **Query**: `orderBy('timestamp', descending: true)`.
- **Client**: `ChatProvider` also explicitly sorts `_messages` in memory (`b.timestamp.compareTo(a.timestamp)`) after merging optimistic updates to ensure new messages stay at the bottom/top correctly.

### **20. List how you handle network latency**
- **Optimistic UI**: Messages appear instantly.
- **Background Upload**: The user is unblocked while `_uploadAndSend` runs in the background.

### **21. Document optimistic UI implementation for messages**
1. Provider creates `MessageModel` with `status='unsent'` (or `'sent'` for text).
2. Adds to `_optimisticMessages` map and `_messages` list.
3. Notifies listeners (UI renders).
4. Network call executes.
5. On success, `_mergeWithOptimisticMessages` replaces the temp ID with the real Firestore ID.

### **22. Define message states (sending, sent, failed) and how you show them**
- **unsent/sending**: Clock Icon (Alpha 0.5).
- **uploading**: (For media) Distinct state.
- **sent**: Single Checkmark.
- **seen**: Double Checkmark (handled by `markMessageAsSeen`).
- **failed**: Red UI element (handled in `ChatProvider` catch block).

### **23. Note deduplication strategies you use**
- **Temp IDs**: Optimistic messages use `tempId`.
- **Merging Logic**: `ChatProvider._mergeWithOptimisticMessages` checks if a server message matches a local optimistic one (by ID or roughly by content/timestamp/sender) and removes the local duplicate.

### **24. Document how you handle reconnects**
- **Firestore**: Automatically handles socket reconnection.
- **App Logic**: `AuthWrapper` can trigger `_performCleanupAsync` or re-init listeners on auth state change.
- **Safety Sync**: `ChatProvider` re-decrypts messages (`_reDecryptAllMessages`) when `EncryptionService` signals `onKeyReady`.

### **25. Document cold start behavior for chat**
- **Limit**: Fetches last 20 messages (`limit(20)`).
- **Pagination**: `fetchMoreMessages` uses `startAfterDocument` to load history as user scrolls.

---

## 🔌 Offline & Sync

### **26. List what data is cached locally**
- **Auth**: `User` object (Firebase Auth).
- **DB**: Firestore Offline Persistence (enabled by default).
- **Images**: `flutter_cache_manager` (standard lib behavior).
- **Keys**: `FlutterSecureStorage`.

### **27. Write your cache invalidation strategy**
- **Reactive**: We rely on Firestore pushing updates to overwrite stale cache.
- **Logout**: Explicitly clears `Conversation` state and Encryption Keys.

### **28. Describe your sync-on-connect flow**
- **RHM**: `ChatProvider` runs `_syncRhmPoints` to log queued points (e.g., 'message sent') to `RhmRepository`.

### **29. Describe conflict resolution approach**
- **Default**: Last Write Wins (Firestore).
- **Points**: `RhmRepository` logic likely adds points rather than setting absolute values where possible, or relies on atomic updates logic if implemented (current code shows simple writes).

### **30. Note Firestore offline persistence behavior in your app**
- **Enabled**: `DefaultFirebaseOptions`.
- **Writes**: Queued locally. A text message sent offline will reside in the local cache and sync automatically when online.

### **31. List edge cases when app is killed**
- **Media Uploads**: If killed during `_uploadAndSend` (image), the upload fails. No background service retries it. User sees "Failed" on next launch.
- **Text Sync**: Firestore SDK handles text message sync on next launch if it was committed to the local queue.

---

## 🖼️ Media Pipeline

### **32. Document image upload pipeline end-to-end**
1. **User Pick**: `ImagePicker` (Gallery).
2. **Upload**: `ChatProvider` calls `MediaRepository.uploadToGoogleDrive`.
3. **Storage**: The **raw file** is uploaded to the user's private Google Drive (HTTPS).
4. **Reference**: The implementation encrypts the **Drive File ID** (string) using `EncryptionService.encryptText` before saving to Firestore.
5. **Security Model**: Relies on Google Drive's Access Control + Encrypted Reference ID.

### **33. Write down compression tradeoffs you chose**
- **Images**: `CloudinaryHelper` (for profile) uses strict transformations. Chat images are uploaded as-is (from picker) or compressed depending on implementation tweaks.
- **Audio**: Uploaded as `.m4a`.

### **34. Document media caching strategy**
- **Mechanism**: `LocalStorageHelper.saveImageLocally`.
- **Usage**: `ChatProvider` checks local cache before downloading from Drive.

### **35. Note memory considerations and limits**
- **Thumbs**: `CachedNetworkImage` (if used) generally handles memory cache.
- **Audio**: `JustAudio` streams playback, avoiding full file load into heap if possible.

### **36. Check where you use lazy loading for media**
- **List**: `ListView.builder` in `ChatScreen`.
- **Pagination**: Firestore limits fetching to 20 items.

### **37. Plan and document cleanup of orphaned media**
- **Current**: `ChatRepository.deleteMessage` attempts to delete the Google Drive file (`_mediaRepository.deleteFromGoogleDrive`) and Firebase Storage audio (`storageRef.delete()`).

---

## 🚀 Performance

### **38. List widget rebuild triggers you care about**
- **Keyboard**: `resizeToAvoidBottomInset`.
- **Focus**: `TextFormField` focus changes.
- **Provider**: `notifyListeners()`.

### **39. Audit and add `const` where possible**
- **Practice**: Used for `Text`, `Icon`, and stateless containers to block rebuild propagation.

### **40. Replace heavy `Column` usage with `ListView.builder` where needed**
- **Chat**: `ChatScreen` uses `ListView.builder` (reverse: true).
- **Reason**: Performance O(1) vs O(N) for memory.

### **41. Isolate expensive widgets to reduce rebuild cost**
- **Waves**: `FluidWave` animation (MoodBox) is isolated in a `RepaintBoundary` to prevent full-widget repaints during animation frames.
- **Audio**: `AudioMessageBubble` manages its own playback state.

### **42. Remove unnecessary `setState` calls**
- **Chat Input**: Uses `TextEditingController`. Only calls `setState` when `isComposing` state changes (empty vs non-empty) to toggle Send button.

### **43. Measure performance with DevTools and frame times**
- **Goal**: Maintain 60fps.
- **Heavy Ops**: Decryption (`Chacha20`) is async and off-main-thread (mostly native/FFI via `cryptography` package) to avoid jank.

### **44. Compare behavior across debug, profile, and release modes**
- **Debug**: Checked mode enabled. Slower animations.
- **Release**: AOT compiled. Fast startup.
