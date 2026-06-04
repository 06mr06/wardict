import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/powerup.dart';
import '../../providers/language_provider.dart';
import '../../services/weekly_practice_points_service.dart';

class WeeklyMilestoneRewardDialog extends StatefulWidget {
  final int threshold;

  const WeeklyMilestoneRewardDialog({super.key, required this.threshold});

  static Future<void> show(BuildContext context, int threshold) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => WeeklyMilestoneRewardDialog(threshold: threshold),
    );
  }

  @override
  State<WeeklyMilestoneRewardDialog> createState() =>
      _WeeklyMilestoneRewardDialogState();
}

class _WeeklyMilestoneRewardDialogState
    extends State<WeeklyMilestoneRewardDialog> {
  bool _busy = false;

  String _powerupLabel(LanguageProvider lang, PowerupType t) {
    switch (t) {
      case PowerupType.revealAnswer:
        return lang.getString('weekly_pu_reveal');
      case PowerupType.fiftyFifty:
        return lang.getString('weekly_pu_fifty');
      case PowerupType.doubleChance:
        return lang.getString('weekly_pu_double');
      case PowerupType.freezeTime:
        return lang.getString('weekly_pu_freeze');
      case PowerupType.multiplier:
        return lang.getString('weekly_pu_multiplier');
      case PowerupType.streakShield:
        return t.name;
    }
  }

  Future<void> _claim() async {
    if (_busy) return;
    setState(() => _busy = true);
    final ok = await WeeklyPracticePointsService.instance
        .claimMilestone(widget.threshold);
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    final b = WeeklyPracticePointsService.breakdown(widget.threshold);
    final chestColor = WeeklyPracticePointsService.chestColor(widget.threshold);

    final lines = <Widget>[
      Text(
        lang.format('weekly_milestone_dialog_reached', {'n': '${b.threshold}'}),
        style: const TextStyle(color: Colors.white70, height: 1.35),
      ),
      const SizedBox(height: 12),
    ];
    if (b.coins > 0) {
      lines.add(
        Text(
          lang.format('weekly_milestone_coin', {'n': '${b.coins}'}),
          style: const TextStyle(
            color: Color(0xFFFFD700),
            fontWeight: FontWeight.w800,
            fontSize: 16,
          ),
        ),
      );
    }
    for (final e in b.powerups.entries) {
      lines.add(Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              e.key.emoji,
              style: const TextStyle(fontSize: 28),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _powerupLabel(lang, e.key),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  Text(
                    '×${e.value}',
                    style: TextStyle(
                      color: const Color(0xFF69F0AE),
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ));
    }

    return AlertDialog(
      backgroundColor: const Color(0xFF1A3A5C),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(
        lang.getString('weekly_milestone_dialog_title'),
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: 18,
        ),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: chestColor.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                  border: Border.all(color: chestColor, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: chestColor.withValues(alpha: 0.45),
                      blurRadius: 18,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Icon(
                  Icons.inventory_2_rounded,
                  size: 56,
                  color: chestColor,
                ),
              ),
            ),
            const SizedBox(height: 16),
            ...lines,
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: Text(
            lang.getString('close'),
            style: const TextStyle(
                color: Color(0xFF53D5D1), fontWeight: FontWeight.w700),
          ),
        ),
        FilledButton(
          onPressed: _busy ? null : _claim,
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF4CAF50),
            foregroundColor: Colors.white,
          ),
          child: _busy
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(
                  lang.getString('weekly_milestone_claim'),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
        ),
      ],
    );
  }
}
