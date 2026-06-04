import 'dart:math';

/// Lig kademelerini temsil eder (Puan bazlı) - Chess.com tarzı
enum LeagueTier {
  bronze('Bronze', '🥉', 0, 500),
  silver('Silver', '🥈', 501, 1500),
  gold('Gold', '🥇', 1501, 3000),
  platinum('Platinum', '💠', 3001, 5000),
  diamond('Diamond', '💎', 5001, 8000),
  master('Master', '⭐', 8001, 12000),
  legend('Legend', '🏆', 12001, 999999);

  final String name;
  final String icon;
  final int minPoints;
  final int maxPoints;

  const LeagueTier(this.name, this.icon, this.minPoints, this.maxPoints);

  static LeagueTier fromScore(int score) {
    if (score <= 500) return LeagueTier.bronze;
    if (score <= 1500) return LeagueTier.silver;
    if (score <= 3000) return LeagueTier.gold;
    if (score <= 5000) return LeagueTier.platinum;
    if (score <= 8000) return LeagueTier.diamond;
    if (score <= 12000) return LeagueTier.master;
    return LeagueTier.legend;
  }
}

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

  /// Lig için başlangıç LP puanı
  static const int startingLp = 1500;

  /// Standart LP değişimi hesaplar (FIDE/Lichess sistemi)
  /// - Zayıf oyuncu güçlü rakibi yenerse: YÜKSEK kazanç (+25 ile +40)
  /// - Güçlü oyuncu zayıf rakibe kaybederse: YÜKSEK kayıp (-25 ile -40)
  /// - Eşit rakipler: Normal değişim (±12 ile ±16)
  /// - Beraberlik: Puanlar beklenen sonuca göre değişir
  ///
  /// K-Factor: Oyun sayısına göre dinamik
  /// - Az oyun (0-15): K=40 (hızlı yerleşim)
  /// - Orta (16-30): K=32 (normal)
  /// - Çok oyun (31+): K=24 (kararlı rating)
  static int calculateLpChange({
    required int currentLp,
    required int opponentLp,
    required double result, // 1.0 = kazandı, 0.5 = berabere, 0.0 = kaybetti
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

    // Beklenen skor hesaplaması (Standart LP formülü)
    // NOT: pow(10, x) kullanılmalı, 10*x değil!
    final lpDiff = opponentLp - currentLp;
    final expectedScore = 1.0 / (1.0 + pow(10, lpDiff / 400.0));

    // Gerçek skor (1.0 = galibiyet, 0.5 = beraberlik, 0.0 = mağlubiyet)
    final actualScore = result;

    // Ham değişim
    int change = (kFactor * (actualScore - expectedScore)).round();

    // Minimum değişim garantisi (sadece kesin galibiyet/mağlubiyetlerde)
    // Beraberlikte doğal değişimi kullan
    if (result == 1.0 && change < 5) change = 5;
    if (result == 0.0 && change > -5) change = -5;

    // Maksimum sınır (±50 puan)
    change = change.clamp(-50, 50);

    return change;
  }

  /// LP puanına göre lig kodunu döndürür
  static String getLeagueCodeFromLp(int lp) {
    if (lp >= 2000) return 'C';
    if (lp >= 1500) return 'B';
    return 'A';
  }

  /// Tahmini puan değişimini hesaplar (UI için)
  static Map<String, int> estimateLpChanges({
    required int currentLp,
    required int opponentLp,
    int gamesPlayed = 30,
  }) {
    return {
      'win': calculateLpChange(
        currentLp: currentLp,
        opponentLp: opponentLp,
        result: 1.0,
        gamesPlayed: gamesPlayed,
      ),
      'draw': calculateLpChange(
        currentLp: currentLp,
        opponentLp: opponentLp,
        result: 0.5,
        gamesPlayed: gamesPlayed,
      ),
      'loss': calculateLpChange(
        currentLp: currentLp,
        opponentLp: opponentLp,
        result: 0.0,
        gamesPlayed: gamesPlayed,
      ),
    };
  }
}

/// Lig puanları - her lig için ayrı puan tutulur
class LeagueScores {
  final int beginnerLp;
  final int intermediateLp;
  final int advancedLp;

  const LeagueScores({
    this.beginnerLp = 1500,
    this.intermediateLp = 1500,
    this.advancedLp = 1500,
  });

  LeagueScores copyWith({
    int? beginnerLp,
    int? intermediateLp,
    int? advancedLp,
  }) {
    return LeagueScores(
      beginnerLp: beginnerLp ?? this.beginnerLp,
      intermediateLp: intermediateLp ?? this.intermediateLp,
      advancedLp: advancedLp ?? this.advancedLp,
    );
  }

  /// Belirli bir ligin puanını döndürür
  int getScore(League league) {
    switch (league) {
      case League.beginner:
        return beginnerLp;
      case League.intermediate:
        return intermediateLp;
      case League.advanced:
        return advancedLp;
    }
  }

  /// Belirli bir ligin puanını günceller
  LeagueScores updateScore(League league, int newScore) {
    switch (league) {
      case League.beginner:
        return copyWith(beginnerLp: newScore);
      case League.intermediate:
        return copyWith(intermediateLp: newScore);
      case League.advanced:
        return copyWith(advancedLp: newScore);
    }
  }

  /// Formatted display: A1500, B1500, C1500
  String getFormattedScore(League league) {
    return '${league.code}${getScore(league)}';
  }

  Map<String, dynamic> toJson() {
    return {
      'A': beginnerLp,
      'B': intermediateLp,
      'C': advancedLp,
    };
  }

  factory LeagueScores.fromJson(Map<String, dynamic> json) {
    return LeagueScores(
      beginnerLp: (json['A'] ?? json['beginnerLp'] ?? 1500) as int,
      intermediateLp: (json['B'] ?? json['intermediateLp'] ?? 1500) as int,
      advancedLp: (json['C'] ?? json['advancedLp'] ?? 1500) as int,
    );
  }
}
