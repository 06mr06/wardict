import 'question_mode.dart';
import 'friend.dart';

/// Duel daveti
class DuelInvitation {
  final String id;
  final Friend fromUser;
  final String leagueCode;
  final DateTime createdAt;
  final DateTime expiresAt;
  final bool isAccepted;
  final bool isDeclined;

  const DuelInvitation({
    required this.id,
    required this.fromUser,
    required this.leagueCode,
    required this.createdAt,
    required this.expiresAt,
    this.isAccepted = false,
    this.isDeclined = false,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);
  bool get isPending => !isAccepted && !isDeclined && !isExpired;

  int get secondsRemaining {
    final diff = expiresAt.difference(DateTime.now()).inSeconds;
    return diff > 0 ? diff : 0;
  }
}

/// Online düello durumu
enum OnlineDuelStatus {
  waiting,      // Rakip bekleniyor
  ready,        // Her iki oyuncu hazır
  inProgress,   // Oyun devam ediyor
  finished,     // Oyun bitti
  cancelled,    // İptal edildi
  timeout,      // Zaman aşımı
}

/// Online düello sorusu
class OnlineDuelQuestion {
  final String id;
  final String prompt;
  final List<String> options;
  final int correctIndex;
  final String? hint;
  final QuestionMode mode;
  final String? turkishMeaning;

  const OnlineDuelQuestion({
    required this.id,
    required this.prompt,
    required this.options,
    required this.correctIndex,
    this.hint,
    required this.mode,
    this.turkishMeaning,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'prompt': prompt,
      'options': options,
      'correctIndex': correctIndex,
      'hint': hint,
      'mode': mode.name,
      if (turkishMeaning != null) 'turkishMeaning': turkishMeaning,
    };
  }

  factory OnlineDuelQuestion.fromJson(Map<dynamic, dynamic> json) {
    return OnlineDuelQuestion(
      id: json['id']?.toString() ?? '',
      prompt: json['prompt']?.toString() ?? '',
      options: List<String>.from(json['options'] ?? []),
      correctIndex: (json['correctIndex'] as num?)?.toInt() ?? 0,
      hint: json['hint']?.toString(),
      mode: QuestionMode.values.firstWhere(
        (m) => m.name == json['mode'],
        orElse: () => QuestionMode.enToTr,
      ),
      turkishMeaning: json['turkishMeaning']?.toString(),
    );
  }
}

/// Oyuncu cevabı
class PlayerAnswer {
  final String userId;
  final int questionIndex;
  final int selectedOption;
  final bool isCorrect;
  final int timeMs;
  final DateTime answeredAt;

  const PlayerAnswer({
    required this.userId,
    required this.questionIndex,
    required this.selectedOption,
    required this.isCorrect,
    required this.timeMs,
    required this.answeredAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'questionIndex': questionIndex,
      'selectedOption': selectedOption,
      'isCorrect': isCorrect,
      'timeMs': timeMs,
      'answeredAt': answeredAt.toIso8601String(),
    };
  }

  factory PlayerAnswer.fromJson(Map<dynamic, dynamic> json) {
    return PlayerAnswer(
      userId: json['userId']?.toString() ?? '',
      questionIndex: (json['questionIndex'] as num?)?.toInt() ?? 0,
      selectedOption: (json['selectedOption'] as num?)?.toInt() ?? -1,
      isCorrect: json['isCorrect'] == true,
      timeMs: (json['timeMs'] as num?)?.toInt() ?? 0,
      answeredAt: DateTime.tryParse(json['answeredAt']?.toString() ?? '') ?? DateTime.now(),
    );
  }
}

/// Online düello maçı
class OnlineDuelMatch {
  final String matchId;
  final String hostUserId;
  final String? guestUserId;
  final String hostUsername;
  final String? guestUsername;
  final String leagueCode;
  final OnlineDuelStatus status;
  final bool hostReady;
  final bool guestReady;
  final bool hostInDuelScreen;
  final bool guestInDuelScreen;
  final bool hostFinished;
  final bool guestFinished;
  final List<OnlineDuelQuestion> questions;
  final Map<String, List<PlayerAnswer>> playerAnswers;
  final DateTime createdAt;
  final DateTime? startedAt;
  final DateTime? finishedAt;
  final int currentQuestionIndex;
  final int hostScore;
  final int guestScore;
  final int hostLp;
  final int guestLp;
  final String? cancelledBy;

