import 'package:flutter/material.dart';

class QuestionCard extends StatelessWidget {
  final String prompt;
  final String? hint;
  final int streak;

  const QuestionCard(
      {super.key, required this.prompt, this.hint, this.streak = 0});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: const Color(0xFF26C6DA),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF26C6DA).withAlpha(100),
            blurRadius: 15,
            spreadRadius: 2,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              prompt,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                height: 1.2,
                letterSpacing: 0.5,
              ),
              textAlign: TextAlign.center,
              maxLines: 4,
            ),
          ),
        ],
      ),
    );
  }
}
