import '../../widgets/common/top_toast.dart';
import '../../widgets/common/ad_banner_widget.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/share_service.dart';
import '../../models/answered_entry.dart';
import '../../models/question_mode.dart';
import '../../providers/game_provider.dart';
import '../../providers/practice_provider.dart';
import '../../providers/language_provider.dart';
import '../../services/word_pool_service.dart';
import '../../services/achievement_service.dart';
import '../../services/user_profile_service.dart';
import '../../services/ranking_service.dart';
import '../../widgets/game/achievement_celebration.dart';
import 'package:confetti/confetti.dart';
import '../../models/premium.dart';
import '../../services/ad_service.dart';
import '../../services/shop_service.dart';
import '../../services/word_usage_service.dart';
import '../../services/sound_service.dart';
import '../../widgets/common/level_up_dialog.dart';
import '../../models/user_level.dart';
import '../home/widgets/home_dialogs.dart';
import '../../widgets/game/learning_summary_card.dart';

class SeventyThirtyResultsScreen extends StatefulWidget {
  final PracticeSessionResult result;
  const SeventyThirtyResultsScreen({super.key, required this.result});

  @override
  State<SeventyThirtyResultsScreen> createState() => _SeventyThirtyResultsScreenState();
}

class _SeventyThirtyResultsScreenState extends State<SeventyThirtyResultsScreen> {
  final Set<int> _savedIndices = {};
  late ConfettiController _confettiController;
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _boundaryKey = GlobalKey();
  bool _showWordsList = true;
  
  bool get allSelected => _savedIndices.length == result.answerHistory.length && result.answerHistory.isNotEmpty;

