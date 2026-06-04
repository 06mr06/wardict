import 'package:flutter/material.dart';
import '../../services/shop_service.dart';
import 'package:google_fonts/google_fonts.dart';
import '../game/daily_reward_path.dart';
import '../../providers/language_provider.dart';
import 'package:provider/provider.dart';
class DailyRewardDialog extends StatefulWidget {
  final int bonusCoins;
  final int streak;
  final List<String> milestones;
  final bool isNewUser;

  const DailyRewardDialog({
    super.key,
    required this.bonusCoins,
    required this.streak,
    required this.milestones,
    this.isNewUser = false,
  });

  static bool _isShowing = false;

  /// Hoşgeldin ödülü zaten [ShopService.checkAndGiveWelcomeGift] ile verildi; sadece görsel onay.
  static Future<void> showWelcomeGiftVisual(BuildContext context) async {
    if (_isShowing) return;
    _isShowing = true;
    try {
      if (!context.mounted) return;
      final language = context.read<LanguageProvider>();
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) => DailyRewardDialog(
          bonusCoins: ShopService.welcomeGiftCoins,
          streak: 0,
          milestones: ['🃏 2x ${language.getString('powerups')}'],
          isNewUser: true,
        ),
      );
    } finally {
      _isShowing = false;
    }
  }

  static Future<void> show(BuildContext context) async {
    if (_isShowing) return;
    _isShowing = true;

    final result = await ShopService.instance.claimDailyBonus();
    int displayCoins = result['coins'];
    List<String> rewards = List<String>.from(result['rewards']);

    if (displayCoins > 0 || rewards.isNotEmpty) {
      if (!context.mounted) return;
      try {
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => DailyRewardDialog(
            bonusCoins: displayCoins,
            streak: result['streak'],
            milestones: rewards,
            isNewUser: false,
          ),
        );
      } finally {
        _isShowing = false;
      }
    } else {
      _isShowing = false;
    }
  }

  @override
  State<DailyRewardDialog> createState() => _DailyRewardDialogState();
}

class _DailyRewardDialogState extends State<DailyRewardDialog> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _scaleAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
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
    return ScaleTransition(
      scale: _scaleAnimation,
      child: Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1A3A5C), Color(0xFF2E5A8C)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: Colors.white.withAlpha(26)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(128),
                blurRadius: 30,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                (widget.isNewUser 
                  ? context.read<LanguageProvider>().getString('welcome_gift_title')
                  : context.read<LanguageProvider>().getString('welcome_title')).toUpperCase(),
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                ),
              ),
              if (!widget.isNewUser) ...[
                const SizedBox(height: 8),
                Text(
                  context.read<LanguageProvider>().getString('daily_bonus_ready'),
                  style: TextStyle(
                    color: Colors.white.withAlpha(153),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
              const SizedBox(height: 32),
              
              if (widget.isNewUser) ...[
                const SizedBox(height: 16),
                _buildPowerupGrid(context),
              ] else ...[
                // Map View - Sadece eski kullanıcılara göster
                DailyRewardPath(
                  currentStreak: widget.streak,
                  claimedMilestones: widget.milestones,
                  lastClaimDate: DateTime.now(),
                ),
              ],
              
              const SizedBox(height: 32),
              
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6C27FF),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    elevation: 10,
                    shadowColor: const Color(0xFF6C27FF).withAlpha(128),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: Text(
                    context.read<LanguageProvider>().getString('claim_rewards'),
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  Widget _buildPowerupGrid(BuildContext context) {
    final language = context.read<LanguageProvider>();
    return Column(
      children: [
        // Coin Prize Hero
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
          decoration: BoxDecoration(
            color: Colors.amber.withAlpha(30),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.amber.withAlpha(100), width: 2),
            boxShadow: [
              BoxShadow(color: Colors.amber.withAlpha(40), blurRadius: 20),
            ],
          ),
          child: Column(
            children: [
              const Icon(Icons.monetization_on, color: Colors.amber, size: 48),
              const SizedBox(height: 8),
              Text(
                '+${widget.bonusCoins} ${language.getString('coins_unit_label')}',
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        
        // Powerups Title
        Text(
          language.getString('welcome_jokers_added').toUpperCase(),
          style: GoogleFonts.outfit(
            color: const Color(0xFFB388FF), 
            fontSize: 14, 
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 16),
        
        // Joker Grid
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildJokerCard('✂️', Colors.redAccent, '+2'),
            const SizedBox(width: 12),
            _buildJokerCard('🔄', Colors.greenAccent, '+2'),
            const SizedBox(width: 12),
            _buildJokerCard('❄️', Colors.lightBlueAccent, '+2'),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildJokerCard('⚡', Colors.amberAccent, '+2'),
            const SizedBox(width: 12),
            _buildJokerCard('🎯', Colors.pinkAccent, '+2'),
          ],
        ),
      ],
    );
  }

  Widget _buildJokerCard(String emoji, Color color, String badge) {
    return Container(
      width: 70,
      height: 70,
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(15),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withAlpha(100), width: 2),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 32)),
          Positioned(
            bottom: 4,
            right: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                badge,
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
