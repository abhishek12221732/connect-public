# Detailed Services Documentation

## 🔐 The Encryption Handshake (`EncryptionService`)

The app's security is built on a "Trust-on-First-Auth" model.

### 1. Device Identity Generation
On first launch, the service generates an `X25519` key pair. The **Private Key** is stored in `FlutterSecureStorage` and NEVER leaves the device.

### 2. The Handshake Flow (ECDH)
When two users connect:
1.  **Exchange**: User A and User B upload their **Public Keys** to Firestore (`users/{id}/publicKey`).
2.  **Shared Secret**: User A downloads User B's Public Key. Using their own Private Key, they derive a **Shared Secret** via ECDH.
3.  **Key Wrapping**: User A generates a random **Couple Master Key (CMK)** and encrypts it with the Shared Secret (using HKDF for key derivation and Chacha20 for encryption).
4.  **The "Parcel"**: User A uploads this encrypted CMK (the "parcel") to Firestore.
5.  **Receipt**: User B's device detects the parcel, derives the same Shared Secret using User B's Private Key + User A's Public Key, and decrypts the CMK.

### 3. Data Encryption Specs
- **Symmetric Cipher**: Chacha20-Poly1305 (AEAD).
- **KDF**: HKDF with HMAC-SHA256 for session keys; Argon2id for passphrase-based backups.
- **Key Storage**: `FlutterSecureStorage` (Keychain/Keystore) ensures keys are encrypted at rest on the hardware level.

---

## 🔔 Notification Architecture (`NotificationService`)

The notification system is deeply integrated with the app's business logic.

### FCM Lifecycle
- **Token Sync**: Tokens are refreshed on every login and stored in `users/{id}/fcmTokens` (a list to support multiple devices).
- **Notification Groups**: On Android, we dynamically create `NotificationChannel`s for partners, allowing users to customize alert sounds specifically for their partner.
- **Silent Data Messages**: Some notifications are "Data Only," used to trigger background syncs or update local unread counts without alerting the user.

### Click Handling
The service exposes a static `onNotificationClick` callback used in `main.dart` to navigate via the `navigatorKey`. This ensures that even if the app is in the background, clicking a chat notification takes the user directly to the correct screen.

---

## 🧪 Service Integrity & Error Handling

Each service implements a "Safe-Fail" pattern:
- **Firebase Initialization**: Wrapped in try-catch to allow the app to boot even if configuration is missing (e.g., during local development without `.env`).
- **Secure Storage**: Includes a `hardReset()` option for developer use or account deletion, ensuring no cryptographic residue is left behind.
- **Permission Management**: Bridges with `permission_handler` to gracefully handle denied notification or storage permissions.
