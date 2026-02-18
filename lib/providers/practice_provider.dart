import '../services/quest_service.dart';
import '../models/quest.dart';
import '../models/practice_session.dart';
import '../models/user_level.dart';
import '../models/question_mode.dart';
import '../services/user_profile_service.dart';
import '../services/word_pool_service.dart';
import '../services/achievement_service.dart';
import 'base_game_provider.dart';

/// Practice modu için özel provider
class PracticeProvider extends BaseGameProvider {
    // 5'lik blok ilerlemesi ve duel unlock
    int get sessionsInRow => _session.sessionsInRow;
    bool get duelUnlocked => _session.duelUnlocked;
    int get correctInSession => _session.correctInSession;
    int get levelStreak => _session.levelStreak;
  PracticeSession _session = const PracticeSession();
  
  // Internal session specific state
  List<GeneratedQuestion> _questions = [];
  String _currentQuestionLevel = 'A2'; // Soru seviyesi
  int _currentStreak = 0; // Dinamik zorluk için doğru cevap serisi
  
  // Şuanki soru bilgileri - Base getterlar için
  GeneratedQuestion? _currentQuestion;
  List<String> _shuffledOptions = [];
  int _shuffledCorrectIndex = 0;
  
  // Cevap geçmişi
  final List<PracticeAnswerRecord> _answerHistory = [];

  // Önceki yanlış kelimeleri saklamak için alan
  List<String> _previousWrongWords = [];

  // --- BaseGameProvider Implementation ---
  
  @override
  int get totalQuestions => 10;
  
  @override
  String get currentPrompt => _currentQuestion?.prompt ?? 'Loading...';
  
  @override
  List<String> get currentOptions => _shuffledOptions;
  
  @override
  int get currentCorrectIndex => _shuffledCorrectIndex;
  
  @override
  QuestionMode get currentMode {
    if (_currentQuestion == null) return QuestionMode.trToEn;
    switch (_currentQuestion!.mode) {
      case QuestionType.enToTr:
        return QuestionMode.enToTr;
      case QuestionType.trToEn:
        return QuestionMode.trToEn;
      case QuestionType.synonym:
      case QuestionType.antonym:
      case QuestionType.relation:
        return QuestionMode.engToEng;
    }
  }

  GeneratedQuestion? get currentQuestion => _currentQuestion;

  @override 
  void nextQuestion() {
     _nextQuestionInternal();
  }

  // --- Specific Getters ---
  PracticeSession get session => _session;
  int get currentQuestionIndex => index; // Using Base 'index'
  int get sessionScore => score; // Using Base 'score'
  @override
  String get currentLevel => _session.currentLevel;
  @override
  bool get isSessionComplete => _answerHistory.length >= 10;
  int get questionsRemaining => 10 - _answerHistory.length;
  List<PracticeAnswerRecord> get answerHistory => List.unmodifiable(_answerHistory);
  int get totalSessionsCompleted => _session.totalSessionsCompleted;

  /// Yeni practice oturumu başlat
  @override
  Future<void> startSession() async {
    final profile = await UserProfileService.instance.loadProfile();
    _session = profile.practiceSession;
    // Yeni oturum başlat
    if (_session.totalInSession >= 10) {
      // Seviye değiştiyse blok baştan başlar
      bool levelChanged = false;
      if (_session.lastLevel != null && _session.lastLevel != _session.currentLevel) {
        levelChanged = true;
      }
      _session = _session.startNewSession(levelChanged: levelChanged);
    }
    
    // Start fresh at A2 for the very first placement test session
    if (_session.totalSessionsCompleted == 0) {
      // Ensure we start at A2 if this is the very first time
      if (_session.currentLevel != 'A2') {
         _session = PracticeSession(currentLevel: 'A2');
      }
    }
    
    // Sanity Check: If total sessions < 5, duel CANNOT be unlocked yet.
    // This fixes issues with dirty data or premature unlocks.
    if (_session.totalSessionsCompleted < 5 && _session.duelUnlocked) {
      _session = PracticeSession(
        sessionNumber: _session.sessionNumber,
        correctInSession: _session.correctInSession,
        totalInSession: _session.totalInSession,
        consecutiveCorrect: _session.consecutiveCorrect,
        consecutiveWrong: _session.consecutiveWrong,
        currentLevel: _session.currentLevel,
        totalSessionsCompleted: _session.totalSessionsCompleted,
        levelStreak: _session.levelStreak,
        lastLevel: _session.lastLevel,
        lastTwoSessionsCorrectCount: _session.lastTwoSessionsCorrectCount,
        consecutiveHighSuccess: _session.consecutiveHighSuccess,
        consecutiveLowSuccess: _session.consecutiveLowSuccess,
        sessionsInRow: _session.sessionsInRow,
        duelUnlocked: false, // FORCE FALSE
      );
    }

    // Yüklenen seanstaki tamamlanan soru sayısına göre indeksi ayarla
    index = _session.totalInSession;
    score = 0;
    _currentQuestionLevel = _session.currentLevel;
    _answerHistory.clear();
    
    // Kelime havuzunu yükle
    await WordPoolService.instance.loadWordPool();
    
    // 10 benzersiz soru üret
    _questions = WordPoolService.instance.generateQuestions70_30(
      UserLevel.fromCode(_currentQuestionLevel),
      previousWrongWords: _previousWrongWords,
    );
    // İlk soruyu yükle
    _currentStreak = 0;
    await _loadNextQuestion();
    notifyListeners();
  }

