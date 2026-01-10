import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:feelings/services/encryption_service.dart';


class MessageModel {
  final String id;

  final String senderId;

  final String receiverId;

  final String content;
  
  final DateTime timestamp;
  
  final String status;

  final List<String> participants;

  final String? repliedToMessageId;

  final String? repliedToMessageContent;

  final String? repliedToSenderName;
  
  // --- NEW FIELD ---
  final String? repliedToSenderId;
  // --- END NEW ---
  final DateTime? editedAt;

  final int? editCount;

final String? ciphertext;

final String? nonce;

final String? mac; // Authentication tag

final int? encryptionVersion; // 1 = Encrypted, null = Old Plaintext

  // ✨ NEW Reply fields for images
  final String? repliedToMessageType; // 'text' or 'image'
  final String? repliedToImageUrl; // The googleDriveImageId

  final String? messageType; // 'text' or 'image'
  final String? googleDriveImageId; // To store the ID from Google Drive
  final String? localImagePath; // Stores local path before upload finishes
  final String? uploadStatus;
  final String? audioUrl;
  final double? audioDuration;
  final String? localAudioPath;
  
  // ✨ NEW: Audio Encryption Fields
  final String? audioGlobalOtk; // Encrypted OTK (using CMK)

  final String? audioNonce; // Nonce used for the file itself

  final int? audioEncryptionVersion; // 1 = Encrypted

  final String? audioOtkNonce; // Nonce used to encrypt the OTK

  final String? audioOtkMac; // MAC for the OTK

  MessageModel({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.content,
    required this.timestamp,
    required this.status,
    required this.participants,
    this.repliedToMessageId,
    this.repliedToMessageContent,
    this.repliedToSenderName,
    this.repliedToSenderId, // Updated constructor
    this.repliedToMessageType, // ✨ Add to constructor
    this.repliedToImageUrl, // ✨ Add to constructor
    this.editedAt,
    this.editCount,
    this.messageType = 'text',
    this.googleDriveImageId,
    this.localImagePath,
    this.uploadStatus,
    this.audioUrl,
    this.audioDuration,
    this.localAudioPath,
    this.ciphertext,
    this.encryptionVersion,
    this.nonce,
    this.mac,
    this.audioGlobalOtk,
    this.audioNonce,
    this.audioEncryptionVersion,
    this.audioOtkNonce,
    this.audioOtkMac,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'senderId': senderId,
      'receiverId': receiverId,
      'content': content,
      'timestamp': Timestamp.fromDate(timestamp),
      'status': status,
      'participants': participants,
      'repliedToMessageId': repliedToMessageId,
      'repliedToMessageContent': repliedToMessageContent,
      'repliedToSenderName': repliedToSenderName,
      'repliedToSenderId': repliedToSenderId,
      'repliedToMessageType': repliedToMessageType, // ✨ Add to map
      'repliedToImageUrl': repliedToImageUrl, // ✨ Add to map
      'editedAt': editedAt != null ? Timestamp.fromDate(editedAt!) : null,
      'editCount': editCount,
      'messageType': messageType,
      'googleDriveImageId': googleDriveImageId,
      'audioUrl': audioUrl,
      'audioDuration': audioDuration,
      'ciphertext': ciphertext,
'nonce': nonce,
'mac': mac,
      'encryptionVersion': encryptionVersion,
      'audioGlobalOtk': audioGlobalOtk,
      'audioNonce': audioNonce,
      'audioEncryptionVersion': audioEncryptionVersion,
      'audioOtkNonce': audioOtkNonce,
      'audioOtkMac': audioOtkMac,
    };
  }


