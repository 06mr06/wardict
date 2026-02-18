
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/friend.dart';
import '../models/question_mode.dart';
import 'user_profile_service.dart';
import 'word_pool_service.dart';
import '../models/user_level.dart';
import 'firebase/auth_service.dart';

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
  final String level;

  const OnlineDuelQuestion({
    required this.id,
    required this.prompt,
    required this.options,
    required this.correctIndex,
    this.hint,
    this.mode = QuestionMode.enToTr,
    this.level = 'A1',
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'prompt': prompt,
    'options': options,
    'correctIndex': correctIndex,
    'hint': hint,
    'mode': mode.name,
    'level': level,
  };

  factory OnlineDuelQuestion.fromJson(Map<String, dynamic> json) {
    QuestionMode mode = QuestionMode.enToTr;
    if (json['mode'] != null) {
      mode = QuestionMode.values.firstWhere(
        (m) => m.name == json['mode'],
        orElse: () => QuestionMode.enToTr,
      );
    }
    return OnlineDuelQuestion(
      id: json['id'] ?? '',
      prompt: json['prompt'] ?? '',
      options: List<String>.from(json['options'] ?? []),
      correctIndex: json['correctIndex'] ?? 0,
      hint: json['hint'],
      mode: mode,
      level: json['level'] ?? 'A1',
    );
  }
}

/// Oyuncu cevabı
class PlayerAnswer {
  final String oderId;
  final int questionIndex;
  final int selectedOption;
  final bool isCorrect;
  final int timeMs; // Cevaplama süresi (ms)
  final DateTime answeredAt;

  const PlayerAnswer({
    required this.oderId,
    required this.questionIndex,
    required this.selectedOption,
    required this.isCorrect,
    required this.timeMs,
    required this.answeredAt,
  });

  Map<String, dynamic> toJson() => {
    'oderId': oderId,
    'questionIndex': questionIndex,
    'selectedOption': selectedOption,
    'isCorrect': isCorrect,
    'timeMs': timeMs,
    'answeredAt': answeredAt.toIso8601String(),
  };

