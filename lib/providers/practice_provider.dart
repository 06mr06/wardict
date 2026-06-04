import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../services/quest_service.dart';
import '../models/quest.dart';
import '../models/practice_session.dart';
import '../models/user_level.dart';
import '../models/question_mode.dart';
import '../services/user_profile_service.dart';
import '../services/word_pool_service.dart';
import '../services/achievement_service.dart';
import '../services/word_category_service.dart';
import '../utils/quest_points_helper.dart';
import 'base_game_provider.dart';

/// Practice modu için özel provider
class PracticeProvider extends BaseGameProvider {
  // 3 oturumluk placement ilerlemesi ve duel unlock
  int get sessionsInRow => _session.sessionsInRow;
  bool get duelUnlocked => _session.duelUnlocked;
  int get correctInSession => _session.correctInSession;
  PracticeSession _session = const PracticeSession();

  // Internal session specific state
  List<GeneratedQuestion> _questions = [];
  String _currentQuestionLevel = 'B1'; // Soru seviyesi

  // Şuanki soru bilgileri - Base getterlar için
  GeneratedQuestion? _currentQuestion;
  List<String> _shuffledOptions = [];
  List<String> _shuffledOptionMeanings = [];
  int _shuffledCorrectIndex = 0;

  // Cevap geçmişi
  final List<PracticeAnswerRecord> _answerHistory = [];

  // Önceki yanlış kelimeleri saklamak için alan
  List<String> _previousWrongWords = [];

  // Seçili kelime paketleri
  List<String> _selectedPacks = [];
  List<String> get selectedPacks => _selectedPacks;

  void setSelectedPacks(List<String> packs) {
    _selectedPacks = List.from(packs);
    notifyListeners();
  }

  // --- BaseGameProvider Implementation ---

  @override
  int get totalQuestions => 10;

  @override
  String get currentPrompt => _currentQuestion?.prompt ?? 'Loading...';

  @override
  List<String> get currentOptions => _shuffledOptions;

  @override
  List<String> get currentOptionMeanings => _shuffledOptionMeanings;

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
  String get currentLevel => _session.currentLevel;
  bool get isSessionComplete => _answerHistory.length >= 10;
  int get questionsRemaining => 10 - _answerHistory.length;
  List<PracticeAnswerRecord> get answerHistory =>
      List.unmodifiable(_answerHistory);
  int get totalSessionsCompleted => _session.totalSessionsCompleted;
  int get levelStreak => _session.levelStreak;

