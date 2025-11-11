import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/message_model.dart';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'package:feelings/features/media/repository/media_repository.dart';


class ChatRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance; 

  // Debounce timer for typing status
  Timer? _typingDebounceTimer;
  final FirebaseAuth _auth = FirebaseAuth.instance; // 👈 2. Add this instance

  final MediaRepository _mediaRepository = MediaRepository();

  Future<void> sendMessage(
  String senderId,
  String receiverId,
  String content, {
  // Existing reply fields
  String? repliedToMessageId,
  String? repliedToMessageContent,
  String? repliedToSenderName,
  String? repliedToSenderId,
  
  // ✨ NEW reply fields
  String? repliedToMessageType,
  String? repliedToImageUrl,

  // ✨ NEW FIELDS TO ACCEPT
  String? messageType,
  String? googleDriveImageId,

  String? audioUrl,
    double? audioDuration,
}) async {
  try {
    final chatId = _getChatId(senderId, receiverId);

    final messageRef = _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .doc();

    final message = MessageModel(
      id: messageRef.id,
      senderId: senderId,
      receiverId: receiverId,
      content: content,
      timestamp: DateTime.now(),
      status: 'sent',
      participants: [senderId, receiverId],
      repliedToMessageId: repliedToMessageId,
      repliedToMessageContent: repliedToMessageContent,
      repliedToSenderName: repliedToSenderName,
      repliedToSenderId: repliedToSenderId,
      repliedToMessageType: repliedToMessageType, // ✨ Add to model
      repliedToImageUrl: repliedToImageUrl, // ✨ Add to model

      // ✨ PASS THE NEW DATA TO THE MODEL
      messageType: messageType ?? 'text', // Default to 'text'
      googleDriveImageId: googleDriveImageId,
      audioUrl: audioUrl,
      audioDuration: audioDuration,
      // localImagePath is null, as it's never saved to Firestore
    );

    // message.toMap() will now correctly include the new fields
    await messageRef.set(message.toMap());
  } catch (e) {
    debugPrint("Error sending message: $e");
    rethrow;
  }
}

Future<String> uploadAudioToFirebaseStorage(File audioFile, String senderId, String receiverId, String messageId) async {
  try {
    final fileExtension = audioFile.path.split('.').last;
    final chatId = _getChatId(senderId, receiverId);
    final ref = _storage
          .ref()
          .child('chats')
          .child(chatId)
          .child('audio')
          .child('$messageId.$fileExtension');

    UploadTask uploadTask = ref.putFile(audioFile);

    final snapshot = await uploadTask;
    final downloadUrl = await snapshot.ref.getDownloadURL();

    return downloadUrl;
  } catch (e) {
    debugPrint("Error uploading audio to Firebase Storage: $e");
    rethrow;
  }
}

  // ✨ MODIFIED: Changed return type from void to StreamSubscription
  StreamSubscription listenToMessages(
  String userId,
  String partnerId,
  Function(List<MessageModel>) onMessagesUpdated, {
  Function(dynamic error)? onError,
}) {
  try {
    return _firestore
        .collection('chats')
        .doc(_getChatId(userId, partnerId))
        .collection('messages')
        .where('participants', arrayContains: userId)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .listen(
      (snapshot) async {
        try {
          List<MessageModel> messages = [];

          for (var doc in snapshot.docs) {
            MessageModel msg = MessageModel.fromMap(doc.data());
            messages.add(msg);
          }

          onMessagesUpdated(messages);
        } catch (e) {
          debugPrint("Error processing messages: $e");
        }
      },
      onError: (error) {
        debugPrint("Firestore listener error: $error");
        onError?.call(error); // Safely invoke if provided
      },
    );
  } catch (e) {
    debugPrint("Error setting up message listener: $e");
    rethrow;
  }
}


  Future<void> markSingleMessageAsSeen(String userId, String partnerId, String messageId) async {
    try {
      final chatId = _getChatId(userId, partnerId);
      final docRef = _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .doc(messageId);

      await docRef.update({'status': 'seen'});
      debugPrint('Marked message $messageId as seen');

    } catch (e) {
      debugPrint("Error marking single message as seen: $e");
    }
  }

  Future<void> deleteMessage(String chatId, MessageModel message) async {
    // 1. Delete Firestore Document
    try {
      await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .doc(message.id)
          .delete();
    } catch (e) {
      debugPrint("Error deleting Firestore message: $e");
      rethrow; // Re-throw to notify the provider of the main failure
    }

    // 2. Delete Google Drive Image (if it exists)
    if (message.googleDriveImageId != null) {
      try {
        await _mediaRepository.deleteFromGoogleDrive(message.googleDriveImageId!);
        debugPrint("Successfully deleted image from Google Drive: ${message.googleDriveImageId}");
      } catch (e) {
        debugPrint("Error deleting Google Drive file: $e. (Note: 'deleteFromGoogleDrive' must exist in MediaRepository)");
        // Don't rethrow, as the main message is already deleted.
      }
    }

    // 3. Delete Firebase Storage Audio (if it exists)
    if (message.audioUrl != null) {
      try {
        // Use refFromURL to get a reference from the download URL
        final Reference storageRef = _storage.refFromURL(message.audioUrl!);
        await storageRef.delete();
        debugPrint("Successfully deleted audio from Firebase Storage: ${message.audioUrl}");
      } catch (e) {
        debugPrint("Error deleting Firebase Storage file: $e");
        // Don't rethrow.
      }
    }
  }

  Future<List<MessageModel>> searchMessages(String userId, String partnerId, String query) async {
    try {
      final chatId = _getChatId(userId, partnerId);
      final querySnapshot = await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .where('participants', arrayContains: userId)
          .orderBy('timestamp', descending: true)
          .get();
      
      return querySnapshot.docs
          .map((doc) => MessageModel.fromMap(doc.data()))
          .where((message) => message.content.toLowerCase().contains(query.toLowerCase()))
          .toList();
    } catch (e) {
      debugPrint("Error searching messages: $e");
      return [];
    }
  }

  Future<void> updateTypingStatus(String userId, String partnerId, bool isTyping) async {
    final currentUser = _auth.currentUser;
    // If no one is signed in, or if the ID we have doesn't match the
    // currently signed-in user, exit immediately to prevent a crash.
    if (currentUser == null || currentUser.uid != userId) {
      debugPrint("Typing status update skipped: User is not authenticated or ID mismatch.");
      return; 
    }
    try {
      _typingDebounceTimer?.cancel();
      
      final docRef = _firestore
          .collection('chats')
          .doc(_getChatId(userId, partnerId))
          .collection('typingStatus')
          .doc(userId);

      if (isTyping) {
        await docRef.set({'isTyping': isTyping, 'timestamp': FieldValue.serverTimestamp()});
      } else {
        _typingDebounceTimer = Timer(const Duration(milliseconds: 1000), () async {
          await docRef.set({'isTyping': false, 'timestamp': FieldValue.serverTimestamp()});
        });
      }
    } catch (e) {
      debugPrint("Error updating typing status: $e");
    }
  }

  // ✨ MODIFIED: Changed return type from void to StreamSubscription
  StreamSubscription listenToTypingStatus(
  String userId,
  String partnerId,
  Function(bool) onTypingUpdated, {
  Function(dynamic error)? onError,
}) {
  try {
    return _firestore
        .collection('chats')
        .doc(_getChatId(userId, partnerId))
        .collection('typingStatus')
        .doc(partnerId)
        .snapshots()
        .listen(
      (snapshot) {
        try {
          if (snapshot.exists) {
            final data = snapshot.data();
            final isTyping = data?['isTyping'] ?? false;
            final timestamp = data?['timestamp'] as Timestamp?;

            if (timestamp != null) {
              final now = DateTime.now();
              final typingTime = timestamp.toDate();
              final timeDiff = now.difference(typingTime).inSeconds;

              if (timeDiff > 10) {
                onTypingUpdated(false);
                return;
              }
            }
            onTypingUpdated(isTyping);
          } else {
            onTypingUpdated(false);
          }
        } catch (e) {
          debugPrint("Error processing typing status: $e");
          onTypingUpdated(false);
        }
      },
      onError: (error) {
        debugPrint("Typing status listener error: $error");
        onError?.call(error); // Safely invoke if provided
      },
    );
  } catch (e) {
    debugPrint("Error setting up typing status listener: $e");
    rethrow;
  }
}