  factory PlayerAnswer.fromJson(Map<String, dynamic> json) {
    return PlayerAnswer(
      oderId: json['oderId'] ?? '',
      questionIndex: json['questionIndex'] ?? 0,
      selectedOption: json['selectedOption'] ?? -1,
      isCorrect: json['isCorrect'] ?? false,
      timeMs: json['timeMs'] ?? 0,
      answeredAt: DateTime.tryParse(json['answeredAt'] ?? '') ?? DateTime.now(),
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
  final List<OnlineDuelQuestion> questions;
  final Map<String, List<PlayerAnswer>> playerAnswers;
  final DateTime createdAt;
  final DateTime? startedAt;
  final DateTime? finishedAt;
  final int currentQuestionIndex;
  final int hostScore;
  final int guestScore;

  const OnlineDuelMatch({
    required this.matchId,
    required this.hostUserId,
    this.guestUserId,
    required this.hostUsername,
    this.guestUsername,
    required this.leagueCode,
    required this.status,
    required this.questions,
    required this.playerAnswers,
    required this.createdAt,
    this.startedAt,
    this.finishedAt,
    this.currentQuestionIndex = 0,
    this.hostScore = 0,
    this.guestScore = 0,
  });

  bool get isHost => hostUserId == _currentUserId;
  bool get isGuest => guestUserId == _currentUserId;
  bool get isFull => guestUserId != null;
  bool get isWaiting => status == OnlineDuelStatus.waiting;
  bool get isReady => status == OnlineDuelStatus.ready;
  bool get isInProgress => status == OnlineDuelStatus.inProgress;
  bool get isFinished => status == OnlineDuelStatus.finished;

  String? get opponentUsername => isHost ? guestUsername : hostUsername;
  String? get opponentId => isHost ? guestUserId : hostUserId;
  int get myScore => isHost ? hostScore : guestScore;
  int get opponentScore => isHost ? guestScore : hostScore;

  static String? _currentUserId;
  static void setCurrentUserId(String oderId) => _currentUserId = oderId;

  Map<String, dynamic> toJson() => {
    'matchId': matchId,
    'hostUserId': hostUserId,
    'guestUserId': guestUserId,
    'hostUsername': hostUsername,
    'guestUsername': guestUsername,
    'leagueCode': leagueCode,
    'status': status.name,
    'questions': questions.map((q) => q.toJson()).toList(),
    'playerAnswers': playerAnswers.map((k, v) => MapEntry(k, v.map((a) => a.toJson()).toList())),
    'createdAt': createdAt.toIso8601String(),
    'startedAt': startedAt?.toIso8601String(),
    'finishedAt': finishedAt?.toIso8601String(),
    'currentQuestionIndex': currentQuestionIndex,
    'hostScore': hostScore,
    'guestScore': guestScore,
  };

  factory OnlineDuelMatch.fromJson(Map<String, dynamic> json) {
    return OnlineDuelMatch(
      matchId: json['matchId'] ?? '',
      hostUserId: json['hostUserId'] ?? '',
      guestUserId: json['guestUserId'],
      hostUsername: json['hostUsername'] ?? '',
      guestUsername: json['guestUsername'],
      leagueCode: json['leagueCode'] ?? 'A1',
      status: OnlineDuelStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => OnlineDuelStatus.waiting,
      ),
      questions: (json['questions'] as List<dynamic>?)
          ?.map((q) => OnlineDuelQuestion.fromJson(q))
          .toList() ?? [],
      playerAnswers: (json['playerAnswers'] as Map<String, dynamic>?)?.map(
        (k, v) => MapEntry(k, (v as List).map((a) => PlayerAnswer.fromJson(a)).toList()),
      ) ?? {},
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
      startedAt: json['startedAt'] != null ? DateTime.tryParse(json['startedAt']) : null,
      finishedAt: json['finishedAt'] != null ? DateTime.tryParse(json['finishedAt']) : null,
      currentQuestionIndex: json['currentQuestionIndex'] ?? 0,
      hostScore: json['hostScore'] ?? 0,
      guestScore: json['guestScore'] ?? 0,
    );
  }

  OnlineDuelMatch copyWith({
    String? matchId,
    String? hostUserId,
    String? guestUserId,
    String? hostUsername,
    String? guestUsername,
    String? leagueCode,
    OnlineDuelStatus? status,
    List<OnlineDuelQuestion>? questions,
    Map<String, List<PlayerAnswer>>? playerAnswers,
    DateTime? createdAt,
    DateTime? startedAt,
    DateTime? finishedAt,
    int? currentQuestionIndex,
    int? hostScore,
    int? guestScore,
  }) {
    return OnlineDuelMatch(
      matchId: matchId ?? this.matchId,
      hostUserId: hostUserId ?? this.hostUserId,
      guestUserId: guestUserId ?? this.guestUserId,
      hostUsername: hostUsername ?? this.hostUsername,
      guestUsername: guestUsername ?? this.guestUsername,
      leagueCode: leagueCode ?? this.leagueCode,
      status: status ?? this.status,
      questions: questions ?? this.questions,
      playerAnswers: playerAnswers ?? this.playerAnswers,
      createdAt: createdAt ?? this.createdAt,
      startedAt: startedAt ?? this.startedAt,
      finishedAt: finishedAt ?? this.finishedAt,
      currentQuestionIndex: currentQuestionIndex ?? this.currentQuestionIndex,
      hostScore: hostScore ?? this.hostScore,
      guestScore: guestScore ?? this.guestScore,
    );
  }
}

/// Online Düello Servisi
class OnlineDuelService {
  static final OnlineDuelService instance = OnlineDuelService._internal();
  OnlineDuelService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  static const String _matchesCollection = 'online_duels';
  // ignore: unused_field - Waiting queue için saklanıyor
  static const String _waitingCollection = 'waiting_players';

  StreamSubscription<DocumentSnapshot>? _matchSubscription;
  final StreamController<OnlineDuelMatch?> _matchController = StreamController<OnlineDuelMatch?>.broadcast();
  
  Stream<OnlineDuelMatch?> get matchStream => _matchController.stream;
  OnlineDuelMatch? _currentMatch;
  OnlineDuelMatch? get currentMatch => _currentMatch;
  StreamSubscription? _invitationSubscription; // Davetleri dinlemek için
  

