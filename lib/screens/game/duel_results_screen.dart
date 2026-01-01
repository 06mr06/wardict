import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../providers/game_provider.dart';
import '../../models/answered_entry.dart';
import '../../models/question_mode.dart';
import '../../models/league.dart';
import '../../widgets/common/top_toast.dart';
import '../../widgets/game/game_confetti.dart';
import '../../widgets/game/achievement_celebration.dart';
import 'package:confetti/confetti.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/achievement_service.dart';
import '../../models/achievement.dart';
import '../../services/user_profile_service.dart';

class DuelResultsScreen extends StatefulWidget {
  final int userScore;
  final int botScore;
  final List<AnsweredEntry> items;
  final League? league;
  final int eloChange;
  
  const DuelResultsScreen({
    super.key, 
    required this.userScore, 
    required this.botScore, 
    required this.items,
    this.league,
    this.eloChange = 0,
  });

  @override
  State<DuelResultsScreen> createState() => _DuelResultsScreenState();
}

class _DuelResultsScreenState extends State<DuelResultsScreen> {
  final Set<int> _selectedIndices = {};

  int get userScore => widget.userScore;
  int get botScore => widget.botScore;
  List<AnsweredEntry> get items => widget.items;
  League? get league => widget.league;
  int get eloChange => widget.eloChange;

  bool get allSelected => _selectedIndices.length == items.length && items.isNotEmpty;

  late ConfettiController _confettiController;
  DateTime? _gameStartTime;

