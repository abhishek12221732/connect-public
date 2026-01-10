# Feature: User Onboarding

The `onboarding` feature is the "first mile" experience for new users, guiding them through identity setup, email verification, and the critical step of connecting with a partner.

## 📂 Directory Structure

```text
lib/features/onboarding/
└── onboarding_screen.dart  # The 1400+ line multi-step orchestrator
```

## 🛠️ The Onboarding Flow

The onboarding process is a multi-page experience managed by a `PageController`:

1.  **Welcome**: Introduction to the "Feelings" concept.
2.  **Email Verification**: Forces users to verify their email before proceeding. Uses a real-time polling timer (`Timer.periodic`) to check the Firebase Auth state.
3.  **Basic Profile**: 
    - **Name & Photo**: Integrated with `CloudinaryHelper` for immediate profil image hosting.
    - **Identity**: Selection of Gender and Love Language.
4.  **Partner Connection**:
    - **Generate Code**: Generates a random invite code for the user to share.
    - **Accept Code**: Allows the user to enter a partner's code or scan a QR code.
    - **Real-time Confirmation**: Uses `CoupleProvider` to verify the connection.
5.  **Relational Context**: Optional setup for shared location (Distance-based tips).

## ⚙️ Logic & Transitions

- **Success Transition**: Once the final `_completeOnboarding()` method is called, the user document is marked with `onboardingCompleted: true` and the app navigates to the Home screen (/bottom_nav).
- **Graceful Failures**: Includes extensive error handling for network timeouts, verification delays, and invalid connection codes.
