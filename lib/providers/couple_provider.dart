import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // ✨ Add this import
import 'package:feelings/features/connectCouple/repository/couple_repository.dart';
import 'package:feelings/features/auth/services/user_repository.dart';
// ✨ 1. Import RHM Repository
import 'package:feelings/features/rhm/repository/rhm_repository.dart';
import 'package:feelings/services/encryption_service.dart';
import 'dart:async';

class CoupleProvider extends ChangeNotifier {
  final CoupleRepository _coupleRepository;
  final RhmRepository _rhmRepository; // ✨ 2. Add RHM Repository
  final UserRepository _userRepository = UserRepository();

  Map<String, dynamic>? _coupleData;
  Map<String, dynamic>? _partnerData;
  String? _coupleId; // ✨ 3. Add state for coupleId
  bool _isLoading = false;

  // ✨ 4. Update Constructor
  CoupleProvider({
    required CoupleRepository coupleRepository,
    required RhmRepository rhmRepository,
  })  : _coupleRepository = coupleRepository,
        _rhmRepository = rhmRepository;

  Map<String, dynamic>? get coupleData => _coupleData;
  Map<String, dynamic>? get partnerData => _partnerData;
  String? get coupleId => _coupleId; // ✨ Add getter
  bool get isLoading => _isLoading;
  StreamSubscription? _keySubscription;

  void listenForIncomingKey(String userId) {
    if (_coupleId == null) return;
    
    // If I already have the key, don't listen
    if (EncryptionService.instance.isReady) return;

    _keySubscription?.cancel();
    _keySubscription = _coupleRepository.listenForIncomingKey(_coupleId!, userId).listen((snapshot) async {
      if (snapshot.exists && snapshot.data() != null) {
        debugPrint("🔐 [Receiver] Found an encrypted key parcel!");
        final data = snapshot.data() as Map<String, dynamic>;
        
        // We need the partner's public key to decrypt/verify sender
        final partnerId = _partnerData?['userId'];
        if (partnerId != null) {
          final partnerPubKey = await _coupleRepository.getPartnerPublicKey(partnerId);
          if (partnerPubKey != null) {
             await EncryptionService.instance.decryptAndSaveMasterKey(_coupleId!, partnerPubKey, data);
             _keySubscription?.cancel(); // Done!
             notifyListeners(); // Update UI if showing "Waiting for secure connection..."
          }
        }
      }
    });
  }
  
  // Add to dispose/clear
  // _keySubscription?.cancel();

  /// Connects the current user with a partner using their unique code.
  Future<void> connectWithPartnerCode(String currentUserId, String partnerCode, String currentUserName) async {
    try {
      final partnerId = await _userRepository.getUserIdByCoupleCode(partnerCode);
      if (partnerId == null) {
        throw Exception('No user found with that code');
      }

      final currentUserData = await _userRepository.getUserData(currentUserId);
      if (currentUserData?['coupleId'] != null) {
        final inactive = await _coupleRepository.isCoupleInactive(currentUserData?['coupleId']);
        if (!inactive) {
          throw Exception('You are already in an active relationship with someone else.');
        }
      }

      final partnerData = await _userRepository.getUserData(partnerId);
      if (partnerData?['coupleId'] != null) {
        final inactive = await _coupleRepository.isCoupleInactive(partnerData?['coupleId']);
        if (!inactive) {
          throw Exception('This user is already in an active relationship with someone else.');
        }
      }

      // --- Connection happens ---
      await _coupleRepository.connectUsers(currentUserId, partnerId);
      final myPublicKey = await EncryptionService.instance.getDevicePublicKey();
      await _coupleRepository.uploadDevicePublicKey(currentUserId, myPublicKey);
      // Fetch new couple data, which will now set _coupleId
      await _fetchCoupleData(currentUserId);
      await fetchPartnerUserData(currentUserId);
      // --- Connection finished ---

      // ✨ 5. ADD RHM LOGIC
      if (_coupleId != null) {
        try {
          // Log 10 points for each user for this major action
          await _rhmRepository.logAction(
            coupleId: _coupleId!,
            userId: currentUserId,
            actionType: 'partner_connected',
            points: 25,
          );
          await _rhmRepository.logAction(
            coupleId: _coupleId!,
            userId: partnerId,
            actionType: 'partner_connected',
            points: 25,
          );
        } catch (e) {
          // Don't fail the connect if RHM fails, just log it
          debugPrint("Error logging RHM action for partner_connected: $e");
        }
      }
      // --- END RHM LOGIC ---

      try {
        await _userRepository.sendPushNotification(
          partnerId,
          "$currentUserName has connected with you as their partner!",
          partnerName: "New Connection!", // This will be the notification title
        );
      } catch (e) {
        debugPrint("Error sending connection notification: $e");
        // Don't fail the connect if notification fails
      }
      // ✨ --- END OF ADDED BLOCK ---
      try {
        await _userRepository.sendConnectionUpdate(partnerId);
      } catch (e) {
        debugPrint("Error sending connection *update*: $e");
      }

      notifyListeners();

    } catch (e) {
      print('Error connecting with partner code: $e');
      rethrow;
    }
  }

