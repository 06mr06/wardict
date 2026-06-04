import 'package:cloud_firestore/cloud_firestore.dart';
import 'league.dart';
import 'practice_session.dart';
import 'match_history_item.dart';

DateTime? _parseCreatedAtField(dynamic raw) {
  if (raw == null) return null;
  if (raw is Timestamp) return raw.toDate();
  if (raw is DateTime) return raw;
  return DateTime.tryParse(raw.toString());
}

/// Kullanıcı seviyesini temsil eder
enum UserLevel {
  a1('A1', 'Harf', 'Letter', 0),
  a2('A2', 'Hece', 'Syllable', 1),
  b1('B1', 'Kelime', 'Word', 2),
  b2('B2', 'Cümle', 'Sentence', 3),
  c1('C1', 'Roman', 'Novel', 4),
  c2('C2', 'Yazar', 'Author', 5);

  final String code;
  final String turkishName;
  final String englishName;
  final int order;

  const UserLevel(this.code, this.turkishName, this.englishName, this.order);

  /// Seviyeye özel ana renk
  dynamic get color {
    switch (this) {
      case UserLevel.a1: return 0xFFCD7F32; // Bronze
      case UserLevel.a2: return 0xFFB0C4DE; // Silver Blue
      case UserLevel.b1: return 0xFFFFD700; // Gold
      case UserLevel.b2: return 0xFFFFA500; // Orange/Gold
      case UserLevel.c1: return 0xFF9370DB; // Purple/Elite
      case UserLevel.c2: return 0xFF00CED1; // Diamond
    }
  }

  /// Seviyeye özel gradyan renkleri
  List<dynamic> get gradientColors {
    switch (this) {
      case UserLevel.a1: return [0xFF8B4513, 0xFFCD7F32];
      case UserLevel.a2: return [0xFF4682B4, 0xFFB0C4DE];
      case UserLevel.b1: return [0xFFB8860B, 0xFFFFD700];
      case UserLevel.b2: return [0xFFFF8C00, 0xFFFFA500];
      case UserLevel.c1: return [0xFF4B0082, 0xFF9370DB];
      case UserLevel.c2: return [0xFF20B2AA, 0xFF00CED1];
    }
  }

