import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../app.dart';
import '../../models/answered_entry.dart';
import '../../providers/game_provider.dart';
import '../../widgets/common/ad_banner_widget.dart';
import 'matchmaking_screen.dart';
import '../../models/league.dart';
import 'package:lugorena/services/online_duel_service.dart';
import '../../models/friend.dart';
import '../../services/ad_service.dart';
import '../../widgets/game/league_promotion_dialog.dart';
import '../../services/friend_service.dart';
import '../../providers/language_provider.dart';
import '../../services/sound_service.dart';
import '../../services/word_pool_service.dart';
import '../../models/question_mode.dart';
import '../../widgets/common/top_toast.dart';
import 'package:lugorena/models/cosmetic_item.dart';

class OnlineDuelResultsScreen extends StatefulWidget {
  final bool isWinner;
  final int myScore;
  final int opponentScore;
  final String opponentName;
  final String myName;
  final int totalQuestions;
  final bool isDemo;
  final List<AnsweredEntry> answeredItems;
  final String? myAvatarEmoji;
  final String? opponentAvatarEmoji;
  final String? opponentId;
  final String? leagueCode;

  final int? lpChange;
  final int? leaguePoints;
  final int? userLp;

  /// Bu maç bir rövanş maçı ise true. AdService rövanş zinciri bitene kadar
  /// reklamı erteler.
  final bool isRematch;

  const OnlineDuelResultsScreen({
    super.key,
    required this.isWinner,
    required this.myScore,
    required this.opponentScore,
    required this.opponentName,
    this.myName = 'Sen',
    this.totalQuestions = 10,
    this.isDemo = false,
    this.answeredItems = const [],
    this.myAvatarEmoji,
    this.opponentAvatarEmoji,
    this.opponentId,
    this.leagueCode,
    this.lpChange,
    this.leaguePoints,
    this.userLp,
    this.isRematch = false,
  });

  @override
  State<OnlineDuelResultsScreen> createState() => _OnlineDuelResultsScreenState();
}

