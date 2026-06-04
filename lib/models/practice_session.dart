/// Practice oturum durumunu temsil eder
/// Yeni seviye tespit sistemi:
/// - B1 seviyeden başlanır
/// - 7+ doğru: bir üst seviyeye çıkar
/// - 3- yanlış: bir seviye aşağı düşer
/// - 3 oyun oynayacak, gerçek seviye tespit edilecek
/// - 3 oyun sonra duel modu açılır
class PracticeSession {
  final int sessionNumber; // Oturum numarası (1, 2, 3, ...)
  final int correctInSession; // Bu oturumdaki doğru sayısı
  final int totalInSession; // Bu oturumdaki toplam soru sayısı
  final int consecutiveCorrect; // Üst üste doğru sayısı
  final int consecutiveWrong; // Üst üste yanlış sayısı
  final String currentLevel; // Şuanki seviye (A1, A2, B1, B2, C1, C2)
  final int totalSessionsCompleted; // Tamamlanan toplam oturum sayısı
  final int levelStreak; // Aynı seviyede üst üste tamamlanan oturum sayısı
  final int sessionsInRow; // Placement sırasında tamamlanan oturum sayısı (0–3)
  final bool duelUnlocked; // Duel modu açıldı mı
  final String? lastLevel; // Bir önceki oturumun seviyesi

  /// Son iki oturumun doğru sayıları (seviye değişimi kontrolü için)
  final List<int> lastTwoSessionsCorrectCount;

  /// Üst üste %70+ başarı sayısı (2 olunca seviye atlar)
  final int consecutiveHighSuccess;

  /// Üst üste %30- başarısızlık sayısı (2 olunca seviye düşer)
  final int consecutiveLowSuccess;

  /// Aktif oturum bilgileri (Kaldığı yerden devam edebilmesi için)
  final String? currentQuestionsJson;
  final String? answerHistoryJson;
  final int totalScore; // Oturum içi puan

  const PracticeSession({
    this.sessionNumber = 1,
    this.correctInSession = 0,
    this.totalInSession = 0,
    this.consecutiveCorrect = 0,
    this.consecutiveWrong = 0,
    this.currentLevel = 'B1', // B1'den başla
    this.totalSessionsCompleted = 0,
    this.levelStreak = 0,
    this.lastLevel,
    this.lastTwoSessionsCorrectCount = const [],
    this.consecutiveHighSuccess = 0,
    this.consecutiveLowSuccess = 0,
    this.sessionsInRow = 0,
    this.duelUnlocked = false,
    this.currentQuestionsJson,
    this.answerHistoryJson,
    this.totalScore = 0,
  });

  PracticeSession copyWith({
    int? sessionNumber,
    int? correctInSession,
    int? totalInSession,
    int? consecutiveCorrect,
    int? consecutiveWrong,
    String? currentLevel,
    int? totalSessionsCompleted,
    int? levelStreak,
    int? sessionsInRow,
    bool? duelUnlocked,
    String? lastLevel,
    List<int>? lastTwoSessionsCorrectCount,
    int? consecutiveHighSuccess,
    int? consecutiveLowSuccess,
    String? currentQuestionsJson,
    String? answerHistoryJson,
    int? totalScore,
  }) {
    return PracticeSession(
      sessionNumber: sessionNumber ?? this.sessionNumber,
      correctInSession: correctInSession ?? this.correctInSession,
      totalInSession: totalInSession ?? this.totalInSession,
      consecutiveCorrect: consecutiveCorrect ?? this.consecutiveCorrect,
      consecutiveWrong: consecutiveWrong ?? this.consecutiveWrong,
      currentLevel: currentLevel ?? this.currentLevel,
      totalSessionsCompleted:
          totalSessionsCompleted ?? this.totalSessionsCompleted,
      levelStreak: levelStreak ?? this.levelStreak,
      sessionsInRow: sessionsInRow ?? this.sessionsInRow,
      duelUnlocked: duelUnlocked ?? this.duelUnlocked,
      lastLevel: lastLevel ?? this.lastLevel,
      lastTwoSessionsCorrectCount:
          lastTwoSessionsCorrectCount ?? this.lastTwoSessionsCorrectCount,
      consecutiveHighSuccess:
          consecutiveHighSuccess ?? this.consecutiveHighSuccess,
      consecutiveLowSuccess:
          consecutiveLowSuccess ?? this.consecutiveLowSuccess,
      currentQuestionsJson: currentQuestionsJson ?? this.currentQuestionsJson,
      answerHistoryJson: answerHistoryJson ?? this.answerHistoryJson,
      totalScore: totalScore ?? this.totalScore,
    );
  }

  bool get isActiveSession =>
      totalInSession < 10 && currentQuestionsJson != null;

