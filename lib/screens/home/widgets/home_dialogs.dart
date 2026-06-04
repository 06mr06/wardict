import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../providers/language_provider.dart';
import '../../../models/user_level.dart';
import '../../../services/user_profile_service.dart';
import '../../game/level_selection_screen.dart';
import '../../../widgets/common/daily_reward_dialog.dart';

class HomeDialogs {
  static void showModernInfoDialog({
    required BuildContext context,
    required String title,
    required String icon,
    required Color color,
    required List<Map<String, String>> sections,
    String? buttonText,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: double.maxFinite,
          constraints: const BoxConstraints(maxWidth: 400),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1E3A5F), Color(0xFF0F2027)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 20, spreadRadius: 5),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(icon, style: const TextStyle(fontSize: 24)),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        title.toUpperCase(),
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              // Content
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: sections.map((section) => Padding(
                      padding: const EdgeInsets.only(bottom: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 4,
                                height: 16,
                                decoration: BoxDecoration(
                                  color: color,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                section['title']!,
                                style: GoogleFonts.outfit(
                                  color: color,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            section['body']!,
                            style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.4),
                          ),
                        ],
                      ),
                    )).toList(),
                  ),
                ),
              ),
              
              // Action
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: color,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 5,
                    ),
                    child: Text(
                      (buttonText ?? context.read<LanguageProvider>().getString('close')).toUpperCase(),
                      style: GoogleFonts.outfit(fontWeight: FontWeight.bold, letterSpacing: 1),
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

  static Future<void> showDailyBonusDialog({
    required BuildContext context,
    required Map<String, dynamic> result,
  }) async {
    final coins = result['coins'] as int;
    final streak = result['streak'] as int;
    final rewards = result['rewards'] as List<String>;
    final languageProvider = context.read<LanguageProvider>();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2E5A8C),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Text('🔥', style: TextStyle(fontSize: 28)),
            const SizedBox(width: 10),
            Text(
              languageProvider.getString('daily_bonus_streak').replaceAll('{streak}', streak.toString()),
              style: const TextStyle(color: Colors.white, fontSize: 20),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [const Color(0xFF00F5A0).withOpacity(0.3), const Color(0xFF00D9F5).withOpacity(0.2)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Text(
                    languageProvider.getString('coins_added').replaceAll('{coins}', coins.toString()),
                    style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  if (rewards.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const Divider(color: Colors.white24),
                    const SizedBox(height: 8),
                    ...rewards.map((r) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text(r, style: const TextStyle(color: Colors.amber, fontSize: 14)),
                    )),
                  ],
                ],
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2AA7FF),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(languageProvider.getString('continue_btn'), style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  /// Hoşgeldin hediyesi (yeni kullanıcı) — ödüller zaten verildi; görsel onay.
  static Future<void> showWelcomeGiftDialog(BuildContext context) {
    return DailyRewardDialog.showWelcomeGiftVisual(context);
  }

  static void showMyWordsInfo(BuildContext context) {
    final lp = context.read<LanguageProvider>();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A3A5C),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: Colors.amber.withOpacity(0.5), width: 1.5),
        ),
        title: Row(
          children: [
            const Icon(Icons.history_edu_rounded, color: Colors.amber),
            const SizedBox(width: 12),
            Text(lp.getString('my_words'), style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
             _buildInfoRow('🧠', 'Burada hatalı bildiğin veya öğrendiğin tüm kelimeler toplanır.'),
            const SizedBox(height: 12),
            _buildInfoRow('⏳', 'Akıllı Tekrar Sistemi (SRS) ile kelimeleri en iyi zamanda hatırlatıyoruz.'),
            const SizedBox(height: 12),
            _buildInfoRow('⭐', 'Bir kelimeyi 5 kez doğru bilirsen tam ustalık kazanırsın!'),
            const SizedBox(height: 12),
            _buildInfoRow('🔔', 'Kırmızı rozet, bugün tekrar etmen gereken kelime sayısını gösterir.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ANLADIM', style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  static void showLevelInfo({
    required BuildContext context,
    required UserProfile? userProfile,
    required bool mounted,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1E3A5F), Color(0xFF0F2027)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.info_outline, color: Colors.amber, size: 24),
                const SizedBox(width: 12),
                Text(
                  'SEVİYE SİSTEMİ',
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _buildLevelRow(UserLevel.a1, 'Temel kelimeler', userProfile),
                    _buildLevelRow(UserLevel.a2, 'Günlük kelimeler', userProfile),
                    _buildLevelRow(UserLevel.b1, 'Orta düzey', userProfile),
                    _buildLevelRow(UserLevel.b2, 'İleri düzey', userProfile),
                    _buildLevelRow(UserLevel.c1, 'Akademik', userProfile),
                    _buildLevelRow(UserLevel.c2, 'Uzman', userProfile),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: () async {
                  Navigator.pop(context);
                  // Seviye seçim ekranına git
                  await UserProfileService.instance.resetAll();
                  if (mounted) {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (context) => const LevelSelectionScreen()),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  elevation: 8,
                  shadowColor: Colors.orange.withOpacity(0.4),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: Text(
                  'SEVİYEMİ DEĞİŞTİR',
                  style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 16),
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  static Widget _buildLevelRow(UserLevel level, String description, UserProfile? userProfile) {
    final isCurrentLevel = userProfile?.level == level;
    final color = _getLevelColor(level);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isCurrentLevel ? color.withOpacity(0.2) : Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: isCurrentLevel ? Border.all(color: color, width: 2) : null,
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            padding: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(6)),
            child: Text(
              level.code,
              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            level.turkishName,
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: isCurrentLevel ? FontWeight.bold : FontWeight.normal),
          ),
          const Spacer(),
          Text(description, style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 14)),
          if (isCurrentLevel) ...[
            const SizedBox(width: 8),
            const Icon(Icons.check_circle, color: Colors.green, size: 20),
          ],
        ],
      ),
    );
  }

  static Color _getLevelColor(UserLevel level) {
    switch (level) {
      case UserLevel.a1: return Colors.green;
      case UserLevel.a2: return Colors.lightGreen;
      case UserLevel.b1: return Colors.yellow.shade700;
      case UserLevel.b2: return Colors.orange;
      case UserLevel.c1: return Colors.deepOrange;
      case UserLevel.c2: return Colors.red;
    }
  }

  static Widget _buildInfoRow(String emoji, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(emoji, style: const TextStyle(fontSize: 18)),
        const SizedBox(width: 12),
        Expanded(
          child: Text(text, style: GoogleFonts.outfit(color: Colors.white70, fontSize: 14)),
        ),
      ],
    );
  }
}
