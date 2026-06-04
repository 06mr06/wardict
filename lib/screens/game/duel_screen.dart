import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/game_provider.dart';
import '../../models/league.dart';
import '../../models/powerup.dart';
import '../../models/question_mode.dart'; // Fixed import
import '../../services/user_profile_service.dart';
import '../../services/quest_service.dart';
import '../../services/achievement_service.dart';
import '../../services/network_service.dart';
import '../../services/feed_service.dart';
import '../../models/quest.dart';
import '../../models/achievement.dart';
import '../../models/user_level.dart';
import '../../models/feed_item.dart';
import '../../services/shop_service.dart';
import '../../services/ranking_service.dart';
import '../../models/cosmetic_item.dart';
import '../../services/firebase/auth_service.dart';
import 'base_game_screen.dart';
import 'duel_results_screen.dart';
import 'vs_screen.dart';
import '../../widgets/game/question_card.dart';
import '../../widgets/game/options_grid.dart';
import '../../widgets/game/game_progress_bar.dart'; // Fixed import casing
import '../../widgets/game/game_timer.dart';
import '../../widgets/game/game_confetti.dart';
import 'package:confetti/confetti.dart';
import '../../widgets/game/game_background.dart';
import '../../models/match_history_item.dart'; // Added import
import '../../widgets/game/lottie_answer_overlay.dart';
import '../../widgets/common/connection_lost_dialog.dart';

class DuelScreen extends BaseGameScreen {
  final Map<String, String>? wordOfTheDay;
  final String? botName;
  final String? botAvatar;

  const DuelScreen({
    super.key,
    this.wordOfTheDay,
    this.botName,
    this.botAvatar,
  });

  @override
  State<DuelScreen> createState() => _DuelScreenState();
}

class _DuelScreenState extends BaseGameScreenState<DuelScreen> with NetworkAwareMixin {
  final _rng = Random();
  int? _userSelection;
  int? _botSelection;
  bool _locked = false;
  League? _currentLeague;

  @override
  String? get backgroundImage => 'assets/images/welcome.png';
  
  @override
  double get imageOpacity => 0.15;
  
  // VS Animation State
  bool _showVsAnim = true;

  // Bot logic
  int botScore = 0;
  int botStreak = 0;
  late String _botName;
  late String _botAvatar;
  
  // Powerup state
  PowerupInventory _inventory = const PowerupInventory();
  bool _fiftyFiftyUsed = false;
  bool _doubleChanceUsed = false;
  bool _firstChanceWrong = false;
  bool _freezeTimeUsed = false;
  double _scoreMultiplier = 1.0;
  Set<int> _eliminatedOptions = {};
  String? _selectedAvatarEmoji;
  String? _myPhotoUrl;
  UserProfile? _userProfile;

  bool _showAnswerAnimation = false;
  bool _answerIsCorrect = false;

  // Animations
  late AnimationController _userPulseController;
  late AnimationController _botPulseController;
  late Animation<double> _userPulseAnim;
  late Animation<double> _botPulseAnim;
  late ConfettiController _confettiController;
  
  // Network monitoring
  StreamSubscription<bool>? _networkSubscription;

  @override
  void initState() {
    super.initState(); // Base inits
    _confettiController = ConfettiController(duration: const Duration(seconds: 3));
    _initBotIdentity();
    _initDuel();
    _initPulseAnimations();
    _startNetworkMonitoring();
  }

  void _startNetworkMonitoring() {
    NetworkService.instance.startMonitoring();
    _networkSubscription = NetworkService.instance.connectionStream.listen((isConnected) {
      if (!isConnected && mounted) {
        // Bot düellosu olduğu için oyunu duraklatmıyoruz, sadece debug log basıyoruz.
        debugPrint('📡 DuelScreen: Connection lost, but continuing bot duel offline.');
      }
    });
  }

  void _initBotIdentity() {
    if (widget.botName != null && widget.botAvatar != null) {
      _botName = widget.botName!;
      _botAvatar = widget.botAvatar!;
    } else {
      final names = ['Bot Can', 'Bot Ayşe', 'Bot Mehmet', 'Bot Zeynep', 'Bot Ali', 'Bot Fatma', 'Bot Cem', 'Bot Elif'];
      _botName = names[_rng.nextInt(names.length)];
      _botAvatar = UserProfileService.avatars[_rng.nextInt(UserProfileService.avatars.length)];
    }
  }
  
