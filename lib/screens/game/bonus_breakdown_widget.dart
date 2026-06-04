import 'package:flutter/material.dart';

class BonusBreakdownWidget extends StatelessWidget {
  final Map<String, int> bonuses;
  const BonusBreakdownWidget({super.key, required this.bonuses});

  @override
  Widget build(BuildContext context) {
    final hasBonus = bonuses.values.any((v) => v > 0);
    if (!hasBonus) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(38),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Bonuslar', style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 4),
          ...bonuses.entries.where((e) => e.value > 0).map((e) => Row(
            children: [
              if (e.key == 'Streak Bonus') const Text('🔥', style: TextStyle(fontSize: 18)),
              if (e.key == 'Speed Bonus') const Text('⚡', style: TextStyle(fontSize: 18)),
              if (e.key == 'Upper Level Bonus') const Text('⬆️', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 6),
              Text('${e.key}: ', style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w500)),
              Text('+${e.value}', style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
            ],
          )),
        ],
      ),
    );
  }
}
