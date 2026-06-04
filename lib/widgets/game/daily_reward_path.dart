import 'package:flutter/material.dart';
import '../../providers/language_provider.dart';
import 'package:provider/provider.dart';

class DailyRewardPath extends StatelessWidget {
  final int currentStreak;
  final List<String> claimedMilestones;
  final DateTime? lastClaimDate;

  const DailyRewardPath({
    super.key,
    required this.currentStreak,
    required this.claimedMilestones,
    this.lastClaimDate,
  });

  @override
  Widget build(BuildContext context) {
    // Determine if today's reward is already claimed
    final now = DateTime.now();
    final bool alreadyClaimedToday = lastClaimDate != null &&
        lastClaimDate!.year == now.year &&
        lastClaimDate!.month == now.month &&
        lastClaimDate!.day == now.day;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(13),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withAlpha(26)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 10, bottom: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.read<LanguageProvider>().getString('daily_login_rewards'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (currentStreak > 1)
                  Text(
                    context.read<LanguageProvider>().getString('streak_message').replaceAll('{streak}', currentStreak.toString()),
                    style: TextStyle(
                      color: Colors.white.withAlpha(153),
                      fontSize: 14,
                    ),
                  ),
              ],
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: List.generate(7, (index) {
                final dayNum = index + 1;
                // Simple logic: if streak is 3 and claimed today, then days 1, 2, 3 are completed.
                // If streak is 3 and NOT yet claimed today, then original streak was 2, so days 1, 2 are completed.
                final bool isCompleted = index < currentStreak;
                final bool isToday = index == (alreadyClaimedToday ? currentStreak - 1 : currentStreak);
                final bool isNext = index == (alreadyClaimedToday ? currentStreak : currentStreak + 1);

                return _buildDayCard(
                  context: context,
                  day: dayNum,
                  isCompleted: isCompleted,
                  isToday: isToday,
                  reward: _getRewardForDay(context, dayNum),
                  rewardIcon: _getIconForDay(dayNum),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  String _getRewardForDay(BuildContext context, int day) {
    if (day == 7) return context.read<LanguageProvider>().getString('grand_prize');
    return '${day * 20} ${context.read<LanguageProvider>().getString('coins_unit_label')}';
  }

  IconData _getIconForDay(int day) {
    if (day == 3) return Icons.autorenew; // Second chance
    if (day == 7) return Icons.card_giftcard;
    return Icons.monetization_on;
  }

  Widget _buildDayCard({
    required BuildContext context,
    required int day,
    required bool isCompleted,
    required bool isToday,
    required String reward,
    required IconData rewardIcon,
  }) {
    Color cardColor;
    Color iconColor;
    if (isCompleted) {
      cardColor = Colors.green.withAlpha(51);
      iconColor = Colors.green;
    } else if (isToday) {
      cardColor = Colors.orange.withAlpha(51);
      iconColor = Colors.orange;
    } else {
      cardColor = Colors.white.withAlpha(13);
      iconColor = Colors.white.withAlpha(77);
    }

    return Container(
      width: 100,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isToday ? Colors.orange : (isCompleted ? Colors.green : Colors.white.withAlpha(26)),
          width: isToday ? 2 : 1,
        ),
        boxShadow: isToday ? [
          BoxShadow(color: Colors.orange.withAlpha(77), blurRadius: 10, spreadRadius: 1)
        ] : null,
      ),
      child: Column(
        children: [
          Text(
            '${context.read<LanguageProvider>().getString('day_label')} $day',
            style: TextStyle(
              color: isCompleted || isToday ? Colors.white : Colors.white.withAlpha(102),
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 12),
          Icon(
            isCompleted ? Icons.check_circle : rewardIcon,
            color: iconColor,
            size: 32,
          ),
          const SizedBox(height: 12),
          Text(
            reward,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isCompleted || isToday ? Colors.white : Colors.white.withAlpha(102),
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
