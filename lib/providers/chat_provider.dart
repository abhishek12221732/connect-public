// lib/providers/chat_provider.dart

import 'dart:async';
import 'dart:io'; // Make sure this is imported
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart'; // ✨ Import for SchedulerBinding
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:feelings/features/media/repository/media_repository.dart';
import 'package:feelings/features/media/services/local_storage_helper.dart';
import 'package:feelings/features/chat/repositories/chat_repository.dart';
import 'package:feelings/features/chat/models/message_model.dart';
import 'package:feelings/features/auth/services/user_repository.dart';
import 'package:feelings/services/notification_services.dart';
import 'dynamic_actions_provider.dart';
import 'package:feelings/features/rhm/repository/rhm_repository.dart';
import 'package:just_audio/just_audio.dart'; // ✨ Import
import 'package:feelings/services/encryption_service.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:collection/collection.dart'; // ✨ Import for firstWhereOrNull

class ChatProvider with ChangeNotifier {
  final DynamicActionsProvider _dynamicActionsProvider;
  final ChatRepository _chatRepository;
  final UserRepository _userRepository;
  final RhmRepository _rhmRepository;
  final AudioPlayer _audioPlayer = AudioPlayer();

  // ✨ ADD MediaRepository
  final MediaRepository _mediaRepository = MediaRepository();

  List<MessageModel> _messages = [];
  bool _isPartnerTyping = false;
  List<MessageModel> _filteredMessages = [];
  bool _isLoadingMessages = false;
  bool _isSearching = false;
  String _currentSearchQuery = '';
  StreamSubscription? _messagesSubscription;
  StreamSubscription? _typingSubscription;
  DocumentSnapshot? _lastFetchedDoc;
  bool _hasMoreMessages = true;
  bool get hasMoreMessages => _hasMoreMessages;

  Timer? _typingHeartbeatTimer;
  String? _currentTypingUserId;
  String? _currentTypingPartnerId;

  MessageModel? _replyingToMessage;
  MessageModel? get replyingToMessage => _replyingToMessage;

  int _unsyncedMessageCount = 0;
  Timer? _rhmSyncTimer;
  String? _currentChatUserId;
  String? _currentChatPartnerId;

  static const Duration editWindow = Duration(minutes: 15);
  MessageModel? _editingMessage;
  MessageModel? get editingMessage => _editingMessage;
  Timer? _seenDebounceTimer;
  final List<String> _messagesToMarkAsSeen = [];
  
  StreamSubscription? _keyWaitSub; // ✨ Added for encryption key listener
  
  // ✨ RELIABILITY FIX: Use ValueNotifier for direct updates
  final ValueNotifier<List<MessageModel>> messagesNotifier = ValueNotifier([]);


  // Add this getter if you want to show a specific "Waiting for secure connection..." UI
  bool get isWaitingForKey => _isWaitingForKey;
  bool _isWaitingForKey = false;




  // ✨ ADD THIS to track the image being sent
  final Map<String, MessageModel> _optimisticMessages = {};
  Map<String, MessageModel> get optimisticMessages => _optimisticMessages;

  int get unreadMessageCount {
    if (_currentChatPartnerId == null) return 0;
    return _messages
        .where((msg) =>
            msg.senderId == _currentChatPartnerId && msg.status != 'seen')
        .length;
  }

  void setReplyingTo(MessageModel? message) {
    _replyingToMessage = message;
    notifyListeners();
  }

  void cancelReply() {
    _replyingToMessage = null;
    notifyListeners();
  }

  // ✨ NEW: Helper to merge server messages with optimistic ones
  List<MessageModel> _mergeWithOptimisticMessages(
      List<MessageModel> serverMessages) {
    // addLog("Merging. Server: ${serverMessages.length}, Opt: ${_optimisticMessages.length}");
    // 1. Create a mutable copy of server messages
    final merged = List<MessageModel>.from(serverMessages);

    // 2. Identify optimistic messages that have been confirmed by the server
    final List<String> confirmedOptimisticIds = [];
    _optimisticMessages.forEach((tempId, optimisticMsg) {
      final serverMatch = serverMessages.firstWhereOrNull(
        (serverMsg) => serverMsg.id == optimisticMsg.id || // Direct match
                      (serverMsg.senderId == optimisticMsg.senderId &&
                       serverMsg.messageType == optimisticMsg.messageType &&
                       serverMsg.timestamp.difference(optimisticMsg.timestamp).inSeconds.abs() < 20 &&
                       (serverMsg.content == optimisticMsg.content || serverMsg.googleDriveImageId == optimisticMsg.googleDriveImageId)),
      );
      if (serverMatch != null) {
        confirmedOptimisticIds.add(tempId);
      }
    });

    // 3. Remove confirmed optimistic messages from our _optimisticMessages map
    confirmedOptimisticIds.forEach(_optimisticMessages.remove);

    // 4. Add any remaining optimistic messages (those still pending) to the merged list
    // These will appear at the top if sorted by timestamp, as they are newer.
    merged.addAll(_optimisticMessages.values);

    // 5. Sort by timestamp (newest first)
    merged.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return merged;
  }

  List<MessageModel> get messages =>
      _isSearching ? _filteredMessages : _messages;
  List<MessageModel> get filteredMessages => _filteredMessages;
  bool get isLoadingMessages => _isLoadingMessages;
  bool get isPartnerTyping => _isPartnerTyping;
  bool get isSearching => _isSearching;
  String get currentSearchQuery => _currentSearchQuery;

  ChatProvider(
    this._dynamicActionsProvider, {
    required RhmRepository rhmRepository,
    required ChatRepository chatRepository,
  })  : _rhmRepository = rhmRepository,
        _chatRepository = chatRepository,
        _userRepository = UserRepository() {
     debugPrint("ChatProvider CREATED! Hash: $hashCode");
  }

  Future<void> loadMessages(String userId, String partnerId) async {
    if (_isLoadingMessages) return;
    _isLoadingMessages = true;
    notifyListeners();
    try {} catch (e) {
      debugPrint('Error loading messages: $e');
    } finally {
      _isLoadingMessages = false;
      notifyListeners();
    }
  }

