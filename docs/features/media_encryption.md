# Feature: Media Management

The `media` system handles the diverse storage needs of the "Feelings" app, balancing public accessibility for profiles with strict privacy for shared memories.

## 📂 Directory Structure

```text
lib/features/media/
├── services/       # GoogleDriveHelper, LocalStorageHelper
└── ...
(Auth features)
└── services/       # CloudinaryHelper
```

## ☁️ Public Storage (`CloudinaryHelper`)

Used for non-sensitive, public-facing assets like profile pictures:
- **Direct Upload**: Uploads images to Cloudinary via signed/unsigned presets.
- **Optimization**: Images are automatically transformed and resized by Cloudinary for performance.

## 🔒 Private Storage (`GoogleDriveHelper`)

Used for sensitive, End-to-End Encrypted (E2EE) media (from Chat and Secret Notes):
- **User-Owned**: Media is stored in the user's personal Google Drive, not on the "Feelings" server.
- **Authentication**: Requires Google Sign-In with `driveFileScope` permission.
- **E2EE Integration**: Files are encrypted locally before upload and decrypted on-the-fly after download.
- **Web Fallback**: Implements a rotation of CORS proxies (e.g., `allorigins`) to allow web-based clients to fetch images from Google Drive API without CORS constraints.

---

# Feature: Encryption Flow (UI)

While the `EncryptionService` handles the math, the `encryption` feature folder manages the user experience of securing the relationship.

## 🤝 Key Handshake

When a couple connects, the `EncryptionSetupDialog` orchestrates the multi-step handshake:
1. **Identity Generation**: Each device generates an `X25519` key pair.
2. **Public Key Exchange**: Partners exchange public keys via Firestore (`CoupleRepository`).
3. **Master Key Creation**: The "initiator" generates the Couple Master Key (CMK).
4. **CMK Transfer**: The CMK is encrypted with the partner's public key and shared securely.

## 🛡️ Backup & Recovery

- **Passphrase Backup**: Users are prompted to set a passphrase which, combined with `Argon2id`, is used to encrypt a backup of the CMK to Firestore. This allows recovery if a device is lost.
- **Security Bubble**: The `EncryptionStatusBubble` provides persistent visual feedback on the home screen/chat ensuring the connection is "Verified & Secure."