  final String? invitedUserId;
  final Map<String, dynamic>? lastEmote;
  final Map<String, String>? wordOfTheDay;

  const OnlineDuelMatch({
    required this.matchId,
    required this.hostUserId,
    this.guestUserId,
    required this.hostUsername,
    this.guestUsername,
    required this.leagueCode,
    required this.status,
    this.hostReady = false,
    this.guestReady = false,
    this.hostInDuelScreen = false,
    this.guestInDuelScreen = false,
    this.hostFinished = false,
    this.guestFinished = false,
    required this.questions,
    required this.playerAnswers,
    required this.createdAt,
    this.startedAt,
    this.finishedAt,
    this.currentQuestionIndex = 0,
    this.hostScore = 0,
    this.guestScore = 0,
    this.hostLp = 1500,
    this.guestLp = 1500,
    this.invitedUserId,
    this.cancelledBy,
    this.lastEmote,
    this.wordOfTheDay,
  });

  String? opponentUsername(String? currentId) {
    if (currentId == hostUserId) return guestUsername;
    return hostUsername;
  }

  String? opponentUserId(String? currentId) {
    if (currentId == hostUserId) return guestUserId;
    return hostUserId;
  }

  bool get isFull => guestUserId != null;
  bool get isWaiting => status == OnlineDuelStatus.waiting;
  bool get isReady => status == OnlineDuelStatus.ready;
  bool get isInProgress => status == OnlineDuelStatus.inProgress;
  bool get isFinished => status == OnlineDuelStatus.finished;

  OnlineDuelMatch copyWith({
    String? matchId,
    String? hostUserId,
    String? guestUserId,
    String? hostUsername,
    String? guestUsername,
    String? leagueCode,
    OnlineDuelStatus? status,
    bool? hostReady,
    bool? guestReady,
    bool? hostInDuelScreen,
    bool? guestInDuelScreen,
    bool? hostFinished,
    bool? guestFinished,
    List<OnlineDuelQuestion>? questions,
    Map<String, List<PlayerAnswer>>? playerAnswers,
    DateTime? createdAt,
    DateTime? startedAt,
    DateTime? finishedAt,
    int? hostScore,
    int? guestScore,
    int? hostLp,
    int? guestLp,
    String? invitedUserId,
    String? cancelledBy,
    Map<String, dynamic>? lastEmote,
    Map<String, String>? wordOfTheDay,
  }) {
    return OnlineDuelMatch(
      matchId: matchId ?? this.matchId,
      hostUserId: hostUserId ?? this.hostUserId,
      guestUserId: guestUserId ?? this.guestUserId,
      hostUsername: hostUsername ?? this.hostUsername,
      guestUsername: guestUsername ?? this.guestUsername,
      leagueCode: leagueCode ?? this.leagueCode,
      status: status ?? this.status,
      hostReady: hostReady ?? this.hostReady,
      guestReady: guestReady ?? this.guestReady,
      hostInDuelScreen: hostInDuelScreen ?? this.hostInDuelScreen,
      guestInDuelScreen: guestInDuelScreen ?? this.guestInDuelScreen,
      hostFinished: hostFinished ?? this.hostFinished,
      guestFinished: guestFinished ?? this.guestFinished,
      questions: questions ?? this.questions,
      playerAnswers: playerAnswers ?? this.playerAnswers,
      createdAt: createdAt ?? this.createdAt,
      startedAt: startedAt ?? this.startedAt,
      finishedAt: finishedAt ?? this.finishedAt,
      currentQuestionIndex: currentQuestionIndex ?? currentQuestionIndex,
      hostScore: hostScore ?? this.hostScore,
      guestScore: guestScore ?? this.guestScore,
      hostLp: hostLp ?? this.hostLp,
      guestLp: guestLp ?? this.guestLp,
      invitedUserId: invitedUserId ?? this.invitedUserId,
      cancelledBy: cancelledBy ?? this.cancelledBy,
      lastEmote: lastEmote ?? this.lastEmote,
      wordOfTheDay: wordOfTheDay ?? this.wordOfTheDay,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'matchId': matchId,
      'hostUserId': hostUserId,
      'guestUserId': guestUserId,
      'hostUsername': hostUsername,
      'guestUsername': guestUsername,
      'leagueCode': leagueCode,
      'status': status.name,
      'hostReady': hostReady,
      'guestReady': guestReady,
      'hostInDuelScreen': hostInDuelScreen,
      'guestInDuelScreen': guestInDuelScreen,
      'hostFinished': hostFinished,
      'guestFinished': guestFinished,
      'questions': questions.map((q) => q.toJson()).toList(),
      'playerAnswers': playerAnswers.map((k, v) => MapEntry(k, v.map((a) => a.toJson()).toList())),
      'createdAt': createdAt.toIso8601String(),
      'startedAt': startedAt?.toIso8601String(),
      'finishedAt': finishedAt?.toIso8601String(),
      'currentQuestionIndex': currentQuestionIndex,
      'hostScore': hostScore,
      'guestScore': guestScore,
      'hostLp': hostLp,
      'guestLp': guestLp,
      'invitedUserId': invitedUserId,
      'cancelledBy': cancelledBy,
      'lastEmote': lastEmote,
      'wordOfTheDay': wordOfTheDay,
    };
  }