  /// Listen to real-time messages from Firestore
  void listenToMessages(String userId, String partnerId) async {
    debugPrint("🔍 [ChatProvider] listenToMessages called for user: $userId, partner: $partnerId");

    // ✨ Prevent duplicate subscriptions for the same pair
    if (_currentChatUserId == userId && _currentChatPartnerId == partnerId && _messagesSubscription != null) {
      debugPrint("ℹ️ [ChatProvider] Already listening for this pair. Skipping.");
      return;
    }

    _currentChatUserId = userId;
    _currentChatPartnerId = partnerId;

    // 1. ALWAYS listen for Key Readiness to auto-retry decryption
    // This handles cases where key becomes ready LATER or was ready NOW.
    _keyWaitSub?.cancel();
    _keyWaitSub = EncryptionService.instance.onKeyReady.listen((isReady) {
      debugPrint("🔍 [ChatProvider] onKeyReady event: $isReady");
      
      if (isReady) {
        // If we were waiting, or even if we weren't, verify decryption.
        if (_isWaitingForKey) {
           debugPrint("✅ [ChatProvider] Key became ready! Triggering full re-decryption.");
           _isWaitingForKey = false;
           // Provide immediate feedback to UI if needed, though _reDecryptAllMessages calls notifyListeners
           notifyListeners(); 
        } else {
           debugPrint("ℹ️ [ChatProvider] Key ready event received (already active).");
        }
        
        // Always try to re-decrypt to clear any "Waiting..." placeholders
        _reDecryptAllMessages();
      } else {
        debugPrint("⚠️ [ChatProvider] Key became UNAVAILABLE.");
        _isWaitingForKey = true;
        notifyListeners();
      }
    });

    // 2. Initial State Check (Sync immediately)
    if (!EncryptionService.instance.isReady) {
      debugPrint("⏳ [ChatProvider] Key NOT ready initially. UI will show placeholders.");
      _isWaitingForKey = true;
    } else {
      // debugPrint("✅ [ChatProvider] Key IS ready initially.");
      _isWaitingForKey = false;
    }
    // Don't notify listeners yet, let the stream start first to avoid double paint
    // notifyListeners();

    // 3. Start Firestore Stream IMMEDIATELY (Do not await key)
    // This ensures messages load even if key is delayed.
    // They will just show "Waiting..." until the listener above fires.


    _messagesSubscription?.cancel();

    _currentChatUserId = userId;
    _currentChatPartnerId = partnerId;

    // Listen to real-time updates
    _messagesSubscription = _chatRepository.listenToMessages(
      userId, 
      partnerId,
      (serverMessages) async {

        if (serverMessages.isEmpty) {
          _messages = _mergeWithOptimisticMessages([]);
          _isLoadingMessages = false;
          notifyListeners();
          return;
        }

        // 1. FIRST PASS: Show what we have IMMEDIATELY (even if encrypted)
        // This ensures the UI is snappy and "Message Not Appearing" bug is impossible.
        final List<MessageModel> rawMergedList = [];
        
        for (var msg in serverMessages) {
             MessageModel tempMsg = msg;
             
             // Preserve local paths
             final existingIndex = _messages.indexWhere((m) => m.id == msg.id);
             if (existingIndex != -1) {
               final existing = _messages[existingIndex];
               if (existing.localAudioPath != null) {
                  tempMsg = tempMsg.copyWith(localAudioPath: existing.localAudioPath);
               }
               if (existing.localImagePath != null) {
                  tempMsg = tempMsg.copyWith(localImagePath: existing.localImagePath);
               }
             }
             rawMergedList.add(tempMsg);
        }

       // Update UI NOW with raw messages
        _messages = _mergeWithOptimisticMessages(rawMergedList);
        _isLoadingMessages = false;
        notifyListeners(); // ⚡ FORCE PAINT

        // 2. SECOND PASS: Decrypt in background
        // We iterate on the LOCAL _messages list to ensure we update what's on screen
        bool needsUpdate = false;
        final List<MessageModel> decryptedList = [];

        for (var msg in _messages) {
            MessageModel tempMsg = msg;
             if (tempMsg.encryptionVersion == 1) {
                 try {
                   final decryptedString = await tempMsg.getDecryptedContent();
                   if (tempMsg.messageType == 'text') {
                      tempMsg = tempMsg.copyWith(content: decryptedString);
                      needsUpdate = true;
                   } else if (tempMsg.messageType == 'image') {
                      tempMsg = tempMsg.copyWith(googleDriveImageId: decryptedString);
                      needsUpdate = true;
                   }
                   // Mark as Plaintext so we don't re-decrypt
                   // tempMsg = tempMsg.copyWith(encryptionVersion: null); 
                 } catch (e) {
                   debugPrint("Failed to decrypt message ${tempMsg.id}: $e");
                 }
             }
             decryptedList.add(tempMsg);
        }

        if (needsUpdate) {
           _messages = decryptedList; // No need to re-merge, just swap
           notifyListeners(); // ⚡ PAINT DECRYPTED TEXT
        }
      },
    ); // ✨ Close the listenToMessages call
  }



  void queueMessageAsSeen(String userId, String partnerId, String messageId) {
    // Only queue if it's not already 'seen' and not already in the queue
    final index = _messages.indexWhere((m) => m.id == messageId);
    if (index != -1 &&
        _messages[index].status != 'seen' &&
        !_messagesToMarkAsSeen.contains(messageId)) {
      _messagesToMarkAsSeen.add(messageId);

      _seenDebounceTimer?.cancel();
      _seenDebounceTimer = Timer(const Duration(milliseconds: 300), () {
        _flushSeenMessages(userId, partnerId);
      });
    }
  }


