import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../models/user_level.dart';
import '../../../providers/language_provider.dart';

class LpProgressionBar extends StatelessWidget {
  final UserProfile? userProfile;
  final LanguageProvider languageProvider;

  const LpProgressionBar({
    super.key,
    required this.userProfile,
    required this.languageProvider,
  });

  @override
  Widget build(BuildContext context) {
    if (userProfile == null) return const SizedBox.shrink();
    
    double lpProgress = 0.0;
    int currentLp = userProfile!.lpRating;
    UserLevel level = userProfile!.level;
    int startLp = UserProfile.getInitialLpForLevel(level);
    
    if (level == UserLevel.c2) {
      lpProgress = 1.0;
    } else {
      int endLp = UserProfile.getInitialLpForLevel(level.nextLevel);
      if (endLp > startLp) {
        lpProgress = (currentLp - startLp) / (endLp - startLp);
        lpProgress = lpProgress.clamp(0.0, 1.0).toDouble();
      } else {
        lpProgress = 1.0;
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                languageProvider.getString('lp_progress').toUpperCase(),
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                ),
              ),
              Text(
                '$currentLp LP',
                style: GoogleFonts.outfit(
                  color: Colors.amber,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                 ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            height: 16,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: Stack(
              children: [
                FractionallySizedBox(
                  widthFactor: lpProgress,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF00E5FF), Color(0xFF2979FF)],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF00E5FF).withValues(alpha: 0.5),
                          blurRadius: 12,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  ),
                ),
               ],
            ),
          ),
        ],
      ),
    );
  }
}