  void _initPulseAnimations() {
    _userPulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _botPulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _userPulseAnim = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _userPulseController, curve: Curves.easeOut),
    );
    _botPulseAnim = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _botPulseController, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _networkSubscription?.cancel();
    NetworkService.instance.stopMonitoring();
    _userPulseController.dispose();
    _botPulseController.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is League) {
      _currentLeague = args;
    }
  }

  Future<void> _initDuel() async {
    final profile = await UserProfileService.instance.loadProfile();
    // Get user's photo URL from Firebase Auth (Google profile picture)
    final photoUrl = AuthService.instance.photoURL;
    if (photoUrl != null && photoUrl.isNotEmpty && mounted) {
      setState(() => _myPhotoUrl = photoUrl);
    }
    
    final inventory = await ShopService.instance.getInventory();
    final avatarId = await ShopService.instance.getSelectedCosmetic(CosmeticType.avatar);
    String? emoji;
    if (avatarId != null && avatarId.isNotEmpty) {
      final items = CosmeticItem.availableItems.where((i) => i.id == avatarId);
      if (items.isNotEmpty) {
        emoji = items.first.previewValue;
      }
    }

    if (mounted) {
      setState(() {
        _userProfile = profile;
        _inventory = inventory;
        _selectedAvatarEmoji = emoji;
      });
    }
  }

  void _onVsAnimationComplete() {
    if (!mounted) return;
    setState(() => _showVsAnim = false);
    // Now start the BaseGameScreen 3-2-1 countdown
    startPreGame();
  }

  @override
  void onGameStart() {
    // Round Started
    _resetRoundState();
    _startBot();
  }

  @override
  Widget buildPreScreen(BuildContext context) {
    final gp = context.read<GameProvider>();
    // First question mode
    final firstMode = gp.questions.isNotEmpty ? gp.questions[0].mode : QuestionMode.trToEn;

    return Scaffold(
      body: GameBackground(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              buildCountdown(), // 3-2-1
              const SizedBox(height: 48),
              _buildScrabbleMode(firstMode),
              const SizedBox(height: 24),
              const Text(
                'Hazır Ol!',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  // Interstitial State
  // ignore: unused_field - Interstitial overlay için saklanıyor  
  final bool _showNextQuestionOverlay = false;
  List<PowerupType> _roundPowerups = [];

  @override
  Widget build(BuildContext context) {
    // Override build to stack VS Animation and Interstitial
    final gp = context.watch<GameProvider>();
    return Stack(
      children: [
        if (!_showVsAnim) super.build(context), // Only show game after VS
        GameConfetti(controller: _confettiController),
        
        if (_showAnswerAnimation)
          LottieAnswerOverlay(
            isCorrect: _answerIsCorrect,
            onComplete: () {
              if (mounted) setState(() => _showAnswerAnimation = false);
            },
          ),
          
        // Interstitial Overlay (Between Questions)
        if (_interstitialStep > 0)
          Material(
            color: Colors.transparent,
            child: Container(
              color: Colors.black.withAlpha(217),
              alignment: Alignment.center,
              child: TweenAnimationBuilder<double>(
                duration: const Duration(milliseconds: 600),
                tween: Tween(begin: 0.3, end: 1.0),
                curve: Curves.elasticOut,
                builder: (context, value, child) {
                  final nextIndex = (gp.index + 1).clamp(0, gp.totalQuestions - 1);
                  final nextMode = gp.questions[nextIndex].mode;
                  
                  return Transform.scale(
                    scale: value.clamp(0.3, 1.0),
                    child: Opacity(
                      opacity: value.clamp(0.0, 1.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Question Number Bubble (Countdown style)
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
                                  color: const Color(0xFF6C27FF).withAlpha(128),
                                  blurRadius: 40,
                                  spreadRadius: 10,
                                ),
                              ],
                            ),
                            child: Center(
                              child: Text(
                                '${nextIndex + 1}',
                                style: const TextStyle(
                                  fontSize: 64, // Synced with countdown
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  shadows: [Shadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 4))],
                                ),
                              ),
                            ),
                          ),
                          
                          const SizedBox(height: 40),
                          
                          // Mode Indicator (Scrabble style)
                          _buildScrabbleMode(nextMode),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

        if (_showVsAnim)
          VsScreen(
            onAnimationComplete: _onVsAnimationComplete,
            userAvatarUrl: _myPhotoUrl ?? _selectedAvatarEmoji ?? '👤',
            botAvatarUrl: _botAvatar,
            userScore: gp.score,
            botScore: botScore,
            userName: AuthService.instance.displayName ?? 'You',
            botName: _botName,
            userLevel: _userProfile?.level.order ?? 1,
            botLevel: (_userProfile?.level.order ?? 1) + _rng.nextInt(3) - 1,
            userTier: _userProfile?.level.code ?? 'A1',
            botTier: _userProfile?.level.code ?? 'A1',
            userLp: _userProfile?.leagueScores.getScore(_currentLeague ?? League.beginner) ?? 1500,
            botLp: (_userProfile?.leagueScores.getScore(_currentLeague ?? League.beginner) ?? 1500) + _rng.nextInt(200) - 100,
            userWinRate: _calcWinRate(_userProfile),
            botWinRate: 50 + _rng.nextInt(20),
            arenaName: _currentLeague != null ? 'Arena ${_currentLeague!.code}: ${_currentLeague!.name}' : 'Arena 01: Training Ground',
            wordOfTheDay: widget.wordOfTheDay,
          ),
      ],
    );
  }

  int _calcWinRate(UserProfile? profile) {
    if (profile == null) return 50;
    final total = profile.duelWins + profile.duelLosses;
    if (total == 0) return 50;
    return ((profile.duelWins / total) * 100).round();
  }

  void _resetRoundState() {
    setState(() {
      _userSelection = null;
      _botSelection = null;
      _locked = false;
      _eliminatedOptions = {};
      _roundPowerups = [];
       _fiftyFiftyUsed = false;
       _doubleChanceUsed = false;
       _firstChanceWrong = false;
       _freezeTimeUsed = false;
       _scoreMultiplier = 1.0;
    });
  }

  // ... (keeping other methods same until _onUserTap)

  void _submitAnswer(int index) {
     if (_locked || _userSelection != null || timeLeft == 0) return;

    // Double Chance Logic
    if (_doubleChanceUsed && !_firstChanceWrong) {
         final gp = context.read<GameProvider>();
         if (index != gp.currentCorrectIndex) {
             setState(() {
                 _firstChanceWrong = true;
                 _eliminatedOptions.add(index);
             });
             return; 
         }
    }

    setState(() => _userSelection = index);
    
    // Force bot reaction if missing
    if (_botSelection == null) {
      Future.delayed(const Duration(milliseconds: 200), () {
        if (!mounted || _botSelection != null) return;
        _startBot();
      });
    }
    
    Future.delayed(const Duration(milliseconds: 300), _finalizeRound);
  }

  void _onUserTap(int index) {
     _submitAnswer(index);
  }

  void _finalizeRound() {
    if (_locked) return;
    timer?.cancel();
    
    final gp = context.read<GameProvider>();
    // Pass used powerups
    gp.answer(_userSelection ?? -1, timeLeft, usedPowerups: List.from(_roundPowerups)); 
    
    final correctIndex = gp.currentCorrectIndex;
    final botCorrect = _botSelection == correctIndex;

    int botPoints = 0;
    if (botCorrect) {
      botStreak++;
      botPoints = (10 * (1 + botStreak * 0.1)).round(); 
    } else {
      botStreak = 0;
    }
    botScore += botPoints;

    setState(() {
      _locked = true;
      _answerIsCorrect = _userSelection != null && _userSelection == correctIndex;
      _showAnswerAnimation = true;
      if (gp.lastScore > 0) _userPulseController.forward(from: 0).then((_) => _userPulseController.reverse());
      if (botPoints > 0) _botPulseController.forward(from: 0).then((_) => _botPulseController.reverse());
    });

    // Instead of _nextQuestion directly, show interstitial if not game over
    if (gp.index + 1 < gp.totalQuestions) {
        Future.delayed(const Duration(seconds: 2), _startInterstitial);
    } else {
        Future.delayed(const Duration(seconds: 2), _nextQuestion); // Will trigger finish
    }
  }

  // Interstitial State
  int _interstitialStep = 0; // 0: None, 1: Count, 2: Mode

  void _startInterstitial() async {
      if (!mounted) return;
      setState(() => _interstitialStep = 1); // Show Count
      
      await Future.delayed(const Duration(milliseconds: 1500));
      if (!mounted) return;
      
      setState(() => _interstitialStep = 2); // Show Mode
      
      await Future.delayed(const Duration(milliseconds: 1500));
      if (!mounted) return;
      
      setState(() => _interstitialStep = 0); // Hide
      _nextQuestion();
  }

  @override
  void onTimeUp() {
    if (_locked) return;
    _finalizeRound();
  }

  void _startBot() {
    final gp = context.read<GameProvider>();
    final optionsLen = gp.currentOptions.length;
    final correctIndex = gp.currentCorrectIndex;
    
    final reactMs = _rng.nextInt(1900) + 600; // 600-2500ms arası
    const correctProb = 0.7; // %70 oranında doğru bilir

    Future.delayed(Duration(milliseconds: reactMs), () {
      if (!mounted || _locked) return;
      int choice;
      if (_rng.nextDouble() < correctProb) {
        choice = correctIndex;
      } else {
        final wrongs = List.generate(optionsLen, (i) => i)..remove(correctIndex);
        choice = wrongs[_rng.nextInt(wrongs.length)];
      }
      setState(() => _botSelection = choice);
      
      // If user also answered or time up, validation happens separately
      // Check if both answered to quick finish?
      if (_userSelection != null) {
         Future.delayed(const Duration(milliseconds: 300), _finalizeRound);
      }
    });
  }

  void _nextQuestion() {
    if (!mounted) return;
    final gp = context.read<GameProvider>();
    
    if (gp.isFinished) { // 'index' is checked in goNext usually, here we check before
        _showResult();
        return;
    }
    
    // Check if next is actually EOF
    if (gp.index + 1 >= gp.totalQuestions) {
       _showResult();
       return;
    }

    gp.goNext();
    
    _resetRoundState(); // Reset local state
    startTimer(); // Base timer restart
    _startBot(); // Start bot for new round
  }

  void _showResult() async {
    final gp = context.read<GameProvider>();
    int lpChange = 0;
    int userLpBeforeMatch = 1500;
    const int botLp = 1500;

    final int finalUserScore = gp.score;
    final int finalBotScore = botScore;

    if (_currentLeague != null) {
        final isWin = finalUserScore > finalBotScore;
        final isDraw = finalUserScore == finalBotScore;
        final profile = await UserProfileService.instance.loadProfile();
        userLpBeforeMatch = profile.leagueScores.getScore(_currentLeague!);
        
        final gamesPlayed = profile.gamesPlayed;
        
        final double result = isDraw ? 0.5 : (isWin ? 1.0 : 0.0);
        lpChange = League.calculateLpChange(
          currentLp: userLpBeforeMatch, 
          opponentLp: botLp, 
          result: result,
          gamesPlayed: gamesPlayed,
        );
        await UserProfileService.instance.updateLeagueScore(_currentLeague!, lpChange);
        
        await UserProfileService.instance.addMatchHistory(MatchHistoryItem(
            opponentName: _botName,
            userScore: finalUserScore,
            opponentScore: finalBotScore,
            isWin: isWin,
            date: DateTime.now(),
            league: _currentLeague,
            eloChange: lpChange,
        ));
        
        if (isWin) {
           QuestService.instance.updateProgress(QuestType.winDuels, 1);
           AchievementService.instance.updateProgress(AchievementCategory.career, 1);
           FeedService.instance.logUserActivity(FeedType.duelWin, 'Bir düello kazandın! ⚔️');
           
           final profile = await UserProfileService.instance.loadProfile();
           await RankingService.instance.addScore(profile.username, lpChange);
           
           await Future.delayed(const Duration(seconds: 2)); 
        }
    } else {
        await UserProfileService.instance.addMatchHistory(MatchHistoryItem(
            opponentName: _botName,
            userScore: finalUserScore,
            opponentScore: finalBotScore,
            isWin: finalUserScore > finalBotScore,
            date: DateTime.now(),
            league: null,
            eloChange: 0,
        ));
    }

    if (!mounted) return;
    Navigator.pushReplacement(context, MaterialPageRoute(
        builder: (_) => DuelResultsScreen(
            userScore: finalUserScore,
            botScore: finalBotScore,
            items: gp.history,
            league: _currentLeague,
            lpChange: lpChange,
            userLp: userLpBeforeMatch,
            botLp: botLp,
            botName: _botName,
            botAvatar: _botAvatar,
        )
    ));
  }


  @override
  Widget buildHeader(BuildContext context) {
    final gp = context.watch<GameProvider>();
    
    // Mode Text
    String modeText = 'TR - EN';
    if (gp.currentMode == QuestionMode.enToTr) modeText = 'EN - TR';
    if (gp.currentMode == QuestionMode.engToEng) modeText = 'ENG - ENG';

    return Column(
      children: [
        // Top Row: Level/Mode -- Counter -- Timer
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black.withAlpha(77),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
               // Mode Indicator
               Container(
                 padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                 decoration: BoxDecoration(
                   color: const Color(0xFF6C27FF),
                   borderRadius: BorderRadius.circular(12),
                 ),
                 child: Text(
                   modeText,
                   style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13),
                 ),
               ),
               
               // Question Counter (High Contrast)
               Container(
                 padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                 decoration: BoxDecoration(
                   color: Colors.white,
                   borderRadius: BorderRadius.circular(12),
                 ),
                 child: Text(
                   'Soru ${(gp.index + 1).clamp(1, 10)} / 10',
                   style: const TextStyle(
                     fontWeight: FontWeight.w900,
                     color: Colors.black, // Stark contrast
                     fontSize: 14,
                   ),
                 ),
               ),

               // Timer
               GameTimer(timeLeft: timeLeft),
            ],
          ),
        ),
        const SizedBox(height: 12),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ScaleTransition(
                        scale: _userPulseAnim,
                        child: _compactPlayerCircle(
                          name: 'Sen',
                          score: gp.score,
                          avatarUrl: _myPhotoUrl,
                          avatarEmoji: _selectedAvatarEmoji,
                          color: const Color(0xFF2AA7FF),
                          isUser: true,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Image.asset(
                        'assets/images/vs_emblem.png',
                        width: 50,
                        height: 50,
                        fit: BoxFit.contain,
                      ),
                      const SizedBox(width: 16),
                      ScaleTransition(
                        scale: _botPulseAnim,
                        child: _compactPlayerCircle(
                          name: _botName,
                          score: botScore,
                          avatarEmoji: '🤖',
                          color: const Color(0xFFFF9800),
                          isUser: false,
                        ),
                      ),
                    ],
                  ),
        )
      ],
    );
  }

  Widget _duelCompactAvatarFallback(double size, String? avatarEmoji) {
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
        style: TextStyle(fontSize: (size * 0.44).clamp(18.0, 28.0)),
      ),
    );
  }

  Widget _compactPlayerCircle({
    required String name,
    required int score,
    String? avatarUrl,
    String? avatarEmoji,
    required Color color,
    required bool isUser,
  }) {
    const double size = 54;
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
                  BoxShadow(color: color.withAlpha(51), blurRadius: 10, spreadRadius: 1),
                ],
              ),
              child: ClipOval(
                child: SizedBox(
                  width: size,
                  height: size,
                  child: avatarUrl != null && avatarUrl.isNotEmpty
                      ? Image.network(
                          avatarUrl,
                          width: size,
                          height: size,
                          fit: BoxFit.cover,
                          alignment: Alignment.center,
                          errorBuilder: (_, __, ___) =>
                              _duelCompactAvatarFallback(size, avatarEmoji),
                        )
                      : _duelCompactAvatarFallback(size, avatarEmoji),
                ),
              ),
            ),
            Positioned(
              bottom: -2,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withAlpha(128), blurRadius: 4),
                  ],
                ),
                child: Text(
                  '$score',
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          name,
          style: TextStyle(color: Colors.white.withAlpha(204), fontSize: 11, fontWeight: FontWeight.bold),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  @override
  Widget buildContent(BuildContext context) {
     final gp = context.watch<GameProvider>();
     
     return Expanded(
        child: Column(
            children: [
                GameProgressBar(currentIndex: gp.index, totalQuestions: gp.totalQuestions),
                const SizedBox(height: 20),
                QuestionCard(prompt: gp.currentPrompt),
                const SizedBox(height: 20),
                Expanded(
                    child: OptionsGrid(
                        options: gp.currentOptions,
                        selectedIndex: _userSelection, // Show user selection
                        correctIndex: gp.currentCorrectIndex,
                        isLocked: _locked, // Show correct/wrong colors only when locked
                        showCorrect: _locked, 
                        onOptionSelected: _onUserTap,
                        eliminatedOptions: _eliminatedOptions, // Pass this
                    )
                ),
                // Powerup Button (Bottom Right or similar)
                Align(
                    alignment: Alignment.centerRight,
                    child: Padding(
                        padding: const EdgeInsets.only(bottom: 10, right: 10),
                        child: _buildPowerupButton()
                    )
                )
            ],
        ),
     );
  }

  // ignore: unused_element - Mod etiketi için saklanıyor
  String _modeLabel(QuestionMode mode) {
    switch (mode) {
      case QuestionMode.trToEn:
        return 'TR → EN';
      case QuestionMode.enToTr:
        return 'EN → TR';
      case QuestionMode.engToEng:
        return 'ENG - ENG';
    }
  }

  // ignore: unused_element - Mod badge widget'ı için saklanıyor
  Widget _modeBadgeWidget(QuestionMode mode) {
    switch (mode) {
      case QuestionMode.trToEn:
        return const Text('🇹🇷➡️🇬🇧', style: TextStyle(fontSize: 18));
      case QuestionMode.enToTr:
        return const Text('🇬🇧➡️🇹🇷', style: TextStyle(fontSize: 18));
      case QuestionMode.engToEng:
        return const Text('🇬🇧＝🇬🇧', style: TextStyle(fontSize: 18));
    }
  }

  // Powerup Functions
  void _showPowerupMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF2E5A8C), Color(0xFF1A3A5C)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              '⚡ Powerups',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            // Powerup grid
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: PowerupType.values.map((type) {
                final count = _inventory.getCount(type);
                final isAvailable = count > 0 && !_isPowerupUsedThisRound(type);
                
                return GestureDetector(
                  onTap: isAvailable ? () {
                    Navigator.pop(context);
                    _usePowerup(type);
                  } : null,
                  child: Container(
                    width: 100,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isAvailable 
                          ? const Color(0xFF6C27FF).withValues(alpha: 0.3)
                          : Colors.grey.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isAvailable 
                            ? const Color(0xFF6C27FF)
                            : Colors.grey.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(type.emoji, style: const TextStyle(fontSize: 28)),
                        const SizedBox(height: 6),
                        Text(
                          type.name,
                          style: TextStyle(
                            color: isAvailable ? Colors.white : Colors.grey,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: count > 0 ? Colors.green : Colors.red,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            'x$count',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  bool _isPowerupUsedThisRound(PowerupType type) {
    switch (type) {
      case PowerupType.fiftyFifty:
        return _fiftyFiftyUsed;
      case PowerupType.doubleChance:
        return _doubleChanceUsed;
      case PowerupType.freezeTime:
        return _freezeTimeUsed;
      case PowerupType.multiplier:
        return _scoreMultiplier > 1.0;
      case PowerupType.revealAnswer:
        return false; // Can use anytime
      case PowerupType.streakShield:
        return true; // Not usable in game, only passive
    }
  }

  Future<void> _usePowerup(PowerupType type) async {
    if (_locked || showPreScreen) return; // Fixed _showPre to showPreScreen
    
    final success = await ShopService.instance.usePowerup(type);
    if (!success) return;
    
    await _loadInventory();
    
    setState(() => _roundPowerups.add(type));
    
    switch (type) {
      case PowerupType.revealAnswer:
        _useRevealAnswer();
        break;
      case PowerupType.fiftyFifty:
        _useFiftyFifty();
        break;
      case PowerupType.doubleChance:
        _useDoubleChance();
        break;
      case PowerupType.freezeTime:
        _useFreezeTime();
        break;
      case PowerupType.multiplier:
        _useMultiplier();
        break;
      case PowerupType.streakShield:
        // Passive powerup - not used in game directly
        break;
    }
  }

  Future<void> _loadInventory() async {
     final inv = await ShopService.instance.getInventory();
     if(mounted) setState(() => _inventory = inv);
  }

  void _useRevealAnswer() {
    final gp = context.read<GameProvider>();
    final correctIndex = gp.currentCorrectIndex;
    // Otomatik olarak doğru cevabı seç
    _submitAnswer(correctIndex);
  }

  void _useFiftyFifty() {
    final gp = context.read<GameProvider>();
    final correctIndex = gp.currentCorrectIndex;
    final optionsLen = gp.currentOptions.length;
    
    // 2 yanlış şıkkı eleme
    final wrongs = List.generate(optionsLen, (i) => i)
      ..remove(correctIndex)
      ..shuffle();
    
    setState(() {
      _fiftyFiftyUsed = true;
      _eliminatedOptions = wrongs.take(2).toSet();
    });
  }

  void _useDoubleChance() {
    setState(() {
      _doubleChanceUsed = true;
      _firstChanceWrong = false;
    });
  }

  void _useFreezeTime() {
    timer?.cancel(); // Mevcut timer'ı durdur
    setState(() {
      _freezeTimeUsed = true;
    });
    // 5 saniye bekle sonra timer'ı yeniden başlat
    Future.delayed(const Duration(seconds: 5), () {
      if (!mounted || _locked) return;
      if (timeLeft == 0) { // Check if time already ran out
           _finalizeRound();
      } else {
         startTimer(); // Restart base timer
      }
    });
  }


  void _useMultiplier() {
    setState(() {
      _scoreMultiplier = 2.0;
    });
  }

  Widget _buildPowerupButton() {
    final totalPowerups = _inventory.items.values.fold(0, (a, b) => a + b);
    
    return GestureDetector(
      onTap: _showPowerupMenu,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF6C27FF), Color(0xFF9D4EDD)],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF6C27FF).withValues(alpha: 0.3),
              blurRadius: 8,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('⚡', style: TextStyle(fontSize: 18)),
            const SizedBox(width: 6),
            Text(
              '$totalPowerups',
              style: const TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  
  Widget _buildScrabbleMode(QuestionMode mode) {
    String leftText, rightText;
    Color leftColor, rightColor;
    
    switch (mode) {
      case QuestionMode.trToEn:
        leftText = 'TR';
        rightText = 'ENG';
        leftColor = const Color(0xFFE53935); // Red
        rightColor = const Color(0xFF1E88E5); // Blue
        break;
      case QuestionMode.enToTr:
        leftText = 'ENG';
        rightText = 'TR';
        leftColor = const Color(0xFF1E88E5); // Blue
        rightColor = const Color(0xFFE53935); // Red
        break;
      case QuestionMode.engToEng:
        leftText = 'ENG';
        rightText = 'ENG';
        leftColor = const Color(0xFF1E88E5); // Blue
        rightColor = const Color(0xFF1E88E5); // Blue
        break;
    }
    
    return Center(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ...leftText.split('').map((char) => _buildScrabbleTile(char, leftColor)),
            const SizedBox(width: 20),
            const Icon(
              Icons.arrow_forward_rounded,
              color: Colors.white,
              size: 44,
            ),
            const SizedBox(width: 20),
            ...rightText.split('').map((char) => _buildScrabbleTile(char, rightColor)),
          ],
        ),
      ),
    );
  }

  Widget _buildScrabbleTile(String char, Color color) {
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
            fontSize: 32,
            fontWeight: FontWeight.w900,
            color: color,
          ),
        ),
      ),
    );
  }
  
  // ignore: unused_element - Numara emojisi için saklanıyor
  String _getNumberEmoji(int number) {
    const emojis = ['0️⃣', '1️⃣', '2️⃣', '3️⃣', '4️⃣', '5️⃣', '6️⃣', '7️⃣', '8️⃣', '9️⃣', '🔟'];
    if (number >= 1 && number <= 10) {
      return emojis[number];
    }
    return '❓';
  }
  
  // ignore: unused_element - Mod flag text için saklanıyor
  String _getModeFlagText(QuestionMode mode) {
    switch (mode) {
      case QuestionMode.trToEn:
        return '🇹🇷 → 🇬🇧';
      case QuestionMode.enToTr:
        return '🇬🇧 → 🇹🇷';
      case QuestionMode.engToEng:
        return '🇬🇧 ＝ 🇬🇧';
    }
  }
  
  // ignore: unused_element - Mod emojisi için saklanıyor
  String _getModeEmoji(QuestionMode mode) {
    switch (mode) {
      case QuestionMode.trToEn:
        return '🇹🇷➡️🇬🇧';
      case QuestionMode.enToTr:
        return '🇬🇧➡️🇹🇷';
      case QuestionMode.engToEng:
        return '🇬🇧＝🇬🇧';
    }
  }
}
