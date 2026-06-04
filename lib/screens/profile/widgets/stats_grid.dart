import 'package:flutter/material.dart';
import '../../../models/user_level.dart';
import '../../../providers/language_provider.dart';
import 'package:provider/provider.dart';

class StatsGrid extends StatelessWidget {
  final UserProfile profile;

  const StatsGrid({super.key, required this.profile});

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: 1.4, // Kartların yatay/dikey oranı (Daha geniş kartlar)
      children: [
        _buildStatCard(
          lang.getString('total_points'),
          '${profile.totalScore}',
          Icons.stars_rounded,
          Colors.amber,
          [const Color(0xFFFFA000), const Color(0xFFFFD54F)],
        ),
        _buildStatCard(
          lang.getString('daily_streak'),
          '${profile.dailyStreak} ${lang.getString('days_unit')}',
          Icons.local_fire_department_rounded,
          Colors.deepOrange,
          [const Color(0xFFF4511E), const Color(0xFFFF7043)],
        ),
        _buildStatCard(
          lang.getString('lp_points'),
          '${profile.lpRating}',
          Icons.emoji_events_rounded,
          Colors.blueAccent,
          [const Color(0xFF1976D2), const Color(0xFF64B5F6)],
        ),
        _buildStatCard(
          lang.getString('practice_stats'),
          '${profile.practiceScore}',
          Icons.school_rounded,
          Colors.greenAccent,
          [const Color(0xFF2E7D32), const Color(0xFF81C784)],
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color iconColor, List<Color> gradientColors) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors.map((c) => c.withAlpha(46)).toList(),
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: gradientColors[0].withAlpha(77), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: gradientColors[0].withAlpha(20),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: iconColor, size: 28),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withAlpha(140),
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}
