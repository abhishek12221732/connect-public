import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:feelings/features/auth/services/user_repository.dart'; // Import the UserRepository

class CoupleRepository {
  final FirebaseFirestore _firestore;
  final UserRepository _userRepository; // Add a UserRepository instance

  CoupleRepository({FirebaseFirestore? firestore, UserRepository? userRepository})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _userRepository = userRepository ?? UserRepository(); // Initialize UserRepository

  // Create a new couple
  Future<void> createCouple(String user1Id, String user2Id) async {
    // Check if either user is already in a couple
    final user1InCouple = await isUserInCouple(user1Id);
    final user2InCouple = await isUserInCouple(user2Id);
    
    if (user1InCouple && user2InCouple) {
      // Both users are already connected - check if they're connected to each other
      final user1PartnerId = await getPartnerId(user1Id);
      final user2PartnerId = await getPartnerId(user2Id);
      
      if (user1PartnerId == user2Id && user2PartnerId == user1Id) {
        // They're already connected to each other
        throw Exception('You are already connected with this partner');
      } else {
        // Both users are connected to different partners
        throw Exception('Both users are already connected to other partners');
      }
    } else if (user1InCouple) {
      // User1 is already connected to someone else
      throw Exception('You are already connected to another partner');
    } else if (user2InCouple) {
      // User2 is already connected to someone else
      throw Exception('This user is already connected to another partner');
    }
    
    // Neither user is connected, safe to create new couple
    await _firestore.collection('couples').add({
      'user1Id': user1Id,
      'user2Id': user2Id,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // Get a couple where the user is involved
  Future<DocumentSnapshot<Map<String, dynamic>>?> getCoupleByUserId(String userId) async {
    final query = await _firestore
        .collection('couples')
        .where(Filter.or(
          Filter("user1Id", isEqualTo: userId),
          Filter("user2Id", isEqualTo: userId),
        ))
        .limit(1)
        .get();

    return query.docs.isNotEmpty ? query.docs.first : null;
  }

  // Check if a user is in a couple
  Future<bool> isUserInCouple(String userId) async {
  try {
    final coupleDoc = await getCoupleByUserId(userId);
    return coupleDoc != null;
  } catch (e) {
    throw Exception('Failed to check couple connection: $e');
  }
}

  // Get a couple by user ID
  Future<String?> getPartnerId(String userId) async {
  try {
    final coupleDoc = await getCoupleByUserId(userId); // Reuse the existing method
    if (coupleDoc != null) {
      final data = coupleDoc.data();
      if (data?['user1Id'] == userId) {
        return data?['user2Id'] as String?;
      } else if (data?['user2Id'] == userId) {
        return data?['user1Id'] as String?;
      }
    }
  } catch (e) {
    throw Exception('Failed to get partner ID: $e');
  }
  return null;
}
  // New function to get partner's user data
  Future<Map<String, dynamic>?> getPartnerUserData(String currentUserId) async {
    try {
      final partnerId = await getPartnerId(currentUserId);
      if (partnerId != null) {
        return await _userRepository.getUserData(partnerId);
      }
    } catch (e) {
      throw Exception('Failed to get partner user data: $e');
    }
    return null;
  }

  // ✨ **[REWRITTEN]** This is the new, smarter connection logic.
  Future<void> connectUsers(String currentUserId, String partnerId) async {
    // 1. Check if the two users share an existing couple document.
    final existingCouple = await _findCoupleDocumentForUsers(currentUserId, partnerId);

    if (existingCouple != null) {
      final data = existingCouple.data()!;
      final List disconnectedUsers = data['disconnectedUsers'] ?? [];

      // CASE A: They are already actively connected.
      if (disconnectedUsers.isEmpty) {
        throw Exception('You are already connected with this partner');
      }

      // CASE B: The current user had disconnected, but the partner had not. This is a RECONNECTION.
      if (disconnectedUsers.contains(currentUserId) && !disconnectedUsers.contains(partnerId)) {
        await _reactivateCouple(existingCouple.id, currentUserId);
        return; // Success!
      }

      // CASE C: The partner had disconnected, but the current user had not. RECONNECTION.
       if (disconnectedUsers.contains(partnerId) && !disconnectedUsers.contains(currentUserId)) {
        throw Exception('This user must reconnect with you.'); // The other user needs to initiate
      }
    }

    // 2. If no existing couple, check if either user is in ANOTHER active relationship.
final currentUserData = await _userRepository.getUserData(currentUserId);
if (currentUserData?['coupleId'] != null) {
  final inactive = await isCoupleInactive(currentUserData?['coupleId']);
  if (!inactive) {
    throw Exception('You are already in an active relationship with someone else.');
  }
}

final partnerData = await _userRepository.getUserData(partnerId);
if (partnerData?['coupleId'] != null) {
  final inactive = await isCoupleInactive(partnerData?['coupleId']);
  if (!inactive) {
    throw Exception('This user is already in an active relationship with someone else.');
  }
}


    // 3. If both users are free, create a brand new couple.
    await _createNewCouple(currentUserId, partnerId);
  }

  // ✨ **[NEW HELPER]** Reactivates an inactive relationship.
  Future<void> _reactivateCouple(String coupleId, String reconnectingUserId) async {
    final batch = _firestore.batch();

    // Remove the user from the disconnected list
    final coupleRef = _firestore.collection('couples').doc(coupleId);
    batch.update(coupleRef, {
      'disconnectedUsers': FieldValue.arrayRemove([reconnectingUserId])
    });

    // Add the coupleId back to the user's document
    final userRef = _firestore.collection('users').doc(reconnectingUserId);
    batch.update(userRef, {'coupleId': coupleId});

    await batch.commit();
  }


  // ✨ **[NEW HELPER]** Creates a new couple document and links the users.
  Future<void> _createNewCouple(String user1Id, String user2Id) async {
    final coupleRef = await _firestore.collection('couples').add({
      'user1Id': user1Id,
      'user2Id': user2Id,
      'members': [user1Id, user2Id], // Storing members in an array is good for queries
      'disconnectedUsers': [], // Initialize as empty
      'createdAt': FieldValue.serverTimestamp(),
    });

    final coupleId = coupleRef.id;
    final batch = _firestore.batch();
    batch.update(_firestore.collection('users').doc(user1Id), {'coupleId': coupleId});
    batch.update(_firestore.collection('users').doc(user2Id), {'coupleId': coupleId});
    await batch.commit();
  }

  // ✨ **[FIXED]** Finds a couple document containing both users, regardless of status.
// Ensures reconnecting to the previous partner reuses the same document.
Future<DocumentSnapshot<Map<String, dynamic>>?> _findCoupleDocumentForUsers(
    String user1Id,
    String user2Id,
  ) async {

  try {
    // 1. Fetch all couples containing user1
    final querySnapshot = await _firestore
        .collection('couples')
        .where('members', arrayContains: user1Id)
        .get(); // Remove limit(1) to check all possible couples

    // 2. Filter in memory for a document that contains both users
    for (var doc in querySnapshot.docs) {
      final members = List<String>.from(doc.data()['members'] ?? []);
      if (members.contains(user2Id)) {
        return doc; // Found the existing couple
      }
    }

    // 3. No existing couple found
    return null;

  } catch (e) {
    print('Error in _findCoupleDocumentForUsers: $e');
    return null;
  }
}



  // ✨ **[NEW]** Fetches the raw couple document snapshot.
  Future<DocumentSnapshot<Map<String, dynamic>>> getCoupleDocument(String coupleId) async {
    return await _firestore.collection('couples').doc(coupleId).get();
  }

  // ✨ **[NEW]** Performs the "soft disconnect" for the first user.
  Future<void> softDisconnectUser({
    required String coupleId,
    required String userIdToDisconnect,
  }) async {
    final coupleDoc = await getCoupleDocument(coupleId);
    if (!coupleDoc.exists) {
      await _firestore.collection('users').doc(userIdToDisconnect).update({'coupleId': null});
      return;
    }

    final data = coupleDoc.data()!;
    final partnerId = (data['user1Id'] == userIdToDisconnect) ? data['user2Id'] : data['user1Id']; // ✨ [FIXED] Correct field name

    final partnerExists = await _userRepository.checkIfUserExists(partnerId);

    if (!partnerExists) {
      print("Partner ($partnerId) not found. Performing hard delete for couple ($coupleId).");
      await hardDeleteCouple(coupleId: coupleId);
      return;
    }

    final batch = _firestore.batch();
    final coupleRef = _firestore.collection('couples').doc(coupleId);
    batch.update(coupleRef, {'disconnectedUsers': FieldValue.arrayUnion([userIdToDisconnect])});

    final userRef = _firestore.collection('users').doc(userIdToDisconnect);
    batch.update(userRef, {'coupleId': null});
    
    await batch.commit();
  }


  // ✨ **[NEW]** Performs the "hard delete" when the second user disconnects.
  Future<void> hardDeleteCouple({required String coupleId}) async {
    final coupleDoc = await getCoupleDocument(coupleId);
    if (!coupleDoc.exists) return;

    final String user1Id = coupleDoc.data()!['user1Id'];
    final String user2Id = coupleDoc.data()!['user2Id'];

    // 1. Delete all sub-collections first
    await _deleteSubcollection('couples/$coupleId/memories');
    await _deleteSubcollection('couples/$coupleId/sharedJournals');
    
    final batch = _firestore.batch();

    // 2. Delete the main couple document
    batch.delete(_firestore.collection('couples').doc(coupleId));

    // 3. **[FIX]** Check if each user still exists before attempting to update them.
    final user1DocRef = _firestore.collection('users').doc(user1Id);
    final user1Doc = await user1DocRef.get();
    if (user1Doc.exists) {
      batch.update(user1DocRef, {'coupleId': null});
    }

    final user2DocRef = _firestore.collection('users').doc(user2Id);
    final user2Doc = await user2DocRef.get();
    if (user2Doc.exists) {
      batch.update(user2DocRef, {'coupleId': null});
    }

    await batch.commit();
  }

  // Helper method to delete all documents in a sub-collection.
  Future<void> _deleteSubcollection(String collectionPath) async {
    final snapshot = await _firestore.collection(collectionPath).limit(500).get(); // Limit to 500 to stay within batch limits
    if (snapshot.docs.isEmpty) return;

    final batch = _firestore.batch();
    for (var doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();

    // If there might be more than 500 documents, recursively delete
    if (snapshot.docs.length == 500) {
      await _deleteSubcollection(collectionPath);
    }
  }

  // ✨ [NEW METHOD] Checks if a relationship is inactive.
  Future<bool> isCoupleInactive(String coupleId) async {
    try {
      final coupleDoc = await getCoupleDocument(coupleId);
      // A non-existent couple is considered inactive/gone.
      if (!coupleDoc.exists) return true; 

      final List disconnectedUsers = coupleDoc.data()?['disconnectedUsers'] ?? [];
      // The relationship is inactive if ANYONE is in the disconnected list.
      return disconnectedUsers.isNotEmpty;
    } catch (e) {
      print("Error checking couple inactivity: $e");
      return true; // Default to inactive on error to be safe.
    }
  }
}
