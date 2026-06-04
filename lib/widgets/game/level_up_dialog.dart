import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';
import 'package:provider/provider.dart';
import '../../providers/language_provider.dart';
import '../../services/sound_service.dart';

class LevelUpDialog extends StatefulWidget {
  final String oldLevel;
  final String newLevel;
  final bool isPromotion;

  const LevelUpDialog({
    super.key,
    required this.oldLevel,
    required this.newLevel,
    required this.isPromotion,
  });

  static Future<void> show(
    BuildContext context, {
    required String oldLevel,
    required String newLevel,
    required bool isPromotion,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => LevelUpDialog(
        oldLevel: oldLevel,
        newLevel: newLevel,
        isPromotion: isPromotion,
      ),
    );
  }

  @override
  State<LevelUpDialog> createState() => _LevelUpDialogState();
}

class _LevelUpDialogState extends State<LevelUpDialog>
    with TickerProviderStateMixin {
  late ConfettiController _confettiController;
  late AnimationController _scaleController;
  late AnimationController _glowController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();

    _confettiController =
        ConfettiController(duration: const Duration(seconds: 5));

    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.elasticOut),
    );

    _glowAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    if (widget.isPromotion) {
      _confettiController.play();
      SoundService.instance.playLevelUp();
    } else {
      // Level down - no sound for now
    }

    _scaleController.forward();
    _glowController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _scaleController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  Color get _levelColor {
    switch (widget.newLevel) {
      case 'A1':
        return const Color(0xFFCD7F32);
      case 'A2':
        return const Color(0xFFB0C4DE);
      case 'B1':
        return const Color(0xFFFFD700);
      case 'B2':
        return const Color(0xFFFFA500);
      case 'C1':
        return const Color(0xFF9370DB);
      case 'C2':
        return const Color(0xFF00CED1);
      default:
        return Colors.blue;
    }
  }

  String get _levelName {
    switch (widget.newLevel) {
      case 'A1':
        return 'Harf';
      case 'A2':
        return 'Hece';
      case 'B1':
        return 'Kelime';
      case 'B2':
        return 'Cümle';
      case 'C1':
        return 'Roman';
      case 'C2':
        return 'Yazar';
      default:
        return '';
    }
  }

  IconData get _levelIcon {
    switch (widget.newLevel) {
      case 'A1':
        return Icons.abc;
      case 'A2':
        return Icons.text_fields;
      case 'B1':
        return Icons.abc;
      case 'B2':
        return Icons.short_text;
      case 'C1':
        return Icons.menu_book;
      case 'C2':
        return Icons.auto_stories;
      default:
        return Icons.star;
    }
  }

  @override
  Widget build(BuildContext context) {
    final lp = context.read<LanguageProvider>();

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(color: Colors.black54),
          ),
          if (widget.isPromotion)
            Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.only(top: 100),
                child: ConfettiWidget(
                  confettiController: _confettiController,
                  blastDirectionality: BlastDirectionality.explosive,
                  shouldLoop: false,
                  numberOfParticles: 50,
                  maxBlastForce: 30,
                  minBlastForce: 10,
                  gravity: 0.3,
                  emissionFrequency: 0.05,
                  colors: [
                    _levelColor,
                    Colors.amber,
                    Colors.white,
                    _levelColor.withValues(alpha: 0.7),
                  ],
                ),
              ),
            ),
          Center(
            child: AnimatedBuilder(
              animation: _scaleAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _scaleAnimation.value,
                  child: child,
                );
              },
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 32),
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: widget.isPromotion
                        ? [const Color(0xFF2E5A8C), const Color(0xFF1A3A5C)]
                        : [const Color(0xFF5C2E2E), const Color(0xFF3D1A1A)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(32),
                  border: Border.all(
                    color: widget.isPromotion ? Colors.amber : Colors.red,
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (widget.isPromotion ? Colors.amber : Colors.red)
                          .withValues(alpha: 0.3),
                      blurRadius: 30,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedBuilder(
                      animation: _glowAnimation,
                      builder: (context, child) {
                        return Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: _levelColor.withValues(alpha: 
                                    0.3 + (_glowAnimation.value * 0.4)),
                                blurRadius: 30 + (_glowAnimation.value * 20),
                                spreadRadius: 5 + (_glowAnimation.value * 10),
                              ),
                            ],
                          ),
                          child: Icon(
                            widget.isPromotion
                                ? Icons.arrow_upward_rounded
                                : Icons.arrow_downward_rounded,
                            color: widget.isPromotion
                                ? Colors.greenAccent
                                : Colors.redAccent,
                            size: 48,
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    Text(
                      widget.isPromotion ? 'SEVİYE ATLADIN!' : 'SEVİYE DÜŞTÜN',
                      style: TextStyle(
                        color: widget.isPromotion
                            ? Colors.amber
                            : Colors.redAccent,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildLevelBadge(widget.oldLevel, false),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Icon(
                            Icons.arrow_forward,
                            color: widget.isPromotion
                                ? Colors.greenAccent
                                : Colors.redAccent,
                            size: 32,
                          ),
                        ),
                        _buildLevelBadge(widget.newLevel, true),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                      decoration: BoxDecoration(
                        color: _levelColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: _levelColor.withValues(alpha: 0.5)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(_levelIcon, color: _levelColor, size: 24),
                          const SizedBox(width: 8),
                          Text(
                            '${widget.newLevel} - $_levelName',
                            style: TextStyle(
                              color: _levelColor,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              widget.isPromotion ? Colors.amber : Colors.red,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(
                          widget.isPromotion ? 'HARİKA!' : 'DEVAM ET',
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLevelBadge(String level, bool isHighlighted) {
    final color = isHighlighted ? _levelColor : Colors.white38;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Text(
        level,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w900,
          fontSize: 20,
        ),
      ),
    );
  }
}