  // ✨ --- ADD NEW METHOD: sendVoiceMessage --- ✨
  Future<void> sendVoiceMessage(
    String senderId,
    String receiverId,
    File audioFile, {
    required String senderName,
    required String partnerName,
    bool isEncryptionEnabled = false,
  }) async {
    final messageToReplyTo = _replyingToMessage;
    String? finalRepliedToSenderName;
    if (messageToReplyTo != null) {
      finalRepliedToSenderName =
          messageToReplyTo.senderId == senderId ? senderName : partnerName;
    }

    // 1. Get audio duration
    // We must load it into a player briefly to get its duration.
    double? durationInSeconds;
    try {
      final duration = await _audioPlayer.setFilePath(audioFile.path);
      durationInSeconds = (duration?.inMilliseconds.toDouble() ?? 0.0) / 1000.0;
    } catch (e) {
      debugPrint("Error getting audio duration: $e");
      durationInSeconds = 0.0; // Fallback
    }

    // 2. Create optimistic message
    final tempId = 'optimistic_audio_${DateTime.now().millisecondsSinceEpoch}';
    final newMessage = MessageModel(
      id: tempId,
      senderId: senderId,
      receiverId: receiverId,
      content: '', // No text content for a voice message
      timestamp: DateTime.now(),
      status: 'unsent',
      participants: [senderId, receiverId],
      repliedToMessageId: messageToReplyTo?.id,
      repliedToMessageContent: messageToReplyTo?.content,
      repliedToSenderName: finalRepliedToSenderName,
      repliedToSenderId: messageToReplyTo?.senderId,
      repliedToMessageType: messageToReplyTo?.messageType,
      repliedToImageUrl: messageToReplyTo?.googleDriveImageId,
      messageType: 'voice',
      localAudioPath: audioFile.path,
      audioDuration: durationInSeconds,
      uploadStatus: 'uploading',
    );

    // 3. Add to UI optimistically
    _optimisticMessages[tempId] = newMessage;
    // ✨ FIX: Immutable update
    _messages = [newMessage, ..._messages];
    _messages.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    if (_isSearching) _applySearchFilter(_currentSearchQuery);
    
    cancelReply();
    notifyListeners();

    // 4. Start background upload
    _uploadAndSendVoiceMessage(
      tempId: tempId,
      newMessage: newMessage,
      audioFile: audioFile,
      senderId: senderId,
      receiverId: receiverId,
      senderName: senderName,

      receiverIdForNotif: receiverId,
      isEncryptionEnabled: isEncryptionEnabled,
    );
  }

  // ✨ --- NEW METHOD: Resend Expired/Missing Audio --- ✨
  Future<void> resendExpiredAudio({
    required MessageModel message,
    required File audioFile,
    bool isEncryptionEnabled = false,
  }) async {
    try {
      debugPrint("🔄 [ChatProvider] Resending expired voice message: ${message.id}");

      // 1. Upload & Encrypt (Reuse existing secure logic)
       final uploadResult = await _chatRepository.uploadSecureAudio(
         audioFile, message.senderId, message.receiverId, message.id,
         isEncryptionEnabled: isEncryptionEnabled,
       );
       
       // 2. Update the EXISTING message document with new metadata
       await _chatRepository.updateMessageAudioData(
         message.senderId, 
         message.receiverId, 
         message.id,
         audioUrl: uploadResult['url']!,
         audioGlobalOtk: uploadResult['audioGlobalOtk'],
         audioNonce: uploadResult['audioNonce'],
         audioEncryptionVersion: uploadResult['audioEncryptionVersion'] != null 
             ? int.tryParse(uploadResult['audioEncryptionVersion']!) 
             : null,
         audioOtkNonce: uploadResult['audioOtkNonce'],
         audioOtkMac: uploadResult['audioOtkMac'],
       );

       debugPrint("✅ [ChatProvider] Message restored successfully.");
       
    } catch (e) {
      debugPrint("❌ [ChatProvider] Resend failed: $e");
      rethrow;
    }
  }

