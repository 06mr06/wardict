import 'league.dart';
import 'practice_session.dart';

/// Kullanıcı seviyesini temsil eder
enum UserLevel {
  a1('A1', 'Harf', 0),
  a2('A2', 'Hece', 1),
  b1('B1', 'Kelime', 2),
  b2('B2', 'Cümle', 3),
  c1('C1', 'Roman', 4),
  c2('C2', 'Yazar', 5);

  final String code;
  final String turkishName;
  final int order;

  const UserLevel(this.code, this.turkishName, this.order);

  /// Seviye kodundan UserLevel döndürür
  static UserLevel fromCode(String code) {
    return UserLevel.values.firstWhere(
      (level) => level.code == code,
      orElse: () => UserLevel.a1,
    );
  }

  /// Bir üst seviyeyi döndürür (C2 için kendisini döndürür)
  UserLevel get nextLevel {
    if (this == UserLevel.c2) return this;
    return UserLevel.values[order + 1];
  }

  /// Bir alt seviyeyi döndürür (A1 için kendisini döndürür)
  UserLevel get previousLevel {
    if (this == UserLevel.a1) return this;
    return UserLevel.values[order - 1];
  }

  /// İki üst seviyeyi döndürür
  UserLevel get twoLevelsUp {
    return nextLevel.nextLevel;
  }
}

/// Kullanıcı profili - tüm bilgileri tutar
class UserProfile {
  final UserLevel level;
  final int totalScore;
  final int gamesPlayed;
  final DateTime? lastPlayed;
  
  // Yeni alanlar
  final String username;
  final String? profileImagePath;
  final List<String> awards; // Ödüller (ileride detaylandırılacak)
  final LeagueScores leagueScores; // Lig puanları (A1500, B1500, C1500)
  final int practiceScore; // Practice modu toplam puanı
  final PracticeSession practiceSession; // Practice oturum durumu

  UserProfile({
    this.level = UserLevel.a1,
    this.totalScore = 0,
    this.gamesPlayed = 0,
    this.lastPlayed,
    this.username = 'Player',
    this.profileImagePath,
    this.awards = const [],
    this.leagueScores = const LeagueScores(),
    this.practiceScore = 0,
    this.practiceSession = const PracticeSession(),
  });

  UserProfile copyWith({
    UserLevel? level,
    int? totalScore,
    int? gamesPlayed,
    DateTime? lastPlayed,
    String? username,
    String? profileImagePath,
    List<String>? awards,
    LeagueScores? leagueScores,
    int? practiceScore,
    PracticeSession? practiceSession,
  }) {
    return UserProfile(
      level: level ?? this.level,
      totalScore: totalScore ?? this.totalScore,
      gamesPlayed: gamesPlayed ?? this.gamesPlayed,
      lastPlayed: lastPlayed ?? this.lastPlayed,
      username: username ?? this.username,
      profileImagePath: profileImagePath ?? this.profileImagePath,
      awards: awards ?? this.awards,
      leagueScores: leagueScores ?? this.leagueScores,
      practiceScore: practiceScore ?? this.practiceScore,
      practiceSession: practiceSession ?? this.practiceSession,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'level': level.code,
      'totalScore': totalScore,
      'gamesPlayed': gamesPlayed,
      'lastPlayed': lastPlayed?.toIso8601String(),
      'username': username,
      'profileImagePath': profileImagePath,
      'awards': awards,
      'leagueScores': leagueScores.toJson(),
      'practiceScore': practiceScore,
      'practiceSession': practiceSession.toJson(),
    };
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      level: UserLevel.fromCode(json['level'] ?? 'A1'),
      totalScore: json['totalScore'] ?? 0,
      gamesPlayed: json['gamesPlayed'] ?? 0,
      lastPlayed: json['lastPlayed'] != null
          ? DateTime.parse(json['lastPlayed'])
          : null,
      username: json['username'] ?? 'Player',
      profileImagePath: json['profileImagePath'],
      awards: List<String>.from(json['awards'] ?? []),
      leagueScores: json['leagueScores'] != null
          ? LeagueScores.fromJson(json['leagueScores'])
          : const LeagueScores(),
      practiceScore: json['practiceScore'] ?? 0,
      practiceSession: json['practiceSession'] != null
          ? PracticeSession.fromJson(json['practiceSession'])
          : const PracticeSession(),
    );
  }
}
