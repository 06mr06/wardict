import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_level.dart';
import '../models/question_mode.dart';
import '../services/word_pool_service.dart';
import 'base_game_provider.dart';

/// Cevaplanan soru bilgisi
class AnsweredQuestion {
  final String prompt;
  final String correctAnswer;
  final String? userAnswer;
  final bool isCorrect;
  
  AnsweredQuestion({
    required this.prompt,
    required this.correctAnswer,
    this.userAnswer,
    required this.isCorrect,
  });
}

class Daily123Provider extends BaseGameProvider {
  UserLevel _currentLevel = UserLevel.a1;
  int _timeLeft = 123;
  Timer? _timer;
  bool _isGameOver = false;

  GeneratedQuestion? _currentQuestion;
  List<String> _shuffledOptions = [];
  int _shuffledCorrectIndex = 0;
  
  // Görülen soru prompt'larını takip et (tekrar engellemek için)
  final Set<String> _usedPrompts = {};
  
  // Doğru ve yanlış cevapları takip et
  final List<AnsweredQuestion> _correctAnswers = [];
  final List<AnsweredQuestion> _wrongAnswers = [];

  // --- State Persistence Keys ---
  static const String _keyScore = 'daily_123_score';
  static const String _keyTime = 'daily_123_time';
  static const String _keyLevel = 'daily_123_level';
  static const String _keyIndex = 'daily_123_index';
  
  // Getter'lar
  List<AnsweredQuestion> get correctAnswers => List.unmodifiable(_correctAnswers);
  List<AnsweredQuestion> get wrongAnswers => List.unmodifiable(_wrongAnswers);

  // --- BaseGameProvider Implementation ---

  @override
  int get totalQuestions => 999; 

  @override
  String get currentPrompt => _currentQuestion?.prompt ?? 'Yükleniyor...';

  @override
  List<String> get currentOptions => _shuffledOptions;

  @override
  int get currentCorrectIndex => _shuffledCorrectIndex;

  @override
  QuestionMode get currentMode {
    if (_currentQuestion == null) return QuestionMode.trToEn;
    switch (_currentQuestion!.mode) {
      case QuestionType.enToTr: return QuestionMode.enToTr;
      case QuestionType.trToEn: return QuestionMode.trToEn;
      default: return QuestionMode.engToEng;
    }
  }

  int get timeLeft => _timeLeft;
  UserLevel get currentLevel => _currentLevel;
  bool get isWin => score >= 123;
  bool get isGameOver => _isGameOver;

  @override
  Future<void> startSession() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Önceki yarım kalan oyunu yükle
    score = prefs.getInt(_keyScore) ?? 0;
    _timeLeft = prefs.getInt(_keyTime) ?? 123;
    final levelStr = prefs.getString(_keyLevel) ?? 'a1';
    _currentLevel = UserLevel.values.firstWhere(
      (e) => e.name == levelStr, 
      orElse: () => UserLevel.a1
    );
    index = prefs.getInt(_keyIndex) ?? 0;
    
    _isGameOver = (_timeLeft <= 0 || score >= 123);
    
    if (!_isGameOver) {
      _startTimer();
      await _loadNextQuestion();
    } else {
      notifyListeners();
    }
  }

  Future<void> resetWithAd() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyScore);
    await prefs.remove(_keyTime);
    await prefs.remove(_keyLevel);
    await prefs.remove(_keyIndex);
    
    score = 0;
    _timeLeft = 123;
    _currentLevel = UserLevel.a1;
    index = 0;
    _isGameOver = false;
    
    // Listeleri temizle
    _usedPrompts.clear();
    _correctAnswers.clear();
    _wrongAnswers.clear();
    
    _startTimer();
    await _loadNextQuestion();
  }

  Future<void> _saveState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyScore, score);
    await prefs.setInt(_keyTime, _timeLeft);
    await prefs.setString(_keyLevel, _currentLevel.name);
    await prefs.setInt(_keyIndex, index);
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (_timeLeft > 0 && !_isGameOver) {
        _timeLeft--;
        
        // Son 5 saniyede titreşim
        if (_timeLeft <= 5 && _timeLeft > 0) {
          final prefs = await SharedPreferences.getInstance();
          final vibrationEnabled = prefs.getBool('vibration_enabled') ?? true;
          if (vibrationEnabled) {
            HapticFeedback.heavyImpact();
          }
        }
        
        _saveState();
        notifyListeners();
      } else {
        _endGame();
      }
    });
  }

  void _endGame() {
    _isGameOver = true;
    _timer?.cancel();
    _saveState(); // Oyun bitiş durumunu da kaydet
    notifyListeners();
  }

  Future<void> _loadNextQuestion() async {
    // Tekrar etmeyen soru bul (maksimum 10 deneme)
    GeneratedQuestion? uniqueQuestion;
    for (int attempt = 0; attempt < 10; attempt++) {
      final questions = WordPoolService.instance.generateQuestionsForLevel(_currentLevel, 5);
      for (final q in questions) {
        if (!_usedPrompts.contains(q.prompt)) {
          uniqueQuestion = q;
          break;
        }
      }
      if (uniqueQuestion != null) break;
    }
    
    // Hala bulunamadıysa, yeni soru al (son çare)
    if (uniqueQuestion == null) {
      final questions = WordPoolService.instance.generateQuestionsForLevel(_currentLevel, 1);
      if (questions.isNotEmpty) {
        uniqueQuestion = questions.first;
      }
    }
    
    if (uniqueQuestion != null) {
      _currentQuestion = uniqueQuestion;
      _usedPrompts.add(uniqueQuestion.prompt);
      _shuffledOptions = List.from(_currentQuestion!.options);
      _shuffledOptions.shuffle();
      _shuffledCorrectIndex = _shuffledOptions.indexOf(_currentQuestion!.options[_currentQuestion!.correctIndex]);
      notifyListeners();
    }
  }

  @override
  Future<void> answer(int selectedIndex, int _) async {
    if (_isGameOver) return;

    final isCorrect = selectedIndex == _shuffledCorrectIndex;
    
    // Cevabı kaydet
    if (_currentQuestion != null) {
      final answered = AnsweredQuestion(
        prompt: _currentQuestion!.prompt,
        correctAnswer: _currentQuestion!.options[_currentQuestion!.correctIndex],
        userAnswer: _shuffledOptions[selectedIndex],
        isCorrect: isCorrect,
      );
      
      if (isCorrect) {
        _correctAnswers.add(answered);
      } else {
        _wrongAnswers.add(answered);
      }
    }
    
    int points = 0;
    switch (_currentLevel) {
      case UserLevel.a1: points = isCorrect ? 2 : 0; break;
      case UserLevel.a2: points = isCorrect ? 3 : -1; break;
      case UserLevel.b1: points = isCorrect ? 5 : -2; break;
      case UserLevel.b2: points = isCorrect ? 7 : -3; break;
      case UserLevel.c1: points = isCorrect ? 9 : -5; break;
      case UserLevel.c2: points = isCorrect ? 11 : -7; break;
    }

    score += points;
    if (score < 0) score = 0;

    if (isCorrect) {
      if (_currentLevel != UserLevel.c2) {
        _currentLevel = _currentLevel.nextLevel;
      }
    } else {
      if (_currentLevel != UserLevel.a1) {
        _currentLevel = _currentLevel.previousLevel;
      }
    }

    if (score >= 123) {
      _endGame();
    } else {
      index++;
      await _saveState();
      await _loadNextQuestion();
    }
  }

  @override
  void nextQuestion() {}

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
