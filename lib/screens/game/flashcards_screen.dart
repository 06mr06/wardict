import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/game_provider.dart';
import '../../models/question_mode.dart';
import '../../services/sound_service.dart';
import '../../services/tts_service.dart';

class FlashcardsScreen extends StatefulWidget {
  final bool reviewOnly;
  const FlashcardsScreen({super.key, this.reviewOnly = true});

  @override
  State<FlashcardsScreen> createState() => _FlashcardsScreenState();
}

class _FlashcardsScreenState extends State<FlashcardsScreen> with SingleTickerProviderStateMixin {
  int _index = 0;
  bool _flipped = false;
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggleFlip() {
    SoundService.instance.playClick();
    setState(() => _flipped = !_flipped);
    if (_flipped) {
      _controller.forward(from: 0);
    } else {
      _controller.reverse(from: 1);
    }
  }



  Widget _modeBadge(QuestionMode mode) {
    switch (mode) {
      case QuestionMode.trToEn:
        return const Text('🇹🇷➡️🇬🇧', style: TextStyle(fontSize: 18));
      case QuestionMode.enToTr:
        return const Text('🇬🇧➡️🇹🇷', style: TextStyle(fontSize: 18));
      case QuestionMode.engToEng:
        return const Text('🇬🇧＝🇬🇧', style: TextStyle(fontSize: 18));
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<GameProvider>(context);
    final items = widget.reviewOnly ? provider.readyForReview : provider.savedPool;
    
    if (items.isEmpty) {
      return Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: Colors.white,
        ),
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF2E5A8C), Color(0xFF1A3A5C)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.check_circle_outline, size: 80, color: Color(0xFF00F5A0)),
                const SizedBox(height: 24),
                const Text(
                  'Harika!',
                  style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Şu an tekrar edilecek kelime yok.\nYeni kelimeler öğrenmeye devam et!',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontSize: 16),
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00F5A0),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text('GERİ DÖN', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(widget.reviewOnly ? 'Akıllı Tekrar' : 'Kelime Çalışması', style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        actions: [
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
            ),
            child: Center(
              child: Text(
                '${_index + 1} / ${items.length}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
          )
        ],
      ),
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
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const SizedBox(height: 20),
                Expanded(
                  child: PageView.builder(
                    itemCount: items.length,
                    onPageChanged: (i) {
                      setState(() {
                        _index = i;
                        _flipped = false;
                        _controller.reset();
                      });
                    },
                    itemBuilder: (context, i) {
                      final item = items[i];
                      return GestureDetector(
                        onTap: _toggleFlip,
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            return Center(
                              child: AnimatedBuilder(
                                animation: _controller,
                                builder: (context, child) {
                                  final isCurrent = i == _index;
                                  final progress = (isCurrent && _flipped) ? _controller.value : 0.0;
                                  final angle = math.pi * progress;
                                  return Transform(
                                    alignment: Alignment.center,
                                    transform: Matrix4.identity()
                                      ..setEntry(3, 2, 0.001)
                                      ..rotateY(angle),
                                    child: Container(
                                      width: double.infinity,
                                      height: constraints.maxHeight * 0.8,
                                      margin: const EdgeInsets.symmetric(horizontal: 10),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: progress < 0.5 
                                          ? [Colors.white.withValues(alpha: 0.15), Colors.white.withValues(alpha: 0.05)]
                                          : [const Color(0xFF00F5A0).withValues(alpha: 0.2), const Color(0xFF00F5A0).withValues(alpha: 0.05)],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                        borderRadius: BorderRadius.circular(30),
                                        border: Border.all(
                                      color: progress < 0.5 ? Colors.white.withValues(alpha: 0.3) : const Color(0xFF00F5A0).withValues(alpha: 0.5),
                                          width: 2,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                        color: progress < 0.5 ? Colors.black26 : const Color(0xFF00F5A0).withValues(alpha: 0.2),
                                            blurRadius: 30,
                                            spreadRadius: 2,
                                          )
                                        ],
                                      ),
                                      alignment: Alignment.center,
                                      padding: const EdgeInsets.all(32),
                                      child: progress < 0.5
                                          ? Column(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                _modeBadge(item.mode),
                                                const SizedBox(height: 16),
                                                Text(
                                                  item.prompt,
                                                  textAlign: TextAlign.center,
                                                  style: const TextStyle(
                                                    fontSize: 34,
                                                    fontWeight: FontWeight.w900,
                                                    color: Colors.white,
                                                    letterSpacing: -1,
                                                  ),
                                                ),
                                                const SizedBox(height: 24),
                                                IconButton(
                                                  onPressed: () {
                                                    // Ön yüz dili tespit et
                                                    final isTr = item.mode == QuestionMode.trToEn;
                                                    TtsService.instance.speak(item.prompt, language: isTr ? "tr-TR" : "en-US");
                                                  },
                                                  icon: const Icon(Icons.volume_up_rounded, color: Colors.white70, size: 32),
                                                ),
                                                const SizedBox(height: 16),
                                                Text(
                                                  'Cevap için dokun',
                                                  style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 12),
                                                ),
                                              ],
                                            )
                                            : Column(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  Transform(
                                                    alignment: Alignment.center,
                                                    transform: Matrix4.rotationY(math.pi),
                                                    child: Text(
                                                      item.correctText,
                                                      textAlign: TextAlign.center,
                                                      style: const TextStyle(
                                                        fontSize: 34,
                                                        fontWeight: FontWeight.w900,
                                                        color: Color(0xFF00F5A0),
                                                        shadows: [Shadow(color: Color(0xFF00F5A0), blurRadius: 10)],
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(height: 24),
                                                  Transform(
                                                    alignment: Alignment.center,
                                                    transform: Matrix4.rotationY(math.pi),
                                                    child: IconButton(
                                                      onPressed: () {
                                                        // Arka yüz dili tespit et (Ön yüzün tersi)
                                                        final isTr = item.mode == QuestionMode.enToTr;
                                                        TtsService.instance.speak(item.correctText, language: isTr ? "tr-TR" : "en-US");
                                                      },
                                                      icon: const Icon(Icons.volume_up_rounded, color: Colors.white70, size: 32),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                    ),
                                  );
                                },
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 32),
                if (_flipped)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _reviewButton(
                        label: 'BİLMİYORUM',
                        color: Colors.redAccent,
                        icon: Icons.close_rounded,
                        onTap: () {
                          provider.updateSrsLevel(items[_index], false);
                          _nextCard(items.length);
                        },
                      ),
                      const SizedBox(width: 20),
                      _reviewButton(
                        label: 'BİLİYORUM',
                        color: const Color(0xFF00F5A0),
                        icon: Icons.check_rounded,
                        onTap: () {
                          provider.updateSrsLevel(items[_index], true);
                          _nextCard(items.length);
                        },
                      ),
                    ],
                  ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }


  void _nextCard(int total) {
    if (_index < total - 1) {
      setState(() {
        _index++;
        _flipped = false;
        _controller.reset();
      });
    } else {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tebrikler! Tüm kelimeleri tekrar ettin.'),
          backgroundColor: Color(0xFF00F5A0),
        ),
      );
    }
  }

  Widget _reviewButton({
    required String label,
    required Color color,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.5), width: 2),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
