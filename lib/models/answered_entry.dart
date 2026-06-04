import 'question_mode.dart';
import 'powerup.dart';

class AnsweredEntry {
  final String prompt;
  final int selectedIndex; // -1 if no selection (time up)
  final int correctIndex;
  final int earnedPoints;
  final QuestionMode mode;
  final String? selectedText; // null if no selection
  final String correctText;
  final String? turkishMeaning;
  final List<PowerupType> usedPowerups;
  
  // SRS (Spaced Repetition System) Fields
  DateTime? lastReviewedAt;
  int srsLevel; // 0-5 (Leitner boxes)

  AnsweredEntry({
    required this.prompt,
    required this.selectedIndex,
    required this.correctIndex,
    required this.earnedPoints,
    required this.mode,
    required this.correctText,
    this.selectedText,
    this.turkishMeaning,
    this.usedPowerups = const [],
    this.lastReviewedAt,
    this.srsLevel = 0,
  });

  Map<String, dynamic> toJson() {
    return {
      'prompt': prompt,
      'selectedIndex': selectedIndex,
      'correctIndex': correctIndex,
      'earnedPoints': earnedPoints,
      'mode': mode.name,
      'selectedText': selectedText,
      'correctText': correctText,
      'turkishMeaning': turkishMeaning,
      'usedPowerups': usedPowerups.map((e) => e.name).toList(),
      'lastReviewedAt': lastReviewedAt?.toIso8601String(),
      'srsLevel': srsLevel,
    };
  }

  factory AnsweredEntry.fromJson(Map<String, dynamic> json) {
    return AnsweredEntry(
      prompt: json['prompt'] ?? '',
      selectedIndex: json['selectedIndex'] ?? -1,
      correctIndex: json['correctIndex'] ?? 0,
      earnedPoints: json['earnedPoints'] ?? 0,
      mode: QuestionMode.values.firstWhere(
        (e) => e.name == json['mode'],
        orElse: () => QuestionMode.enToTr,
      ),
      correctText: json['correctText'] ?? '',
      selectedText: json['selectedText'],
      turkishMeaning: json['turkishMeaning'],
      usedPowerups: (json['usedPowerups'] as List<dynamic>?)
              ?.map((e) => PowerupType.values.firstWhere(
                    (p) => p.name == e,
                    orElse: () => PowerupType.revealAnswer,
                  ))
              .toList() ??
          [],
      lastReviewedAt: json['lastReviewedAt'] != null ? DateTime.parse(json['lastReviewedAt']) : null,
      srsLevel: json['srsLevel'] ?? 0,
    );
  }
}