class _OnlineDuelResultsScreenState extends State<OnlineDuelResultsScreen>
    with TickerProviderStateMixin {
  late AnimationController _mainController;
  // ignore: unused_field - Animasyonlar ileride kullanılacak
  late Animation<double> _scaleAnimation;
  // ignore: unused_field - Animasyonlar ileride kullanılacak
  late Animation<double> _fadeAnimation;
  late AnimationController _bounceController;
  // ignore: unused_field - Animasyonlar ileride kullanılacak
  late Animation<double> _bounceAnimation;
  late ConfettiController _confettiController;
  final ScrollController _scrollController = ScrollController();

  bool _showWordsList = false;
  final Set<int> _selectedWords = {};
  bool get _allSelected => _selectedWords.length == widget.answeredItems.length && widget.answeredItems.isNotEmpty;

  void _checkPromotion() {
    if (widget.userLp == null || widget.lpChange == null) return;
    
    final int startLp = widget.userLp!;
    final int endLp = startLp + widget.lpChange!;
    
    final startTier = LeagueTier.fromScore(startLp);
    final endTier = LeagueTier.fromScore(endLp);
    
    if (endTier.index > startTier.index) {
        Future.delayed(const Duration(milliseconds: 1500), () {
            if (mounted) {
                LeaguePromotionDialog.show(context, endTier);
            }
        });
    }
  }

  @override
  void initState() {
    super.initState();
    _confettiController =
        ConfettiController(duration: const Duration(seconds: 3));

    // Reklam servisini bilgilendir — rövanş zinciri bitmeden gösterilmez.
    AdService.instance.onDuelCompleted(
      isRematch: widget.isRematch,
      rematchChainEnded: false,
    );

    if (widget.isWinner) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
           _confettiController.play();
           _checkPromotion();
        }
      });
    }

    // Animasyon kontrolcülerini başlat
    _mainController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _mainController, curve: Curves.elasticOut),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _mainController, curve: Curves.easeIn),
    );
    _bounceController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    _bounceAnimation = Tween<double>(begin: 0.0, end: 10.0).animate(
      CurvedAnimation(parent: _bounceController, curve: Curves.easeInOut),
    );

    _mainController.forward();

    // Kazandıysa confetti ve ses başlat
    if (widget.isWinner && widget.myScore > widget.opponentScore) {
      _confettiController.play();
      SoundService.instance.playSuccess();
    }
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _mainController.dispose();
    _bounceController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDraw = widget.myScore == widget.opponentScore;

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
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Column(
                    children: [
                      // 1. Skor Özeti
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: Center(
                          child: _buildCompactResultHeader(isDraw),
                        ),
                      ),

                      // 2. Çıkmış Kelimeler (Sınırlı yükseklik ve içten kaydırma)
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                        height: 280, // Sabit yükseklik: 3-4 kelime + buton sığacak şekilde
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(13),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: _buildWordsList(),
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

                      // 4. Butonlar
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                        child: _buildActionButtons(),
                      ),

                      // Navigasyon barı için boşluk
                      SizedBox(height: MediaQuery.of(context).padding.bottom),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildCompactResultHeader(bool isDraw) {
    String title;
    Color titleColor;
    String emoji;

    final languageProvider = context.read<LanguageProvider>();
    if (isDraw) {
      title = languageProvider.getString('draw_title');
      titleColor = Colors.orange;
      emoji = '🤝';
    } else if (widget.isWinner) {
      title = languageProvider.getString('win_title');
      titleColor = Colors.green;
      emoji = '🏆';
    } else {
      title = languageProvider.getString('lose_title');
      titleColor = Colors.red;
      emoji = '😢';
    }

    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Column(
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: titleColor,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 12),
          _vibrantScoreboard(),
          const SizedBox(height: 20),
          _buildLPBar(),
        ],
      ),
    );
  }

  Widget _vibrantScoreboard() {
    final isDraw = widget.myScore == widget.opponentScore;
    final iWon = widget.isWinner && !isDraw;
    final theyWon = !widget.isWinner && !isDraw;
    
    final myLpChange = widget.lpChange ?? (iWon ? 25 : (isDraw ? 2 : -15));
    final opponentLpChange = -(widget.lpChange ?? (iWon ? 25 : (isDraw ? 2 : -15)));

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _playerResultCircle(
          name: widget.myName,
          score: widget.myScore,
          avatarEmoji: widget.myAvatarEmoji,
          lpChange: myLpChange,
          isWinner: iWon,
          color: const Color(0xFF2AA7FF),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Opacity(
            opacity: 0.3,
            child: Icon(Icons.close_rounded, color: Colors.white, size: 20),
          ),
        ),
        _playerResultCircle(
          name: widget.opponentName,
          score: widget.opponentScore,
          avatarEmoji: widget.opponentAvatarEmoji,
          lpChange: opponentLpChange,
          isWinner: theyWon,
          color: const Color(0xFFFF9800),
        ),
      ],
    );
  }

  Widget _playerResultCircle({
    required String name,
    required int score,
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
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isWinner ? Colors.greenAccent : color,
                  width: 3,
                ),
                boxShadow: [
                  BoxShadow(
                    color: (isWinner ? Colors.greenAccent : color).withAlpha(80),
                    blurRadius: 12,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Center(
                child: _buildAvatarContent(avatarEmoji ?? name[0].toUpperCase(), color),
              ),
            ),
            if (isWinner)
              Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.amber,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.emoji_events, size: 12, color: Colors.black),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          name,
          style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w500),
        ),
        Text(
          '$score',
          style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900),
        ),
        if (lpChange != null && lpChange != 0)
          Text(
            '${lpChange > 0 ? "+" : ""}$lpChange LP',
            style: TextStyle(
              color: lpChange > 0 ? Colors.greenAccent : Colors.redAccent,
              fontSize: 9,
              fontWeight: FontWeight.bold,
            ),
          ),
      ],
    );
  }

  Widget _buildAvatarContent(String avatarUrl, Color color) {
    if (avatarUrl.startsWith('http')) {
      return ClipOval(
        child: Image.network(
          avatarUrl,
          fit: BoxFit.cover,
          width: 50,
          height: 50,
          errorBuilder: (_, __, ___) => const Icon(Icons.person, color: Colors.white, size: 28),
        ),
      );
    } 

    String displayValue = avatarUrl;
    // Resolve asset path if it's an ID
    if (!avatarUrl.startsWith('assets/') && avatarUrl.length > 2) {
      try {
        final item = CosmeticItem.availableItems.firstWhere((i) => i.id == avatarUrl);
        displayValue = item.previewValue;
      } catch (_) {}
    }

    if (displayValue.startsWith('assets/')) {
      return ClipOval(
        child: Image.asset(
          displayValue,
          fit: BoxFit.cover,
          width: 50,
          height: 50,
        ),
      );
    }

    return Text(
      displayValue,
      style: const TextStyle(fontSize: 28),
    );
  }

  Widget _buildScoreCards() {
    final isDraw = widget.myScore == widget.opponentScore;
    final iWon = widget.isWinner && !isDraw;
    final theyWon = !widget.isWinner && !isDraw;
    
    final myLpChange = widget.lpChange ?? (iWon ? 25 : (isDraw ? 2 : -15));
    final opponentLpChange = -(widget.lpChange ?? (iWon ? 25 : (isDraw ? 2 : -15)));
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          // Benim kartım (Sol - Yeşil)
          Expanded(
            child: _buildCompactPlayerCard(
              name: widget.myName,
              score: widget.myScore,
              avatarEmoji: widget.myAvatarEmoji,
              isWinner: iWon,
              cardColor: iWon ? Colors.green : Colors.blue,
              initial: 'S',
              lpChange: myLpChange,
            ),
          ),
          
          // VS
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              'VS',
              style: TextStyle(
                color: Colors.white60,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
          
          // Rakip kartı (Sağ - Kırmızı)
          Expanded(
            child: GestureDetector(
              onTap: (widget.isDemo || widget.opponentId == null) ? null : _showOpponentProfile,
              child: _buildCompactPlayerCard(
                name: widget.opponentName,
                score: widget.opponentScore,
                avatarEmoji: widget.opponentAvatarEmoji,
                isWinner: theyWon,
                cardColor: theyWon ? Colors.green : Colors.red.shade700,
                initial: widget.opponentName.isNotEmpty ? widget.opponentName[0].toUpperCase() : 'R',
                lpChange: opponentLpChange,
              ),
            ),
          ),
        ],
      ),
    );

  }

  Widget _buildCompactPlayerCard({
    required String name,
    required int score,
    String? avatarEmoji,
    required bool isWinner,
    required Color cardColor,
    required String initial,
    int? lpChange, // New param
  }) {
    String lpText = '';
    Color lpColor = Colors.white;
    
    if (lpChange != null) {
      if (lpChange > 0) {
        lpText = '+$lpChange LP';
        lpColor = Colors.greenAccent;
      } else if (lpChange < 0) {
        lpText = '$lpChange LP';
        lpColor = Colors.redAccent;
      } else {
        lpText = '+0 LP';
        lpColor = Colors.white70;
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            cardColor.withAlpha(102), 
            cardColor.withAlpha(51), 
          ],
        ),
        border: Border.all(
          color: cardColor.withAlpha(153), 
          width: 2,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Avatar
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              shape: BoxShape.circle, 
              
              color: cardColor.withAlpha(77), // Fixed typo: withValues -> withOpacity
              border: Border.all(color: Colors.white.withAlpha(128), width: 2), // Fixed typo: withValues -> withOpacity
            ),
            child: Center(
              child: _buildAvatarContent(avatarEmoji ?? initial, cardColor),
            ),
          ),
          const SizedBox(height: 6),
          
          // İsim
          Text(
            name,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          
          // Skor
          Text(
            '$score',
            style: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w900,
              color: cardColor,
              shadows: [
                Shadow(                  
                  color: cardColor.withAlpha(128), // Fixed typo: withValues -> withOpacity
                  blurRadius: 10,
                ),
              ],
            ),
          ),
          
          // LP Değişimi
          if (lpChange != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                lpText,
                style: TextStyle(
                  color: lpColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          
          // Kazanan rozet
          if (isWinner)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.emoji_events, color: Colors.amber, size: 14),
                  const SizedBox(width: 2),
                  Text(
                    context.watch<LanguageProvider>().getString('winner'),
                    style: const TextStyle(
                      color: Colors.amber,
                      fontWeight: FontWeight.bold,
                      fontSize: 9,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildShowWordsButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
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
                    : '${context.watch<LanguageProvider>().getString('show_words')} (${widget.answeredItems.length})',
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

  Widget _buildWordsList() { // This was previously _buildWordsList
    return Container(
      decoration: BoxDecoration(
        color: Colors.black38,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white12),
        boxShadow: [
          BoxShadow(            color: Colors.black.withAlpha(51),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header Row
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
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
                TextButton(
                  onPressed: _toggleSelectAll,
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: Colors.white54,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    _allSelected 
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
                itemCount: widget.answeredItems.length,
                separatorBuilder: (context, index) => const SizedBox(height: 4),
                itemBuilder: (context, index) {
              final item = widget.answeredItems[index];
              final isSelected = _selectedWords.contains(index);
              final isCorrect = item.selectedIndex == item.correctIndex;
              
              return GestureDetector(
                onTap: () => _toggleWord(index),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOut,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected 
                        ? Colors.amber.withAlpha(20) 
                        : (isCorrect ? Colors.white.withAlpha(10) : Colors.redAccent.withAlpha(20)),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? Colors.amber 
                          : (isCorrect ? Colors.white10 : Colors.redAccent.withAlpha(80)),
                      width: isSelected || !isCorrect ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: (isCorrect ? Colors.green : Colors.red).withAlpha(40),
                        ),
                        child: Icon(
                          isCorrect ? Icons.check_rounded : Icons.close_rounded,
                          size: 18,
                          color: isCorrect ? Colors.greenAccent : Colors.redAccent,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.correctText,
                              style: TextStyle(
                                color: isSelected ? Colors.amber : Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              '${item.prompt} (${_getTurkishMeaning(item) ?? ""})',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        isSelected ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                        color: isSelected ? Colors.amber : Colors.white24,
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
          
          // Add to my words footer
          if (widget.answeredItems.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: AnimatedScale(
                  scale: _selectedWords.isNotEmpty ? 1.02 : 1.0,
                  duration: const Duration(milliseconds: 200),
                  child: ElevatedButton(
                    onPressed: _selectedWords.isNotEmpty ? _addToMyWords : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber,
                      foregroundColor: Colors.black,
                      disabledBackgroundColor: Colors.white.withAlpha(26),
                      disabledForegroundColor: Colors.white24,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: _selectedWords.isNotEmpty ? 12 : 0,
                      shadowColor: Colors.amber.withAlpha(128),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _selectedWords.isNotEmpty ? Icons.auto_awesome : Icons.bookmark_add_outlined,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          _selectedWords.isNotEmpty 
                              ? '${_selectedWords.length} KELİMEYİ KAYDET'
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
    );
  }

  void _toggleWord(int index) {
    setState(() {
      if (_selectedWords.contains(index)) {
        _selectedWords.remove(index);
      } else {
        _selectedWords.add(index);
      }
    });
  }

  void _toggleSelectAll() {
    setState(() {
      if (_allSelected) {
        _selectedWords.clear();
      } else {
        _selectedWords.addAll(List.generate(widget.answeredItems.length, (index) => index));
      }
    });
  }

  void _addToMyWords() {
    if (_selectedWords.isEmpty) return;

    final gameProvider = context.read<GameProvider>();
    int addedCount = 0;

    for (final index in _selectedWords) {
      final item = widget.answeredItems[index];
      if (!gameProvider.isSaved(item)) {
        gameProvider.addToPool(item);
        addedCount++;
      }
    }

    setState(() {
      _selectedWords.clear();
    });

    if (mounted) {
      TopToast.show(
        context,
        title: 'Koleksiyon Güncellendi',
        message: '$addedCount yeni kelime havuzunuza katıldı.',
        icon: Icons.auto_awesome,
        color: Colors.amber,
      );
    }
  }

  void _goHome() {
    AdService.instance.onRematchChainEnded();
    final nav = navigatorKey.currentState ?? Navigator.of(context);
    nav.pushNamedAndRemoveUntil('/home', (_) => false);
  }

  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          // Ana menü butonu
          Expanded(
            child: ElevatedButton(
              onPressed: _goHome,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3F51B5), // Belirgin İndigo rengi
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: Colors.white10),
                ),
                elevation: 4,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.home_rounded, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    context.read<LanguageProvider>().getString('home').toUpperCase(),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(width: 12),
          
          // Tekrar oyna butonu (Daha Belirgin)
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.amber.withAlpha(76), // 0.3 * 255 = 76.5
                    blurRadius: 15,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: ElevatedButton.icon(
                onPressed: () async {
                  if (widget.isDemo || widget.opponentId == null) {
                    _goHome();
                    return;
                  }

                  // Show loading
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (context) => const Center(child: CircularProgressIndicator()),
                  );

                  final friend = Friend(
                    userId: widget.opponentId!,
                    username: widget.opponentName,
                  );

                  await FriendService.instance.sendFriendRequest(friend);

                  final match = await OnlineDuelService.instance.inviteFriend(
                    friend,
                    widget.leagueCode ?? 'A1',
                  );

                  if (mounted) {
                    Navigator.pop(context); // Close loading
                    if (match != null) {
                      // Rövanş zinciri devam ediyor — MatchmakingScreen'e
                      // isRematch=true bilgisi ile yönlendir.
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => MatchmakingScreen(
                            leagueCode: widget.leagueCode ?? 'A1',
                            existingMatch: match,
                            isRematch: true,
                          ),
                        ),
                      );
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.bolt_rounded),
                label: Text(
                  widget.isDemo 
                    ? context.watch<LanguageProvider>().getString('play_again').toUpperCase()
                    : context.watch<LanguageProvider>().getString('rematch').toUpperCase(),
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 1.2),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showOpponentProfile() async {
    try {
      if (widget.opponentId == null) return;
      
      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );
      
      try {
        final profile = await OnlineDuelService.instance.firestore.collection('users').doc(widget.opponentId).get();
        final h2h = await OnlineDuelService.instance.getHeadToHeadScore(widget.opponentId!);
        
        if (!mounted) return;
        Navigator.pop(context); // Close loading
        
        if (!profile.exists) return;
        final data = profile.data()!;

        final languageProvider = context.read<LanguageProvider>();
        showDialog(
          context: context,
          builder: (context) => Dialog(
            backgroundColor: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF1A3A5C),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white24),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: Colors.white10,
                    child: Builder(
                      builder: (context) {
                        final avatarId = data['avatarId'] as String?;
                        if (avatarId == null || avatarId.isEmpty) {
                          return const Text('👤', style: TextStyle(fontSize: 40));
                        }
                        
                        final items = CosmeticItem.availableItems.where((i) => i.id == avatarId);
                        if (items.isEmpty) return const Text('👤', style: TextStyle(fontSize: 40));
                        
                        final previewValue = items.first.previewValue;
                        if (previewValue.startsWith('assets/')) {
                          return Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Image.asset(previewValue, fit: BoxFit.contain),
                          );
                        }
                        return Text(previewValue, style: const TextStyle(fontSize: 40));
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    data['username'] ?? languageProvider.getString('opponent_name'),
                    style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '${languageProvider.getString('level')} ${data['level'] ?? 1}',
                    style: const TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                  const Divider(color: Colors.white12, height: 32),
                  
                  Text(languageProvider.getString('duel_performance').toUpperCase(), style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 12)),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('${h2h['me']}', style: const TextStyle(color: Colors.blue, fontSize: 32, fontWeight: FontWeight.w900)),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Text('-', style: TextStyle(color: Colors.white60, fontSize: 24)),
                      ),
                      Text('${h2h['opponent']}', style: const TextStyle(color: Colors.red, fontSize: 32, fontWeight: FontWeight.w900)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      } catch (e) {
        if (mounted) {
          Navigator.pop(context); // Close loading in case of error
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Profil yüklenirken bir hata oluştu: $e')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Bir hata oluştu: $e')),
        );
      }
    }
  }

  String? _getTurkishMeaning(AnsweredEntry item) {
    // 1. Eğer modelde varsa kullan
    if (item.turkishMeaning != null && item.turkishMeaning!.isNotEmpty) {
      return item.turkishMeaning;
    }
    
    // 2. Eğer mod En->Tr ise doğru cevap zaten Türkçedir, tekrar yazmaya gerek yok
    if (item.mode == QuestionMode.enToTr) return null;
    
    // 3. Eğer mod Tr->En ise prompt zaten Türkçedir
    if (item.mode == QuestionMode.trToEn) return null;
    
    // 4. Eş anlamlı sorularda (En->En) Türkçe'yi havuzdan çekmeyi dene
    return WordPoolService.instance.getTurkishMeaning(item.prompt) ?? 
           WordPoolService.instance.getTurkishMeaning(item.correctText);
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
        return const Text('🇹🇷➡️🇬🇧', style: TextStyle(fontSize: 12));
      case QuestionMode.enToTr:
        return const Text('🇬🇧➡️🇹🇷', style: TextStyle(fontSize: 12));
      case QuestionMode.engToEng:
        return const Text('🇬🇧＝🇬🇧', style: TextStyle(fontSize: 12));
    }
  }

  Widget _buildLPBar() {
    final startLp = widget.userLp ?? 1500;
    final endLp = startLp + (widget.lpChange ?? 0);
    
    final tier = LeagueTier.fromScore(endLp);
    
    // Alt ve üst sınırları belirle
    final minPts = tier.minPoints;
    final maxPts = tier.maxPoints;
    
    // Progress calculation
    double startRatio = (startLp - minPts) / (maxPts - minPts);
    double endRatio = (endLp - minPts) / (maxPts - minPts);
    
    return Container(
      width: 280,
      padding: const EdgeInsets.all(16),
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
                style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 13),
              ),
              TweenAnimationBuilder<int>(
                duration: const Duration(milliseconds: 2000),
                tween: IntTween(begin: startLp, end: endLp),
                builder: (context, value, child) {
                  return Text(
                    '$value LP',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 10),
          Stack(
            children: [
              Container(
                height: 10,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(5),
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
                      height: 10,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF6C27FF), Color(0xFF2AA7FF)],
                        ),
                        borderRadius: BorderRadius.circular(5),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF6C27FF).withAlpha(102),
                            blurRadius: 8,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('$minPts', style: const TextStyle(color: Colors.white38, fontSize: 10)),
              Text('$maxPts', style: const TextStyle(color: Colors.white38, fontSize: 10)),
            ],
          ),
        ],
      ),
    );
  }
}

