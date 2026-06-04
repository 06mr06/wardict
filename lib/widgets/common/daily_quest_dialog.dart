import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:confetti/confetti.dart';
import '../../models/quest.dart';
import '../../models/powerup.dart';
import '../../services/quest_service.dart';
import '../../services/sound_service.dart';
import '../../providers/language_provider.dart';
import 'package:provider/provider.dart';

class DailyQuestDialog extends StatefulWidget {
  final List<Quest> quests;
  final ConfettiController? confettiController;
  final VoidCallback? onRefresh;
  final Function(QuestType)? onNavigate;

  const DailyQuestDialog({
    super.key,
    required this.quests,
    this.confettiController,
    this.onRefresh,
    this.onNavigate,
  });

  static Future<void> show(BuildContext context, {ConfettiController? confettiController, VoidCallback? onRefresh, Function(QuestType)? onNavigate}) async {
    final quests = await QuestService.instance.getQuests();
    if (context.mounted) {
      await showDialog(
        context: context,
        builder: (context) => DailyQuestDialog(
          quests: quests,
          confettiController: confettiController,
          onRefresh: onRefresh,
          onNavigate: onNavigate,
        ),
      );
    }
  }

  @override
  State<DailyQuestDialog> createState() => _DailyQuestDialogState();
}

class _DailyQuestDialogState extends State<DailyQuestDialog> {
  late List<Quest> _quests;
  late ConfettiController _internalConfettiController;
  bool _isInternalConfetti = false;

  @override
  void initState() {
    super.initState();
    _quests = widget.quests;
    if (widget.confettiController == null) {
      _internalConfettiController = ConfettiController(duration: const Duration(seconds: 2));
      _isInternalConfetti = true;
    } else {
      _internalConfettiController = widget.confettiController!;
    }
  }

