import 'package:cloud_firestore/cloud_firestore.dart';

class CheckInModel {
  /// Unique Firestore document ID
  final String id;
  /// User who created the check-in
  final String userId;
  /// Couple ID
  final String coupleId;
  /// When the check-in was created
  final DateTime timestamp;
  /// List of questions for this check-in
  final List<CheckInQuestion> questions;
  /// Answers keyed by question ID
  final Map<String, dynamic> answers;
  /// Whether the check-in is completed
  final bool isCompleted;
  /// When the check-in was completed
  final DateTime? completedAt;
  /// Insights the user chose to share
  final List<String> sharedInsights;
  /// Whether a reminder is set for the next check-in
  final bool reminderSet;
  /// If this check-in was shared with a partner (copied to their collection)
  final bool sharedWithPartner;
  /// If shared, the userId of the partner who shared it
  final String? sharedByUserId;
  /// Insights generated for the user
  final List<String> userInsights;
  /// Tracks if the shared insight has been viewed by the partner.
  final bool isRead; 
  /// Distinguishes between a partial insight and a full check-in share.
  final bool isFullCheckInShared; 

  CheckInModel({
    required this.id,
    required this.userId,
    required this.coupleId,
    required this.timestamp,
    required this.questions,
    required this.answers,
    this.isCompleted = false,
    this.completedAt,
    this.sharedInsights = const [],
    this.reminderSet = false,
    this.sharedWithPartner = false,
    this.sharedByUserId,
    this.userInsights = const [],
    this.isRead = false,
    this.isFullCheckInShared = false,
  });

  /// The factory constructor to create a CheckInModel from a Firestore document.
  factory CheckInModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    return CheckInModel.fromMap(doc.data() ?? {}, doc.id);
  }

  /// Creates a CheckInModel from a map (raw data from Firestore).
  factory CheckInModel.fromMap(Map<String, dynamic> map, String documentId) {
    DateTime? completedAt;
    if (map['completedAt'] != null && map['completedAt'] is Timestamp) {
      completedAt = (map['completedAt'] as Timestamp).toDate();
    } else if (map['timestamp'] != null && map['timestamp'] is Timestamp) {
      completedAt = (map['timestamp'] as Timestamp).toDate();
    }
    
    return CheckInModel(
      id: documentId,
      userId: map['userId'] ?? '',
      coupleId: map['coupleId'] ?? '',
      timestamp: (map['timestamp'] is Timestamp) 
          ? (map['timestamp'] as Timestamp).toDate() 
          : DateTime.now(),
      
      // ✨ [FIXED] Safely parses the 'questions' list, preventing crashes if the field is null.
      questions: (map['questions'] as List<dynamic>? ?? [])
          .map((q) => CheckInQuestion.fromMap(q as Map<String, dynamic>))
          .toList(),
      
      answers: Map<String, dynamic>.from(map['answers'] ?? {}),
      isCompleted: map['isCompleted'] ?? false,
      completedAt: completedAt,
      sharedInsights: List<String>.from(map['sharedInsights'] ?? []),
      reminderSet: map['reminderSet'] ?? false,
      sharedWithPartner: map['sharedWithPartner'] ?? false,
      sharedByUserId: map['sharedByUserId'],
      userInsights: List<String>.from(map['userInsights'] ?? []),

      // ✨ [ADDED] Reads the new fields from the Firestore map.
      isRead: map['isRead'] ?? false,
      isFullCheckInShared: map['isFullCheckInShared'] ?? false,
    );
  }

  /// Converts the CheckInModel object to a map for saving to Firestore.
  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'coupleId': coupleId,
      'timestamp': Timestamp.fromDate(timestamp),
      'questions': questions.map((q) => q.toMap()).toList(),
      'answers': answers,
      'isCompleted': isCompleted,
      'completedAt': completedAt != null ? Timestamp.fromDate(completedAt!) : null,
      'sharedInsights': sharedInsights,
      'reminderSet': reminderSet,
      if (sharedWithPartner) 'sharedWithPartner': true,
      if (sharedByUserId != null) 'sharedByUserId': sharedByUserId,
      'userInsights': userInsights,

      // ✨ [ADDED] Adds new fields to the map for saving to Firestore.
      'isRead': isRead,
      'isFullCheckInShared': isFullCheckInShared,
    };
  }

  /// Creates a copy of the model with optional new values.
  // ✨ [THE FIX] Replace your copyWith method with this complete version.
  CheckInModel copyWith({
    String? id,
    String? userId,
    String? coupleId,
    DateTime? timestamp,
    List<CheckInQuestion>? questions,
    Map<String, dynamic>? answers,
    bool? isCompleted,
    DateTime? completedAt,
    List<String>? sharedInsights,
    bool? reminderSet,
    bool? sharedWithPartner,
    String? sharedByUserId,
    List<String>? userInsights,
    bool? isRead,
    bool? isFullCheckInShared,
  }) {
    return CheckInModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      coupleId: coupleId ?? this.coupleId,
      timestamp: timestamp ?? this.timestamp,
      questions: questions ?? this.questions,
      answers: answers ?? this.answers,
      isCompleted: isCompleted ?? this.isCompleted,
      completedAt: completedAt ?? this.completedAt,
      sharedInsights: sharedInsights ?? this.sharedInsights,
      reminderSet: reminderSet ?? this.reminderSet,
      sharedWithPartner: sharedWithPartner ?? this.sharedWithPartner,
      sharedByUserId: sharedByUserId ?? this.sharedByUserId,
      userInsights: userInsights ?? this.userInsights,
      isRead: isRead ?? this.isRead,
      isFullCheckInShared: isFullCheckInShared ?? this.isFullCheckInShared,
    );
  }
}