  factory MessageModel.fromDocument(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    
    DateTime parseTimestamp(dynamic timestamp) {
      if (timestamp is Timestamp) return timestamp.toDate();
      if (timestamp is String) return DateTime.tryParse(timestamp) ?? DateTime.now();
      if (timestamp is DateTime) return timestamp;
      return DateTime.now();
    }

    DateTime? parseEditedAt(dynamic v) {
      if (v is Timestamp) return v.toDate();
      if (v is String) return DateTime.tryParse(v);
      return null;
    }

    String status = data['status'] ?? 'unknown';
    // ✨ Handle Offline/Optimistic State
    // If the document has pending writes, it hasn't reached the server yet.
    // We visually treat 'sent' as 'unsent' (clock icon) until confirmed.
    if (doc.metadata.hasPendingWrites && status == 'sent') {
      status = 'unsent';
    }

    return MessageModel(
      id: doc.id,
      senderId: data['senderId'] ?? '',
      receiverId: data['receiverId'] ?? '',
      content: data['content'] ?? '',
      timestamp: parseTimestamp(data['timestamp']),
      status: status,
      participants: List<String>.from(data['participants'] ?? []),
      repliedToMessageId: data['repliedToMessageId'],
      repliedToMessageContent: data['repliedToMessageContent'],
      repliedToSenderName: data['repliedToSenderName'],
      repliedToSenderId: data['repliedToSenderId'],
      repliedToMessageType: data['repliedToMessageType'] as String?,
      repliedToImageUrl: data['repliedToImageUrl'] as String?,
      editedAt: parseEditedAt(data['editedAt']),
      editCount: data['editCount'] as int?,
      messageType: data['messageType'] ?? 'text',
      googleDriveImageId: data['googleDriveImageId'],
      audioUrl: data['audioUrl'],
      audioDuration: (data['audioDuration'] as num?)?.toDouble(),
      
      // Local paths are not on server, but we can't really restore them from just a doc unless we check local storage.
      // ChatProvider handles merging local logic.
      localImagePath: null, 
      uploadStatus: null, 
      localAudioPath: null, 
      
      // ✨ Missing Encryption Fields Added
      ciphertext: data['ciphertext'],
      nonce: data['nonce'],
      mac: data['mac'],
      encryptionVersion: data['encryptionVersion'],

      audioGlobalOtk: data['audioGlobalOtk'],
      audioNonce: data['audioNonce'],
      audioEncryptionVersion: data['audioEncryptionVersion'],
      audioOtkNonce: data['audioOtkNonce'],
      audioOtkMac: data['audioOtkMac'],
    );
  }

  factory MessageModel.fromMap(Map<String, dynamic> map) {
    DateTime parseTimestamp(dynamic timestamp) {
      if (timestamp is Timestamp) return timestamp.toDate();
      if (timestamp is String) return DateTime.tryParse(timestamp) ?? DateTime.now();
      if (timestamp is DateTime) return timestamp;
      return DateTime.now();
    }

    DateTime? parseEditedAt(dynamic v) {
      if (v is Timestamp) return v.toDate();
      if (v is String) return DateTime.tryParse(v);
      return null;
    }

    return MessageModel(
      id: map['id'] ?? '',
      senderId: map['senderId'] ?? '',
      receiverId: map['receiverId'] ?? '',
      content: map['content'] ?? '',
      timestamp: parseTimestamp(map['timestamp']),
      status: map['status'] ?? 'sent',
      participants: List<String>.from(map['participants'] ?? []),
      repliedToMessageId: map['repliedToMessageId'],
      repliedToMessageContent: map['repliedToMessageContent'],
      repliedToSenderName: map['repliedToSenderName'],
      repliedToSenderId: map['repliedToSenderId'],
      repliedToMessageType: map['repliedToMessageType'] as String?, // ✨ Add from map
      repliedToImageUrl: map['repliedToImageUrl'] as String?, // ✨ Add from map
      editedAt: parseEditedAt(map['editedAt']),
      editCount: map['editCount'] as int?,
      messageType: map['messageType'] as String?,
      googleDriveImageId: map['googleDriveImageId'] as String?,
      localImagePath: map['localImagePath'] as String?,
      
      // ✨ --- THIS IS THE FIX --- ✨
      audioUrl: map['audioUrl'] as String?,
      audioDuration: (map['audioDuration'] as num?)?.toDouble(),
      localAudioPath: map['localAudioPath'] as String?,
      // ✨ --- END OF FIX --- ✨
      ciphertext: map['ciphertext'],
nonce: map['nonce'],
mac: map['mac'],
      encryptionVersion: map['encryptionVersion'],
      audioGlobalOtk: map['audioGlobalOtk'],
      audioNonce: map['audioNonce'],
      audioEncryptionVersion: map['audioEncryptionVersion'],
      audioOtkNonce: map['audioOtkNonce'],
      audioOtkMac: map['audioOtkMac'],
    );
  }