  /// Yeni practice oturumu başlat
  @override
  Future<void> startSession() async {
    try {
      UserProfileService.instance.clearCache();
      final profile = await UserProfileService.instance.loadProfile();
      _session = profile.practiceSession;
      _previousWrongWords = List<String>.from(profile.wrongWords);

      debugPrint(
          '🎲 Practice startSession - isActive: ${_session.isActiveSession}, totalInSession: ${_session.totalInSession}, session: ${_session.toJson()}');

      // Kaldığı yerden devam edebilir mi?
      if (_session.isActiveSession && _session.currentQuestionsJson != null) {
        debugPrint(
            '⏮️ Resuming existing session (profile totalInSession: ${_session.totalInSession})');
        try {
          final List<dynamic> questionsList =
              jsonDecode(_session.currentQuestionsJson!);
          _questions =
              questionsList.map((q) => GeneratedQuestion.fromJson(q)).toList();

          if (_session.answerHistoryJson != null) {
            final List<dynamic> historyList =
                jsonDecode(_session.answerHistoryJson!);
            _answerHistory.clear();
            _answerHistory.addAll(
                historyList.map((h) => PracticeAnswerRecord.fromJson(h)));
          }

          if (_questions.isEmpty) {
            throw Exception('Resumed session has no questions in JSON');
          }

          // Profildeki sayaç ile cevap geçmişi uyumsuz olabiliyor; her zaman
          // cevap sayısına göre devam.
          index = _answerHistory.length;
          score = _answerHistory.fold<int>(0, (s, h) => s + h.points);
          _currentQuestionLevel = _session.currentLevel;

          await _loadNextQuestion();
          if (_currentQuestion == null) {
            if (isSessionComplete) {
              // 10/10 cevaplanmış; sonuç ekranı [SeventyThirty] tarafında açılır
              notifyListeners();
              return;
            }
            throw Exception(
                'Resumed session has no current question (incomplete, index=$index, q=${_questions.length})');
          }
          notifyListeners();
          return; // Devam edilen session yüklendi
        } catch (e) {
          debugPrint('⚠️ Session resume failed: $e. Starting new.');
        }
      }

      // Oturum tamamlanmışsa veya 10 soru dolmuşsa yeni oturum başlat
      if (_session.totalInSession >= 10 ||
          isSessionComplete ||
          _session.currentQuestionsJson == null) {
        debugPrint(
            '🔄 Resetting session (totalInSession: ${_session.totalInSession})');
        bool levelChanged = false;
        if (_session.lastLevel != null &&
            _session.lastLevel != _session.currentLevel) {
          levelChanged = true;
        }
        _session = _session.startNewSession(levelChanged: levelChanged);
      }
    } catch (e) {
      debugPrint('⚠️ Practice session yüklenirken hata: $e');
      _session = const PracticeSession();
    }

    index = 0;
    score = 0;
    _currentQuestionLevel = _session.currentLevel;
    _answerHistory.clear();
    _questions = [];
    _currentQuestion = null;

    // Kelime havuzunu yükle
    await WordPoolService.instance.loadWordPool();

    // 10 benzersiz soru üret
    if (_selectedPacks.isNotEmpty) {
      if (_selectedPacks.length == 1 && _selectedPacks.first == 'base') {
        _questions = WordPoolService.instance.generateQuestions70_30(
          UserLevel.fromCode(_currentQuestionLevel),
          previousWrongWords: _previousWrongWords,
        );
      } else {
        _questions = await WordPoolService.instance.generateQuestionsFromPacks(
          _selectedPacks,
          UserLevel.fromCode(_currentQuestionLevel),
        );
      }
    } else {
      _questions = WordPoolService.instance.generateQuestions70_30(
        UserLevel.fromCode(_currentQuestionLevel),
        previousWrongWords: _previousWrongWords,
      );
    }

    // Baştan başlıyoruz, soruları session'a kaydet (Ama totalInSession=0 olacak)
    _session = _session.copyWith(
      currentQuestionsJson:
          jsonEncode(_questions.map((q) => q.toJson()).toList()),
      answerHistoryJson: '[]',
      totalInSession: 0,
      correctInSession: 0,
    );
    await UserProfileService.instance.updatePracticeSession(_session);

    // İlk soruyu yükle
    await _loadNextQuestion();
    notifyListeners();
  }

  /// Sonraki soruyu yükle
  Future<void> _loadNextQuestion() async {
    // 10'luk oturumda aynı soru tekrar etmesin: sıradaki soruyu al
    if (index < _questions.length) {
      _currentQuestion = _questions[index];
      // Şıklar ve anlamlar karıştırılmış olarak geliyor
      _shuffledOptions = _currentQuestion!.options;
      _shuffledOptionMeanings = _currentQuestion!.optionMeanings;
      _shuffledCorrectIndex = _currentQuestion!.correctIndex;
    } else {
      _currentQuestion = null;
    }
  }

