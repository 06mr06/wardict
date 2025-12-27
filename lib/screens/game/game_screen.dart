import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/game_provider.dart';
import '../../models/question_mode.dart';
import 'results_screen.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}


class _GameScreenState extends State<GameScreen> with TickerProviderStateMixin {
  bool _showPreScreen = true;
  bool _showCountdown = true;
  int _countdown = 3;
  int _timeLeft = 5;
  Timer? _timer;
  int? _selectedIndex;
  bool _answered = false;
  int _earnedPoint = 0;
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;
  late AnimationController _waveController;

  @override
  void initState() {
    super.initState();
    _selectedIndex = null;
    _answered = false;
    _earnedPoint = 0;
    _initAnimation();
    _waveController = AnimationController(vsync: this, duration: const Duration(milliseconds: 2000))..repeat();
    _showPreScreen = true;
    _showCountdown = true;
    _countdown = 3;
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
            _showPreScreen = false;
          });
          _startTimer();
        });
      });
    });
  }

  // Pre-screen kaldırıldı (Practice modda kullanılmıyor).

  void _initAnimation() {
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeAnim = Tween<double>(begin: 1, end: 0).animate(_animController);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0),
      end: const Offset(0, -0.6),
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    ));
  }

  void _startTimer() {
    _timer?.cancel();
    _timeLeft = 5;
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_timeLeft == 0) {
        t.cancel();
        _onTimeUp();
      } else {
        setState(() => _timeLeft--);
      }
    });
  }

  void _onTimeUp() {
    if (_answered) return;
    setState(() {
      _answered = true;
      _earnedPoint = 0;
    });
    final gameProvider = context.read<GameProvider>();
    gameProvider.answer(-1, 0);
    Future.delayed(const Duration(seconds: 2), _nextQuestion);
  }

  void _answer(int index) {
    // Eğer zaten cevaplandıysa veya süre bittiyse yeni cevap kabul etme
    if (_answered || _timeLeft == 0) return;
    _timer?.cancel();
    final gameProvider = context.read<GameProvider>();
    setState(() {
      _selectedIndex = index;
      _answered = true;
    });
    gameProvider.answer(index, _timeLeft);
    setState(() {
      _earnedPoint = gameProvider.lastScore;
    });
    if (_earnedPoint > 0) {
      _animController.forward(from: 0);
    }
    Future.delayed(const Duration(seconds: 2), _nextQuestion);
  }

  void _nextQuestion() {
    if (!mounted) return;
    final gameProvider = context.read<GameProvider>();
    // Son soru ise sonuç ekranına git
    if (gameProvider.index + 1 >= gameProvider.questionCount) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const ResultsScreen(),
        ),
      );
      return;
    }
    // Provider içinde soruyu ilerlet ve geri sayımı başlat
    gameProvider.goNext();
    _animController.reset();
    setState(() {
      _selectedIndex = null;
      _answered = false;
      _earnedPoint = 0;
      _showPreScreen = true;
      _showCountdown = true;
      _countdown = 3;
    });
    _runCountdown();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _animController.dispose();
    _waveController.dispose();
    super.dispose();
  }

  Widget _buildBadge(QuestionMode mode, {double size = 20, bool wave = false}) {
    Widget inner;
    switch (mode) {
      case QuestionMode.enToTr:
      case QuestionMode.trToEn:
        inner = Text(
          _modeEmoji(mode),
          style: TextStyle(fontSize: size),
        );
        break;
      case QuestionMode.engToEng:
        inner = Text('🇬🇧＝🇬🇧', style: TextStyle(fontSize: size));
        break;
    }
    if (!wave) return inner;
    return AnimatedBuilder(
      animation: _waveController,
      builder: (context, _) {
        final v = _waveController.value;
        final angle = math.sin(v * 2 * math.pi) * 0.2; // ~11 deg
        final y = math.sin(v * 2 * math.pi) * 10;
        return Transform.translate(
          offset: Offset(0, y),
          child: Transform.rotate(angle: angle, child: inner),
        );
      },
    );
  }

  // Pre-screen: show flag → arrow → flag sequentially (direction based on mode)
  Widget _buildModeSequence(QuestionMode mode, {required double size, required double t}) {
    List<Widget> pieces;
    switch (mode) {
      case QuestionMode.enToTr:
        pieces = [
          Text('🇬🇧', style: TextStyle(fontSize: size)),
          const SizedBox(width: 6),
          const Text('➡️', style: TextStyle(fontSize: 28)),
          const SizedBox(width: 6),
          Text('🇹🇷', style: TextStyle(fontSize: size)),
        ];
        break;
      case QuestionMode.trToEn:
        pieces = [
          Text('🇹🇷', style: TextStyle(fontSize: size)),
          const SizedBox(width: 6),
          const Text('➡️', style: TextStyle(fontSize: 28)),
          const SizedBox(width: 6),
          Text('🇬🇧', style: TextStyle(fontSize: size)),
        ];
        break;
      case QuestionMode.engToEng:
        pieces = [
          Text('🇬🇧', style: TextStyle(fontSize: size)),
          const SizedBox(width: 6),
          const Text('＝', style: TextStyle(fontSize: 28)),
          const SizedBox(width: 6),
          Text('🇬🇧', style: TextStyle(fontSize: size)),
        ];
        break;
    }

    // Sequential fade-in for each non-SizedBox piece
    final items = <Widget>[];
    int logicalIndex = 0;
    for (final w in pieces) {
      if (w is SizedBox) {
        items.add(w);
        continue;
      }
      final start = (logicalIndex) / 3.0;
      final end = (logicalIndex + 1) / 3.0;
      final prog = ((t - start) / (end - start)).clamp(0.0, 1.0);
      items.add(Opacity(opacity: prog, child: w));
      logicalIndex++;
    }

    return Row(mainAxisSize: MainAxisSize.min, children: items);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<GameProvider>(
      builder: (context, gameProvider, child) {
        if (gameProvider.isFinished) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => const ResultsScreen(),
              ),
            );
          });
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }
        final q = gameProvider.currentQuestion;
        if (_showPreScreen) {
          return Scaffold(
            body: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF1a1a2e), Color(0xFF16213e)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Mode badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF6C27FF), Color(0xFF2AA7FF)],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF6C27FF).withValues(alpha: 0.4),
                            blurRadius: 20,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildBadge(q.mode, size: 22),
                          const SizedBox(width: 8),
                          Text(
                            _modeShortText(q.mode),
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
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
            ),
          );
        }

        // Main question UI
        return Scaffold(
          body: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF1a1a2e), Color(0xFF16213e)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Progress bar
                    Container(
                      height: 8,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        color: Colors.white.withValues(alpha: 0.2),
                      ),
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: (gameProvider.index + 1) / gameProvider.questionCount,
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
                    const SizedBox(height: 12),
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
                              _buildBadge(q.mode, size: 18, wave: false),
                            const SizedBox(width: 6),
                            Text(
                              _modeShortText(q.mode),
                              style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
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
                      const Spacer(),
                      Consumer<GameProvider>(
                        builder: (_, gp, __) => gp.streak > 0
                            ? Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.orange,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  '🔥 ${gp.streak}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ),
                  if (_earnedPoint > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Align(
                        alignment: Alignment.center,
                        child: SlideTransition(
                          position: _slideAnim,
                          child: FadeTransition(
                            opacity: _fadeAnim,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [Colors.green.shade400, Colors.green.shade600],
                                ),
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.green.withValues(alpha: 0.5),
                                    blurRadius: 12,
                                  ),
                                ],
                              ),
                              child: Text(
                                '+$_earnedPoint',
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
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
                    child: Text(
                      q.prompt,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final isNarrow = constraints.maxWidth < 420;
                        final crossAxisCount = isNarrow ? 1 : 2;
                        final aspect = isNarrow ? 3.2 : 2.0;
                        final provider = context.read<GameProvider>();
                        final options = provider.currentOptions;
                        final correctIndex = provider.currentCorrectIndex;
                        return GridView.builder(
                          itemCount: options.length,
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: crossAxisCount,
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                            childAspectRatio: aspect,
                          ),
                          itemBuilder: (_, i) {
                            final bool shouldHighlight = (_selectedIndex != null) || (_timeLeft == 0);
                            List<Color> gradientColors = [Colors.white.withValues(alpha: 0.15), Colors.white.withValues(alpha: 0.05)];
                            Color borderColor = Colors.white.withValues(alpha: 0.3);
                            IconData? trailingIcon;

                            if (shouldHighlight) {
                              if (_selectedIndex == null) {
                                if (i == correctIndex) {
                                  gradientColors = [Colors.green.shade400, Colors.green.shade600];
                                  borderColor = Colors.green;
                                  trailingIcon = Icons.check_circle;
                                }
                              } else {
                                if (_selectedIndex == correctIndex) {
                                  if (i == _selectedIndex) {
                                    gradientColors = [Colors.green.shade400, Colors.green.shade600];
                                    borderColor = Colors.green;
                                    trailingIcon = Icons.check_circle;
                                  }
                                } else {
                                  if (i == _selectedIndex) {
                                    gradientColors = [Colors.red.shade400, Colors.red.shade600];
                                    borderColor = Colors.red;
                                    trailingIcon = Icons.cancel;
                                  } else if (i == correctIndex) {
                                    gradientColors = [Colors.green.shade400, Colors.green.shade600];
                                    borderColor = Colors.green;
                                    trailingIcon = Icons.check_circle;
                                  }
                                }
                              }
                            } else if (_selectedIndex == i) {
                              gradientColors = [const Color(0xFF2AA7FF), const Color(0xFF1167B1)];
                              borderColor = Colors.white;
                            }
                            return GestureDetector(
                              onTap: () => _answer(i),
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
                                        options[i],
                                        textAlign: TextAlign.center,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
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
                        );
                      },
                    ),
                  ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

String _modeShortText(QuestionMode mode) {
  switch (mode) {
    case QuestionMode.enToTr:
      return 'EN > TR';
    case QuestionMode.trToEn:
      return 'TR > ENG';
    case QuestionMode.engToEng:
      return 'Eş Anlam';
  }
}

String _modeEmoji(QuestionMode mode) {
  switch (mode) {
    case QuestionMode.enToTr:
      return '🇬🇧➡️🇹🇷';
    case QuestionMode.trToEn:
      return '🇹🇷➡️🇬🇧';
    case QuestionMode.engToEng:
      return '🇬🇧＝🇬🇧';
  }
}

// Moved `_buildBadge` into the state so it can access `_waveController`.


