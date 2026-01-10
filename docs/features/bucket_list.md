# Feature: Bucket List

The `bucket_list` feature allows couples to create and track a shared list of dreams, adventures, and collective goals.

## 📂 Directory Structure

```text
lib/features/bucket_list/
├── repository/     # BucketListRepository (Firestore CRUD)
├── screens/        # BucketListScreen
└── (logic)         # Managed by BucketListProvider (global)
```

## 📝 Collaborative Goals

Bucket list items are stored in `couples/{coupleId}/bucketList`.

- **Ownership**: Each item tracks `createdBy`, allowing users to filter by "Mine," "Partner's," or "Both."
- **Date Idea Integration**: Items can be created directly from the "Discover" section's date ideas. In this case, they carry additional metadata like `dateIdeaId`, `category`, and `whatYoullNeed`.
- **Completion & Sync**: When an item is marked "Done," it can automatically trigger the creation of a `DoneDate` (in the `DoneDatesProvider`), serving as a historical record of the achievement.

## 📈 RHM & Gamification

The Bucket List is tightly integrated with the **Relationship Health Meter (RHM)**:
- **Adding an Item**: Grants **+1 point** (limited by frequency once every 7 days per couple).
- **Completing an Item**: Grants **+5 points** (significant reward for achieving shared goals).

## ⚙️ Logic & State (`BucketListProvider`)

The provider manages:
- **Real-time Streaming**: Listens to the Firestore collection for live updates.
- **Persistence**: Remembers the user's preferred sort (Alpha vs. Date) and filter settings using `SharedPreferences`.
- **Search**: Implements a client-side search across the list.
- **Optimistic UI**: Reflects completion toggles immediately while the background write completes.

## 🎨 UI Components

- **`BucketListTile`**: Displays the item title, author, and completion status with custom animations.
- **`BucketListPreview`**: (Found in Discover) A condensed version of the list for quick access.
