# State Management: Technical Details

## 💾 Caching Strategy: Stale-While-Revalidate

The primary providers (`UserProvider`, `CoupleProvider`) implement a robust caching layer to ensure "Instant App" feel regardless of network speed.

### Flow for `fetchUserData()`:
1.  **Stage 1 (Cache)**: Queries Firestore with `Source.cache`. If data exists, it updates `_userData` and `notifyListeners()` immediately. UI renders instantly.
2.  **Stage 2 (Server)**: Simultaneously triggers a query with `Source.server`.
3.  **Merge**: When the server response returns, it checks for changes. If the data is different, it updates the state and notifies listeners again.
4.  **Secondary Data**: Triggers background tasks like `_cacheProfileImage` only after the primary data is established.

### User-Specific Caching
Image caching (`_cacheProfileImage`) is scoped to `userId`. This prevents "Partner Overlap" when logging between different accounts on the same device. Paths are stored in `SharedPreferences` and physical files in `getApplicationDocumentsDirectory()`.

---

## 💬 Chat Provider: The Messaging Engine

Managing real-time chat with encryption and optimistic UI is handled through several key mechanisms:

### 1. Optimistic Message Merging
When sending a message, the provider creates a `MessageModel` with `isSending: true` and adds it to the local list.
- **Server Sync**: Once Firestore confirms the write, the temporary message is replaced by the official server version via `_mergeWithOptimisticMessages`.
- **ID Stability**: We use a `tempId` generated on the client to track messages during this round-trip.

### 2. Intelligent Decryption
- **Lazy Decryption**: Messages are stored in the `ChatProvider` list as received (encrypted).
- **Automatic Migration**: The `ChatProvider` implements a "Check-on-View" migration. If it encounters a message with `encryptionVersion: null`, it automatically encrypts it with the CMK and updates Firestore.
- **Failure Recovery**: If a message fails decryption (e.g., key sync delay), the UI shows a "Waiting for secure connection" placeholder.

### 3. Engagement Tracking (RHM)
The `ChatProvider` doesn't just manage messages; it manages relationship health.
- **Action Logging**: Every sent message triggers an asynchronous call to `RhmRepository`.
- **Throttling**: To prevent spam, point awards are throttled via internal timers, ensuring points are awarded for meaningful interaction.

---

## 🤝 CoupleProvider: The Connection Hub

The `CoupleProvider` acts as the orchestrator for the partner relationship.

### Key Logic: `auto-handshake`
- **Listener Activity**: On startup, it checks if it has the CMK. If not, it starts `listenForIncomingKey` to wait for a "Key Parcel" from the partner.
- **Public Key Refresh**: It automatically ensures the device's current Public Key is always synced to Firestore, fixing issues where a fresh app install would lead to keys being lost.
- **Soft vs Hard Disconnect**:
    - **Soft**: Removes the connection but preserves the couple document (for 14-day history).
    - **Hard**: Deletes the entire couple document and subcollections (triggered when both users disconnect).
