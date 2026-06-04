import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/language_provider.dart';
import '../../services/weekly_practice_points_service.dart';
import 'weekly_milestone_reward_dialog.dart';

/// Sandık sütununun merkezinin x koordinatı (çubuk genişliği ile hizalı).
double _milestoneCenterX(
  double layoutW,
  int maxPts,
  int value,
  double colW,
) {
  final x = (value / maxPts) * layoutW;
  final left = (x - colW / 2).clamp(0.0, layoutW - colW);
  return left + colW / 2;
}

class WeeklyPracticeProgressBar extends StatefulWidget {
  final bool compact;
  const WeeklyPracticeProgressBar({super.key, this.compact = false});

  @override
  State<WeeklyPracticeProgressBar> createState() =>
      _WeeklyPracticeProgressBarState();
}

class _WeeklyPracticeProgressBarState extends State<WeeklyPracticeProgressBar> {
  int _points = 0;
  Set<int> _claimed = {};

  @override
  void initState() {
    super.initState();
    _load();
    WeeklyPracticePointsService.instance.pointsNotifier.addListener(_onPts);
    WeeklyPracticePointsService.instance.uiBump.addListener(_onBump);
  }

  void _onPts() {
    if (mounted) {
      setState(
          () => _points = WeeklyPracticePointsService.instance.pointsNotifier.value);
    }
  }

  void _onBump() {
    if (mounted) _load();
  }

  Future<void> _load() async {
    final s = WeeklyPracticePointsService.instance;
    final p = await s.getWeeklyPoints();
    final c = await s.getClaimedThresholds();
    if (mounted) {
      setState(() {
        _points = p;
        _claimed = c;
      });
    }
  }

  @override
  void dispose() {
    WeeklyPracticePointsService.instance.pointsNotifier.removeListener(_onPts);
    WeeklyPracticePointsService.instance.uiBump.removeListener(_onBump);
    super.dispose();
  }

  List<int> get _pendingClaim {
    return WeeklyPracticePointsService.thresholds
        .where((t) => _points >= t && !_claimed.contains(t))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    const maxPts = WeeklyPracticePointsService.displayMax;
    const t = WeeklyPracticePointsService.thresholds;
    final frac = (_points / maxPts).clamp(0.0, 1.0);
    final pad = widget.compact
        ? const EdgeInsets.symmetric(horizontal: 10, vertical: 8)
        : const EdgeInsets.symmetric(horizontal: 14, vertical: 12);
    final pending = _pendingClaim;

    return Container(
      padding: pad,
      decoration: BoxDecoration(
        color: const Color(0xFF1A3A5C).withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF53D5D1).withValues(alpha: 0.45)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth;
          final colW = widget.compact ? 78.0 : 88.0;
          final lastCenter = _milestoneCenterX(w, maxPts, t[3], colW);
          final fillW =
              (lastCenter * frac).clamp(0.0, lastCenter);

          Widget tick(int value, String label) {
            final x = (value / maxPts) * w;
            final done = _points >= value;
            final claimed = _claimed.contains(value);
            final chestC = WeeklyPracticePointsService.chestColor(value);
            final iconBox = widget.compact ? 40.0 : 46.0;
            final iconSz = widget.compact ? 24.0 : 28.0;
            final left = (x - colW / 2).clamp(0.0, w - colW);
            return Positioned(
              left: left,
              top: 0,
              child: SizedBox(
                width: colW,
                child: Column(
                  children: [
                    Stack(
                      alignment: Alignment.center,
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: iconBox,
                          height: iconBox,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: chestC.withValues(
                                alpha: claimed ? 0.35 : (done ? 0.22 : 0.12)),
                            border: Border.all(
                              color: claimed
                                  ? Colors.amber
                                  : chestC.withValues(
                                      alpha: done ? 1.0 : 0.65),
                              width: claimed || done ? 2.5 : 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: chestC.withValues(
                                    alpha: done || claimed ? 0.55 : 0.28),
                                blurRadius: done || claimed ? 10 : 6,
                                spreadRadius: 0.5,
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.inventory_2_rounded,
                            size: iconSz,
                            color: claimed
                                ? Colors.amber.shade200
                                : (done
                                    ? chestC
                                    : chestC.withValues(alpha: 0.72)),
                          ),
                        ),
                        if (claimed)
                          Positioned(
                            right: -2,
                            top: -2,
                            child: Icon(
                              Icons.check_circle,
                              size: widget.compact ? 16 : 18,
                              color: Colors.lightGreenAccent,
                              shadows: const [
                                Shadow(
                                    color: Colors.black54, blurRadius: 2),
                              ],
                            ),
                          ),
                      ],
                    ),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        label,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        style: TextStyle(
                          fontSize: widget.compact ? 9 : 10,
                          color: Colors.white70,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(Icons.emoji_events_outlined,
                      color: Colors.amber.shade300,
                      size: widget.compact ? 18 : 22),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      lang.getString('weekly_practice_bar_title'),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: widget.compact ? 12 : 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Text(
                    '$_points / $maxPts',
                    style: TextStyle(
                      color: Colors.amber.shade200,
                      fontSize: widget.compact ? 11 : 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              SizedBox(height: widget.compact ? 6 : 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: lastCenter,
                  height: widget.compact ? 10 : 12,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Container(color: Colors.white.withValues(alpha: 0.12)),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: SizedBox(
                          width: fillW,
                          child: Container(
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Color(0xFF26C6DA),
                                  Color(0xFF53D5D1),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: widget.compact ? 4 : 6),
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    height: widget.compact ? 48 : 56,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        tick(t[0], '2000'),
                        tick(t[1], '4000'),
                        tick(t[2], '7000'),
                        tick(t[3], '10000'),
                      ],
                    ),
                  ),
                  if (pending.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    ...pending.map((th) {
                      final col = WeeklyPracticePointsService.chestColor(th);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Material(
                          color: col.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(12),
                          child: InkWell(
                            onTap: () =>
                                WeeklyMilestoneRewardDialog.show(context, th),
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 8),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: col.withValues(alpha: 0.25),
                                      border: Border.all(color: col, width: 2),
                                    ),
                                    child: Icon(Icons.inventory_2_rounded,
                                        color: col, size: 30),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      lang.format('weekly_chest_ready',
                                          {'n': '$th'}),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    lang.getString('weekly_milestone_claim'),
                                    style: TextStyle(
                                      color: col,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}