  /// Yeni bir oturum başlat
  PracticeSession startNewSession({bool levelChanged = false}) {
    return PracticeSession(
      sessionNumber: sessionNumber + 1,
      correctInSession: 0,
      totalInSession: 0,
      consecutiveCorrect: 0,
      consecutiveWrong: 0,
      currentLevel: currentLevel,
      totalSessionsCompleted: totalSessionsCompleted,
      levelStreak: levelStreak,
      lastLevel: lastLevel,
      lastTwoSessionsCorrectCount: lastTwoSessionsCorrectCount,
      consecutiveHighSuccess: consecutiveHighSuccess,
      consecutiveLowSuccess: consecutiveLowSuccess,
      sessionsInRow:
          !duelUnlocked ? sessionsInRow : (levelChanged ? 1 : sessionsInRow),
      duelUnlocked: duelUnlocked,
    );
  }

  /// Doğru cevap sonrası güncelle
  PracticeSession onCorrectAnswer() {
    return PracticeSession(
      sessionNumber: sessionNumber,
      correctInSession: correctInSession + 1,
      totalInSession: totalInSession + 1,
      consecutiveCorrect: consecutiveCorrect + 1,
      consecutiveWrong: 0,
      currentLevel: currentLevel,
      totalSessionsCompleted: totalSessionsCompleted,
      levelStreak: levelStreak,
      lastLevel: lastLevel,
      lastTwoSessionsCorrectCount: lastTwoSessionsCorrectCount,
      consecutiveHighSuccess: consecutiveHighSuccess,
      consecutiveLowSuccess: consecutiveLowSuccess,
      sessionsInRow: sessionsInRow,
      duelUnlocked: duelUnlocked,
    );
  }

  /// Yanlış cevap sonrası güncelle
  PracticeSession onWrongAnswer() {
    return PracticeSession(
      sessionNumber: sessionNumber,
      correctInSession: correctInSession,
      totalInSession: totalInSession + 1,
      consecutiveCorrect: 0,
      consecutiveWrong: consecutiveWrong + 1,
      currentLevel: currentLevel,
      totalSessionsCompleted: totalSessionsCompleted,
      levelStreak: levelStreak,
      lastLevel: lastLevel,
      lastTwoSessionsCorrectCount: lastTwoSessionsCorrectCount,
      consecutiveHighSuccess: consecutiveHighSuccess,
      consecutiveLowSuccess: consecutiveLowSuccess,
      sessionsInRow: sessionsInRow,
      duelUnlocked: duelUnlocked,
    );
  }

  /// Seviye değişikliği ile güncelle
  PracticeSession withLevel(String newLevel) {
    // Seviye tespit aşamasında (ilk 5 oyun) sayaç asla sıfırlanmaz, kaldığı yerden devam eder.
    return PracticeSession(
      sessionNumber: sessionNumber,
      correctInSession: correctInSession,
      totalInSession: totalInSession,
      consecutiveCorrect: consecutiveCorrect,
      consecutiveWrong: consecutiveWrong,
      currentLevel: newLevel,
      totalSessionsCompleted: totalSessionsCompleted,
      levelStreak: levelStreak,
      lastLevel: lastLevel,
      lastTwoSessionsCorrectCount: lastTwoSessionsCorrectCount,
      consecutiveHighSuccess: 0,
      consecutiveLowSuccess: 0,
      sessionsInRow: sessionsInRow, // LEVEL TEST boyunca 1, 2, 3, 4 diye gider
      duelUnlocked: duelUnlocked,
    );
  }

  /// Oturum tamamlandığında güncelle (seviye tespit sistemi)
  PracticeSession completeSession() {
    List<int> updatedLastTwo = List.from(lastTwoSessionsCorrectCount);
    updatedLastTwo.add(correctInSession);
    if (updatedLastTwo.length > 2) {
      updatedLastTwo.removeAt(0);
    }

    int newTotalSessionsCompleted = totalSessionsCompleted + 1;
    // sessionsInRow placement'ta tamamlanan oturum sayısı (en fazla 3).
    // Placement bitince (duelUnlocked) seviye değişimine göre 1'den başlar.
    int newSessionsInRow = !duelUnlocked
        ? (newTotalSessionsCompleted <= 3 ? newTotalSessionsCompleted : 3)
        : sessionsInRow;

    // Duel modu SADECE 3. oturum bittiğinde açılır
    bool unlocked = duelUnlocked || newTotalSessionsCompleted >= 3;

    int newStreak = (lastLevel == currentLevel) ? levelStreak + 1 : 1;

    int newHighStreak =
        (correctInSession >= 7) ? consecutiveHighSuccess + 1 : 0;
    int newLowStreak = (correctInSession <= 3) ? consecutiveLowSuccess + 1 : 0;

    return PracticeSession(
      sessionNumber: sessionNumber + 1, // Oturum numarasını artır
      correctInSession: 0, // Sıfırla
      totalInSession: 0, // Sıfırla
      consecutiveCorrect: 0,
      consecutiveWrong: 0,
      currentLevel: currentLevel,
      totalSessionsCompleted: newTotalSessionsCompleted,
      levelStreak: newStreak,
      lastLevel: currentLevel,
      lastTwoSessionsCorrectCount: updatedLastTwo,
      consecutiveHighSuccess: newHighStreak,
      consecutiveLowSuccess: newLowStreak,
      sessionsInRow: newSessionsInRow,
      duelUnlocked: unlocked,
    );
  }