  PracticeSessionResult get result => widget.result;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 3));
    
    // Yeni kazanılan ödülleri kontrol et
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndShowNewAchievements();
      _addPointsToWeeklyScore();
      
      for (int i = 0; i < result.answerHistory.length; i++) {
        _savedIndices.add(i);
      }
      
      setState(() {});

      // Eğer başarı oranı yüksekse konfeti patlat
      if (widget.result.accuracy >= 0.7) {
        _confettiController.play();
        SoundService.instance.playSuccess();
      }
      
      if (widget.result.leveledUp && widget.result.oldLevel != null && widget.result.newLevel != null) {
        LevelUpDialog.show(
          context,
          UserLevel.fromCode(widget.result.oldLevel!),
          UserLevel.fromCode(widget.result.newLevel!),
        );
      }

      // Reklam sayacını güncelle (Geçiş reklamı için)
      AdService.instance.onGameCompleted();

      // Kelime kullanım istatistiklerini güncelle (Tekrar eden soruları önlemek için)
      final usedWords = result.answerHistory.map((e) => e.correctAnswer).cast<String>().toList();
      WordUsageService.instance.markWordsUsed(usedWords);
    });
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final practiceProvider = Provider.of<PracticeProvider>(context, listen: false);
    if (practiceProvider.duelUnlocked && practiceProvider.totalSessionsCompleted == 3) {
      // Sadece ilk kez açıldığında göster
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showDuelUnlockedAnimation(context);
      });
    }
  }

  Future<void> _checkAndShowNewAchievements() async {
    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;

    final isNewUser = await ShopService.instance.checkAndGiveWelcomeGift();
    if (isNewUser && mounted) {
      HomeDialogs.showWelcomeGiftDialog(context);
      return; // Yeni kullanıcıysa başarımları hemen gösterme, çok karmaşık olmasın
    }

    final newAchievements = await AchievementService.instance.getNewlyUnlockedAchievements();
    if (newAchievements.isNotEmpty && mounted) {
      AchievementCelebration.showNewAchievements(context, newAchievements);
    }
  }

  Future<void> _addPointsToWeeklyScore() async {
    // Haftalık puana ekle
    final pointsToAdd = result.sessionScore; // Artık gerçek puan toplamını kullanıyoruz
    if (pointsToAdd > 0) {
      final profile = await UserProfileService.instance.loadProfile();
      await RankingService.instance.addScore(profile.username, pointsToAdd);
    }
  }

  Widget _buildAdSection() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: AdBannerWidget(),
      ),
    );
  }

  Widget _buildFooter(bool isLevelTest, int sessionProgress) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A3A5C),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(120),
            blurRadius: 15,
            offset: const Offset(0, -5),
          ),
        ],
        border: Border(top: BorderSide(color: Colors.white.withAlpha(20))),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Center(child: AdBannerWidget()),
          const SizedBox(height: 12),
          Builder(
            builder: (context) {
              final practiceProvider = Provider.of<PracticeProvider>(context, listen: false);
              final duelJustUnlocked = practiceProvider.duelUnlocked && practiceProvider.totalSessionsCompleted == 3 && result.isPlacementComplete;
              return Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white.withAlpha(26),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: Colors.white.withAlpha(77)),
                        ),
                      ),
                      child: Text(
                        context.read<LanguageProvider>().getString('home'),
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pushReplacementNamed('/7030');
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4CAF50),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: Text(
                        context.read<LanguageProvider>().getString('continue_button'),
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final practiceProvider = Provider.of<PracticeProvider>(context, listen: false);
    final isLevelTest = !practiceProvider.duelUnlocked;
    final sessionProgress = result.sessionsInRow;
    
    return Scaffold(
      backgroundColor: const Color(0xFF1A3A5C),
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight),
                      child: Column(
                        children: [
                          // 1. Skor ve Seviye Durumu
                          RepaintBoundary(
                            key: _boundaryKey,
                            child: Container(
                              color: const Color(0xFF1A3A5C),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (isLevelTest) _buildLevelProgressBanner(sessionProgress),
                                  _buildScoreCard(),
                                ],
                              ),
                            ),
                          ),

  // 2. Öğrenme Özeti (Yanlış kelimeler)
  Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    child: LearningSummaryCard(
      answerHistory: result.answerHistory.map((r) => AnsweredEntry(
        prompt: r.prompt,
        selectedIndex: r.selectedAnswer == r.correctAnswer ? 1 : 0, // Mock index for summary card
        correctIndex: 1, // Mock index
        earnedPoints: r.points,
        mode: QuestionMode.values[r.mode.index], // Enum conversion assuming they map
        correctText: r.correctAnswer,
        selectedText: r.selectedAnswer,
        turkishMeaning: r.turkishMeaning,
      )).toList(),
    ),
  ),

                          // 3. Çıkmış Kelimeler (Sınırlı yükseklik ve içten kaydırma)
                          Container(
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            height: 280, // Sabit yükseklik: 3-4 kelime + buton sığacak şekilde
                            decoration: BoxDecoration(
                              color: Colors.white.withAlpha(13),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.white10),
                            ),
                            child: _buildWordsList(),
                          ),

                          // 3. Reklam Alanı (Medium Rectangle)
                          const AdBannerWidget(isMediumRectangle: true),

                          const SizedBox(height: 16),

                          // 4. Alt Butonlar
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                            child: Row(
                              children: [
                                IconButton(
                                  onPressed: () => ShareService.instance.shareWidgetAsImage(_boundaryKey, 'LUGORENA\'da pratik skoruma bak!'),
                                  icon: const Icon(Icons.share, color: Colors.white),
                                  style: IconButton.styleFrom(
                                    backgroundColor: Colors.white.withAlpha(26),
                                    padding: const EdgeInsets.all(14),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: () => Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF3F51B5), // Belirgin İndigo rengi
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      elevation: 4,
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const Icon(Icons.home_rounded, size: 20),
                                        const SizedBox(width: 8),
                                        Text(
                                          context.watch<LanguageProvider>().getString('home').toUpperCase(),
                                          style: const TextStyle(fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: () {
                                      Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF28A745),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                    child: Text(
                                      context.watch<LanguageProvider>().getString('continue_button').toUpperCase(),
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Navigasyon bar emniyeti
                          SizedBox(height: MediaQuery.of(context).padding.bottom),
                        ],
                      ),
                  ),
                );
              },
            ),

            // Navigasyon barı güvenli bölgesi
            SizedBox(height: MediaQuery.of(context).padding.bottom + 10),


            // Konfeti
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
      ),
    );
  }

  Widget _buildLevelChangeBanner({required bool isLevelUp, required String newLevel}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isLevelUp
              ? [Colors.green.shade400, Colors.green.shade600]
              : [Colors.red.shade400, Colors.red.shade600],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: (isLevelUp ? Colors.green : Colors.red).withAlpha(128),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isLevelUp ? Icons.arrow_upward : Icons.arrow_downward,
            color: Colors.white,
            size: 28,
          ),
          const SizedBox(width: 12),
          Column(
            children: [
              Text(
                isLevelUp 
                    ? context.watch<LanguageProvider>().getString('level_up_message') 
                    : context.watch<LanguageProvider>().getString('level_down_message'),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '${context.watch<LanguageProvider>().getString('new_level_prefix')} $newLevel',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLpAssignmentCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFFD700).withAlpha(128),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.emoji_events,
                color: Colors.white,
                size: 32,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  context.watch<LanguageProvider>().getString('level_test_complete'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(77),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Text(
                  context.watch<LanguageProvider>().getString('determined_level'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  result.currentLevel,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          FutureBuilder<int>(
            future: _getLpRating(),
            builder: (context, snapshot) {
              final lp = snapshot.data ?? 0;
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(51),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.stars,
                      color: Colors.white,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      context.watch<LanguageProvider>().getString('starting_lp'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      lp > 0 ? '$lp' : (context.watch<LanguageProvider>().currentLanguage == 'tr' ? 'Hesaplanıyor...' : 'Calculating...'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          Text(
            context.watch<LanguageProvider>().getString('duel_unlocked_desc'),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Future<int> _getLpRating() async {
    final profile = await UserProfileService.instance.loadProfile();
    return profile.lpRating;
  }

  Widget _buildScoreCard() {
    final percentage = (result.accuracy * 100).round();
    final isGood = percentage >= 70;
    final isMedium = percentage > 30; // 30 ve altı başarısız (Kırmızı) kabul edilecek

    Color cardColor;
    Color textColor;
    String performanceText;

    if (isGood) {
      cardColor = Colors.green;
      textColor = Colors.green;
      performanceText = context.watch<LanguageProvider>().getString('great');
    } else if (isMedium) {
      cardColor = const Color(0xFF00CED1); // Turkuaz
      textColor = const Color(0xFF00CED1);
      performanceText = context.watch<LanguageProvider>().getString('good');
    } else {
      cardColor = Colors.red;
      textColor = Colors.red;
      performanceText = context.watch<LanguageProvider>().getString('keep_working');
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4), 
      margin: const EdgeInsets.symmetric(vertical: 4), 
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [cardColor.withAlpha(77), cardColor.withAlpha(26)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: cardColor,
          width: 2,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isGood ? Icons.star : isMedium ? Icons.thumb_up : Icons.school,
            color: cardColor,
            size: 26,
          ),
          const SizedBox(width: 12),
          Column(
            children: [
              Text(
                context.watch<LanguageProvider>().getString('success_rate'),
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                ),
              ),
              Text(
                '%$percentage',
                style: TextStyle(
                  color: textColor,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                performanceText,
                style: TextStyle(
                  color: textColor.withAlpha(204),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatisticsRow() {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            context.watch<LanguageProvider>().getString('correct'),
            '${result.correctAnswers}',
            Colors.green,
            Icons.check_circle,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            context.watch<LanguageProvider>().getString('wrong'),
            '${result.totalQuestions - result.correctAnswers}',
            Colors.red,
            Icons.cancel,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            context.watch<LanguageProvider>().getString('success'),
            '%${(result.accuracy * 100).round()}',
            result.accuracy >= 0.7 ? Colors.green : (result.accuracy > 0.3 ? Colors.blue : Colors.red),
            Icons.analytics,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            context.watch<LanguageProvider>().getString('points'),
            '${result.sessionScore}',
            Colors.amber,
            Icons.stars,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      decoration: BoxDecoration(
        color: color.withAlpha(38),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(77)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: color.withAlpha(204),
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentLevelCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(26),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withAlpha(51)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.school, color: Colors.amber, size: 20),
          const SizedBox(width: 8),
          Text(
            '${context.watch<LanguageProvider>().getString('level')}:',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.amber.withAlpha(51),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.amber),
            ),
            child: Text(
              result.currentLevel,
              style: const TextStyle(
                color: Colors.amber,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDuelProgressBanner() {
    final practiceProvider = Provider.of<PracticeProvider>(context, listen: false);
    final remainingGames = 3 - practiceProvider.sessionsInRow;
    final message = remainingGames == 1
      ? context.watch<LanguageProvider>().getString('one_session_left')
      : context.watch<LanguageProvider>().getString('sessions_remaining')
          .replaceAll('{remaining}', remainingGames.toString())
          .replaceAll('{progress}', practiceProvider.sessionsInRow.toString());

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6C27FF), Color(0xFF8E2DE2)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6C27FF).withAlpha(128),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.flash_on,
            color: Colors.yellow,
            size: 28,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              children: [
                Text(
                  context.watch<LanguageProvider>().getString('towards_duel'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWordsToggle() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 0),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => setState(() => _showWordsList = !_showWordsList),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(26),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _showWordsList ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                  color: Colors.amber,
                  size: 20,
                ),
                const SizedBox(width: 6),
                Text(
                  _showWordsList 
                      ? context.watch<LanguageProvider>().getString('hide_words') 
                      : '${context.watch<LanguageProvider>().getString('show_words')} (${result.answerHistory.length})',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWordsList() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black38,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(51),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      const Icon(Icons.list_alt_rounded, color: Colors.amber, size: 18),
                      const SizedBox(width: 6),
                      Text(
                        context.watch<LanguageProvider>().getString('words_appeared'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: _toggleSelectAll,
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: Colors.white60,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    allSelected 
                        ? 'TEMİZLE' 
                        : 'TÜMÜNÜ SEÇ',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          
          const Divider(color: Colors.white10, height: 1),
          
          // Kelime listesi
          Expanded(
            child: Scrollbar(
              controller: _scrollController,
              thumbVisibility: true,
              child: ListView.separated(
                shrinkWrap: true,
                controller: _scrollController,
                padding: const EdgeInsets.all(12),
                itemCount: result.answerHistory.length,
                separatorBuilder: (context, index) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                final answer = result.answerHistory[index];
                final isSaved = _savedIndices.contains(index);
                final isCorrect = answer.isCorrect;
                
                return GestureDetector(
                  onTap: () => _toggleWord(index),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeInOut,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: isSaved 
                          ? Colors.amber.withAlpha(20) 
                          : Colors.white.withAlpha(10),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSaved ? Colors.amber : Colors.white10,
                        width: isSaved ? 1.5 : 1,
                      ),
                      boxShadow: isSaved ? [
                        BoxShadow(
                          color: Colors.amber.withAlpha(30),
                          blurRadius: 8,
                          spreadRadius: 1,
                        )
                      ] : null,
                    ),
                    child: Row(
                      children: [
                        // Status Icon
                        TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0.8, end: 1.0),
                          duration: const Duration(milliseconds: 200),
                          builder: (context, value, child) {
                            return Transform.scale(
                              scale: isSaved ? value : 1.0,
                              child: Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: (isCorrect ? Colors.green : Colors.red).withAlpha(51),
                                ),
                                child: Icon(
                                  isCorrect ? Icons.check_rounded : Icons.close_rounded,
                                  size: 18,
                                  color: isCorrect ? Colors.greenAccent : Colors.redAccent,
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(width: 12),
                        
                        // Word and Meaning
                        Flexible(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    answer.correctAnswer,
                                    style: TextStyle(
                                      color: isSaved ? Colors.amber : Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                answer.prompt + (answer.turkishMeaning != null ? ' | ${answer.turkishMeaning}' : ''),
                                style: TextStyle(
                                  color: isSaved ? Colors.amber.withAlpha(179) : Colors.white.withAlpha(153),
                                  fontSize: 11,
                                  fontStyle: FontStyle.italic,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        
                        // Points
                        if (!isSaved)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.amber.withAlpha(26),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.amber.withAlpha(77)),
                            ),
                            child: Text(
                              '+${answer.points}',
                              style: const TextStyle(
                                color: Colors.amber,
                                fontWeight: FontWeight.w900,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        
                        const SizedBox(width: 8),
                        
                        // Checkbox Icon
                        Icon(
                          isSaved ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                          color: isSaved ? Colors.amber : Colors.white24,
                          size: 22,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
          
          // Add to my words footer
          if (result.answerHistory.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(12),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _savedIndices.isNotEmpty ? _addToMyWords : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber,
                    foregroundColor: Colors.black,
                    disabledBackgroundColor: Colors.white.withAlpha(26),
                    disabledForegroundColor: Colors.white24,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: _savedIndices.isNotEmpty ? 8 : 0,
                    shadowColor: Colors.amber.withAlpha(102),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _savedIndices.isNotEmpty ? Icons.auto_awesome : Icons.bookmark_add_outlined,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        _savedIndices.isNotEmpty 
                            ? '${_savedIndices.length} KELİMEYİ KAYDET'
                            : 'KAYDEDİLECEK KELİME SEÇİN',
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.5),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  void _toggleWord(int index) {
    setState(() {
      if (_savedIndices.contains(index)) {
        _savedIndices.remove(index);
      } else {
        _savedIndices.add(index);
      }
    });
  }

  void _toggleSelectAll() {
    setState(() {
      if (allSelected) {
        _savedIndices.clear();
      } else {
        for (int i = 0; i < result.answerHistory.length; i++) {
          _savedIndices.add(i);
        }
      }
    });
  }

  void _addToMyWords() {
    if (_savedIndices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.watch<LanguageProvider>().getString('please_select_level')),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final gameProvider = context.read<GameProvider>();
    int addedCount = 0;

    for (final index in _savedIndices) {
      final answer = result.answerHistory[index];
      final questionMode = _convertToQuestionMode(answer.mode);
      
      final entry = AnsweredEntry(
        prompt: answer.prompt,
        correctText: answer.correctAnswer,
        selectedText: answer.selectedAnswer,
        selectedIndex: answer.isCorrect ? 0 : 1,
        correctIndex: 0,
        earnedPoints: answer.points,
        mode: questionMode,
        turkishMeaning: answer.turkishMeaning,
      );
      if (!gameProvider.isSaved(entry)) {
        gameProvider.addToPool(entry);
        addedCount++;
      }
    }

    if (mounted) {
      TopToast.show(
        context,
        title: 'Başarılı!',
        message: '$addedCount yeni kelime koleksiyonuna eklendi.',
        icon: Icons.bookmark_added_rounded,
        color: Colors.amber,
      );
    }
  }

  /// QuestionType'ı QuestionMode'a dönüştürür
  QuestionMode _convertToQuestionMode(QuestionType type) {
    switch (type) {
      case QuestionType.enToTr:
        return QuestionMode.enToTr;
      case QuestionType.trToEn:
        return QuestionMode.trToEn;
      case QuestionType.synonym:
      case QuestionType.antonym:
      case QuestionType.relation:
        return QuestionMode.engToEng;
    }
  }

  void _showDuelUnlockedAnimation(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.deepPurple.withAlpha(77),
                blurRadius: 24,
                spreadRadius: 4,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.sports_kabaddi, color: Colors.deepPurple, size: 64),
              const SizedBox(height: 16),
              Text(
                context.watch<LanguageProvider>().getString('duel_unlocked_dialog_title'),
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.deepPurple,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                context.watch<LanguageProvider>().getString('duel_unlocked_dialog_body'),
                style: const TextStyle(fontSize: 16, color: Colors.black87),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop(); // Diyaloğu kapat
                  Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false); // Ana ekrana dön
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(context.watch<LanguageProvider>().getString('awesome')),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLevelProgressBanner(int sessionProgress) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6C27FF), Color(0xFF8E2DE2)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6C27FF).withAlpha(128),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.assignment_turned_in, color: Colors.amber, size: 24),
          const SizedBox(width: 12),
          Column(
            children: [
              Text(
                context.watch<LanguageProvider>().getString('level_test_title'),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '${context.watch<LanguageProvider>().getString('session')} $sessionProgress / 3',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 6),
              SizedBox(
                width: 120,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: sessionProgress / 3.0,
                    backgroundColor: Colors.black.withAlpha(51),
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.amber),
                    minHeight: 6,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumBanner() {
    return FutureBuilder<PremiumSubscription>(
      future: ShopService.instance.getSubscription(),
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data!.tier != PremiumTier.free) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFFD700), Color(0xFFFFA000)],
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(color: Colors.black.withAlpha(77), blurRadius: 8),
              ],
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.star, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Text(
                  'PREMIUM ÜYE',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ],
            ),
          );
        }
        return const SizedBox.shrink();
      },
    );
  }
}
