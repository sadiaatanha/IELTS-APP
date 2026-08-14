class WritingQuestion {
  final String id;
  final String taskType;
  final String questionType;
  final String title;
  final String questionText;
  final String imageUrl;
  final String difficulty;
  final String source;
  final String? userId; // null = admin/public, non-null = user-added

  WritingQuestion({
    required this.id,
    required this.taskType,
    required this.questionType,
    required this.title,
    required this.questionText,
    required this.imageUrl,
    required this.difficulty,
    required this.source,
    this.userId,
  });

  factory WritingQuestion.fromMap(Map<String, dynamic> map) {
    return WritingQuestion(
      id: map['id'] ?? '',
      taskType: map['task_type'] ?? '',
      questionType: map['question_type'] ?? '',
      title: map['title'] ?? '',
      questionText: map['question_text'] ?? '',
      imageUrl: map['image_url'] ?? '',
      difficulty: map['difficulty'] ?? '',
      source: map['source'] ?? '',
      userId: map['user_id'],
    );
  }
}