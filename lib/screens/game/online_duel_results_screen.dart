import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/answered_entry.dart';
import '../../providers/game_provider.dart';
import '../../widgets/game/game_confetti.dart';
import '../../widgets/common/ad_banner_widget.dart';

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

  final Set<int> _selectedWords = {};
  bool _showWordsList = false;
  bool _allSelected = false;

  @override
  void initState() {
    super.initState();

    _confettiController = ConfettiController(duration: const Duration(seconds: 3));

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
    
    // Kazandıysa confetti başlat
    if (widget.isWinner && widget.myScore != widget.opponentScore) {
      _confettiController.play();
    }
    
    // Tüm kelimeleri seçili olarak başlat
    for (int i = 0; i < widget.answeredItems.length; i++) {
      _selectedWords.add(i);
    }
    _allSelected = widget.answeredItems.isNotEmpty;
  }

  @override
  void dispose() {
    _mainController.dispose();
    _bounceController.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  void _toggleSelectAll() {
    setState(() {
      if (_allSelected) {
        _selectedWords.clear();
        _allSelected = false;
      } else {
        for (int i = 0; i < widget.answeredItems.length; i++) {
          _selectedWords.add(i);
        }
        _allSelected = true;
      }
    });
  }

  void _toggleWord(int index) {
    setState(() {
      if (_selectedWords.contains(index)) {
        _selectedWords.remove(index);
        _allSelected = false;
      } else {
        _selectedWords.add(index);
        if (_selectedWords.length == widget.answeredItems.length) {
          _allSelected = true;
        }
      }
    });
  }

  void _addToMyWords() {
    if (_selectedWords.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lütfen en az bir kelime seçin'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final gameProvider = context.read<GameProvider>();
    int addedCount = 0;

    for (final index in _selectedWords) {
      final entry = widget.answeredItems[index];
      // GameProvider addToPool metodunu kullan
      if (!gameProvider.isSaved(entry)) {
        gameProvider.addToPool(entry);
        addedCount++;
      }
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 8),
              Text('$addedCount kelime My Words\'e eklendi'),
            ],
          ),
          backgroundColor: const Color(0xFF2E5A8C),
        ),
      );
    }
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
        child: Stack(
          children: [
            // Confetti sadece kazanınca
            if (widget.isWinner && !isDraw)
              GameConfetti(controller: _confettiController),
            
            SafeArea(
              child: Column(
                children: [
                  const SizedBox(height: 16),
                  
                  // Sonuç başlığı (kompakt)
                  _buildCompactResultHeader(isDraw),
                  
                  const SizedBox(height: 16),
                  
                  // Skor kartları
                  _buildScoreCards(),
                  
                  const SizedBox(height: 12),
                  
                  // Kelime listesi toggle
                  if (widget.answeredItems.isNotEmpty)
                    _buildWordsToggle(),
                  
                  // Kelime listesi
                  if (_showWordsList && widget.answeredItems.isNotEmpty)
                    Expanded(child: _buildWordsList()),
                  
                  if (!_showWordsList)
                    const Spacer(),
                  
                  // Reklam banner (chess.com tarzı)
                  const AdBannerWidget(),
                  
                  // Butonlar
                  _buildActionButtons(),
                  
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactResultHeader(bool isDraw) {
    String title;
    Color titleColor;
    String emoji;

    if (isDraw) {
      title = 'BERABERE';
      titleColor = Colors.orange;
      emoji = '🤝';
    } else if (widget.isWinner) {
      title = 'KAZANDIN!';
      titleColor = Colors.green;
      emoji = '🏆';
    } else {
      title = 'KAYBETTİN';
      titleColor = Colors.red;
      emoji = '😢';
    }

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: titleColor.withOpacity(0.2),
            border: Border.all(color: titleColor, width: 2),
          ),
          child: Text(emoji, style: const TextStyle(fontSize: 40)),
        ),
        const SizedBox(height: 10),
        Text(
          title,
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: titleColor,
          ),
        ),
      ],
    );
  }

  Widget _buildScoreCards() {
    final isDraw = widget.myScore == widget.opponentScore;
    final iWon = widget.isWinner && !isDraw;
    final theyWon = !widget.isWinner && !isDraw;
    
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
            child: _buildCompactPlayerCard(
              name: widget.opponentName,
              score: widget.opponentScore,
              avatarEmoji: widget.opponentAvatarEmoji,
              isWinner: theyWon,
              cardColor: theyWon ? Colors.green : Colors.red.shade700,
              initial: widget.opponentName.isNotEmpty ? widget.opponentName[0].toUpperCase() : 'R',
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
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            cardColor.withOpacity(0.4),
            cardColor.withOpacity(0.2),
          ],
        ),
        border: Border.all(
          color: cardColor.withOpacity(0.6),
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
              color: cardColor.withOpacity(0.3),
              border: Border.all(color: Colors.white.withOpacity(0.5), width: 2),
            ),
            child: Center(
              child: avatarEmoji != null && avatarEmoji.isNotEmpty
                  ? Text(avatarEmoji, style: const TextStyle(fontSize: 28))
                  : Text(
                      initial,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: cardColor,
                      ),
                    ),
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
                  color: cardColor.withOpacity(0.5),
                  blurRadius: 10,
                ),
              ],
            ),
          ),
          
          // Kazanan rozet
          if (isWinner)
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.emoji_events, color: Colors.amber, size: 14),
                  SizedBox(width: 2),
                  Text(
                    'KAZANAN',
                    style: TextStyle(
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

  Widget _buildWordsToggle() {
    return GestureDetector(
      onTap: () => setState(() => _showWordsList = !_showWordsList),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white24),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _showWordsList ? Icons.expand_less : Icons.expand_more,
              color: Colors.white70,
            ),
            const SizedBox(width: 8),
            Text(
              _showWordsList ? 'Kelimeleri Gizle' : 'Kelimeleri Göster (${widget.answeredItems.length})',
              style: const TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWordsList() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        children: [
          // Tümünü seç / kaldır butonu
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Çıkan Kelimeler',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              TextButton.icon(
                onPressed: _toggleSelectAll,
                icon: Icon(
                  _allSelected ? Icons.deselect : Icons.select_all,
                  size: 18,
                  color: Colors.amber,
                ),
                label: Text(
                  _allSelected ? 'Tümünü Kaldır' : 'Tümünü Seç',
                  style: const TextStyle(color: Colors.amber),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          
          // Kelime listesi
          Expanded(
            child: ListView.builder(
              itemCount: widget.answeredItems.length,
              itemBuilder: (context, index) {
                final item = widget.answeredItems[index];
                final isSelected = _selectedWords.contains(index);
                final isCorrect = item.selectedIndex == item.correctIndex;
                
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: isCorrect
                        ? Colors.green.withOpacity(0.2)
                        : Colors.red.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected ? Colors.amber : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: ListTile(
                    onTap: () => _toggleWord(index),
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isCorrect
                            ? Colors.green.withOpacity(0.3)
                            : Colors.red.withOpacity(0.3),
                      ),
                      child: Icon(
                        isCorrect ? Icons.check : Icons.close,
                        color: isCorrect ? Colors.green : Colors.red,
                      ),
                    ),
                    title: Text(
                      item.correctText,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(
                      item.prompt,
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 12,
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Puan
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.deepPurple.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '+${item.earnedPoints}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Seçim checkbox
                        Checkbox(
                          value: isSelected,
                          onChanged: (_) => _toggleWord(index),
                          activeColor: Colors.amber,
                          checkColor: Colors.black,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          
          // My Words'e ekle butonu
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _selectedWords.isNotEmpty ? _addToMyWords : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.bookmark_add),
              label: Text(
                'Seçilenleri My Words\'e Ekle (${_selectedWords.length})',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          // Ana menü butonu
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).popUntil((route) => route.isFirst);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey.shade700,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.home),
              label: const Text(
                'Ana Menü',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
          
          const SizedBox(width: 12),
          
          // Tekrar oyna butonu
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () {
                // Bir önceki ekrana dön (matchmaking veya online duel menü)
                Navigator.of(context).pop();
                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.refresh),
              label: const Text(
                'Tekrar Oyna',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