  /// Seviyeye özel ikon (IconData olarak kullanılacak)
  int get iconCode {
    switch (this) {
      case UserLevel.a1: return 0xe5da; // school
      case UserLevel.a2: return 0xf0204; // workspace_premium
      case UserLevel.b1: return 0xe3e0; // military_tech
      case UserLevel.b2: return 0xe23b; // emoji_events
      case UserLevel.c1: return 0xe89e; // diamond
      case UserLevel.c2: return 0xe07f; // auto_awesome
    }
  }

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
  final int lpRating; // TEK PUAN SİSTEMİ - Duel için kullanılacak
  final LeagueScores leagueScores;
  final int practiceScore; // Pratik modu skoru
  final PracticeSession practiceSession;
  final List<MatchHistoryItem> matchHistory;
  final DateTime? createdAt; // Kayıt tarihi
  final int dailyStreak; // Günlük seri
  final int practiceGamesPlayed; // İlk 5 oyun takibi için
  final int duelWinStreak; // Düello galibiyet serisi
  final int coins; // Kullanıcı bakiyesi (Güvenlik için buraya taşındı)
  final int duelWins;
  final int duelLosses;
  final bool isPremium;
  final String? frameId;
  final List<String> unlockedCosmetics;
  final bool hasReceivedWelcomeGift; // Yeni: Mükerrer hediye önleme
  final DateTime? lastDailyBonusClaimed; // Yeni: 25 coinlik bonus takibi
  final DateTime? lastDailyRewardClaimed; // Yeni: Seri (streak) ödülü takibi
  final Map<String, Map<String, int>> categoryStats; // Yeni: Kategori bazlı istatistikler {'verbs': {'correct': 10, 'wrong': 5}}
  final List<String> wrongWords; // Yeni: Tekrar edilmesi gereken yanlış kelimeler

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
    this.lpRating = 0, // TEK PUAN SİSTEMİ - Duel için kullanılacak
    this.leagueScores = const LeagueScores(), // Lig puanları
    this.practiceScore = 0, // Pratik skoru
    this.practiceSession = const PracticeSession(),
    this.matchHistory = const [],
    this.hasCompletedPlacementTest = false,
    this.createdAt,
    this.dailyStreak = 0,
    this.practiceGamesPlayed = 0,
    this.duelWinStreak = 0,
    this.coins = 0,
    this.duelWins = 0,
    this.duelLosses = 0,
    this.isPremium = false,
    this.frameId,
    this.unlockedCosmetics = const [],
    this.hasReceivedWelcomeGift = false,
    this.lastDailyBonusClaimed,
    this.lastDailyRewardClaimed,
    this.categoryStats = const {},
    this.wrongWords = const [],
  });

  /// Seviyeye göre başlangıç puanı
  static int getInitialLpForLevel(UserLevel level) {
    switch (level) {
      case UserLevel.a1: return 1000;
      case UserLevel.a2: return 1250;
      case UserLevel.b1: return 1500;
      case UserLevel.b2: return 1750;
      case UserLevel.c1: return 2000;
      case UserLevel.c2: return 2250;
    }
  }


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
    bool clearProfileImagePath = false,
    bool clearFrameId = false,
    List<String>? awards,
    int? lpRating,
    LeagueScores? leagueScores,
    int? practiceScore,
    PracticeSession? practiceSession,
    List<MatchHistoryItem>? matchHistory,
    DateTime? createdAt,
    int? dailyStreak,
    int? practiceGamesPlayed,
    int? duelWinStreak,
    bool? hasCompletedPlacementTest,
    int? coins,
    int? duelWins,
    int? duelLosses,
    bool? isPremium,
    String? frameId,
    List<String>? unlockedCosmetics,
    bool? hasReceivedWelcomeGift,
    DateTime? lastDailyBonusClaimed,
    DateTime? lastDailyRewardClaimed,
    Map<String, Map<String, int>>? categoryStats,
    List<String>? wrongWords,
  }) {
    return UserProfile(
      level: level ?? this.level,
      totalScore: totalScore ?? this.totalScore,
      gamesPlayed: gamesPlayed ?? this.gamesPlayed,
      lastPlayed: lastPlayed ?? this.lastPlayed,
      username: username ?? this.username,
      email: email ?? this.email,
      profileImagePath: clearProfileImagePath ? null : (profileImagePath ?? this.profileImagePath),
      avatarId: clearAvatarId ? null : (avatarId ?? this.avatarId),
      awards: awards ?? this.awards,
      lpRating: lpRating ?? this.lpRating,
      leagueScores: leagueScores ?? this.leagueScores,
      practiceScore: practiceScore ?? this.practiceScore,
      practiceSession: practiceSession ?? this.practiceSession,
      matchHistory: matchHistory ?? this.matchHistory,
      hasCompletedPlacementTest: hasCompletedPlacementTest ?? this.hasCompletedPlacementTest,
      createdAt: createdAt ?? this.createdAt,
      dailyStreak: dailyStreak ?? this.dailyStreak,
      practiceGamesPlayed: practiceGamesPlayed ?? this.practiceGamesPlayed,
      duelWinStreak: duelWinStreak ?? this.duelWinStreak,
      coins: coins ?? this.coins,
      duelWins: duelWins ?? this.duelWins,
      duelLosses: duelLosses ?? this.duelLosses,
      isPremium: isPremium ?? this.isPremium,
      frameId: clearFrameId ? null : (frameId ?? this.frameId),
      unlockedCosmetics: unlockedCosmetics ?? this.unlockedCosmetics,
      hasReceivedWelcomeGift: hasReceivedWelcomeGift ?? this.hasReceivedWelcomeGift,
      lastDailyBonusClaimed: lastDailyBonusClaimed ?? this.lastDailyBonusClaimed,
      lastDailyRewardClaimed: lastDailyRewardClaimed ?? this.lastDailyRewardClaimed,
      categoryStats: categoryStats ?? this.categoryStats,
      wrongWords: wrongWords ?? this.wrongWords,
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
      'lpRating': lpRating,
      'leagueScores': leagueScores.toJson(),
      'practiceScore': practiceScore,
      'practiceSession': practiceSession.toJson(),
      'matchHistory': matchHistory.map((e) => e.toJson()).toList(),
      'hasCompletedPlacementTest': hasCompletedPlacementTest,
      'createdAt': createdAt?.toIso8601String(),
      'dailyStreak': dailyStreak,
      'practiceGamesPlayed': practiceGamesPlayed,
      'duelWinStreak': duelWinStreak,
      'coins': coins,
      'duelWins': duelWins,
      'duelLosses': duelLosses,
      'isPremium': isPremium,
      'frameId': frameId,
      'unlockedCosmetics': unlockedCosmetics,
      'hasReceivedWelcomeGift': hasReceivedWelcomeGift,
      'lastDailyBonusClaimed': lastDailyBonusClaimed?.toIso8601String(),
      'lastDailyRewardClaimed': lastDailyRewardClaimed?.toIso8601String(),
      'categoryStats': categoryStats,
      'wrongWords': wrongWords,
    };
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      level: UserLevel.fromCode(json['level'] ?? 'A1'),
      totalScore: json['totalScore'] ?? 0,
      gamesPlayed: json['gamesPlayed'] ?? 0,
      lastPlayed: json['lastPlayed'] != null
          ? (json['lastPlayed'] is Timestamp 
              ? (json['lastPlayed'] as Timestamp).toDate() 
              : DateTime.tryParse(json['lastPlayed'].toString()))
          : null,
      username: json['username'] ?? 'Player',
      email: json['email'],
      profileImagePath: json['profileImagePath'],
      avatarId: json['avatarId'],
      awards: List<String>.from(json['awards'] ?? []),
      lpRating: json['lpRating'] ?? json['eloRating'] ?? 0,
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
      // Yoksa veya parse edilemezse null — yanlışlıkla "bugün" göstermez
      createdAt: _parseCreatedAtField(json['createdAt']),
      dailyStreak: json['dailyStreak'] ?? 0,
      practiceGamesPlayed: json['practiceGamesPlayed'] ?? 0,
      duelWinStreak: json['duelWinStreak'] ?? 0,
      coins: json['coins'] ?? 0,
      duelWins: json['duelWins'] ?? 0,
      duelLosses: json['duelLosses'] ?? 0,
      isPremium: json['isPremium'] ?? false,
      frameId: json['frameId'],
      unlockedCosmetics: List<String>.from(json['unlockedCosmetics'] ?? []),
      hasReceivedWelcomeGift: json['hasReceivedWelcomeGift'] ?? false,
      lastDailyBonusClaimed: json['lastDailyBonusClaimed'] != null 
          ? DateTime.tryParse(json['lastDailyBonusClaimed'].toString()) 
          : null,
      lastDailyRewardClaimed: json['lastDailyRewardClaimed'] != null 
          ? DateTime.tryParse(json['lastDailyRewardClaimed'].toString()) 
          : null,
      categoryStats: json['categoryStats'] != null
          ? (json['categoryStats'] as Map<String, dynamic>).map(
              (key, value) => MapEntry(
                key,
                (value as Map<String, dynamic>).map(
                  (k, v) => MapEntry(k, v as int),
                ),
              ),
            )
          : const {},
      wrongWords: List<String>.from(json['wrongWords'] ?? []),
    );
  }
}
