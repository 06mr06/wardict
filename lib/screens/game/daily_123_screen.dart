import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/daily_123_provider.dart';
import '../../services/daily_123_service.dart';
import '../../models/daily_123.dart';
import '../../widgets/game/question_card.dart';
import '../../widgets/game/options_grid.dart';
import 'daily_123_results_screen.dart';

class Daily123Screen extends StatefulWidget {
  const Daily123Screen({super.key});

  @override
  State<Daily123Screen> createState() => _Daily123ScreenState();
}

class _Daily123ScreenState extends State<Daily123Screen> {
  bool _initialized = false;
  bool _showingResult = false;
  int? _selectedIndex;
  bool _locked = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      _initializeGame();
    }
  }
  
  Future<void> _initializeGame() async {
    final provider = context.read<Daily123Provider>();
    await provider.startSession();
    
    // Oyun zaten bittiyse direkt sonuç ekranına git
    if (provider.isGameOver && mounted) {
      _showingResult = true;
      _finishGame();
    }
  }

  void _onAnswer(int index) async {
    if (_locked) return;

    setState(() {
      _selectedIndex = index;
      _locked = true;
    });

    // Görsel geri bildirim için kısa bekleme (0.4 sn artırıldı)
    await Future.delayed(const Duration(milliseconds: 1000));

    if (!mounted) return;

    final provider = context.read<Daily123Provider>();
    await provider.answer(index, 0);

    if (provider.score >= 123 || provider.timeLeft <= 0) {
      if (!_showingResult) {
        _showingResult = true;
        _finishGame();
      }
    } else {
      setState(() {
        _selectedIndex = null;
        _locked = false;
      });
    }
  }

  Future<void> _finishGame() async {
    final provider = context.read<Daily123Provider>();
    final score = provider.score;
    final timeSpent = 123 - provider.timeLeft;
    final isWin = provider.isWin;
    final correctAnswers = provider.correctAnswers;
    final wrongAnswers = provider.wrongAnswers;

    // Record the game
    await Daily123Service.instance.recordGame(Daily123Result(
      date: DateTime.now(),
      score: score,
      timeSeconds: timeSpent,
      isWin: isWin,
    ));

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => Daily123ResultsScreen(
          finalScore: score,
          timeSpent: timeSpent,
          isWin: isWin,
          correctAnswers: correctAnswers,
          wrongAnswers: wrongAnswers,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<Daily123Provider>();
    
    // Auto-finish if time is up
    if (provider.timeLeft <= 0 && !_showingResult) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _finishGame());
    }

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
                        onOptionSelected: _onAnswer,
                        isLocked: _locked,
                        showCorrect: _locked,
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

  Widget _buildHeader(Daily123Provider provider) {
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
                    _headerInfo('DÜZEY', provider.currentLevel.code, Colors.orange),
                    _headerInfo('SÜRE', '${provider.timeLeft}s', Colors.redAccent),
                    _headerInfo('PUAN', '${provider.score}/123', Colors.greenAccent),
                  ],
                ),
              ),
              const SizedBox(width: 40), // Balance for back button
            ],
          ),
          const SizedBox(height: 20),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: provider.score / 123,
              minHeight: 12,
              backgroundColor: Colors.white12,
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF00F5A0)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _headerInfo(String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.w900)),
      ],
    );
  }
}
