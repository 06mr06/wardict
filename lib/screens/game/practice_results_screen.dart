import '../../widgets/common/top_toast.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/answered_entry.dart';
import '../../models/question_mode.dart';
import '../../models/user_level.dart';
import '../../providers/game_provider.dart';
import '../../providers/practice_provider.dart';
import '../../services/word_pool_service.dart';
import '../../services/achievement_service.dart';
import '../../services/user_profile_service.dart';
import '../../services/sound_service.dart';
import '../../widgets/game/achievement_celebration.dart';
import 'package:confetti/confetti.dart';
class SeventyThirtyResultsScreen extends StatefulWidget {
  final PracticeSessionResult result;
  const SeventyThirtyResultsScreen({super.key, required this.result});

  @override
  State<SeventyThirtyResultsScreen> createState() => _SeventyThirtyResultsScreenState();
}

class _SeventyThirtyResultsScreenState extends State<SeventyThirtyResultsScreen> {
  final Set<int> _savedIndices = {};
  late ConfettiController _confettiController;

  PracticeSessionResult get result => widget.result;

  bool get allSelected => _savedIndices.length == result.answerHistory.length && result.answerHistory.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 3));
    
    // Yeni kazanılan ödülleri kontrol et
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndShowNewAchievements();
      
      // Eğer başarı oranı yüksekse konfeti patlat
      if (widget.result.accuracy >= 0.7) {
        _confettiController.play();
        // SoundService.instance.playSuccess();
      }
    });
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final practiceProvider = Provider.of<PracticeProvider>(context, listen: false);
    if (practiceProvider.duelUnlocked && result.sessionsInRow == 5) {
      // Sadece ilk kez açıldığında göster
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showDuelUnlockedAnimation(context);
      });
    }
  }

  Future<void> _checkAndShowNewAchievements() async {
    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;

    final newAchievements = await AchievementService.instance.getNewlyUnlockedAchievements();
    if (newAchievements.isNotEmpty && mounted) {
      AchievementCelebration.showNewAchievements(context, newAchievements);
    }
  }

  @override
  Widget build(BuildContext context) {
    final practiceProvider = Provider.of<PracticeProvider>(context, listen: false);
    final isLevelTest = !practiceProvider.duelUnlocked;
    final sessionProgress = result.sessionsInRow;
    
    return Scaffold(
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
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // Confetti Widget
                Align(
                  alignment: Alignment.topCenter,
                  child: ConfettiWidget(
                    confettiController: _confettiController,
                    blastDirectionality: BlastDirectionality.explosive,
                    shouldLoop: false,
                    colors: const [
                      Colors.green,
                      Colors.blue,
                      Colors.pink,
                      Colors.orange,
                      Colors.purple
                    ],
                  ),
                ),
                // Header with Level Test Progress
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      children: [
                        // Header with Level Test Progress
                        if (isLevelTest)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF6C27FF), Color(0xFF8E2DE2)],
                              ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF6C27FF).withOpacity(0.5),
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
                                    const Text(
                                      'Seviye Tespiti',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      'Oturum $sessionProgress / 5',
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        // Header
                        Text(
                          isLevelTest ? 'Test Oturumu Tamamlandı!' : 'Oturum Tamamlandı!',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        // ELO Assignment Display (only on 5th session)
                        if (result.isPlacementComplete && sessionProgress == 5)
                          _buildEloAssignmentCard(),
                        if (result.isPlacementComplete && sessionProgress == 5)
                          const SizedBox(height: 12),
                        // Level change banner (if any)
                        if (result.leveledUp)
                          _buildLevelChangeBanner(
                            isLevelUp: true,
                            newLevel: result.newLevel!,
                          )
                        else if (result.leveledDown)
                          _buildLevelChangeBanner(
                            isLevelUp: false,
                            newLevel: result.newLevel!,
                          ),
                        if (result.leveledUp || result.leveledDown)
                          const SizedBox(height: 12),
                        // Score card
                        _buildLeagueProgressBar(),
                        const SizedBox(height: 16),
                        _buildScoreCard(),
                        const SizedBox(height: 12),
                        // Soru-Cevap Geçmişi Başlığı
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Padding(
                            padding: const EdgeInsets.only(left: 4, top: 12, bottom: 8),
                            child: Row(
                              children: [
                                const Icon(Icons.menu_book, color: Colors.amber, size: 20),
                                const SizedBox(width: 8),
                                const Text(
                                  'GÜNÜN ÖNEMLİ KELİMELERİ',
                                  style: TextStyle(
                                    color: Colors.amber,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(
                          height: 220,
                          child: _buildAnswerHistory(),
                        ),
                        const SizedBox(height: 24),
                        // Row butonlar
                        Builder(
                          builder: (context) {
                            final practiceProvider = Provider.of<PracticeProvider>(context, listen: false);
                            final duelJustUnlocked = practiceProvider.duelUnlocked && result.sessionsInRow == 5 && result.isPlacementComplete;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 20),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton(
                                      onPressed: () {
                                        Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.white.withOpacity(0.1),
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(vertical: 16),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(16),
                                          side: BorderSide(color: Colors.white.withOpacity(0.3)),
                                        ),
                                      ),
                                      child: const Text(
                                        'Ana Sayfa',
                                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ),
                                  if (!duelJustUnlocked) ...[
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
                                        child: const Text(
                                          'Devam Et',
                                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ),
                                  ]
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLevelBadge(UserLevel level, {bool large = false}) {
    return Container(
      width: large ? 100 : 50,
      height: large ? 100 : 50,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: level.gradientColors.map((c) => Color(c as int)).toList(),
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Color(level.color as int).withOpacity(0.5),
            blurRadius: large ? 20 : 10,
            spreadRadius: 2,
          ),
        ],
        border: Border.all(color: Colors.white.withOpacity(0.3), width: 2),
      ),
      child: Icon(
        IconData(level.iconCode, fontFamily: 'MaterialIcons'),
        color: Colors.white,
        size: large ? 48 : 24,
      ),
    );
  }

  Widget _buildLevelChangeBanner({required bool isLevelUp, required String newLevel}) {
    final level = UserLevel.fromCode(newLevel);
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: level.gradientColors.map((c) => Color(c as int)).toList(),
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Color(level.color as int).withOpacity(0.5),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildLevelBadge(level),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isLevelUp ? 'SEVİYE ATLADIN!' : 'SEVİYE DÜŞTÜ',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
                Text(
                  'Yeni Seviye: ${level.turkishName} (${level.code})',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            isLevelUp ? Icons.arrow_upward : Icons.arrow_downward,
            color: Colors.white,
            size: 32,
          ),
        ],
      ),
    );
  }

  Widget _buildEloAssignmentCard() {
    final level = UserLevel.fromCode(result.currentLevel);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          const Text(
            'SEVİYE TESPİTİ TAMAMLANDI',
            style: TextStyle(
              color: Colors.amber,
              fontSize: 14,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 20),
          _buildLevelBadge(level, large: true),
          const SizedBox(height: 16),
          Text(
            level.turkishName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 20),
          FutureBuilder<int>(
            future: _getEloRating(),
            builder: (context, snapshot) {
              final elo = snapshot.data ?? 0;
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: level.gradientColors.map((c) => Color(c as int)).toList(),
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Color(level.color as int).withOpacity(0.3),
                      blurRadius: 15,
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const Text(
                      'BAŞLANGIÇ ELO',
                      style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      elo > 0 ? '$elo' : '...',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 36,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 20),
          const Text(
            'Harika bir başlangıç! Artık Düello modunda gerçek rakiplerle yarışabilirsin.',
            style: TextStyle(color: Colors.white60, fontSize: 13, height: 1.5),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildLeagueProgressBar() {
    final correctCount = result.correctAnswers;
    final progress = correctCount / 10.0;
    final level = UserLevel.fromCode(result.currentLevel);
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'LİG İLERLEMESİ',
                style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1),
              ),
              Text(
                '$correctCount / 10 Doğru',
                style: TextStyle(color: Color(level.color as int), fontSize: 13, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Stack(
            alignment: Alignment.centerLeft,
            children: [
              // Background Bar
              Container(
                height: 12,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              // Progress Bar
              AnimatedFractionallySizedBox(
                duration: const Duration(milliseconds: 1000),
                widthFactor: progress,
                child: Container(
                  height: 12,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: level.gradientColors.map((c) => Color(c as int)).toList(),
                    ),
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
              // Level Up Threshold (7. doğru)
              Positioned(
                left: MediaQuery.of(context).size.width * 0.58, // Approx 0.7 position
                child: Column(
                  children: [
                    Container(
                      width: 2,
                      height: 20,
                      color: Colors.amber.withOpacity(0.8),
                    ),
                    const Icon(Icons.keyboard_double_arrow_up, color: Colors.amber, size: 14),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('A1', style: TextStyle(color: Colors.white30, fontSize: 10)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text('LEVEL UP SINIRI (7)', style: TextStyle(color: Colors.amber, fontSize: 9, fontWeight: FontWeight.bold)),
              ),
              const Text('C2', style: TextStyle(color: Colors.white30, fontSize: 10)),
            ],
          ),
        ],
      ),
    );
  }

  Future<int> _getEloRating() async {
    final profile = await UserProfileService.instance.loadProfile();
    return profile.eloRating;
  }

  Widget _buildScoreCard() {
    final percentage = (result.accuracy * 100).round();
    final isGood = percentage >= 70;
    final isMedium = percentage >= 30;

    Color cardColor;
    Color textColor;
    String performanceText;

    if (isGood) {
      cardColor = Colors.green;
      textColor = Colors.green;
      performanceText = 'Harika!';
    } else if (isMedium) {
      cardColor = const Color(0xFF00CED1); // Turkuaz
      textColor = const Color(0xFF00CED1);
      performanceText = 'İyi!';
    } else {
      cardColor = Colors.red;
      textColor = Colors.red;
      performanceText = 'Çalışmaya Devam!';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            cardColor.withOpacity(0.3),
            cardColor.withOpacity(0.1)
          ],
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
              const Text(
                'Başarı Oranı',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                ),
              ),
              Text(
                '%$percentage',
                style: TextStyle(
                  color: textColor,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                performanceText,
                style: TextStyle(
                  color: textColor.withOpacity(0.8),
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
            'Doğru',
            '${result.correctAnswers}',
            Colors.green,
            Icons.check_circle,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            'Yanlış',
            '${result.totalQuestions - result.correctAnswers}',
            Colors.red,
            Icons.cancel,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            'Başarı',
            '%${(result.accuracy * 100).round()}',
            Colors.blue,
            Icons.analytics,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
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
              color: color.withOpacity(0.8),
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
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.school, color: Colors.amber, size: 20),
          const SizedBox(width: 8),
          const Text(
            'Seviye:',
            style: TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.amber.withOpacity(0.2),
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
    final remainingGames = 5 - practiceProvider.sessionsInRow;
    final message = remainingGames == 1
      ? 'Son oyun kaldı! (4/5) Düello modu açılacak.'
      : 'Son $remainingGames oyun kaldı! (${practiceProvider.sessionsInRow}/5) Düello modu açılacak.';

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
            color: const Color(0xFF6C27FF).withOpacity(0.5),
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
                const Text(
                  'Düello Moduna Doğru!',
                  style: TextStyle(
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

  Widget _buildAnswerHistory() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          // Header with Tümünü Seç/Kaldır
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Cevaplar',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                // Tümünü Seç / Tümünü Kaldır butonu
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
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              itemCount: result.answerHistory.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final answer = result.answerHistory[index];
                final isSaved = _savedIndices.contains(index);
                
                return GestureDetector(
                  onTap: () => _toggleItem(index, answer),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isSaved
                            ? [Colors.green.withOpacity(0.2), Colors.green.withOpacity(0.1)]
                            : answer.isCorrect
                                ? [Colors.green.withOpacity(0.15), Colors.green.withOpacity(0.05)]
                                : [Colors.red.withOpacity(0.15), Colors.red.withOpacity(0.05)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSaved
                            ? Colors.green.withOpacity(0.5)
                            : answer.isCorrect
                                ? Colors.green.withOpacity(0.3)
                                : Colors.red.withOpacity(0.3),
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
                        const SizedBox(width: 10),
                        // Seviye badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            answer.level,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        // Soru ve cevap
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                answer.prompt,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                '➡️ ${answer.correctAnswer}',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _toggleItem(int index, PracticeAnswerRecord answer) {
    final provider = context.read<GameProvider>();
    
    setState(() {
      if (_savedIndices.contains(index)) {
        // Kaldır
        _savedIndices.remove(index);
        // QuestionType -> QuestionMode dönüşümü
        final questionMode = _convertToQuestionMode(answer.mode);
        final entry = AnsweredEntry(
          prompt: answer.prompt,
          correctText: answer.correctAnswer,
          selectedText: answer.selectedAnswer,
          selectedIndex: answer.isCorrect ? 0 : 1,
          correctIndex: 0,
          earnedPoints: answer.points,
          mode: questionMode,
        );
        provider.removeFromPool(entry);
      } else {
        // Ekle
        _savedIndices.add(index);
        // QuestionType -> QuestionMode dönüşümü
        final questionMode = _convertToQuestionMode(answer.mode);
        final entry = AnsweredEntry(
          prompt: answer.prompt,
          correctText: answer.correctAnswer,
          selectedText: answer.selectedAnswer,
          selectedIndex: answer.isCorrect ? 0 : 1,
          correctIndex: 0,
          earnedPoints: answer.points,
          mode: questionMode,
        );
        provider.addToPool(entry);
        SoundService.instance.playCoinSound();
        SoundService.instance.vibrate(HapticFeedbackType.selection);
      }
    });
  }

  void _toggleAll() {
    final provider = context.read<GameProvider>();
    
    setState(() {
      if (allSelected) {
        // Tümünü kaldır
        for (int i = 0; i < result.answerHistory.length; i++) {
          final answer = result.answerHistory[i];
          final questionMode = _convertToQuestionMode(answer.mode);
          final entry = AnsweredEntry(
            prompt: answer.prompt,
            correctText: answer.correctAnswer,
            selectedText: answer.selectedAnswer,
            selectedIndex: answer.isCorrect ? 0 : 1,
            correctIndex: 0,
            earnedPoints: answer.points,
            mode: questionMode,
          );
          provider.removeFromPool(entry);
        }
        _savedIndices.clear();
        SoundService.instance.vibrate(HapticFeedbackType.medium);
        showTopToast(context, 'Tüm kelimeler havuzdan çıkarıldı', isError: true);
      } else {
        // Tümünü seç
        for (int i = 0; i < result.answerHistory.length; i++) {
          if (!_savedIndices.contains(i)) {
            final answer = result.answerHistory[i];
            final questionMode = _convertToQuestionMode(answer.mode);
            final entry = AnsweredEntry(
              prompt: answer.prompt,
              correctText: answer.correctAnswer,
              selectedText: answer.selectedAnswer,
              selectedIndex: answer.isCorrect ? 0 : 1,
              correctIndex: 0,
              earnedPoints: answer.points,
              mode: questionMode,
            );
            provider.addToPool(entry);
            _savedIndices.add(i);
          }
        }
        SoundService.instance.playCoinSound();
        SoundService.instance.vibrate(HapticFeedbackType.heavy);
        showTopToast(context, '${result.answerHistory.length} kelime havuza eklendi');
      }
    });
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
                color: Colors.deepPurple.withOpacity(0.3),
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
              const Text(
                'Düello Modu Açıldı!',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.deepPurple,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const Text(
                'Artık arkadaşlarınla veya bota karşı yarışabilirsin!',
                style: TextStyle(fontSize: 16, color: Colors.black87),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Harika!'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
