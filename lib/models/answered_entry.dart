import 'package:wardict_skeleton/models/question_mode.dart';

class AnsweredEntry {
  final String prompt;
  final int selectedIndex; // -1 if no selection (time up)
  final int correctIndex;
  final int earnedPoints;
  final QuestionMode mode;
  final String? selectedText; // null if no selection
  final String correctText;

  AnsweredEntry({
    required this.prompt,
    required this.selectedIndex,
    required this.correctIndex,
    required this.earnedPoints,
    required this.mode,
    required this.correctText,
    this.selectedText,
  });
}
