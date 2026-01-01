import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/game_provider.dart';
import '../../models/league.dart';
import '../../models/powerup.dart';
import '../../models/question_mode.dart'; // Fixed import
import '../../services/user_profile_service.dart';
import '../../services/word_pool_service.dart';
import '../../services/quest_service.dart';
import '../../services/achievement_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/feed_service.dart';
import '../../models/quest.dart';
import '../../models/achievement.dart';
import '../../models/feed_item.dart';
import '../../services/shop_service.dart';
import '../../models/cosmetic_item.dart';
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

class DuelScreen extends BaseGameScreen {
  const DuelScreen({super.key});

  @override
  State<DuelScreen> createState() => _DuelScreenState();
}

class _DuelScreenState extends BaseGameScreenState<DuelScreen> {
  final _rng = Random();
  int? _userSelection;
  int? _botSelection;
  bool _locked = false;
  League? _currentLeague;
  
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

  // Animations
  late AnimationController _userPulseController;
  late AnimationController _botPulseController;
  late Animation<double> _userPulseAnim;
  late Animation<double> _botPulseAnim;
  late ConfettiController _confettiController;

  @override
  void initState() {
    super.initState(); // Base inits
    _confettiController = ConfettiController(duration: const Duration(seconds: 3));
    _initBotIdentity();
    _initDuel();
    _initPulseAnimations();
  }

  void _initBotIdentity() {
    final names = ['Can', 'Ayşe', 'Mehmet', 'Zeynep', 'Ali', 'Fatma', 'Cem', 'Elif'];
    _botName = names[_rng.nextInt(names.length)];
    _botAvatar = UserProfileService.avatars[_rng.nextInt(UserProfileService.avatars.length)];
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
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is League) {
      _currentLeague = args;
    }
  }

  Future<void> _initDuel() async {
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
  bool _showNextQuestionOverlay = false;
  List<PowerupType> _roundPowerups = [];

  @override
  Widget build(BuildContext context) {
    // Override build to stack VS Animation and Interstitial
    final gp = context.watch<GameProvider>();
    return Stack(
      children: [
        if (!_showVsAnim) super.build(context), // Only show game after VS
        GameConfetti(controller: _confettiController),
        
        // Interstitial Overlay (Between Questions)
        if (_interstitialStep > 0)
          Material(
            color: Colors.transparent,
            child: Container(
              color: Colors.black.withOpacity(0.85),
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
                                  color: const Color(0xFF6C27FF).withOpacity(0.5),
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
            userAvatarUrl: _selectedAvatarEmoji ?? '👤', // Using emoji if URL is not supported yet
            botAvatarUrl: _botAvatar,
          ),
      ],
    );
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
    
    // Bot reaction time ~600-2500ms
    final reactMs = _rng.nextInt(1900) + 600; 
    const correctProb = 0.7; 

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
    int eloChange = 0;
    
    // Save Match History
    final historyItem = MatchHistoryItem(
      opponentName: 'Bot', // Could use random name
      userScore: gp.score,
      opponentScore: botScore,
      isWin: gp.score > botScore,
      date: DateTime.now(),
      league: _currentLeague,
      eloChange: 0, // Placeholder until calc
    );

    if (_currentLeague != null) {
        final isWin = gp.score > botScore;
        final isDraw = gp.score == botScore;
        final profile = await UserProfileService.instance.loadProfile();
        final currentElo = profile.leagueScores.getScore(_currentLeague!);
        const botElo = 1500;
        
        if (!isDraw) {
            eloChange = League.calculateEloChange(currentElo: currentElo, opponentElo: botElo, won: isWin);
            await UserProfileService.instance.updateLeagueScore(_currentLeague!, eloChange);
        }
        
        // Update history item with calculated elo change
        await UserProfileService.instance.addMatchHistory(MatchHistoryItem(
            opponentName: _botName,
            userScore: gp.score,
            opponentScore: botScore,
            isWin: isWin,
            date: DateTime.now(),
            league: _currentLeague,
            eloChange: eloChange,
        ));
        
        if (isWin) {
           // _confettiController.play();
           QuestService.instance.updateProgress(QuestType.winDuels, 1);
           AchievementService.instance.updateProgress(AchievementCategory.career, 1);
           FeedService.instance.logUserActivity(FeedType.duelWin, 'Bir düello kazandın! ⚔️');
           await Future.delayed(const Duration(seconds: 2)); 
        }
    } else {
        // Save practice duel history too? Yes.
        await UserProfileService.instance.addMatchHistory(MatchHistoryItem(
            opponentName: _botName,
            userScore: gp.score,
            opponentScore: botScore,
            isWin: gp.score > botScore,
            date: DateTime.now(),
            league: null,
            eloChange: 0,
        ));
    }

    if (!mounted) return;
    Navigator.pushReplacement(context, MaterialPageRoute(
        builder: (_) => DuelResultsScreen(
            userScore: gp.score,
            botScore: botScore,
            items: gp.history,
            league: _currentLeague,
            eloChange: eloChange
        )
    ));
  }


  @override
  Widget buildHeader(BuildContext context) {
    final gp = context.watch<GameProvider>();
    
    // Mode Text
    String modeText = 'TR - EN';
    if (gp.currentMode == QuestionMode.enToTr) modeText = 'EN - TR';
    if (gp.currentMode == QuestionMode.engToEng) modeText = 'Eş Anlam';

    return Column(
      children: [
        // Top Row: Level/Mode -- Counter -- Timer
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.3),
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
            children: [
                  ScaleTransition(
                      scale: _userPulseAnim,
                      child: _scoreTile('${_selectedAvatarEmoji ?? "👤"} You', gp.score, gp.streak, const Color(0xFF2AA7FF))
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16), 
                    child: Text(
                      'VS', 
                      style: TextStyle(
                        fontSize: 24, 
                        fontWeight: FontWeight.w900, 
                        color: Colors.white,
                        shadows: [Shadow(color: Colors.purple, blurRadius: 10)]
                      )
                    )
                  ),
                  ScaleTransition(
                      scale: _botPulseAnim,
                      child: _scoreTile('$_botAvatar $_botName', botScore, botStreak, const Color(0xFFE91E63))
                  ),
            ],
          ),
        )
      ],
    );
  }
  
  Widget _scoreTile(String label, int score, int streak, Color color) {
    return Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.5))
        ),
        child: Column(
            children: [
                Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                Text('$score', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                if (streak > 1) Text('🔥 $streak', style: const TextStyle(color: Colors.orangeAccent, fontSize: 12)),
            ],
        ),
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

  String _modeLabel(QuestionMode mode) {
    switch (mode) {
      case QuestionMode.trToEn:
        return 'TR → EN';
      case QuestionMode.enToTr:
        return 'EN → TR';
      case QuestionMode.engToEng:
        return 'Eş Anlam';
    }
  }

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
                color: Colors.white.withOpacity(0.3),
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
                          ? const Color(0xFF6C27FF).withOpacity(0.3)
                          : Colors.grey.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isAvailable 
                            ? const Color(0xFF6C27FF)
                            : Colors.grey.withOpacity(0.3),
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
              color: const Color(0xFF6C27FF).withOpacity(0.3),
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
            color: Colors.black.withOpacity(0.3),
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
  
  String _getNumberEmoji(int number) {
    const emojis = ['0️⃣', '1️⃣', '2️⃣', '3️⃣', '4️⃣', '5️⃣', '6️⃣', '7️⃣', '8️⃣', '9️⃣', '🔟'];
    if (number >= 1 && number <= 10) {
      return emojis[number];
    }
    return '❓';
  }
  
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
