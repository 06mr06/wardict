import 'package:flutter/material.dart';
import '../../../providers/language_provider.dart';

class MyWordsButton extends StatelessWidget {
  final LanguageProvider languageProvider;
  final VoidCallback onTap;
  final VoidCallback onInfoTap;

  const MyWordsButton({
    super.key,
    required this.languageProvider,
    required this.onTap,
    required this.onInfoTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            GestureDetector(
              onTap: onTap,
              child: Container(
                height: 52,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(30),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF3A608C), Color(0xFF1A3A5C)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  border: Border.all(color: const Color(0xFFFFD700).withValues(alpha: 0.5), width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.history_edu_rounded, color: Colors.amber, size: 28),
                    const SizedBox(width: 10),
                    Text(
                      languageProvider.getString('my_words').toUpperCase(),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: 1),
                    ),
                  ],
                ),
              ),
            ),
            // Info Button
            Positioned(
              top: -5,
              right: -5,
              child: GestureDetector(
                onTap: onInfoTap,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.amber,
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFF1A3A5C), width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.info_outline, color: Color(0xFF1A3A5C), size: 16),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