// chat_repository.dart

Future<void> editMessage(
  String userId,
  String partnerId,
  String messageId,
  String newContent, {
  int? nextEditCount,
}) async {
  final chatId = _getChatId(userId, partnerId);
  final docRef = _firestore
      .collection('chats')
      .doc(chatId)
      .collection('messages')
      .doc(messageId);

  await docRef.update({
    'content': newContent.trim(),
    'editedAt': FieldValue.serverTimestamp(),
    if (nextEditCount != null) 'editCount': nextEditCount,
  });
}


  String _getChatId(String user1, String user2) {
    List<String> sortedIds = [user1, user2]..sort();
    return '${sortedIds[0]}_${sortedIds[1]}';
  }

  Future<void> clearChat(String userId, String partnerId) async {
    try {
      final chatId = _getChatId(userId, partnerId);
      
      final querySnapshot = await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .where('participants', arrayContains: userId)
          .get();
      
      WriteBatch batch = _firestore.batch();
      for (var doc in querySnapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      
    } catch (e) {
      debugPrint("Error clearing chat: $e");
      rethrow;
    }
  }

  Future<Map<String, dynamic>> fetchMessagesBatch(String userId, String partnerId, {int limit = 20, DocumentSnapshot? startAfter}) async {
    try {
      final chatId = _getChatId(userId, partnerId);
      Query query = _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .where('participants', arrayContains: userId)
          .orderBy('timestamp', descending: true)
          .limit(limit);
      if (startAfter != null) {
        query = query.startAfterDocument(startAfter);
      }
      final snapshot = await query.get();
      final messages = snapshot.docs.map((doc) => MessageModel.fromMap(doc.data() as Map<String, dynamic>)).toList();
      final lastDoc = snapshot.docs.isNotEmpty ? snapshot.docs.last : null;
      return {'messages': messages, 'lastDoc': lastDoc};
    } catch (e) {
      debugPrint('Error fetching paginated messages: $e');
      return {'messages': [], 'lastDoc': null};
    }
  }

  Future<void> markBatchMessagesAsSeen(String userId, String partnerId, List<String> messageIds) async {
    if (messageIds.isEmpty) return;
    
    try {
      final chatId = _getChatId(userId, partnerId);
      final messagesCollection = _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages');
      
      WriteBatch batch = _firestore.batch();
      
      for (final messageId in messageIds) {
        final docRef = messagesCollection.doc(messageId);
        batch.update(docRef, {'status': 'seen'});
      }
      
      await batch.commit();
      debugPrint('Marked ${messageIds.length} messages as seen in a batch');
    } catch (e) {
      debugPrint("Error in markBatchMessagesAsSeen: $e");
    }
  }

  void dispose() {
    _typingDebounceTimer?.cancel();
  }
}