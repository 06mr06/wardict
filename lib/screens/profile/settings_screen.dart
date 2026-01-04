import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../services/firebase/auth_service.dart';
import '../../services/shop_service.dart';
import '../auth/login_screen.dart';
import '../onboarding/tutorial_screen.dart';
import '../support/support_screen.dart';
import '../support/privacy_policy_screen.dart';
import '../support/terms_of_service_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _soundEnabled = true;
  bool _vibrationEnabled = true;
  bool _notificationsEnabled = true;
  String _version = '';

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadVersion();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _soundEnabled = prefs.getBool('sound_enabled') ?? true;
      _vibrationEnabled = prefs.getBool('vibration_enabled') ?? true;
      _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
    });
  }

  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      setState(() {
        _version = '${info.version} (${info.buildNumber})';
      });
    } catch (e) {
      setState(() {
        _version = '1.0.0';
      });
    }
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('sound_enabled', _soundEnabled);
    await prefs.setBool('vibration_enabled', _vibrationEnabled);
    await prefs.setBool('notifications_enabled', _notificationsEnabled);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF2E5A8C), Color(0xFF1A3A5C)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
                    ),
                    const Expanded(
                      child: Text(
                        'Ayarlar',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),

              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Ses Ayarları
                      _buildSectionTitle('Ses ve Titreşim'),
                      const SizedBox(height: 12),
                      _buildSettingsCard([
                        _buildSwitchTile(
                          icon: Icons.volume_up,
                          title: 'Ses',
                          subtitle: 'Oyun seslerini aç/kapat',
                          value: _soundEnabled,
                          onChanged: (value) {
                            setState(() => _soundEnabled = value);
                            _saveSettings();
                          },
                        ),
                        const Divider(color: Colors.white12),
                        _buildSwitchTile(
                          icon: Icons.vibration,
                          title: 'Titreşim',
                          subtitle: 'Daily123\'te son 5 saniye titreşim',
                          value: _vibrationEnabled,
                          onChanged: (value) {
                            setState(() => _vibrationEnabled = value);
                            _saveSettings();
                            if (value) {
                              HapticFeedback.mediumImpact();
                            }
                          },
                        ),
                      ]),

                      const SizedBox(height: 24),

                      // Bildirimler
                      _buildSectionTitle('Bildirimler'),
                      const SizedBox(height: 12),
                      _buildSettingsCard([
                        _buildSwitchTile(
                          icon: Icons.notifications,
                          title: 'Bildirimler',
                          subtitle: 'Push bildirimlerini aç/kapat',
                          value: _notificationsEnabled,
                          onChanged: (value) {
                            setState(() => _notificationsEnabled = value);
                            _saveSettings();
                          },
                        ),
                      ]),

                      const SizedBox(height: 24),

                      // Yasal
                      _buildSectionTitle('Yasal'),
                      const SizedBox(height: 12),
                      _buildSettingsCard([
                        _buildNavigationTile(
                          icon: Icons.description,
                          title: 'Terms and Conditions',
                          onTap: () => _showTermsDialog(),
                        ),
                        const Divider(color: Colors.white12),
                        _buildNavigationTile(
                          icon: Icons.privacy_tip,
                          title: 'Privacy Policy',
                          onTap: () => _showPrivacyDialog(),
                        ),
                      ]),

                      const SizedBox(height: 24),

                      // Çıkış
                      _buildSettingsCard([
                        _buildNavigationTile(
                          icon: Icons.logout,
                          title: 'Çıkış Yap',
                          iconColor: Colors.red,
                          textColor: Colors.red,
                          onTap: () => _handleLogout(),
                        ),
                      ]),

                      const SizedBox(height: 24),

                      // Diğer
                      _buildSectionTitle('Diğer'),
                      const SizedBox(height: 12),
                      _buildSettingsCard([
                        _buildNavigationTile(
                          icon: Icons.support_agent,
                          title: 'Destek',
                          subtitle: 'Yardım ve geri bildirim',
                          onTap: () => _openSupport(),
                        ),
                        const Divider(color: Colors.white12),
                        _buildNavigationTile(
                          icon: Icons.menu_book,
                          title: 'Rehber',
                          onTap: () => _showGuide(),
                        ),
                        const Divider(color: Colors.white12),
                        _buildNavigationTile(
                          icon: Icons.play_circle_outline,
                          title: 'Tutorial\'ı Tekrar İzle',
                          onTap: () => _showTutorial(),
                        ),
                        const Divider(color: Colors.white12),
                        _buildNavigationTile(
                          icon: Icons.card_giftcard,
                          title: 'Promosyon Kodu Kullan',
                          onTap: () => _showPromoCodeDialog(),
                        ),
                      ]),

                      const SizedBox(height: 40),

                      // Version
                      Center(
                        child: Text(
                          'Version $_version',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.5),
                            fontSize: 14,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildSettingsCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: children,
      ),
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF3D7AB8),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: const Color(0xFF00D9F5),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    String? subtitle,
    Color? iconColor,
    Color? textColor,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconColor?.withOpacity(0.2) ?? const Color(0xFF3D7AB8),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor ?? Colors.white, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: textColor ?? Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: textColor?.withOpacity(0.7) ?? Colors.white60,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: textColor?.withOpacity(0.5) ?? Colors.white54,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }

  void _openSupport() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SupportScreen()),
    );
  }

  void _showTermsDialog() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const TermsOfServiceScreen()),
    );
  }

  void _showPrivacyDialog() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()),
    );
  }

  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A3A5C),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Çıkış Yap',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Hesabınızdan çıkış yapmak istediğinize emin misiniz?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İptal', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
            ),
            child: const Text('Çıkış Yap', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await AuthService.instance.signOut();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
    }
  }

  void _showTutorial() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TutorialScreen(
          onComplete: () => Navigator.of(context).pop(),
        ),
      ),
    );
  }

  void _showPromoCodeDialog() {
    final codeController = TextEditingController();
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1A3A5C),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.card_giftcard, color: Colors.amber, size: 28),
              SizedBox(width: 8),
              Text(
                'Promosyon Kodu',
                style: TextStyle(color: Colors.white),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Premium kazanmak için promosyon kodunuzu girin:',
                style: TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: codeController,
                textCapitalization: TextCapitalization.characters,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Kodu girin...',
                  hintStyle: const TextStyle(color: Colors.white38),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.1),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  prefixIcon: const Icon(Icons.code, color: Colors.white54),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('İptal', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      final code = codeController.text.trim();
                      if (code.isEmpty) return;

                      setDialogState(() => isLoading = true);

                      final result = await ShopService.instance.redeemPromoCode(code);

                      setDialogState(() => isLoading = false);

                      if (!context.mounted) return;
                      Navigator.pop(context);

                      // Sonucu göster
                      ScaffoldMessenger.of(this.context).showSnackBar(
                        SnackBar(
                          content: Text(result['message'] as String),
                          backgroundColor: result['success'] == true
                              ? Colors.green
                              : Colors.red.shade700,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Uygula'),
            ),
          ],
        ),
      ),
    );
  }

  void _showGuide() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Color(0xFF1A3A5C),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white38,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Title
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    Icon(Icons.menu_book, color: Colors.amber, size: 28),
                    SizedBox(width: 12),
                    Text(
                      'Oyun Rehberi',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(color: Colors.white24),
              // Content
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(20),
                  children: [
                    _buildGuideSection(
                      icon: '🎮',
                      title: 'WARDICT Nedir?',
                      description: 'İngilizce kelime bilgini test et ve geliştir! '
                          'Farklı oyun modlarıyla eğlenerek öğren.',
                      color: const Color(0xFF6C27FF),
                    ),
                    _buildGuideSection(
                      icon: '⚔️',
                      title: 'Duel Modu',
                      description: 'Online rakiplerinle, arkadaşlarınla veya '
                          'seviyene uygun botla 10 soruluk düellolara katıl!',
                      color: const Color(0xFF2AA7FF),
                    ),
                    _buildGuideSection(
                      icon: '🎯',
                      title: 'Daily 123',
                      description: '123 saniyede 123 puana ulaşmaya çalış! '
                          'Her gün yeni bir meydan okuma seni bekliyor. '
                          'Hızlı ol, üst sıraları yakala!',
                      color: const Color(0xFFFF6B6B),
                    ),
                    _buildGuideSection(
                      icon: '📚',
                      title: 'Practice Modu',
                      description: 'Kendi hızında pratik yap. '
                          'A2 seviyesinden başla, başarına göre seviye atla!',
                      color: const Color(0xFF00D9F5),
                    ),

                    _buildGuideSection(
                      icon: '⭐',
                      title: 'Premium Özellikler',
                      description: 'Premium üyelikle reklamsız deneyim, '
                          'özel temalar, sınırsız duel ve daha fazlası!',
                      color: const Color(0xFF00F5A0),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGuideSection({
    required String icon,
    required String title,
    required String description,
    required Color color,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.3), color.withOpacity(0.1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(icon, style: const TextStyle(fontSize: 32)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  description,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Vibration helper sınıfı - Daily123'te son 5 saniye için
class VibrationHelper {
  static Future<void> vibrate() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool('vibration_enabled') ?? true;
    if (enabled) {
      HapticFeedback.heavyImpact();
    }
  }
  
  static Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('vibration_enabled') ?? true;
  }
}
