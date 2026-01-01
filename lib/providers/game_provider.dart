import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/quest_service.dart';
import '../services/achievement_service.dart';
import '../models/quest.dart';
import '../models/achievement.dart';
import '../models/question.dart';
import '../models/question_mode.dart';
import '../models/answered_entry.dart';
import '../models/powerup.dart';
import '../services/word_pool_service.dart';
import 'base_game_provider.dart';

class GameProvider extends BaseGameProvider {
  static const String _savedPoolKey = 'my_words_saved_pool';
  
  late List<Question> _questions;
  List<Question> get questions => _questions;
  late List<List<String>> _shuffledOptions; 
  late List<int> _shuffledCorrectIndexes;  // Her soru için doğru şıkkın yeni indexi
  
  // Note: 'index', 'score' are now in BaseGameProvider
  // We keep 'totalScore' alias or map it?
  // Base has 'score'. Let's use 'score' as the primary score.
  // We will alias 'totalScore' to 'score' for backward compatibility if needed, 
  // or just rename usages.
  
  int lastScore = 0;
  final List<AnsweredEntry> history = [];
  final List<AnsweredEntry> savedPool = [];
  // streak is in BaseGameProvider
  int maxStreak = 0;
  int correctCount = 0;

  // Model sırası ve geçişi için
  late List<QuestionMode> _modelOrder;
  late List<int> _modelStartIndexes;
  QuestionMode? _currentModel;

  GameProvider() {
    _questions = [];
    _shuffledOptions = [];
    _shuffledCorrectIndexes = [];
    _modelOrder = [];
    _modelStartIndexes = [];
    // Load persisted My Words pool
    loadSavedPool();
  }

  // --- BaseGameProvider Implementation ---

  @override
  int get totalQuestions => _questions.length;

  @override
  String get currentPrompt {
    if (isFinished) return "Game Over";
    return _questions[index].prompt;
  }

  @override
  List<String> get currentOptions => _shuffledOptions[index];

  @override
  int get currentCorrectIndex => _shuffledCorrectIndexes[index];

  @override
  QuestionMode get currentMode => _currentModel ?? QuestionMode.trToEn;

  // Specific Accessor
  Question get currentQuestionModel => _questions[index];
  // Alias for backward compatibility
  Question get currentQuestion => currentQuestionModel;
  
  int get questionCount => totalQuestions;
  
  @override
  void nextQuestion() {
    goNext();
  }

  @override
  Future<void> answer(int selected, int remainingSeconds, {List<PowerupType> usedPowerups = const []}) async {
    // This matches the signature of BaseGameProvider (Future void vs void)
    // We can make it async to satisfy interface or keep it sync inside.
    _answerInternal(selected, remainingSeconds, usedPowerups: usedPowerups);
  }

  @override
  void startSession() {
     // Default start? might need arguments.
     // For now this might be unused or we can have specific start methods
  }
  
  // --- Existing Logic ---

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
    score = 0; // Reset Base score
    lastScore = 0;
    history.clear();
    // savedPool is persistent - don't clear it
    streak = 0; // Reset Base streak
    maxStreak = 0;
    correctCount = 0;
    _currentModel = _questions.isNotEmpty ? _questions[0].mode : null;
    notifyListeners();
  }

  void _answerInternal(int selected, int remainingSeconds, {List<PowerupType> usedPowerups = const []}) {
    if (isFinished) return;
    
    final q = currentQuestionModel;
    final correctIndex = currentCorrectIndex;
    final options = currentOptions;
    
    double multiplier = 1.0;
    if (remainingSeconds >= 8) {
      multiplier = 1.5;
    } else if (remainingSeconds >= 5) {
      multiplier = 1.2;
    } else if (remainingSeconds >= 3) {
      multiplier = 1.0;
    } else {
      multiplier = 0.7;
    }

    double streakBonusMultiplier = 1.0;
    final isCorrect = selected == correctIndex && selected != -1;
    
    if (isCorrect) {
      streak++;
      correctCount++;
      if (streak > maxStreak) maxStreak = streak;
      streakBonusMultiplier += (streak - 1) * 0.1; 
      if (streakBonusMultiplier > 1.3) streakBonusMultiplier = 1.3;
      
      // Başarım: En yüksek seri
      AchievementService.instance.updateProgress(AchievementCategory.skill, streak, setExact: true);
    } else {
      streak = 0;
    }
    
    if (isCorrect) {
      lastScore = (q.baseScore * multiplier * streakBonusMultiplier).round();
      lastScore += streak * 2;
    } else {
      lastScore = 0;
    }
    
    score += lastScore; // Update Base score
    
    // Günlük görev ilerlemesini güncelle
    if (isCorrect) {
      QuestService.instance.updateProgress(QuestType.answerQuestions, 1);
      QuestService.instance.updateProgress(QuestType.earnPoints, lastScore);
    }
    
    history.add(AnsweredEntry(
      prompt: q.prompt,
      selectedIndex: selected,
      correctIndex: correctIndex,
      earnedPoints: lastScore,
      mode: q.mode,
      correctText: options[correctIndex],
      selectedText: selected == -1 ? null : options[selected],
      usedPowerups: usedPowerups,
    ));
    
    // UI should call goNext() manually after delay
  }
  
  int get answeredCount => history.length;
  double get accuracy => answeredCount == 0 ? 0 : correctCount / answeredCount;

  /// SharedPreferences'tan My Words havuzunu yükle
  Future<void> loadSavedPool() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_savedPoolKey);
      if (jsonString != null && jsonString.isNotEmpty) {
        final List<dynamic> jsonList = json.decode(jsonString);
        savedPool.clear();
        savedPool.addAll(
          jsonList.map((e) => AnsweredEntry.fromJson(e as Map<String, dynamic>)).toList(),
        );
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading saved pool: $e');
    }
  }

  /// My Words havuzunu SharedPreferences'a kaydet
  Future<void> _saveSavedPool() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = savedPool.map((e) => e.toJson()).toList();
      await prefs.setString(_savedPoolKey, json.encode(jsonList));
    } catch (e) {
      debugPrint('Error saving saved pool: $e');
    }
  }

  void addToPool(AnsweredEntry entry) {
    final exists = savedPool.any((e) => e.prompt == entry.prompt && e.correctText == entry.correctText && e.mode == entry.mode);
    if (!exists) {
      savedPool.add(entry);
      _saveSavedPool();
      notifyListeners();
    }
  }

  bool isSaved(AnsweredEntry entry) {
    return savedPool.any((e) => e.prompt == entry.prompt && e.correctText == entry.correctText && e.mode == entry.mode);
  }

  void removeFromPool(AnsweredEntry entry) {
    savedPool.removeWhere((e) => e.prompt == entry.prompt && e.correctText == entry.correctText && e.mode == entry.mode);
    _saveSavedPool();
    notifyListeners();
  }

  void toggleInPool(AnsweredEntry entry) {
    if (isSaved(entry)) {
      removeFromPool(entry);
    } else {
      addToPool(entry);
    }
  }

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
    score = 0;
    lastScore = 0;
    history.clear();
    // savedPool is persistent - don't clear it
    streak = 0;
    maxStreak = 0;
    correctCount = 0;
    _currentModel = _questions.isNotEmpty ? _questions[0].mode : null;
    notifyListeners();
  }
}
