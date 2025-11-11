import 'package:flutter/material.dart';
import 'package:feelings/features/connectCouple/repository/couple_repository.dart';
import 'package:feelings/features/auth/services/user_repository.dart';
// ✨ 1. Import RHM Repository
import 'package:feelings/features/rhm/repository/rhm_repository.dart';

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
    _isLoading = true;
    notifyListeners();
    try {
      final couple = await _coupleRepository.getCoupleByUserId(userId);
      if (couple != null && couple.exists) {
        _coupleData = couple.data() as Map<String, dynamic>;
        _coupleId = couple.id;
        final partner = await _coupleRepository.getPartnerUserData(userId);
        _partnerData = partner;
      } else {
        _coupleData = null;
        _partnerData = null;
        _coupleId = null;
      }
    } catch (e) {
      print('Error fetching couple/partner data: $e');
      _coupleData = null;
      _partnerData = null;
      _coupleId = null;
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

  // ✨ RENAMED: from clearCoupleData to clear for consistency.
  void clear() {
    _coupleData = null;
    _partnerData = null;
    _coupleId = null; // ✨ 7. Clear the couple ID
    _isLoading = false;
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