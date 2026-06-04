import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/language_provider.dart';
import '../../models/user_level.dart';
import '../../services/word_pool_service.dart';
import '../../services/word_hint_service.dart';
import '../../models/practice_session.dart';
import '../../providers/practice_provider.dart';
import '../../widgets/game/question_card.dart';
import '../../models/question_mode.dart';
import '../../widgets/game/options_grid.dart';
import '../../widgets/game/lottie_answer_overlay.dart';
import 'practice_results_screen.dart';
import '../../services/sound_service.dart';
import '../../widgets/animations/shake_widget.dart';
import '../../utils/quest_points_helper.dart';

/// PlacementTestManager: 5x10 dinamik seviye yerleştirme testi akışı
class PlacementTestManager extends StatefulWidget {
  final void Function(String finalLevel, int correctCount) onTestComplete;
  const PlacementTestManager({super.key, required this.onTestComplete});

  @override
  State<PlacementTestManager> createState() => _PlacementTestManagerState();
}

class _PlacementTestManagerState extends State<PlacementTestManager> {
  static const int totalSessions = 3;
  static const int questionsPerSession = 10;
  String _currentLevel = 'B1';
  int _currentSession = 0;
  int _currentQuestion = 0;
  int _correctInSession = 0;
  bool _locked = false;
  int? _selectedIndex;
  Timer? _timer;
  final int _questionTime = 7;
  int _timeLeft = 7;
  bool _testFinished = false;
  List<List<Map<String, dynamic>>> _allQuestions = [];
  List<List<int>> _allAnswers = [];
  List<int> _sessionScores = [];
  bool _showAnswerAnimation = false;
  bool _answerIsCorrect = false;
  int _streak = 0;
  int _placementSessionPoints = 0;
  String? _wrongAnswerMeaning;
  final GlobalKey<ShakeWidgetState> _shakeKey = GlobalKey<ShakeWidgetState>();

  @override
  void initState() {
    super.initState();
    _allQuestions = [];
    _allAnswers = [];
    _sessionScores = [];
    _startNewSession(_currentLevel);
  }

