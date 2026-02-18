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
import 'bonus_breakdown_widget.dart';
import '../../widgets/common/ad_banner_widget.dart';
import 'package:confetti/confetti.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/achievement_service.dart';
import '../../services/shop_service.dart';
import '../../models/achievement.dart';

class DuelResultsScreen extends StatefulWidget {
  final int userScore;
  final int botScore;
  final List<AnsweredEntry> items;
  final League? league;
  final int eloChange;
  final int userElo;
  final int botElo;
  
  const DuelResultsScreen({
    super.key, 
    required this.userScore, 
    required this.botScore, 
    required this.items,
    this.league,
    this.eloChange = 0,
    this.userElo = 1500,
    this.botElo = 1500,
  });

  @override
  State<DuelResultsScreen> createState() => _DuelResultsScreenState();
}

class _DuelResultsScreenState extends State<DuelResultsScreen> {
    // Bonus breakdown calculation
    Map<String, int> _calculateBonuses() {
      int streakBonus = 0;
      int speedBonus = 0;
      int upperLevelBonus = 0;
      int maxStreak = 0;
      int fastAnswers = 0;
      for (final e in items) {
        if (e.selectedIndex == e.correctIndex && e.selectedIndex != -1) {
          // Streak: count max streak
          maxStreak++;
          // Speed: if earnedPoints was with high multiplier (assume >1.2x means fast)
          if (e.earnedPoints >= (e.mode == QuestionMode.engToEng ? 18 : 15)) {
            fastAnswers++;
          }
          // Upper level: if mode is engToEng (assume upper level)
          if (e.mode == QuestionMode.engToEng) {
            upperLevelBonus += 5; // Example: 5 points per upper level correct
          }
        } else {
          if (maxStreak > streakBonus) streakBonus = maxStreak;
          maxStreak = 0;
        }
      }
      if (maxStreak > streakBonus) streakBonus = maxStreak;
      streakBonus = streakBonus > 1 ? streakBonus * 2 : 0; // Example: 2 points per streak
      speedBonus = fastAnswers * 3; // Example: 3 points per fast answer
      return {
        'Streak Bonus': streakBonus,
        'Speed Bonus': speedBonus,
        'Upper Level Bonus': upperLevelBonus,
      };
    }
  final Set<int> _selectedIndices = {};

  int get userScore => widget.userScore;
  int get botScore => widget.botScore;
  List<AnsweredEntry> get items => widget.items;
  League? get league => widget.league;
  int get eloChange => widget.eloChange;
  int get userElo => widget.userElo;
  int get botElo => widget.botElo;

  bool get allSelected => _selectedIndices.length == items.length && items.isNotEmpty;

  late ConfettiController _confettiController;
  // ignore: unused_field - Oyun süresi hesaplama için saklanıyor
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
    // Seri Koruma var mı kontrol et
    final hasShield = await ShopService.instance.hasActiveStreakShield();
    if (hasShield) {
      // Kalkan aktif - seri korunur, sıfırlamıyoruz
      return;
    }
    
