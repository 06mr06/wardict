import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/game_provider.dart';
import '../../models/answered_entry.dart';
import '../../models/question_mode.dart';
import '../../models/league.dart';
import '../../widgets/common/top_toast.dart';
import '../../widgets/game/achievement_celebration.dart';
import 'package:confetti/confetti.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../widgets/common/ad_banner_widget.dart';
import '../../services/shop_service.dart';
import '../../models/achievement.dart';
import '../../services/achievement_service.dart';
import '../../providers/language_provider.dart';
import '../../services/user_profile_service.dart';
import '../../services/word_pool_service.dart';
import '../../models/cosmetic_item.dart';
import '../../widgets/common/match_loot_chest_dialog.dart';

import '../home/widgets/home_dialogs.dart';
import '../../services/share_service.dart';

class DuelResultsScreen extends StatefulWidget {
  final int userScore;
  final int botScore;
  final List<AnsweredEntry> items;
  final League? league;
  final int lpChange;
  final int userLp;
  final int botLp;
  final String? botName;
  final String? botAvatar;
  
  const DuelResultsScreen({
    super.key, 
    required this.userScore, 
    required this.botScore, 
    required this.items,
    this.league,
    this.lpChange = 0,
    this.userLp = 1500,
    this.botLp = 1500,
    this.botName,
    this.botAvatar,
  });

  @override
  State<DuelResultsScreen> createState() => _DuelResultsScreenState();
}

class _DuelResultsScreenState extends State<DuelResultsScreen> {
    Map<String, int> _calculateBonuses() {
      int streakBonus = 0;
      int speedBonus = 0;
      int upperLevelBonus = 0;
      int maxStreak = 0;
      int fastAnswers = 0;
      for (final e in items) {
        if (e.selectedIndex == e.correctIndex && e.selectedIndex != -1) {
          maxStreak++;
          if (e.earnedPoints >= (e.mode == QuestionMode.engToEng ? 18 : 15)) {
            fastAnswers++;
          }
          if (e.mode == QuestionMode.engToEng) {
            upperLevelBonus += 5;
          }
        } else {
          if (maxStreak > streakBonus) streakBonus = maxStreak;
          maxStreak = 0;
        }
      }
      if (maxStreak > streakBonus) streakBonus = maxStreak;
      streakBonus = streakBonus > 1 ? streakBonus * 2 : 0;
      speedBonus = fastAnswers * 3;
      return {
        'Streak Bonus': streakBonus,
        'Speed Bonus': speedBonus,
        'Upper Level Bonus': upperLevelBonus,
      };
    }
  final Set<int> _selectedIndices = {};
  late ConfettiController _confettiController;
  final GlobalKey _boundaryKey = GlobalKey();

  int get userScore => widget.userScore;
  int get botScore => widget.botScore;
  List<AnsweredEntry> get items => widget.items;
  League? get league => widget.league;
  int get lpChange => widget.lpChange;
  int get userLp => widget.userLp;
  int get botLp => widget.botLp;

  bool get allSelected => _selectedIndices.length == items.length && items.isNotEmpty;

