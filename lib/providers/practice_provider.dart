import 'package:flutter/material.dart';
import '../models/practice_session.dart';
import '../models/user_level.dart';
import '../services/user_profile_service.dart';
import '../services/word_pool_service.dart';

/// Practice modu için özel provider
/// Adaptif zorluk, oturum takibi ve puanlama yönetir
class PracticeProvider extends ChangeNotifier {
  PracticeSession _session = const PracticeSession();
  int _currentQuestionIndex = 0;
  int _sessionScore = 0;
  List<GeneratedQuestion> _questions = [];
  String _currentQuestionLevel = 'A2'; // Soru seviyesi
  
  // Şuanki soru bilgileri
  GeneratedQuestion? _currentQuestion;
  List<String> _shuffledOptions = [];
  int _shuffledCorrectIndex = 0;
  
  // Cevap geçmişi
  final List<PracticeAnswerRecord> _answerHistory = [];

  // Getters
  PracticeSession get session => _session;
  int get currentQuestionIndex => _currentQuestionIndex;
  int get sessionScore => _sessionScore;
  GeneratedQuestion? get currentQuestion => _currentQuestion;
  List<String> get currentOptions => _shuffledOptions;
  int get currentCorrectIndex => _shuffledCorrectIndex;
  String get currentLevel => _session.currentLevel;
  bool get isSessionComplete => _currentQuestionIndex >= 10;
  int get questionsRemaining => 10 - _currentQuestionIndex;
  List<PracticeAnswerRecord> get answerHistory => List.unmodifiable(_answerHistory);

  /// Yeni practice oturumu başlat
  Future<void> startSession() async {
    final profile = await UserProfileService.instance.loadProfile();
    _session = profile.practiceSession;
    
    // Yeni oturum başlat
    if (_session.totalInSession >= 10) {
      _session = _session.startNewSession();
    }
    
    _currentQuestionIndex = _session.totalInSession;
    _sessionScore = 0;
    _currentQuestionLevel = _session.currentLevel;
    _answerHistory.clear();
    
    // İlk soruyu yükle
    await _loadNextQuestion();
    notifyListeners();
  }

  /// Sonraki soruyu yükle
  Future<void> _loadNextQuestion() async {
    // Seviyeye göre soru getir
    final level = UserLevel.fromCode(_currentQuestionLevel);
    final questions = WordPoolService.instance.generateQuestionsForLevel(level, 1);
    
    if (questions.isNotEmpty) {
      _currentQuestion = questions.first;
      
      // Şıkları karıştır
      _shuffledOptions = List.from(_currentQuestion!.options);
      _shuffledOptions.shuffle();
      _shuffledCorrectIndex = _shuffledOptions.indexOf(_currentQuestion!.options[_currentQuestion!.correctIndex]);
    }
  }

  /// Cevap ver
  Future<void> answer(int selectedIndex, int remainingSeconds) async {
    if (_currentQuestion == null) return;
    
    final isCorrect = selectedIndex == _shuffledCorrectIndex && selectedIndex != -1;
    final questionLevel = _currentQuestionLevel;
    
    // Puan hesapla
    int points = 0;
    if (isCorrect) {
      points = PracticeScoring.calculateCorrectPoints(questionLevel);
    } else if (selectedIndex != -1) {
      points = PracticeScoring.calculateWrongPoints(questionLevel);
    } else {
      // Süre doldu, cevap verilmedi
      points = PracticeScoring.calculateWrongPoints(questionLevel);
    }
    
    _sessionScore += points;
    
    // Cevap kaydı ekle
    _answerHistory.add(PracticeAnswerRecord(
      prompt: _currentQuestion!.prompt,
      correctAnswer: _currentQuestion!.options[_currentQuestion!.correctIndex],
      selectedAnswer: selectedIndex >= 0 ? _shuffledOptions[selectedIndex] : null,
      isCorrect: isCorrect,
      points: points,
      level: questionLevel,
      mode: _currentQuestion!.mode,
    ));
    
    // Session güncelle
    if (isCorrect) {
      _session = _session.onCorrectAnswer();
    } else {
      _session = _session.onWrongAnswer();
    }
    
    // Adaptif zorluk kontrolü (ilk 3 oturumda)
    if (_session.isInAdaptivePeriod) {
      if (isCorrect && _session.shouldAdaptivelyIncreaseLevel) {
        // 2 üst üste doğru - seviye artır
        _currentQuestionLevel = PracticeScoring.getNextLevel(_currentQuestionLevel);
        _session = _session.withLevel(_currentQuestionLevel);
      } else if (!isCorrect && _session.shouldAdaptivelyDecreaseLevel) {
        // 2 üst üste yanlış - seviye düşür
        _currentQuestionLevel = PracticeScoring.getPreviousLevel(_currentQuestionLevel);
        _session = _session.withLevel(_currentQuestionLevel);
      }
    }
    
    _currentQuestionIndex++;
    
    // Profili güncelle
    await UserProfileService.instance.updatePracticeScore(points);
    await UserProfileService.instance.updatePracticeSession(_session);
    
    notifyListeners();
  }