  void _startNewSession(String level) {
    setState(() {
      _currentLevel = level;
      _currentQuestion = 0;
      _correctInSession = 0;
      _locked = false;
      _selectedIndex = null;
      _timeLeft = _questionTime;
      _placementSessionPoints = 0;
    });
    final questions = WordPoolService.instance
        .generateQuestions(UserLevel.fromCode(level))
        .map((q) => {
              'question': q.prompt,
              'options': q.options,
              'answer': q.options[q.correctIndex],
              'meaning': q.turkishMeaning,
              'mode': q.mode.index,
            })
        .toList();
    // Her oturumda tam 10 soru olsun (eksikse dummy ekle, fazlaysa kırp)
    while (questions.length < questionsPerSession) {
      questions.add({
        'question': 'Boş Soru',
        'options': ['-', '-', '-', '-'],
        'answer': '-',
      });
    }
    if (questions.length > questionsPerSession) {
      questions.removeRange(questionsPerSession, questions.length);
    }
    _allQuestions.add(questions);
    _allAnswers.add([]);
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timeLeft = _questionTime;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_timeLeft == 0) {
        _onTimeUp();
      } else {
        setState(() {
          _timeLeft--;
        });
      }
    });
  }

  void _onTimeUp() {
    _timer?.cancel();
    _answerQuestion(null);
  }

  bool _showSessionResult = false;
  int _lastSessionScore = 0;
  String _lastSessionLevel = '';
  void _answerQuestion(int? selectedIdx) {
    if (_locked) return;

    final rem = _timeLeft;
    final question = _allQuestions[_currentSession][_currentQuestion];
    final options = (question['options'] as List<String>? ?? []);
    final correctIndex = options.indexOf(question['answer']);
    bool isCorrect = selectedIdx != null && selectedIdx == correctIndex;

    setState(() {
      _locked = true;
      _selectedIndex = selectedIdx;
      _answerIsCorrect = isCorrect;
      _showAnswerAnimation = true;
      _wrongAnswerMeaning = null;

      if (isCorrect) {
        _correctInSession++;
        _streak++;
        _placementSessionPoints += duelStyleRoundPoints(
          remainingSeconds: rem,
          streakAfterCorrect: _streak,
        );
        debugPrint(
            '✅ Placement Correct: $_correctInSession/10. Answered: ${question['answer']}');
      } else {
        _streak = 0;
        HapticFeedback.heavyImpact();
        _shakeKey.currentState?.shake();

        // Kelimenin anlamını göster
        final meaning = question['meaning'] as String? ?? '';
        final mode = question['mode'] as int? ?? 0;
        // mode 0 = trToEn (Türkçe soru, İngilizce cevap), mode 1 = enToTr (İngilizce soru, Türkçe cevap)
        if (mode == 0) {
          // Türkçe soru soruldu, İngilizce cevap bekleniyor - anlam Türkçe
          _wrongAnswerMeaning = question['answer'];
        } else {
          // İngilizce soru soruldu, Türkçe cevap bekleniyor - anlam İngilizce
          _wrongAnswerMeaning = meaning;
        }

        debugPrint(
            '❌ Placement Wrong: Answered: ${selectedIdx != null ? options[selectedIdx] : "TIME UP"}, Correct: ${question['answer']}, Meaning: $_wrongAnswerMeaning');
      }
    });
    _allAnswers[_currentSession].add(selectedIdx ?? -1);
    Future.delayed(const Duration(milliseconds: 1200), () async {
      if (!mounted) return;

      setState(() {
        _currentQuestion++;
        _locked = false;
        _selectedIndex = null;
        _timeLeft = _questionTime;
        _showAnswerAnimation = false;
        _wrongAnswerMeaning = null;
      });

      if (_currentQuestion >= questionsPerSession) {
        // Oturum tamamlandı, skor ve seviye güncelle
        _sessionScores.add(_correctInSession);
        _lastSessionScore = _correctInSession;

        // Seviye güncelleme mantığı
        String nextLevel = _currentLevel;
        if (_correctInSession >= 7) {
          nextLevel = PracticeScoring.getNextLevel(_currentLevel);
        } else if (_correctInSession <= 3) {
          nextLevel = PracticeScoring.getPreviousLevel(_currentLevel);
        }

        // PracticeProvider'daki oturumu da sonlandır ki veriler kaydolsun
        final provider = context.read<PracticeProvider>();
        await provider.completeSession();

        setState(() {
          _lastSessionLevel = nextLevel;
          _showSessionResult = true;
          _currentLevel = nextLevel;
        });
      } else {
        _startTimer();
      }
    });
  }

  Widget _buildAnswerFeedback() {
    if (_answerIsCorrect) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.green.withAlpha(51),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.green, width: 2),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 32),
            SizedBox(width: 12),
            Text(
              'DOĞRU!',
              style: TextStyle(
                color: Colors.green,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.red.withAlpha(51),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.red, width: 2),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.cancel, color: Colors.red, size: 28),
                SizedBox(width: 8),
                Text(
                  'YANLIŞ',
                  style: TextStyle(
                    color: Colors.red,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            if (_wrongAnswerMeaning != null &&
                _wrongAnswerMeaning!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(26),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.translate,
                        color: Colors.white70, size: 18),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        _wrongAnswerMeaning!.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      );
    }
  }

  void _onContinueSession() {
    setState(() {
      _showSessionResult = false;
      _currentSession++;
      if (_currentSession >= totalSessions) {
        // Test tamamlandı, sonucu bildir
        _testFinished = true;
        widget.onTestComplete(
            _currentLevel, _sessionScores.fold(0, (a, b) => a + b));
      } else {
        _correctInSession = 0;
        _currentQuestion = 0;
        _startNewSession(_currentLevel);
      }
    });
  }

  void _showExitConfirmation() {
    // Tutorial sonrası pushReplacementNamed('/7030') ile yığında tek route kalabiliyor;
    // çift pop navigator'u boşaltıp beyaz ekran veriyor. Ana sayfaya güvenli dönüş:
    final navigator = Navigator.of(context);
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF1A3A5C),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          dialogContext.read<LanguageProvider>().getString('quit_practice_title'),
          style:
              const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          dialogContext.read<LanguageProvider>().getString('quit_practice_confirm'),
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(
              dialogContext.read<LanguageProvider>().getString('cancel'),
              style: const TextStyle(color: Colors.white60),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              navigator.pushNamedAndRemoveUntil('/home', (route) => false);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(
              dialogContext.read<LanguageProvider>().getString('confirm_quit'),
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_testFinished || _showSessionResult) {
      // Her oturum sonunda ve test sonunda practice modundaki sonuç ekranını göster
      return Column(
        children: [
          Expanded(
            child: SeventyThirtyResultsScreen(
              result: PracticeSessionResult(
                totalQuestions: questionsPerSession,
                correctAnswers: _lastSessionScore,
                sessionScore: _placementSessionPoints,
                leveledUp: false,
                leveledDown: false,
                newLevel: _lastSessionLevel,
                currentLevel: _lastSessionLevel,
                answerHistory: [], // Burada gerçek cevap geçmişi eklenmeli
                consecutiveHighSuccess: 0,
                consecutiveLowSuccess: 0,
                sessionsInRow: _currentSession + 1,
              ),
            ),
          ),
          if (_showSessionResult && !_testFinished)
            Padding(
              padding: const EdgeInsets.only(bottom: 32.0),
              child: ElevatedButton(
                onPressed: _onContinueSession,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4CAF50),
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                child: Text(
                    context
                        .read<LanguageProvider>()
                        .getString('continue_button'),
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ),
        ],
      );
    }
    if (_allQuestions.isEmpty || _allQuestions[_currentSession].isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    final question = _allQuestions[_currentSession][_currentQuestion];
    final options = (question['options'] as List<String>? ?? []);
    final correctIndex = options.indexOf(question['answer']);
    final double successPercentage =
        (_correctInSession / questionsPerSession) * 100;
    Color progressColor;
    if (successPercentage <= 30) {
      progressColor = Colors.red;
    } else if (successPercentage < 70) {
      progressColor = Colors.yellow;
    } else {
      progressColor = Colors.green;
    }
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1A1A2E), Color(0xFF16213E), Color(0xFF0F3460)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(builder: (context, constraints) {
            return SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            onPressed: _showExitConfirmation,
                            icon:
                                const Icon(Icons.close, color: Colors.white70),
                            tooltip: context
                                .read<LanguageProvider>()
                                .getString('close'),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF6C27FF).withAlpha(51),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: const Color(0xFF6C27FF), width: 1),
                            ),
                            child: Text(
                              '${context.watch<LanguageProvider>().getString('question')}: ${_currentQuestion + 1} / $questionsPerSession',
                              style: const TextStyle(
                                color: Color(0xFFB392FF),
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white.withAlpha(26),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '${context.watch<LanguageProvider>().getString('points')}: ${_correctInSession * 10}', // Her doğru cevap seviye tespiti sırasında da 10 puandır.
                              style: TextStyle(
                                color: progressColor,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF6C27FF), Color(0xFF8E2DE2)],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF6C27FF).withAlpha(77),
                              blurRadius: 12,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.assignment_turned_in,
                                color: Colors.amber, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              '${context.watch<LanguageProvider>().getString('level_test_title')}:',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white.withAlpha(51),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${context.watch<LanguageProvider>().getString('session')} ${_currentSession + 1} / $totalSessions',
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
                      Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(20),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            const Icon(Icons.timer,
                                color: Colors.amber, size: 18),
                            const SizedBox(width: 4),
                            Text(
                              '$_timeLeft sn',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      const SizedBox(height: 20),
                      ShakeWidget(
                        key: _shakeKey,
                        child: QuestionCard(
                          prompt: question['question'] ?? 'No question',
                          streak: _streak,
                        ),
                      ),
                      const SizedBox(height: 24),
                      OptionsGrid(
                        options: options,
                        selectedIndex: _selectedIndex,
                        correctIndex: correctIndex,
                        isLocked: _locked,
                        showCorrect: _locked,
                        onOptionSelected: (selectedIdx) {
                          if (_locked) return;
                          _timer?.cancel();
                          _answerQuestion(selectedIdx);
                        },
                        eliminatedOptions: const {},
                      ),
                      const SizedBox(height: 16),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        height: _showAnswerAnimation ? 100 : 0,
                        child: _showAnswerAnimation
                            ? _buildAnswerFeedback()
                            : const SizedBox.shrink(),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

class SeventyThirtyScreen extends StatefulWidget {
  const SeventyThirtyScreen({super.key});

  @override
  State<SeventyThirtyScreen> createState() => _SeventyThirtyScreenState();
}

class _SeventyThirtyScreenState extends State<SeventyThirtyScreen>
    with TickerProviderStateMixin {
  // Eksik değişken tanımları
  late AnimationController _waveController;
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;
  bool _isLoading = true;
  bool _showCountdown = false; // Direkt başla
  bool _showPreScreen = false; // Direkt başla
  Timer? _timer;
  int _timeLeft = 7;
  bool _answered = false;
  int _earnedPoint = 0;
  int? _selectedIndex;
  int _countdown = 3;
  bool _isNavigating = false;
  bool _showAnswerAnimation = false;
  bool _answerIsCorrect = false;
  final GlobalKey<ShakeWidgetState> _shakeKey = GlobalKey<ShakeWidgetState>();

  @override
  void initState() {
    super.initState();
    _initAnimation();
    _waveController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2000))
      ..repeat();
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

    if (!mounted) return;
    if (practiceProvider.isSessionComplete) {
      // Önceki kapatılan oturum / bozuk profil: profilde 10/10 cevap kaldıysa
      // sonuç ekranına geç, yoksa yükleyici.
      setState(() => _isLoading = false);
      await _showResults();
      return;
    }
    if (practiceProvider.currentQuestion == null) {
      setState(() => _isLoading = false);
      debugPrint(
          '⚠️ [7030] startSession left currentQuestion == null, going home');
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!context.mounted) return;
          Navigator.of(context)
              .pushNamedAndRemoveUntil('/home', (route) => false);
        });
      }
      return;
    }
    if (mounted) {
      setState(() => _isLoading = false);
      _runCountdown();
    }
  }

  void _runCountdown() {
    if (!mounted) return;
    // İlk seviye testindeki ekstra 3-2-1 ekranını kaldır.
    setState(() {
      _showCountdown = false;
      _showPreScreen = false;
    });
    _startTimer();
  }

  void _startCountdownSequence() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_countdown > 1) {
        setState(() => _countdown--);
      } else {
        t.cancel();
        setState(() {
          _showCountdown = false;
          _showPreScreen = false;
        });
        _startTimer();
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
      }
    });
  }

  Future<void> _onTimeUp() async {
    if (_answered) return;
    setState(() {
      _answered = true;
      _earnedPoint = 0;
    });
    final practiceProvider = context.read<PracticeProvider>();
    await practiceProvider.answer(-1, 0);
    Future.delayed(const Duration(milliseconds: 1200), _nextQuestion);
  }

  Future<void> _answer(int index) async {
    if (_answered || _timeLeft == 0) return;
    _timer?.cancel();

    final practiceProvider = context.read<PracticeProvider>();

    setState(() {
      _selectedIndex = index;
      _answered = true;
    });

    await practiceProvider.answer(index, _timeLeft);

    // Debug toast format feedback
    if (!mounted) return;
    final isCorrect =
        (practiceProvider.answerHistory.lastOrNull?.isCorrect ?? false);

    setState(() {
      _answerIsCorrect = isCorrect;
      _showAnswerAnimation = true;
    });

    // Kazanılan puanı göster
    if (practiceProvider.answerHistory.isNotEmpty) {
      final lastAnswer = practiceProvider.answerHistory.last;
      _earnedPoint = lastAnswer.points;

      if (_earnedPoint > 0) {
        SoundService.instance.playCorrect();
      } else {
        SoundService.instance.playWrong();
      }
    }

    if (_earnedPoint > 0) {
      _animController.forward(from: 0);
      HapticFeedback.lightImpact();
    } else {
      HapticFeedback.heavyImpact();
      _shakeKey.currentState?.shake();
    }

    Future.delayed(const Duration(milliseconds: 1500), _nextQuestion);
  }

  void _nextQuestion() {
    if (!mounted || _isNavigating) return;
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
      _showPreScreen = false; // Direkt geçiş
      _showCountdown = false;
      _countdown = 3;
    });
    _runCountdown();
  }

  Future<void> _showResults() async {
    if (_isNavigating) return;
    setState(() => _isNavigating = true);

    final practiceProvider = context.read<PracticeProvider>();

    try {
      final result = await practiceProvider.completeSession();

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => SeventyThirtyResultsScreen(result: result),
          ),
        );
      }
    } catch (e) {
      debugPrint("Sonuç ekranına geçiş hatası: $e");
      // Hata olsa bile kullanıcıyı ana sayfaya yönlendir veya tekrar dene
      if (mounted) setState(() => _isNavigating = false);
    }
  }

  void _showExitConfirmation() {
    // Tutorial sonrası pushReplacementNamed('/7030') ile yığında tek route kalabiliyor;
    // çift pop navigator'u boşaltıp beyaz ekran veriyor. Ana sayfaya güvenli dönüş:
    final navigator = Navigator.of(context);
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF1A3A5C),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          dialogContext.read<LanguageProvider>().getString('quit_practice_title'),
          style:
              const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          dialogContext.read<LanguageProvider>().getString('quit_practice_confirm'),
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(
              dialogContext.read<LanguageProvider>().getString('cancel'),
              style: const TextStyle(color: Colors.white60),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              navigator.pushNamedAndRemoveUntil('/home', (route) => false);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(
              dialogContext.read<LanguageProvider>().getString('confirm_quit'),
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
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
    return Consumer<PracticeProvider>(
      builder: (context, provider, child) {
        if (provider.currentQuestion == null) {
          return const Scaffold(
            backgroundColor: Color(0xFF2E5A8C),
            body: Center(child: CircularProgressIndicator(color: Colors.white)),
          );
        }

        if (_showPreScreen) {
          return _buildPreScreen(provider);
        }

        return _buildPracticeGameScreen(provider);
      },
    );
  }

  Widget _buildPracticeGameScreen(PracticeProvider provider) {
    // İlerleme rengi: doğru/10 soru (%70 = yeşil eşiği)
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
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF2E5A8C), Color(0xFF1A3A5C)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: SafeArea(
              child: LayoutBuilder(builder: (context, constraints) {
                return SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  child: ConstrainedBox(
                    constraints:
                        BoxConstraints(minHeight: constraints.maxHeight),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Üst Bilgi Satırı
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              IconButton(
                                onPressed: _showExitConfirmation,
                                icon: const Icon(Icons.close,
                                    color: Colors.white70),
                                tooltip: context
                                    .read<LanguageProvider>()
                                    .getString('close'),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withAlpha(51),
                                  borderRadius: BorderRadius.circular(20),
                                  border:
                                      Border.all(color: Colors.blue, width: 1),
                                ),
                                child: Text(
                                  '${context.watch<LanguageProvider>().getString('level')}: ${provider.currentLevel}',
                                  style: const TextStyle(
                                    color: Colors.blueAccent,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.white.withAlpha(26),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  '${context.watch<LanguageProvider>().getString('points')}: ${provider.sessionScore}',
                                  style: TextStyle(
                                    color: progressColor,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withAlpha(51),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                      color: Colors.orange, width: 1),
                                ),
                                child: Text(
                                  '${context.watch<LanguageProvider>().getString('question')}: ${(provider.currentQuestionIndex + 1).clamp(1, 10)} / 10',
                                  style: const TextStyle(
                                    color: Colors.orange,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          if (!provider.duelUnlocked)
                            Container(
                              width: double.infinity,
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 10),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF6C27FF),
                                    Color(0xFF8E2DE2)
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color:
                                        const Color(0xFF6C27FF).withAlpha(77),
                                    blurRadius: 12,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.assignment_turned_in,
                                      color: Colors.amber, size: 20),
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
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withAlpha(51),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      'Oturum ${provider.sessionsInRow + 1} / 3',
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
                          const SizedBox(height: 8),

                          Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withAlpha(20),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                const Icon(Icons.timer,
                                    color: Colors.amber, size: 18),
                                const SizedBox(width: 4),
                                Text(
                                  '$_timeLeft ${context.watch<LanguageProvider>().getString('seconds_short')}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          _buildAnimatedProgressBar(provider),
                          const SizedBox(height: 12),
                          const SizedBox(height: 20),
                          ShakeWidget(
                            key: _shakeKey,
                            child: QuestionCard(
                              prompt: provider.currentQuestion?.prompt ?? '',
                              hint: provider.currentQuestion != null
                                  ? WordHintService.instance.getHint(provider
                                              .currentMode ==
                                          QuestionMode.enToTr
                                      ? provider.currentQuestion!.prompt
                                      : provider.currentQuestion!.correctAnswer)
                                  : null,
                              streak: provider.levelStreak,
                            ),
                          ),
                          const SizedBox(height: 24),
                          OptionsGrid(
                            options: provider.currentOptions,
                            optionMeanings: provider.currentOptionMeanings,
                            selectedIndex: _selectedIndex,
                            correctIndex: provider.currentCorrectIndex,
                            isLocked: _answered,
                            showCorrect: _answered,
                            onOptionSelected: (index) => _answer(index),
                            eliminatedOptions: const {},
                          ),
                          const SizedBox(height: 24),
                          // Yanıt animasyonu yeri (Şıkların alt kısmında)
                          SizedBox(
                            width: 140,
                            height: 140,
                            child: _showAnswerAnimation
                                ? LottieAnswerOverlay(
                                    isCorrect: _answerIsCorrect,
                                    onComplete: () {
                                      if (mounted) {
                                        setState(
                                            () => _showAnswerAnimation = false);
                                      }
                                    },
                                  )
                                : const SizedBox.shrink(),
                          ),
                          const SizedBox(height: 30),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),
                );
              }),
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
          style: TextStyle(
              color: Colors.white.withAlpha(128),
              fontSize: 10,
              fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5),
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
          borderRadius: BorderRadius.circular(12),
          child: Container(
            height: 18, // Taller bar
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(26),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withAlpha(51), width: 1),
            ),
            child: AnimatedFractionallySizedBox(
              duration: const Duration(milliseconds: 1000), // Smoother
              curve: Curves.elasticOut,
              alignment: Alignment.centerLeft,
              widthFactor: math.max(0.05, progress.clamp(0.0, 1.0)),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: LinearGradient(
                    colors: [
                      progressColor.withAlpha(255),
                      progressColor.withAlpha(180),
                    ],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: progressColor.withAlpha(150),
                      blurRadius: 12,
                      spreadRadius: 2,
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
                color: Colors.white.withAlpha(153),
                fontSize: 10,
              ),
            ),
            Text(
              context.watch<LanguageProvider>().currentLanguage == 'tr'
                  ? '%$percentage'
                  : '$percentage%',
              style: TextStyle(
                color: Colors.white.withAlpha(230),
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              '100%',
              style: TextStyle(
                color: Colors.white.withAlpha(153),
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
                  Colors.black.withAlpha(128),
                  Colors.black.withAlpha(179),
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
                // Kapatma butonu, Seviye ve soru numarası
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      onPressed: _showExitConfirmation,
                      icon: const Icon(Icons.close, color: Colors.white70),
                      tooltip:
                          context.read<LanguageProvider>().getString('close'),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFF9800), Color(0xFFFF5722)],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFF9800).withAlpha(102),
                            blurRadius: 20,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.school,
                              color: Colors.white, size: 22),
                          const SizedBox(width: 8),
                          Text(
                            '${context.watch<LanguageProvider>().getString('level')}: ${provider.currentLevel}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.white.withAlpha(51),
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
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(38),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withAlpha(51)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.timer,
                              color: Colors.amber, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            '$_timeLeft ${context.watch<LanguageProvider>().getString('seconds_short')}',
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(38),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withAlpha(51)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.flag, color: Colors.amber, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        '${context.watch<LanguageProvider>().getString('level_test_title')}: ${provider.sessionsInRow}/3',
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
                                  ? [
                                      Colors.green.shade400,
                                      Colors.green.shade700
                                    ]
                                  : _countdown == 2
                                      ? [
                                          Colors.orange.shade400,
                                          Colors.orange.shade700
                                        ]
                                      : [
                                          Colors.red.shade400,
                                          Colors.red.shade700
                                        ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: (_countdown == 1
                                        ? Colors.green
                                        : _countdown == 2
                                            ? Colors.orange
                                            : Colors.red)
                                    .withAlpha(128),
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
        ],
      ),
    );
  }
}
