class TipModel {
  final String id;
  final String title;
  final String content;
  final String category;
  final TipPriority priority;
  final Map<String, dynamic>? contextData;
  final DateTime createdAt;
  final bool isDynamic;

  TipModel({
    required this.id,
    required this.title,
    required this.content,
    required this.category,
    this.priority = TipPriority.medium,
    this.contextData,
    DateTime? createdAt,
    this.isDynamic = true,
  }) : createdAt = createdAt ?? DateTime.now();

  factory TipModel.fromMap(Map<String, dynamic> map) {
    return TipModel(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      content: map['content'] ?? '',
      category: map['category'] ?? 'general',
      priority: TipPriority.values.firstWhere(
        (e) => e.toString() == 'TipPriority.${map['priority']}',
        orElse: () => TipPriority.medium,
      ),
      contextData: map['contextData'],
      createdAt: map['createdAt'] != null 
          ? DateTime.parse(map['createdAt']) 
          : DateTime.now(),
      isDynamic: map['isDynamic'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'category': category,
      'priority': priority.toString().split('.').last,
      'contextData': contextData,
      'createdAt': createdAt.toIso8601String(),
      'isDynamic': isDynamic,
    };
  }

  TipModel copyWith({
    String? id,
    String? title,
    String? content,
    String? category,
    TipPriority? priority,
    Map<String, dynamic>? contextData,
    DateTime? createdAt,
    bool? isDynamic,
  }) {
    return TipModel(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      category: category ?? this.category,
      priority: priority ?? this.priority,
      contextData: contextData ?? this.contextData,
      createdAt: createdAt ?? this.createdAt,
      isDynamic: isDynamic ?? this.isDynamic,
    );
  }
}

enum TipPriority {
  low,
  medium,
  high,
  urgent,
}

enum TipCategory {
  communication,
  qualityTime,
  appreciation,
  stress,
  intimacy,
  goals,
  fun,
  trust,
  support,
  conflict,
  general,
  mood,
  checkIn,
} 