  /// Cevap ver
  @override
  Future<void> answer(int selectedIndex, int remainingSeconds) async {
    if (_currentQuestion == null) return;

    final isCorrect =
        selectedIndex == _shuffledCorrectIndex && selectedIndex != -1;
    debugPrint(
        '🤔 [PracticeProvider] answer check: selected=$selectedIndex, correct=$_shuffledCorrectIndex, match=$isCorrect');
    final questionLevel = _currentQuestionLevel;

    // Session güncelle
    if (isCorrect) {
      _session = _session.onCorrectAnswer();
    } else {
      _session = _session.onWrongAnswer();
      // Yanlış cevap verildiğinde kelimeyi önceki yanlışlar listesine ekle
      _previousWrongWords
          .add(_currentQuestion!.options[_currentQuestion!.correctIndex]);
    }

    // Kategori bazlı istatistikleri güncelle
    final category = WordCategoryService.instance
        .getCategory(_currentQuestion!.options[_currentQuestion!.correctIndex]);
    await UserProfileService.instance.updateCategoryStats(category, isCorrect);

    if (!isCorrect) {
      final cw = _currentQuestion!.options[_currentQuestion!.correctIndex];
      await UserProfileService.instance.addWrongWord(cw);
    }

    // Puan: düello / GameProvider ile aynı (hız + seri + seri combo); %70 seviye kuralı ayrıca correctInSession ile.
    int roundPoints = 0;
    if (isCorrect) {
      roundPoints = duelStyleRoundPoints(
        remainingSeconds: remainingSeconds,
        streakAfterCorrect: _session.consecutiveCorrect,
      );
      score += roundPoints;
    }

    debugPrint(
        '🎯 Practice Score Update: SessionCorrect=${_session.correctInSession}, Score=$score, round=$roundPoints');

    final int points = roundPoints;

    // Cevap kaydı ekle
    _answerHistory.add(PracticeAnswerRecord(
      prompt: _currentQuestion!.prompt,
      correctAnswer: _currentQuestion!.options[_currentQuestion!.correctIndex],
      selectedAnswer:
          selectedIndex >= 0 ? _shuffledOptions[selectedIndex] : null,
      isCorrect: isCorrect,
      points: points,
      level: questionLevel,
      mode: _currentQuestion!.mode,
      turkishMeaning: _currentQuestion!.turkishMeaning,
    ));

    // NOT: index burada artmıyor, _nextQuestionInternal içinde artacak
    // Böylece yeni soru gelene kadar UI'daki soru numarası sabit kalır.

    // Profili güncelle (Soruları ve cevapları da kaydet)
    _session = _session.copyWith(
      answerHistoryJson:
          jsonEncode(_answerHistory.map((h) => h.toJson()).toList()),
      totalInSession: _answerHistory.length, // Şuan cevaplanan sayısı
    );
    await UserProfileService.instance.updatePracticeSession(_session);

    // Yanlış kelimeleri profile kaydet
    if (!isCorrect) {
      await UserProfileService.instance.updateWrongWords(_previousWrongWords);
    }

    // Günlük görev ilerlemesi (ana oyunla aynı puan çekirdeği → "puan topla" practice'te de ilerler)
    if (isCorrect) {
      QuestService.instance.updateProgress(QuestType.answerQuestions, 1);
      QuestService.instance.updateProgress(QuestType.earnPoints, roundPoints);
      if (remainingSeconds >= 3) {
        QuestService.instance.updateProgress(QuestType.speedAnswer, 1);
      }
      QuestService.instance.updateProgress(
        QuestType.streakCount,
        _session.consecutiveCorrect,
        setExact: true,
      );
    }

    debugPrint(
        '🔔 [PracticeProvider] Answer: isCorrect=$isCorrect, newScore=$score, sessionCorrect=${_session.correctInSession}');

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
    final String oldLevel = _session.currentLevel;
    // ÖNEMLİ: Sıfırlamadan önce mevcut oturum verilerini yedekle
    final historyForResults = List<PracticeAnswerRecord>.from(_answerHistory);
    // Profil / resume asenkronluk sonrası _session.sayacı ile geçmiş sürüm uyumsuz kalabiliyor
    final int completedCorrect =
        historyForResults.where((a) => a.isCorrect).length;
    final int historyCount = historyForResults.length;

    // Oturumu tamamla ve sayaçları sıfırla (sessionsInRow burada artar)
    _session = _session.completeSession();

    bool leveledUp = false;
    bool leveledDown = false;
    String? newLevel;

    // Seviye tespiti (Level Test) mi yoksa normal Practice mi?
    // NOT: duelUnlocked true ise Seviye Testi Bitmiştir.
    if (_session.duelUnlocked) {
      // NORMAL PRACTICE MODU: Üst üste 2 başarı (7+) veya 2 başarısızlık (3-) gerekiyor
      if (_session.consecutiveHighSuccess >= 2) {
        final nextLevel = PracticeScoring.getNextLevel(_session.currentLevel);
        if (nextLevel != _session.currentLevel) {
          _session = _session.withLevel(nextLevel);
          leveledUp = true;
          newLevel = nextLevel;
          try {
            await UserProfileService.instance
                .updateLevel(UserLevel.fromCode(nextLevel));
          } catch (e) {
            debugPrint('⚠️ Seviye güncelleme hatası: $e');
          }
        }
      } else if (_session.consecutiveLowSuccess >= 2 &&
          _session.currentLevel != 'A1') {
        final prevLevel =
            PracticeScoring.getPreviousLevel(_session.currentLevel);
        if (prevLevel != _session.currentLevel) {
          _session = _session.withLevel(prevLevel);
          leveledDown = true;
          newLevel = prevLevel;
          try {
            await UserProfileService.instance
                .updateLevel(UserLevel.fromCode(prevLevel));
          } catch (e) {
            debugPrint('⚠️ Seviye güncelleme hatası: $e');
          }
        }
      }
    } else {
      // SEVİYE TESPİT AŞAMASI (Placement Test): İlk 3 oturum boyunca anlık değişim
      if (completedCorrect >= 7) {
        // Placement'da C2'ye geçiş yok (istek üzerine)
        if (_session.currentLevel == 'C1') {
          debugPrint('ℹ️ Placement test - Already C1, not moving to C2');
        } else {
          final nextLevel = PracticeScoring.getNextLevel(_session.currentLevel);
          if (nextLevel != _session.currentLevel) {
            _session = _session.withLevel(nextLevel);
            leveledUp = true;
            newLevel = nextLevel;
            try {
              await UserProfileService.instance
                  .updateLevel(UserLevel.fromCode(nextLevel));
              debugPrint('📈 Placement Level Up: $newLevel');
            } catch (e) {
              debugPrint('⚠️ Seviye güncelleme hatası: $e');
            }
          }
        }
      } else if (completedCorrect <= 3 && _session.currentLevel != 'A1') {
        final prevLevel =
            PracticeScoring.getPreviousLevel(_session.currentLevel);
        if (prevLevel != _session.currentLevel) {
          _session = _session.withLevel(prevLevel);
          leveledDown = true;
          newLevel = prevLevel;
          try {
            await UserProfileService.instance
                .updateLevel(UserLevel.fromCode(prevLevel));
          } catch (e) {
            debugPrint('⚠️ Seviye güncelleme hatası: $e');
          }
        }
      }
    }

    // Profili güncelle (her durumda session güncel)
    try {
      await UserProfileService.instance.updatePracticeSession(_session);
    } catch (e) {
      debugPrint('⚠️ Session kaydetme hatası: $e');
    }

    // Günlük görev ilerlemesini güncelle (Alıştırma tamamlama)
    try {
      QuestService.instance.updateProgress(QuestType.playPractice, 1);
    } catch (e) {
      debugPrint('⚠️ Görev güncelleme hatası: $e');
    }

    // Seviye serisi başarımı kontrol et (7 maç kuralı)
    if (_session.levelStreak >= 7) {
      final achievementId = 'lvl_${_session.currentLevel.toLowerCase()}';
      try {
        await AchievementService.instance
            .updateAchievementProgressById(achievementId, 7, setExact: true);
      } catch (e) {
        debugPrint('⚠️ Başarım güncelleme hatası: $e');
      }
    }

    // Cache'i temizle (profil güncellemesi için)
    try {
      UserProfileService.instance.clearCache();
    } catch (_) {}

    // Oturum sonunda yanlış yapılan kelimeleri kaydet
    _previousWrongWords = historyForResults
        .where((a) => !a.isCorrect && a.selectedAnswer != null)
        .map((a) => a.correctAnswer)
        .toList();
    final int totalSessionPoints =
        historyForResults.fold<int>(0, (s, r) => s + r.points);
    score = 0;
    debugPrint(
        '🏁 Session Completed: Correct=$completedCorrect, totalPoints=$totalSessionPoints');

    // UI durumunu sıfırla
    _session = _session.copyWith(
      currentQuestionsJson: null,
      answerHistoryJson: null,
      totalInSession: 0,
      correctInSession: 0,
    );
    index = 0;
    _currentQuestion = null;
    _answerHistory.clear();
    notifyListeners();

    return PracticeSessionResult(
      totalQuestions: historyCount,
      correctAnswers: completedCorrect,
      sessionScore: totalSessionPoints,
      leveledUp: leveledUp,
      leveledDown: leveledDown,
      oldLevel: oldLevel,
      newLevel: newLevel,
      currentLevel: _session.currentLevel,
      answerHistory: historyForResults,
      consecutiveHighSuccess: _session.consecutiveHighSuccess,
      consecutiveLowSuccess: _session.consecutiveLowSuccess,
      sessionsInRow: _session.sessionsInRow,
    );
  }

