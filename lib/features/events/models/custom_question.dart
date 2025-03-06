class CustomQuestion {
  final String question;
  final bool isRequired;
  final String? answer;

  CustomQuestion({
    required this.question,
    this.isRequired = false,
    this.answer,
  });

  Map<String, dynamic> toJson() {
    return {
      'question': question,
      'isRequired': isRequired,
      'answer': answer,
    };
  }

  factory CustomQuestion.fromJson(Map<String, dynamic> json) {
    return CustomQuestion(
      question: json['question'] as String,
      isRequired: json['isRequired'] as bool? ?? false,
      answer: json['answer'] as String?,
    );
  }
}