// No changes needed below this line //
//==================================//

class CheckInQuestion {
  final String id;
  final String question;
  final QuestionType type;
  final List<String>? options;
  final double? minValue;
  final double? maxValue;
  final String? placeholder;
  final bool isRequired;
  final String category;
  final bool? isTrendBased;

  CheckInQuestion({
    required this.id,
    required this.question,
    required this.type,
    this.options,
    this.minValue,
    this.maxValue,
    this.placeholder,
    this.isRequired = true,
    required this.category,
    this.isTrendBased = false,
  });

  factory CheckInQuestion.fromMap(Map<String, dynamic> map) {
    return CheckInQuestion(
      id: map['id'] ?? '',
      question: map['question'] ?? '',
      type: QuestionType.values.firstWhere(
        (e) => e.toString() == 'QuestionType.${map['type']}',
        orElse: () => QuestionType.slider,
      ),
      options: map['options'] != null 
          ? List<String>.from(map['options']) 
          : null,
      minValue: map['minValue']?.toDouble(),
      maxValue: map['maxValue']?.toDouble(),
      placeholder: map['placeholder'],
      isRequired: map['isRequired'] ?? true,
      category: map['category'] ?? 'general',
      isTrendBased: map['isTrendBased'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'question': question,
      'type': type.toString().split('.').last,
      'options': options,
      'minValue': minValue,
      'maxValue': maxValue,
      'placeholder': placeholder,
      'isRequired': isRequired,
      'category': category,
      'isTrendBased': isTrendBased ?? false,
    };
  }

  CheckInQuestion copyWith({
    String? id,
    String? question,
    QuestionType? type,
    List<String>? options,
    double? minValue,
    double? maxValue,
    String? placeholder,
    bool? isRequired,
    String? category,
    bool? isTrendBased,
  }) {
    return CheckInQuestion(
      id: id ?? this.id,
      question: question ?? this.question,
      type: type ?? this.type,
      options: options ?? this.options,
      minValue: minValue ?? this.minValue,
      maxValue: maxValue ?? this.maxValue,
      placeholder: placeholder ?? this.placeholder,
      isRequired: isRequired ?? this.isRequired,
      category: category ?? this.category,
      isTrendBased: isTrendBased ?? this.isTrendBased,
    );
  }
}

enum QuestionType {
  slider,
  multipleChoice,
  textInput,
  yesNo,
}