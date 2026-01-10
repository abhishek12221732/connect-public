# Feature: App Configuration & Status

The `app_config` feature provides a global control plane for the application, allowing the development team to manage maintenance windows and send urgent system notifications.

## 📂 Directory Structure

```text
lib/features/app_config/
├── models/         # AppStatusModel
└── services/       # AppConfigService
```

## 🌐 Global Status Monitoring (`AppConfigService`)

The `AppConfigService` maintains a real-time connection to a singleFirestore document: `app_config/status`.

- **Maintenance Mode**: If `isBlocking` is true, the app can prevent users from proceeding to the dashboard, displaying a global maintenance message instead.
- **Alert System**: Can push a non-blocking `message` (e.g., "New feature update incoming!") to a banner on the home screen.
- **Reactive UI**: The service uses the `ChangeNotifier` pattern, allowing any widget in the app to react instantly to environment changes.

## ⚙️ Integration

The `AppConfigService` is usually initialized in `main.dart` or via a global MultiProvider, ensuring it is active from the moment the app boots.