  /// Bu oturumda %70+ başarı var mı?
  bool get canLevelUp => correctInSession >= 7;

  /// Bu oturumda %30- başarısızlık var mı?
  bool get shouldLevelDown => correctInSession <= 3;

  /// Bu oturumda %70+ başarı var mı?
  bool get hasHighSuccess => correctInSession >= 7;

  /// Bu oturumda %30- başarısızlık var mı?
  bool get hasLowSuccess => correctInSession <= 3;

  /// Mevcut oturumdaki seri (streak) sayısı. [consecutiveCorrect] için bir alias.
  int get streak => consecutiveCorrect;

  Map<String, dynamic> toJson() {
    return {
      'sessionNumber': sessionNumber,
      'correctInSession': correctInSession,
      'totalInSession': totalInSession,
      'consecutiveCorrect': consecutiveCorrect,
      'consecutiveWrong': consecutiveWrong,
      'currentLevel': currentLevel,
      'totalSessionsCompleted': totalSessionsCompleted,
      'levelStreak': levelStreak,
      'lastLevel': lastLevel,
      'lastTwoSessionsCorrectCount': lastTwoSessionsCorrectCount,
      'consecutiveHighSuccess': consecutiveHighSuccess,
      'consecutiveLowSuccess': consecutiveLowSuccess,
      'sessionsInRow': sessionsInRow,
      'duelUnlocked': duelUnlocked,
      'currentQuestionsJson': currentQuestionsJson,
      'answerHistoryJson': answerHistoryJson,
      'totalScore': totalScore,
    };
  }

  factory PracticeSession.fromJson(Map<String, dynamic> json) {
    return PracticeSession(
      sessionNumber: json['sessionNumber'] ?? 1,
      correctInSession: json['correctInSession'] ?? 0,
      totalInSession: json['totalInSession'] ?? 0,
      consecutiveCorrect: json['consecutiveCorrect'] ?? 0,
      consecutiveWrong: json['consecutiveWrong'] ?? 0,
      currentLevel: json['currentLevel'] ?? 'A2',
      totalSessionsCompleted: json['totalSessionsCompleted'] ?? 0,
      levelStreak: json['levelStreak'] ?? 0,
      lastLevel: json['lastLevel'],
      lastTwoSessionsCorrectCount:
          List<int>.from(json['lastTwoSessionsCorrectCount'] ?? []),
      consecutiveHighSuccess: json['consecutiveHighSuccess'] ?? 0,
      consecutiveLowSuccess: json['consecutiveLowSuccess'] ?? 0,
      sessionsInRow: json['sessionsInRow'] ?? 0,
      duelUnlocked: json['duelUnlocked'] ?? false,
      currentQuestionsJson: json['currentQuestionsJson'],
      answerHistoryJson: json['answerHistoryJson'],
      totalScore: json['totalScore'] ?? 0,
    );
  }
}

/// Practice puanlama mantığı
class PracticeScoring {
  /// Seviye çarpanlarını hesapla
  /// A seviyesi: 1x, B seviyesi: 2x, C seviyesi: 3x
  static int getMultiplier(String level) {
    if (level.startsWith('C')) return 3;
    if (level.startsWith('B')) return 2;
    return 1;
  }

  /// Doğru cevap için puan hesapla
  /// Sabit: +10 Puan (Seviyeden bağımsız)
  static int calculateCorrectPoints(String level) {
    return 10;
  }

  /// Yanlış cevap için puan hesapla
  /// Sabit: 0 Puan (Yanlış cevap puan düşürmesin)
  static int calculateWrongPoints(String level) {
    return 0;
  }

  /// Seviye sıralamasını al
  static int getLevelOrder(String level) {
    switch (level) {
      case 'A1':
        return 0;
      case 'A2':
        return 1;
      case 'B1':
        return 2;
      case 'B2':
        return 3;
      case 'C1':
        return 4;
      case 'C2':
        return 5;
      default:
        return 1;
    }
  }

  /// Bir üst seviye
  static String getNextLevel(String level) {
    switch (level) {
      case 'A1':
        return 'A2';
      case 'A2':
        return 'B1';
      case 'B1':
        return 'B2';
      case 'B2':
        return 'C1';
      case 'C1':
        return 'C2';
      case 'C2':
        return 'C2'; // En üst seviye
      default:
        return level;
    }
  }

  /// Bir alt seviye
  static String getPreviousLevel(String level) {
    switch (level) {
      case 'A1':
        return 'A1'; // En alt seviye
      case 'A2':
        return 'A1';
      case 'B1':
        return 'A2';
      case 'B2':
        return 'B1';
      case 'C1':
        return 'B2';
      case 'C2':
        return 'C1';
      default:
        return level;
    }
  }
}
