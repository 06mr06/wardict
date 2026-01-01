import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/game_provider.dart';
import '../../models/question_mode.dart';

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
    if (items.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Flash Cards')),
        body: const Center(child: Text('Havuz boş. Sonuçlardan + ile ekleyin.')),
      );
    }
    final e = items[_index];
    return Scaffold(
      appBar: AppBar(
        title: const Text('Flash Cards'),
        actions: [
          Center(child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text('${_index + 1}/${items.length}'),
          ))
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  _modeBadge(e.mode),
                  const SizedBox(width: 8),
                  Text(
                    e.mode == QuestionMode.trToEn ? 'TR > ENG' : e.mode == QuestionMode.enToTr ? 'EN > TR' : 'Eş Anlam',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Expanded(
                child: GestureDetector(
                  onTap: _toggleFlip,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final double w = constraints.maxWidth * 0.9;
                      final double h = constraints.maxHeight * 0.6;
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
                                width: w,
                                height: h,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFF4A7AB0), Color(0xFF2E5A8C)],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 15, spreadRadius: 2)],
                                  border: Border.all(color: const Color(0xFF6C27FF), width: 2),
                                ),
                                alignment: Alignment.center,
                                padding: const EdgeInsets.all(24),
                                child: progress < 0.5
                                    ? Text(
                                        e.prompt,
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
                                      )
                                    : Transform(
                                        alignment: Alignment.center,
                                        transform: Matrix4.rotationY(math.pi),
                                        child: Text(
                                          e.correctText,
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF00F5A0)),
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
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ElevatedButton(
                    onPressed: () => _prev(items.length),
                    child: const Text('Önceki'),
                  ),
                  ElevatedButton(
                    onPressed: () => _next(items.length),
                    child: const Text('Sonraki'),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}
