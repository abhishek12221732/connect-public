class QuestionModel {
  final String id;
  final String question;
  final String category;
  final String subCategory; // Add this new field

  QuestionModel({
    required this.id,
    required this.question,
    required this.category,
    required this.subCategory, // Require it in the constructor
  });

  factory QuestionModel.fromMap(Map<String, dynamic> map, String documentId) {
    return QuestionModel(
      id: documentId,
      question: map['question'] ?? '',
      category: map['category'] ?? 'General',
      subCategory: map['subCategory'] ?? 'Uncategorized', // Default for subCategory
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'question': question,
      'category': category,
      'subCategory': subCategory, // Include it in toMap
    };
  }

  factory QuestionModel.fromJson(Map<String, dynamic> json) {
    return QuestionModel(
      id: json['id'].toString(),
      question: json['question'] ?? '',
      category: json['category'] ?? 'General',
      subCategory: json['subCategory'] ?? 'Uncategorized',
    );
  }
}