  // ✨ --- ADD NEW METHOD: _uploadAndSendVoiceMessage --- ✨
  Future<void> _uploadAndSendVoiceMessage({
    required String tempId,
    required MessageModel newMessage,
    required File audioFile,
    required String senderId,
    required String receiverId,
    required String senderName,

    required String receiverIdForNotif,
    required bool isEncryptionEnabled,
  }) async {
    try {
      // 1. Upload & Encrypt (handled by repository)
       final uploadResult = await _chatRepository.uploadSecureAudio(
         audioFile, senderId, receiverId, tempId,
         isEncryptionEnabled: isEncryptionEnabled,
       );
       
       String audioUrl = uploadResult['url']!;
       
       // Metadata is already encrypted by the repository if encryption was ready
       String? audioGlobalOtk = uploadResult['audioGlobalOtk'];
       String? audioNonce = uploadResult['audioNonce'];
       String? audioOtkNonce = uploadResult['audioOtkNonce'];
       String? audioOtkMac = uploadResult['audioOtkMac'];
       int? audioEncryptionVersion = uploadResult['audioEncryptionVersion'] != null 
           ? int.tryParse(uploadResult['audioEncryptionVersion']!) 
           : null;

      // 2. Send the REAL message data to Firestore
      await _chatRepository.sendMessage(
        senderId,
        receiverId,
        audioNonce ?? '', // Store file nonce in content for backward compatibility if needed, or just leave empty
        repliedToMessageId: newMessage.repliedToMessageId,
        repliedToMessageContent: newMessage.repliedToMessageContent,
        repliedToSenderName: newMessage.repliedToSenderName,
        repliedToSenderId: newMessage.repliedToSenderId,
        repliedToMessageType: newMessage.repliedToMessageType,
        repliedToImageUrl: newMessage.repliedToImageUrl,
        messageType: 'voice',
        audioDuration: newMessage.audioDuration,
         
        // Pass encrypted audio metadata
        audioUrl: audioUrl,
        audioGlobalOtk: audioGlobalOtk,
        audioNonce: audioNonce,
        audioEncryptionVersion: audioEncryptionVersion,
        audioOtkNonce: audioOtkNonce,

        audioOtkMac: audioOtkMac,
        isEncryptionEnabled: isEncryptionEnabled,
    );


      // 3. Update optimistic message to 'success'
      if (_optimisticMessages.containsKey(tempId)) {
  // 1. Update the message in our tracking map
  final updatedOptimisticMessage = _optimisticMessages[tempId]!.copyWith(
    uploadStatus: 'success',
    audioUrl: audioUrl,
    status : 'sent',
  );
  _optimisticMessages[tempId] = updatedOptimisticMessage;

  // 2. Find the message in the main UI list and replace it
  final mainIndex = _messages.indexWhere((m) => m.id == tempId);
  if (mainIndex != -1) {
    // ✨ FIX: Replace the old message with the fully updated one,
    // which correctly preserves the localAudioPath.
    // Immutable update
    final updatedList = List<MessageModel>.from(_messages);
    updatedList[mainIndex] = updatedOptimisticMessage;
    _messages = updatedList;
    notifyListeners();
  }
}

      // 4. Handle notifications & RHM logic
      _dynamicActionsProvider.recordMessageSent();
      _unsyncedMessageCount++;
      _startRhmSyncTimer();

      // ✨ FIXED: Now properly awaited with retry logic
      await _sendNotificationWithRetry(
        receiverId: receiverIdForNotif,
        message: "🎤 Voice Message",
        senderName: senderName,
      );


    } catch (e) {
      debugPrint('Error sending voice message: $e');
      // 5. Mark optimistic message as 'failed'
      if (_optimisticMessages.containsKey(tempId)) {
        _optimisticMessages[tempId] = _optimisticMessages[tempId]!.copyWith(uploadStatus: 'failed', status: 'failed');
        
        // ✨ FIX: Find the index again because we are in a different scope (catch block)
        final mainIndex = _messages.indexWhere((m) => m.id == tempId);
        
        if (mainIndex != -1) {
          // ✨ FIX: Immutable update
          final updatedList = List<MessageModel>.from(_messages);
          updatedList[mainIndex] = updatedList[mainIndex].copyWith(uploadStatus: 'failed', status: 'failed');
          _messages = updatedList;
          notifyListeners();
        }
      }
    }
  }

  /// Downloads and decrypts an audio file to a local temporary path
  Future<String> prepareAudioFile(MessageModel msg) async {
    // 1. Check for PREVIOUSLY DECRYPTED file (Cached)
    final tempDir = await getTemporaryDirectory();
    final decryptedFile = File('${tempDir.path}/${msg.id}_dec.m4a');
    
    if (await decryptedFile.exists()) {
      return decryptedFile.path;
    }

    // 2. Check for ORIGINAL RECORDING (Sent by me)
    // IMPORTANT: Only return this if it's the sender and the file actually exists on disk.
    // This relies on listenToMessages correctly preserving the localAudioPath.
    if (msg.localAudioPath != null) {
      final originalFile = File(msg.localAudioPath!);
      if (await originalFile.exists()) {
        return originalFile.path;
      }
    }

    // 3. Download & Decrypt
    try {
      if (msg.audioUrl == null) throw Exception("Audio URL is null");
      
      // debugPrint("⬇️ [Audio] Downloading from: ${msg.audioUrl}");
      final response = await http.get(Uri.parse(msg.audioUrl!));
      
      if (response.statusCode != 200) {
        throw Exception("Download failed with status: ${response.statusCode}");
      }
      
      final encryptedBytes = response.bodyBytes;
      List<int> playableBytes = encryptedBytes;

      // 4. Decrypt (if needed)
      // 4. Decrypt (if needed)
      // Check for Audio Encryption Version OR fallback to standard version 1
      if (msg.audioEncryptionVersion == 1 || (msg.encryptionVersion == 1 && msg.messageType == 'voice')) {
         
         String? encryptedOtk = msg.audioGlobalOtk;
         String? otkNonce = msg.audioOtkNonce;
         String? otkMac = msg.audioOtkMac;
         String? fileNonce = msg.audioNonce;

         // Fallback for legacy "broken" messages (if any were partially working) or old logic
         if (encryptedOtk == null && msg.ciphertext != null) {
            encryptedOtk = msg.ciphertext;
            otkNonce = msg.nonce;
            otkMac = msg.mac;
            fileNonce = msg.content; // In old logic, fileNonce was stored in content
         }

         if (encryptedOtk == null || otkNonce == null || otkMac == null || fileNonce == null) {
           debugPrint("⚠️ [Audio] Encryption metadata missing. Playing as-is.");
         } else {
           // debugPrint("🔐 [Audio] Decrypting audio...");
           
           // 1. Decrypt the OTK using the CMK
           final otkBase64 = await EncryptionService.instance.decryptText(
             encryptedOtk, otkNonce, otkMac
           );
           
           // 2. Decrypt the file using the OTK
           playableBytes = await EncryptionService.instance.decryptFile(
             encryptedBytes, 
             fileNonce, 
             otkBase64
           );
         }
      }

      // 5. Save to temp file
      if (playableBytes.isEmpty) throw Exception("Decryption resulted in empty file");
      
      await decryptedFile.writeAsBytes(playableBytes);
      debugPrint("✅ [Audio] Saved ready-to-play file: ${decryptedFile.path}");
      return decryptedFile.path;

    } catch (e) {
      debugPrint("❌ [Audio] Prep failed: $e");
      rethrow;
    }
  }



  Future<void> _flushSeenMessages(String userId, String partnerId) async {
    if (_messagesToMarkAsSeen.isEmpty) return;

    final List<String> messageIdsToMark = List.from(_messagesToMarkAsSeen);
    _messagesToMarkAsSeen.clear();

    bool needsNotify = false;
    // ✨ FIX: Immutable Update
    // We create a new list and update it
    final updatedList = List<MessageModel>.from(_messages);
    
    for (int i = 0; i < updatedList.length; i++) {
        final msg = updatedList[i];
        if (messageIdsToMark.contains(msg.id)) {
            updatedList[i] = msg.copyWith(status: 'seen');
            needsNotify = true;
        }
    }

    if (needsNotify) {
      _messages = updatedList; // Assign new list
      notifyListeners();
      await _chatRepository.markBatchMessagesAsSeen(
          userId, partnerId, messageIdsToMark);

      for (final messageId in messageIdsToMark) {
        await NotificationService.dismissNotificationForMessage(messageId);
      }
    }
  }

