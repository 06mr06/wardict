import 'package:flutter/material.dart';

class GameBackground extends StatelessWidget {
  final Widget child;
  final String? backgroundImage;
  final double imageOpacity;

  const GameBackground({
    super.key, 
    required this.child,
    this.backgroundImage,
    this.imageOpacity = 0.3,
  });

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
      child: Stack(
        children: [
          if (backgroundImage != null)
            Positioned.fill(
              child: Opacity(
                opacity: imageOpacity,
                child: Image.asset(
                  backgroundImage!,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          SafeArea(child: child),
        ],
      ),
    );
  }
}
