import 'question_mode.dart';

class Question {
  final String prompt;
  final List<String> options;
  final int answerIndex;
  final QuestionMode mode;
  final int baseScore;

  Question({
    required this.prompt,
    required this.options,
    required this.answerIndex,
    required this.mode,
    this.baseScore = 10,
  });

  int get correctIndex => answerIndex;
}
