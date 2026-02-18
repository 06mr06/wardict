import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/user_level.dart';
import '../../services/word_pool_service.dart';
import '../../models/practice_session.dart';
import '../../providers/practice_provider.dart';
import '../../widgets/game/question_card.dart';
import '../../widgets/game/options_grid.dart';
import 'practice_results_screen.dart';
import '../../services/sound_service.dart';
import '../../widgets/animations/shake_widget.dart';
/// SeventyThirtyScreen - Alıştırma (70/30) ve Seviye Tespit (Level Test) ekranı
class SeventyThirtyScreen extends StatefulWidget {
  const SeventyThirtyScreen({super.key});

  @override
  State<SeventyThirtyScreen> createState() => _SeventyThirtyScreenState();
}

class _SeventyThirtyScreenState extends State<SeventyThirtyScreen> with TickerProviderStateMixin {
  // Eksik değişken tanımları
  late AnimationController _waveController;
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;
  bool _isLoading = true;
  bool _showCountdown = false; // Geri sayımı kapattık
  bool _showPreScreen = false; // Ara ekranı kapattık
  Timer? _timer;
  int _timeLeft = 7; // Standart 7 saniye
  bool _answered = false;
  int? _selectedIndex;
  int _countdown = 3;
  final GlobalKey<ShakeWidgetState> _shakeKey = GlobalKey<ShakeWidgetState>();

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
    final practiceProvider = context.read<PracticeProvider>();
    await practiceProvider.startSession();
    
