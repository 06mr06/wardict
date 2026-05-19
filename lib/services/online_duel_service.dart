import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/friend.dart';
import '../models/question_mode.dart';
import 'firebase/auth_service.dart';
import 'user_profile_service.dart';

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

  const OnlineDuelQuestion({
    required this.id,
    required this.prompt,
    required this.options,
    required this.correctIndex,
    this.hint,
    this.mode = QuestionMode.enToTr,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'prompt': prompt,
    'options': options,
    'correctIndex': correctIndex,
    'hint': hint,
    'mode': mode.name,
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
  static const String _waitingCollection = 'waiting_players';

  StreamSubscription<DocumentSnapshot>? _matchSubscription;
  final StreamController<OnlineDuelMatch?> _matchController = StreamController<OnlineDuelMatch?>.broadcast();
  
  Stream<OnlineDuelMatch?> get matchStream => _matchController.stream;
  OnlineDuelMatch? _currentMatch;
  OnlineDuelMatch? get currentMatch => _currentMatch;

  /// Mevcut kullanıcı ID'si
  String? _currentUserId;
  String? _currentUsername;

  Future<void> initialize() async {
    final profile = await UserProfileService.instance.loadProfile();
    _currentUserId = AuthService.instance.userId ?? profile.username;
    _currentUsername = profile.username;
    if (_currentUserId != null) {
      OnlineDuelMatch.setCurrentUserId(_currentUserId!);
    }
  }

  /// Rastgele eşleşme ara
  Future<OnlineDuelMatch?> findRandomMatch(String leagueCode) async {
    if (_currentUserId == null) await initialize();
    if (_currentUserId == null) return null;

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
        return await _joinMatch(matchDoc.id);
      } else {
        // Yeni maç oluştur
        return await _createMatch(leagueCode);
      }
    } catch (e) {
      debugPrint('Error finding match: $e');
      // Fallback: Demo maç oluştur
      return _createDemoMatch(leagueCode);
    }
  }

  /// Arkadaşa düello daveti gönder
  Future<OnlineDuelMatch?> inviteFriend(Friend friend, String leagueCode) async {
    if (_currentUserId == null) await initialize();
    if (_currentUserId == null) return null;

    try {
      final match = await _createMatch(leagueCode, invitedUserId: friend.oderId);
      
      // Arkadaşa bildirim gönder (FCM ile)
      // TODO: FCM notification gönder
      
      return match;
    } catch (e) {
      debugPrint('Error inviting friend: $e');
      return _createDemoMatch(leagueCode);
    }
  }

  /// Maç oluştur
  Future<OnlineDuelMatch?> _createMatch(String leagueCode, {String? invitedUserId}) async {
    final matchId = 'match_${DateTime.now().millisecondsSinceEpoch}_${_currentUserId}';
    
    final questions = _generateQuestions(leagueCode);
    
    final match = OnlineDuelMatch(
      matchId: matchId,
      hostUserId: _currentUserId!,
      hostUsername: _currentUsername ?? 'Player',
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
  Future<OnlineDuelMatch?> _joinMatch(String matchId) async {
    try {
      await _firestore.collection(_matchesCollection).doc(matchId).update({
        'guestUserId': _currentUserId,
        'guestUsername': _currentUsername,
        'status': OnlineDuelStatus.ready.name,
      });

      final doc = await _firestore.collection(_matchesCollection).doc(matchId).get();
      if (doc.exists) {
        _currentMatch = OnlineDuelMatch.fromJson(doc.data()!);
        _listenToMatch(matchId);
        return _currentMatch;
      }
    } catch (e) {
      debugPrint('Error joining match: $e');
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
    if (_currentMatch == null || _currentUserId == null) return;

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
        if (!snapshot.exists) return;

        final data = snapshot.data()!;
        final playerAnswers = Map<String, dynamic>.from(data['playerAnswers'] ?? {});
        
        final answers = List<Map<String, dynamic>>.from(playerAnswers[_currentUserId] ?? []);
        answers.add(answer.toJson());
        playerAnswers[_currentUserId!] = answers;

        // Skoru güncelle
        int hostScore = data['hostScore'] ?? 0;
        int guestScore = data['guestScore'] ?? 0;
        
        if (isCorrect) {
          if (_currentUserId == data['hostUserId']) {
            hostScore++;
          } else {
            guestScore++;
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
    if (_currentMatch == null || !isCorrect) return;
    
    final isHost = _currentMatch!.hostUserId == _currentUserId;
    _currentMatch = _currentMatch!.copyWith(
      hostScore: isHost ? _currentMatch!.hostScore + 1 : _currentMatch!.hostScore,
      guestScore: !isHost ? _currentMatch!.guestScore + 1 : _currentMatch!.guestScore,
    );
    _matchController.add(_currentMatch);
  }

  /// Oyunu başlat
  Future<void> startGame() async {
    if (_currentMatch == null) return;

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
    if (_currentMatch == null) return;

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
    if (_currentMatch == null) return;

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
  OnlineDuelMatch _createDemoMatch(String leagueCode) {
    final matchId = 'demo_${DateTime.now().millisecondsSinceEpoch}';
    final questions = _generateQuestions(leagueCode);
    
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

  /// Sorular oluştur
  List<OnlineDuelQuestion> _generateQuestions(String leagueCode) {
    // Demo sorular - gerçek uygulamada Firestore'dan çekilir
    // Her soru için hem İngilizce hem Türkçe veriler
    final allQuestions = <Map<String, dynamic>>[
      {'english': 'abandon', 'turkish': 'terk etmek', 'wrongTr': ['kabul etmek', 'başarmak', 'reddetmek'], 'wrongEn': ['accept', 'achieve', 'refuse']},
      {'english': 'brilliant', 'turkish': 'parlak', 'wrongTr': ['karanlık', 'yavaş', 'sakin'], 'wrongEn': ['dark', 'slow', 'calm']},
      {'english': 'courage', 'turkish': 'cesaret', 'wrongTr': ['korku', 'şüphe', 'utanç'], 'wrongEn': ['fear', 'doubt', 'shame']},
      {'english': 'diligent', 'turkish': 'çalışkan', 'wrongTr': ['tembel', 'yorgun', 'kızgın'], 'wrongEn': ['lazy', 'tired', 'angry']},
      {'english': 'enormous', 'turkish': 'devasa', 'wrongTr': ['küçücük', 'orta', 'dar'], 'wrongEn': ['tiny', 'medium', 'narrow']},
      {'english': 'fierce', 'turkish': 'azgın', 'wrongTr': ['nazik', 'sakin', 'yavaş'], 'wrongEn': ['gentle', 'calm', 'slow']},
      {'english': 'generous', 'turkish': 'cömert', 'wrongTr': ['cimri', 'zalim', 'korkak'], 'wrongEn': ['stingy', 'cruel', 'coward']},
      {'english': 'hesitate', 'turkish': 'tereddüt etmek', 'wrongTr': ['acele etmek', 'karar vermek', 'emin olmak'], 'wrongEn': ['hurry', 'decide', 'be sure']},
      {'english': 'immense', 'turkish': 'muazzam', 'wrongTr': ['minik', 'dar', 'kısa'], 'wrongEn': ['tiny', 'narrow', 'short']},
      {'english': 'jealous', 'turkish': 'kıskanç', 'wrongTr': ['mutlu', 'nazik', 'sakin'], 'wrongEn': ['happy', 'kind', 'calm']},
      {'english': 'accomplish', 'turkish': 'başarmak', 'wrongTr': ['başarısız olmak', 'denemek', 'vazgeçmek'], 'wrongEn': ['fail', 'try', 'give up']},
      {'english': 'ancient', 'turkish': 'antik', 'wrongTr': ['modern', 'yeni', 'güncel'], 'wrongEn': ['modern', 'new', 'current']},
      {'english': 'beautiful', 'turkish': 'güzel', 'wrongTr': ['çirkin', 'normal', 'sıradan'], 'wrongEn': ['ugly', 'normal', 'ordinary']},
      {'english': 'celebrate', 'turkish': 'kutlamak', 'wrongTr': ['ağlamak', 'üzülmek', 'kızmak'], 'wrongEn': ['cry', 'grieve', 'angry']},
      {'english': 'dangerous', 'turkish': 'tehlikeli', 'wrongTr': ['güvenli', 'rahat', 'kolay'], 'wrongEn': ['safe', 'comfortable', 'easy']},
      {'english': 'eager', 'turkish': 'hevesli', 'wrongTr': ['temkinli', 'tembel', 'kayıtsız'], 'wrongEn': ['cautious', 'lazy', 'indifferent']},
      {'english': 'famous', 'turkish': 'ünlü', 'wrongTr': ['bilinmeyen', 'gizli', 'sıradan'], 'wrongEn': ['unknown', 'hidden', 'ordinary']},
      {'english': 'gentle', 'turkish': 'nazik', 'wrongTr': ['sert', 'kaba', 'acımasız'], 'wrongEn': ['harsh', 'rude', 'cruel']},
      {'english': 'honest', 'turkish': 'dürüst', 'wrongTr': ['yalancı', 'sahtekar', 'güvenilmez'], 'wrongEn': ['liar', 'fake', 'unreliable']},
      {'english': 'innocent', 'turkish': 'masum', 'wrongTr': ['suçlu', 'kötü', 'zararlı'], 'wrongEn': ['guilty', 'evil', 'harmful']},
      {'english': 'joyful', 'turkish': 'neşeli', 'wrongTr': ['üzgün', 'sinirli', 'endişeli'], 'wrongEn': ['sad', 'angry', 'anxious']},
      {'english': 'knowledge', 'turkish': 'bilgi', 'wrongTr': ['cehalet', 'şüphe', 'korku'], 'wrongEn': ['ignorance', 'doubt', 'fear']},
      {'english': 'lazy', 'turkish': 'tembel', 'wrongTr': ['çalışkan', 'enerjik', 'aktif'], 'wrongEn': ['diligent', 'energetic', 'active']},
      {'english': 'mysterious', 'turkish': 'gizemli', 'wrongTr': ['açık', 'basit', 'anlaşılır'], 'wrongEn': ['clear', 'simple', 'obvious']},
      {'english': 'nervous', 'turkish': 'gergin', 'wrongTr': ['sakin', 'rahat', 'mutlu'], 'wrongEn': ['calm', 'relaxed', 'happy']},
      {'english': 'obvious', 'turkish': 'açık', 'wrongTr': ['gizli', 'belirsiz', 'karmaşık'], 'wrongEn': ['hidden', 'vague', 'complex']},
      {'english': 'patient', 'turkish': 'sabırlı', 'wrongTr': ['aceleci', 'sinirli', 'tahammülsüz'], 'wrongEn': ['impatient', 'nervous', 'intolerant']},
      {'english': 'quiet', 'turkish': 'sessiz', 'wrongTr': ['gürültülü', 'şamatalı', 'patırtılı'], 'wrongEn': ['noisy', 'loud', 'rowdy']},
      {'english': 'reliable', 'turkish': 'güvenilir', 'wrongTr': ['güvenilmez', 'şüpheli', 'riskli'], 'wrongEn': ['unreliable', 'suspicious', 'risky']},
      {'english': 'serious', 'turkish': 'ciddi', 'wrongTr': ['komik', 'şakacı', 'eğlenceli'], 'wrongEn': ['funny', 'joking', 'amusing']},
    ];

    // Soruları karıştır ve 10 tanesini seç
    allQuestions.shuffle();
    final selectedQuestions = allQuestions.take(10).toList();
    
    // Modları tanımla (enToTr ve trToEn karışık)
    final modes = [QuestionMode.enToTr, QuestionMode.trToEn];
    
    final questions = <OnlineDuelQuestion>[];
    for (int i = 0; i < selectedQuestions.length; i++) {
      final data = selectedQuestions[i];
      final mode = modes[i % modes.length]; // Her soruya dönüşümlü mod ata
      
      String prompt;
      List<String> options;
      int correctIndex;
      
      if (mode == QuestionMode.enToTr) {
        // İngilizce kelime, Türkçe şıklar
        prompt = data['english'] as String;
        final wrongOptions = List<String>.from(data['wrongTr'] as List);
        wrongOptions.shuffle();
        options = [data['turkish'] as String, ...wrongOptions.take(3)];
        options.shuffle();
        correctIndex = options.indexOf(data['turkish'] as String);
      } else {
        // Türkçe kelime, İngilizce şıklar
        prompt = data['turkish'] as String;
        final wrongOptions = List<String>.from(data['wrongEn'] as List);
        wrongOptions.shuffle();
        options = [data['english'] as String, ...wrongOptions.take(3)];
        options.shuffle();
        correctIndex = options.indexOf(data['english'] as String);
      }
      
      questions.add(OnlineDuelQuestion(
        id: 'q_$i',
        prompt: prompt,
        options: options,
        correctIndex: correctIndex,
        mode: mode,
      ));
    }

    return questions;
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
