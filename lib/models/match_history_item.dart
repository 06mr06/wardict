import 'user_level.dart';
import 'league.dart';

class MatchHistoryItem {
  final String opponentName;
  final int userScore;
  final int opponentScore;
  final bool isWin;
  final DateTime date;
  final League? league;
  final int eloChange;

  const MatchHistoryItem({
    required this.opponentName,
    required this.userScore,
    required this.opponentScore,
    required this.isWin,
    required this.date,
    this.league,
    this.eloChange = 0,
  });

  Map<String, dynamic> toJson() {
    return {
      'opponentName': opponentName,
      'userScore': userScore,
      'opponentScore': opponentScore,
      'isWin': isWin,
      'date': date.toIso8601String(),
      'league': league?.name,
      'eloChange': eloChange,
    };
  }

  factory MatchHistoryItem.fromJson(Map<String, dynamic> json) {
    return MatchHistoryItem(
      opponentName: json['opponentName'] ?? 'Opponent',
      userScore: json['userScore'] ?? 0,
      opponentScore: json['opponentScore'] ?? 0,
      isWin: json['isWin'] ?? false,
      date: json['date'] != null ? DateTime.parse(json['date']) : DateTime.now(),
      league: json['league'] != null ? League.values.firstWhere((e) => e.name == json['league'], orElse: () => League.beginner) : null,
      eloChange: json['eloChange'] ?? 0,
    );
  }
}
