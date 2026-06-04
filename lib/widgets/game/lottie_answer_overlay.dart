import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

class LottieAnswerOverlay extends StatefulWidget {
  final bool isCorrect;
  final VoidCallback onComplete;

  const LottieAnswerOverlay({
    super.key,
    required this.isCorrect,
    required this.onComplete,
  });

  @override
  State<LottieAnswerOverlay> createState() => _LottieAnswerOverlayState();
}

class _LottieAnswerOverlayState extends State<LottieAnswerOverlay> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _controller.forward().then((_) {
      if (mounted) {
        widget.onComplete();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: FadeTransition(
        opacity: Tween<double>(begin: 1.0, end: 0.0).animate(
          CurvedAnimation(
            parent: _controller,
            curve: const Interval(0.7, 1.0, curve: Curves.easeOut),
          ),
        ),
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.5, end: 1.2).animate(
            CurvedAnimation(
              parent: _controller,
              curve: const Interval(0.0, 0.4, curve: Curves.elasticOut),
            ),
          ),
        child: AspectRatio(
          aspectRatio: 1,
          child: Container(
             padding: const EdgeInsets.all(12),
             decoration: BoxDecoration(
               color: widget.isCorrect ? Colors.greenAccent.withValues(alpha: 0.1) : Colors.redAccent.withValues(alpha: 0.1),
               shape: BoxShape.circle,
             ),
             child: Lottie.asset(
               widget.isCorrect ? 'assets/animations/correct.json' : 'assets/animations/wrong.json',
               width: 80,
               height: 80,
               fit: BoxFit.contain,
               repeat: false,
               errorBuilder: (context, error, stackTrace) {
                 return Icon(
                   widget.isCorrect ? Icons.check_circle : Icons.sentiment_very_dissatisfied,
                   color: widget.isCorrect ? const Color(0xFF00F5A0) : Colors.redAccent,
                   size: 80,
                 );
               },
             ),
          ),
        ),
        ),
      ),
    );
  }
}
