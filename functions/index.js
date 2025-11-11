const admin = require("firebase-admin");
const cloudinary = require("cloudinary").v2;
const { onCall } = require("firebase-functions/v2/https");
const { defineString } = require("firebase-functions/params");
const { onSchedule } = require("firebase-functions/v2/scheduler");


admin.initializeApp();
const db = admin.firestore();


// ✅ Your existing Cloudinary config - NO CHANGES NEEDED
const CLOUDINARY_CLOUD_NAME = defineString("CLOUDINARY_CLOUD_NAME");
const CLOUDINARY_API_KEY = defineString("CLOUDINARY_API_KEY");
const CLOUDINARY_API_SECRET = defineString("CLOUDINARY_API_SECRET");

cloudinary.config({
  cloud_name: CLOUDINARY_CLOUD_NAME.value(),
  api_key: CLOUDINARY_API_KEY.value(),
  api_secret: CLOUDINARY_API_SECRET.value(),
  secure: true,
});

// ✨ --- NEW FUNCTION: Generates a signature for secure Cloudinary uploads --- ✨
exports.generateCloudinarySignature = onCall(async (request) => {
  if (!request.auth) {
    throw new Error("User not authenticated.");
  }

  const publicId = request.data.publicId;
  const folder = request.data.folder; // Get the folder from the request

  if (!publicId || !folder) {
    throw new Error("Missing publicId or folder parameters.");
  }

  const timestamp = Math.round((new Date()).getTime() / 1000);

  // Generate the signature with ALL the signed parameters
  const signature = cloudinary.utils.api_sign_request(
    {
      public_id: publicId,
      timestamp: timestamp,
      upload_preset: "unsigned_uploads",
      folder: folder, // ✨ ADD THIS LINE
    },
    cloudinary.config().api_secret,
  );

  return {
    signature: signature,
    timestamp: timestamp,
    api_key: cloudinary.config().api_key,
  };
});


// 🔧 Helper: Recursively delete documents in a collection (No change needed)
const deleteCollection = async (db, collectionPath, batchSize = 50) => {
  const collectionRef = db.collection(collectionPath);
  const query = collectionRef.orderBy("__name__").limit(batchSize);

  return new Promise((resolve, reject) => {
    deleteQueryBatch(db, query, resolve).catch(reject);
  });
};

const deleteQueryBatch = async (db, query, resolve) => {
  const snapshot = await query.get();
  if (snapshot.size === 0) {
    resolve();
    return;
  }

  const batch = db.batch();
  snapshot.docs.forEach((doc) => batch.delete(doc.ref));
  await batch.commit();

  process.nextTick(() => {
    deleteQueryBatch(db, query, resolve);
  });
};

// 🔥 Delete Cloudinary Image (Updated to v2 - No change needed)
exports.deleteCloudinaryImage = onCall({
    timeoutSeconds: 120,
    memory: "256MiB",
  },
  async (request) => {
    if (!request.auth) {
      throw new Error("User not authenticated.");
    }

    const publicId = request.data.publicId;
    if (!publicId || typeof publicId !== "string") {
      throw new Error("Invalid or missing publicId.");
    }

    try {
      const result = await cloudinary.uploader.destroy(publicId, { resource_type: "image" });
      if (result.result === "ok" || result.result === "not found") {
        return { success: true, message: `Image ${publicId} deleted.` };
      } else {
        console.error("Cloudinary failed to delete image:", result);
        throw new Error("Cloudinary failed to delete image.");
      }
    } catch (error) {
      console.error("Cloudinary deletion error:", error);
      throw new Error("Cloudinary internal error.");
    }
  }
);

