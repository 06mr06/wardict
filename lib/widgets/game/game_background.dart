import 'package:flutter/material.dart';

class GameBackground extends StatelessWidget {
  final Widget child;

  const GameBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF2E5A8C), Color(0xFF1A3A5C)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: SafeArea(child: child),
    );
  }
}
