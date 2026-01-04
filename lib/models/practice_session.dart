/// Practice oturum durumunu temsil eder
/// Yeni kurgu:
/// - A2 seviyeden başlanır
/// - 10 soruda %70+ başarı (7+) üst üste 2 kez = seviye atlama
/// - 10 soruda %30- başarısızlık (3-) üst üste 2 kez = seviye düşme
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
  
  /// Son iki oturumun doğru sayıları (seviye değişimi kontrolü için)
  final List<int> lastTwoSessionsCorrectCount;
  
  /// Üst üste %70+ başarı sayısı (2 olunca seviye atlar)
  final int consecutiveHighSuccess;
  
  /// Üst üste %30- başarısızlık sayısı (2 olunca seviye düşer)
  final int consecutiveLowSuccess;

  const PracticeSession({
    this.sessionNumber = 1,
    this.correctInSession = 0,
    this.totalInSession = 0,
    this.consecutiveCorrect = 0,
    this.consecutiveWrong = 0,
    this.currentLevel = 'A2', // A2'den başla
    this.totalSessionsCompleted = 0,
    this.levelStreak = 0,
    this.lastLevel,
    this.lastTwoSessionsCorrectCount = const [],
    this.consecutiveHighSuccess = 0,
    this.consecutiveLowSuccess = 0,
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
      consecutiveHighSuccess: consecutiveHighSuccess,
      consecutiveLowSuccess: consecutiveLowSuccess,
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
      consecutiveHighSuccess: 0, // Seviye değişince sıfırla
      consecutiveLowSuccess: 0,
    );
  }

  /// Oturum tamamlandığında güncelle
  /// Yeni kurgu: %70+ başarı = highSuccess++, %30- başarısızlık = lowSuccess++
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
    
    // Başarı kontrolü: %70+ = 7/10 doğru, %30- = 3/10 veya altı
    int newHighSuccess = consecutiveHighSuccess;
    int newLowSuccess = consecutiveLowSuccess;
    
    if (correctInSession >= 7) {
      // %70+ başarı
      newHighSuccess++;
      newLowSuccess = 0; // Düşük başarı serisini sıfırla
    } else if (correctInSession <= 3) {
      // %30- başarısızlık
      newLowSuccess++;
      newHighSuccess = 0; // Yüksek başarı serisini sıfırla
    } else {
      // %30-%70 arası - serileri sıfırla
      newHighSuccess = 0;
      newLowSuccess = 0;
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
      consecutiveHighSuccess: newHighSuccess,
      consecutiveLowSuccess: newLowSuccess,
    );
  }

  /// Üst seviyeye çıkılabilir mi? (2 üst üste %70+ başarı)
  bool get canLevelUp => consecutiveHighSuccess >= 2;

  /// Alt seviyeye düşülmeli mi? (2 üst üste %30- başarısızlık)
  bool get shouldLevelDown => consecutiveLowSuccess >= 2;

  /// Bu oturumda %70+ başarı var mı?
  bool get hasHighSuccess => correctInSession >= 7;
  
  /// Bu oturumda %30- başarısızlık var mı?
  bool get hasLowSuccess => correctInSession <= 3;

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
      consecutiveHighSuccess: json['consecutiveHighSuccess'] ?? 0,
      consecutiveLowSuccess: json['consecutiveLowSuccess'] ?? 0,
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
