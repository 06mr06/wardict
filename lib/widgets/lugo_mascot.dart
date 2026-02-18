import 'package:flutter/material.dart';

class LugoMascot extends StatelessWidget {
  final String message;
  final double size;
  final bool flipped;
  const LugoMascot({
    Key? key,
    required this.message,
    this.size = 180,
    this.flipped = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (flipped) _buildSpeechBubble(context),
        Stack(
          alignment: Alignment.bottomCenter,
          children: [
            // Lugo karakteri (PNG veya animasyonlu görsel)
            Image.asset(
              'assets/images/lugo.png',
              width: size,
              height: size,
              fit: BoxFit.contain,
            ),
          ],
        ),
        if (!flipped) _buildSpeechBubble(context),
      ],
    );
  }

  Widget _buildSpeechBubble(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      constraints: const BoxConstraints(maxWidth: 220),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(2, 4),
          ),
        ],
      ),
      child: Text(
        message,
        style: const TextStyle(
          color: Color(0xFF1A3A5C),
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
