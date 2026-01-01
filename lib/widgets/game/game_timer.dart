import 'package:flutter/material.dart';

class GameTimer extends StatelessWidget {
  final int timeLeft;

  const GameTimer({super.key, required this.timeLeft});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      width: 50,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: timeLeft <= 2
              ? [Colors.red.shade400, Colors.red.shade700]
              : [const Color(0xFF6C27FF), const Color(0xFF9D4EDD)],
        ),
        boxShadow: [
          BoxShadow(
            color: (timeLeft <= 2 ? Colors.red : const Color(0xFF6C27FF))
                .withOpacity(0.5),
            blurRadius: 12,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Center(
        child: Text(
          '$timeLeft',
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
