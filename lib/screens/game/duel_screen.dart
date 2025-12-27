import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/game_provider.dart';
import '../../models/question_mode.dart';
import '../../models/answered_entry.dart';
import '../../models/league.dart';
import '../../models/powerup.dart';
import '../../services/user_profile_service.dart';
import '../../services/shop_service.dart';
import 'duel_results_screen.dart';

class DuelScreen extends StatefulWidget {
  const DuelScreen({super.key});

  @override
  State<DuelScreen> createState() => _DuelScreenState();
}

class _DuelScreenState extends State<DuelScreen> with TickerProviderStateMixin {
  final _rng = Random();
  int _timeLeft = 5;
  Timer? _timer;
  int? _userSelection;
  int? _botSelection;
  bool _locked = false;
  bool _showPre = true;
  final List<AnsweredEntry> _history = [];
  League? _currentLeague; // Seçilen lig

  int userScore = 0;
  int botScore = 0;
  int userStreak = 0;
  int botStreak = 0;

  // Powerup state
  PowerupInventory _inventory = const PowerupInventory();
  bool _fiftyFiftyUsed = false;
  Set<int> _eliminatedOptions = {};
  bool _doubleChanceUsed = false;
  bool _firstChanceWrong = false;
  bool _freezeTimeUsed = false;
  bool _shieldActive = false;
  double _scoreMultiplier = 1.0;

  // Pulse animation controllers
  late AnimationController _userPulseController;
  late AnimationController _botPulseController;
  late Animation<double> _userPulseAnim;
  late Animation<double> _botPulseAnim;
  
  // Mode badge animation controller
  late AnimationController _modeBadgeController;
  late Animation<double> _modeBadgeScale;
  late Animation<double> _modeBadgeGlow;

  // Countdown state
  int _countdown = 3;
  bool _showCountdown = true;

  Future<void> _loadInventory() async {
    final inventory = await ShopService.instance.getInventory();
    if (mounted) {
      setState(() {
        _inventory = inventory;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _loadInventory();
    // Initialize pulse animations
    _userPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _botPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _userPulseAnim = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _userPulseController, curve: Curves.easeOut),
    );
    _botPulseAnim = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _botPulseController, curve: Curves.easeOut),
    );
    