  /// Mevcut kullanıcı ID'si
  String? _currentUserId;
  String? _currentUsername;

  Future<void> initialize() async {
    final profile = await UserProfileService.instance.loadProfile();
    
    // Auth ID varsa onu kullan (Firestore'daki ID ile eşleşmesi için)
    final authUserId = AuthService.instance.userId;
    if (authUserId != null) {
      _currentUserId = authUserId;
      _currentUsername = profile.username.isNotEmpty ? profile.username : 'Player';
    } else {
      // Fallback: Username veya geçici ID kullan
      _currentUserId = profile.username.isNotEmpty ? profile.username : 'Player';
      _currentUsername = _currentUserId;
      
      // Yerel testlerde çakışmayı önlemek için 'Player' ise rastgele suffix ekle
      if (_currentUserId == 'Player') {
        final randomSuffix = (100 + (DateTime.now().millisecond % 900)).toString();
        _currentUserId = 'Player_$randomSuffix';
        _currentUsername = 'Player_$randomSuffix';
      }
    }

    if (_currentUserId != null) {
      OnlineDuelMatch.setCurrentUserId(_currentUserId!);
    }
  }

  /// Rastgele eşleşme ara
  Future<OnlineDuelMatch?> findRandomMatch(String leagueCode) async {
    if (_currentUserId == null) {
      await initialize();
    }
    if (_currentUserId == null) {
      return null;
    }

    try {
      // Önce bekleyen bir maç var mı kontrol et
      final waitingMatches = await _firestore
          .collection(_matchesCollection)
          .where('status', isEqualTo: OnlineDuelStatus.waiting.name)
          .where('leagueCode', isEqualTo: leagueCode)
          .where('hostUserId', isNotEqualTo: _currentUserId)
          .limit(1)
          .get();

      if (waitingMatches.docs.isNotEmpty) {
        // Bekleyen maça katıl
        final matchDoc = waitingMatches.docs.first;
        return await joinMatch(matchDoc.id);
      } else {
        // Yeni maç oluştur
        return await _createMatch(leagueCode);
      }
    } catch (e) {
      debugPrint('Error finding match: $e');
      // Fallback: Demo maç oluştur
      return await _createDemoMatch(leagueCode);
    }
  }

  /// Arkadaşa düello daveti gönder
  Future<OnlineDuelMatch?> inviteFriend(Friend friend, String leagueCode) async {
    if (_currentUserId == null) {
      await initialize();
    }
    if (_currentUserId == null) {
      return null;
    }

    try {
      debugPrint('📤 Sending invitation from $_currentUserId to ${friend.oderId} (${friend.username})');
      final match = await _createMatch(leagueCode, invitedUserId: friend.oderId);
      debugPrint('✅ Invitation created: Match ID ${match?.matchId}');
      return match;
    } catch (e) {
      debugPrint('❌ Error inviting friend: $e');
      return null;
    }
  }

  /// Rövanş (Tekrar Oyna) daveti gönder
  Future<OnlineDuelMatch?> inviteRematch(String opponentId, String leagueCode) async {
    if (_currentUserId == null) {
      await initialize();
    }
    if (_currentUserId == null) {
      return null;
    }

    try {
      final match = await _createMatch(leagueCode, invitedUserId: opponentId);
      return match;
    } catch (e) {
      debugPrint('Error inviting rematch: $e');
      return null;
    }
  }

  /// Davetleri dinle
  void listenForInvitations(Function(OnlineDuelMatch) onInvitation) {
    if (_currentUserId == null) {
      return;
    }
    
    debugPrint('👂 Listening for invitations for user: $_currentUserId');
    
    _invitationSubscription?.cancel();
    _invitationSubscription = _firestore.collection(_matchesCollection)
      .where('guestUserId', isEqualTo: _currentUserId)
      .where('status', isEqualTo: OnlineDuelStatus.waiting.name)
      .snapshots()
      .listen((snapshot) {
        debugPrint('📬 Invitation query result: ${snapshot.docs.length} matches');
        for (var change in snapshot.docChanges) {
          if (change.type == DocumentChangeType.added) {
            final match = OnlineDuelMatch.fromJson(change.doc.data()!);
            debugPrint('🔔 New invitation received! From: ${match.hostUsername}, Match: ${match.matchId}');
            onInvitation(match);
          }
        }
      });
  }