  /// Sonraki soruya geç
  Future<void> nextQuestion() async {
    if (isSessionComplete) return;
    
    await _loadNextQuestion();
    notifyListeners();
  }

  /// Oturumu tamamla
  Future<PracticeSessionResult> completeSession() async {
    _session = _session.completeSession();
    
    // 3. oturumdan sonra seviye değerlendirmesi
    bool leveledUp = false;
    bool leveledDown = false;
    String? newLevel;
    
    if (!_session.isInAdaptivePeriod) {
      if (_session.canLevelUp) {
        // 7+ doğru - seviye artır
        final nextLevel = PracticeScoring.getNextLevel(_session.currentLevel);
        if (nextLevel != _session.currentLevel) {
          _session = _session.withLevel(nextLevel);
          leveledUp = true;
          newLevel = nextLevel;
        }
      } else if (_session.shouldLevelDown) {
        // 2 oturum üst üste 3 veya altında - seviye düşür
        final prevLevel = PracticeScoring.getPreviousLevel(_session.currentLevel);
        if (prevLevel != _session.currentLevel) {
          _session = _session.withLevel(prevLevel);
          leveledDown = true;
          newLevel = prevLevel;
        }
      }
    }
    
    // Profili güncelle
    await UserProfileService.instance.updatePracticeSession(_session);
    
    // Cache'i temizle (profil güncellemesi için)
    UserProfileService.instance.clearCache();
    
    return PracticeSessionResult(
      totalQuestions: 10,
      correctAnswers: _session.correctInSession,
      sessionScore: _sessionScore,
      leveledUp: leveledUp,
      leveledDown: leveledDown,
      newLevel: newLevel,
      currentLevel: _session.currentLevel,
      answerHistory: _answerHistory,
    );
  }

  /// Yeni bir tam oturum başlat (sıfırdan)
  Future<void> resetAndStartNewSession() async {
    final profile = await UserProfileService.instance.loadProfile();
    _session = PracticeSession(currentLevel: profile.practiceSession.currentLevel);
    _currentQuestionIndex = 0;
    _sessionScore = 0;
    _currentQuestionLevel = _session.currentLevel;
    _answerHistory.clear();
    
    await UserProfileService.instance.updatePracticeSession(_session);
    await _loadNextQuestion();
    notifyListeners();
  }
}

/// Cevap kaydı
class PracticeAnswerRecord {
  final String prompt;
  final String correctAnswer;
  final String? selectedAnswer;
  final bool isCorrect;
  final int points;
  final String level;
  final QuestionType mode;

  const PracticeAnswerRecord({
    required this.prompt,
    required this.correctAnswer,
    this.selectedAnswer,
    required this.isCorrect,
    required this.points,
    required this.level,
    required this.mode,
  });
}

/// Oturum sonucu
class PracticeSessionResult {
  final int totalQuestions;
  final int correctAnswers;
  final int sessionScore;
  final bool leveledUp;
  final bool leveledDown;
  final String? newLevel;
  final String currentLevel;
  final List<PracticeAnswerRecord> answerHistory;

  const PracticeSessionResult({
    required this.totalQuestions,
    required this.correctAnswers,
    required this.sessionScore,
    this.leveledUp = false,
    this.leveledDown = false,
    this.newLevel,
    required this.currentLevel,
    required this.answerHistory,
  });

  double get accuracy => totalQuestions > 0 ? correctAnswers / totalQuestions : 0;
}
