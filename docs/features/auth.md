# Feature: Authentication & User Management

The `auth` feature handles user registration, boarding, profile management, and session security.

## 📂 Directory Structure

```text
lib/features/auth/
├── models/         # UserModel definition
├── screens/        # Login, Register, Profile, Change Password screenshots
├── services/       # AuthService (logic) and UserRepository (data)
└── widgets/        # Specialized auth UI components (Form fields, buttons)
```

## 👤 User Model (`UserModel`)

The `UserModel` represents the profile of a user in the system.

- **Core Fields**: `id`, `email`, `name`, `profileImageUrl`.
- **Relationship Fields**: `coupleId` (links to a couple document), `loveLanguage`, `gender`.
- **Status Fields**: `mood`, `moodLastUpdated`, `encryptionStatus` ('pending', 'enabled', 'disabled').
- **Settings**: `notificationsEnabled`, `locationSharingEnabled`.

## ⚙️ Logic Layer (`AuthService`)

A high-level service that interacts directly with `FirebaseAuth` and coordinate with `UserRepository`.

### Core Flow: Register (`register`)
1. Creates a user in `FirebaseAuth` with email/password.
2. If successful, creates a corresponding user document in Firestore via `UserRepository.saveUserData`.
3. Stores the `userId` locally in `SharedPreferences`.

### Core Flow: Google Sign-In (`signInWithGoogle`)
1. Orchestrates the OAuth flow using `google_sign_in`.
2. Exchanges the Google token for a Firebase credential.
3. Automatically completes registration if the user is new.

### Session Cleanup (`logout`)
1. Triggers `FirebaseAuth.instance.signOut()`.
2. Clears local `SharedPreferences`.
3. Calls `EncryptionService.instance.clearSessionKeys()` to ensure sensitive crypto keys are wiped from memory.

---

## 🏗️ Data Layer (`UserRepository`)

Handles all Firestore interactions for user profiles and tokens.

### Key Methods
- **`getUserData(userId, {source})`**: Fetches user profile. Supports `Source.cache` for instant UI and `Source.server` for fresh data.
- **`updateUserMood(userId, mood)`**: Optimistically updates the user's mood in Firestore.
- **`sendPushNotification(...)`**: A helper that sends a request to a server-side endpoint (usually via a Cloud Function bridge) to trigger FCM alerts to the partner.
- **`deleteUserAccount()`**: Securely deletes all user data (Chat, Journals, Profile) by invoking a Cloud Function. This ensures "Cascading Deletion" for privacy compliance.

### FCM Token Management
- **`updateFcmToken(userId)`**: Fetches the current device token and adds it to the user's `fcmTokens` array in Firestore.
- **`refreshFcmToken(userId)`**: Safely removes old tokens and adds the new one, preventing notification duplication.

## 📱 Screens & UI

- **`LoginScreen`**: Simple entry point with email and Google Sign-In options.
- **`RegisterScreen`**: Multi-step flow for email users. Also acts as the "Complete Profile" screen for social sign-in users.
- **`ProfileScreen`**: A heavy screen allowing users to update their photo (via Cloudinary), mood, love language, and account security settings.
- **`OnboardingScreen`**: (in `lib/features/onboarding/`) Used for first-time users to set up their initial profile details.