  /// Maç oluştur
  Future<OnlineDuelMatch?> _createMatch(String leagueCode, {String? invitedUserId}) async {
    final matchId = 'match_${DateTime.now().millisecondsSinceEpoch}_$_currentUserId';
    
    final questions = await _generateQuestions(leagueCode);
    
    final match = OnlineDuelMatch(
      matchId: matchId,
      hostUserId: _currentUserId!,
      hostUsername: _currentUsername ?? 'Player',
      guestUserId: invitedUserId, // Davet edilen kullanıcıyı burada set ediyoruz
      leagueCode: leagueCode,
      status: OnlineDuelStatus.waiting,
      questions: questions,
      playerAnswers: {},
      createdAt: DateTime.now(),
    );

    try {
      await _firestore.collection(_matchesCollection).doc(matchId).set(match.toJson());
      _currentMatch = match;
      _listenToMatch(matchId);
      return match;
    } catch (e) {
      debugPrint('Error creating match: $e');
      return match; // Offline modda devam et
    }
  }

  /// Maça katıl
  Future<OnlineDuelMatch?> joinMatch(String matchId) async {
    debugPrint('🎮 Attempting to join match: $matchId');
    debugPrint('   Current user: $_currentUserId ($_currentUsername)');
    
    try {
      debugPrint('   Updating match with guest info...');
      await _firestore.collection(_matchesCollection).doc(matchId).update({
        'guestUserId': _currentUserId,
        'guestUsername': _currentUsername,
        'status': OnlineDuelStatus.ready.name,
      });
      debugPrint('   ✅ Match updated successfully');

      debugPrint('   Fetching updated match data...');
      final doc = await _firestore.collection(_matchesCollection).doc(matchId).get();
      if (doc.exists) {
        debugPrint('   ✅ Match data retrieved');
        _currentMatch = OnlineDuelMatch.fromJson(doc.data()!);
        _listenToMatch(matchId);
        debugPrint('   🎉 Successfully joined match! Host: ${_currentMatch!.hostUsername}, Guest: ${_currentMatch!.guestUsername}');
        return _currentMatch;
      } else {
        debugPrint('   ❌ Match document does not exist');
      }
    } catch (e) {
      debugPrint('❌ Error joining match: $e');
    }
    return null;
  }

  /// Maç değişikliklerini dinle
  void _listenToMatch(String matchId) {
    _matchSubscription?.cancel();
    
    try {
      _matchSubscription = _firestore
          .collection(_matchesCollection)
          .doc(matchId)
          .snapshots()
          .listen((snapshot) {
        if (snapshot.exists) {
          _currentMatch = OnlineDuelMatch.fromJson(snapshot.data()!);
          _matchController.add(_currentMatch);
        }
      });
    } catch (e) {
      debugPrint('Error listening to match: $e');
    }
  }

