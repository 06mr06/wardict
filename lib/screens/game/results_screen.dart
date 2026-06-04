import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/game_provider.dart';
import '../../models/question_mode.dart';
import 'package:confetti/confetti.dart';
import '../../services/sound_service.dart';
import '../../services/ad_service.dart';

import '../../widgets/common/ad_banner_widget.dart';
import '../../widgets/common/top_toast.dart';
import '../../models/answered_entry.dart';

class ResultsScreen extends StatefulWidget {
  const ResultsScreen({super.key});

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen> {
  late ConfettiController _confettiController;
  final ScrollController _scrollController = ScrollController();
  final Set<int> _selectedWords = {};

  void _toggleWord(int index) {
    setState(() {
      if (_selectedWords.contains(index)) {
        _selectedWords.remove(index);
      } else {
        _selectedWords.add(index);
      }
    });
  }

  void _addToMyWords(List<AnsweredEntry> items) {
    if (_selectedWords.isEmpty) return;

    final provider = Provider.of<GameProvider>(context, listen: false);
    int addedCount = 0;

    for (final index in _selectedWords) {
      final item = items[index];
      if (!provider.isSaved(item)) {
        provider.addToPool(item);
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

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 3));
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<GameProvider>(context, listen: false);
      if (provider.accuracy >= 0.7) {
        _confettiController.play();
        SoundService.instance.playSuccess();
      }
      // Reklam sayacını güncelle
      AdService.instance.onGameCompleted();
    });
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<GameProvider>(context);
    final total = provider.score;
    final items = provider.history;
    final accuracy = provider.accuracy;

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
                          // 1. Skor Alanı
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                            child: Center(
                              child: _buildScoreCard(accuracy, total),
                            ),
                          ),

                          // 2. Çıkmış Kelimeler
                          Flexible(
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 16),
                              constraints: const BoxConstraints(maxHeight: 400),
                              decoration: BoxDecoration(
                                color: Colors.white.withAlpha(13),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.white10),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text(
                                          'ÇIKMIŞ KELİMELER',
                                          style: TextStyle(color: Colors.amber, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1),
                                        ),
                                        GestureDetector(
                                          onTap: () {
                                            setState(() {
                                              if (_selectedWords.length == items.length) {
                                                _selectedWords.clear();
                                              } else {
                                                _selectedWords.addAll(List.generate(items.length, (index) => index));
                                              }
                                            });
                                          },
                                          child: Text(
                                            _selectedWords.length == items.length ? 'TEMİZLE' : 'TÜMÜNÜ SEÇ',
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
                                              padding: const EdgeInsets.all(12),
                                              itemCount: items.length,
                                              separatorBuilder: (context, index) => const SizedBox(height: 6),
                                              itemBuilder: (context, i) {
                                                final e = items[i];
                                                final isCorrect = e.selectedIndex == e.correctIndex && e.selectedIndex != -1;
                                                final isSelected = _selectedWords.contains(i);
                                                
                                                return GestureDetector(
                                                  onTap: () => _toggleWord(i),
                                                  child: AnimatedContainer(
                                                    duration: const Duration(milliseconds: 250),
                                                    curve: Curves.easeInOut,
                                                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                                                    decoration: BoxDecoration(
                                                      color: isSelected 
                                                          ? Colors.amber.withAlpha(20) 
                                                          : Colors.white.withAlpha(10),
                                                      borderRadius: BorderRadius.circular(12),
                                                      border: Border.all(
                                                        color: isSelected ? Colors.amber : Colors.white10,
                                                        width: isSelected ? 1.5 : 1,
                                                      ),
                                                      boxShadow: isSelected ? [
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
                                                              scale: isSelected ? value : 1.0,
                                                              child: Icon(
                                                                isCorrect ? Icons.check_circle_rounded : Icons.cancel_rounded,
                                                                color: isCorrect ? Colors.greenAccent : Colors.redAccent,
                                                                size: 18,
                                                              ),
                                                            );
                                                          },
                                                        ),
                                                        const SizedBox(width: 12),
                                                        Expanded(
                                                          child: Column(
                                                            crossAxisAlignment: CrossAxisAlignment.start,
                                                            children: [
                                                              Text(
                                                                e.correctText,
                                                                style: TextStyle(
                                                                  color: isSelected ? Colors.amber : Colors.white,
                                                                  fontSize: 14, 
                                                                  fontWeight: FontWeight.bold
                                                                ),
                                                                maxLines: 1,
                                                                overflow: TextOverflow.ellipsis,
                                                              ),
                                                              Text(
                                                                e.prompt + (e.turkishMeaning != null ? ' | ${e.turkishMeaning}' : ''),
                                                                style: TextStyle(
                                                                  color: isSelected ? Colors.amber.withAlpha(179) : Colors.white70,
                                                                  fontSize: 11, 
                                                                  fontStyle: FontStyle.italic
                                                                ),
                                                                maxLines: 1,
                                                                overflow: TextOverflow.ellipsis,
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                        const SizedBox(width: 8),
                                                        Icon(
                                                          isSelected ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                                                          color: isSelected ? Colors.amber : Colors.white24,
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
                                  // Alt Kısım - Kaydet Butonu
                                  if (items.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.all(12),
                                      child: SizedBox(
                                        width: double.infinity,
                                        height: 52,
                                        child: AnimatedScale(
                                          scale: _selectedWords.isNotEmpty ? 1.02 : 1.0,
                                          duration: const Duration(milliseconds: 200),
                                          child: ElevatedButton(
                                            onPressed: _selectedWords.isNotEmpty ? () => _addToMyWords(items) : null,
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
                                  const SizedBox(height: 6),
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
                            padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                            child: SizedBox(
                              width: double.infinity,
                              height: 54,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF6C27FF),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  elevation: 4,
                                ),
                                onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
                                child: const Text(
                                  'ANA SAYFAYA DÖN',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                              ),
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

            // Konfeti Efekti (En üstte)
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

  String _modeLabel(QuestionMode mode) {
    switch (mode) {
      case QuestionMode.trToEn:
        return 'TR → EN';
      case QuestionMode.enToTr:
        return 'EN → TR';
      case QuestionMode.engToEng:
        return 'ENG - ENG';
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
        return const Text('🇹🇷➡️🇬🇧', style: TextStyle(fontSize: 18));
      case QuestionMode.enToTr:
        return const Text('🇬🇧➡️🇹🇷', style: TextStyle(fontSize: 18));
      case QuestionMode.engToEng:
        return const Text('🇬🇧＝🇬🇧', style: TextStyle(fontSize: 18));
    }
  }

  Widget _buildScoreCard(double accuracy, int score) {
    final percentage = (accuracy * 100).round();
    final isGood = percentage >= 70;
    final isMedium = percentage > 30;

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
      performanceText = 'Daha Çok Çalışmalısın!';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [cardColor.withAlpha(51), cardColor.withAlpha(20)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: cardColor.withAlpha(128),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: cardColor.withAlpha(26),
            blurRadius: 12,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: cardColor.withAlpha(38),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isGood ? Icons.star_rounded : isMedium ? Icons.thumb_up_rounded : Icons.school_rounded,
              color: cardColor,
              size: 32,
            ),
          ),
          const SizedBox(width: 16),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'SKOR: $score',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    '%$percentage',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    performanceText,
                    style: TextStyle(
                      color: cardColor.withAlpha(230),
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
