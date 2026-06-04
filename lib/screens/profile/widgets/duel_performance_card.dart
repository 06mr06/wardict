import 'package:flutter/material.dart';
import '../../../models/user_level.dart';
import '../../../providers/language_provider.dart';
import 'package:provider/provider.dart';

class DuelPerformanceCard extends StatelessWidget {
  final UserProfile profile;

  const DuelPerformanceCard({super.key, required this.profile});

  @override
  Widget build(BuildContext context) {
    final totalDuels = profile.duelWins + profile.duelLosses;
    final winRate = totalDuels > 0 ? (profile.duelWins / totalDuels) : 0.0;
    final winPercentage = (winRate * 100).round();
    final lang = context.watch<LanguageProvider>();

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF6C27FF).withAlpha(38),
            const Color(0xFF2E5A8C).withAlpha(26),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF6C27FF).withAlpha(77)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6C27FF).withAlpha(26),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Row(
        children: [
          // Sol: Görsel Oran (Nested Circular)
          Stack(
            alignment: Alignment.center,
            children: [
              // Outer Glow
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withAlpha(13), width: 1),
                ),
              ),
              // Outer (Total - Gray Background)
              SizedBox(
                width: 76,
                height: 76,
                child: CircularProgressIndicator(
                  value: 1.0,
                  strokeWidth: 8,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white.withAlpha(26)),
                ),
              ),
              // Middle (Win Rate)
              SizedBox(
                width: 76,
                height: 76,
                child: CircularProgressIndicator(
                  value: winRate,
                  strokeWidth: 8,
                  strokeCap: StrokeCap.round,
                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF00E676)), // Green Accent
                ),
              ),
              // Inner (Optional Second indicator for style or Loss rate in red)
              SizedBox(
                width: 58,
                height: 58,
                child: CircularProgressIndicator(
                  value: 1.0 - winRate,
                  strokeWidth: 4,
                  strokeCap: StrokeCap.round,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.redAccent.withAlpha(77)),
                ),
              ),
              // Center Text
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '%$winPercentage',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const Text(
                    'WR',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(width: 24),
          // Sağ: İstatistikler
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  lang.getString('duel_performance'),
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 16),
                _buildStatRow(Icons.check_circle_rounded, lang.getString('wins'), '${profile.duelWins}', const Color(0xFF00E676)),
                const SizedBox(height: 6),
                _buildStatRow(Icons.cancel_rounded, lang.getString('losses'), '${profile.duelLosses}', Colors.redAccent),
                const SizedBox(height: 16),
                Text(
                  lang.getString('total_played').replaceAll('{count}', totalDuels.toString()),
                  style: TextStyle(
                    color: Colors.white.withAlpha(102),
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(IconData icon, String label, String value, Color color) {
    return Row(
      children: [
        Icon(icon, color: color.withAlpha(179), size: 16),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(color: Colors.white54, fontSize: 13),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
