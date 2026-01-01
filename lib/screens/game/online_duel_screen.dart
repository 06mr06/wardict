import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:confetti/confetti.dart';
import '../../services/online_duel_service.dart';
import '../../services/sound_service.dart';
import '../../services/user_profile_service.dart';
import '../../services/shop_service.dart';
import '../../models/cosmetic_item.dart';
import '../../models/question_mode.dart';
import '../../models/answered_entry.dart';
import '../../widgets/game/game_background.dart';
import '../../widgets/game/game_timer.dart';
import '../../widgets/game/game_confetti.dart';
import '../../widgets/game/question_card.dart';
import '../../widgets/game/options_grid.dart';
import '../../widgets/game/game_progress_bar.dart';
import 'vs_screen.dart';
import 'online_duel_results_screen.dart';

class OnlineDuelScreen extends StatefulWidget {
  final OnlineDuelMatch match;

  const OnlineDuelScreen({super.key, required this.match});

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
  int _timeLeft = 10;
  
  bool _showVsAnim = true;
  int _interstitialStep = 0;
  bool _showCountdown = false;
  int _countdownValue = 3;
  
  late AnimationController _pulseController;
  late AnimationController _opponentPulseController;
  late Animation<double> _pulseAnim;
  late Animation<double> _opponentPulseAnim;
  late ConfettiController _confettiController;
  
  StreamSubscription? _matchSubscription;
  
  Timer? _botTimer;
  bool _isDemo = false;
  final _rng = Random();
  
  final List<AnsweredEntry> _answeredItems = [];
  
  List<List<String>> _shuffledOptions = [];
  List<int> _shuffledCorrectIndexes = [];
  
  String? _myAvatarEmoji;
  String _opponentAvatar = '👤';
  late String _botName;
  
  List<QuestionMode> _questionModes = [];