// 🧹 Delete User Account and Data (Updated to v2 - No change needed)
exports.deleteUserAccount = onCall({
    timeoutSeconds: 540,
    memory: "512MiB",
  },
  async (request) => {
    if (!request.auth) {
      throw new Error("User not authenticated.");
    }

    const uid = request.auth.uid;
    const db = admin.firestore();

    try {
      const userDocRef = db.collection("users").doc(uid);
      const userDoc = await userDocRef.get();

      if (!userDoc.exists) {
        await admin.auth().deleteUser(uid);
        return { success: true, message: "Auth user deleted." };
      }

      const { coupleId, profileImageUrl, coupleCode } = userDoc.data();

      // 🔗 Handle couple data
      if (coupleId) {
        const coupleDocRef = db.collection("couples").doc(coupleId);
        const coupleDoc = await coupleDocRef.get();
        if (coupleDoc.exists) {
          const coupleData = coupleDoc.data();
          const partnerId = coupleData.user1Id === uid ? coupleData.user2Id : coupleData.user1Id;
          const partnerDoc = await db.collection("users").doc(partnerId).get();

          if (!partnerDoc.exists) {
            const chatId = [uid, partnerId].sort().join("_");
            await deleteCollection(db, `chats/${chatId}/messages`);
            await deleteCollection(db, `chats/${chatId}/typingStatus`);
            await db.collection("chats").doc(chatId).delete();
            await deleteCollection(db, `couples/${coupleId}/memories`);
            await deleteCollection(db, `couples/${coupleId}/sharedJournals`);
            await coupleDocRef.delete();
          } else {
            await coupleDocRef.update({
              disconnectedUsers: admin.firestore.FieldValue.arrayUnion(uid),
            });
          }
        }
      }

      // 🖼 Delete Cloudinary profile image
      if (profileImageUrl && profileImageUrl.includes("res.cloudinary.com")) {
        try {
          const urlParts = profileImageUrl.split("/");
          const uploadIndex = urlParts.indexOf("upload");
          if (uploadIndex !== -1 && urlParts.length > uploadIndex + 2) {
            const publicIdWithExt = urlParts.slice(uploadIndex + 2).join("/");
            const publicId = publicIdWithExt.substring(0, publicIdWithExt.lastIndexOf("."));
            await cloudinary.uploader.destroy(publicId, { resource_type: "image" });
          }
        } catch (e) {
          console.error("Cloudinary profile deletion failed:", e);
        }
      }

      // 🏷 Remove couple code registry if it belongs to this user
      if (coupleCode) {
        try {
          const ccRef = db.collection('coupleCodes').doc(coupleCode);
          const ccSnap = await ccRef.get();
          if (ccSnap.exists) {
            const ccData = ccSnap.data();
            if (ccData && ccData.userId === uid) {
              await ccRef.delete();
              console.log(`Removed coupleCodes/${coupleCode} owned by ${uid}`);
            } else {
              console.log(`coupleCodes/${coupleCode} does not belong to ${uid}; skipping delete.`);
            }
          }
        } catch (e) {
          console.error('Failed to remove coupleCode doc:', e);
        }
      }

      // 🧾 Delete user-related collections
      await deleteCollection(db, `users/${uid}/personalJournals`);
      await deleteCollection(db, `users/${uid}/check_ins`);

      if (coupleCode) {
        await db.collection("coupleCodes").doc(coupleCode).delete();
      }

      // 🗑 Delete user document and auth user
      await userDocRef.delete();
      await admin.auth().deleteUser(uid);

      return { success: true, message: "Account deleted successfully." };
    } catch (error) {
      console.error("Account deletion failed:", error);
      throw new Error("Failed to delete account.");
    }
  }
);


exports.checkRhmScores = onSchedule({
  schedule: "every day 09:00",
  timeZone: "Asia/Kolkata", // ✨ Changed from America/New_York
}, async (event) => {
  console.log("Running daily RHM score check...");

  const couplesSnapshot = await db.collection("couples").get();

  for (const coupleDoc of couplesSnapshot.docs) {
    const coupleId = coupleDoc.id;
    const coupleData = coupleDoc.data();

    // ✨ Using 'user1Id' and 'user2Id' based on your 'deleteUserAccount' function
    const userA = coupleData.user1Id;
    const userB = coupleData.user2Id;

    if (!userA || !userB) {
      console.warn(`Couple ${coupleId} is missing user IDs. Skipping.`);
      continue; // Skip this couple if one user is missing
    }

    // 1. Calculate the RHM score
    const score = await calculateRhmScore(coupleId);

    // 2. Check if the score is below the threshold
    const LOW_SCORE_THRESHOLD = 40; // "Needs Nurturing"
    if (score < LOW_SCORE_THRESHOLD) {
      console.log(`Couple ${coupleId} has low score: ${score}. Sending notification.`);
      
      // 3. Send notifications to both users
      await sendLowScoreNotification(userA, score);
      await sendLowScoreNotification(userB, score);
    }
  }
  console.log("RHM score check complete.");
});

/**
 * Helper to calculate the RHM score for a couple.
 * This logic MUST match your client-side logic in rhm_repository.dart
 */
async function calculateRhmScore(coupleId) {
  const cutoff = new Date();
  cutoff.setDate(cutoff.getDate() - 7); // 7 days ago

  const actionsSnapshot = await db
    .collection("couples")
    .doc(coupleId)
    .collection("rhm_actions")
    .where("createdAt", ">", admin.firestore.Timestamp.fromDate(cutoff))
    .get();

  let activityPoints = 0;
  for (const doc of actionsSnapshot.docs) {
    activityPoints += (doc.data().points) || 0; // Get points, default to 0
  }

  // --- THIS MUST MATCH YOUR REPOSITORY ---
  const targetPoints = 75.0;
  let calculatedScore = (activityPoints / targetPoints) * 100.0;
  if (calculatedScore > 100) calculatedScore = 100;
  if (calculatedScore < 0) calculatedScore = 0;
  
  return Math.floor(calculatedScore);
}

/**
 * Helper to fetch a user's FCM token and send them a notification.
 */
async function sendLowScoreNotification(userId, score) {
  if (!userId) return;

  // 1. Get the user's document to find their FCM token
  const userDoc = await db.collection("users").doc(userId).get();
  if (!userDoc.exists) {
    console.warn(`User ${userId} not found, cannot send notification.`);
    return;
  }

  const fcmToken = userDoc.data()?.fcmToken;
  if (!fcmToken) {
    console.log(`User ${userId} has no FCM token. Skipping.`);
    return;
  }

  // 2. Define the notification payload
  const payload = {
    notification: {
      title: "Reconnect with your partner ❤️",
      body: `Your relationship health score is ${score}%. Why not start a conversation or suggest a date night?`,
    },
    token: fcmToken,
  };

  // 3. Send the message
  try {
    await admin.messaging().send(payload);
    console.log(`Successfully sent notification to user ${userId}`);
  } catch (error) {
    console.error(`Error sending notification to user ${userId}:`, error);
    // You might want to remove invalid tokens here if they are unregistered
  }
}