  MessageModel copyWith({
    String? id,
    String? senderId,
    String? receiverId,
    String? content,
    DateTime? timestamp,
    String? status,
    List<String>? participants,
    String? repliedToMessageId,
    String? repliedToMessageContent,
    String? repliedToSenderName,
    String? repliedToSenderId,
    String? repliedToMessageType, // ✨ Add to copyWith
    String? repliedToImageUrl, // ✨ Add to copyWith
    DateTime? editedAt,
    int? editCount,
    String? messageType,
    String? googleDriveImageId,
    String? localImagePath,
    String? uploadStatus,
     String? audioUrl,
    double? audioDuration,
    String? localAudioPath,
    String? ciphertext,
    String? nonce,
    String? mac,
    int? encryptionVersion,
  }) {
    return MessageModel(
      id: id ?? this.id,
      senderId: senderId ?? this.senderId,
      receiverId: receiverId ?? this.receiverId,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      status: status ?? this.status,
      participants: participants ?? this.participants,
      repliedToMessageId: repliedToMessageId ?? this.repliedToMessageId,
      repliedToMessageContent:
          repliedToMessageContent ?? this.repliedToMessageContent,
      repliedToSenderName: repliedToSenderName ?? this.repliedToSenderName,
      repliedToSenderId: repliedToSenderId ?? this.repliedToSenderId,
      repliedToMessageType: repliedToMessageType ?? this.repliedToMessageType, // ✨ Add
      repliedToImageUrl: repliedToImageUrl ?? this.repliedToImageUrl, // ✨ Add
      editedAt: editedAt ?? this.editedAt,
      editCount: editCount ?? this.editCount,
      messageType: messageType ?? this.messageType,
      googleDriveImageId: googleDriveImageId ?? this.googleDriveImageId,
      localImagePath: localImagePath ?? this.localImagePath,
      uploadStatus: uploadStatus ?? this.uploadStatus,
      audioUrl: audioUrl ?? this.audioUrl,
      audioDuration: audioDuration ?? this.audioDuration,
      localAudioPath: localAudioPath ?? this.localAudioPath,
      ciphertext: ciphertext ?? this.ciphertext,
      nonce: nonce ?? this.nonce,
      mac: mac ?? this.mac,
      encryptionVersion: encryptionVersion ?? this.encryptionVersion,
      
      // ✨ NEW
      audioGlobalOtk: audioGlobalOtk ?? this.audioGlobalOtk,
      audioNonce: audioNonce ?? this.audioNonce,
      audioEncryptionVersion: audioEncryptionVersion ?? this.audioEncryptionVersion,
      audioOtkNonce: audioOtkNonce ?? this.audioOtkNonce,
      audioOtkMac: audioOtkMac ?? this.audioOtkMac,
    );
  }

  // ✨ --- UPDATED for full equality check --- ✨
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
  