  String? _userProfilePhoto;
  String? _userAvatarEmoji;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 3));
    
    _loadUserProfile();

    if (widget.userScore > widget.botScore) {
       Future.delayed(const Duration(milliseconds: 500), () {
         if (mounted) _confettiController.play();
       });
       _handleDuelWinAchievements();
    } else {
       _resetDuelStreak();
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final gp = context.read<GameProvider>();
      for (int i = 0; i < items.length; i++) {
        if (gp.isSaved(items[i])) {
          _selectedIndices.add(i);
        }
      }
      setState(() {});
      _checkAndShowNewAchievements();
    });
  }

  Future<void> _loadUserProfile() async {
    final profile = await UserProfileService.instance.loadProfile();
    if (mounted) {
      setState(() {
        _userProfilePhoto = profile.profileImagePath;
        _userAvatarEmoji = profile.avatarId;
      });
    }
  }
  
  Future<void> _checkAndShowNewAchievements() async {
    await Future.delayed(const Duration(milliseconds: 1500));
    if (!mounted) return;
    
    final isNewUser = await ShopService.instance.checkAndGiveWelcomeGift();
    if (isNewUser && mounted) {
      HomeDialogs.showWelcomeGiftDialog(context);
      return;
    }
    
    if (widget.userScore > widget.botScore && mounted) {
      await MatchLootChestDialog.show(context, onClaimed: () {});
    }
    
    final newAchievements = await AchievementService.instance.getNewlyUnlockedAchievements();
    if (newAchievements.isNotEmpty && mounted) {
      AchievementCelebration.showNewAchievements(context, newAchievements);
    }
  }
  
  @override
  void dispose() {
    _confettiController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _handleDuelWinAchievements() async {
    await AchievementService.instance.updateProgress(AchievementCategory.career, 1);
    final prefs = await SharedPreferences.getInstance();
    int currentStreak = (prefs.getInt('duel_win_streak') ?? 0) + 1;
    await prefs.setInt('duel_win_streak', currentStreak);
    
    if (currentStreak >= 5) {
      await AchievementService.instance.updateAchievementProgressById('duel_streak_5', 5, setExact: true);
    }
    await AchievementService.instance.updateProgress(AchievementCategory.social, 1);
  }

  Future<void> _resetDuelStreak() async {
    final hasShield = await ShopService.instance.hasActiveStreakShield();
    if (hasShield) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('duel_win_streak', 0);
  }

  void _requestRematch() {
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
              Navigator.pop(context);
              Navigator.pop(context);
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
        for (int i = 0; i < items.length; i++) {
          gp.removeFromPool(items[i]);
        }
        _selectedIndices.clear();
        TopToast.show(
          context, 
          title: 'Çıkarıldı!', 
          message: 'Tüm kelimeler havuzdan temizlendi.', 
          icon: Icons.bookmark_remove_rounded,
          color: Colors.redAccent,
        );
      } else {
        for (int i = 0; i < items.length; i++) {
          if (!_selectedIndices.contains(i)) {
            gp.addToPool(items[i]);
            _selectedIndices.add(i);
          }
        }
        TopToast.show(
          context, 
          title: 'Eklendi!', 
          message: '${items.length} kelime koleksiyona katıldı.', 
          icon: Icons.bookmark_added_rounded,
          color: Colors.amber,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isWin = userScore > botScore;
    final isDraw = userScore == botScore;
    final bonuses = _calculateBonuses();

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
                    child: IntrinsicHeight(
                      child: Column(
                        children: [
                          // 1. Skor Alanı (Paylaşım için sınır)
                          RepaintBoundary(
                            key: _boundaryKey,
                            child: Container(
                              color: const Color(0xFF1A3A5C), // Arka plan rengi paylaşım için gerekli
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    isDraw ? 'BERABERE' : (isWin ? 'ZAFER!' : 'MAĞLUBİYET'),
                                    style: TextStyle(
                                      color: isDraw ? Colors.amber : (isWin ? Colors.greenAccent : Colors.redAccent),
                                      fontSize: 22,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 3,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  _vibrantScoreboard(userScore, botScore, userLp, botLp, lpChange),
                                  const SizedBox(height: 12),
                                  _buildLPBar(),
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      if (bonuses['Streak Bonus']! > 0)
                                        _compactBonusItem('🔥', bonuses['Streak Bonus']!),
                                      if (bonuses['Speed Bonus']! > 0)
                                        _compactBonusItem('⚡', bonuses['Speed Bonus']!),
                                      if (bonuses['Upper Level Bonus']! > 0)
                                        _compactBonusItem('⬆️', bonuses['Upper Level Bonus']!),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // 2. Cevap Geçmişi
                          Flexible(
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 16),
                              constraints: const BoxConstraints(maxHeight: 350),
                              decoration: BoxDecoration(
                                color: Colors.white.withAlpha(13),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.white10),
                              ),
                              child: Column(
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text(
                                          'CEVAP GEÇMİŞİ',
                                          style: TextStyle(color: Colors.amber, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1),
                                        ),
                                        GestureDetector(
                                          onTap: _toggleAll,
                                          child: Text(
                                            allSelected ? 'TEMİZLE' : 'TÜMÜNÜ SEÇ',
                                            style: const TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Expanded(
                                    child: items.isEmpty
                                        ? const Center(child: Text('Kayıt bulunamadı', style: TextStyle(color: Colors.white38)))
                                        : Scrollbar(
                                            controller: _scrollController,
                                            thumbVisibility: true,
                                            child: ListView.separated(
                                              controller: _scrollController,
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                              itemCount: items.length,
                                              separatorBuilder: (_, __) => const SizedBox(height: 6),
                                              itemBuilder: (context, index) {
                                                final item = items[index];
                                                final isSaved = _selectedIndices.contains(index);
                                                final isCorrect = item.selectedIndex == item.correctIndex;
                                                
                                                return GestureDetector(
                                                  onTap: () => _toggleItem(index),
                                                  child: AnimatedContainer(
                                                    duration: const Duration(milliseconds: 250),
                                                    curve: Curves.easeInOut,
                                                    padding: const EdgeInsets.all(10),
                                                    decoration: BoxDecoration(
                                                      color: isSaved 
                                                        ? Colors.amber.withAlpha(20) 
                                                        : (isCorrect ? Colors.white.withAlpha(10) : Colors.redAccent.withAlpha(20)),
                                                      borderRadius: BorderRadius.circular(12),
                                                      border: Border.all(
                                                        color: isSaved 
                                                          ? Colors.amber 
                                                          : (isCorrect ? Colors.white10 : Colors.redAccent.withAlpha(80)),
                                                        width: (isSaved || !isCorrect) ? 1.5 : 1,
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
                                                        TweenAnimationBuilder<double>(
                                                          tween: Tween(begin: 0.8, end: 1.0),
                                                          duration: const Duration(milliseconds: 200),
                                                          builder: (context, value, child) {
                                                            return Transform.scale(
                                                              scale: isSaved ? value : 1.0,
                                                              child: _modeBadgeWidget(item.mode),
                                                            );
                                                          },
                                                        ),
                                                        const SizedBox(width: 10),
                                                        Expanded(
                                                          child: Column(
                                                            crossAxisAlignment: CrossAxisAlignment.start,
                                                            children: [
                                                              Row(
                                                                children: [
                                                                  Expanded(
                                                                    child: Text(
                                                                      item.prompt,
                                                                      style: TextStyle(
                                                                        color: isSaved ? Colors.amber : Colors.white, 
                                                                        fontWeight: FontWeight.bold, 
                                                                        fontSize: 13
                                                                      ),
                                                                      maxLines: 1,
                                                                      overflow: TextOverflow.ellipsis,
                                                                    ),
                                                                  ),
                                                                ],
                                                              ),
                                                              Row(
                                                                children: [
                                                                  Text(
                                                                    '${_modeOperator(item.mode)} ${item.correctText}',
                                                                    style: TextStyle(
                                                                      color: isSaved ? Colors.amber.withAlpha(179) : Colors.white.withAlpha(153), 
                                                                      fontSize: 11,
                                                                      fontStyle: FontStyle.italic,
                                                                    ),
                                                                    maxLines: 1,
                                                                    overflow: TextOverflow.ellipsis,
                                                                  ),
                                                                  if (_getTurkishMeaning(item) != null) ...[
                                                                    const SizedBox(width: 6),
                                                                    Expanded(
                                                                      child: Text(
                                                                        '(${_getTurkishMeaning(item)})',
                                                                        style: TextStyle(
                                                                          color: isSaved ? Colors.amber.withAlpha(128) : Colors.amber.withAlpha(100), 
                                                                          fontSize: 10,
                                                                          fontStyle: FontStyle.italic,
                                                                        ),
                                                                        maxLines: 1,
                                                                        overflow: TextOverflow.ellipsis,
                                                                      ),
                                                                    ),
                                                                  ],
                                                                ],
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                        const SizedBox(width: 8),
                                                        Icon(
                                                          isSaved ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                                                          color: isSaved ? Colors.amber : Colors.white24,
                                                          size: 20,
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                );
                                              },
                                            ),
                                          ),
                                  ),
                                  // Alt Kısım - Kaydet Butonu
                                  if (items.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
                                      child: SizedBox(
                                        width: double.infinity,
                                        height: 52,
                                        child: AnimatedScale(
                                          scale: _selectedIndices.isNotEmpty ? 1.02 : 1.0,
                                          duration: const Duration(milliseconds: 200),
                                          child: ElevatedButton(
                                            onPressed: _selectedIndices.isNotEmpty ? () {
                                              TopToast.show(
                                                context,
                                                title: 'Koleksiyon Güncellendi',
                                                message: '${_selectedIndices.length} kelime havuzunuzda hazır.',
                                                icon: Icons.auto_awesome,
                                                color: Colors.amber,
                                              );
                                            } : null,
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.amber,
                                              foregroundColor: Colors.black,
                                              disabledBackgroundColor: Colors.white.withAlpha(26),
                                              disabledForegroundColor: Colors.white24,
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                              elevation: _selectedIndices.isNotEmpty ? 12 : 0,
                                              shadowColor: Colors.amber.withAlpha(128),
                                            ),
                                            child: Row(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                Icon(
                                                  _selectedIndices.isNotEmpty ? Icons.auto_awesome : Icons.bookmark_add_outlined,
                                                  size: 20,
                                                ),
                                                const SizedBox(width: 10),
                                                Text(
                                                  _selectedIndices.isNotEmpty 
                                                      ? '${_selectedIndices.length} KELİMEYİ KAYDET'
                                                      : 'KAYDEDİLECEK KELİME SEÇİN',
                                                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.5),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),

                          // 3. Reklam Alanı
                          Container(
                            margin: const EdgeInsets.all(16),
                            height: 250,
                            decoration: BoxDecoration(
                              color: Colors.black26,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.blueAccent.withAlpha(38)),
                            ),
                            child: const Stack(
                              alignment: Alignment.center,
                              children: [
                                AdBannerWidget(isMediumRectangle: true, height: 250),
                              ],
                            ),
                          ),

                          // 4. Alt Butonlar
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 6, 20, 20),
                            child: Row(
                              children: [
                                IconButton(
                                  onPressed: () => ShareService.instance.shareWidgetAsImage(_boundaryKey, 'LUGORENA\'da düello skoruma bak!'),
                                  icon: const Icon(Icons.share, color: Colors.white),
                                  style: IconButton.styleFrom(
                                    backgroundColor: Colors.white.withAlpha(26),
                                    padding: const EdgeInsets.all(14),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: _requestRematch,
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.white,
                                      side: const BorderSide(color: Colors.white24),
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                    child: const Text('RÖVANŞ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: () => Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF6C27FF),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      elevation: 4,
                                    ),
                                    child: const Text('DEVAM ET', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
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
                  ),
                );
              },
            ),

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

  Widget _vibrantScoreboard(int left, int right, int leftLp, int rightLp, int lpChange) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // User Player
        _playerResultCircle(
          name: context.read<LanguageProvider>().getString('you'),
          score: left,
          avatarUrl: _userProfilePhoto,
          avatarEmoji: _userAvatarEmoji,
          lpChange: lpChange,
          isWinner: left > right,
          color: const Color(0xFF2AA7FF),
        ),
        
        // VS Icon
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Opacity(
            opacity: 0.5,
            child: Icon(Icons.close_rounded, color: Colors.white, size: 24),
          ),
        ),

        // Bot Player
        _playerResultCircle(
          name: widget.botName ?? context.read<LanguageProvider>().getString('opponent_name'),
          score: right,
          avatarUrl: null,
          avatarEmoji: widget.botAvatar ?? '🤖',
          lpChange: -lpChange,
          isWinner: right > left,
          color: const Color(0xFFFF9800),
        ),
      ],
    );
  }

  Widget _playerResultCircle({
    required String name,
    required int score,
    String? avatarUrl,
    String? avatarEmoji,
    int? lpChange,
    required bool isWinner,
    required Color color,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          alignment: Alignment.bottomRight,
          children: [
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isWinner ? Colors.greenAccent : color,
                  width: 3,
                ),
                boxShadow: [
                  BoxShadow(
                    color: (isWinner ? Colors.greenAccent : color).withAlpha(80),
                    blurRadius: 15,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: _buildAvatarWidget(avatarUrl, avatarEmoji),
            ),
            if (isWinner)
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.amber,
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)],
                  ),
                  child: const Icon(Icons.emoji_events, size: 14, color: Colors.black),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          name,
          style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500),
        ),
        Text(
          '$score',
          style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900),
        ),
        if (lpChange != null && lpChange != 0)
          Text(
            '${lpChange > 0 ? "+" : ""}$lpChange LP',
            style: TextStyle(
              color: lpChange > 0 ? Colors.greenAccent : Colors.redAccent,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
      ],
    );
  }

  Widget _buildAvatarWidget(String? url, String? emoji) {
    if (url != null && url.isNotEmpty) {
      return Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _buildEmojiOrAssetAvatar(emoji),
      );
    }
    return _buildEmojiOrAssetAvatar(emoji);
  }

  Widget _buildEmojiOrAssetAvatar(String? emoji) {
    if (emoji == null) return const Center(child: Text('👤', style: TextStyle(fontSize: 32)));

    String displayValue = emoji;
    // Eğer emoji bir path değilse ve emoji listesinde veya cosmetic listesinde bir ID ise asset path'ini bulmaya çalış
    if (!emoji.startsWith('assets/') && emoji.length > 2) {
      try {
        final item = CosmeticItem.availableItems.firstWhere((i) => i.id == emoji);
        displayValue = item.previewValue;
      } catch (_) {}
    }

    if (displayValue.startsWith('assets/')) {
      return Image.asset(displayValue, fit: BoxFit.cover);
    }

    return Center(child: Text(displayValue, style: const TextStyle(fontSize: 32)));
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

  Widget _compactBonusItem(String emoji, int value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        '$emoji +$value',
        style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }
  String? _getTurkishMeaning(AnsweredEntry item) {
    if (item.turkishMeaning != null && item.turkishMeaning!.isNotEmpty) {
      return item.turkishMeaning;
    }
    if (item.mode == QuestionMode.enToTr) return null;
    if (item.mode == QuestionMode.trToEn) return null;
    return WordPoolService.instance.getTurkishMeaning(item.prompt) ?? 
           WordPoolService.instance.getTurkishMeaning(item.correctText);
  }

  Widget _buildLPBar() {
    final startLp = widget.userLp;
    final endLp = startLp + widget.lpChange;
    
    final tier = LeagueTier.fromScore(endLp);
    
    // Alt ve üst sınırları belirle
    final minPts = tier.minPoints;
    final maxPts = tier.maxPoints;
    
    // Progress calculation
    double startRatio = (startLp - minPts) / (maxPts - minPts);
    double endRatio = (endLp - minPts) / (maxPts - minPts);
    
    return Container(
      width: 280,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(13),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${tier.icon} ${tier.name}',
                style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 12),
              ),
              TweenAnimationBuilder<int>(
                duration: const Duration(milliseconds: 2000),
                tween: IntTween(begin: startLp, end: endLp),
                builder: (context, value, child) {
                  return Text(
                    '$value LP',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          Stack(
            children: [
              Container(
                height: 8,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              TweenAnimationBuilder<double>(
                duration: const Duration(milliseconds: 2000),
                tween: Tween<double>(
                  begin: startRatio.clamp(0.0, 1.0),
                  end: endRatio.clamp(0.0, 1.0),
                ),
                builder: (context, value, child) {
                  return FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: value.clamp(0.001, 1.0),
                    child: Container(
                      height: 8,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF6C27FF), Color(0xFF2AA7FF)],
                        ),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
