import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/message_model.dart';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'package:feelings/features/media/repository/media_repository.dart';
import 'package:feelings/services/encryption_service.dart';


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
  String? ciphertext,
    String? nonce,
    String? mac,
    int? encryptionVersion,

  String? audioUrl,
    double? audioDuration,
    
  // ✨ NEW: Audio Encryption Fields
  String? audioGlobalOtk, 
  String? audioNonce,
  int? audioEncryptionVersion,
  String? audioOtkNonce,
  String? audioOtkMac,
  
  bool isEncryptionEnabled = false, // ✨ NEW: Respect User Preference
}) async {
  try {
    final chatId = _getChatId(senderId, receiverId);

    final messageRef = _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .doc();

    // ✨ ENCRYPTION LOGIC START
      String? ciphertext;
      String? nonce;
      String? mac;
      int? encryptionVersion;

      // We default to sending the plaintext for now, unless encryption succeeds
      String finalContent = content;
      String? finalGoogleDriveImageId = googleDriveImageId;

      // 1. Check if we should encrypt
      // ✨ RULES:
      // - Service must be ready (keys loaded)
      // - User must have ENABLED encryption explicitly
      if (EncryptionService.instance.isReady && isEncryptionEnabled) {
        debugPrint("🔐 [Chat] Encryption enforced & service ready. Processing...");
        try {
          // CASE A: Text Message
          if (messageType == 'text' && content.isNotEmpty) {
             debugPrint("🔐 [Chat] Encrypting text content.");
             final encrypted = await EncryptionService.instance.encryptText(content);
             ciphertext = encrypted['ciphertext'];
             nonce = encrypted['nonce'];
             mac = encrypted['mac'];
             encryptionVersion = 1;
             finalContent = "🔒 Encrypted Message"; // 🔒 Set fallback for legacy clients
          }
          
          // CASE B: Image Message
          else if (messageType == 'image' && googleDriveImageId != null) {
             debugPrint("🔐 [Chat] Encrypting image ID.");
             // We encrypt the ID as if it were text
             final encrypted = await EncryptionService.instance.encryptText(googleDriveImageId);
             ciphertext = encrypted['ciphertext'];
             nonce = encrypted['nonce'];
             mac = encrypted['mac'];
             encryptionVersion = 1;
             finalGoogleDriveImageId = ""; // 🔒 Hide the ID in Firestore
          }
          
        } catch (e) {
          debugPrint("⚠️ Encryption failed, sending plaintext: $e");
        }

      } else {
        if (!EncryptionService.instance.isReady) {
           debugPrint("⚠️ [Chat] Encryption service is NOT ready. Sending Plaintext.");
        } else {
           debugPrint("⚠️ [Chat] Encryption DISABLED by user preference. Sending Plaintext.");
        }
      }
      // ✨ ENCRYPTION LOGIC END

    final message = MessageModel(
      id: messageRef.id,
      senderId: senderId,
      receiverId: receiverId,
      content: finalContent,
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
      googleDriveImageId: finalGoogleDriveImageId,
      audioUrl: audioUrl,
      audioDuration: audioDuration,
      ciphertext: ciphertext,
        nonce: nonce,
        mac: mac,
        encryptionVersion: encryptionVersion,
        
      // ✨ NEW: Pass Audio Encryption Data
      audioGlobalOtk: audioGlobalOtk,
      audioNonce: audioNonce,
      audioEncryptionVersion: audioEncryptionVersion,
      audioOtkNonce: audioOtkNonce,
      audioOtkMac: audioOtkMac,
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

// Change signature to return a Map with metadata
  Future<Map<String, String>> uploadSecureAudio(
      File audioFile, 
      String senderId, 
      String receiverId, 
      String messageId, {
      bool isEncryptionEnabled = false,
  }) async {
    try {
      File fileToUpload = audioFile;
      String? encryptedOtk; // The OTK itself encrypted with the Master Key
      String? otkNonce;
      String? otkMac;
      String? fileNonce; // The nonce for the audio file
      
      // ✨ ENCRYPT FILE IF READY AND ENABLED
      if (EncryptionService.instance.isReady && isEncryptionEnabled) {
        // 1. Encrypt the file itself (Generates a random OTK)
        final result = await EncryptionService.instance.encryptFile(audioFile);
        final plaintextOtk = result['otk']; // This is the RAW key base64
        fileNonce = result['nonce'];
        
        // 2. Encrypt the OTK with the Couple Master Key
        // So only we (and partner) can decrypt the key, and then use the key to decrypt the file.
        final encryptedKeyMap = await EncryptionService.instance.encryptText(plaintextOtk!);
        
        encryptedOtk = encryptedKeyMap['ciphertext'];
        otkNonce = encryptedKeyMap['nonce'];
        otkMac = encryptedKeyMap['mac'];

        // Write encrypted bytes to a temp file for upload
        final tempDir = Directory.systemTemp;
        final tempFile = File('${tempDir.path}/enc_$messageId.m4a');
        await tempFile.writeAsBytes(result['fileBytes']);
        
        fileToUpload = tempFile;
      }

      // Upload (either the plain file or the encrypted temp file)
      final chatId = _getChatId(senderId, receiverId);
      final ref = _storage
          .ref()
          .child('chats')
          .child(chatId)
          .child('audio')
          .child('$messageId.m4a'); // keep extension

      UploadTask uploadTask = ref.putFile(fileToUpload);
      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();

      // Return metadata
      return {
        'url': downloadUrl,
        'audioGlobalOtk': encryptedOtk ?? '',
        'audioNonce': fileNonce ?? '',
        'audioOtkNonce': otkNonce ?? '',
        'audioOtkMac': otkMac ?? '',
        'audioEncryptionVersion': encryptedOtk != null ? '1' : '',
      };
    } catch (e) {
      debugPrint("Error uploading audio: $e");
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
        .snapshots(includeMetadataChanges: true)
        .listen(
      (snapshot) async {
        try {
          List<MessageModel> messages = [];

          for (var doc in snapshot.docs) {
            MessageModel msg = MessageModel.fromDocument(doc);
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
          .map((doc) => MessageModel.fromDocument(doc))
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
  });
}

  Future<void> updateMessageAudioData(
    String userId,
    String partnerId,
    String messageId, {
    required String audioUrl,
    required String? audioGlobalOtk,
    required String? audioNonce,
    required int? audioEncryptionVersion,
    required String? audioOtkNonce,
    required String? audioOtkMac,
  }) async {
    final chatId = _getChatId(userId, partnerId);
    final docRef = _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .doc(messageId);

    await docRef.update({
      'audioUrl': audioUrl,
      'storageStatus': FieldValue.delete(), // Remove expired flag
      'audioGlobalOtk': audioGlobalOtk,
      'audioNonce': audioNonce,
      'audioEncryptionVersion': audioEncryptionVersion,
      'audioOtkNonce': audioOtkNonce,
      'audioOtkMac': audioOtkMac,
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
      final messages = snapshot.docs.map((doc) => MessageModel.fromDocument(doc)).toList();
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

  Future<void> migrateLegacyMessage(String userId, String partnerId, MessageModel message, {bool isEncryptionEnabled = false}) async {
    if (!EncryptionService.instance.isReady) return;
    if (!isEncryptionEnabled) return; // ✨ Respect preference
  
    // Only migrate if it's NOT already encrypted
    if (message.encryptionVersion != null) return;

    try {
      final chatId = _getChatId(userId, partnerId);
      final docRef = _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .doc(message.id);

      String? ciphertext;
      String? nonce;
      String? mac;
      
      Map<String, dynamic> updates = {};

      // ✨ Handle null messageType as 'text' for legacy messages
      final isText = message.messageType == 'text' || message.messageType == null;
      final isImage = message.messageType == 'image';

      if (isText && message.content.isNotEmpty) {
        final encrypted = await EncryptionService.instance.encryptText(message.content);
        ciphertext = encrypted['ciphertext'];
        nonce = encrypted['nonce'];
        mac = encrypted['mac'];
        
        updates = {
          'content': '', // Clear plaintext
          'ciphertext': ciphertext,
          'nonce': nonce,
          'mac': mac,
          'encryptionVersion': 1,
        };
      } else if (isImage && message.googleDriveImageId != null) {
        final encrypted = await EncryptionService.instance.encryptText(message.googleDriveImageId!);
        ciphertext = encrypted['ciphertext'];
        nonce = encrypted['nonce'];
        mac = encrypted['mac'];
        
        updates = {
          'googleDriveImageId': '', // Clear plaintext ID
          'ciphertext': ciphertext,
          'nonce': nonce,
          'mac': mac,
          'encryptionVersion': 1,
        };
      }

      if (updates.isNotEmpty) {
        debugPrint("🔒 [Migration] Migrating message ${message.id} to encrypted format...");
        await docRef.update(updates);
      }

    } catch (e) {
      debugPrint("⚠️ [Migration] Failed to migrate message ${message.id}: $e");
    }
  }

  void dispose() {
    _typingDebounceTimer?.cancel();
  }
}