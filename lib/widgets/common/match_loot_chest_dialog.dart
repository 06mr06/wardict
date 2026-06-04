import 'package:flutter/material.dart';
import '../../services/shop_service.dart';
import '../../providers/language_provider.dart';
import 'package:provider/provider.dart';
import 'package:confetti/confetti.dart';

class MatchLootChestDialog extends StatefulWidget {
  final VoidCallback onClaimed;

  const MatchLootChestDialog({super.key, required this.onClaimed});

  static Future<void> show(BuildContext context, {required VoidCallback onClaimed}) async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => MatchLootChestDialog(onClaimed: onClaimed),
    );
  }

  @override
  State<MatchLootChestDialog> createState() => _MatchLootChestDialogState();
}

class _MatchLootChestDialogState extends State<MatchLootChestDialog> with TickerProviderStateMixin {
  late AnimationController _shakeController;
  late ConfettiController _confettiController;
  bool _isOpened = false;
  bool _isOpening = false;
  Map<String, dynamic>? _reward;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..repeat(reverse: true);
    _confettiController = ConfettiController(duration: const Duration(seconds: 3));
  }

  @override
  void dispose() {
    _shakeController.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  Future<void> _openChest() async {
    if (_isOpening || _isOpened) return;
    
    setState(() => _isOpening = true);
    _shakeController.duration = const Duration(milliseconds: 100);
    _shakeController.repeat(reverse: true);

    await Future.delayed(const Duration(milliseconds: 1500));

    final result = await ShopService.instance.openMatchChest();
    
    if (mounted) {
      setState(() {
        _reward = result;
        _isOpened = true;
        _isOpening = false;
      });
      _shakeController.stop();
      _confettiController.play();
    }
  }

  @override
  Widget build(BuildContext context) {
    final lp = context.read<LanguageProvider>();

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF1E3A5F).withAlpha(240),
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: Colors.amber.withAlpha(100), width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.amber.withAlpha(20),
              blurRadius: 30,
              spreadRadius: 10,
            )
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'ZAFER GANİMETİ!',
              style: const TextStyle(color: Colors.amber, fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 1.2),
            ),
            const SizedBox(height: 32),
            
            // Chest Animation Area
            GestureDetector(
              onTap: _openChest,
              child: AnimatedBuilder(
                animation: _shakeController,
                builder: (context, child) {
                  double offset = _isOpening ? (_shakeController.value * 10 - 5) : 0;
                  return Transform.translate(
                    offset: Offset(offset, 0),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        if (_isOpened) ConfettiWidget(
                          confettiController: _confettiController,
                          blastDirectionality: BlastDirectionality.explosive,
                          colors: const [Colors.amber, Colors.yellow, Colors.orange, Colors.white],
                        ),
                        
                        Container(
                          width: 140,
                          height: 140,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [Colors.amber.withAlpha(50), Colors.transparent],
                            ),
                          ),
                          child: Center(
                            child: Text(
                              _isOpened ? '✨' : '🎁',
                              style: const TextStyle(fontSize: 80),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Status or Reward Text
            if (!_isOpened && !_isOpening)
              Text(
                lp.getString('tap_to_open') == 'tap_to_open' ? 'Açmak için dokun!' : lp.getString('tap_to_open'),
                style: const TextStyle(color: Colors.white70, fontSize: 16),
              )
            else if (_isOpening)
              Text(
                lp.getString('opening') == 'opening' ? 'Açılıyor...' : lp.getString('opening'),
                style: const TextStyle(color: Colors.white70, fontSize: 16, fontStyle: FontStyle.italic),
              )
            else if (_reward != null)
              Column(
                children: [
                  Text(
                    '${_reward!['amount']}x ${_reward!['icon']}',
                    style: const TextStyle(
                      color: Colors.amber,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _reward!['type'] == 'coins' 
                      ? (lp.getString('coins') == 'coins' ? 'Altın Kazandın!' : lp.getString('coins'))
                      : 'Joker Kazandın!',
                    style: const TextStyle(color: Colors.white, fontSize: 18),
                  ),
                ],
              ),
              
            const SizedBox(height: 32),
            
            // Claim Button
            if (_isOpened)
              ElevatedButton(
                onPressed: () {
                  widget.onClaimed();
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 8,
                ),
                child: Text(
                  lp.getString('collect') == 'collect' ? 'Topla' : lp.getString('collect'),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