  Future<void> markMessageAsSeen(
      String userId, String partnerId, String messageId) async {
    try {
      final index = _messages.indexWhere((m) => m.id == messageId);
      if (index != -1 && _messages[index].status != 'seen') {
        // ✨ FIX: Immutable Update
        final updatedList = List<MessageModel>.from(_messages);
        updatedList[index] = updatedList[index].copyWith(status: 'seen');
        _messages = updatedList;
        notifyListeners();
        
        await _chatRepository.markSingleMessageAsSeen(
            userId, partnerId, messageId);

        await NotificationService.dismissNotificationForMessage(messageId);
      }
      // Redundant call removed or kept if necessary for race conditions
      await _chatRepository.markSingleMessageAsSeen(
          userId, partnerId, messageId);
    } catch (e) {
      debugPrint('Error marking single message as seen: $e');
    }
  }

  void startEditing(MessageModel message, String currentUserId) {
    if (canEditMessage(message, currentUserId)) {
      _editingMessage = message;
      notifyListeners();
    }
  }

  void cancelEditing() {
    _editingMessage = null;
    notifyListeners();
  }

  bool canEditMessage(MessageModel message, String currentUserId) {
    if (message.senderId != currentUserId) return false;
    final diff = DateTime.now().difference(message.timestamp);
    return diff <= editWindow;
  }

  Future<void> commitEdit(
    String userId,
    String partnerId,
    String newContent,
  ) async {
    final editing = _editingMessage;
    if (editing == null) return;
    if (!canEditMessage(editing, userId)) {
      _editingMessage = null;
      notifyListeners();
      return;
    }

    final idx = _messages.indexWhere((m) => m.id == editing.id);
    if (idx != -1) {
      final updated = editing.copyWith(
        content: newContent.trim(),
        editedAt: DateTime.now(),
        editCount: (editing.editCount ?? 0) + 1,
      );
      // ✨ FIX: Immutable Update
      final updatedList = List<MessageModel>.from(_messages);
      updatedList[idx] = updated;
      _messages = updatedList;
      
      _filteredMessages =
          List.from(_isSearching ? _filteredMessages : _messages);
      notifyListeners();
    }

    _editingMessage = null;
    notifyListeners();

    try {
      await _chatRepository.editMessage(
        userId,
        partnerId,
        editing.id,
        newContent.trim(),
        nextEditCount: (editing.editCount ?? 0) + 1,
      );
    } catch (e) {
      debugPrint('Error editing message: $e');
    }
  }

  /// Complete function to send text, images, or both.
  /// Uses Google Drive for image uploads.
  Future<void> sendMessage(
    String senderId,
    String receiverId,
    String content, {
    // 'content' is the caption
    required String senderName,
    required String partnerName,
    String? messageText, // for notifications
    File? imageFile, // ✨ The file to upload
    bool isEncryptionEnabled = false, // ✨ NEW: Respect User Preference
  }) async {

    try {
      // 1. Check if there is content to send
      if (content.trim().isEmpty && imageFile == null) return;
  
      final messageToReplyTo = _replyingToMessage;
      String? finalRepliedToSenderName;
      if (messageToReplyTo != null) {
        finalRepliedToSenderName =
            messageToReplyTo.senderId == senderId ? senderName : partnerName;
      }
      final tempId = 'optimistic_${DateTime.now().millisecondsSinceEpoch}';
  
      // 2. ✨ Create an optimistic local message
      final newMessage = MessageModel(
        id: tempId,
        senderId: senderId,
        receiverId: receiverId,
        content: content.trim(),
        timestamp: DateTime.now(),
        status: 'unsent', // CORRECT: Always unsent initially until server confirms
        participants: [senderId, receiverId],
        repliedToMessageId: messageToReplyTo?.id,
        repliedToMessageContent: messageToReplyTo?.content,
        repliedToSenderName: finalRepliedToSenderName,
        repliedToSenderId: messageToReplyTo?.senderId,
        repliedToMessageType: messageToReplyTo?.messageType, // ✨ Add this
        repliedToImageUrl: messageToReplyTo?.googleDriveImageId, // ✨ Add this
        messageType: imageFile != null ? 'image' : 'text',
        localImagePath: imageFile?.path,
        uploadStatus: imageFile != null ? 'uploading' : null, // ✨ SET STATUS
        encryptionVersion: isEncryptionEnabled ? 1 : null, // ✨ OPTIMISTIC LOCK ICON
      );
  
      _optimisticMessages[tempId] = newMessage;
      // addLog("sendMessage: Added optimistic msg to map");

      // ✨ FIX: Create a new list reference to ensure UI updates
      _messages = [newMessage, ..._messages];
      _messages.sort((a, b) => b.timestamp.compareTo(a.timestamp)); // Re-sort
      if (_isSearching) _applySearchFilter(_currentSearchQuery);
      
      cancelReply();
      // addLog("sendMessage: Notifying listeners (MsgCount: ${_messages.length})");
      notifyListeners();
  
      // 4. Actual Network Call (Background)
      // addLog("sendMessage: Triggering uploadAndSend");
      _uploadAndSend(
        tempId: tempId,
        newMessage: newMessage,
        imageFile: imageFile,
        senderId: senderId,
        receiverId: receiverId,
        content: content.trim(),
        // Pass other fields...
        repliedToMessageId: messageToReplyTo?.id,
        repliedToMessageContent: messageToReplyTo?.content,
        repliedToSenderName: finalRepliedToSenderName,
        repliedToSenderId: messageToReplyTo?.senderId,
        repliedToMessageType: messageToReplyTo?.messageType, // ✨ Add this
        repliedToImageUrl: messageToReplyTo?.googleDriveImageId, // ✨ Add this
        // Notification fields
        senderName: senderName,
        receiverIdForNotif: receiverId,
        messageTextForNotif: messageText,
        isEncryptionEnabled: isEncryptionEnabled,
      );
    } catch (e, stack) {
      // addLog("sendMessage ERROR: $e");
      debugPrint("Error sending message: $e");
    }
  }