  /// Cevap gönder
  Future<void> submitAnswer(int questionIndex, int selectedOption, int timeMs) async {
    if (_currentMatch == null || _currentUserId == null) {
      return;
    }

    final question = _currentMatch!.questions[questionIndex];
    final isCorrect = selectedOption == question.correctIndex;

    final answer = PlayerAnswer(
      oderId: _currentUserId!,
      questionIndex: questionIndex,
      selectedOption: selectedOption,
      isCorrect: isCorrect,
      timeMs: timeMs,
      answeredAt: DateTime.now(),
    );

    try {
      // Firestore'a cevabı ekle
      final matchRef = _firestore.collection(_matchesCollection).doc(_currentMatch!.matchId);
      
      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(matchRef);
        if (!snapshot.exists) {
          return;
        }

        final data = snapshot.data()!;
        final playerAnswers = Map<String, dynamic>.from(data['playerAnswers'] ?? {});
        
        final answers = List<Map<String, dynamic>>.from(playerAnswers[_currentUserId] ?? []);
        
        // Calculate Streak (before adding current answer)
        int currentStreak = 0;
        if (answers.isNotEmpty) {
           for (int i = answers.length - 1; i >= 0; i--) {
              if (answers[i]['isCorrect'] == true) {
                 currentStreak++;
              } else {
                 break;
              }
           }
        }

        answers.add(answer.toJson());
        playerAnswers[_currentUserId!] = answers;

        // Skoru güncelle
        int hostScore = data['hostScore'] ?? 0;
        int guestScore = data['guestScore'] ?? 0;
        
        if (isCorrect) {
          // Puanlama Mantığı
          int baseScore = 10;
          
          // 1. Seviye Bonusu
          int levelMult = 1;
          if (question.level.startsWith('B')) {
            levelMult = 2;
          }
          if (question.level.startsWith('C')) {
            levelMult = 3;
          }
          
          // 2. Hız Bonusu
          double speedMult = 1.0;
          if (timeMs < 2000) {
            speedMult = 1.5;
          } else if (timeMs < 5000) {
            speedMult = 1.2;
          }
          
          // 3. Seri Bonusu
          int streakBonus = (currentStreak + 1) * 2;
          
          int points = (baseScore * levelMult * speedMult).round() + streakBonus;

          if (_currentUserId == data['hostUserId']) {
            hostScore += points;
          } else {
            guestScore += points;
          }
        }

        transaction.update(matchRef, {
          'playerAnswers': playerAnswers,
          'hostScore': hostScore,
          'guestScore': guestScore,
        });
      });
    } catch (e) {
      debugPrint('Error submitting answer: $e');
      // Offline modda lokal güncelle
      _updateLocalScore(isCorrect);
    }
  }

  void _updateLocalScore(bool isCorrect) {
    if (_currentMatch == null || !isCorrect) {
      return;
    }
    
    final isHost = _currentMatch!.hostUserId == _currentUserId;
    _currentMatch = _currentMatch!.copyWith(
      hostScore: isHost ? _currentMatch!.hostScore + 1 : _currentMatch!.hostScore,
      guestScore: !isHost ? _currentMatch!.guestScore + 1 : _currentMatch!.guestScore,
    );
    _matchController.add(_currentMatch);
  }

  /// Oyunu başlat
  Future<void> startGame() async {
    if (_currentMatch == null) {
      return;
    }

    try {
      await _firestore.collection(_matchesCollection).doc(_currentMatch!.matchId).update({
        'status': OnlineDuelStatus.inProgress.name,
        'startedAt': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('Error starting game: $e');
    }
  }

  /// Oyunu bitir
  Future<void> finishGame() async {
    if (_currentMatch == null) {
      return;
    }

    try {
      await _firestore.collection(_matchesCollection).doc(_currentMatch!.matchId).update({
        'status': OnlineDuelStatus.finished.name,
        'finishedAt': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('Error finishing game: $e');
    }
  }

  /// Maçı iptal et
  Future<void> cancelMatch() async {
    if (_currentMatch == null) {
      return;
    }

    try {
      await _firestore.collection(_matchesCollection).doc(_currentMatch!.matchId).update({
        'status': OnlineDuelStatus.cancelled.name,
      });
    } catch (e) {
      debugPrint('Error cancelling match: $e');
    }

    _matchSubscription?.cancel();
    _currentMatch = null;
    _matchController.add(null);
  }

  /// Maç dinleyicisini kapat
  void dispose() {
    _matchSubscription?.cancel();
    _matchController.close();
  }

  /// Demo maç oluştur (offline mod için)
  Future<OnlineDuelMatch> _createDemoMatch(String leagueCode) async {
    final matchId = 'demo_${DateTime.now().millisecondsSinceEpoch}';
    final questions = await _generateQuestions(leagueCode);
    
    return OnlineDuelMatch(
      matchId: matchId,
      hostUserId: _currentUserId ?? 'demo_user',
      hostUsername: _currentUsername ?? 'Player',
      guestUserId: 'bot_user',
      guestUsername: 'Bot 🤖',
      leagueCode: leagueCode,
      status: OnlineDuelStatus.ready,
      questions: questions,
      playerAnswers: {},
      createdAt: DateTime.now(),
    );
  }

  /// Sorular oluştur (Gerçek veri ile)
  Future<List<OnlineDuelQuestion>> _generateQuestions(String leagueCode) async {
    // Profil ve kelime havuzunu yükle
    await WordPoolService.instance.loadWordPool();
    final profile = await UserProfileService.instance.loadProfile();
    
    // Convert leagueCode (which is UserLevel code) to UserLevel
    final level = UserLevel.fromCode(leagueCode);
    
    // Generate questions with ELO consideration
    final generatedQs = WordPoolService.instance.generateQuestions(
      level, 
      elo: profile.eloRating
    );
    
    // Convert to OnlineDuelQuestion
    return generatedQs.asMap().entries.map((entry) {
      final index = entry.key;
      final gq = entry.value;
      
      QuestionMode mode = QuestionMode.enToTr;
      switch (gq.mode) {
        case QuestionType.enToTr:
          mode = QuestionMode.enToTr;
          break;
        case QuestionType.trToEn:
          mode = QuestionMode.trToEn;
          break;
        case QuestionType.synonym:
        case QuestionType.antonym:
        case QuestionType.relation:
          mode = QuestionMode.engToEng;
          break;
      }

      return OnlineDuelQuestion(
        id: 'q_$index',
        prompt: gq.prompt,
        options: gq.options,
        correctIndex: gq.correctIndex,
        mode: mode,
        level: gq.level,
      );
    }).toList();
  }
  
  /// Demo sorular - MaxiGame için public erişim
  List<Map<String, dynamic>> getDemoQuestions() {
    final allQuestions = <Map<String, dynamic>>[
      {'english': 'abandon', 'options': ['terk etmek', 'kabul etmek', 'başarmak', 'reddetmek'], 'correctIndex': 0},
      {'english': 'brilliant', 'options': ['karanlık', 'parlak', 'yavaş', 'sakin'], 'correctIndex': 1},
      {'english': 'courage', 'options': ['korku', 'şüphe', 'cesaret', 'utanç'], 'correctIndex': 2},
      {'english': 'diligent', 'options': ['tembel', 'yorgun', 'kızgın', 'çalışkan'], 'correctIndex': 3},
      {'english': 'enormous', 'options': ['devasa', 'küçücük', 'orta', 'dar'], 'correctIndex': 0},
      {'english': 'fierce', 'options': ['nazik', 'azgın', 'sakin', 'yavaş'], 'correctIndex': 1},
      {'english': 'generous', 'options': ['cimri', 'zalim', 'cömert', 'korkak'], 'correctIndex': 2},
      {'english': 'hesitate', 'options': ['acele etmek', 'karar vermek', 'emin olmak', 'tereddüt etmek'], 'correctIndex': 3},
      {'english': 'immense', 'options': ['muazzam', 'minik', 'normal', 'kısa'], 'correctIndex': 0},
      {'english': 'jealous', 'options': ['mutlu', 'kıskanç', 'sakin', 'nazik'], 'correctIndex': 1},
      {'english': 'keen', 'options': ['yorgun', 'üzgün', 'hevesli', 'korkak'], 'correctIndex': 2},
      {'english': 'loyal', 'options': ['hain', 'yabancı', 'düşman', 'sadık'], 'correctIndex': 3},
      {'english': 'magnificent', 'options': ['muhteşem', 'sıradan', 'kötü', 'korkunç'], 'correctIndex': 0},
      {'english': 'noble', 'options': ['kaba', 'asil', 'fakir', 'acı'], 'correctIndex': 1},
      {'english': 'obvious', 'options': ['gizli', 'karmaşık', 'açık', 'belirsiz'], 'correctIndex': 2},
      {'english': 'precious', 'options': ['ucuz', 'eski', 'kirli', 'değerli'], 'correctIndex': 3},
      {'english': 'quiet', 'options': ['sessiz', 'gürültülü', 'hızlı', 'parlak'], 'correctIndex': 0},
      {'english': 'rapid', 'options': ['yavaş', 'hızlı', 'sakin', 'ağır'], 'correctIndex': 1},
      {'english': 'sincere', 'options': ['sahte', 'kurnaz', 'samimi', 'yalancı'], 'correctIndex': 2},
      {'english': 'tremendous', 'options': ['küçük', 'zayıf', 'yavaş', 'muazzam'], 'correctIndex': 3},
    ];
    allQuestions.shuffle();
    return allQuestions;
  }
}
