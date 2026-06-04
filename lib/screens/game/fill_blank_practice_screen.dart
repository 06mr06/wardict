import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../app.dart';
import '../../providers/fill_blank_practice_provider.dart';
import '../../providers/language_provider.dart';
import '../../models/powerup.dart';
import '../../services/shop_service.dart';
import '../../services/sound_service.dart';
import '../../services/quest_service.dart';
import '../../models/quest.dart';
import 'fill_blank_results_screen.dart';
import '../../widgets/game/lottie_answer_overlay.dart';

class FillBlankPracticeScreen extends StatefulWidget {
  final String userLevelCode;

  const FillBlankPracticeScreen({super.key, required this.userLevelCode});

  @override
  State<FillBlankPracticeScreen> createState() =>
      _FillBlankPracticeScreenState();
}

class _FillBlankPracticeScreenState extends State<FillBlankPracticeScreen> {
  Timer? _timer;
  int _timeLeft = 10;
  bool _answered = false;
  int? _selectedIndex;
  bool _freezeActive = false;
  bool _doubleChanceActive = false;
  final Set<int> _eliminatedOptions = {};
  final Set<PowerupType> _usedPowerupsInQuestion = {};
  PowerupInventory _inventory = const PowerupInventory();
  bool _loading = true;
  bool _showAnswerAnimation = false;
  bool _answerIsCorrect = false;
  bool _isNavigating = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final inv = await ShopService.instance.getInventory();
    if (!mounted) return;
    setState(() => _inventory = inv);
    await context.read<FillBlankPracticeProvider>().startSession(widget.userLevelCode);
    if (!mounted) return;
    setState(() => _loading = false);
    _startTimer();
  }

  void _resetRoundPowerups() {
    _freezeActive = false;
    _doubleChanceActive = false;
    _eliminatedOptions.clear();
    _usedPowerupsInQuestion.clear();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    _resetRoundPowerups();
    _timeLeft = 10;
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_answered || _freezeActive) return;
      if (_timeLeft <= 0) {
        t.cancel();
        _onTimeUp();
      } else {
        setState(() => _timeLeft--);
        if (_timeLeft <= 0) {
          t.cancel();
          _onTimeUp();
        }
      }
    });
  }

  Future<void> _onTimeUp() async {
    if (_answered) return;
    final p = context.read<FillBlankPracticeProvider>();
    setState(() {
      _answered = true;
      _answerIsCorrect = false;
      _showAnswerAnimation = true;
    });
    await p.answerQuestion(-1, 0);
    if (!mounted) return;
    SoundService.instance.playWrong();
    HapticFeedback.heavyImpact();
    Future.delayed(const Duration(milliseconds: 1500), _goNext);
    _scheduleGoNextFallback();
  }

  Future<void> _commitAnswer(int index) async {
    final p = context.read<FillBlankPracticeProvider>();
    final q = p.current;
    if (q == null) return;

    setState(() {
      _selectedIndex = index;
      _answered = true;
    });
    _timer?.cancel();

    await p.answerQuestion(index, _timeLeft);
    if (!mounted) return;
    final ok = p.history.isNotEmpty && p.history.last.isCorrect;
    setState(() {
      _answerIsCorrect = ok;
      _showAnswerAnimation = true;
    });
    if (ok) {
      SoundService.instance.playCorrect();
      HapticFeedback.lightImpact();
    } else {
      SoundService.instance.playWrong();
      HapticFeedback.heavyImpact();
    }
    Future.delayed(const Duration(milliseconds: 1500), _goNext);
    _scheduleGoNextFallback();
  }

  /// Web tarayıcıları arka planda Timer/Future geciktirebilir; yedek tetikleyici.
  void _scheduleGoNextFallback() {
    Future.delayed(const Duration(milliseconds: 3200), () {
      if (!mounted || _isNavigating || !_answered) return;
      final p = context.read<FillBlankPracticeProvider>();
      if (p.questions.isEmpty) return;
      final sessionDone =
          p.history.length >= p.questions.length ||
          p.index >= p.questions.length - 1;
      if (sessionDone) _goNext();
    });
  }

  Future<void> _onOption(int index) async {
    if (_answered || _isNavigating) return;
    final p = context.read<FillBlankPracticeProvider>();
    final q = p.current;
    if (q == null) return;

    if (_doubleChanceActive &&
        index != q.correctIndex &&
        !_eliminatedOptions.contains(index)) {
      setState(() {
        _doubleChanceActive = false;
        _eliminatedOptions.add(index);
        _selectedIndex = null;
      });
      final lang = context.read<LanguageProvider>();
      _snack(lang.getString('fill_blank_powerup_double_retry'));
      SoundService.instance.playWrong();
      return;
    }

    await _commitAnswer(index);
  }

  void _snack(String m) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(content: Text(m), behavior: SnackBarBehavior.floating),
    );
  }

  bool _isPowerupBlocked(PowerupType type) {
    if (_answered) return true;
    return false;
  }

  Future<void> _usePowerup(PowerupType type) async {
    if (_isPowerupBlocked(type)) return;
    if (_inventory.getCount(type) <= 0) return;
    final ok = await ShopService.instance.usePowerup(type);
    if (!ok || !mounted) return;
    QuestService.instance.updateProgress(QuestType.usePowerup, 1);
    setState(() {
      _usedPowerupsInQuestion.add(type);
      _inventory = _inventory.use(type);
    });

    final lang = context.read<LanguageProvider>();
    final p = context.read<FillBlankPracticeProvider>();
    final q = p.current;
    if (q == null) return;

    switch (type) {
      case PowerupType.revealAnswer:
        _snack(lang.getString('fill_blank_powerup_reveal'));
        await _commitAnswer(q.correctIndex);
        break;
      case PowerupType.fiftyFifty:
        final wrong = <int>[];
        for (var i = 0; i < q.options.length; i++) {
          if (i != q.correctIndex) wrong.add(i);
        }
        wrong.shuffle();
        setState(() {
          if (wrong.isNotEmpty) _eliminatedOptions.add(wrong[0]);
          if (wrong.length > 1) _eliminatedOptions.add(wrong[1]);
        });
        _snack(lang.getString('fill_blank_powerup_fifty'));
        break;
      case PowerupType.doubleChance:
        setState(() => _doubleChanceActive = true);
        _snack(lang.getString('fill_blank_powerup_double'));
        break;
      case PowerupType.freezeTime:
        setState(() {
          _freezeActive = true;
          _timeLeft += 5;
        });
        _snack(lang.getString('fill_blank_powerup_freeze'));
        break;
      default:
        break;
    }
  }

  void _goNext() {
    if (!mounted || _isNavigating) return;
    final p = context.read<FillBlankPracticeProvider>();
    if (p.questions.isEmpty) return;

    final sessionDone =
        p.history.length >= p.questions.length ||
        p.index >= p.questions.length - 1;
    if (sessionDone) {
      _showResults(p);
      return;
    }

    p.nextQuestion();
    setState(() {
      _answered = false;
      _selectedIndex = null;
      _showAnswerAnimation = false;
    });
    _startTimer();
  }

  void _showResults(FillBlankPracticeProvider p) {
    if (_isNavigating || !mounted) return;
    setState(() => _isNavigating = true);

    final total = p.history.length;
    final pts = p.sessionPoints;
    final rec = List<FillBlankAnswerRecord>.from(p.history);

    try {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => FillBlankResultsScreen(
            totalQuestions: total,
            sessionPoints: pts,
            records: rec,
            userLevelCode: widget.userLevelCode,
          ),
        ),
      );
    } catch (e) {
      debugPrint('Fill blank results navigation error: $e');
      if (mounted) setState(() => _isNavigating = false);
      navigatorKey.currentState?.pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => FillBlankResultsScreen(
            totalQuestions: total,
            sessionPoints: pts,
            records: rec,
            userLevelCode: widget.userLevelCode,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    if (_loading) {
      return const Scaffold(
        backgroundColor: Color(0xFF2E5A8C),
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    final p = context.watch<FillBlankPracticeProvider>();
    final q = p.current;
    if (q == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF2E5A8C),
        body: Center(
          child: _isNavigating
              ? const CircularProgressIndicator(color: Colors.white)
              : Text(lang.getString('fill_blank_no_data')),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF2E5A8C),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2E5A8C),
        foregroundColor: Colors.white,
        title: Text(lang.getString('practice_fill_blank_header')),
      ),
      body: SafeArea(
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${lang.getString('question')}: ${p.index + 1}/${p.questions.length}',
                          style: const TextStyle(color: Colors.white70),
                        ),
                        Text(
                          '$_timeLeft ${lang.getString('seconds_short')}',
                          style: const TextStyle(
                              color: Colors.amber,
                              fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${lang.getString('points')}: ${p.sessionPoints}',
                      textAlign: TextAlign.end,
                      style: const TextStyle(
                          color: Colors.amberAccent,
                          fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 12),
                    if (!_answered) _buildPowerupRow(lang),
                    const SizedBox(height: 12),
                    Expanded(
                      child: SingleChildScrollView(
                        physics: _showAnswerAnimation
                            ? const NeverScrollableScrollPhysics()
                            : const BouncingScrollPhysics(),
                        padding: EdgeInsets.only(
                          bottom: _showAnswerAnimation ? 160 : 0,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: const Color(0xFF26C6DA),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Text(
                                q.sentenceDisplay,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  height: 1.3,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            ...List.generate(q.options.length, (i) {
                              if (_eliminatedOptions.contains(i)) {
                                return const SizedBox.shrink();
                              }
                              final sel = _selectedIndex == i;
                              final show = _answered;
                              final correct = i == q.correctIndex;
                              Color bg = Colors.white.withAlpha(31);
                              Color? borderColor;
                              double borderW = 0;
                              if (show) {
                                if (correct) {
                                  bg = Colors.green.withAlpha(51);
                                  borderColor = Colors.green;
                                  borderW = 2;
                                } else if (sel) {
                                  bg = Colors.red.withAlpha(51);
                                  borderColor = Colors.red;
                                  borderW = 2;
                                }
                              }
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Material(
                                  color: bg,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    side: borderW > 0 && borderColor != null
                                        ? BorderSide(
                                            color: borderColor, width: borderW)
                                        : BorderSide.none,
                                  ),
                                  child: GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onTap: _answered || _isNavigating
                                        ? null
                                        : () {
                                            SoundService.instance.playClick();
                                            _onOption(i);
                                          },
                                    child: Padding(
                                      padding: const EdgeInsets.all(14),
                                      child: Row(
                                        children: [
                                          if (show && correct)
                                            const Icon(Icons.check_circle,
                                                color: Colors.green, size: 22),
                                          if (show && !correct && sel)
                                            const Icon(Icons.cancel,
                                                color: Colors.red, size: 22),
                                          if (show && (correct || sel))
                                            const SizedBox(width: 10),
                                          Expanded(
                                            child: Text(
                                              q.options[i],
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 16,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_showAnswerAnimation)
              Positioned(
                left: 0,
                right: 0,
                bottom: 8,
                child: IgnorePointer(
                  child: SizedBox(
                    height: 140,
                    child: Align(
                      alignment: Alignment.center,
                      child: SizedBox(
                        width: 140,
                        height: 140,
                        child: LottieAnswerOverlay(
                          isCorrect: _answerIsCorrect,
                          onComplete: () {
                            if (mounted) {
                              setState(() =>
                                  _showAnswerAnimation = false);
                            }
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPowerupRow(LanguageProvider lang) {
    final types = [
      PowerupType.revealAnswer,
      PowerupType.fiftyFifty,
      PowerupType.doubleChance,
      PowerupType.freezeTime,
    ];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: types.map((type) {
        final n = _inventory.getCount(type);
        final used = _usedPowerupsInQuestion.contains(type);
        final can = n > 0 && !used && !_answered;
        return Opacity(
          opacity: can ? 1 : 0.45,
          child: InkWell(
            onTap: can ? () => _usePowerup(type) : null,
            child: Column(
              children: [
                Text(type.emoji, style: const TextStyle(fontSize: 22)),
                Text('x$n', style: const TextStyle(color: Colors.white70, fontSize: 10)),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
