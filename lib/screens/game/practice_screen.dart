import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/practice_provider.dart';
import '../../services/word_pool_service.dart';
import '../../widgets/game/question_card.dart';
import '../../widgets/game/options_grid.dart';
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
    if (!mounted) return;
    // Skip 3-2-1 countdown for Practice Mode as requested
    setState(() {
      _showCountdown = false;
      _showPreScreen = false;
    });
    _startTimer();
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
                    colors: [Color(0xFF2E5A8C), Color(0xFF1A3A5C)],
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
                    Colors.black.withOpacity(0.5),
                    Colors.black.withOpacity(0.7),
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
                        colors: [Color(0xFF2E5A8C), Color(0xFF1A3A5C)],
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
                        Colors.black.withOpacity(0.5),
                        Colors.black.withOpacity(0.7),
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

        return _buildPracticeGameScreen(practiceProvider);
      },
    );
  }

  Widget _buildPracticeGameScreen(PracticeProvider provider) {
    return Scaffold(
      backgroundColor: const Color(0xFF2E5A8C),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(provider),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    QuestionCard(
                      prompt: provider.currentPrompt,
                    ),
                    const SizedBox(height: 30),
                    Expanded(
                      child: OptionsGrid(
                        options: provider.currentOptions,
                        correctIndex: provider.currentCorrectIndex,
                        selectedIndex: _selectedIndex,
                        onOptionSelected: _answer,
                        isLocked: _answered,
                        showCorrect: _answered,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(PracticeProvider provider) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.1))),
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _headerInfo('DÜZEY', provider.currentLevel, Colors.orange),
                    _headerInfo('SÜRE', '${_timeLeft}s', Colors.redAccent),
                    _headerInfo('PUAN', '${provider.sessionScore}', Colors.greenAccent),
                  ],
                ),
              ),
              const SizedBox(width: 40), // Balance for back button
            ],
          ),
          const SizedBox(height: 12),
          // Progress Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: (provider.currentQuestionIndex + 1) / 10,
                backgroundColor: Colors.white.withOpacity(0.1),
                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF2AA7FF)),
                minHeight: 6,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _headerInfo(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 10, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 0.5),
        ),
      ],
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
                  colors: [Color(0xFF2E5A8C), Color(0xFF1A3A5C)],
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
                  Colors.black.withOpacity(0.5),
                  Colors.black.withOpacity(0.7),
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
                        color: const Color(0xFFFF9800).withOpacity(0.4),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
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
                            color: Colors.white.withOpacity(0.2),
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
                              color: (_countdown == 1 ? Colors.green : _countdown == 2 ? Colors.orange : Colors.red).withOpacity(0.5),
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

}