  factory OnlineDuelMatch.fromJson(Map<dynamic, dynamic> json, [String? id]) {
    final playerAnswersMap = <String, List<PlayerAnswer>>{};
    
    // playerAnswers işlemesi
    if (json['playerAnswers'] != null) {
      final answersData = json['playerAnswers'] as Map<dynamic, dynamic>;
      answersData.forEach((key, value) {
        if (value is List) {
          playerAnswersMap[key.toString()] = value
              .map((a) => PlayerAnswer.fromJson(Map<String, dynamic>.from(a as Map)))
              .toList();
        }
      });
    }

    return OnlineDuelMatch(
      matchId: id ?? json['matchId']?.toString() ?? '',
      hostUserId: json['hostUserId']?.toString() ?? '',
      guestUserId: json['guestUserId']?.toString(),
      hostUsername: json['hostUsername']?.toString() ?? 'Player',
      guestUsername: json['guestUsername']?.toString(),
      leagueCode: json['leagueCode']?.toString() ?? 'A1',
      status: OnlineDuelStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => OnlineDuelStatus.waiting,
      ),
      hostReady: json['hostReady'] == true,
      guestReady: json['guestReady'] == true,
      hostInDuelScreen: json['hostInDuelScreen'] == true,
      guestInDuelScreen: json['guestInDuelScreen'] == true,
      hostFinished: json['hostFinished'] == true,
      guestFinished: json['guestFinished'] == true,
      questions: (json['questions'] as List<dynamic>?)
          ?.map((q) => OnlineDuelQuestion.fromJson(Map<String, dynamic>.from(q as Map)))
          .toList() ?? [],
      playerAnswers: playerAnswersMap,
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.now(),
      startedAt: json['startedAt'] != null ? DateTime.tryParse(json['startedAt'].toString()) : null,
      finishedAt: json['finishedAt'] != null ? DateTime.tryParse(json['finishedAt'].toString()) : null,
      currentQuestionIndex: (json['currentQuestionIndex'] as num?)?.toInt() ?? 0,
      hostScore: (json['hostScore'] as num?)?.toInt() ?? 0,
      guestScore: (json['guestScore'] as num?)?.toInt() ?? 0,
      hostLp: (json['hostLp'] as num?)?.toInt() ?? 1500,
      guestLp: (json['guestLp'] as num?)?.toInt() ?? 1500,
      invitedUserId: json['invitedUserId']?.toString(),
      cancelledBy: json['cancelledBy']?.toString(),
      lastEmote: json['lastEmote'] != null ? Map<String, dynamic>.from(json['lastEmote'] as Map) : null,
      wordOfTheDay: json['wordOfTheDay'] != null ? Map<String, String>.from(json['wordOfTheDay'] as Map) : null,
    );
  }
}