  /// Sonraki soruyu yükle
  Future<void> _loadNextQuestion() async {
    // 10'luk oturumda önceden üretilmiş sorulardan sıradakini al
    if (index < _questions.length) {
      _currentQuestion = _questions[index];
      _shuffledOptions = List.from(_currentQuestion!.options);
      _shuffledOptions.shuffle();
      _shuffledCorrectIndex = _shuffledOptions.indexOf(_currentQuestion!.options[_currentQuestion!.correctIndex]);
      
      // Soru seviyesini güncelle
      _currentQuestionLevel = _currentQuestion!.level;
    } else {
      _currentQuestion = null;
    }
  }

  /// Cevap ver
  @override
  Future<void> answer(int selectedIndex, int remainingSeconds) async {
    if (_currentQuestion == null) return;
    
    final isCorrect = selectedIndex == _shuffledCorrectIndex && selectedIndex != -1;
    final questionLevel = _currentQuestionLevel;
    
    // Puan hesaplanmıyor - sadece doğru/yanlış takip ediliyor
    const int points = 0;
    
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
      _currentStreak++;
    } else {
      _session = _session.onWrongAnswer();
      _currentStreak = 0; // Hata yapınca seri sıfırlanır
      // Yanlış cevap verildiğinde kelimeyi önceki yanlışlar listesine ekle
      _previousWrongWords.add(_currentQuestion!.options[_currentQuestion!.correctIndex]);
    }
    
    // NOT: index burada artmıyor, _nextQuestionInternal içinde artacak
    // Böylece yeni soru gelene kadar UI'daki soru numarası sabit kalır.
    
    // Profili güncelle (puan güncellemesi kaldırıldı)
    await UserProfileService.instance.updatePracticeSession(_session);
    
    // Günlük görev ilerlemesini güncelle
    if (isCorrect) {
      QuestService.instance.updateProgress(QuestType.answerQuestions, 1);
    }
    