  // Fetch and store couple data based on a user's ID
  Future<void> _fetchCoupleData(String userId) async {
    try {
      final couple = await _coupleRepository.getCoupleByUserId(userId);
      if (couple != null && couple.exists) {
        _coupleData = couple.data();
        _coupleId = couple.id; // ✨ 6. Store the couple ID
        
        // ✨ VALIDATE ENCRYPTION VERSION
        if (_coupleData != null && _coupleData!['encryptionVersion'] == null) {
           // If we are ready, mark the couple as V1 (meaning new structure)
           // This is a lazy migration of the couple document itself.
           if (EncryptionService.instance.isReady) {
              debugPrint("ℹ️ [Couple] lazy-updating encryptionVersion to 1.");
              _coupleRepository.updateCoupleField(_coupleId!, 'encryptionVersion', 1);
           }
        }
        
      } else {
        _coupleData = null;
        _coupleId = null; // ✨ Clear the couple ID
      }
      notifyListeners();
    } catch (e) {
      print('Error fetching couple data: $e');
      rethrow;
    }
  }

  // Fetch partner's user data and store in local state
  Future<void> fetchPartnerUserData(String userId) async {
    try {
      final partner = await _coupleRepository.getPartnerUserData(userId);
      _partnerData = partner;
      notifyListeners();
    } catch (e) {
      print('Error fetching partner user data: $e');
      rethrow;
    }
  }

