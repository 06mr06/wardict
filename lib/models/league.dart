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

  /// Kazanç/kayıp için Elo değişimlerini hesaplar
  /// K-factor: 32 (standart)
  static int calculateEloChange({
    required int currentElo,
    required int opponentElo,
    required bool won,
    double kFactor = 32,
  }) {
    // Beklenen skor hesaplaması
    final expectedScore = 1 / (1 + (10.0 * ((opponentElo - currentElo) / 400)));
    final actualScore = won ? 1.0 : 0.0;
    return (kFactor * (actualScore - expectedScore)).round();
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
