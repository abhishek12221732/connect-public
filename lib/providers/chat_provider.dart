// lib/providers/chat_provider.dart

import 'dart:async';
import 'dart:io'; // Make sure this is imported
import 'package:flutter/material.dart';
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

  // ✨ ADD THIS to track the image being sent
  final Map<String, MessageModel> _optimisticMessages = {};

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
    ChatRepository? chatRepository,
    UserRepository? userRepository,
  })  : _chatRepository = chatRepository ?? ChatRepository(),
        _userRepository = userRepository ?? UserRepository(),
        _rhmRepository = rhmRepository;

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
  void listenToMessages(String userId, String partnerId) {
    _messagesSubscription?.cancel();

    _currentChatUserId = userId;
    _currentChatPartnerId = partnerId;

    _messagesSubscription = _chatRepository.listenToMessages(userId, partnerId,
      (newMessages) {
        // ✨ --- [GUARD 1: ON-DATA] --- ✨
        if (FirebaseAuth.instance.currentUser == null) {
          debugPrint(
              "[ChatProvider] Message event received, but user is logged out. Ignoring.");
          return;
        }

        final List<MessageModel> processedMessages = List.from(newMessages);

        // 2. Create a list of optimistic IDs to remove (to avoid concurrent modification)
        final List<String> optimisticIdsToRemove = [];

        // 3. Iterate over our tracked optimistic messages
        _optimisticMessages.forEach((tempId, optimisticMsg) {
          
          // 4. Try to find its matching message from the server
          final int serverIndex = processedMessages.indexWhere(
            (serverMsg) {
              // If the upload is done, we can match by GDrive ID
              if (optimisticMsg.googleDriveImageId != null) {
                return serverMsg.googleDriveImageId ==
                    optimisticMsg.googleDriveImageId;
              }
              // If still uploading, match by content and timestamp
              return serverMsg.senderId == optimisticMsg.senderId &&
                  serverMsg.content == optimisticMsg.content &&
                  serverMsg.timestamp
                          .difference(optimisticMsg.timestamp)
                          .inSeconds
                          .abs() <
                      20; // 20-second window
            },
          );

          // 5. IF a match is found:
          if (serverIndex != -1) {
  // Merge the local path and upload status into the server message
  final serverMessage = processedMessages[serverIndex];
  
  // ✨ FIX: Explicitly copy the correct local path based on message type
  processedMessages[serverIndex] = serverMessage.copyWith(
    localImagePath: serverMessage.messageType == 'image'
        ? optimisticMsg.localImagePath
        : serverMessage.localImagePath,
    localAudioPath: serverMessage.messageType == 'voice'
        ? optimisticMsg.localAudioPath
        : serverMessage.localAudioPath,
    uploadStatus: 'success', // Mark as complete
  );
  
  // Mark this optimistic message for removal from our map
  optimisticIdsToRemove.add(tempId);
}
          // 6. IF no match is found, the optimistic message (e.g., uploading/failed)
          // will just be added back to the list later.
        });

        // 7. Clean up the optimistic map
        for (var id in optimisticIdsToRemove) {
          _optimisticMessages.remove(id);
        }

        // 8. Create the final list
        final Map<String, MessageModel> finalMessageMap = {};

        // Add all processed server messages
        for (var msg in processedMessages) {
          finalMessageMap[msg.id] = msg;
        }

        // Add any remaining optimistic messages (still uploading/failed)
        for (var msg in _optimisticMessages.values) {
          finalMessageMap[msg.id] = msg;
        }

        // 9. Set the final state
        _messages = finalMessageMap.values.toList();
        _messages.sort((a, b) => b.timestamp.compareTo(a.timestamp));

        
        if (_isSearching) {
          _applySearchFilter(_currentSearchQuery);
        } else {
          _filteredMessages = List.from(_messages);
        }
        notifyListeners();
      },
      onError: (error) {
        // ✨ --- [GUARD 2: ON-ERROR] --- ✨
        if (error is FirebaseException &&
            error.code == 'permission-denied') {
          if (FirebaseAuth.instance.currentUser == null) {
            debugPrint(
                "[ChatProvider] Safely caught permission-denied on message listener during logout.");
          } else {
            debugPrint(
                "[ChatProvider] CRITICAL MESSAGE PERMISSION ERROR: $error");
          }
        } else {
          debugPrint("[ChatProvider] Unexpected message error: $error");
        }
      },
    );
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
    _messages.insert(0, newMessage);
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
    );
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
  }) async {
    try {
      // 1. Upload to Firebase Storage
      final downloadUrl = await _chatRepository.uploadAudioToFirebaseStorage(
        audioFile,
        senderId,
        receiverId,
        tempId, // Use tempId as part of the file name
      );

      // 2. Send the REAL message data to Firestore
      await _chatRepository.sendMessage(
        senderId,
        receiverId,
        '', // No text content
        repliedToMessageId: newMessage.repliedToMessageId,
        repliedToMessageContent: newMessage.repliedToMessageContent,
        repliedToSenderName: newMessage.repliedToSenderName,
        repliedToSenderId: newMessage.repliedToSenderId,
        repliedToMessageType: newMessage.repliedToMessageType,
        repliedToImageUrl: newMessage.repliedToImageUrl,
        messageType: 'voice',
        audioUrl: downloadUrl,
        audioDuration: newMessage.audioDuration,
      );

      // 3. Update optimistic message to 'success'
      if (_optimisticMessages.containsKey(tempId)) {
  // 1. Update the message in our tracking map
  final updatedOptimisticMessage = _optimisticMessages[tempId]!.copyWith(
    uploadStatus: 'success',
    audioUrl: downloadUrl,
    status : 'sent',
  );
  _optimisticMessages[tempId] = updatedOptimisticMessage;

  // 2. Find the message in the main UI list and replace it
  final mainIndex = _messages.indexWhere((m) => m.id == tempId);
  if (mainIndex != -1) {
    // ✨ FIX: Replace the old message with the fully updated one,
    // which correctly preserves the localAudioPath.
    _messages[mainIndex] = updatedOptimisticMessage;
    notifyListeners();
  }
}

      // 4. Handle notifications & RHM logic
      _dynamicActionsProvider.recordMessageSent();
      _unsyncedMessageCount++;
      _startRhmSyncTimer();

      _userRepository
          .sendPushNotification(
            receiverIdForNotif,
            "🎤 Voice Message", // Notification text
            partnerName: senderName,
          )
          .catchError((e) {
        debugPrint('Push notification error (ignored): $e');
      });

    } catch (e) {
      debugPrint('Error sending voice message: $e');
      // 5. Mark optimistic message as 'failed'
      if (_optimisticMessages.containsKey(tempId)) {
        _optimisticMessages[tempId] = _optimisticMessages[tempId]!.copyWith(uploadStatus: 'failed', status: 'failed');
        final mainIndex = _messages.indexWhere((m) => m.id == tempId);
        if (mainIndex != -1) {
          _messages[mainIndex] = _messages[mainIndex].copyWith(uploadStatus: 'failed', status: 'failed');
          notifyListeners();
        }
      }
    }
  }

  Future<void> _flushSeenMessages(String userId, String partnerId) async {
    if (_messagesToMarkAsSeen.isEmpty) return;

    final List<String> messageIdsToMark = List.from(_messagesToMarkAsSeen);
    _messagesToMarkAsSeen.clear();

    bool needsNotify = false;
    for (int i = 0; i < _messages.length; i++) {
      final msg = _messages[i];
      if (messageIdsToMark.contains(msg.id)) {
        _messages[i] = msg.copyWith(status: 'seen');
        needsNotify = true;
      }
    }

    if (needsNotify) {
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
        _messages[index] = _messages[index].copyWith(status: 'seen');
        notifyListeners();
        await _chatRepository.markSingleMessageAsSeen(
            userId, partnerId, messageId);

        await NotificationService.dismissNotificationForMessage(messageId);
      }
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
      _messages[idx] = updated;
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
  }) async {
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
      status: imageFile != null ? 'unsent' : 'sent', // Message status (distinct from upload status)
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
    );

   _optimisticMessages[tempId] = newMessage;
    _messages.insert(0, newMessage); // Insert into main list
    _messages.sort((a, b) => b.timestamp.compareTo(a.timestamp)); // Re-sort
    if (_isSearching) _applySearchFilter(_currentSearchQuery);
    
    cancelReply();
    notifyListeners();

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
    );
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
        final mainIndex = _messages.indexWhere((m) => m.id == tempId);
        if (mainIndex != -1) {
          _messages[mainIndex] = _messages[mainIndex].copyWith(
            uploadStatus: 'success',
            googleDriveImageId: finalImageId,
            status: 'sent',
          );
          notifyListeners();
        }
      }
      
      // 7. Handle RHM logic and notifications
      _dynamicActionsProvider.recordMessageSent();
      _unsyncedMessageCount++;
      _startRhmSyncTimer();

      _userRepository
          .sendPushNotification(
            receiverIdForNotif,
            imageFile != null ? "📷 Image" : content,
            partnerName: senderName,
            messageText: messageTextForNotif,
          )
          .catchError((e) {
        debugPrint('Push notification error (ignored): $e');
      });

    } catch (e) {
      debugPrint('Error sending message: $e');
      // 8. ✨ Mark the optimistic message as 'failed'
      if (_optimisticMessages.containsKey(tempId)) {
        _optimisticMessages[tempId] = _optimisticMessages[tempId]!
            .copyWith(uploadStatus: 'failed', status: 'failed');
        // We find it in the *main* list to update the UI
        final mainIndex = _messages.indexWhere((m) => m.id == tempId);
        if (mainIndex != -1) {
          _messages[mainIndex] =
              _messages[mainIndex].copyWith(uploadStatus: 'failed', status: 'failed');
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
      _messages.removeWhere((m) => m.id == message.id); // ✨ Use message.id
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

  void _applySearchFilter(String query) {
    if (query.isEmpty) {
      _filteredMessages = List.from(_messages);
      return;
    }
    _filteredMessages = _messages
        .where((msg) => msg.content.toLowerCase().contains(query.toLowerCase()))
        .toList();
  }

  void clearSearch() {
    _isSearching = false;
    _currentSearchQuery = '';
    _filteredMessages = List.from(_messages);
    notifyListeners();
  }

  Future<void> fetchInitialMessages(String userId, String partnerId,
      {int limit = 20}) async {
    _isLoadingMessages = true;
    notifyListeners();
    try {
      final result = await _chatRepository.fetchMessagesBatch(userId, partnerId,
          limit: limit);
      final List<MessageModel> messages = result['messages'] ?? [];
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
      final List<MessageModel> messages = result['messages'] ?? [];
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

  @override
  void dispose() {
    clear();
    _seenDebounceTimer?.cancel();
    super.dispose();
  }
}