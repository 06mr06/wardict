import 'dart:async';
import 'package:flutter/material.dart';
import 'daily_123_screen.dart';

class Daily123IntroScreen extends StatefulWidget {
  const Daily123IntroScreen({super.key});

  @override
  State<Daily123IntroScreen> createState() => _Daily123IntroScreenState();
}

class _Daily123IntroScreenState extends State<Daily123IntroScreen> with TickerProviderStateMixin {
  int _step = 0; // 0: Daily, 1: 1, 2: 2, 3: 3
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotateAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );
    _rotateAnimation = Tween<double>(begin: -0.2, end: 0.1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _startAnimation();
  }

  Future<void> _startAnimation() async {
    // Step 0: Daily
    setState(() => _step = 0);
    _controller.forward(from: 0);
    await Future.delayed(const Duration(milliseconds: 800));

    // Step 1: 1
    setState(() => _step = 1);
    _controller.forward(from: 0);
    await Future.delayed(const Duration(milliseconds: 600));

    // Step 2: 2
    setState(() => _step = 2);
    _controller.forward(from: 0);
    await Future.delayed(const Duration(milliseconds: 600));

    // Step 3: 3
    setState(() => _step = 3);
    _controller.forward(from: 0);
    await Future.delayed(const Duration(milliseconds: 1000));

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const Daily123Screen()),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF2E5A8C),
      body: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Transform.scale(
              scale: _scaleAnimation.value,
              child: Transform.rotate(
                angle: _rotateAnimation.value,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'DAILY',
                      style: TextStyle(
                        fontSize: 80,
                        fontWeight: FontWeight.w900,
                        color: Colors.amber,
                        fontStyle: FontStyle.italic,
                        letterSpacing: 2,
                        shadows: [
                          const Shadow(color: Colors.black, offset: Offset(4, 4)),
                          Shadow(color: Colors.amber.withOpacity(0.5), blurRadius: 20),
                        ],
                      ),
                    ),
                    if (_step >= 1)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildNumber('1', _step >= 1 ? 1.0 : 0.0, Colors.red),
                          if (_step >= 2) _buildNumber('2', _step >= 2 ? 1.0 : 0.0, Colors.green),
                          if (_step >= 3) _buildNumber('3', _step >= 3 ? 1.0 : 0.0, Colors.blue),
                        ],
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildNumber(String num, double opacity, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Text(
        num,
        style: TextStyle(
          fontSize: 100,
          fontWeight: FontWeight.w900,
          color: color,
          shadows: [
            const Shadow(color: Colors.black, offset: Offset(5, 5)),
          ],
        ),
      ),
    );
  }
}
