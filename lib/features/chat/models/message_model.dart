import 'package:hive/hive.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

part 'message_model.g.dart';

@HiveType(typeId: 0)
class MessageModel {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String senderId;

  @HiveField(2)
  final String receiverId;

  @HiveField(3)
  final String content;
  
  @HiveField(4)
  final DateTime timestamp;
  
  @HiveField(5)
  final String status;

  @HiveField(6)
  final List<String> participants;

  @HiveField(7)
  final String? repliedToMessageId;

  @HiveField(8)
  final String? repliedToMessageContent;

  @HiveField(9)
  final String? repliedToSenderName;
  
  // --- NEW FIELD ---
  @HiveField(10)
  final String? repliedToSenderId;
  // --- END NEW ---
  @HiveField(11)
  final DateTime? editedAt;

  @HiveField(12)
  final int? editCount;

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
    };
  }


  factory MessageModel.fromDocument(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return MessageModel(
      id: doc.id,
      senderId: data['senderId'] ?? '',
      receiverId: data['receiverId'] ?? '',
      content: data['content'] ?? '',
      timestamp: (data['timestamp'] as Timestamp? ?? Timestamp.now()).toDate(),
      status: data['status'] ?? 'unknown',
      participants: List<String>.from(data['participants'] ?? []),
      repliedToMessageId: data['repliedToMessageId'],
      repliedToMessageContent: data['repliedToMessageContent'],
      repliedToSenderName: data['repliedToSenderName'],
      repliedToSenderId: data['repliedToSenderId'],
      repliedToMessageType: data['repliedToMessageType'], // ✨ Add from map
      repliedToImageUrl: data['repliedToImageUrl'], // ✨ Add from map
      editedAt: (data['editedAt'] as Timestamp?)?.toDate(),
      editCount: data['editCount'],
      messageType: data['messageType'] ?? 'text',
      googleDriveImageId: data['googleDriveImageId'],
      audioUrl: data['audioUrl'],
      audioDuration: (data['audioDuration'] as num?)?.toDouble(),
      localImagePath: null, // Never from server
      uploadStatus: null, // Never from server
      localAudioPath: null, // Never from server
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
      other.localAudioPath == localAudioPath;
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
      localAudioPath.hashCode;
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
}