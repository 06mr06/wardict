import 'league.dart';
import 'practice_session.dart';
import 'match_history_item.dart';

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
  final bool hasCompletedPlacementTest;
  
  // Yeni alanlar
  final String username;
  final String? email;
  final String? profileImagePath;
  final String? avatarId; // For selected avatar icon/emoji
  final List<String> awards; 
  final LeagueScores leagueScores; 
  final int practiceScore; 
  final PracticeSession practiceSession; 
  final List<MatchHistoryItem> matchHistory;
  final DateTime? createdAt; // Kayıt tarihi
  final int dailyStreak; // Günlük seri

  UserProfile({
    this.level = UserLevel.a1,
    this.totalScore = 0,
    this.gamesPlayed = 0,
    this.lastPlayed,
    this.username = 'Player',
    this.email,
    this.profileImagePath,
    this.avatarId,
    this.awards = const [],
    this.leagueScores = const LeagueScores(),
    this.practiceScore = 0,
    this.practiceSession = const PracticeSession(),
    this.matchHistory = const [],
    this.hasCompletedPlacementTest = false,
    this.createdAt,
    this.dailyStreak = 0,
  });

  UserProfile copyWith({
    UserLevel? level,
    int? totalScore,
    int? gamesPlayed,
    DateTime? lastPlayed,
    String? username,
    String? email,
    String? profileImagePath,
    String? avatarId,
    bool clearAvatarId = false,
    List<String>? awards,
    LeagueScores? leagueScores,
    int? practiceScore,
    PracticeSession? practiceSession,
    List<MatchHistoryItem>? matchHistory,
    DateTime? createdAt,
    int? dailyStreak,
    bool? hasCompletedPlacementTest,
  }) {
    return UserProfile(
      level: level ?? this.level,
      totalScore: totalScore ?? this.totalScore,
      gamesPlayed: gamesPlayed ?? this.gamesPlayed,
      lastPlayed: lastPlayed ?? this.lastPlayed,
      username: username ?? this.username,
      email: email ?? this.email,
      profileImagePath: profileImagePath ?? this.profileImagePath,
      avatarId: clearAvatarId ? null : (avatarId ?? this.avatarId),
      awards: awards ?? this.awards,
      leagueScores: leagueScores ?? this.leagueScores,
      practiceScore: practiceScore ?? this.practiceScore,
      practiceSession: practiceSession ?? this.practiceSession,
      matchHistory: matchHistory ?? this.matchHistory,
      hasCompletedPlacementTest: hasCompletedPlacementTest ?? this.hasCompletedPlacementTest,
      createdAt: createdAt ?? this.createdAt,
      dailyStreak: dailyStreak ?? this.dailyStreak,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'level': level.code,
      'totalScore': totalScore,
      'gamesPlayed': gamesPlayed,
      'lastPlayed': lastPlayed?.toIso8601String(),
      'username': username,
      'email': email,
      'profileImagePath': profileImagePath,
      'avatarId': avatarId,
      'awards': awards,
      'leagueScores': leagueScores.toJson(),
      'practiceScore': practiceScore,
      'practiceSession': practiceSession.toJson(),
      'matchHistory': matchHistory.map((e) => e.toJson()).toList(),
      'hasCompletedPlacementTest': hasCompletedPlacementTest,
      'createdAt': createdAt?.toIso8601String(),
      'dailyStreak': dailyStreak,
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
      email: json['email'],
      profileImagePath: json['profileImagePath'],
      avatarId: json['avatarId'],
      awards: List<String>.from(json['awards'] ?? []),
      leagueScores: json['leagueScores'] != null
          ? LeagueScores.fromJson(json['leagueScores'])
          : const LeagueScores(),
      practiceScore: json['practiceScore'] ?? 0,
      practiceSession: json['practiceSession'] != null
          ? PracticeSession.fromJson(json['practiceSession'])
          : const PracticeSession(),
      matchHistory: (json['matchHistory'] as List<dynamic>?)
          ?.map((e) => MatchHistoryItem.fromJson(e))
          .toList() ?? [],
      hasCompletedPlacementTest: json['hasCompletedPlacementTest'] ?? false,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      dailyStreak: json['dailyStreak'] ?? 0,
    );
  }
}