  Future<void> fetchCoupleAndPartnerData(String userId) async {
    // ✨ SET LOADING
    if (!_isLoading) {
       _isLoading = true;
       notifyListeners();
    }
    
    // --- ⚡ STAGE 1: CACHE FIRST ---
    try {
        final couple = await _coupleRepository.getCoupleByUserId(userId, source: Source.cache);
        if (couple != null && couple.exists) {
           _coupleData = couple.data() as Map<String, dynamic>;
           _coupleId = couple.id;
           // If we got the couple from cache, try getting partner from cache too.
           final partner = await _coupleRepository.getPartnerUserData(userId, source: Source.cache);
           _partnerData = partner;
           
           if (_partnerData != null) {
              debugPrint("⚡ [CoupleProvider] Loaded Couple & Partner Data from CACHE.");
              
              // Key Loading (Cached)
               if (_coupleId != null) {
                 await EncryptionService.instance.loadMasterKey(_coupleId!);
               }
               
              // 🚀 SHOW UI NOW
              _isLoading = false;
              notifyListeners();
           }
        }
    } catch (e) {
       debugPrint("⚠️ [CoupleProvider] Cache miss or error: $e");
    }

    // --- 🌐 STAGE 2: FRESH SERVER DATA ---
    try {
      debugPrint("🌐 [CoupleProvider] Fetching FRESH Couple Data from Server...");
      
      // 1. Fetch Data
      final couple = await _coupleRepository.getCoupleByUserId(userId, source: Source.server);
      
      if (couple != null && couple.exists) {
        _coupleData = couple.data() as Map<String, dynamic>;
        _coupleId = couple.id;
        final partner = await _coupleRepository.getPartnerUserData(userId, source: Source.server);
        _partnerData = partner;
        
        // ✨ ROBUSTNESS FIX: ALWAYS Upload My Public Key on Startup
        // This fixes the issue where reinstalling the app locks you out.
        try {
           final myPublicKey = await EncryptionService.instance.getDevicePublicKey();
           await _coupleRepository.uploadDevicePublicKey(userId, myPublicKey);
        } catch (e) {
           debugPrint("⚠️ [Handshake] Failed to refresh Public Key: $e");
        }

        // ✨ AUTO-HANDSHAKE LOGIC
        if (_coupleId != null) {
          bool iHaveKey = await EncryptionService.instance.loadMasterKey(_coupleId!);
          
          if (iHaveKey) {
            await checkAndSyncKeys(userId);
          } else {
            listenForIncomingKey(userId);
          }
        }

      } else {
        _coupleData = null;
        _partnerData = null;
        _coupleId = null;
      }
    } catch (e) {
      print('Error fetching couple/partner data: $e');
      if (_coupleData == null) {
         // Only clear if we didn't show cache
         _coupleData = null;
         _partnerData = null;
         _coupleId = null;
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }



  // A helper for the UI to know which dialog to show.
  Future<bool> isFirstToDisconnect(String coupleId) async {
    // ... (no change)
    final coupleDoc = await _coupleRepository.getCoupleDocument(coupleId);
    if (!coupleDoc.exists) return true; // Default to safe option
    final List disconnectedUsers = coupleDoc.data()?['disconnectedUsers'] ?? [];
    return disconnectedUsers.isEmpty;
  }

  // The single method the UI will call to perform the entire disconnect operation.
    Future<void> disconnectFromPartner({
    required String currentUserId,
    required String coupleId,
    required String senderName,
  }) async {
    // ... (no change)
    try {
      final coupleDoc = await _coupleRepository.getCoupleDocument(coupleId);
      if (!coupleDoc.exists) {
        throw Exception('Couple document not found.');
      }
      final coupleData = coupleDoc.data()!;
      final List disconnectedUsers = coupleData['disconnectedUsers'] ?? [];
      final isFirst = disconnectedUsers.isEmpty;

      if (isFirst) {
        // --- This is a SOFT DISCONNECT ---
        final String user1Id = coupleData['user1Id'];
        final String user2Id = coupleData['user2Id'];
        final String partnerId = currentUserId == user1Id ? user2Id : user1Id; // Corrected logic

        final message = '$senderName has disconnected from your couple.';
        await _userRepository.sendPushNotification(partnerId, message);

        await _coupleRepository.softDisconnectUser(
          coupleId: coupleId,
          userIdToDisconnect: currentUserId,
        );
      } else {
        // --- This is a HARD DELETE ---
        await _coupleRepository.hardDeleteCouple(coupleId: coupleId);
      }
      
      clear(); // Clear local state after disconnection
      notifyListeners();
    } catch (e) {
      print('Error in disconnectFromPartner: $e');
      rethrow;
    }
  }

  // Checks if a relationship is inactive.
  Future<bool> isRelationshipInactive(String coupleId) async {
    if (_coupleId == null) {
      debugPrint('[CoupleProvider] isRelationshipInactive called after logout. Aborting check.');
      return true;
    }
    try {
      final coupleDoc = await _coupleRepository.getCoupleDocument(coupleId);
      if (!coupleDoc.exists) return true;
      final List disconnectedUsers = coupleDoc.data()?['disconnectedUsers'] ?? [];
      return disconnectedUsers.isNotEmpty;
    } catch (e) {
      print('Error checking relationship status: $e');
      return true;
    }
  }
  /// Checks if encryption keys need to be synced between partners
  Future<void> checkAndSyncKeys(String currentUserId) async {
    if (_coupleId == null) return;
    if (!EncryptionService.instance.isReady) return; // I don't have the key yet, can't share it

    // 1. Get Partner ID
    final partnerId = _partnerData?['userId'];
    if (partnerId == null) return;

    // 2. Check if partner already has the key (optimization)
    // You could store a 'keyShared: true' flag in Firestore to avoid checking every time.
    // For now, we will just try to fetch their public key and send it if we haven't recently.

    try {
      // 3. Get Partner's Public Key
      final partnerPubKey = await _coupleRepository.getPartnerPublicKey(partnerId);
      
      if (partnerPubKey != null) {
        // 4. Encrypt CMK for them
        debugPrint("🔐 [Sync] Found partner public key, encrypting CMK...");
        final encryptedParcel = await EncryptionService.instance.encryptMasterKeyForPartner(partnerPubKey);
        
  /// 5. Upload
        await _coupleRepository.uploadEncryptedKeyForPartner(_coupleId!, partnerId, encryptedParcel);
        debugPrint("🔐 [Sync] Sent encrypted CMK to partner!");
      } else {
        debugPrint("🔐 [Sync] Partner has no public key yet. Waiting...");
      }
    } catch (e) {
      debugPrint("⚠️ [Sync] Key sync failed: $e");
    }
  }

  /// ✨ EMERGENCY FIX: Regenerate Master Key
  /// Call this when encryption is irrevocably lost to restore functionality for NEW messages.
  Future<void> regenerateMasterKey() async {
    if (_coupleId == null) return;
    try {
      debugPrint("⚠️ [Encryption] REGENERATING MASTER KEY...");
      await EncryptionService.instance.generateAndSaveMasterKey(_coupleId!);
      
      // Immediately sync with partner so they get the new key
      final currentUserId = _userRepository.currentUser?.uid;
      if (currentUserId != null) {
        await checkAndSyncKeys(currentUserId);
      }
      notifyListeners();
      debugPrint("✅ [Encryption] Master Key Regenerated & Synced.");
    } catch (e) {
      debugPrint("❌ [Encryption] Regeneration failed: $e");
    }
  }

  // ✨ RENAMED: from clearCoupleData to clear for consistency.
  void clear() {
    _coupleData = null;
    _partnerData = null;
    _coupleId = null; // ✨ 7. Clear the couple ID
    _isLoading = false;
    _keySubscription?.cancel();
    // notifyListeners();
    print("[CoupleProvider] Cleared and reset state.");
  }

  // ✨ ADDED: dispose method for proper cleanup.
  @override
  void dispose() {
    clear();
    super.dispose();
  }
}