  @override
  void dispose() {
    if (_isInternalConfetti) {
      _internalConfettiController.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lp = context.read<LanguageProvider>();
    
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        width: double.maxFinite,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1E3A5F), Color(0xFF0F2027)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 20, spreadRadius: 5),
          ],
        ),
        child: Stack(
          children: [
            Align(
              alignment: Alignment.topCenter,
              child: ConfettiWidget(
                confettiController: _internalConfettiController,
                blastDirectionality: BlastDirectionality.explosive,
                shouldLoop: false,
                colors: const [Colors.amber, Colors.green, Colors.blue, Colors.pink, Colors.orange],
                numberOfParticles: 20,
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.auto_awesome, color: Colors.amber, size: 28),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              lp.getString('daily_quests_title').toUpperCase(),
                              style: GoogleFonts.outfit(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                              ),
                            ),
                            Text(
                              lp.getString('daily_quests_subtitle'),
                              style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Quest List
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                    child: Column(
                      children: _buildQuestItems(),
                    ),
                  ),
                ),
                
                // Başla Butonu
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  child: SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6C27FF),
                        foregroundColor: Colors.white,
                        elevation: 8,
                        shadowColor: const Color(0xFF6C27FF).withValues(alpha: 0.4),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: Text(
                        lp.getString('continue_btn').toUpperCase(),
                        style: GoogleFonts.outfit(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildQuestItems() {
    final sortedQuests = List<Quest>.from(_quests.where((q) => q.id.startsWith('d_'))).take(3).toList();
    sortedQuests.sort((a, b) {
      if (a.isCompleted && !b.isCompleted) return 1;
      if (!a.isCompleted && b.isCompleted) return -1;
      final aCanClaim = a.currentProgress >= a.goal;
      final bCanClaim = b.currentProgress >= b.goal;
      if (aCanClaim && !bCanClaim) return -1;
      if (!aCanClaim && bCanClaim) return 1;
      return 0;
    });

    return sortedQuests.map((quest) {
      final progress = (quest.currentProgress / quest.goal).clamp(0.0, 1.0);
      final isDone = quest.isCompleted;
      final canClaim = quest.currentProgress >= quest.goal && !isDone;

      return GestureDetector(
        onTap: () {
          if (!isDone && !canClaim && widget.onNavigate != null) {
            Navigator.pop(context);
            widget.onNavigate!(quest.type);
          }
        },
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 300),
          opacity: isDone ? 0.6 : 1.0,
          child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              if (canClaim)
                BoxShadow(
                  color: Colors.amber.withValues(alpha: 0.1),
                  blurRadius: 15,
                  spreadRadius: 2,
                ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isDone 
                    ? Colors.green.withValues(alpha: 0.05) 
                    : (canClaim 
                        ? Colors.amber.withValues(alpha: 0.08) 
                        : Colors.white.withValues(alpha: 0.05)),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: isDone
                      ? Colors.green.withValues(alpha: 0.3)
                      : (canClaim 
                          ? Colors.amber.withValues(alpha: 0.5) 
                          : Colors.white.withValues(alpha: 0.1)),
                    width: canClaim ? 2 : 1.5,
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: isDone
                                  ? [Colors.green.withValues(alpha: 0.2), Colors.green.withValues(alpha: 0.05)]
                                  : (canClaim 
                                      ? [Colors.amber.withValues(alpha: 0.3), Colors.amber.withValues(alpha: 0.1)]
                                      : [Colors.white.withValues(alpha: 0.1), Colors.white.withValues(alpha: 0.05)]),
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isDone ? Icons.check_circle : (canClaim ? Icons.celebration : Icons.rocket_launch),
                            color: isDone ? Colors.green : (canClaim ? Colors.amber : Colors.white70),
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                quest.title,
                                style: GoogleFonts.outfit(
                                  color: isDone ? Colors.white38 : Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  decoration: isDone ? TextDecoration.lineThrough : null,
                                ),
                              ),
                              const SizedBox(height: 4),
                              _buildQuestRewardBadge(quest),
                            ],
                          ),
                        ),
                        if (canClaim)
                          _buildQuestClaimButton(quest)
                        else if (isDone)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.green.withValues(alpha: 0.5)),
                            ),
                            child: const Text(
                              'ALINDI',
                              style: TextStyle(
                                color: Colors.green,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        quest.description,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.4),
                          fontSize: 13,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 10,
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: FractionallySizedBox(
                              alignment: Alignment.centerLeft,
                              widthFactor: progress,
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: isDone 
                                      ? [Colors.green, Colors.greenAccent]
                                      : [const Color(0xFF6C27FF), const Color(0xFFB392FF)],
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                  boxShadow: [
                                    if (!isDone) 
                                      BoxShadow(
                                        color: const Color(0xFF6C27FF).withValues(alpha: 0.3),
                                        blurRadius: 4,
                                      )
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '${quest.currentProgress}/${quest.goal}',
                          style: GoogleFonts.firaCode(
                            color: isDone ? Colors.white24 : Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ));
    }).toList();
  }

  Widget _buildQuestRewardBadge(Quest quest) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (quest.rewardCoins > 0) ...[
            const Text('🪙', style: TextStyle(fontSize: 13)),
            const SizedBox(width: 4),
            Text('${quest.rewardCoins}', style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 12)),
          ],
          if (quest.rewardPowerupType != null) ...[
            if (quest.rewardCoins > 0) const SizedBox(width: 8),
            Text(PowerupType.fromId(quest.rewardPowerupType!).emoji, style: const TextStyle(fontSize: 13)),
            const SizedBox(width: 4),
            Text('x${quest.rewardPowerupCount ?? 1}', style: const TextStyle(color: Color(0xFF00D9F5), fontWeight: FontWeight.bold, fontSize: 12)),
          ],
        ],
      ),
    );
  }

  Widget _buildQuestClaimButton(Quest quest) {
    return ElevatedButton(
      onPressed: () async {
        final success = await QuestService.instance.claimReward(quest.id);
        if (success) {
          SoundService.instance.playSuccess();
          _internalConfettiController.play();
          widget.onRefresh?.call();
          
          final updatedQuests = await QuestService.instance.getQuests();
          setState(() {
            _quests = updatedQuests;
          });
          
          if (mounted) {
            final messenger = ScaffoldMessenger.of(context);
            messenger.clearSnackBars();
            messenger.showSnackBar(
              SnackBar(
                content: Text(
                  '${quest.title} Ödülü Toplandı! 🎉',
                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                ),
                backgroundColor: Colors.green,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        }
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.amber,
        foregroundColor: Colors.black,
        elevation: 4,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        minimumSize: const Size(60, 36),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      child: const Text('AL', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
    );
  }
}
