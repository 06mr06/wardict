import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';
import '../../models/achievement.dart';

/// Yeni kazanılan ödülleri kutlama dialogu olarak gösterir
class AchievementCelebration {
  static void showNewAchievements(BuildContext context, List<Achievement> achievements) {
    if (achievements.isEmpty) return;
    
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black87,
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (context, animation, secondaryAnimation) {
        return _AchievementCelebrationDialog(achievements: achievements);
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: CurvedAnimation(
              parent: animation,
              curve: Curves.elasticOut,
            ),
            child: child,
          ),
        );
      },
    );
  }
}

class _AchievementCelebrationDialog extends StatefulWidget {
  final List<Achievement> achievements;
  
  const _AchievementCelebrationDialog({required this.achievements});
  
  @override
  State<_AchievementCelebrationDialog> createState() => _AchievementCelebrationDialogState();
}

class _AchievementCelebrationDialogState extends State<_AchievementCelebrationDialog> 
    with TickerProviderStateMixin {
  late ConfettiController _confettiController;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 3));
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _confettiController.play();
    });
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Achievement get currentAchievement => widget.achievements[_currentIndex];

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
    return Stack(
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
              gradient: const LinearGradient(
                colors: [Color(0xFF3A6EA5), Color(0xFF2E5A8C)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: _getTierColor(currentAchievement.tier),
                width: 3,
              ),
              boxShadow: [
                BoxShadow(
                  color: _getTierColor(currentAchievement.tier).withOpacity(0.5),
                  blurRadius: 30,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Yeni Ödül başlığı
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.amber),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('🎉', style: TextStyle(fontSize: 20)),
                      SizedBox(width: 8),
                      Text(
                        'YENİ ÖDÜL!',
                        style: TextStyle(
                          color: Colors.amber,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                        ),
                      ),
                      SizedBox(width: 8),
                      Text('🎉', style: TextStyle(fontSize: 20)),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                
                // Badge animasyonlu
                ScaleTransition(
                  scale: _pulseAnimation,
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        colors: [
                          _getTierColor(currentAchievement.tier).withOpacity(0.3),
                          _getTierColor(currentAchievement.tier).withOpacity(0.1),
                        ],
                      ),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _getTierColor(currentAchievement.tier),
                        width: 4,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: _getTierColor(currentAchievement.tier).withOpacity(0.5),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        currentAchievement.badgeIcon,
                        style: const TextStyle(fontSize: 52),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                
                // Başlık
                Text(
                  currentAchievement.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                
                // Açıklama
                Text(
                  currentAchievement.description,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                
                // Ödül
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.amber.withOpacity(0.3),
                        Colors.orange.withOpacity(0.2),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.amber.withOpacity(0.5)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('🪙', style: TextStyle(fontSize: 24)),
                      const SizedBox(width: 10),
                      Text(
                        '+${currentAchievement.rewardCoins}',
                        style: const TextStyle(
                          color: Colors.amber,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'altın',
                        style: TextStyle(
                          color: Colors.amber.withOpacity(0.8),
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                
                // Tier rozeti
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: _getTierColor(currentAchievement.tier),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    currentAchievement.tier.name.toUpperCase(),
                    style: TextStyle(
                      color: currentAchievement.tier == AchievementTier.gold || 
                             currentAchievement.tier == AchievementTier.silver
                          ? Colors.black87
                          : Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                
                // Sayfa göstergesi (birden fazla ödül varsa)
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
                              : Colors.white.withOpacity(0.3),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 16),
                ],
                
                // Buton
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
                      backgroundColor: Colors.amber,
                      foregroundColor: Colors.black87,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      _currentIndex < widget.achievements.length - 1
                          ? 'Sonraki Ödül →'
                          : 'Harika! 🎊',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