    // Kalkan yok - seri sıfırlanır
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('duel_win_streak', 0);
  }

  /// Rövanş talebi gönder
  void _requestRematch() {
    // Bot maçı için direkt yeni oyun başlat
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2E5A8C),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Text('🔄', style: TextStyle(fontSize: 28)),
            SizedBox(width: 8),
            Text('Rövanş', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: const Text(
          'Aynı rakiple tekrar oynamak ister misin?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // Dialog kapat
              Navigator.pop(context); // Sonuç ekranı kapat
              // Yeni düello başlat - duel_screen'e geri dön
              Navigator.pushReplacementNamed(context, '/duel');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF6B6B),
            ),
            child: const Text('Rövanş!'),
          ),
        ],
      ),
    );
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
    final bonuses = _calculateBonuses();
    
    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF1A3A5C), Color(0xFF0D1B2A)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  // Header
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white70),
                          onPressed: () => Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false),
                        ),
                        Text(
                          isDraw ? 'BERABERE' : (isWin ? 'ZAFER!' : 'MAĞLUBİYET'),
                          style: TextStyle(
                            color: isDraw ? Colors.amber : (isWin ? Colors.greenAccent : Colors.redAccent),
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.share, color: Colors.white70),
                          onPressed: () => _shareResult(context),
                        ),
                      ],
                    ),
                  ),

                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        children: [
                          // Scoreboard
                          _vibrantScoreboard(userScore, botScore, userElo, botElo, eloChange),
                          const SizedBox(height: 24),

                          // Bonus Breakdown
                          BonusBreakdownWidget(bonuses: bonuses),
                          const SizedBox(height: 24),

                          // Answer History Header
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Cevap Geçmişi',
                                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              TextButton.icon(
                                onPressed: _toggleAll,
                                icon: Icon(allSelected ? Icons.remove_circle_outline : Icons.add_circle_outline, size: 18, color: Color(0xFF6C27FF)),
                                label: Text(
                                  allSelected ? 'Temizle' : 'Tümünü Ekle',
                                  style: const TextStyle(color: Color(0xFF6C27FF), fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),

                          // Answer History List
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: items.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final item = items[index];
                              final isCorrect = item.selectedIndex == item.correctIndex;
                              final isSaved = _selectedIndices.contains(index);
                              
                              return Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: isSaved ? Colors.green.withOpacity(0.5) : Colors.white.withOpacity(0.1),
                                    width: isSaved ? 2 : 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    _modeBadgeWidget(item.mode),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item.prompt,
                                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                          ),
                                          Text(
                                            '${_modeOperator(item.mode)} ${item.correctText}',
                                            style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (!isCorrect && item.selectedIndex != -1)
                                      Padding(
                                        padding: const EdgeInsets.only(right: 8.0),
                                        child: Text(
                                          item.selectedText ?? '',
                                          style: const TextStyle(color: Colors.redAccent, fontSize: 12, decoration: TextDecoration.lineThrough),
                                        ),
                                      ),
                                    IconButton(
                                      icon: Icon(
                                        isSaved ? Icons.bookmark : Icons.bookmark_border,
                                        color: isSaved ? Colors.green : Colors.white38,
                                      ),
                                      onPressed: () => _toggleItem(index),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 100), // Bottom padding for buttons
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Bottom Buttons
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.transparent, Colors.black.withOpacity(0.8)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _requestRematch,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white24),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: const Text('RÖVANŞ', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6C27FF),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 8,
                        shadowColor: const Color(0xFF6C27FF).withOpacity(0.5),
                      ),
                      child: const Text('DEVAM ET', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Confetti Overlay
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              shouldLoop: false,
              colors: const [Colors.green, Colors.blue, Colors.pink, Colors.orange, Colors.purple],
            ),
          ),
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

  Widget _vibrantScoreboard(int left, int right, int leftElo, int rightElo, int eloChange) {
    final userEloChange = eloChange;
    final botEloChange = -eloChange; // Rakip ters puan alır
    
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
                          BoxShadow(color: const Color(0xFF2AA7FF).withValues(alpha: 0.5), blurRadius: 20, offset: const Offset(0, 8)),
                        ],
                        border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 2),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('👤 Sen', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: labelSize)),
                          const SizedBox(height: 4),
                          Text('$left', style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w900, color: Colors.white)),
                          // ELO Değişimi
                          if (eloChange != 0) ...[  
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '$leftElo',
                                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                                  ),
                                  Text(
                                    ' ${userEloChange >= 0 ? "+" : ""}$userEloChange',
                                    style: TextStyle(
                                      color: userEloChange >= 0 ? Colors.greenAccent : Colors.redAccent,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
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
                          BoxShadow(color: const Color(0xFFFF9800).withValues(alpha: 0.5), blurRadius: 20, offset: const Offset(0, 8)),
                        ],
                        border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 2),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('🤖 Bot', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: labelSize)),
                          const SizedBox(height: 4),
                          Text('$right', style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w900, color: Colors.white)),
                          // ELO Değişimi (Rakip)
                          if (eloChange != 0) ...[  
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '$rightElo',
                                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                                  ),
                                  Text(
                                    ' ${botEloChange >= 0 ? "+" : ""}$botEloChange',
                                    style: TextStyle(
                                      color: botEloChange >= 0 ? Colors.greenAccent : Colors.redAccent,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
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

  Future<void> _shareResult(BuildContext context) async {
    // Paylaşılabilirlik sadece VIP (Premium) üyelere olacak
    final isPremium = await ShopService.instance.hasFeature('share_results');
    
    if (!isPremium) {
      if (!context.mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF1A3A5C),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.star, color: Colors.amber),
              SizedBox(width: 8),
              Text('Premium Özellik', style: TextStyle(color: Colors.white)),
            ],
          ),
          content: const Text(
            'Sonuçlarını paylaşma özelliği sadece Premium üyelerimiz içindir. Sen de Premium\'a geçip tüm özelliklerin kilidini açabilirsin!',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('TAMAM', style: TextStyle(color: Colors.amber)),
            ),
          ],
        ),
      );
      return;
    }

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
$resultEmoji LUGORENA Duel Sonucu $resultEmoji

📊 Skor: $userScore - $botScore
🎯 Başarı: %$accuracy
$resultText

${league != null && eloChange != 0 ? '$leagueEmoji ${league!.name}: ${eloChange > 0 ? '+' : ''}$eloChange' : ''}

🎮 Sen de LUGORENA ile kelime bilgini test et!
#LUGORENA #VocabularyGame #EnglishLearning
''';
    
    Share.share(shareText.trim());
  }
}
