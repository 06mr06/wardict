/// Lig türlerini temsil eder
enum League {
  beginner('A', 'Beginner', 'A1-A2'),
  intermediate('B', 'Intermediate', 'B1-B2'),
  advanced('C', 'Advanced', 'C1-C2');

  final String code;
  final String name;
  final String levelRange;

  const League(this.code, this.name, this.levelRange);

  /// Kod'dan League döndürür
  static League fromCode(String code) {
    return League.values.firstWhere(
      (league) => league.code == code,
      orElse: () => League.beginner,
    );
  }

  /// Lig için başlangıç Elo puanı
  static const int startingElo = 1500;

  /// Lichess benzeri Elo değişimi hesaplar
  /// - Zayıf oyuncu güçlü rakibi yenerse: YÜKSEK kazanç (+25 ile +40)
  /// - Güçlü oyuncu zayıf rakibe kaybederse: YÜKSEK kayıp (-25 ile -40)
  /// - Eşit rakipler: Normal değişim (±12 ile ±16)
  /// 
  /// K-Factor: Oyun sayısına göre dinamik
  /// - Az oyun (0-15): K=40 (hızlı yerleşim)
  /// - Orta (16-30): K=32 (normal)
  /// - Çok oyun (31+): K=24 (kararlı rating)
  static int calculateEloChange({
    required int currentElo,
    required int opponentElo,
    required bool won,
    int gamesPlayed = 30, // Oyun sayısı
  }) {
    // Dinamik K-Factor (Lichess benzeri)
    double kFactor;
    if (gamesPlayed <= 15) {
      kFactor = 40.0; // Yeni oyuncu - hızlı değişim
    } else if (gamesPlayed <= 30) {
      kFactor = 32.0; // Normal oyuncu
    } else {
      kFactor = 24.0; // Deneyimli oyuncu - yavaş değişim
    }

    // Beklenen skor hesaplaması (Lichess formülü)
    final eloDiff = opponentElo - currentElo;
    final expectedScore = 1.0 / (1.0 + (10.0 * (eloDiff / 400.0)));
    
    // Gerçek skor
    final actualScore = won ? 1.0 : 0.0;
    
    // Ham değişim
    int change = (kFactor * (actualScore - expectedScore)).round();
    
    // Minimum değişim garantisi (en az ±5 puan)
    if (won && change < 5) change = 5;
    if (!won && change > -5) change = -5;
    
    // Maksimum sınır (±50 puan)
    change = change.clamp(-50, 50);
    
    return change;
  }
  
  /// Tahmini puan değişimini hesaplar (UI için)
  static Map<String, int> estimateEloChanges({
    required int currentElo,
    required int opponentElo,
    int gamesPlayed = 30,
  }) {
    return {
      'win': calculateEloChange(
        currentElo: currentElo,
        opponentElo: opponentElo,
        won: true,
        gamesPlayed: gamesPlayed,
      ),
      'loss': calculateEloChange(
        currentElo: currentElo,
        opponentElo: opponentElo,
        won: false,
        gamesPlayed: gamesPlayed,
      ),
    };
  }
}

/// Lig puanları - her lig için ayrı puan tutulur
class LeagueScores {
  final int beginnerElo;
  final int intermediateElo;
  final int advancedElo;

  const LeagueScores({
    this.beginnerElo = 1500,
    this.intermediateElo = 1500,
    this.advancedElo = 1500,
  });

  LeagueScores copyWith({
    int? beginnerElo,
    int? intermediateElo,
    int? advancedElo,
  }) {
    return LeagueScores(
      beginnerElo: beginnerElo ?? this.beginnerElo,
      intermediateElo: intermediateElo ?? this.intermediateElo,
      advancedElo: advancedElo ?? this.advancedElo,
    );
  }

  /// Belirli bir ligin puanını döndürür
  int getScore(League league) {
    switch (league) {
      case League.beginner:
        return beginnerElo;
      case League.intermediate:
        return intermediateElo;
      case League.advanced:
        return advancedElo;
    }
  }

  /// Belirli bir ligin puanını günceller
  LeagueScores updateScore(League league, int newScore) {
    switch (league) {
      case League.beginner:
        return copyWith(beginnerElo: newScore);
      case League.intermediate:
        return copyWith(intermediateElo: newScore);
      case League.advanced:
        return copyWith(advancedElo: newScore);
    }
  }

  /// Formatted display: A1500, B1500, C1500
  String getFormattedScore(League league) {
    return '${league.code}${getScore(league)}';
  }

  Map<String, dynamic> toJson() {
    return {
      'beginnerElo': beginnerElo,
      'intermediateElo': intermediateElo,
      'advancedElo': advancedElo,
    };
  }

  factory LeagueScores.fromJson(Map<String, dynamic> json) {
    return LeagueScores(
      beginnerElo: json['beginnerElo'] ?? 1500,
      intermediateElo: json['intermediateElo'] ?? 1500,
      advancedElo: json['advancedElo'] ?? 1500,
    );
  }
}