    notifyListeners();
  }

  /// Sonraki soruya geç
  Future<void> _nextQuestionInternal() async {
    if (isSessionComplete) return;
    index++; // İndeksi şimdi artırıyoruz
    await _loadNextQuestion();
    notifyListeners();
  }

  /// Oturumu tamamla (seviye tespit sistemi)
  Future<PracticeSessionResult> completeSession() async {
    _session = _session.completeSession();

    bool leveledUp = false;
    bool leveledDown = false;
    String? newLevel;

    // Seviye değişimi kontrolü
    // İlk 5 oturum (Placement Test): Anında seviye atlama/düşme
    // Normal Practice: 2 kere üst üste %70+ (artış) veya %30- (düşüş)
    
    bool shouldLevelUp = false;
    bool shouldLevelDown = false;

    if (_session.totalSessionsCompleted <= 5) {
      // Placement Phase: Anında tepki
      if (_session.correctInSession >= 7) shouldLevelUp = true;
      if (_session.correctInSession <= 3) shouldLevelDown = true;
    } else {
      // Normal Phase: 2'li seri kuralı
      if (_session.consecutiveHighSuccess >= 2) shouldLevelUp = true;
      if (_session.consecutiveLowSuccess >= 2) shouldLevelDown = true;
    }

    if (shouldLevelUp) {
      final nextLevel = PracticeScoring.getNextLevel(_session.currentLevel);
      if (nextLevel != _session.currentLevel) {
        _session = _session.withLevel(nextLevel);
        leveledUp = true;
        newLevel = nextLevel;
        await UserProfileService.instance.updateLevel(UserLevel.fromCode(nextLevel));
      }
    } else if (shouldLevelDown && _session.currentLevel != 'A1') {
      final prevLevel = PracticeScoring.getPreviousLevel(_session.currentLevel);
      if (prevLevel != _session.currentLevel) {
        _session = _session.withLevel(prevLevel);
        leveledDown = true;
        newLevel = prevLevel;
        await UserProfileService.instance.updateLevel(UserLevel.fromCode(prevLevel));
      }
    }
    
    // 5. Oyun sonu: Placement Test bitişi ve ELO ataması
    if (_session.totalSessionsCompleted == 5) {
      // Seviyeye göre başlangıç ELO'sunu ata
      await UserProfileService.instance.assignInitialEloByLevel(
        UserLevel.fromCode(_session.currentLevel)
      );
      
      // Testin tamamlandığını işaretle
      await UserProfileService.instance.markPlacementTestCompleted();
    }

    // Profili güncelle (her durumda session güncel)
    await UserProfileService.instance.updatePracticeSession(_session);
    
    // Günlük görev ilerlemesini güncelle (Alıştırma tamamlama)
    QuestService.instance.updateProgress(QuestType.playPractice, 1);
    
    // Görev: Kusursuz (10/10)
    if (_session.correctInSession == 10) {
      QuestService.instance.updateProgress(QuestType.perfectPractice, 1);
    }
    
    // Seviye serisi başarımı kontrol et (7 maç kuralı)
    if (_session.levelStreak >= 7) {
      final achievementId = 'lvl_${_session.currentLevel.toLowerCase()}';
      await AchievementService.instance.updateAchievementProgressById(achievementId, 7, setExact: true);
    }
    
    // Cache'i temizle (profil güncellemesi için)
    UserProfileService.instance.clearCache();
    
    // Oturum sonunda yanlış yapılan kelimeleri kaydet
    _previousWrongWords = _answerHistory
        .where((a) => !a.isCorrect && a.selectedAnswer != null)
        .map((a) => a.correctAnswer)
        .toList();
    
    return PracticeSessionResult(
      totalQuestions: 10,
      correctAnswers: _session.correctInSession,
      sessionScore: 0, // Puan hesaplanmıyor
      leveledUp: leveledUp,
      leveledDown: leveledDown,
      newLevel: newLevel,
      currentLevel: _session.currentLevel,
      answerHistory: _answerHistory,
      consecutiveHighSuccess: 0,
      consecutiveLowSuccess: 0,
      sessionsInRow: _session.sessionsInRow,
      isPlacementComplete: _session.duelUnlocked && _session.totalSessionsCompleted == 5,
    );
  }

  /// Yeni bir tam oturum başlat (sıfırdan)
  Future<void> resetAndStartNewSession() async {
    final profile = await UserProfileService.instance.loadProfile();
    _session = PracticeSession(currentLevel: profile.practiceSession.currentLevel);
    index = 0;
    score = 0;
    _currentQuestionLevel = _session.currentLevel;
    _answerHistory.clear();
    
    await UserProfileService.instance.updatePracticeSession(_session);
    await _loadNextQuestion();
    notifyListeners();
  }

  /// Profile'dan session durumunu yükle (ana sayfada göstermek için)
  Future<void> loadSessionFromProfile() async {
    final profile = await UserProfileService.instance.reloadProfile();
    _session = profile.practiceSession;
    notifyListeners();
  }
}

// ... classes PracticeAnswerRecord, PracticeSessionResult (unchanged)
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

class PracticeSessionResult {
  final int totalQuestions;
  final int correctAnswers;
  final int sessionScore;
  final bool leveledUp;
  final bool leveledDown;
  final String? newLevel;
  final String currentLevel;
  final List<PracticeAnswerRecord> answerHistory;
  final int consecutiveHighSuccess; // Üst üste yüksek başarı sayısı
  final int consecutiveLowSuccess;  // Üst üste düşük başarı sayısı
  final int sessionsInRow; // Seviye tespitinde kaç oturum oynandı
  final bool isPlacementComplete;

  const PracticeSessionResult({
    required this.totalQuestions,
    required this.correctAnswers,
    required this.sessionScore,
    this.leveledUp = false,
    this.leveledDown = false,
    this.newLevel,
    required this.currentLevel,
    required this.answerHistory,
    this.consecutiveHighSuccess = 0,
    this.consecutiveLowSuccess = 0,
    required this.sessionsInRow,
    this.isPlacementComplete = false,
  });

  double get accuracy => totalQuestions > 0 ? correctAnswers / totalQuestions : 0;
  
  /// %70+ başarı mı?
  bool get hasHighSuccess => correctAnswers >= 7;
  
  /// %30- başarısızlık mı?
  bool get hasLowSuccess => correctAnswers <= 3;
}