    if (mounted) {
      setState(() => _isLoading = false);
      _startTimer(); // Geri sayım yerine direkt zamanlayıcıyı başlat
    }
  }

  void _runCountdown() {
    if (!mounted) return;
    
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_countdown == 0) {
        t.cancel();
        setState(() {
          _showCountdown = false;
          _showPreScreen = false;
        });
        _startTimer();
      } else {
        setState(() => _countdown--);
      }
    });
  }

  void _startTimer() {
    _timer?.cancel();
    _timeLeft = 7;
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_timeLeft == 0) {
        t.cancel();
        _onTimeUp();
      } else {
        setState(() => _timeLeft--);
        // Son 3 saniyede sesli uyarı ver
        if (_timeLeft <= 3 && _timeLeft > 0) {
          SoundService.instance.playCountdown();
          SoundService.instance.vibrate(HapticFeedbackType.light);
        }
      }
    });
  }

  void _onTimeUp() {
    if (_answered) return;
    setState(() {
      _answered = true;
    });
    final practiceProvider = context.read<PracticeProvider>();
    practiceProvider.answer(-1, 0);
    Future.delayed(const Duration(seconds: 2), _nextQuestion);
  }

  void _answer(int index) {
    if (_answered || _timeLeft == 0) return;
    _timer?.cancel();
    
    final practiceProvider = context.read<PracticeProvider>();
    
    setState(() {
      _selectedIndex = index;
      _answered = true;
    });
    
    practiceProvider.answer(index, _timeLeft);
    
    // Kazanılan puanı göster
    if (practiceProvider.answerHistory.isNotEmpty) {
      final lastAnswer = practiceProvider.answerHistory.last;
      
      if (lastAnswer.isCorrect) {
        SoundService.instance.playCorrect();
        SoundService.instance.vibrate(HapticFeedbackType.medium);
        _animController.forward(from: 0);
      } else {
        SoundService.instance.playWrong();
        SoundService.instance.vibrate(HapticFeedbackType.heavy);
        _shakeKey.currentState?.shake();
      }
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
      _showPreScreen = false;
      _showCountdown = false;
      _countdown = 0;
    });
    _startTimer(); // Direkt sonraki soru zamanlayıcısı
  }

  Future<void> _showResults() async {
    final practiceProvider = context.read<PracticeProvider>();
    final result = await practiceProvider.completeSession();
    
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => SeventyThirtyResultsScreen(result: result),
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
      return const Scaffold(
        backgroundColor: Color(0xFF1A3A5C),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final practiceProvider = context.watch<PracticeProvider>();
    
    if (_showPreScreen) {
      return _buildPreScreen(practiceProvider);
    }

    return _buildPracticeGameScreen(practiceProvider);
  }

  Widget _buildPracticeGameScreen(PracticeProvider provider) {
    // Puan durumu (Doğru sayısı * 10 = Yüzde)
    final double successPercentage = provider.correctInSession * 10.0;
    
    // Dinamik Renk Seçimi
    Color progressColor;
    if (successPercentage <= 30) {
      progressColor = Colors.red;
    } else if (successPercentage < 70) {
      progressColor = Colors.yellow;
    } else {
      progressColor = Colors.green;
    }

    return Scaffold(
      backgroundColor: const Color(0xFF2E5A8C),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF2E5A8C), Color(0xFF1A3A5C)],
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
                // Üst Bilgi Satırı (her zaman üstte ve sabit)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.orange, width: 1),
                      ),
                      child: Text(
                        'Soru: ${(provider.currentQuestionIndex + 1).clamp(1, 10)} / 10',
                        style: const TextStyle(
                          color: Colors.orange,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Puan: %${successPercentage.toInt()}',
                        style: TextStyle(
                          color: progressColor,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.blueAccent, width: 1),
                      ),
                      child: Text(
                        'Seviye: ${provider.currentQuestion?.level ?? "-"}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                                const SizedBox(height: 12),
                  // Kaçıncı level test oturumu - Daha belirgin gösterge
                  if (!provider.duelUnlocked)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF6C27FF), Color(0xFF8E2DE2)],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF6C27FF).withOpacity(0.3),
                            blurRadius: 12,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.assignment_turned_in, color: Colors.amber, size: 20),
                          const SizedBox(width: 8),
                          const Text(
                            'Seviye Tespiti:',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Oturum ${provider.sessionsInRow} / 5',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (provider.duelUnlocked)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.13),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Seri: ${provider.levelStreak}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                TweenAnimationBuilder<double>(
                  duration: const Duration(milliseconds: 300),
                  tween: Tween(begin: 1.0, end: _timeLeft <= 3 ? 1.2 : 1.0),
                  builder: (context, scale, child) {
                    return Transform.scale(
                      scale: scale,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: _timeLeft <= 3 
                            ? Colors.red.withOpacity(0.2) 
                            : Colors.white.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: _timeLeft <= 3 
                            ? Border.all(color: Colors.red.withOpacity(0.5), width: 1)
                            : null,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Icon(
                              Icons.timer, 
                              color: _timeLeft <= 3 ? Colors.redAccent : Colors.amber, 
                              size: 18
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '$_timeLeft sn',
                              style: TextStyle(
                                color: _timeLeft <= 3 ? Colors.redAccent : Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                // ...existing code...
                
                // Puan/Başarı İlerleme Çubuğu (Dinamik Renkli)
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: successPercentage / 100,
                    backgroundColor: Colors.white.withOpacity(0.1),
                    valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                    minHeight: 12,
                  ),
                ),
                const SizedBox(height: 24),
                
                // Soru Kartı
                ShakeWidget(
                  key: _shakeKey,
                  child: QuestionCard(
                    prompt: provider.currentPrompt,
                  ),
                ),
                const SizedBox(height: 24),
                
                // Seçenekler
                Expanded(
                  child: OptionsGrid(
                    options: provider.currentOptions,
                    selectedIndex: _selectedIndex,
                    correctIndex: provider.currentCorrectIndex,
                    isLocked: _answered, // Geri bildirim için gerekli
                    showCorrect: _answered, // Doğru cevabı göster
                    onOptionSelected: _answered ? (_) {} : _answer,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _headerInfo(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 10, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 0.5),
        ),
      ],
    );
  }

  Widget _buildAnimatedProgressBar(PracticeProvider provider) {
    final progress = provider.correctInSession / 10.0; // 0-1 arası
    final percentage = (progress * 100).round();

    // Renk hesaplaması - yeni sistem
    Color progressColor;
    if (percentage <= 30) {
      progressColor = Colors.red;
    } else if (percentage <= 60) {
      progressColor = Colors.yellow;
    } else {
      progressColor = Colors.green;
    }

    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Container(
            height: 12,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: AnimatedFractionallySizedBox(
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeOutCubic,
              alignment: Alignment.centerRight,
              widthFactor: math.max(0.05, progress.clamp(0.0, 1.0)),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: progressColor.withValues(alpha: 0.8),
                  boxShadow: [
                    BoxShadow(
                      color: progressColor.withValues(alpha: 0.3),
                      blurRadius: 6,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '0%',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 10,
              ),
            ),
            Text(
              '%$percentage',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              '100%',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 10,
              ),
            ),
          ],
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
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
                    const SizedBox(width: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.timer, color: Colors.amber, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            '$_timeLeft sn',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 20),
              // Seviye Tespit İlerlemesi
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.flag, color: Colors.amber, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Seviye Tespiti: ${provider.sessionsInRow}/5',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
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

}
