import 'package:flutter/material.dart';
import '../../../models/user_level.dart';
import '../../../providers/language_provider.dart';
import 'package:provider/provider.dart';

class ActivityChart extends StatelessWidget {
  final UserProfile profile;

  const ActivityChart({super.key, required this.profile});

  @override
  Widget build(BuildContext context) {
    // Son 7 günün verisini hazırla
    final now = DateTime.now();
    final lang = context.watch<LanguageProvider>();
    
    final List<Map<String, dynamic>> dailyStats = List.generate(7, (index) {
      final date = now.subtract(Duration(days: 6 - index));
      // O güne ait maçların toplam puanını hesapla
      final totalPoints = profile.matchHistory.where((match) {
        return match.date.year == date.year &&
               match.date.month == date.month &&
               match.date.day == date.day;
      }).fold(0, (sum, match) => sum + match.userScore);
      
      return {
        'day': _getDayName(date.weekday, context),
        'points': totalPoints,
        'isToday': index == 6,
      };
    });

    // Maksimum değeri bul (grafik ölçeği için)
    int maxPoints = dailyStats.map((e) => e['points'] as int).fold(0, (p, c) => p > c ? p : c);
    if (maxPoints == 0) maxPoints = 100; // Varsayılan ölçek 100 puan üzerinden

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.white.withAlpha(20), Colors.white.withAlpha(8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withAlpha(31)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(51),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bar_chart_rounded, color: Colors.blueAccent, size: 22),
              const SizedBox(width: 8),
              Text(
                lang.getString('weekly_activity'),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: dailyStats.asMap().entries.map((entry) {
              final stat = entry.value;
              final points = stat['points'] as int;
              final heightFactor = (points / maxPoints).clamp(0.1, 1.0);
              final isToday = stat['isToday'] as bool;
              
              return Column(
                children: [
                  // Puan etiketi
                  if (points > 0)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        '$points',
                        style: TextStyle(
                          color: isToday ? Colors.amber : Colors.white38,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  // Bar
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.easeOutCubic,
                    width: 14,
                    height: 80 * heightFactor,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      gradient: isToday 
                        ? const LinearGradient(
                            colors: [Colors.amber, Colors.orangeAccent],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          )
                        : LinearGradient(
                            colors: [Colors.blue.shade400, Colors.blue.shade800],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                      boxShadow: [
                        if (isToday)
                          BoxShadow(
                            color: Colors.amber.withAlpha(77),
                            blurRadius: 8,
                            spreadRadius: 1,
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Gün İsmi
                  Text(
                    stat['day'],
                    style: TextStyle(
                      color: isToday ? Colors.amber : Colors.white54,
                      fontSize: 11,
                      fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  String _getDayName(int weekday, BuildContext context) {
    final lang = context.read<LanguageProvider>();
    final days = [
      lang.getString('mon'),
      lang.getString('tue'),
      lang.getString('wed'),
      lang.getString('thu'),
      lang.getString('fri'),
      lang.getString('sat'),
      lang.getString('sun'),
    ];
    return days[weekday - 1];
  }
}