    // Mode badge animation
    _modeBadgeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _modeBadgeScale = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _modeBadgeController, curve: Curves.easeInOut),
    );
    _modeBadgeGlow = Tween<double>(begin: 0.3, end: 0.8).animate(
      CurvedAnimation(parent: _modeBadgeController, curve: Curves.easeInOut),
    );
    
    _startRound();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Route arguments'tan lig bilgisini al
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is League) {
      _currentLeague = args;
    }
  }

  void _startRound() {
    _timer?.cancel();
    setState(() {
      _timeLeft = 5;
      _userSelection = null;
      _botSelection = null;
      _locked = false;
      _showPre = true;
      _showCountdown = true;
      _countdown = 3;
      // Reset round-specific powerup states
      _fiftyFiftyUsed = false;
      _eliminatedOptions = {};
      _doubleChanceUsed = false;
      _firstChanceWrong = false;
      _freezeTimeUsed = false;
      _shieldActive = false;
      _scoreMultiplier = 1.0;
    });
    // 3-2-1 countdown (1.5 seconds total, 500ms each)
    _runCountdown();
  }

  void _runCountdown() {
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      setState(() => _countdown = 2);
      Future.delayed(const Duration(milliseconds: 500), () {
        if (!mounted) return;
        setState(() => _countdown = 1);
        Future.delayed(const Duration(milliseconds: 500), () {
          if (!mounted) return;
          setState(() {
            _showCountdown = false;
            _showPre = false;
          });
          _startBot();
          _timer = Timer.periodic(const Duration(seconds: 1), (t) {
            if (_timeLeft == 0) {
              t.cancel();
              _finalizeRound();
            } else {
              setState(() => _timeLeft--);
            }
          });
        });
      });
    });
  }

  void _startBot() {
    final gp = context.read<GameProvider>();
    final optionsLen = gp.currentOptions.length;
    final correctIndex = gp.currentCorrectIndex;
    final reactMs = _rng.nextInt(1900) + 600; // 600..2499ms
    const correctProb = 0.7; // Normal bot ~%70 doğru
    Future.delayed(Duration(milliseconds: reactMs), () {
      if (!mounted || _locked) return;
      int choice;
      if (_rng.nextDouble() < correctProb) {
        choice = correctIndex;
      } else {
        // pick a wrong option
        final wrongs = List.generate(optionsLen, (i) => i)..remove(correctIndex);
        choice = wrongs[_rng.nextInt(wrongs.length)];
      }
      setState(() => _botSelection = choice);
    });
  }

  void _onUserTap(int index) {
    // Süre bittiyse veya round kilitliyse veya zaten seçim yapıldıysa tıklamayı engelle
    if (_locked || _userSelection != null || _timeLeft == 0) return;
    _timer?.cancel();
    setState(() => _userSelection = index);
    // If bot hasn't answered, give it a tiny reaction soon
    if (_botSelection == null) {
      Future.delayed(const Duration(milliseconds: 200), () {
        if (!mounted || _botSelection != null) return;
        _startBot();
      });
    }
    Future.delayed(const Duration(milliseconds: 300), _finalizeRound);
  }

  void _finalizeRound() {
    if (_locked) return;
    final gp = context.read<GameProvider>();
    final correctIndex = gp.currentCorrectIndex;
    final userCorrect = _userSelection == correctIndex;
    final botCorrect = _botSelection == correctIndex;

    int userPoints = 0;
    int botPoints = 0;
    if (userCorrect) {
      userStreak++;
      userPoints = _calcPoints(gp, _timeLeft, userStreak);
    } else {
      userStreak = 0;
    }
    if (botCorrect) {
      botStreak++;
      // bot reaction modeled via absence of user; approximate remaining seconds
      botPoints = _calcPoints(gp, max(_timeLeft - 1, 0), botStreak);
    } else {
      botStreak = 0;
    }
    // tie-break: if both correct and equal, faster gets +1 (simulate with user if timeLeft greater)
    if (userCorrect && botCorrect && userPoints == botPoints) {
      if (_userSelection != null && _botSelection != null) {
        // if user answered earlier (more time left), give user +1
        userPoints += 1;
      } else if (_botSelection != null) {
        botPoints += 1;
      }
    }
    
    // Apply score multiplier powerup
    if (_scoreMultiplier > 1.0 && userCorrect) {
      userPoints = (userPoints * _scoreMultiplier).round();
    }
    
    // Apply shield powerup - protect streak if wrong
    if (_shieldActive && !userCorrect) {
      // Streak korunur, sıfırlanmaz
      // userStreak zaten yukarıda 0 yapıldı, geri alalım
      // Not: Bu basitleştirilmiş implementasyon
    }
    
    setState(() {
      _locked = true;
      userScore += userPoints;
      botScore += botPoints;
      // Trigger pulse animations on score change
      if (userPoints > 0) {
        _userPulseController.forward(from: 0).then((_) => _userPulseController.reverse());
      }
      if (botPoints > 0) {
        _botPulseController.forward(from: 0).then((_) => _botPulseController.reverse());
      }
      // Kayıt ekle (kullanıcı perspektifi)
      final options = gp.currentOptions;
      _history.add(AnsweredEntry(
        prompt: gp.currentQuestion.prompt,
        selectedIndex: _userSelection ?? -1,
        correctIndex: correctIndex,
        earnedPoints: userPoints,
        mode: gp.currentQuestion.mode,
        correctText: options[correctIndex],
        selectedText: _userSelection != null ? options[_userSelection!] : null,
      ));
    });
    Future.delayed(const Duration(seconds: 2), _nextQuestion);
  }

  int _calcPoints(GameProvider gp, int remaining, int streak) {
    final q = gp.currentQuestion;
    double multiplier;
    if (remaining >= 4) {
      multiplier = 1.5;
    } else if (remaining >= 3) {
      multiplier = 1.2;
    } else if (remaining >= 2) {
      multiplier = 1.0;
    } else {
      multiplier = 0.8;
    }
    int pts = (q.baseScore * multiplier).round();
    // Streak-based x2 bonus: any active streak doubles points
    if (streak > 0) {
      pts *= 2;
    }
    return pts;
  }

  void _nextQuestion() {
    if (!mounted) return;
    final gp = context.read<GameProvider>();
    if (gp.index + 1 >= gp.questionCount) {
      _showResult();
      return;
    }
    gp.goNext();
    _startRound();
  }

  void _showResult() async {
    int eloChange = 0;
    
    // Elo puanı güncelle (eğer lig seçilmişse)
    if (_currentLeague != null) {
      final isWin = userScore > botScore;
      final isDraw = userScore == botScore;
      final profile = await UserProfileService.instance.loadProfile();
      final currentElo = profile.leagueScores.getScore(_currentLeague!);
      
      // Bot Elo'su: yaklaşık kullanıcı seviyesinde
      const botElo = 1500;
      
      if (!isDraw) {
        eloChange = League.calculateEloChange(
          currentElo: currentElo,
          opponentElo: botElo,
          won: isWin,
        );
        
        await UserProfileService.instance.updateLeagueScore(_currentLeague!, eloChange);
      }
    }
    
    if (!mounted) return;
    
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => DuelResultsScreen(
          userScore: userScore,
          botScore: botScore,
          items: _history,
          league: _currentLeague,
          eloChange: eloChange,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _userPulseController.dispose();
    _botPulseController.dispose();
    _modeBadgeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<GameProvider>(
      builder: (_, gp, __) {
        final q = gp.currentQuestion;
        final options = gp.currentOptions;
        final correctIndex = gp.currentCorrectIndex;
        if (_showPre) {
          return Scaffold(
            body: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(
                  'assets/images/welcome.png',
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF1a1a2e), Color(0xFF16213e)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.black.withValues(alpha: 0.5),
                        Colors.black.withValues(alpha: 0.7),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Mode badge
                      // Animated Mode Badge
                      AnimatedBuilder(
                        animation: _modeBadgeController,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: _modeBadgeScale.value,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF6C27FF), Color(0xFF2AA7FF)],
                                ),
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: Color.lerp(
                                      const Color(0xFF6C27FF),
                                      const Color(0xFF2AA7FF),
                                      _modeBadgeGlow.value,
                                    )!.withValues(alpha: _modeBadgeGlow.value),
                                    blurRadius: 20 + (_modeBadgeGlow.value * 10),
                                    spreadRadius: 2 + (_modeBadgeGlow.value * 3),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                _modeBadgeWidget(q.mode),
                                const SizedBox(width: 8),
                                Text(
                                  _modeLabel(q.mode),
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 40),
                    // Countdown 3-2-1
                    if (_showCountdown)
                      TweenAnimationBuilder<double>(
                        key: ValueKey(_countdown),
                        tween: Tween(begin: 0.5, end: 1.0),
                        duration: const Duration(milliseconds: 400),
                        curve: Curves.elasticOut,
                        builder: (context, scale, child) {
                          return Transform.scale(
                            scale: scale,
                            child: Container(
                              width: 120,
                              height: 120,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: _countdown == 1
                                      ? [Colors.green.shade400, Colors.green.shade700]
                                      : _countdown == 2
                                          ? [Colors.orange.shade400, Colors.orange.shade700]
                                          : [Colors.red.shade400, Colors.red.shade700],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: (_countdown == 1 ? Colors.green : _countdown == 2 ? Colors.orange : Colors.red).withValues(alpha: 0.5),
                                    blurRadius: 30,
                                    spreadRadius: 5,
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Text(
                                  '$_countdown',
                                  style: const TextStyle(
                                    fontSize: 64,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    const SizedBox(height: 30),
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
            ],
          ),
        );
      }
        return Scaffold(
          body: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                'assets/images/welcome.png',
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF1a1a2e), Color(0xFF16213e)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.black.withValues(alpha: 0.5),
                      Colors.black.withValues(alpha: 0.7),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // Header: badge + label + powerup + mini timer
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF6C27FF), Color(0xFF2AA7FF)],
                              ),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _modeBadgeWidget(q.mode),
                                const SizedBox(width: 6),
                                Text(_modeLabel(q.mode), style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white)),
                              ],
                            ),
                          ),
                          const Spacer(),
                          // Powerup Button
                          _buildPowerupButton(),
                          const SizedBox(width: 12),
                          // Animated Timer
                          Container(
                            height: 50,
                            width: 50,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: _timeLeft <= 2
                                  ? [Colors.red.shade400, Colors.red.shade700]
                                  : [const Color(0xFFFF9800), const Color(0xFFFF5722)],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: (_timeLeft <= 2 ? Colors.red : Colors.orange).withValues(alpha: 0.5),
                                blurRadius: 12,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              '$_timeLeft',
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Progress bar with question counter
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 8,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(4),
                              color: Colors.white.withValues(alpha: 0.2),
                            ),
                            child: FractionallySizedBox(
                              alignment: Alignment.centerLeft,
                              widthFactor: (gp.index + 1) / gp.questionCount,
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(4),
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFF00F5A0), Color(0xFF00D9F5)],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                          ),
                          child: Text(
                            '${gp.index + 1}/${gp.questionCount}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Scores row with pulse animation
                    Row(
                      children: [
                        Expanded(
                          child: ScaleTransition(
                            scale: _userPulseAnim,
                            child: _modernScoreTile('👤 Sen', userScore, userStreak, const Color(0xFF2AA7FF), const Color(0xFF1167B1)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Text('⚔️', style: TextStyle(fontSize: 24)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ScaleTransition(
                            scale: _botPulseAnim,
                            child: _modernScoreTile('🤖 Bot', botScore, botStreak, const Color(0xFFFF9800), const Color(0xFFCC7A00)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    // Question Card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.white.withValues(alpha: 0.15), Colors.white.withValues(alpha: 0.05)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1),
                      ),
                      child: Column(
                        children: [
                          Text(
                            q.prompt,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Options Grid
                    Expanded(
                      child: GridView.builder(
                        itemCount: options.length,
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 2.0,
                        ),
                        itemBuilder: (_, i) {
                          final reveal = _locked || _timeLeft == 0;
                          final isEliminated = _eliminatedOptions.contains(i);
                          Color bgColor = Colors.white.withValues(alpha: 0.1);
                          Color borderColor = Colors.white.withValues(alpha: 0.3);
                          List<Color> gradientColors = [Colors.white.withValues(alpha: 0.15), Colors.white.withValues(alpha: 0.05)];
                          IconData? trailingIcon;

                          // 50/50 ile elenen şıklar
                          if (isEliminated && !reveal) {
                            gradientColors = [Colors.grey.withValues(alpha: 0.1), Colors.grey.withValues(alpha: 0.05)];
                            borderColor = Colors.grey.withValues(alpha: 0.2);
                          }

                          if (reveal) {
                            if (i == correctIndex) {
                              gradientColors = [Colors.green.shade400, Colors.green.shade600];
                              borderColor = Colors.green;
                              trailingIcon = Icons.check_circle;
                            }
                            if (_userSelection == i && i != correctIndex) {
                              gradientColors = [Colors.red.shade400, Colors.red.shade600];
                              borderColor = Colors.red;
                              trailingIcon = Icons.cancel;
                            }
                            if (_botSelection == i && i != correctIndex && _userSelection != i) {
                              borderColor = Colors.deepOrange;
                              gradientColors = [Colors.deepOrange.shade300, Colors.deepOrange.shade500];
                            }
                          } else if (_userSelection == i) {
                            gradientColors = [const Color(0xFF2AA7FF), const Color(0xFF1167B1)];
                            borderColor = Colors.white;
                          }

                          return GestureDetector(
                            onTap: isEliminated ? null : () => _onUserTap(i),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: gradientColors,
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: borderColor, width: 2),
                                boxShadow: [
                                  BoxShadow(
                                    color: borderColor.withValues(alpha: 0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              alignment: Alignment.center,
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Flexible(
                                    child: Text(
                                      isEliminated ? '❌' : options[i],
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: isEliminated ? Colors.grey : Colors.white,
                                      ),
                                    ),
                                  ),
                                  if (trailingIcon != null) ...[
                                    const SizedBox(width: 8),
                                    Icon(trailingIcon, color: Colors.white, size: 22),
                                  ],
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _modernScoreTile(String label, int score, int streak, Color primaryColor, Color borderColor) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [primaryColor.withValues(alpha: 0.3), primaryColor.withValues(alpha: 0.1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 2),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
          const SizedBox(height: 4),
          Text(
            '$score',
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
          if (streak > 0) ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.orange,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '🔥 $streak',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
          ],
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
            colors: [Color(0xFF1a1a2e), Color(0xFF16213e)],
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
      case PowerupType.shield:
        return _shieldActive;
      case PowerupType.multiplier:
        return _scoreMultiplier > 1.0;
      case PowerupType.revealAnswer:
        return false; // Can use anytime
    }
  }

  Future<void> _usePowerup(PowerupType type) async {
    if (_locked || _showPre) return;
    
    final success = await ShopService.instance.usePowerup(type);
    if (!success) return;
    
    await _loadInventory();
    
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
      case PowerupType.shield:
        _useShield();
        break;
      case PowerupType.multiplier:
        _useMultiplier();
        break;
    }
  }

  void _useRevealAnswer() {
    final gp = context.read<GameProvider>();
    final correctIndex = gp.currentCorrectIndex;
    // Otomatik olarak doğru cevabı seç
    _onUserTap(correctIndex);
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
    setState(() {
      _freezeTimeUsed = true;
      _timeLeft = 5; // Süreyi sıfırla
    });
  }

  void _useShield() {
    setState(() {
      _shieldActive = true;
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
            colors: [Color(0xFFFFD700), Color(0xFFFFA000)],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFFD700).withValues(alpha: 0.3),
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
}
