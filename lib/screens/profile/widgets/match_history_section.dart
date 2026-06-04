import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/user_level.dart';
import '../../../models/match_history_item.dart';

class MatchHistorySection extends StatelessWidget {
  final UserProfile profile;

  const MatchHistorySection({super.key, required this.profile});

  @override
  Widget build(BuildContext context) {
    if (profile.matchHistory.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(13),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withAlpha(26)),
        ),
        child: Column(
          children: [
            Icon(Icons.history_rounded, color: Colors.white.withAlpha(51), size: 48),
            const SizedBox(height: 12),
            Text(
              'Henüz maç geçmişi yok',
              style: TextStyle(color: Colors.white.withAlpha(102), fontSize: 14),
            ),
          ],
        ),
      );
    }

    // Tarihe göre sırala (en yeni üstte)
    final sortedHistory = List<MatchHistoryItem>.from(profile.matchHistory)
      ..sort((a, b) => b.date.compareTo(a.date));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'SON MAÇLAR',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 13,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: sortedHistory.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) => MatchHistoryItemWidget(item: sortedHistory[index]),
        ),
      ],
    );
  }
}

class MatchHistoryItemWidget extends StatelessWidget {
  final MatchHistoryItem item;

  const MatchHistoryItemWidget({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final bool isWin = item.isWin;
    final String dateStr = DateFormat('dd MMM, HH:mm', 'tr').format(item.date);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(13),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isWin ? Colors.green.withAlpha(51) : Colors.red.withAlpha(51),
        ),
      ),
      child: Row(
        children: [
          // Indicator & Initial
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isWin ? Colors.green.withAlpha(38) : Colors.red.withAlpha(38),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                item.opponentName.isNotEmpty ? item.opponentName[0].toUpperCase() : '?',
                style: TextStyle(
                  color: isWin ? Colors.greenAccent : Colors.redAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.opponentName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  dateStr,
                  style: TextStyle(
                    color: Colors.white.withAlpha(102),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          // Score & LP
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${item.userScore} - ${item.opponentScore}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  letterSpacing: 0.5,
                ),
              ),
              if (item.eloChange != 0)
                Text(
                  '${item.eloChange > 0 ? "+" : ""}${item.eloChange} LP',
                  style: TextStyle(
                    color: item.eloChange > 0 ? Colors.greenAccent : Colors.redAccent,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
