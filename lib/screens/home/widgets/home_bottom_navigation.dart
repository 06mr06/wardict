import 'package:flutter/material.dart';
import '../../../providers/language_provider.dart';

class HomeBottomNavigation extends StatelessWidget {
  final LanguageProvider languageProvider;
  final VoidCallback onShopTap;
  final VoidCallback onLeaderboardTap;
  final Widget centralWidget;

  const HomeBottomNavigation({
    super.key,
    required this.languageProvider,
    required this.onShopTap,
    required this.onLeaderboardTap,
    required this.centralWidget,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Mağaza
          _buildBottomIconBtn(
            icon: Icons.storefront_rounded,
            label: languageProvider.getString('shop'),
            onTap: onShopTap,
          ),
          
          // MY WORDS (Büyük orta buton) - Passed as widget for flexibility
          centralWidget,
          
          // Sıralama
          _buildBottomIconBtn(
            icon: Icons.stars_rounded,
            label: languageProvider.getString('ranking'),
            onTap: onLeaderboardTap,
          ),
        ],
      ),
    );
  }

  Widget _buildBottomIconBtn({required IconData icon, required String label, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: const Color(0xFFFFD54F), size: 30),
          ),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
