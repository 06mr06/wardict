import 'package:flutter/material.dart';
import '../models/question.dart';
import '../models/question_mode.dart';
import '../models/answered_entry.dart';
import '../services/word_pool_service.dart';


class GameProvider extends ChangeNotifier {
  late List<Question> _questions;
  late List<List<String>> _shuffledOptions; // Her soru için karıştırılmış şıklar
  late List<int> _shuffledCorrectIndexes;  // Her soru için doğru şıkkın yeni indexi
  int index = 0;
  int totalScore = 0;
  int lastScore = 0;
  final List<AnsweredEntry> history = [];
  final List<AnsweredEntry> savedPool = [];
  int streak = 0;
  int maxStreak = 0;
  int correctCount = 0;

  // Model sırası ve geçişi için
  late List<QuestionMode> _modelOrder;
  late List<int> _modelStartIndexes; // Her modelin başladığı index
  QuestionMode? _currentModel;

  bool get isFinished => index >= _questions.length;
  int get questionCount => _questions.length;

  Question get currentQuestion {
    if (isFinished) {
      throw StateError('No more questions available');
    }
    return _questions[index];
  }

  List<String> get currentOptions => _shuffledOptions[index];
  int get currentCorrectIndex => _shuffledCorrectIndexes[index];
  QuestionMode? get currentModel => _currentModel;

  void startPractice(List<Question> pool) {
    // Soruları model sırasına göre sırala
    _modelOrder = [
      QuestionMode.trToEn,
      QuestionMode.enToTr,
      QuestionMode.engToEng,
    ];
    _questions = [];
    _modelStartIndexes = [];
    for (final mode in _modelOrder) {
      final modelQuestions = pool.where((q) => q.mode == mode).toList();
      modelQuestions.shuffle();
      _modelStartIndexes.add(_questions.length);
      _questions.addAll(modelQuestions);
    }
    _shuffledOptions = [];
    _shuffledCorrectIndexes = [];
    for (final q in _questions) {
      final opts = List<String>.from(q.options);
      opts.shuffle();
      _shuffledOptions.add(opts);
      _shuffledCorrectIndexes.add(opts.indexOf(q.options[q.answerIndex]));
    }
    index = 0;
    totalScore = 0;
    lastScore = 0;
    history.clear();
    savedPool.clear();
    streak = 0;
    maxStreak = 0;
    correctCount = 0;
    _currentModel = _questions.isNotEmpty ? _questions[0].mode : null;
    notifyListeners();
  }

  void answer(int selected, int remainingSeconds) {
    final q = currentQuestion;
    final correctIndex = currentCorrectIndex;
    final options = currentOptions;
    double multiplier = 1.0;
    // Hızlı cevap verene bonus, yavaş olana ceza
    if (remainingSeconds >= 8) {
      multiplier = 1.5;
    } else if (remainingSeconds >= 5) {
      multiplier = 1.2;
    } else if (remainingSeconds >= 3) {
      multiplier = 1.0;
    } else {
      multiplier = 0.7;
    }
    // Streak handling and streak bonus multiplier (capped)
    double streakBonusMultiplier = 1.0;
    final isCorrect = selected == correctIndex && selected != -1;
    if (isCorrect) {
      streak++;
      correctCount++;
      if (streak > maxStreak) maxStreak = streak;
      streakBonusMultiplier += (streak - 1) * 0.1; // +10% per streak after first
      if (streakBonusMultiplier > 1.3) {
        streakBonusMultiplier = 1.3; // cap at +30%
      }
    } else {
      streak = 0;
    }
    if (isCorrect) {
      lastScore = (q.baseScore * multiplier * streakBonusMultiplier).round();
      // Combo bonus: streak x2 extra points
      lastScore += streak * 2;
    } else {
      lastScore = 0;
    }
    totalScore += lastScore;
    // Record this answer in history (selected can be -1)
    history.add(AnsweredEntry(
      prompt: q.prompt,
      selectedIndex: selected,
      correctIndex: correctIndex,
      earnedPoints: lastScore,
      mode: q.mode,
      correctText: options[correctIndex],
      selectedText: selected == -1 ? null : options[selected],
    ));
    // Index ilerletme ve bildirim goNext() ile yapılacak
  }
  int get answeredCount => history.length;
  double get accuracy => answeredCount == 0 ? 0 : correctCount / answeredCount;

  void addToPool(AnsweredEntry entry) {
    final exists = savedPool.any((e) => e.prompt == entry.prompt && e.correctText == entry.correctText && e.mode == entry.mode);
    if (!exists) {
      savedPool.add(entry);
      notifyListeners();
    }
  }

  bool isSaved(AnsweredEntry entry) {
    return savedPool.any((e) => e.prompt == entry.prompt && e.correctText == entry.correctText && e.mode == entry.mode);
  }

  void removeFromPool(AnsweredEntry entry) {
    savedPool.removeWhere((e) => e.prompt == entry.prompt && e.correctText == entry.correctText && e.mode == entry.mode);
    notifyListeners();
  }

  void toggleInPool(AnsweredEntry entry) {
    if (isSaved(entry)) {
      removeFromPool(entry);
    } else {
      addToPool(entry);
    }
  }
  // Soruyu ilerlet ve gerekli state güncellemelerini yap
  void goNext() {
    if (isFinished) return;
    index++;
    if (!isFinished) {
      final nextMode = _questions[index].mode;
      if (nextMode != _currentModel) {
        _currentModel = nextMode;
      }
    }
    notifyListeners();
  }

  /// Yeni soru sistemi ile practice başlat (GeneratedQuestion listesi ile)
  void startPracticeWithGenerated(List<GeneratedQuestion> generatedQuestions) {
    _questions = generatedQuestions.map((gq) {
      // QuestionType -> QuestionMode dönüşümü
      QuestionMode mode;
      switch (gq.mode) {
        case QuestionType.enToTr:
          mode = QuestionMode.enToTr;
          break;
        case QuestionType.trToEn:
          mode = QuestionMode.trToEn;
          break;
        case QuestionType.synonym:
        case QuestionType.antonym:
        case QuestionType.relation:
          mode = QuestionMode.engToEng;
          break;
      }
      return Question(
        prompt: gq.prompt,
        options: gq.options,
        answerIndex: gq.correctIndex,
        mode: mode,
      );
    }).toList();

    _shuffledOptions = [];
    _shuffledCorrectIndexes = [];
    for (final q in _questions) {
      final opts = List<String>.from(q.options);
      opts.shuffle();
      _shuffledOptions.add(opts);
      _shuffledCorrectIndexes.add(opts.indexOf(q.options[q.answerIndex]));
    }
    index = 0;
    totalScore = 0;
    lastScore = 0;
    history.clear();
    savedPool.clear();
    streak = 0;
    maxStreak = 0;
    correctCount = 0;
    _currentModel = _questions.isNotEmpty ? _questions[0].mode : null;
    notifyListeners();
  }
}