  @override
  void initState() {
    super.initState();
    _gameStartTime = DateTime.now().subtract(const Duration(minutes: 5)); // Oyun başlangıç tahmini
    _confettiController = ConfettiController(duration: const Duration(seconds: 3));
    
    // Play confetti if win
    if (widget.userScore > widget.botScore) {
       Future.delayed(const Duration(milliseconds: 500), () => _confettiController.play());
       _handleDuelWinAchievements();
    } else {
       _resetDuelStreak();
    }

    // Başlangıçta GameProvider'dan kaydedilmiş olanları kontrol et
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final gp = context.read<GameProvider>();
      for (int i = 0; i < items.length; i++) {
        if (gp.isSaved(items[i])) {
          _selectedIndices.add(i);
        }
      }
      setState(() {});
      
      // Yeni kazanılan ödülleri kontrol et ve kutla
      _checkAndShowNewAchievements();
    });
  }
  
  Future<void> _checkAndShowNewAchievements() async {
    await Future.delayed(const Duration(milliseconds: 1500)); // Confetti bittikten sonra
    if (!mounted) return;
    
    final newAchievements = await AchievementService.instance.getNewlyUnlockedAchievements();
    if (newAchievements.isNotEmpty && mounted) {
      AchievementCelebration.showNewAchievements(context, newAchievements);
    }
  }
  
  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  Future<void> _handleDuelWinAchievements() async {
    // Toplam galibiyet başarımı (Warrior)
    await AchievementService.instance.updateProgress(AchievementCategory.career, 1);
    
    // Galibiyet serisi takibi (Yenilmez)
    final prefs = await SharedPreferences.getInstance();
    int currentStreak = (prefs.getInt('duel_win_streak') ?? 0) + 1;
    await prefs.setInt('duel_win_streak', currentStreak);
    
    if (currentStreak >= 5) {
      await AchievementService.instance.updateAchievementProgressById('duel_streak_5', 5, setExact: true);
    }
    
    // Sosyal etkileşim başarımı (Zaten düello yapıldı)
    await AchievementService.instance.updateProgress(AchievementCategory.social, 1);
  }

  Future<void> _resetDuelStreak() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('duel_win_streak', 0);
  }

  void _toggleItem(int index) {
    final gp = context.read<GameProvider>();
    final item = items[index];
    
    setState(() {
      if (_selectedIndices.contains(index)) {
        _selectedIndices.remove(index);
        gp.removeFromPool(item);
      } else {
        _selectedIndices.add(index);
        gp.addToPool(item);
      }
    });
  }

  void _toggleAll() {
    final gp = context.read<GameProvider>();
    
    setState(() {
      if (allSelected) {
        // Tümünü kaldır
        for (int i = 0; i < items.length; i++) {
          gp.removeFromPool(items[i]);
        }
        _selectedIndices.clear();
        showTopToast(context, 'Tüm kelimeler havuzdan çıkarıldı', isError: true);
      } else {
        // Tümünü seç
        for (int i = 0; i < items.length; i++) {
          if (!_selectedIndices.contains(i)) {
            gp.addToPool(items[i]);
            _selectedIndices.add(i);
          }
        }
        showTopToast(context, '${items.length} kelime havuza eklendi');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isWin = userScore > botScore;
    final isDraw = userScore == botScore;
    return Scaffold(
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
              child: Padding(
                padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _vibrantScoreboard(userScore, botScore),
                const SizedBox(height: 12),
                // Elo Change Display with League Icon
                if (league != null && eloChange != 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: eloChange > 0 
                          ? Colors.green.withOpacity(0.2)
                          : Colors.red.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: eloChange > 0 ? Colors.green : Colors.red,
                        width: 1,
                      ),
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _leagueIcon(league!),
                          const SizedBox(width: 8),
                          Icon(
                            eloChange > 0 ? Icons.arrow_upward : Icons.arrow_downward,
                            color: eloChange > 0 ? Colors.green : Colors.red,
                            size: 18,
                          ),
                          Text(
                            '${eloChange > 0 ? '+' : ''}$eloChange',
                            style: TextStyle(
                              color: eloChange > 0 ? Colors.green : Colors.red,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                // Result Banner
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isDraw
                          ? [Colors.purple.shade400, Colors.purple.shade600]
                          : isWin
                              ? [Colors.green.shade400, Colors.green.shade600]
                              : [Colors.red.shade400, Colors.red.shade600],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: (isDraw ? Colors.purple : isWin ? Colors.green : Colors.red).withOpacity(0.5),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Text(
                    isDraw ? '🤝 Berabere!' : (isWin ? '🏆 Kazandın!' : '😢 Kaybettin'),
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white),
                  ),
                ),
                const SizedBox(height: 12),
                // Tümünü Seç / Tümünü Kaldır header
                if (items.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Kelimeler',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        GestureDetector(
                          onTap: _toggleAll,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: allSelected 
                                  ? Colors.orange.withOpacity(0.3)
                                  : const Color(0xFF6C27FF).withOpacity(0.3),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: allSelected ? Colors.orange : const Color(0xFF6C27FF),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  allSelected ? Icons.remove_circle : Icons.add_circle,
                                  color: allSelected ? Colors.orange : const Color(0xFF6C27FF),
                                  size: 16,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  allSelected ? 'Tümünü Kaldır' : 'Tümünü Seç',
                                  style: TextStyle(
                                    color: allSelected ? Colors.orange : const Color(0xFF6C27FF),
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 8),
                Expanded(
                  child: items.isEmpty
                      ? const Center(child: Text('Kayıt bulunamadı', style: TextStyle(color: Colors.white70)))
                      : ListView.separated(
                          itemCount: items.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, i) {
                            final e = items[i];
                            final isCorrect = e.selectedIndex == e.correctIndex && e.selectedIndex != -1;
                            final isSaved = _selectedIndices.contains(i);
                            final op = _modeOperator(e.mode);
                            final answerLine = '$op ${e.correctText}';
                            return GestureDetector(
                              onTap: () => _toggleItem(i),
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: isSaved 
                                        ? [Colors.green.withOpacity(0.2), Colors.green.withOpacity(0.1)]
                                        : [Colors.white.withOpacity(0.1), Colors.white.withOpacity(0.05)],
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isSaved 
                                        ? Colors.green.withOpacity(0.5)
                                        : Colors.white.withOpacity(0.2),
                                    width: isSaved ? 2 : 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    // Checkbox style indicator
                                    Container(
                                      width: 24,
                                      height: 24,
                                      decoration: BoxDecoration(
                                        color: isSaved ? Colors.green : Colors.transparent,
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: isSaved ? Colors.green : Colors.white54,
                                          width: 2,
                                        ),
                                      ),
                                      child: isSaved 
                                          ? const Icon(Icons.check, color: Colors.white, size: 16)
                                          : null,
                                    ),
                                    const SizedBox(width: 12),
                                    // Mode badge
                                    _modeBadgeWidget(e.mode),
                                    const SizedBox(width: 8),
                                    // Content
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            _modeLabel(e.mode),
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                              color: Colors.white70,
                                              fontSize: 12,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '${e.prompt} $answerLine',
                                            style: const TextStyle(fontSize: 14, color: Colors.white),
                                          ),
                                        ],
                                      ),
                                    ),
                                    // Powerups
                                    if (e.usedPowerups.isNotEmpty) ...[
                                      const SizedBox(width: 8),
                                      Row(
                                          children: e.usedPowerups.map((p) => Padding(
                                              padding: const EdgeInsets.only(right: 4),
                                              child: Text(p.emoji, style: const TextStyle(fontSize: 16))
                                          )).toList(),
                                      ),
                                    ],
                                    // Points
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: isCorrect
                                              ? [Colors.green.shade400, Colors.green.shade600]
                                              : [Colors.red.shade400, Colors.red.shade600],
                                        ),
                                        borderRadius: BorderRadius.circular(999),
                                      ),
                                      child: Text(
                                        '+${e.earnedPoints}',
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6C27FF),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
                          child: const Text('Ana Sayfa', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2AA7FF),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        onPressed: () => _shareResult(context),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.share, size: 20),
                            SizedBox(width: 6),
                            Text('Paylaş', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      GameConfetti(controller: _confettiController),
        ],
      ),
    );
  }

  Widget _leagueIcon(League league) {
    switch (league) {
      case League.beginner:
        return const Text('🌱', style: TextStyle(fontSize: 20));
      case League.intermediate:
        return const Text('⚡', style: TextStyle(fontSize: 20));
      case League.advanced:
        return const Text('🔥', style: TextStyle(fontSize: 20));
    }
  }

  Widget _vibrantScoreboard(int left, int right) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 360;
        final padding = isNarrow ? 16.0 : 24.0;
        final fontSize = isNarrow ? 28.0 : 36.0;
        final labelSize = isNarrow ? 14.0 : 16.0;
        
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Left: Sen (Blue)
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: padding, vertical: 16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF2AA7FF), Color(0xFF1167B1)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(color: const Color(0xFF2AA7FF).withOpacity(0.5), blurRadius: 20, offset: const Offset(0, 8)),
                        ],
                        border: Border.all(color: Colors.white.withOpacity(0.3), width: 2),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('👤 Sen', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: labelSize)),
                          const SizedBox(height: 4),
                          Text('$left', style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w900, color: Colors.white)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text('⚔️', style: TextStyle(fontSize: 28)),
                    const SizedBox(width: 12),
                    // Right: Bot (Orange)
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: padding, vertical: 16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFF9800), Color(0xFFCC7A00)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(color: const Color(0xFFFF9800).withOpacity(0.5), blurRadius: 20, offset: const Offset(0, 8)),
                        ],
                        border: Border.all(color: Colors.white.withOpacity(0.3), width: 2),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('🤖 Bot', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: labelSize)),
                          const SizedBox(height: 4),
                          Text('$right', style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w900, color: Colors.white)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
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

  String _modeOperator(QuestionMode mode) {
    switch (mode) {
      case QuestionMode.trToEn:
      case QuestionMode.enToTr:
        return '➡️';
      case QuestionMode.engToEng:
        return '＝';
    }
  }

  Widget _modeBadgeWidget(QuestionMode mode) {
    switch (mode) {
      case QuestionMode.trToEn:
        return const Text('🇹🇷➡️🇬🇧', style: TextStyle(fontSize: 16));
      case QuestionMode.enToTr:
        return const Text('🇬🇧➡️🇹🇷', style: TextStyle(fontSize: 16));
      case QuestionMode.engToEng:
        return const Text('🇬🇧＝🇬🇧', style: TextStyle(fontSize: 16));
    }
  }

  void _shareResult(BuildContext context) {
    final isWin = userScore > botScore;
    final isDraw = userScore == botScore;
    
    String resultEmoji;
    String resultText;
    
    if (isDraw) {
      resultEmoji = '🤝';
      resultText = 'Berabere kaldım!';
    } else if (isWin) {
      resultEmoji = '🏆';
      resultText = 'Kazandım!';
    } else {
      resultEmoji = '💪';
      resultText = 'Zorlu bir maç oldu!';
    }
    
    final accuracy = items.isEmpty ? 0 : (items.where((e) => e.selectedIndex == e.correctIndex && e.selectedIndex != -1).length / items.length * 100).round();
    
    String leagueEmoji = '';
    if (league != null) {
      switch (league!) {
        case League.beginner:
          leagueEmoji = '🌱';
          break;
        case League.intermediate:
          leagueEmoji = '⚡';
          break;
        case League.advanced:
          leagueEmoji = '🔥';
          break;
      }
    }
    
    String shareText = '''
$resultEmoji WARDICT Duel Sonucu $resultEmoji

📊 Skor: $userScore - $botScore
🎯 Başarı: %$accuracy
$resultText

${league != null && eloChange != 0 ? '$leagueEmoji ${league!.name}: ${eloChange > 0 ? '+' : ''}$eloChange' : ''}

🎮 Sen de WARDICT ile kelime bilgini test et!
#WARDICT #VocabularyGame #EnglishLearning
''';
    
    Share.share(shareText.trim());
  }
}
