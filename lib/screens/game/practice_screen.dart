import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/practice_provider.dart';
import '../../services/word_pool_service.dart';
import 'practice_results_screen.dart';

class PracticeScreen extends StatefulWidget {
  const PracticeScreen({super.key});

  @override
  State<PracticeScreen> createState() => _PracticeScreenState();
}

class _PracticeScreenState extends State<PracticeScreen> with TickerProviderStateMixin {
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
  
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initAnimation();
    _waveController = AnimationController(vsync: this, duration: const Duration(milliseconds: 2000))..repeat();
    _initPractice();
  }

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

  Future<void> _initPractice() async {
    await WordPoolService.instance.loadWordPool();
    final practiceProvider = context.read<PracticeProvider>();
    await practiceProvider.startSession();
    
    if (mounted) {
      setState(() => _isLoading = false);
      _runCountdown();
    }
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
    final practiceProvider = context.read<PracticeProvider>();
    practiceProvider.answer(-1, 0);
    Future.delayed(const Duration(seconds: 2), _nextQuestion);
  }

  void _answer(int index) {
    if (_answered || _timeLeft == 0) return;
    _timer?.cancel();
    
    final practiceProvider = context.read<PracticeProvider>();
    final isCorrect = index == practiceProvider.currentCorrectIndex;
    
    setState(() {
      _selectedIndex = index;
      _answered = true;
    });
    
    practiceProvider.answer(index, _timeLeft);
    
    // Kazanılan puanı göster
    if (practiceProvider.answerHistory.isNotEmpty) {
      final lastAnswer = practiceProvider.answerHistory.last;
      _earnedPoint = lastAnswer.points;
    }
    
    if (_earnedPoint > 0) {
      _animController.forward(from: 0);
    }
    
    Future.delayed(const Duration(seconds: 2), _nextQuestion);
  }

  void _nextQuestion() {
    if (!mounted) return;
    final practiceProvider = context.read<PracticeProvider>();
    
    // Oturum tamamlandı mı?
    if (practiceProvider.isSessionComplete) {
      _showResults();
      return;
    }
    
    practiceProvider.nextQuestion();
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

  Future<void> _showResults() async {
    final practiceProvider = context.read<PracticeProvider>();
    final result = await practiceProvider.completeSession();
    
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => PracticeResultsScreen(result: result),
        ),
      );
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _animController.dispose();
    _waveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
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
            const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
          ],
        ),
      );
    }

    return Consumer<PracticeProvider>(
      builder: (context, practiceProvider, child) {
        final question = practiceProvider.currentQuestion;
        
        if (question == null) {
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
                const Center(
                  child: Text('Soru yüklenemedi', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          );
        }

        if (_showPreScreen) {
          return _buildPreScreen(practiceProvider);
        }

        return _buildQuestionScreen(practiceProvider);
      },
    );
  }

  Widget _buildPreScreen(PracticeProvider provider) {
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
                // Seviye ve soru numarası
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF9800), Color(0xFFFF5722)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFF9800).withValues(alpha: 0.4),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.school, color: Colors.white, size: 22),
                    const SizedBox(width: 8),
                    Text(
                      'Seviye: ${provider.currentLevel}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${provider.currentQuestionIndex + 1}/10',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
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
        ],
      ),
    );
  }

  Widget _buildQuestionScreen(PracticeProvider provider) {
    final question = provider.currentQuestion!;
    final options = provider.currentOptions;
    final correctIndex = provider.currentCorrectIndex;

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
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
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
                            widthFactor: (provider.currentQuestionIndex + 1) / 10,
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
                        '${provider.currentQuestionIndex + 1}/10',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                
                // Header row
                Row(
                  children: [
                    // Seviye badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFF9800), Color(0xFFFF5722)],
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        provider.currentLevel,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const Spacer(),
                    // Timer
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
                    // Puan
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.green),
                      ),
                      child: Text(
                        'P: ${provider.sessionScore}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ),
                  ],
                ),
                
                // Puan animasyonu
                if (_earnedPoint != 0)
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
                                colors: _earnedPoint > 0
                                    ? [Colors.green.shade400, Colors.green.shade600]
                                    : [Colors.red.shade400, Colors.red.shade600],
                              ),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: (_earnedPoint > 0 ? Colors.green : Colors.red).withValues(alpha: 0.5),
                                  blurRadius: 12,
                                ),
                              ],
                            ),
                            child: Text(
                              _earnedPoint > 0 ? '+$_earnedPoint' : '$_earnedPoint',
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
                    question.prompt,
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
                
                // Options
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final isNarrow = constraints.maxWidth < 420;
                      final crossAxisCount = isNarrow ? 1 : 2;
                      final aspect = isNarrow ? 3.2 : 2.0;
                      
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
        ],
      ),
    );
  }
}
