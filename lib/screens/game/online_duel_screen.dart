import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:confetti/confetti.dart';
import 'package:lugorena/services/online_duel_service.dart';
import '../../services/sound_service.dart';
import '../../services/user_profile_service.dart';
import '../../services/shop_service.dart';
import '../../services/firebase/auth_service.dart';
import '../../models/cosmetic_item.dart';
import '../../models/question_mode.dart';
import '../../models/answered_entry.dart';
import '../../models/league.dart';
import '../../models/powerup.dart';
import '../../models/user_level.dart';
import 'package:lugorena/models/online_duel.dart';
import '../../services/firebase/firestore_service.dart';
import '../../services/ranking_service.dart';
import '../../widgets/game/game_background.dart';
import '../../widgets/game/game_timer.dart';
import '../../widgets/game/game_confetti.dart';
import '../../widgets/game/question_card.dart';
import '../../widgets/game/options_grid.dart';
import '../../widgets/game/game_progress_bar.dart';
import 'vs_screen.dart';
import 'online_duel_results_screen.dart';
import '../../widgets/game/lottie_answer_overlay.dart';
import '../../models/match_history_item.dart';
import '../../services/quest_service.dart';
import '../../services/achievement_service.dart';
import '../../services/feed_service.dart';
import '../../models/quest.dart';
import '../../models/achievement.dart';
import '../../models/feed_item.dart';
import '../../services/word_usage_service.dart';
import '../../providers/language_provider.dart';
import '../../app.dart';

class OnlineDuelScreen extends StatefulWidget {
  final OnlineDuelMatch match;
  final Map<String, String>? wordOfTheDay;

  /// Bu maç bir rövanş zincirinin parçası ise true.
  final bool isRematch;

  const OnlineDuelScreen({
    super.key,
    required this.match,
    this.wordOfTheDay,
    this.isRematch = false,
  });

  @override
  State<OnlineDuelScreen> createState() => _OnlineDuelScreenState();
}

