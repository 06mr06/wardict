import 'package:flutter/foundation.dart';
import '../models/user_level.dart';
import '../models/quest.dart';
import '../services/quest_service.dart';
import '../services/sentence_cloze_service.dart';
import '../services/word_pool_service.dart';
import '../utils/quest_points_helper.dart';

class FillBlankAnswerRecord {
  final String sentence;
  final String englishFilled;
  final String correctAnswer;
  final String? selectedAnswer;
  final String? selectedMeaningTurkish;
  final bool isCorrect;
  final int points;
  final String? sentenceTurkish;
  final String wordTurkish;
  final String? turkishHighlight;

  const FillBlankAnswerRecord({
    required this.sentence,
    required this.englishFilled,
    required this.correctAnswer,
    this.selectedAnswer,
    this.selectedMeaningTurkish,
    required this.isCorrect,
    required this.points,
    this.sentenceTurkish,
    required this.wordTurkish,
    this.turkishHighlight,
  });
}

class FillBlankPracticeProvider extends ChangeNotifier {
  List<ClozeQuestion> _questions = [];
  final List<FillBlankAnswerRecord> _history = [];
  int _index = 0;
  int _streak = 0;

  List<ClozeQuestion> get questions => _questions;
  int get index => _index;
  int get correctCount => _history.where((h) => h.isCorrect).length;
  int get sessionPoints => _history.fold<int>(0, (s, h) => s + h.points);
  bool get isComplete => _questions.isEmpty || _index >= _questions.length;
  ClozeQuestion? get current =>
      _index < _questions.length ? _questions[_index] : null;
  List<FillBlankAnswerRecord> get history => List.unmodifiable(_history);

  Future<void> startSession(String levelCode) async {
    await WordPoolService.instance.loadWordPool();
    await SentenceClozeService.instance.load();
    _questions = SentenceClozeService.instance
        .buildSession(UserLevel.fromCode(levelCode), questionCount: 10);
    _index = 0;
    _streak = 0;
    _history.clear();
    notifyListeners();
  }

  Future<void> answerQuestion(int selectedIndex, int remainingSeconds) async {
    final q = current;
    if (q == null) return;
    final ok = selectedIndex == q.correctIndex && selectedIndex >= 0;
    int roundPoints = 0;
    if (ok) {
      _streak++;
      roundPoints = duelStyleRoundPoints(
        remainingSeconds: remainingSeconds,
        streakAfterCorrect: _streak,
      );
      QuestService.instance.updateProgress(QuestType.answerQuestions, 1);
      QuestService.instance.updateProgress(QuestType.earnPoints, roundPoints);
      if (remainingSeconds >= 3) {
        QuestService.instance.updateProgress(QuestType.speedAnswer, 1);
      }
      QuestService.instance.updateProgress(
        QuestType.streakCount,
        _streak,
        setExact: true,
      );
    } else {
      _streak = 0;
    }

    final wordTr = (q.correctIndex >= 0 &&
            q.correctIndex < q.optionMeanings.length &&
            q.optionMeanings[q.correctIndex].trim().isNotEmpty)
        ? q.optionMeanings[q.correctIndex].trim()
        : (q.turkishHint?.trim() ?? '');
    final englishFilled = q.sentenceDisplay.replaceAllMapped(
      RegExp(r'_{2,}'),
      (_) => q.correctEnglish,
    );
    String? selMeaning;
    if (selectedIndex >= 0 && selectedIndex < q.optionMeanings.length) {
      final m = q.optionMeanings[selectedIndex].trim();
      if (m.isNotEmpty) selMeaning = m;
    }
    _history.add(
      FillBlankAnswerRecord(
        sentence: q.sentenceDisplay,
        englishFilled: englishFilled,
        correctAnswer: q.correctEnglish,
        selectedAnswer: selectedIndex >= 0 && selectedIndex < q.options.length
            ? q.options[selectedIndex]
            : null,
        selectedMeaningTurkish: selMeaning,
        isCorrect: ok,
        points: roundPoints,
        sentenceTurkish: q.sentenceTurkish?.trim().isNotEmpty == true
            ? q.sentenceTurkish!.trim()
            : null,
        wordTurkish: wordTr,
        turkishHighlight: q.turkishHighlight?.trim().isNotEmpty == true
            ? q.turkishHighlight!.trim()
            : null,
      ),
    );
    notifyListeners();
  }

  void nextQuestion() {
    _index++;
    notifyListeners();
  }
}