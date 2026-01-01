class Daily123Stats {
  final int totalGames;
  final int totalWins; // Reaching 123 points within 123 seconds
  final int currentStreak;
  final int highestStreak;
  final List<Daily123Result> history;

  Daily123Stats({
    this.totalGames = 0,
    this.totalWins = 0,
    this.currentStreak = 0,
    this.highestStreak = 0,
    this.history = const [],
  });

  double get winPercentage => totalGames == 0 ? 0 : (totalWins / totalGames) * 100;

  Map<String, dynamic> toJson() => {
    'totalGames': totalGames,
    'totalWins': totalWins,
    'currentStreak': currentStreak,
    'highestStreak': highestStreak,
    'history': history.map((e) => e.toJson()).toList(),
  };

  factory Daily123Stats.fromJson(Map<String, dynamic> json) => Daily123Stats(
    totalGames: json['totalGames'] ?? 0,
    totalWins: json['totalWins'] ?? 0,
    currentStreak: json['currentStreak'] ?? 0,
    highestStreak: json['highestStreak'] ?? 0,
    history: (json['history'] as List<dynamic>?)
        ?.map((e) => Daily123Result.fromJson(e))
        .toList() ?? [],
  );
}

class Daily123Result {
  final DateTime date;
  final int score;
  final int timeSeconds;
  final bool isWin;

  Daily123Result({
    required this.date,
    required this.score,
    required this.timeSeconds,
    required this.isWin,
  });

  Map<String, dynamic> toJson() => {
    'date': date.toIso8601String(),
    'score': score,
    'timeSeconds': timeSeconds,
    'isWin': isWin,
  };

  factory Daily123Result.fromJson(Map<String, dynamic> json) => Daily123Result(
    date: DateTime.parse(json['date']),
    score: json['score'],
    timeSeconds: json['timeSeconds'],
    isWin: json['isWin'],
  );
}