  @override
  void initState() {
    super.initState();
    _match = widget.match;
    _isDemo = _match.matchId.startsWith('demo_');
    
    _confettiController = ConfettiController(duration: const Duration(seconds: 3));
    
    _pulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _opponentPulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeOut),
    );
    _opponentPulseAnim = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _opponentPulseController, curve: Curves.easeOut),
    );
    
    _initBotIdentity();
    _initAvatars();
    _shuffleQuestionsAndOptions();
    _listenToMatch();
  }

  void _initBotIdentity() {
    final names = ['Can', 'Ayşe', 'Mehmet', 'Zeynep', 'Ali', 'Fatma', 'Cem', 'Elif'];
    _botName = names[_rng.nextInt(names.length)];
  }

  Future<void> _initAvatars() async {
    final avatarId = await ShopService.instance.getSelectedCosmetic(CosmeticType.avatar);
    if (avatarId != null && avatarId.isNotEmpty) {
      final items = CosmeticItem.availableItems.where((i) => i.id == avatarId);
      if (items.isNotEmpty && mounted) {
        setState(() => _myAvatarEmoji = items.first.previewValue);
      }
    }
    
    final avatars = UserProfileService.avatars;
    if (mounted) {
      setState(() => _opponentAvatar = avatars[_rng.nextInt(avatars.length)]);
    }
  }

  void _shuffleQuestionsAndOptions() {
    final questions = List<OnlineDuelQuestion>.from(_match.questions);
    questions.shuffle(_rng);
    
    _shuffledOptions = [];
    _shuffledCorrectIndexes = [];
    _questionModes = [];
    
    for (final q in questions) {
      final options = List<String>.from(q.options);
      final correctAnswer = options[q.correctIndex];
      options.shuffle(_rng);
      final newCorrectIndex = options.indexOf(correctAnswer);
      
      _shuffledOptions.add(options);
      _shuffledCorrectIndexes.add(newCorrectIndex);
      // Sorunun kendi modunu kullan (rastgele değil)
      _questionModes.add(q.mode);
    }
    
    _match = _match.copyWith(questions: questions);
  }

  void _listenToMatch() {
    if (!_isDemo) {
      _matchSubscription = OnlineDuelService.instance.matchStream.listen((match) {
        if (match != null && mounted) {
          setState(() {});
        }
      });
    }
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
    setState(() {
      _selectedOption = null;
      _botSelection = null;
      _locked = false;
      _timeLeft = 10;
    });
    
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
        final wrongs = List.generate(options.length, (i) => i)..remove(correctIndex);
        choice = wrongs[_rng.nextInt(wrongs.length)];
      }
      
      setState(() => _botSelection = choice);
      
      if (_selectedOption != null) {
        Future.delayed(const Duration(milliseconds: 300), _finalizeRound);
      }
    });
  }

  void _handleTimeout() {
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
      usedPowerups: [],
    ));
    
    _myStreak = 0;
    
    if (_botSelection != null && _botSelection == correctIndex) {
      final timeBonus = max(0, 10 - (10 - _timeLeft));
      _opponentStreak++;
      final streakBonus = (_opponentStreak > 1) ? (_opponentStreak - 1) * 2 : 0;
      final points = 10 + timeBonus + streakBonus;
      setState(() => _opponentScore += points);
      _opponentPulseController.forward(from: 0).then((_) => _opponentPulseController.reverse());
    } else {
      _opponentStreak = 0;
    }
    
    setState(() => _locked = true);
    
    Future.delayed(const Duration(seconds: 2), () {
      _goToNextQuestion();
    });
  }

  void _selectOption(int index) {
    if (_locked || _selectedOption != null) return;
    
    setState(() => _selectedOption = index);
    
    if (_botSelection == null) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (!mounted) return;
        if (_botSelection == null) {
          _forceBot();
        }
        Future.delayed(const Duration(milliseconds: 300), _finalizeRound);
      });
    } else {
      Future.delayed(const Duration(milliseconds: 300), _finalizeRound);
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
      final wrongs = List.generate(options.length, (i) => i)..remove(correctIndex);
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
      earnedPoints = 10 + timeBonus + streakBonus;
      
      _myScore += earnedPoints;
      SoundService.instance.playCorrect();
      HapticFeedback.mediumImpact();
      _pulseController.forward(from: 0).then((_) => _pulseController.reverse());
    } else {
      _myStreak = 0;
      SoundService.instance.playWrong();
      HapticFeedback.heavyImpact();
    }
    
    if (botCorrect) {
      final botTimeBonus = max(0, _timeLeft - _rng.nextInt(3));
      _opponentStreak++;
      final botStreakBonus = (_opponentStreak > 1) ? (_opponentStreak - 1) * 2 : 0;
      final botPoints = 10 + botTimeBonus + botStreakBonus;
      _opponentScore += botPoints;
      _opponentPulseController.forward(from: 0).then((_) => _opponentPulseController.reverse());
    } else {
      _opponentStreak = 0;
    }
    
    _answeredItems.add(AnsweredEntry(
      prompt: question.prompt,
      correctText: _shuffledOptions[_currentQuestionIndex][correctIndex],
      selectedIndex: _selectedOption ?? -1,
      correctIndex: correctIndex,
      mode: _questionModes[_currentQuestionIndex],
      earnedPoints: earnedPoints,
      usedPowerups: [],
    ));
    
    setState(() => _locked = true);
    
    if (!_isDemo) {
      final timeMs = (10 - _timeLeft) * 1000;
      OnlineDuelService.instance.submitAnswer(_currentQuestionIndex, _selectedOption ?? -1, timeMs);
    }
    
    Future.delayed(const Duration(seconds: 2), () {
      _goToNextQuestion();
    });
  }

  void _goToNextQuestion() {
    if (!mounted) return;
    
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
    
    await Future.delayed(const Duration(milliseconds: 1500));
    if (!mounted) return;
    
    setState(() => _interstitialStep = 2);
    
    await Future.delayed(const Duration(milliseconds: 1500));
    if (!mounted) return;
    
    setState(() => _interstitialStep = 0);
    _startQuestion();
  }

  void _finishGame() {
    _questionTimer?.cancel();
    _botTimer?.cancel();
    
    if (!_isDemo) {
      OnlineDuelService.instance.finishGame();
    }
    
    if (_myScore > _opponentScore) {
      _confettiController.play();
    }
    
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => OnlineDuelResultsScreen(
          isWinner: _myScore >= _opponentScore,
          myScore: _myScore,
          opponentScore: _opponentScore,
          opponentName: _isDemo ? _botName : (_match.opponentUsername ?? 'Rakip'),
          totalQuestions: _match.questions.length,
          isDemo: _isDemo,
          answeredItems: _answeredItems,
        ),
      ),
    );
  }

  void _quitGame() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2E5A8C),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Düellodan Çık', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Düellodan çıkmak istediğinize emin misiniz? Bu maç kaybedilmiş sayılacak.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal', style: TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              OnlineDuelService.instance.cancelMatch();
              Navigator.of(context).pop();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Çık'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _questionTimer?.cancel();
    _botTimer?.cancel();
    _pulseController.dispose();
    _opponentPulseController.dispose();
    _confettiController.dispose();
    _matchSubscription?.cancel();
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
                    _buildHeader(),
                    const SizedBox(height: 12),
                    if (!_showCountdown && _interstitialStep == 0)
                      Expanded(child: _buildContent()),
                  ],
                ),
              ),
            ),
          ),
        
        GameConfetti(controller: _confettiController),
        
        if (_showCountdown)
          _buildCountdownOverlay(),
        
        if (_interstitialStep > 0)
          _buildInterstitialOverlay(),
        
        if (_showVsAnim)
          VsScreen(
            onAnimationComplete: _onVsAnimationComplete,
            userAvatarUrl: _myAvatarEmoji ?? '👤',
            botAvatarUrl: _opponentAvatar,
          ),
      ],
    );
  }

  Widget _buildCountdownOverlay() {
    final mode = _questionModes.isNotEmpty ? _questionModes[0] : QuestionMode.enToTr;
    
    return Material(
      color: Colors.transparent,
      child: Container(
        color: Colors.black.withOpacity(0.85),
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
                            color: const Color(0xFF6C27FF).withOpacity(0.5),
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
                    _buildScrabbleMode(mode),
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
            );
          },
        ),
      ),
    );
  }

  Widget _buildInterstitialOverlay() {
    final nextMode = _questionModes[_currentQuestionIndex];
    
    return Material(
      color: Colors.transparent,
      child: Container(
        color: Colors.black.withOpacity(0.85),
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
                            color: const Color(0xFF6C27FF).withOpacity(0.5),
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
                    _buildScrabbleMode(nextMode),
                  ],
                ),
              ),
            );
          },
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
        leftColor = const Color(0xFF1E88E5);
        rightColor = const Color(0xFF1E88E5);
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
            const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 44),
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
          style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: color),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final mode = _questionModes.isNotEmpty ? _questionModes[_currentQuestionIndex] : QuestionMode.enToTr;
    
    String modeText = 'EN - TR';
    if (mode == QuestionMode.trToEn) modeText = 'TR - EN';
    if (mode == QuestionMode.engToEng) modeText = 'Eş Anlam';
    
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.3),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
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
                
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Soru ${_currentQuestionIndex + 1} / ${_match.questions.length}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      color: Colors.black,
                      fontSize: 14,
                    ),
                  ),
                ),
                
                GameTimer(timeLeft: _timeLeft),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            children: [
              ScaleTransition(
                scale: _pulseAnim,
                child: _buildScoreTile(
                  '${_myAvatarEmoji ?? "👤"} Sen',
                  _myScore,
                  _myStreak,
                  const Color(0xFF2AA7FF),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'VS',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    shadows: [Shadow(color: Colors.purple, blurRadius: 10)],
                  ),
                ),
              ),
              ScaleTransition(
                scale: _opponentPulseAnim,
                child: _buildScoreTile(
                  '$_opponentAvatar ${_isDemo ? _botName : (_match.opponentUsername ?? "Rakip")}',
                  _opponentScore,
                  _opponentStreak,
                  const Color(0xFFE91E63),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildScoreTile(String label, int score, int streak, Color color) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Column(
        children: [
          Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
          Text('$score', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          if (streak > 1)
            Text('🔥 $streak', style: const TextStyle(color: Colors.orangeAccent, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildContent() {
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
            ),
          ),
        ],
      ),
    );
  }
}
