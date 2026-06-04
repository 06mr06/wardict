import 'package:flutter/material.dart';
import '../../services/shop_service.dart';
import '../../providers/language_provider.dart';
import 'package:provider/provider.dart';
import 'package:confetti/confetti.dart';

class DailyLuckChestDialog extends StatefulWidget {
  final VoidCallback onClaimed;

  const DailyLuckChestDialog({super.key, required this.onClaimed});

  static Future<void> show(BuildContext context, {required VoidCallback onClaimed}) async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => DailyLuckChestDialog(onClaimed: onClaimed),
    );
  }

  @override
  State<DailyLuckChestDialog> createState() => _DailyLuckChestDialogState();
}

class _DailyLuckChestDialogState extends State<DailyLuckChestDialog> with TickerProviderStateMixin {
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

    final result = await ShopService.instance.openLuckChest();
    
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
          border: Border.all(color: Colors.white.withAlpha(51), width: 2),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              (lp.getString('lucky_chest_title') == 'lucky_chest_title' ? 'GÜNLÜK ŞANS SANDIĞI' : lp.getString('lucky_chest_title')).toUpperCase(),
              style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 1.2),
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
                        if (_isOpened) 
                          ConfettiWidget(
                            confettiController: _confettiController,
                            blastDirectionality: BlastDirectionality.explosive,
                            shouldLoop: false,
                            colors: const [Colors.amber, Colors.orange, Colors.white],
                          ),
                        Text(
                          _isOpened ? (_reward?['icon'] ?? '🎁') : '🎁',
                          style: const TextStyle(fontSize: 100),
                        ),
                        if (!_isOpened && !_isOpening)
                          const Positioned(
                            bottom: 0,
                            child: Text(
                              'AÇMAK İÇİN DOKUN!',
                              style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 32),

            if (_isOpened && _reward != null) ...[
              Text(
                'TEBRİKLER!',
                style: TextStyle(color: Colors.amber.shade300, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _reward!['icon'] ?? '',
                    style: const TextStyle(fontSize: 24),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${_reward!['amount']} ${_reward!['type'] == 'coins' ? 'Altın' : 'Joker'} kazandın!',
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],

            if (_isOpened)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    widget.onClaimed();
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('TAMAM', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              
            if (!_isOpened)
              Text(
                'Her 24 saatte bir yeni bir şans!',
                style: TextStyle(color: Colors.white.withAlpha(150), fontSize: 12),
              ),
          ],
        ),
      ),
    );
  }
}