  Future<void> _uploadAndSend({
    required String tempId,
    required MessageModel newMessage,
    required File? imageFile,
    required String senderId,
    required String receiverId,
    required String content,
    String? repliedToMessageId,
    String? repliedToMessageContent,
    String? repliedToSenderName,
    String? repliedToSenderId,
    String? repliedToMessageType, // ✨ Add to signature
    String? repliedToImageUrl, // ✨ Add to signature
    required String senderName,
    required String receiverIdForNotif,
    String? messageTextForNotif,
    required bool isEncryptionEnabled,
  }) async {
    try {
      String? finalImageId;

      if (imageFile != null) {
        debugPrint("[ChatProvider] Uploading image to Google Drive...");
        finalImageId = await _mediaRepository.uploadToGoogleDrive(
          imageFile,
          (progress) {
            debugPrint('[ChatProvider] Image Upload Progress: $progress');
          },
        );
        if (finalImageId == null) {
          throw Exception('Image upload failed, Google Drive ID was null.');
        }
        await LocalStorageHelper.saveImageLocally(imageFile, finalImageId);
      }

      // 5. ✨ Send the REAL message data to Firestore
      await _chatRepository.sendMessage(
        senderId,
        receiverId,
        content,
        repliedToMessageId: repliedToMessageId,
        repliedToMessageContent: repliedToMessageContent,
        repliedToSenderName: repliedToSenderName,
        repliedToSenderId: repliedToSenderId,
        repliedToMessageType: repliedToMessageType, // ✨ Pass to repository
        repliedToImageUrl: repliedToImageUrl, // ✨ Pass to repository
        messageType: imageFile != null ? 'image' : 'text',
        googleDriveImageId: finalImageId,
        isEncryptionEnabled: isEncryptionEnabled,
      );

      // 6. ✨ Update optimistic message to 'success'
      // We also add the GDrive ID for the bubble to use
      if (_optimisticMessages.containsKey(tempId)) {
        _optimisticMessages[tempId] = _optimisticMessages[tempId]!.copyWith(
          uploadStatus: 'success',
          googleDriveImageId: finalImageId,
          status : 'sent',
        );
        // We find it in the *main* list to update the UI
        // We find it in the *main* list to update the UI
        final mainIndex = _messages.indexWhere((m) => m.id == tempId);
        if (mainIndex != -1) {
          // ✨ FIX: Immutable update
          final updatedList = List<MessageModel>.from(_messages);
          updatedList[mainIndex] = updatedList[mainIndex].copyWith(
            uploadStatus: 'success',
            googleDriveImageId: finalImageId,
            status: 'sent',
          );
          _messages = updatedList;
          notifyListeners();
        }
      }
      
      // 7. Handle RHM logic and notifications
      _dynamicActionsProvider.recordMessageSent();
      _unsyncedMessageCount++;
      _startRhmSyncTimer();

      // ✨ FIXED: Now properly awaited with retry logic
      await _sendNotificationWithRetry(
        receiverId: receiverIdForNotif,
        message: imageFile != null ? "📷 Image" : content,
        senderName: senderName,
        messageText: messageTextForNotif,
      );


    } catch (e) {
      debugPrint('Error sending message: $e');
      // 8. ✨ Mark the optimistic message as 'failed'

      if (e is GoogleAuthCancelledException || e.toString().contains("GoogleAuthCancelledException")) {
        debugPrint("[ChatProvider] Upload cancelled by user. removing bubble.");
        
        // 1. Remove from optimistic tracking
        if (_optimisticMessages.containsKey(tempId)) {
          _optimisticMessages.remove(tempId);
        }
        
        // 2. Remove from the UI list completely
        final updatedList = List<MessageModel>.from(_messages);
        updatedList.removeWhere((m) => m.id == tempId);
        _messages = updatedList;
        
        // 3. Update UI and Stop
        notifyListeners();
        return; 
      }

      if (_optimisticMessages.containsKey(tempId)) {
        _optimisticMessages[tempId] = _optimisticMessages[tempId]!
            .copyWith(uploadStatus: 'failed', status: 'failed');
        // We find it in the *main* list to update the UI
        // We find it in the *main* list to update the UI
        final mainIndex = _messages.indexWhere((m) => m.id == tempId);
        if (mainIndex != -1) {
          // ✨ FIX: Immutable update
          final updatedList = List<MessageModel>.from(_messages);
          updatedList[mainIndex] = updatedList[mainIndex].copyWith(
             uploadStatus: 'failed', 
             status: 'failed'
          );
          _messages = updatedList;
          notifyListeners();
        }
      }
    }
  }

  // --- ✨ NEW HELPER METHODS FOR RHM BATCHING ---
  // (Your existing functions: _startRhmSyncTimer, _syncRhmPoints)
  void _startRhmSyncTimer() {
    _rhmSyncTimer?.cancel();
    _rhmSyncTimer = Timer(const Duration(minutes: 1), _syncRhmPoints);
  }

  Future<void> _syncRhmPoints() async {
    _rhmSyncTimer = null;
    if (_unsyncedMessageCount == 0 ||
        _currentChatUserId == null ||
        _currentChatPartnerId == null) {
      return;
    }
    _unsyncedMessageCount = 0;
    int pointsToAdd = 1;
    try {
      final coupleId = await _userRepository.getCoupleId(_currentChatUserId!);
      if (coupleId == null) {
        debugPrint(
            "[ChatProvider] No coupleId found for user ${_currentChatUserId}");
        return;
      }
      final lastActionTime =
          await _rhmRepository.getLastActionTimestampForUser(
        coupleId,
        _currentChatUserId!,
        'chat_message_sent',
      );
      if (lastActionTime == null ||
          DateTime.now().difference(lastActionTime) >
              const Duration(hours: 6)) {
        await _rhmRepository.logAction(
          coupleId: coupleId,
          userId: _currentChatUserId!,
          actionType: 'chat_message_sent',
          points: pointsToAdd,
        );
      }
    } catch (e) {
      debugPrint("[ChatProvider] Error in _syncRhmPoints: $e");
    }
  }