  /// Yeni bir tam oturum başlat (sıfırdan)
  Future<void> resetAndStartNewSession() async {
    final profile = await UserProfileService.instance.loadProfile();
    _session =
        PracticeSession(currentLevel: profile.practiceSession.currentLevel);
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
    final profile = await UserProfileService.instance.loadProfile();
    _session = profile.practiceSession;
    notifyListeners();
  }

  bool get hasResumableSession => _session.isActiveSession;
}

class PracticeAnswerRecord {
  final String prompt;
  final String correctAnswer;
  final String? selectedAnswer;
  final bool isCorrect;
  final int points;
  final String level;
  final QuestionType mode;
  final String? turkishMeaning;

  const PracticeAnswerRecord({
    required this.prompt,
    required this.correctAnswer,
    this.selectedAnswer,
    required this.isCorrect,
    required this.points,
    required this.level,
    required this.mode,
    this.turkishMeaning,
  });

  Map<String, dynamic> toJson() {
    return {
      'prompt': prompt,
      'correctAnswer': correctAnswer,
      'selectedAnswer': selectedAnswer,
      'isCorrect': isCorrect,
      'points': points,
      'level': level,
      'mode': mode.index,
      'turkishMeaning': turkishMeaning,
    };
  }

  factory PracticeAnswerRecord.fromJson(Map<String, dynamic> json) {
    final bool ok = json['isCorrect'] as bool;
    final int? p = json['points'] as int?;
    return PracticeAnswerRecord(
      prompt: json['prompt'] as String,
      correctAnswer: json['correctAnswer'] as String,
      selectedAnswer: json['selectedAnswer'] as String?,
      isCorrect: ok,
      points: p ?? (ok ? 10 : 0),
      level: json['level'] as String,
      mode: QuestionType.values[json['mode'] as int],
      turkishMeaning: json['turkishMeaning'] as String?,
    );
  }
}

