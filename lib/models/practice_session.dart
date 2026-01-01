/// Practice oturum durumunu temsil eder
class PracticeSession {
  final int sessionNumber; // Oturum numarası (1, 2, 3, ...)
  final int correctInSession; // Bu oturumdaki doğru sayısı
  final int totalInSession; // Bu oturumdaki toplam soru sayısı
  final int consecutiveCorrect; // Üst üste doğru sayısı
  final int consecutiveWrong; // Üst üste yanlış sayısı
  final String currentLevel; // Şuanki seviye (A1, A2, B1, B2, C1, C2)
  final int totalSessionsCompleted; // Tamamlanan toplam oturum sayısı
  final int levelStreak; // Aynı seviyede üst üste tamamlanan oturum sayısı
  final String? lastLevel; // Bir önceki oturumun seviyesi
  
  /// Son iki oturumun doğru sayıları (3. oturumdan sonraki seviye düşme kontrolü için)
  final List<int> lastTwoSessionsCorrectCount;

  const PracticeSession({
    this.sessionNumber = 1,
    this.correctInSession = 0,
    this.totalInSession = 0,
    this.consecutiveCorrect = 0,
    this.consecutiveWrong = 0,
    this.currentLevel = 'A2',
    this.totalSessionsCompleted = 0,
    this.levelStreak = 0,
    this.lastLevel,
    this.lastTwoSessionsCorrectCount = const [],
  });

  /// Yeni bir oturum başlat
  PracticeSession startNewSession() {
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
    );
  }

  /// Seviye değişikliği ile güncelle
  PracticeSession withLevel(String newLevel) {
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
    );
  }

  /// Oturum tamamlandığında güncelle
  PracticeSession completeSession() {
    // Son iki oturumun doğru sayılarını güncelle
    List<int> updatedLastTwo = List.from(lastTwoSessionsCorrectCount);
    updatedLastTwo.add(correctInSession);
    if (updatedLastTwo.length > 2) {
      updatedLastTwo.removeAt(0);
    }

    // Seviye serisi kontrolü
    int newStreak = levelStreak;
    if (lastLevel == currentLevel) {
      newStreak++;
    } else {
      newStreak = 1; // Yeni seriye başla
    }

    return PracticeSession(
      sessionNumber: sessionNumber,
      correctInSession: correctInSession,
      totalInSession: totalInSession,
      consecutiveCorrect: consecutiveCorrect,
      consecutiveWrong: consecutiveWrong,
      currentLevel: currentLevel,
      totalSessionsCompleted: totalSessionsCompleted + 1,
      levelStreak: newStreak,
      lastLevel: currentLevel,
      lastTwoSessionsCorrectCount: updatedLastTwo,
    );
  }

  /// İlk 3 oturumda mıyız? (adaptif zorluk aktif)
  bool get isInAdaptivePeriod => totalSessionsCompleted < 3;

  /// Oturumda üst seviyeye çıkılabilir mi? (10 soruda 7+ doğru)
  bool get canLevelUp => correctInSession >= 7;

  /// İki oturum üst üste 3 veya altında doğru mu?
  bool get shouldLevelDown {
    if (lastTwoSessionsCorrectCount.length < 2) return false;
    return lastTwoSessionsCorrectCount.every((count) => count <= 3);
  }

  /// 2 üst üste doğru mu? (adaptif dönemde seviye atlama için)
  bool get shouldAdaptivelyIncreaseLevel => consecutiveCorrect >= 2;

  /// 2 üst üste yanlış mı? (adaptif dönemde seviye düşme için)
  bool get shouldAdaptivelyDecreaseLevel => consecutiveWrong >= 2;

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
      lastTwoSessionsCorrectCount: List<int>.from(json['lastTwoSessionsCorrectCount'] ?? []),
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
  /// Temel: +5, çarpan uygulanır
  static int calculateCorrectPoints(String level) {
    return 5 * getMultiplier(level);
  }

  /// Yanlış cevap için puan hesapla
  /// Temel: -3, çarpan uygulanır
  static int calculateWrongPoints(String level) {
    return -3 * getMultiplier(level);
  }

  /// Seviye sıralamasını al
  static int getLevelOrder(String level) {
    switch (level) {
      case 'A1': return 0;
      case 'A2': return 1;
      case 'B1': return 2;
      case 'B2': return 3;
      case 'C1': return 4;
      case 'C2': return 5;
      default: return 1;
    }
  }

  /// Bir üst seviye
  static String getNextLevel(String level) {
    switch (level) {
      case 'A1': return 'A2';
      case 'A2': return 'B1';
      case 'B1': return 'B2';
      case 'B2': return 'C1';
      case 'C1': return 'C2';
      case 'C2': return 'C2'; // En üst seviye
      default: return level;
    }
  }

  /// Bir alt seviye
  static String getPreviousLevel(String level) {
    switch (level) {
      case 'A1': return 'A1'; // En alt seviye
      case 'A2': return 'A1';
      case 'B1': return 'A2';
      case 'B2': return 'B1';
      case 'C1': return 'B2';
      case 'C2': return 'C1';
      default: return level;
    }
  }
}