  void updateTypingStatus(String userId, String partnerId, bool isTyping) {
    try {
      _chatRepository.updateTypingStatus(userId, partnerId, isTyping);
      if (isTyping) {
        _currentTypingUserId = userId;
        _currentTypingPartnerId = partnerId;
        _typingHeartbeatTimer?.cancel();
        _typingHeartbeatTimer = Timer(const Duration(seconds: 30), () {
          if (_currentTypingUserId == userId &&
              _currentTypingPartnerId == partnerId) {
            _chatRepository.updateTypingStatus(userId, partnerId, false);
            _currentTypingUserId = null;
            _currentTypingPartnerId = null;
          }
        });
      } else {
        _typingHeartbeatTimer?.cancel();
        _currentTypingUserId = null;
        _currentTypingPartnerId = null;
      }
    } catch (e) {
      debugPrint('Error updating typing status: $e');
    }
  }

  void listenToTypingStatus(String userId, String partnerId) {
    _typingSubscription?.cancel();
    _typingSubscription = _chatRepository.listenToTypingStatus(userId, partnerId,
      (isTyping) {
        if (FirebaseAuth.instance.currentUser == null) {
          debugPrint(
              "[ChatProvider] Typing event received, but user is logged out. Ignoring.");
          return;
        }
        if (_isPartnerTyping != isTyping) {
          _isPartnerTyping = isTyping;
          notifyListeners();
        }
      },
      onError: (error) {
        if (error is FirebaseException &&
            error.code == 'permission-denied') {
          if (FirebaseAuth.instance.currentUser == null) {
            debugPrint(
                "[ChatProvider] Safely caught permission-denied on typing listener during logout.");
          } else {
            debugPrint(
                "[ChatProvider] CRITICAL TYPING PERMISSION ERROR: $error");
          }
        } else {
          debugPrint("[ChatProvider] Unexpected typing error: $error");
        }
      },
    );
  }

  Future<void> deleteMessage(String chatId, MessageModel message) async { // ✨ Updated signature
    try {
      // Optimistically remove from UI
      // ✨ FIX: Immutable update
      final updatedList = List<MessageModel>.from(_messages);
      updatedList.removeWhere((m) => m.id == message.id);
      _messages = updatedList;

      if (_isSearching) {
        _applySearchFilter(_currentSearchQuery);
      } else {
        _filteredMessages = List.from(_messages);
      }
      notifyListeners();

      // ✨ Pass the whole message object to the repository
      await _chatRepository.deleteMessage(chatId, message);
    } catch (e) {
      debugPrint('Error deleting message: $e');
      // TODO: Consider re-inserting the message into the list if deletion fails
      rethrow;
    }
  }

  void searchMessages(String query) {
    _currentSearchQuery = query;
    if (query.isEmpty) {
      _isSearching = false;
      _filteredMessages = List.from(_messages);
    } else {
      _isSearching = true;
      _applySearchFilter(query);
    }
    notifyListeners();
  }

  void clearSearch() {
    _isSearching = false;
    _currentSearchQuery = '';
    _filteredMessages = List.from(_messages);
    notifyListeners();
  }

  void _applySearchFilter(String query) {
    if (query.isEmpty) {
      _filteredMessages = List.from(_messages);
      return;
    }
    _filteredMessages = _messages
        .where((msg) => msg.content.toLowerCase().contains(query.toLowerCase()))
        .toList();
  }

  @override
  void notifyListeners() {
    // Sync ValueNotifier for direct listeners
    messagesNotifier.value = List.from(_messages); 
    super.notifyListeners();
  }

  Future<void> fetchInitialMessages(String userId, String partnerId,
      {int limit = 20}) async {
    _isLoadingMessages = true;
    notifyListeners();
    try {
      final result = await _chatRepository.fetchMessagesBatch(userId, partnerId,
          limit: limit);
      final List<MessageModel> messagesRaw = result['messages'] ?? [];
      final List<MessageModel> messages = [];

      // ✨ Decrypt & Migrate Initial Batch
      for (var msg in messagesRaw) {
        // 1. Decrypt
        final decryptedMsg = await _decryptMessage(msg);
        messages.add(decryptedMsg);
        
        // 2. Migrate (if needed)
        _maybeMigrateMessage(userId, partnerId, decryptedMsg);
      }

      _lastFetchedDoc = result['lastDoc'];
      final Map<String, MessageModel> uniqueMessages = {
        for (var m in messages) m.id: m
      };
      _messages = uniqueMessages.values.toList();
      _messages.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      _filteredMessages = List.from(_messages);
      _hasMoreMessages = messages.length == limit;
    } catch (e) {
      debugPrint('Error fetching initial messages: $e');
    } finally {
      _isLoadingMessages = false;
      notifyListeners();
    }
  }

