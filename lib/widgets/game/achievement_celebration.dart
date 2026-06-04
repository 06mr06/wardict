import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';
import 'package:provider/provider.dart';
import '../../models/achievement.dart';
import '../../providers/language_provider.dart';

class AchievementCelebration extends StatefulWidget {
  final List<Achievement> achievements;

  const AchievementCelebration({super.key, required this.achievements});

  static void showNewAchievements(BuildContext context, List<Achievement> achievements) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AchievementCelebration(achievements: achievements),
    );
  }

  @override
  State<AchievementCelebration> createState() => _AchievementCelebrationState();
}

class _AchievementCelebrationState extends State<AchievementCelebration> {
  late ConfettiController _confettiController;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 4));
    // İlk başarım için confetti'yi hemen başlat
    _confettiController.play();
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  Achievement get currentAchievement {
    if (_currentIndex >= widget.achievements.length) {
      return widget.achievements.last;
    }
    return widget.achievements[_currentIndex];
  }

  Color _getTierColor(AchievementTier tier) {
    switch (tier) {
      case AchievementTier.bronze:
        return const Color(0xFFCD7F32);
      case AchievementTier.silver:
        return const Color(0xFFC0C0C0);
      case AchievementTier.gold:
        return const Color(0xFFFFD700);
      case AchievementTier.platinum:
        return const Color(0xFFE5E4E2);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentAchievement = this.currentAchievement;
    
    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
        // Confetti
        Align(
          alignment: Alignment.topCenter,
          child: ConfettiWidget(
            confettiController: _confettiController,
            blastDirectionality: BlastDirectionality.explosive,
            shouldLoop: false,
            colors: const [
              Colors.amber,
              Colors.orange,
              Colors.yellow,
              Colors.green,
              Colors.blue,
              Colors.purple,
            ],
            numberOfParticles: 30,
          ),
        ),
        
        // Dialog
        Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 32),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const RadialGradient(
                center: Alignment(0.5, -0.6),
                radius: 1.2,
                colors: [
                  Color(0xFF1E3A5F),
                  Color(0xFF02040A),
                ],
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: _getTierColor(currentAchievement.tier).withAlpha(100),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(150),
                  blurRadius: 40,
                  spreadRadius: 10,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icon / Emblem
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: _getTierColor(currentAchievement.tier).withAlpha(80),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: Text(
                    currentAchievement.badgeIcon, // This usually contains emoji
                    style: const TextStyle(fontSize: 64),
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Title
                Text(
                  context.read<LanguageProvider>().getString('new_reward').toUpperCase(),
                  style: const TextStyle(
                    color: Colors.amber,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 3,
                  ),
                ),
                
                const SizedBox(height: 8),
                
                Text(
                  currentAchievement.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                
                const SizedBox(height: 12),
                
                Text(
                  currentAchievement.description,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
                
                const SizedBox(height: 24),
                
                // Indicators (if more than one)
                if (widget.achievements.length > 1) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(widget.achievements.length, (index) {
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: index == _currentIndex 
                              ? Colors.amber 
                              : Colors.white.withAlpha(77),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 16),
                ],
                
                // Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      if (_currentIndex < widget.achievements.length - 1) {
                        setState(() {
                          _currentIndex++;
                        });
                        _confettiController.play();
                      } else {
                        Navigator.of(context).pop();
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6C27FF),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      elevation: 8,
                      shadowColor: const Color(0xFF6C27FF).withAlpha(100),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    child: Text(
                      _currentIndex < widget.achievements.length - 1
                          ? context.read<LanguageProvider>().getString('next_reward').toUpperCase()
                          : context.read<LanguageProvider>().getString('great_confetti').toUpperCase(),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
   );
  }
}
