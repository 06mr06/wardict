import 'package:flutter/material.dart';
import '../../../providers/practice_provider.dart';
import '../../../providers/language_provider.dart';
import 'package:lugorena/models/online_duel.dart';
import 'package:lugorena/screens/game/practice_screen.dart';
import 'package:lugorena/screens/game/online_duel_screen.dart';

class ResumableGameButtons extends StatelessWidget {
  final LanguageProvider languageProvider;
  final PracticeProvider practiceProvider;
  final OnlineDuelMatch? resumableDuel;
  final Animation<double> pulseAnimation;
  final VoidCallback onRefresh;

  const ResumableGameButtons({
    super.key,
    required this.languageProvider,
    required this.practiceProvider,
    required this.resumableDuel,
    required this.pulseAnimation,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    if (!practiceProvider.hasResumableSession && resumableDuel == null) {
      return const SizedBox.shrink();
    }

    return Positioned(
      bottom: 120, // Bottom barın üstünde
      right: 20,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (resumableDuel != null)
            _buildResumeDuelFloatingButton(context),
          if (resumableDuel != null && practiceProvider.hasResumableSession)
            const SizedBox(height: 12),
          if (practiceProvider.hasResumableSession)
            _buildResumeFloatingButton(context),
        ],
      ),
    );
  }

  Widget _buildResumeFloatingButton(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context, 
        MaterialPageRoute(builder: (context) => const SeventyThirtyScreen())
      ).then((_) => onRefresh()),
      child: AnimatedBuilder(
        animation: pulseAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: pulseAnimation.value,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFE91E63), Color(0xFFFF5252)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: Colors.pink.withValues(alpha: 0.4),
                    blurRadius: 15,
                    spreadRadius: 2,
                    offset: const Offset(0, 4),
                  ),
                ],
                border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1.5),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.play_circle_fill, color: Colors.white, size: 28),
                  const SizedBox(width: 8),
                  Text(
                    languageProvider.getString('resume_game').toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white, 
                      fontWeight: FontWeight.w900, 
                      fontSize: 13, 
                      letterSpacing: 1.0
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildResumeDuelFloatingButton(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (resumableDuel != null) {
          Navigator.push(
            context, 
            MaterialPageRoute(builder: (context) => OnlineDuelScreen(match: resumableDuel!))
          ).then((_) => onRefresh());
        }
      },
      child: AnimatedBuilder(
        animation: pulseAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: pulseAnimation.value,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6C27FF), Color(0xFF2AA7FF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF6C27FF).withValues(alpha: 0.4),
                    blurRadius: 15,
                    spreadRadius: 2,
                    offset: const Offset(0, 4),
                  ),
                ],
                border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1.5),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.flash_on_rounded, color: Colors.white, size: 28),
                  const SizedBox(width: 8),
                  Text(
                    languageProvider.getString('resume_duel').toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white, 
                      fontWeight: FontWeight.w900, 
                      fontSize: 13, 
                      letterSpacing: 1.0
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