  Future<void> fetchMoreMessages(String userId, String partnerId,
      {int limit = 20}) async {
    if (!_hasMoreMessages || _isLoadingMessages) return;
    _isLoadingMessages = true;
    notifyListeners();
    try {
      final result = await _chatRepository.fetchMessagesBatch(userId, partnerId,
          limit: limit, startAfter: _lastFetchedDoc);
      final List<MessageModel> messagesRaw = result['messages'] ?? [];
      final List<MessageModel> messages = [];
      
      // ✨ Decrypt & Migrate Pagination Batch
      for (var msg in messagesRaw) {
        // 1. Decrypt
        final decryptedMsg = await _decryptMessage(msg);
        messages.add(decryptedMsg);

        // 2. Migrate (if needed)
        _maybeMigrateMessage(userId, partnerId, decryptedMsg);
      }

      _lastFetchedDoc = result['lastDoc'];
      final Map<String, MessageModel> uniqueMessages = {
        for (var m in _messages) m.id: m
      };
      for (var m in messages) {
        uniqueMessages.putIfAbsent(m.id, () => m);
      }
      _messages = uniqueMessages.values.toList();
      _messages.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      _filteredMessages = List.from(_messages);
      _hasMoreMessages = messages.length == limit;
    } catch (e) {
      debugPrint('Error fetching more messages: $e');
    } finally {
      _isLoadingMessages = false;
      notifyListeners();
    }
  }

  Future<void> clearChat(String userId, String partnerId) async {
    try {
      await _chatRepository.clearChat(userId, partnerId);
      _messages.clear();
      _filteredMessages.clear();
      _lastFetchedDoc = null;
      _hasMoreMessages = true;
      notifyListeners();
    } catch (e) {
      debugPrint("Error clearing chat in provider: $e");
      rethrow;
    }
  }

  void clear() {
    _seenDebounceTimer?.cancel();
    _messagesToMarkAsSeen.clear();
    _messagesSubscription?.cancel();
    _typingSubscription?.cancel();
    _typingHeartbeatTimer?.cancel();
    _rhmSyncTimer?.cancel();

    if (_currentTypingUserId != null && _currentTypingPartnerId != null) {
      _chatRepository.updateTypingStatus(
          _currentTypingUserId!, _currentTypingPartnerId!, false);
    }

    _messages = [];
    _filteredMessages = [];
    _isPartnerTyping = false;
    _isLoadingMessages = false;
    _isSearching = false;
    _currentSearchQuery = '';
    _lastFetchedDoc = null;
    _hasMoreMessages = true;
    _replyingToMessage = null;
    _currentTypingUserId = null;
    _currentTypingPartnerId = null;
    _unsyncedMessageCount = 0;
    _currentChatUserId = null;
    _currentChatPartnerId = null;
    _optimisticMessages.clear();// ✨ Clear this too

    print("[ChatProvider] Cleared and reset state.");
  }

  // ✨ Helper method to send notifications with retry logic
  Future<void> _sendNotificationWithRetry({
    required String receiverId,
    required String message,
    required String senderName,
    String? messageText,
    int maxAttempts = 3,
  }) async {
    for (int attempt = 0; attempt < maxAttempts; attempt++) {
      try {
        await _userRepository.sendPushNotification(
          receiverId,
          message,
          partnerName: senderName,
          messageText: messageText,
        );
        // Success! Exit the retry loop
        if (attempt > 0) {
          debugPrint('Notification sent successfully on attempt ${attempt + 1}');
        }
        return;
      } catch (e) {
        debugPrint('Notification attempt ${attempt + 1} failed: $e');
        
        // If this was the last attempt, log the final failure
        if (attempt == maxAttempts - 1) {
          debugPrint('CRITICAL: Notification failed after $maxAttempts attempts for user $receiverId');
          // Don't rethrow - we don't want to break the message sending flow
          return;
        }
        
        // Wait with exponential backoff before retry (500ms, 1s, 2s...)
        await Future.delayed(Duration(milliseconds: 500 * (attempt + 1)));
      }
    }
  }


  void dispose() {
    _messagesSubscription?.cancel();
    _typingSubscription?.cancel();
    _typingHeartbeatTimer?.cancel();
    _rhmSyncTimer?.cancel();
    _seenDebounceTimer?.cancel();
    _keyWaitSub?.cancel(); // ✨ Cancel key listener
    super.dispose();
  }

  /// ✨ RELOAD Messages (e.g. after key restore)
  void reloadMessages() {
    debugPrint("🔄 [ChatProvider] Reloading messages due to key change...");
    if (_currentChatUserId != null && _currentChatPartnerId != null) {
      // Force cancel the current subscription to bypass the "already listening" guard
      _messagesSubscription?.cancel();
      _messagesSubscription = null;
      
      listenToMessages(_currentChatUserId!, _currentChatPartnerId!);
    } else {
      debugPrint("⚠️ [ChatProvider] Cannot reload: User/Partner ID missing.");
    }
  }

  /// Helper to re-run decryption on existing messages when key becomes available
  void _reDecryptAllMessages() {
     // Only reload if we were explicitly waiting for the key.
     // This prevents infinite loops where 'listenToMessages' sets up a listener
     // that immediately fires 'true', which calls this, which calls 'listenToMessages'...
     if (_isWaitingForKey) {
        reloadMessages();
     } else {
       // If we weren't waiting (key was already ready), we normally don't need to do anything
       // as the initial decryption pass would have worked.
       // However, just to be safe (e.g. maybe key changed?), we can notify listeners.
       notifyListeners();
     }
  }

  void _maybeMigrateMessage(String userId, String partnerId, MessageModel msg) {
    if (EncryptionService.instance.isReady && msg.encryptionVersion == null) {
       // Only migrate if there is meaningful content to encrypt
       // ✨ HANDLE NULL messageType (Legacy messages might rely on default)
       bool isText = msg.messageType == 'text' || msg.messageType == null;
       bool isImage = msg.messageType == 'image';

       bool needsMigration = (isText && msg.content.isNotEmpty) ||
                             (isImage && msg.googleDriveImageId != null);
       
       if (needsMigration) {
         // Fire and forget
         _chatRepository.migrateLegacyMessage(userId, partnerId, msg);
       }
    }
  }


  Future<MessageModel> _decryptMessage(MessageModel msg) async {
    if (msg.encryptionVersion == 1) {
       final decryptedString = await msg.getDecryptedContent();
       if (msg.messageType == 'text') {
          return msg.copyWith(content: decryptedString);
       } else if (msg.messageType == 'image') {
          return msg.copyWith(googleDriveImageId: decryptedString);
       }
    }
    return msg;
  }
}