class _OnlineDuelScreenState extends State<OnlineDuelScreen>
    with TickerProviderStateMixin {
  late OnlineDuelMatch _match;
  int _currentQuestionIndex = 0;
  int? _selectedOption;
  int? _botSelection;
  bool _locked = false;

  int _myScore = 0;
  int _opponentScore = 0;
  int _myStreak = 0;
  int _opponentStreak = 0;

  Timer? _questionTimer;
  int _timeLeft = 7;

  bool _showVsAnim = true;
  int _interstitialStep = 0;
  bool _showCountdown = false;
  int _countdownValue = 3;

  bool _waitingForOpponent = false;
  bool _isTransitioning = false;
  bool _showWaitingForGuest = false; // Host rakip bekliyor mu?

  late AnimationController _pulseController;
  late AnimationController _opponentPulseController;
  late Animation<double> _pulseAnim;
  late Animation<double> _opponentPulseAnim;
  late ConfettiController _confettiController;

  StreamSubscription? _matchSubscription;

  Timer? _botTimer;
  Timer? _waitingFallbackTimer;
  bool _isDemo = false;
  bool _syncingStart = false;
  final _rng = Random();

  final List<AnsweredEntry> _answeredItems = [];

  List<List<String>> _shuffledOptions = [];
  List<int> _shuffledCorrectIndexes = [];

  String? _myAvatarEmoji;
  String? _mySelectedEmote;
  String? _myPhotoUrl;
  String _opponentAvatar = '👤';
  String? _opponentPhotoUrl;
  late String _botName;
  CloudUserProfile? _myProfile;
  CloudUserProfile? _opponentProfile;

  List<QuestionMode> _questionModes = [];
  String? _myEmote;
  String? _opponentEmote;
  Timer? _myEmoteTimer;
  Timer? _opponentEmoteTimer;
  int? _lastEmoteTimestamp;

  // Power-up States
  PowerupInventory? _inventory;
  Set<int> _eliminatedOptions = {};
  bool _doubleChanceActive = false;
  double _scoreMultiplier = 1.0;
  List<PowerupType> _usedPowerupsInCurrentQuestion = [];
  bool _iQuit = false; // Flag to track if local user initiated the exit

  bool _showAnswerAnimation = false;
  bool _answerIsCorrect = false;

  String? get _currentUserId => OnlineDuelService.instance.currentUserId;
  bool get _isHost => _match.hostUserId == _currentUserId;
  String? get _opponentId => _isHost ? _match.guestUserId : _match.hostUserId;
  String? get _opponentUsername {
    if (_isDemo) return '${_opponentAvatar ?? "👤"} ${_botName ?? "Bot"}';
    return (_isHost ? _match.guestUsername : _match.hostUsername) ??
        _opponentProfile?.username;
  }

  @override
  void initState() {
    super.initState();
    _match = widget.match;
    _isDemo = _match.matchId.startsWith('demo_');

    _confettiController =
        ConfettiController(duration: const Duration(seconds: 3));

    _pulseController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    _opponentPulseController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeOut),
    );
    _opponentPulseAnim = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _opponentPulseController, curve: Curves.easeOut),
    );

    _initBotIdentity();
    _initAvatars();
    _shuffleQuestionsAndOptions();

    // Eğer host ise ve maç 'waiting' ise bekleme ekranını göster
    if (_isHost && _match.status == OnlineDuelStatus.waiting && !_isDemo) {
      _showWaitingForGuest = true;
      _showVsAnim = false;
      _startWaitingTimer(); // Sayacı başlat
    }

    _currentIndexFromHistory();
    _syncScores();
    _reconstructAnsweredItems();
    _listenToMatch();
    _loadInventory();

    // Lichess-benzeri senkron: sadece duello ekranındaki oyuncular yarışsın.
    if (!_isDemo) {
      OnlineDuelService.instance.setInDuelScreen(true);
    }
  }

  void _currentIndexFromHistory() {
    final myAnswers = _match.playerAnswers[_currentUserId] ?? [];
    _currentQuestionIndex = myAnswers.length;
    debugPrint(
        '🔄 OnlineDuelScreen: Resuming from question index: $_currentQuestionIndex');
  }

  void _syncScores() {
    if (_currentUserId == null) return;
    if (_match.hostUserId == _currentUserId) {
      _myScore = _match.hostScore;
      _opponentScore = _match.guestScore;
    } else {
      _myScore = _match.guestScore;
      _opponentScore = _match.hostScore;
    }
  }

  void _reconstructAnsweredItems() {
    _answeredItems.clear();
    final myAnswers = _match.playerAnswers[_currentUserId] ?? [];
    for (var answer in myAnswers) {
      if (answer.questionIndex < _match.questions.length) {
        final q = _match.questions[answer.questionIndex];
        _answeredItems.add(AnsweredEntry(
          prompt: q.prompt,
          selectedIndex: answer.selectedOption,
          correctIndex: q.correctIndex,
          earnedPoints: 0,
          mode: q.mode,
          correctText: q.options[q.correctIndex],
          selectedText: (answer.selectedOption >= 0 &&
                  answer.selectedOption < q.options.length)
              ? q.options[answer.selectedOption]
              : null,
          turkishMeaning: q.turkishMeaning,
        ));
      }
    }
  }

  Future<void> _loadInventory() async {
    final inventory = await ShopService.instance.getInventory();
    if (mounted) {
      setState(() => _inventory = inventory);
    }
  }

  void _usePowerup(PowerupType type) async {
    if (_locked || _inventory == null || !_inventory!.hasAny(type)) return;

    // Prevent multiple uses of same powerup type per question
    if (_usedPowerupsInCurrentQuestion.contains(type)) return;

    // Logic checks
    if (type == PowerupType.fiftyFifty && _eliminatedOptions.isNotEmpty) return;
    if (type == PowerupType.doubleChance && _doubleChanceActive) return;

    final success = await ShopService.instance.usePowerup(type);
    if (!success) return;

    setState(() {
      _inventory = _inventory!.use(type);
      _usedPowerupsInCurrentQuestion.add(type);
    });

    switch (type) {
      case PowerupType.fiftyFifty:
        _applyFiftyFifty();
        break;
      case PowerupType.doubleChance:
        setState(() => _doubleChanceActive = true);
        _showPowerupEffect('İkinci Şans Aktif!', '🔄');
        break;
      case PowerupType.freezeTime:
        setState(() => _timeLeft += 5);
        _showPowerupEffect('+5 Saniye!', '❄️');
        break;
      case PowerupType.revealAnswer:
        final correctIndex = _shuffledCorrectIndexes[_currentQuestionIndex];
        _selectOption(correctIndex);
        break;
      case PowerupType.multiplier:
        setState(() => _scoreMultiplier = 2.0);
        _showPowerupEffect('x2 Puan Aktif!', '⚡');
        break;
      default:
        break;
    }
  }

  void _applyFiftyFifty() {
    final correctIndex = _shuffledCorrectIndexes[_currentQuestionIndex];
    final optionsCount = _shuffledOptions[_currentQuestionIndex].length;
    final wrongIndices = List.generate(optionsCount, (i) => i)
      ..remove(correctIndex)
      ..removeWhere(
          (i) => _eliminatedOptions.contains(i)); // Don't re-eliminate

    wrongIndices.shuffle(_rng);

    // Eliminate up to 2 wrong options
    final toEliminate = wrongIndices.take(2).toList();

    setState(() {
      _eliminatedOptions.addAll(toEliminate);
    });

    _showPowerupEffect('%50 Kullanıldı!', '✂️');
  }

  void _showPowerupEffect(String text, String emoji) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 12),
            Text(text, style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        backgroundColor: const Color(0xFF6C27FF),
        duration: const Duration(milliseconds: 1500),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _loadOpponentProfile(String oppId) async {
    debugPrint('👤 OnlineDuelScreen: Fetching opponent profile: $oppId');
    try {
      final profile = await FirestoreService.instance.getUserProfile(oppId);
      if (profile != null && mounted) {
        setState(() {
          _opponentProfile = profile;
          if (profile.photoURL != null && profile.photoURL!.isNotEmpty) {
            _opponentPhotoUrl = profile.photoURL;
            debugPrint(
                '✅ OnlineDuelScreen: Opponent photo found: $_opponentPhotoUrl');
          }
          // Avatar emoji yedek olarak (photoURL yoksa)
          if (profile.avatarId != null) {
            final items = CosmeticItem.availableItems
                .where((i) => i.id == profile.avatarId);
            if (items.isNotEmpty) {
              _opponentAvatar = items.first.previewValue;
              debugPrint(
                  '✅ OnlineDuelScreen: Opponent avatar found: $_opponentAvatar');
            }
          }
        });
      }
    } catch (e) {
      debugPrint('⚠️ OnlineDuelScreen: Error loading opponent profile: $e');
    }
  }

  void _initBotIdentity() {
    final names = [
      'Can',
      'Ayşe',
      'Mehmet',
      'Zeynep',
      'Ali',
      'Fatma',
      'Cem',
      'Elif'
    ];
    _botName = names[_rng.nextInt(names.length)];
  }

  Future<void> _initAvatars() async {
    // Kendi profilini yükle
    final photoUrl = AuthService.instance.photoURL;
    if (photoUrl != null && photoUrl.isNotEmpty && mounted) {
      setState(() => _myPhotoUrl = photoUrl);
    }

    // Kendi profil verisini de çek (ELO vb için)
    final myProfile = await FirestoreService.instance.getCurrentUserProfile();
    if (myProfile != null && mounted) {
      setState(() {
        _myProfile = myProfile;
        if ((_myPhotoUrl == null || _myPhotoUrl!.isEmpty) &&
            myProfile.photoURL != null &&
            myProfile.photoURL!.isNotEmpty) {
          _myPhotoUrl = myProfile.photoURL;
          debugPrint(
              '✅ OnlineDuelScreen: My photo loaded from profile: $_myPhotoUrl');
        }
      });
    }
    final avatarId =
        await ShopService.instance.getSelectedCosmetic(CosmeticType.avatar);
    if (avatarId != null && avatarId.isNotEmpty) {
      final items = CosmeticItem.availableItems.where((i) => i.id == avatarId);
      if (items.isNotEmpty && mounted) {
        setState(() => _myAvatarEmoji = items.first.previewValue);
      }
    }

    final emoteId =
        await ShopService.instance.getSelectedCosmetic(CosmeticType.emote);
    if (emoteId != null && emoteId.isNotEmpty) {
      final emoteItems =
          CosmeticItem.availableItems.where((i) => i.id == emoteId);
      if (emoteItems.isNotEmpty && mounted) {
        setState(() => _mySelectedEmote = emoteItems.first.previewValue);
        debugPrint('🎭 Selected emote loaded: $_mySelectedEmote');
      }
    }

    // Rakip avatarını varsayılan yap
    _opponentAvatar = '👤';

    // Gerçek rakip varsa profilini getir
    if (!_isDemo && _opponentId != null) {
      await _loadOpponentProfile(_opponentId!);
    } else if (_isDemo) {
      const avatars = UserProfileService.avatars;
      setState(() => _opponentAvatar = avatars[_rng.nextInt(avatars.length)]);
    }
  }

  void _shuffleQuestionsAndOptions() {
    // Service already provides shuffled questions and options.
    // We should not shuffle them again here to keep them in sync with the bot and the opponent.
    _shuffledOptions = [];
    _shuffledCorrectIndexes = [];
    _questionModes = [];

    for (final q in _match.questions) {
      _shuffledOptions.add(List<String>.from(q.options));
      _shuffledCorrectIndexes.add(q.correctIndex);
      _questionModes.add(q.mode);
    }
  }

  void _listenToMatch() {
    if (!_isDemo) {
      _matchSubscription =
          OnlineDuelService.instance.matchStream.listen((match) {
        if (match != null && mounted) {
          // Optimization: Only update if anything meaningful changed
          if (_match.status == match.status &&
              _match.hostScore == match.hostScore &&
              _match.guestScore == match.guestScore &&
              _match.playerAnswers.length == match.playerAnswers.length) {
            return;
          }

          setState(() {
            final oldStatus = _match.status;
            _match = match;

            final myUserId = OnlineDuelService.instance.currentUserId;
            if (myUserId != null) {
              _syncScores();

              // SYNC READY STATUS
              if (_isHost &&
                  _showWaitingForGuest &&
                  !_syncingStart &&
                  (match.status == OnlineDuelStatus.ready ||
                      match.status == OnlineDuelStatus.inProgress)) {
                debugPrint('🔔 Opponent joined! Syncing start...');
                _showWaitingForGuest = false;
                _syncingStart = true;

                // Rakip maça katıldığı an profil bilgilerini çek
                if (match.guestUserId != null && _opponentProfile == null) {
                  _loadOpponentProfile(match.guestUserId!);
                }

                // Rakibin bağlantısını kurmasına zaman tanı (2 saniye)
                // Bu sayede host ve guest aynı anda VS ekranına geçer
                Future.delayed(const Duration(milliseconds: 2000), () {
                  if (mounted && _isHost && !_iQuit) {
                    // HOST: Maçı başlat (Durumu inProgress yap)
                    // Bu çağrı Guest tarafında da senkronizasyonu tetikler
                    OnlineDuelService.instance.startGame();
                  }
                });
              }

              // SYNC START (Hangi taraftan gelirse gelsin)
              if (oldStatus != OnlineDuelStatus.inProgress &&
                  match.status == OnlineDuelStatus.inProgress &&
                  !_syncingStart) {
                _syncingStart = true;
                _showWaitingForGuest = false;

                debugPrint('🏁 Match is IN PROGRESS! Starting VS animation.');

                if (mounted) {
                  setState(() {
                    _showVsAnim = true;
                  });
                }
              }

              // SYNC PROGRESSION
              final opponentId = match.hostUserId == myUserId
                  ? match.guestUserId
                  : match.hostUserId;
              if (opponentId != null) {
                final answers = match.playerAnswers[opponentId] ?? [];
                final opponentHasAnswered = answers
                    .any((a) => a.questionIndex == _currentQuestionIndex);

                if (opponentHasAnswered &&
                    _waitingForOpponent &&
                    !_isTransitioning) {
                  debugPrint(
                      '🔔 Opponent answered Q$_currentQuestionIndex! Moving to next.');
                  _waitingFallbackTimer?.cancel();
                  _waitingForOpponent = false;

                  // Küçük bir gecikme ver ki rakibin cevabı/skoru UI'da görünsün
                  Future.delayed(const Duration(milliseconds: 1000), () {
                    if (mounted) _goToNextQuestion();
                  });
                }
              }

              // EMOTE SYNC
              if (match.lastEmote != null) {
                final emoteData = match.lastEmote!;
                final ts = (emoteData['timestamp'] as num?)?.toInt();

                // Eğer timestamp yoksa veya değişmediyse işleme
                if (ts != null && (ts != _lastEmoteTimestamp)) {
                  _lastEmoteTimestamp = ts;
                  final senderId = emoteData['userId']?.toString();
                  final emoji = emoteData['emoji']?.toString();

                  if (emoji != null) {
                    debugPrint(
                        '🎭 DUEL: Syncing Emote: $emoji from $senderId (Me: $myUserId)');
                    _showEmote(emoji, senderId == myUserId);
                  }
                }
              }

              // SYNC TERMINATION
              if (match.status == OnlineDuelStatus.cancelled &&
                  oldStatus != OnlineDuelStatus.cancelled &&
                  !_iQuit &&
                  match.cancelledBy != myUserId) {
                _handleOpponentQuit();
              } else if (match.status == OnlineDuelStatus.finished &&
                  oldStatus != OnlineDuelStatus.finished &&
                  !_isTransitioning &&
                  !_resultsNavigated) {
                debugPrint(
                    '🏁 DUEL: Match finished remotely. Navigating to results.');
                _finishGame();
              }
            }
          });
        }
      });
    }
  }

  void _showEmote(String emoji, bool isMe) {
    if (!mounted) return;
    setState(() {
      if (isMe) {
        _myEmote = emoji;
        _myEmoteTimer?.cancel();
        _myEmoteTimer = Timer(const Duration(seconds: 3), () {
          if (mounted) setState(() => _myEmote = null);
        });
      } else {
        _opponentEmote = emoji;
        _opponentEmoteTimer?.cancel();
        _opponentEmoteTimer = Timer(const Duration(seconds: 3), () {
          if (mounted) setState(() => _opponentEmote = null);
        });
      }
    });

    // Ses efekti? Şimdilik kalsın.
  }

  void _handleOpponentQuit() {
    if (!mounted || _iQuit) return;

    // Eğer maçı biz iptal ettiysek (match nesnesi üzerinden kontrol)
    if (_match.cancelledBy == _currentUserId) return;

    // Zaten bitmiş bir maçsa işlem yapma
    if (_match.status == OnlineDuelStatus.finished) return;

    _questionTimer?.cancel();
    _botTimer?.cancel();

    // Soru 1'de, henüz kimse puan almamışsa maç hiç başlamamış sayılır
    if (_currentQuestionIndex == 0 && _myScore == 0 && _opponentScore == 0) {
      // Dialog yerine doğrudan sonuç ekranına yönlendiriyoruz
      _finishGame(opponentForfeited: true);
      return;
    }

    // RAKİP ÇEKİLDİ -> OTOMATİK KAZAN
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A3A5C),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Rakip Çekildi 🏆',
            style: TextStyle(color: Colors.white)),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('🎉', style: TextStyle(fontSize: 48)),
            SizedBox(height: 16),
            Text(
              'Rakibiniz düellodan ayrıldı. Hükmen galip sayıldınız!',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Dialogu kapat
              // Skorları güncelle ve sonuç ekranına git
              _finishGame(opponentForfeited: true);
            },
            child: const Text('Ödülümü Al',
                style: TextStyle(
                    color: Colors.amber, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _onVsAnimationComplete() {
    if (!mounted) return;
    setState(() {
      _showVsAnim = false;
      _showCountdown = true;
    });
    _startCountdown();
  }

  void _startCountdown() async {
    for (int i = 3; i >= 1; i--) {
      if (!mounted) return;
      setState(() => _countdownValue = i);
      await Future.delayed(const Duration(seconds: 1));
    }
    if (!mounted) return;
    setState(() => _showCountdown = false);
    _startQuestion();
  }

  void _startQuestion() {
    if (!mounted) return;

    setState(() {
      _selectedOption = null;
      _botSelection = null;
      _locked = false;
      _timeLeft = 7;

      // Eğer Host isek ve oyun henüz inProgress değilse, RTDB'deki statüyü güncelle
      if (_isHost &&
          _currentQuestionIndex == 0 &&
          _match.status != OnlineDuelStatus.inProgress &&
          !_isDemo) {
        OnlineDuelService.instance.startGame();
      }

      // Reset Power-ups
      _eliminatedOptions = {};
      _doubleChanceActive = false;
      _scoreMultiplier = 1.0;
      _usedPowerupsInCurrentQuestion = [];
      _waitingForOpponent = false;
      _isTransitioning = false;
    });

    // Transition bittiyse ve biz bekliyorsak rakibin durumuna bak
    _checkOpponentProgress();

    _questionTimer?.cancel();
    _questionTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() => _timeLeft--);

      if (_timeLeft <= 0) {
        timer.cancel();
        if (!_locked) {
          _handleTimeout();
        }
      }
    });

    if (_isDemo) {
      _scheduleBotAnswer();
    }
  }

  /// Rakibin mevcut soruya cevap verip vermediğini kontrol eder ve gerekirse geçişi tetikler
  void _checkOpponentProgress() {
    if (_isDemo || !mounted || _isTransitioning) return;

    final myUserId = OnlineDuelService.instance.currentUserId;
    if (myUserId == null) return;

    final opponentId = _isHost ? _match.guestUserId : _match.hostUserId;
    if (opponentId == null) return;

    final answers = _match.playerAnswers[opponentId] ?? [];
    final hasAnswered =
        answers.any((a) => a.questionIndex == _currentQuestionIndex);

    // Eğer biz kilitliysek (cevap verdiysek) ve rakip bekliyorsak ama rakip aslında çoktan cevap verdiyse
    if (hasAnswered && _locked && _waitingForOpponent) {
      debugPrint(
          '🔔 [CheckProgress] Rakip Q$_currentQuestionIndex için çoktan cevap vermiş. Geçiyoruz...');
      _waitingForOpponent = false;
      _goToNextQuestion();
    }
  }

  void _scheduleBotAnswer() {
    _botTimer?.cancel();
    final delay = Duration(milliseconds: 600 + _rng.nextInt(1900));
    _botTimer = Timer(delay, () {
      if (!mounted || _locked) return;

      final correctIndex = _shuffledCorrectIndexes[_currentQuestionIndex];
      final options = _shuffledOptions[_currentQuestionIndex];

      int choice;
      if (_rng.nextDouble() < 0.7) {
        choice = correctIndex;
      } else {
        final wrongs = List.generate(options.length, (i) => i)
          ..remove(correctIndex);
        choice = wrongs[_rng.nextInt(wrongs.length)];
      }

      setState(() => _botSelection = choice);

      if (_selectedOption != null) {
        Future.delayed(const Duration(milliseconds: 300), _finalizeRound);
      }
    });
  }

  void _handleTimeout() {
    if (_locked) return;

    SoundService.instance.playWrong();
    HapticFeedback.heavyImpact();

    final question = _match.questions[_currentQuestionIndex];
    final correctIndex = _shuffledCorrectIndexes[_currentQuestionIndex];

    _answeredItems.add(AnsweredEntry(
      prompt: question.prompt,
      correctText: _shuffledOptions[_currentQuestionIndex][correctIndex],
      selectedIndex: -1,
      correctIndex: correctIndex,
      mode: _questionModes[_currentQuestionIndex],
      earnedPoints: 0,
      turkishMeaning: question.turkishMeaning,
      usedPowerups: _usedPowerupsInCurrentQuestion,
    ));

    _myStreak = 0;

    if (_botSelection != null && _botSelection == correctIndex) {
      final timeBonus = max(0, 10 - (10 - _timeLeft));
      _opponentStreak++;
      final streakBonus = (_opponentStreak > 1) ? (_opponentStreak - 1) * 2 : 0;
      final points = 10 + timeBonus + streakBonus;
      setState(() => _opponentScore += points);
      _opponentPulseController
          .forward(from: 0)
          .then((_) => _opponentPulseController.reverse());
    } else {
      _opponentStreak = 0;
    }

    setState(() => _locked = true);

    // Timeout olduğunda rakibi bekleme kuralı
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) _goToNextQuestion();
    });
  }

  void _selectOption(int index) {
    if (_locked) return;

    _selectedOption = index;

    // Double Chance Logic
    final correctIndex = _shuffledCorrectIndexes[_currentQuestionIndex];
    if (_doubleChanceActive &&
        index != correctIndex &&
        !_eliminatedOptions.contains(index)) {
      // Wrong answer with Double Chance
      setState(() {
        _doubleChanceActive = false; // Consume chance
        _eliminatedOptions.add(index); // Eliminate the wrong choice
      });
      _showPowerupEffect('İkinci Şans! Tekrar Dene.', '🔄');
      SoundService.instance.playWrong();
      return;
    }

    HapticFeedback.lightImpact();
    setState(() => _selectedOption = index);

    // Sadece demo modunda botu zorla.
    // Gerçek düelloda rakibin cevabı Firestore üzerinden gelecek.
    if (_isDemo) {
      if (_botSelection == null) {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (!mounted) return;
          if (_botSelection == null) {
            _forceBot();
          }
          Future.delayed(const Duration(milliseconds: 300), _finalizeRound);
        });
      } else {
        Future.delayed(const Duration(milliseconds: 1200), _finalizeRound);
      }
    } else {
      // Gerçek düello: Cevabı gönder ve rakip skorunun Firestore'dan gelmesini bekle.
      // Finalize sadece lokal UI için bir gecikme sağlar.
      Future.delayed(const Duration(milliseconds: 1200), _finalizeRound);
    }
  }

  void _forceBot() {
    if (_botSelection != null) return;

    final correctIndex = _shuffledCorrectIndexes[_currentQuestionIndex];
    final options = _shuffledOptions[_currentQuestionIndex];

    int choice;
    if (_rng.nextDouble() < 0.7) {
      choice = correctIndex;
    } else {
      final wrongs = List.generate(options.length, (i) => i)
        ..remove(correctIndex);
      choice = wrongs[_rng.nextInt(wrongs.length)];
    }

    setState(() => _botSelection = choice);
  }

  void _finalizeRound() {
    if (_locked) return;

    _questionTimer?.cancel();
    _botTimer?.cancel();

    final question = _match.questions[_currentQuestionIndex];
    final correctIndex = _shuffledCorrectIndexes[_currentQuestionIndex];
    final isCorrect = _selectedOption == correctIndex;
    final botCorrect = _botSelection == correctIndex;

    int earnedPoints = 0;

    if (isCorrect) {
      final timeBonus = _timeLeft;
      _myStreak++;
      final streakBonus = (_myStreak > 1) ? (_myStreak - 1) * 2 : 0;

      // Toplam puanı multiplier (x2) ile çarp
      earnedPoints =
          ((10 + timeBonus + streakBonus) * _scoreMultiplier).toInt();

      _myScore += earnedPoints;
      SoundService.instance.playCorrect();
      HapticFeedback.mediumImpact();
      _pulseController.forward(from: 0).then((_) => _pulseController.reverse());
    } else {
      _myStreak = 0;
      SoundService.instance.playWrong();
      HapticFeedback.heavyImpact();
    }

    // Rakip skoru güncellemesi: Demo'da bot simülasyonu, gerçekte Firestore dinleyici
    if (_isDemo && botCorrect) {
      final botTimeBonus = max(0, _timeLeft - _rng.nextInt(3));
      _opponentStreak++;
      final botStreakBonus =
          (_opponentStreak > 1) ? (_opponentStreak - 1) * 2 : 0;
      final botPoints = 10 + botTimeBonus + botStreakBonus;
      _opponentScore += botPoints;
      _opponentPulseController
          .forward(from: 0)
          .then((_) => _opponentPulseController.reverse());
    } else if (_isDemo && !botCorrect) {
      _opponentStreak = 0;
    }

    _answeredItems.add(AnsweredEntry(
      prompt: question.prompt,
      correctText: _shuffledOptions[_currentQuestionIndex][correctIndex],
      selectedIndex: _selectedOption ?? -1,
      correctIndex: correctIndex,
      mode: _questionModes[_currentQuestionIndex],
      earnedPoints: earnedPoints,
      turkishMeaning: question.turkishMeaning,
      usedPowerups: _usedPowerupsInCurrentQuestion,
    ));

    setState(() {
      _locked = true;
      _answerIsCorrect = isCorrect;
      if (_selectedOption != null) {
        _showAnswerAnimation = true;
      }
    });

    if (!_isDemo) {
      final timeMs = (7 - _timeLeft) * 1000;
      OnlineDuelService.instance.submitAnswer(
        _currentQuestionIndex,
        _selectedOption ?? -1,
        timeMs,
        points: earnedPoints,
      );

      final opponentId = _isHost ? _match.guestUserId : _match.hostUserId;
      if (opponentId != null) {
        final opponentAnswers = _match.playerAnswers[opponentId] ?? [];
        final opponentHasAnswered = opponentAnswers
            .any((a) => a.questionIndex == _currentQuestionIndex);

        if (!opponentHasAnswered) {
          debugPrint('⏳ Q$_currentQuestionIndex: Rakip bekleniyor...');
          setState(() => _waitingForOpponent = true);

          // FALLBACK TIMER: Rakip 7sn + 3sn tampon süresinde cevap vermezse zorla geç
          _waitingFallbackTimer?.cancel();
          final waitTime = max(2, _timeLeft) + 3;
          _waitingFallbackTimer = Timer(Duration(seconds: waitTime), () {
            if (mounted && _waitingForOpponent) {
              debugPrint(
                  '⏰ Fallback Triggered: Moving to next question regardless.');
              setState(() => _waitingForOpponent = false);
              _goToNextQuestion();
            }
          });
          return;
        }
      }
    }

    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) _goToNextQuestion();
    });
  }

  void _goToNextQuestion() {
    if (!mounted || _isTransitioning) return;

    setState(() => _isTransitioning = true);

    if (_currentQuestionIndex < _match.questions.length - 1) {
      _startInterstitial();
    } else {
      _finishGame();
    }
  }

  void _startInterstitial() async {
    if (!mounted) return;

    final nextIndex = _currentQuestionIndex + 1;

    setState(() {
      _interstitialStep = 1;
      _currentQuestionIndex = nextIndex;
    });

    await Future.delayed(const Duration(milliseconds: 800)); // Hızlandırıldı
    if (!mounted) return;

    setState(() => _interstitialStep = 2);

    await Future.delayed(const Duration(milliseconds: 800)); // Hızlandırıldı
    if (!mounted) return;

    setState(() => _interstitialStep = 0);
    _startQuestion();
  }

  void _finishGame(
      {bool opponentForfeited = false, bool weForfeited = false}) async {
    // Lichess-benzeri bitiş: iki taraf da "finished" demeden sonuç ekranına geçme.
    // Demo maçlarda lokal akış devam eder.
    if (!_isDemo && _match.status != OnlineDuelStatus.finished) {
      await OnlineDuelService.instance.markPlayerFinished();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Rakibin bitirmesi bekleniyor...'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      // Devam et; final sonuç ekranına yönlendirmek için sonraki adımları takip etsin
    }

    _questionTimer?.cancel();
    _botTimer?.cancel();

    // Rakip pes etmişse ve skoru bizden küçük/eşitse, ona ait skoru bastırmak ve galip sayılmak için skorumuza ufak bir ekleme yaparız.
    if (opponentForfeited && _myScore <= _opponentScore) {
      _myScore = _opponentScore + 10;
    } else if (weForfeited && _myScore >= _opponentScore) {
      _opponentScore = _myScore +
          10; // Biz pes ettiysek kesin mağlup sayılmak için rakibe puan ekliyoruz.
    }

    // Gerçek düelloda rakibin son cevaplarını senkronize etmeyi bekle
    if (!_isDemo) {
      debugPrint('🏁 Finishing Game: Waiting for final sync...');

      // RAKİBİN SON CEVABINI BEKLE (Senkronizasyon için kritik - "Farklı sonuç" hatasını çözer)
      int syncAttempts = 0;
      while (syncAttempts < 10 && _opponentId != null) {
        final opponentAnswers = _match.playerAnswers[_opponentId!] ?? [];
        // Eğer rakip tüm soruları bitirdiyse artık beklemeye gerek yok
        if (opponentAnswers.length >= _match.questions.length) {
          debugPrint('✅ Final Sync: Opponent finished all questions.');
          break;
        }

        debugPrint(
            '⏳ Final Sync: Waiting for opponent final response... (Attempt ${syncAttempts + 1})');
        await Future.delayed(const Duration(milliseconds: 500));
        syncAttempts++;
      }

      // Son skorları Firestore bazlı güncelle (Stream'den son hali çekmiş olmalıyız)
      final myUserId = OnlineDuelService.instance.currentUserId;
      if (myUserId != null) {
        setState(() {
          if (_match.hostUserId == myUserId) {
            _myScore = _match.hostScore;
            _opponentScore = _match.guestScore;
          } else {
            _myScore = _match.guestScore;
            _opponentScore = _match.hostScore;
          }
        });
      }

      // Not: status=finished artık RTDB'de iki taraf da bitirdiğinde set ediliyor (markPlayerFinished).
    }

    // Puanlama Sistemi: LP ve Lig Puanı Ayrımı
    int lpChange = 0;
    int leaguePoints = 0;
    int newStreak = 0;
    int currentLp = 1500; // Varsayılan

    try {
      final profile = await UserProfileService.instance.loadProfile();
      currentLp = profile.lpRating;

      // Rakip LP'si
      int opponentLp = _isHost ? _match.guestLp : _match.hostLp;

      int newDuelWins = profile.duelWins;
      int newDuelLosses = profile.duelLosses;

      if (_myScore > _opponentScore) {
        // Galibiyet
        newStreak = profile.duelWinStreak + 1;
        newDuelWins++;
        int streakBonus = 0;
        if (newStreak >= 3) {
          streakBonus = 5; // 3. ve sonraki her galibiyet için +5 Lig Puanı
        }
        leaguePoints = 20 + streakBonus; // Galibiyet lig puanı + seri bonusu

        lpChange = League.calculateLpChange(
          currentLp: currentLp,
          opponentLp: opponentLp,
          result: 1.0,
          gamesPlayed: profile.gamesPlayed,
        );
      } else if (_myScore < _opponentScore) {
        // Mağlubiyet
        newDuelLosses++;
        newStreak = 0; // Seri bozuldu
        leaguePoints = 0; // Puan yok
        lpChange = League.calculateLpChange(
          currentLp: currentLp,
          opponentLp: opponentLp,
          result: 0.0,
          gamesPlayed: profile.gamesPlayed,
        );
      } else {
        // Beraberlik
        newStreak = profile.duelWinStreak; // Seri bozulmaz
        // Beraberlik: Özel Puanlama (Buçuklu puan yok)
        // Büyük LP: +2, Küçük/Eşit LP: +1
        if (currentLp > opponentLp) {
          lpChange = 2;
        } else {
          lpChange = 1;
        }
        leaguePoints = 5; // Beraberlik lig puanı
      }

      // Maç geçmişine ekle (Haftalık aktivite ve grafikler için gerekli)
      await UserProfileService.instance.addMatchHistory(MatchHistoryItem(
        opponentName: _isDemo ? _botName : (_opponentUsername ?? 'Rakip'),
        userScore: _myScore,
        opponentScore: _opponentScore,
        isWin: _myScore > _opponentScore,
        date: DateTime.now(),
        league: League.fromCode(_match.leagueCode),
        eloChange: lpChange,
      ));

      if (lpChange != 0 ||
          leaguePoints != 0 ||
          newDuelWins != profile.duelWins ||
          newDuelLosses != profile.duelLosses) {
        // Yeniden profili yükle ki, önceki 'addMatchHistory' değişikliği ezilmesin
        final profileWithHistory =
            await UserProfileService.instance.loadProfile();

        final newLp = (currentLp + lpChange).clamp(0, 99999).toInt();
        // Lig puanı (totalScore) sadece artar (kümülatif)
        final newTotalScore = profileWithHistory.totalScore + leaguePoints;

        final newProfile = profileWithHistory.copyWith(
          lpRating: newLp,
          totalScore: newTotalScore,
          gamesPlayed: profileWithHistory.gamesPlayed + 1,
          duelWinStreak: newStreak,
          duelWins: newDuelWins,
          duelLosses: newDuelLosses,
        );
        await UserProfileService.instance.saveProfile(newProfile);
        // ÖNEMLİ: Firestore'a senkronize et ki puanlar sunucuda da güncellensin
        await UserProfileService.instance.syncProfileToFirestore();

        // Haftalık sıralama için puan ekle
        if (leaguePoints > 0) {
          RankingService.instance.addScore(profile.username, leaguePoints);
        }

        if (_myScore > _opponentScore) {
          QuestService.instance.updateProgress(QuestType.winDuels, 1);
          AchievementService.instance
              .updateProgress(AchievementCategory.career, 1);
          FeedService.instance
              .logUserActivity(FeedType.duelWin, 'Bir düello kazandın! ⚔️');
        }

        final wordsMatched = _answeredItems.map((e) => e.correctText).toList();
        await WordUsageService.instance.markWordsUsed(wordsMatched);
      }
    } catch (e) {
      debugPrint('Puan güncelleme hatası: $e');
    } finally {
      if (mounted) {
        _navigateToResults();
      }
    }
  }

  // ignore: unused_element - Çıkış butonu için saklanıyor
  void quitGame({bool force = false}) {
    if (force) {
      setState(() => _iQuit = true);
      OnlineDuelService.instance.cancelMatch();
      _finishGame(weForfeited: true);
      return;
    }
    showDialog(
      context: context,
      builder: (context) {
        final languageProvider = context.read<LanguageProvider>();
        return AlertDialog(
          backgroundColor: const Color(0xFF2E5A8C),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            languageProvider.getString('quit_duel_title'),
            style: const TextStyle(color: Colors.white),
          ),
          content: Text(
            languageProvider.getString('quit_duel_confirm'),
            style: const TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(languageProvider.getString('cancel'),
                  style: const TextStyle(color: Colors.white70)),
            ),
            TextButton(
              onPressed: () {
                setState(() => _iQuit = true);
                Navigator.pop(context);
                OnlineDuelService.instance.cancelMatch();
                _finishGame(weForfeited: true);
              },
              child: Text(languageProvider.getString('confirm'),
                  style: const TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

bool _resultsNavigated = false;
  
  void _navigateToResults({bool opponentForfeited = false, bool weForfeited = false}) {
    if (_resultsNavigated || !mounted) {
      debugPrint('⚠️ _navigateToResults: skipped');
      return;
    }
    
    _resultsNavigated = true;
    debugPrint('🎯 _navigateToResults: Starting');
    debugPrint('📊 Scores - me: $_myScore, opp: $_opponentScore, demo: $_isDemo');
    
    final opponentName = _isDemo ? (_botName.isNotEmpty ? _botName : 'Bot') : (_opponentUsername ?? 'Rakip');
    final safeMyAvatar = _myPhotoUrl ?? _myAvatarEmoji ?? '👤';
    final safeOppAvatar = _isDemo ? (_opponentAvatar.isNotEmpty ? _opponentAvatar : '🤖') : (_opponentPhotoUrl ?? '👤');
    final safeTotalQuestions = _match.questions.length > 0 ? _match.questions.length : 10;
    
    debugPrint('🎯 Using global navigatorKey for navigation');
    
    // Use the global navigatorKey to avoid rendering assertion errors
    // from navigating with a local context that may have pending dialog animations.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _resultsNavigated == false) {
        debugPrint('⚠️ Skipped postFrame: not mounted');
        return;
      }
      
      try {
        final nav = navigatorKey.currentState;
        if (nav == null) {
          debugPrint('❌ navigatorKey.currentState is null, using local context');
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (ctx) => OnlineDuelResultsScreen(
                isWinner: _myScore > _opponentScore,
                myScore: _myScore,
                opponentScore: _opponentScore,
                opponentName: opponentName,
                totalQuestions: safeTotalQuestions,
                isDemo: _isDemo,
                answeredItems: _answeredItems,
                myAvatarEmoji: safeMyAvatar,
                opponentAvatarEmoji: safeOppAvatar,
                opponentId: _isDemo ? null : _opponentId,
                leagueCode: _match.leagueCode ?? 'A1',
                isRematch: widget.isRematch,
              ),
            ),
          );
        } else {
          nav.pushReplacement(
            MaterialPageRoute(
              builder: (ctx) => OnlineDuelResultsScreen(
                isWinner: _myScore > _opponentScore,
                myScore: _myScore,
                opponentScore: _opponentScore,
                opponentName: opponentName,
                totalQuestions: safeTotalQuestions,
                isDemo: _isDemo,
                answeredItems: _answeredItems,
                myAvatarEmoji: safeMyAvatar,
                opponentAvatarEmoji: safeOppAvatar,
                opponentId: _isDemo ? null : _opponentId,
                leagueCode: _match.leagueCode ?? 'A1',
                isRematch: widget.isRematch,
              ),
            ),
          );
        }
        
        debugPrint('✅ Navigation completed');
      } catch (e, stack) {
        debugPrint('❌ Nav error: $e');
        debugPrint('Stack: $stack');
        _resultsNavigated = false;
      }
    });
  }

  @override
  void dispose() {
    _questionTimer?.cancel();
    _botTimer?.cancel();
    _waitingTimer?.cancel();
    _waitingFallbackTimer?.cancel();
    _pulseController.dispose();
    _opponentPulseController.dispose();
    _confettiController.dispose();
    _matchSubscription?.cancel();

    if (!_isDemo) {
      OnlineDuelService.instance.setInDuelScreen(false);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        if (!_showVsAnim)
          Scaffold(
            body: GameBackground(
              child: SafeArea(
                child: Column(
                  children: [
                    buildHeader(),
                    const SizedBox(height: 12),
                    if (!_showCountdown && _interstitialStep == 0)
                      Expanded(
                        child: Column(
                          children: [
                            Expanded(child: buildContent()),
                            const SizedBox(height: 8),
                            _buildEmoteSelector(),
                            buildPowerupsBar(),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        GameConfetti(controller: _confettiController),
        if (_showCountdown) buildCountdownOverlay(),
        if (_interstitialStep > 0) buildInterstitialOverlay(),
        if (_showVsAnim)
          VsScreen(
            onAnimationComplete: _onVsAnimationComplete,
            userAvatarUrl: _myPhotoUrl ?? _myAvatarEmoji ?? '👤',
            botAvatarUrl: _opponentPhotoUrl ?? _opponentAvatar,
            userName: AuthService.instance.displayName ?? 'Sen',
            botName: _isDemo ? _botName : (_opponentUsername ?? 'Rakip'),
            userLevel: _getLevelOrder(_myProfile?.level),
            botLevel: _getLevelOrder(_opponentProfile?.level),
            userTier: _myProfile?.level ?? 'A1',
            botTier: _opponentProfile?.level ?? 'A1',
            userFrameId: _myProfile?.frameId,
            botFrameId: _opponentProfile?.frameId,
            wordOfTheDay: widget.wordOfTheDay ?? _match.wordOfTheDay,
            userLp: _isHost ? _match.hostLp : _match.guestLp,
            botLp: _isDemo
                ? ((_isHost ? _match.hostLp : _match.guestLp) +
                    _rng.nextInt(100) -
                    50)
                : (_isHost ? _match.guestLp : _match.hostLp),
            userWinRate: _calcWinRateCloud(_myProfile),
            botWinRate: _isDemo
                ? (50 + _rng.nextInt(20))
                : _calcWinRateCloud(_opponentProfile),
            arenaName:
                'Arena ${_match.leagueCode}: ${League.fromCode(_match.leagueCode).name}',
          ),
        if (_showWaitingForGuest) buildWaitingForGuestOverlay(),
      ],
    );
  }

  int _getLevelOrder(String? levelCode) {
    if (levelCode == null) return 1;
    final lvl = UserLevel.fromCode(levelCode);
    return lvl.order * 10 + 5; // Simulating a level number from the A1-C2 order
  }

  int _calcWinRateCloud(CloudUserProfile? profile) {
    if (profile == null) return 50;
    final total = profile.duelWins + profile.duelLosses;
    if (total == 0) return 50;
    return ((profile.duelWins / total) * 100).round();
  }

  int _waitingCountdown = 30;
  Timer? _waitingTimer;

  void _startWaitingTimer() {
    _waitingTimer?.cancel();
    _waitingCountdown = 30;
    _waitingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || !_showWaitingForGuest) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_waitingCountdown > 0) {
          _waitingCountdown--;
        } else {
          timer.cancel();
          _handleWaitingTimeout();
        }
      });
    });
  }

  void _handleWaitingTimeout() {
    if (!mounted) return;

    // Arkadaş düellosu daveti zaman aşımına uğradı
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A3A5C),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Zaman Aşımı', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Arkadaşınız daveti 30 saniye içinde kabul etmedi. Lütfen daha sonra tekrar deneyin.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Dialogu kapat
              quitGame(force: true); // Doğrudan lobiye dön
            },
            child: const Text('Tamam',
                style: TextStyle(
                    color: Colors.amber, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget buildWaitingForGuestOverlay() {
    return Material(
      color: Colors.black.withValues(alpha: 0.9),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Circular Progress with Countdown
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 80,
                  height: 80,
                  child: CircularProgressIndicator(
                    value: _waitingCountdown / 30,
                    color: Colors.orange,
                    backgroundColor: Colors.white10,
                    strokeWidth: 6,
                  ),
                ),
                Text(
                  '$_waitingCountdown',
                  style: const TextStyle(
                    color: Colors.orange,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            const Text(
              'Rakip Bekleniyor...',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              '${_opponentUsername ?? "Arkadaşın"} daveti kabul ettiğinde\ndüello otomatik olarak başlayacak.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 16),
            ),
            const SizedBox(height: 48),
            ElevatedButton(
              onPressed: quitGame,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent.withValues(alpha: 0.2),
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.redAccent),
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('İptal Et'),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildContent() {
    if (_currentQuestionIndex >= _match.questions.length) {
      return const Center(child: CircularProgressIndicator());
    }

    final question = _match.questions[_currentQuestionIndex];
    final options = _shuffledOptions[_currentQuestionIndex];
    final correctIndex = _shuffledCorrectIndexes[_currentQuestionIndex];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          GameProgressBar(
            currentIndex: _currentQuestionIndex,
            totalQuestions: _match.questions.length,
          ),
          const SizedBox(height: 20),
          QuestionCard(prompt: question.prompt),
          const SizedBox(height: 20),
          Expanded(
            child: OptionsGrid(
              options: options,
              selectedIndex: _selectedOption,
              correctIndex: correctIndex,
              isLocked: _locked,
              showCorrect: _locked,
              onOptionSelected: _selectOption,
              eliminatedOptions: _eliminatedOptions,
            ),
          ),
          const SizedBox(height: 10),
          const SizedBox(height: 30),
          // Yanıt animasyonu yeri (Şıkların alt kısmında)
          SizedBox(
            width: 140,
            height: 140,
            child: _showAnswerAnimation
                ? LottieAnswerOverlay(
                    isCorrect: _answerIsCorrect,
                    onComplete: () {
                      if (mounted) setState(() => _showAnswerAnimation = false);
                    },
                  )
                : const SizedBox.shrink(),
          ),
          const SizedBox(height: 30),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget buildPowerupsBar() {
    if (_locked || _inventory == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.2),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          buildPowerupButton(PowerupType.fiftyFifty),
          buildPowerupButton(PowerupType.doubleChance),
          buildPowerupButton(PowerupType.multiplier),
          buildPowerupButton(PowerupType.freezeTime),
          buildPowerupButton(PowerupType.revealAnswer),
        ],
      ),
    );
  }

  Widget buildPowerupButton(PowerupType type) {
    final count = _inventory!.getCount(type);
    final isActive =
        count > 0 && !_usedPowerupsInCurrentQuestion.contains(type);

    Color bgColor = Colors.white.withValues(alpha: 0.1);
    if (type == PowerupType.doubleChance && _doubleChanceActive) {
      bgColor = Colors.yellow.withValues(alpha: 0.3); // Highlight active
    }

    return GestureDetector(
      onTap: isActive ? () => _usePowerup(type) : null,
      child: Opacity(
        opacity: isActive ? 1.0 : 0.4,
        child: Column(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isActive ? Colors.white54 : Colors.transparent,
                  width: 1.5,
                ),
                boxShadow: isActive
                    ? [
                        BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 4,
                            offset: const Offset(0, 2))
                      ]
                    : [],
              ),
              alignment: Alignment.center,
              child: Text(
                type.emoji,
                style: const TextStyle(fontSize: 24),
              ),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$count',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildCountdownOverlay() {
    final mode =
        _questionModes.isNotEmpty ? _questionModes[0] : QuestionMode.enToTr;

    return Material(
      color: Colors.transparent,
      child: Container(
        color: Colors.black.withValues(alpha: 0.85),
        alignment: Alignment.center,
        child: TweenAnimationBuilder<double>(
          key: ValueKey(_countdownValue),
          duration: const Duration(milliseconds: 600),
          tween: Tween(begin: 0.3, end: 1.0),
          curve: Curves.elasticOut,
          builder: (context, value, child) {
            return Transform.scale(
              scale: value.clamp(0.3, 1.0),
              child: Opacity(
                opacity: value.clamp(0.0, 1.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [Color(0xFF6C27FF), Color(0xFF2AA7FF)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color:
                                const Color(0xFF6C27FF).withValues(alpha: 0.5),
                            blurRadius: 40,
                            spreadRadius: 10,
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          '$_countdownValue',
                          style: const TextStyle(
                            fontSize: 64,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
                    buildScrabbleMode(mode),
                    const SizedBox(height: 24),
                    Text(
                      context.watch<LanguageProvider>().getString('get_ready'),
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget buildInterstitialOverlay() {
    final nextMode = _questionModes[_currentQuestionIndex];

    return Material(
      color: Colors.transparent,
      child: Container(
        color: Colors.black.withValues(alpha: 0.85),
        alignment: Alignment.center,
        child: TweenAnimationBuilder<double>(
          duration: const Duration(milliseconds: 600),
          tween: Tween(begin: 0.3, end: 1.0),
          curve: Curves.elasticOut,
          builder: (context, value, child) {
            return Transform.scale(
              scale: value.clamp(0.3, 1.0),
              child: Opacity(
                opacity: value.clamp(0.0, 1.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [Color(0xFF6C27FF), Color(0xFF2AA7FF)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color:
                                const Color(0xFF6C27FF).withValues(alpha: 0.5),
                            blurRadius: 40,
                            spreadRadius: 10,
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          '${_currentQuestionIndex + 1}',
                          style: const TextStyle(
                            fontSize: 64,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
                    buildScrabbleMode(nextMode),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget buildScrabbleMode(QuestionMode mode) {
    String leftText, rightText;
    Color leftColor, rightColor;

    switch (mode) {
      case QuestionMode.trToEn:
        leftText = 'TR';
        rightText = 'ENG';
        leftColor = const Color(0xFFE53935);
        rightColor = const Color(0xFF1E88E5);
        break;
      case QuestionMode.enToTr:
        leftText = 'ENG';
        rightText = 'TR';
        leftColor = const Color(0xFF1E88E5);
        rightColor = const Color(0xFFE53935);
        break;
      case QuestionMode.engToEng:
        leftText = 'ENG';
        rightText = 'ENG';
        leftColor = const Color(0xFF9C27B0);
        rightColor = const Color(0xFFE91E63);
        break;
    }

    return Center(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ...leftText
                .split('')
                .map((char) => buildScrabbleTile(char, leftColor)),
            const SizedBox(width: 20),
            const Icon(Icons.arrow_forward_rounded,
                color: Colors.white, size: 44),
            const SizedBox(width: 20),
            ...rightText
                .split('')
                .map((char) => buildScrabbleTile(char, rightColor)),
          ],
        ),
      ),
    );
  }

  Widget buildScrabbleTile(String char, Color color) {
    return Container(
      width: 50,
      height: 60,
      margin: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Text(
          char,
          style: TextStyle(
              fontSize: 32, fontWeight: FontWeight.w900, color: color),
        ),
      ),
    );
  }

  Widget buildHeader() {
    final mode = _questionModes.isNotEmpty
        ? _questionModes[_currentQuestionIndex]
        : QuestionMode.enToTr;

    String modeText = 'EN - TR';
    if (mode == QuestionMode.trToEn) modeText = 'TR - EN';
    if (mode == QuestionMode.engToEng) modeText = 'ENG - ENG';

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6C27FF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    modeText,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontSize: 13),
                  ),
                ),

                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${context.watch<LanguageProvider>().getString('question')} ${_currentQuestionIndex + 1} / ${_match.questions.length}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      color: Colors.black,
                      fontSize: 14,
                    ),
                  ),
                ),

                GameTimer(timeLeft: _timeLeft),

                // Çekilme Butonu
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white70),
                  onPressed: quitGame,
                  tooltip: context
                      .read<LanguageProvider>()
                      .getString('quit_duel_title'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ScaleTransition(
                scale: _pulseAnim,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    _compactPlayerCircle(
                      name: _myProfile?.username ??
                          context.watch<LanguageProvider>().getString('you'),
                      score: _myScore,
                      avatarUrl: _myPhotoUrl,
                      avatarEmoji: _myAvatarEmoji,
                      color: const Color(0xFF2AA7FF),
                    ),
                    if (_myEmote != null)
                      Positioned(
                        top: -10,
                        right: -10,
                        child: _buildFloatingEmote(_myEmote!),
                      ),
                    if (_mySelectedEmote != null)
                      Positioned(
                        bottom: -8,
                        right: -8,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF6C27FF),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.amber, width: 1.5),
                          ),
                          child: Text(
                            _mySelectedEmote!,
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              Image.asset(
                'assets/images/vs_emblem.png',
                width: 60,
                height: 60,
                fit: BoxFit.contain,
              ),
              const SizedBox(width: 20),
              ScaleTransition(
                scale: _opponentPulseAnim,
                child: GestureDetector(
                  onTap: _isDemo ? null : _showOpponentProfile,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      _compactPlayerCircle(
                        name: _opponentUsername ??
                            context
                                .watch<LanguageProvider>()
                                .getString('opponent_name'),
                        score: _opponentScore,
                        avatarUrl: _opponentPhotoUrl,
                        avatarEmoji: _opponentAvatar,
                        color: Colors.redAccent,
                      ),
                      if (_opponentEmote != null)
                        Positioned(
                          top: -10,
                          left: -10,
                          child: _buildFloatingEmote(_opponentEmote!),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        if (_waitingForOpponent)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white70),
                ),
                const SizedBox(width: 8),
                Text(
                  context
                      .watch<LanguageProvider>()
                      .getString('waiting_for_opponent_answer'),
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7), fontSize: 12),
                ),
              ],
            ),
          ),
      ],
    );
  }

  void _showOpponentProfile() async {
    if (_opponentId == null) return;

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final profile =
          await FirestoreService.instance.getUserProfile(_opponentId!);
      final h2h =
          await OnlineDuelService.instance.getHeadToHeadScore(_opponentId!);

      if (!mounted) return;
      Navigator.pop(context); // Close loading

      if (profile == null) return;

      showDialog(
        context: context,
        builder: (context) => Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF1A3A5C),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white24),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Avatar
                CircleAvatar(
                  radius: 40,
                  backgroundColor: Colors.white10,
                  child: Builder(
                    builder: (context) {
                      final avatarId = profile.avatarId;
                      if (avatarId == null || avatarId.isEmpty) {
                        return const Text('👤', style: TextStyle(fontSize: 40));
                      }

                      final items = CosmeticItem.availableItems
                          .where((i) => i.id == avatarId);
                      if (items.isEmpty)
                        return const Text('👤', style: TextStyle(fontSize: 40));

                      final previewValue = items.first.previewValue;
                      if (previewValue.startsWith('assets/')) {
                        return Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Image.asset(previewValue, fit: BoxFit.contain),
                        );
                      }
                      return Text(previewValue,
                          style: const TextStyle(fontSize: 40));
                    },
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  profile.username,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold),
                ),
                Text(
                  '${context.read<LanguageProvider>().getString('level')} ${profile.level}',
                  style: const TextStyle(color: Colors.white70, fontSize: 16),
                ),
                const Divider(color: Colors.white12, height: 32),

                // H2H Score
                Text(context.read<LanguageProvider>().getString('mutual_score'),
                    style: const TextStyle(
                        color: Colors.amber,
                        fontWeight: FontWeight.bold,
                        fontSize: 12)),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Column(
                      children: [
                        Text('${h2h['me']}',
                            style: const TextStyle(
                                color: Colors.blue,
                                fontSize: 32,
                                fontWeight: FontWeight.w900)),
                        Text(context.read<LanguageProvider>().getString('you'),
                            style: const TextStyle(
                                color: Colors.white54, fontSize: 10)),
                      ],
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 24),
                      child: Text('-',
                          style:
                              TextStyle(color: Colors.white60, fontSize: 24)),
                    ),
                    Column(
                      children: [
                        Text('${h2h['opponent']}',
                            style: const TextStyle(
                                color: Colors.red,
                                fontSize: 32,
                                fontWeight: FontWeight.w900)),
                        Text(
                            context
                                .read<LanguageProvider>()
                                .getString('opponent_name'),
                            style: const TextStyle(
                                color: Colors.white54, fontSize: 10)),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 24),
                const Divider(color: Colors.white12, height: 16),

                // Other stats
                Text(
                    context
                        .read<LanguageProvider>()
                        .getString('opponent_stats_title'),
                    style: const TextStyle(
                        color: Colors.amber,
                        fontWeight: FontWeight.bold,
                        fontSize: 12)),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildMiniStat(
                        context
                            .read<LanguageProvider>()
                            .getString('league_score'),
                        '${profile.leagueScores[_match.leagueCode] ?? 1500}'),
                    _buildMiniStat(
                        context.read<LanguageProvider>().getString('matches'),
                        '${profile.gamesPlayed}'),
                    _buildMiniStat(
                        context.read<LanguageProvider>().getString('win_rate'),
                        '%${_calcWinRateCloud(profile)}'),
                  ],
                ),

                const SizedBox(height: 24),

                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white12,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child:
                      Text(context.read<LanguageProvider>().getString('close')),
                ),
              ],
            ),
          ),
        ),
      );
    } catch (e) {
      if (mounted) Navigator.pop(context);
      debugPrint('Error showing profile: $e');
    }
  }

  Widget _buildMiniStat(String label, String value) {
    return Column(
      children: [
        Text(label,
            style: const TextStyle(
                color: Colors.white54,
                fontSize: 10,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800)),
      ],
    );
  }

  Widget _buildEmoteSelector() {
    final emotes = ['🔥', '😎', '😲', '👋', '💀', '🍀'];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: emotes
            .map((e) => GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    OnlineDuelService.instance.sendEmote(e);
                    // Kendi emojimizi hemen (lokal olarak) göster
                    _showEmote(e, true);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: Colors.white10,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Text(e, style: const TextStyle(fontSize: 20)),
                  ),
                ))
            .toList(),
      ),
    );
  }

  Widget _buildFloatingEmote(String emoji) {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 500),
      tween: Tween(begin: 0.0, end: 1.0),
      curve: Curves.elasticOut,
      builder: (context, val, child) {
        return Transform.scale(
          scale: val,
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF1E3A5F),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.amber, width: 2),
              boxShadow: [
                BoxShadow(
                    color: Colors.amber.withValues(alpha: 0.5), blurRadius: 10),
              ],
            ),
            child: Text(
              emoji,
              style: const TextStyle(fontSize: 32),
            ),
          ),
        );
      },
    );
  }

  Widget _onlineDuelCompactAvatarInner({
    required double size,
    String? avatarUrl,
    String? avatarEmoji,
  }) {
    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      if (avatarUrl.startsWith('http')) {
        return Image.network(
          avatarUrl,
          width: size,
          height: size,
          fit: BoxFit.cover,
          alignment: Alignment.center,
          errorBuilder: (_, __, ___) =>
              _onlineDuelCompactAvatarFallback(size, avatarEmoji),
        );
      }
      if (avatarUrl.startsWith('assets/')) {
        return Image.asset(
          avatarUrl,
          width: size,
          height: size,
          fit: BoxFit.cover,
          alignment: Alignment.center,
        );
      }
      return Center(
        child: Text(
          avatarUrl,
          style: TextStyle(fontSize: (size * 0.48).clamp(20.0, 32.0)),
        ),
      );
    }
    return _onlineDuelCompactAvatarFallback(size, avatarEmoji);
  }

  Widget _onlineDuelCompactAvatarFallback(double size, String? avatarEmoji) {
    if (avatarEmoji != null && avatarEmoji.startsWith('assets/')) {
      return Image.asset(
        avatarEmoji,
        width: size,
        height: size,
        fit: BoxFit.cover,
        alignment: Alignment.center,
      );
    }
    return Center(
      child: Text(
        avatarEmoji ?? '👤',
        style: TextStyle(fontSize: (size * 0.48).clamp(20.0, 32.0)),
      ),
    );
  }

  Widget _compactPlayerCircle({
    required String name,
    required int score,
    String? avatarUrl,
    String? avatarEmoji,
    required Color color,
  }) {
    const double size = 58;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: color, width: 2),
                boxShadow: [
                  BoxShadow(
                      color: color.withAlpha(51),
                      blurRadius: 10,
                      spreadRadius: 1),
                ],
              ),
              child: ClipOval(
                child: SizedBox(
                  width: size,
                  height: size,
                  child: _onlineDuelCompactAvatarInner(
                    size: size,
                    avatarUrl: avatarUrl,
                    avatarEmoji: avatarEmoji,
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: -2,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withAlpha(128), blurRadius: 4),
                  ],
                ),
                child: Text(
                  '$score',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w900),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          name,
          style: TextStyle(
              color: Colors.white.withAlpha(204),
              fontSize: 12,
              fontWeight: FontWeight.bold),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