    return other is MessageModel &&
      other.id == id &&
      other.senderId == senderId &&
      other.receiverId == receiverId &&
      other.content == content &&
      other.timestamp == timestamp &&
      other.status == status &&
      listEquals(other.participants, participants) &&
      other.repliedToMessageId == repliedToMessageId &&
      other.repliedToMessageContent == repliedToMessageContent &&
      other.repliedToSenderName == repliedToSenderName &&
      other.repliedToSenderId == repliedToSenderId &&
      other.repliedToMessageType == repliedToMessageType &&
      other.repliedToImageUrl == repliedToImageUrl &&
      other.editedAt == editedAt &&
      other.editCount == editCount &&
      other.messageType == messageType &&
      other.googleDriveImageId == googleDriveImageId &&
      other.localImagePath == localImagePath &&
      other.uploadStatus == uploadStatus &&
      other.audioUrl == audioUrl &&
      other.audioDuration == audioDuration &&
      other.audioDuration == audioDuration &&
      other.localAudioPath == localAudioPath &&
      other.audioGlobalOtk == audioGlobalOtk &&
      other.audioNonce == audioNonce &&
      other.audioEncryptionVersion == audioEncryptionVersion &&
      other.audioOtkNonce == audioOtkNonce &&
      other.audioOtkMac == audioOtkMac;
  }

  // ✨ --- UPDATED for full equality check --- ✨
  @override
  int get hashCode {
    return id.hashCode ^
      senderId.hashCode ^
      receiverId.hashCode ^
      content.hashCode ^
      timestamp.hashCode ^
      status.hashCode ^
      participants.hashCode ^
      repliedToMessageId.hashCode ^
      repliedToMessageContent.hashCode ^
      repliedToSenderName.hashCode ^
      repliedToSenderId.hashCode ^
      repliedToMessageType.hashCode ^
      repliedToImageUrl.hashCode ^
      editedAt.hashCode ^
      editCount.hashCode ^
      messageType.hashCode ^
      googleDriveImageId.hashCode ^
      localImagePath.hashCode ^
      uploadStatus.hashCode ^
      audioUrl.hashCode ^
      audioDuration.hashCode ^
      localAudioPath.hashCode ^
      audioGlobalOtk.hashCode ^
      audioNonce.hashCode ^
      audioEncryptionVersion.hashCode ^
      audioOtkNonce.hashCode ^
      audioOtkMac.hashCode;
  }

  // No changes below this line
  @override
  String toString() {
    return 'MessageModel(id: $id, senderId: $senderId, receiverId: $receiverId, content: $content, timestamp: $timestamp, status: $status, participants: $participants, repliedToMessageId: $repliedToMessageId, repliedToMessageContent: $repliedToMessageContent, repliedToSenderName: $repliedToSenderName, repliedToSenderId: $repliedToSenderId, repliedToMessageType: $repliedToMessageType, repliedToImageUrl: $repliedToImageUrl, messageType: $messageType, audioUrl: $audioUrl)';
  }

  bool isFromUser(String userId) => senderId == userId;
  bool isToUser(String userId) => receiverId == userId;
  bool isBetweenUsers(String user1, String user2) =>
      (senderId == user1 && receiverId == user2) ||
      (senderId == user2 && receiverId == user1);

  String getFormattedTime() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(timestamp.year, timestamp.month, timestamp.day);
    
    if (messageDate == today) {
      // Use intl or similar for locale-aware time formatting if needed
      return '${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}';
    } else if (messageDate == today.subtract(const Duration(days: 1))) {
      return 'Yesterday ${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}';
    } else {
      return '${timestamp.day}/${timestamp.month} ${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}';
    }
  }

  bool get isRecent => DateTime.now().difference(timestamp).inHours < 24;
  bool get isToday {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(timestamp.year, timestamp.month, timestamp.day);
    return messageDate == today;
  }
  bool get isYesterday {
    final now = DateTime.now();
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    final messageDate = DateTime(timestamp.year, timestamp.month, timestamp.day);
    return messageDate == yesterday;
  }

  /// Decrypts the content if needed. Returns original content if not encrypted.
  Future<String> getDecryptedContent() async {
    // Check if it's an encrypted message (Version 1)
    if (encryptionVersion == 1 && ciphertext != null && nonce != null && mac != null) {
      
      // 1. Check if we even have the key yet
      if (!EncryptionService.instance.isReady) {
         return "⏳ Waiting for key...";
      }

      try {
        // Use the service to decrypt
        return await EncryptionService.instance.decryptText(ciphertext!, nonce!, mac!);
      } catch (e) {
        debugPrint("Error decrypting message $id: $e");
        return "🔒 Decryption Failed"; 
      }
    }
    // If it's old data or not encrypted, just return the plain content
    return content; 
  }
}