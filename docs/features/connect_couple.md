# Feature: Couple Connection

The `connectCouple` feature manages the unique lifecycle of a relationship inside the app, from the initial invitation to account separation.

## 📂 Directory Structure

```text
lib/features/connectCouple/
├── repository/     # CoupleRepository (Lifecycle logic)
└── screens/        # Connection screens (Invite/Accept)
```

## 💍 Relationship Lifecycle

The `CoupleRepository` handles four main states:

1. **Invitation**: One user generates a connection code (their `userId`).
2. **Connection**: The partner enters the code. `connectUsers` creates a shared document in the `couples` collection.
3. **Reactivation**: If a couple was previously disconnected but rejoins, the system can "reactivate" the old document to preserve history.
4. **Separation**: 
   - **Soft Disconnect**: Marks the relationship as inactive but preserves data.
   - **Hard Delete**: Calls a cascading deletion process to remove all shared bucket lists, journals, and chat history.

## 🔗 The Glue System

The `CoupleRepository` acts as the primary coordinator for the **Key Handshake**:
- It provides the transport layer for `EncryptionService` to exchange public keys and encrypted master keys.
- It manages shared relational metadata like "Anniversary Date" and "Connection Status."
