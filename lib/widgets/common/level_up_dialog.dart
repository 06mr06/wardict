import 'package:flutter/material.dart';
import '../../models/user_level.dart';
import '../../services/sound_service.dart';

class LevelUpDialog extends StatefulWidget {
  final UserLevel oldLevel;
  final UserLevel newLevel;

  const LevelUpDialog({
    super.key,
    required this.oldLevel,
    required this.newLevel,
  });

  static Future<void> show(BuildContext context, UserLevel oldLevel, UserLevel newLevel) async {
    SoundService.instance.playLevelUp();
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => LevelUpDialog(oldLevel: oldLevel, newLevel: newLevel),
    );
  }

  @override
  State<LevelUpDialog> createState() => _LevelUpDialogState();
}

class _LevelUpDialogState extends State<LevelUpDialog> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotationAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _scaleAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.6, curve: Curves.elasticOut),
    );
    _rotationAnimation = Tween<double>(begin: 0, end: 2 * 3.14159).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.8, curve: Curves.easeInOutBack)),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF6C27FF), Color(0xFF8E2DE2)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF6C27FF).withAlpha(100),
                blurRadius: 40,
                spreadRadius: 10,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'TEBRİKLER!',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 4,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'SEVİYE ATLADIN',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 40),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildLevelBadge(widget.oldLevel, isSmall: true),
                  const SizedBox(width: 20),
                  const Icon(Icons.double_arrow_rounded, color: Colors.white, size: 40),
                  const SizedBox(width: 20),
                  RotationTransition(
                    turns: AlwaysStoppedAnimation(_rotationAnimation.value / (2 * 3.14159)),
                    child: _buildLevelBadge(widget.newLevel, isGlow: true),
                  ),
                ],
              ),
              const SizedBox(height: 40),
              Text(
                'Artık ${widget.newLevel.turkishName} seviyesindesin!',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF6C27FF),
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    elevation: 5,
                  ),
                  child: const Text(
                    'HARİKA!',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLevelBadge(UserLevel level, {bool isSmall = false, bool isGlow = false}) {
    return Container(
      width: isSmall ? 60 : 90,
      height: isSmall ? 60 : 90,
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(isGlow ? 40 : 20),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: isGlow ? 4 : 2),
        boxShadow: isGlow ? [
          BoxShadow(
            color: Colors.white.withAlpha(100),
            blurRadius: 20,
            spreadRadius: 5,
          ),
        ] : null,
      ),
      child: Center(
        child: Text(
          level.code,
          style: TextStyle(
            color: Colors.white,
            fontSize: isSmall ? 22 : 36,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}