class PracticeSessionResult {
  final int totalQuestions;
  final int correctAnswers;
  final int sessionScore;
  final bool leveledUp;
  final bool leveledDown;
  final String? oldLevel;
  final String? newLevel;
  final String currentLevel;
  final List<PracticeAnswerRecord> answerHistory;
  final int consecutiveHighSuccess; // Üst üste yüksek başarı sayısı
  final int consecutiveLowSuccess; // Üst üste düşük başarı sayısı
  final int sessionsInRow; // Seviye tespitinde kaç oturum oynandı

  const PracticeSessionResult({
    required this.totalQuestions,
    required this.correctAnswers,
    required this.sessionScore,
    this.leveledUp = false,
    this.leveledDown = false,
    this.oldLevel,
    this.newLevel,
    required this.currentLevel,
    required this.answerHistory,
    this.consecutiveHighSuccess = 0,
    this.consecutiveLowSuccess = 0,
    required this.sessionsInRow,
  });

  double get accuracy =>
      totalQuestions > 0 ? correctAnswers / totalQuestions : 0;

  /// %70+ başarı mı?
  bool get hasHighSuccess => correctAnswers >= 7;

  /// %30- başarısızlık mı?
  bool get hasLowSuccess => correctAnswers <= 3;

  /// Seviye tespiti tamamlandı mı? (4 oturum)
  bool get isPlacementComplete => sessionsInRow >= 3;
}
