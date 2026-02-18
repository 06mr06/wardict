import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/game_provider.dart';
import '../../models/question_mode.dart';
import '../../services/sound_service.dart';

class FlashcardsScreen extends StatefulWidget {
  const FlashcardsScreen({super.key});

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
    setState(() => _flipped = !_flipped);
    if (_flipped) {
      _controller.forward(from: 0);
    } else {
      _controller.reverse(from: 1);
    }
  }

  void _next(int len) {
    setState(() {
      _index = (_index + 1) % len;
      _flipped = false;
      _controller.reset();
    });
  }

  void _prev(int len) {
    setState(() {
      _index = (_index - 1 + len) % len;
      _flipped = false;
      _controller.reset();
    });
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
    final items = provider.savedPool;
    
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Akıllı Tekrar', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        actions: [
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.2)),
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
                  child: GestureDetector(
                    onTap: _toggleFlip,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return Center(
                          child: AnimatedBuilder(
                            animation: _controller,
                            builder: (context, child) {
                              final progress = _flipped ? _controller.value : 0.0;
                              final angle = math.pi * progress;
                              return Transform(
                                alignment: Alignment.center,
                                transform: Matrix4.identity()
                                  ..setEntry(3, 2, 0.001)
                                  ..rotateY(angle),
                                child: Container(
                                  width: double.infinity,
                                  height: constraints.maxHeight * 0.8,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: progress < 0.5 
                                          ? [Colors.white.withOpacity(0.15), Colors.white.withOpacity(0.05)]
                                          : [const Color(0xFF00F5A0).withOpacity(0.2), const Color(0xFF00F5A0).withOpacity(0.05)],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(30),
                                    border: Border.all(
                                      color: progress < 0.5 ? Colors.white.withOpacity(0.3) : const Color(0xFF00F5A0).withOpacity(0.5),
                                      width: 2,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: progress < 0.5 ? Colors.black26 : const Color(0xFF00F5A0).withOpacity(0.2),
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
                                            _modeBadge(items[_index].mode),
                                            const SizedBox(height: 16),
                                            Text(
                                              items[_index].prompt,
                                              textAlign: TextAlign.center,
                                              style: const TextStyle(
                                                fontSize: 34,
                                                fontWeight: FontWeight.w900,
                                                color: Colors.white,
                                                letterSpacing: -1,
                                              ),
                                            ),
                                            const SizedBox(height: 32),
                                            Text(
                                              'Cevap için dokun',
                                              style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 13, fontWeight: FontWeight.bold),
                                            ),
                                          ],
                                        )
                                      : Transform(
                                          alignment: Alignment.center,
                                          transform: Matrix4.rotationY(math.pi),
                                          child: Text(
                                            items[_index].correctText,
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(
                                              fontSize: 34,
                                              fontWeight: FontWeight.w900,
                                              color: Color(0xFF00F5A0),
                                              shadows: [Shadow(color: Color(0xFF00F5A0), blurRadius: 10)],
                                            ),
                                          ),
                                        ),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 48),
                Row(
                  children: [
                    _buildNavButton(
                      icon: Icons.arrow_back_ios_new_rounded,
                      label: 'Önceki',
                      onTap: () => _prev(items.length),
                    ),
                    const SizedBox(width: 16),
                    _buildNavButton(
                      icon: Icons.arrow_forward_ios_rounded,
                      label: 'Sonraki',
                      onTap: () => _next(items.length),
                      primary: true,
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

  Widget _buildNavButton({required IconData icon, required String label, required VoidCallback onTap, bool primary = false}) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            SoundService.instance.playClick();
            onTap();
          },
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: primary ? const Color(0xFF6C27FF) : Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: primary ? Colors.white24 : Colors.white12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (!primary) Icon(icon, color: Colors.white, size: 16),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                if (primary) const SizedBox(width: 8),
                if (primary) Icon(icon, color: Colors.white, size: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
