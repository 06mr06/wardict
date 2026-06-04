import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import '../../providers/language_provider.dart';
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
                      icon:
                          const Icon(Icons.arrow_back_ios, color: Colors.white),
                    ),
                    Expanded(
                      child: Text(
                        context.watch<LanguageProvider>().getString('settings'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
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
                      // Genel Ayarlar
                      _buildSectionTitle(context
                          .watch<LanguageProvider>()
                          .getString('general')),
                      const SizedBox(height: 12),
                      _buildSettingsCard([
                        _buildLanguageTile(),
                      ]),
                      const SizedBox(height: 24),

                      // Ses Ayarları
                      _buildSectionTitle(context
                          .watch<LanguageProvider>()
                          .getString('sound_vibration')),
                      const SizedBox(height: 12),
                      _buildSettingsCard([
                        _buildSwitchTile(
                          icon: Icons.volume_up,
                          title: context
                              .watch<LanguageProvider>()
                              .getString('sound'),
                          subtitle: context
                              .watch<LanguageProvider>()
                              .getString('sound_subtitle'),
                          value: _soundEnabled,
                          onChanged: (value) {
                            setState(() => _soundEnabled = value);
                            _saveSettings();
                          },
                        ),
                        const Divider(color: Colors.white12),
                        _buildSwitchTile(
                          icon: Icons.vibration,
                          title: context
                              .watch<LanguageProvider>()
                              .getString('vibration'),
                          subtitle: context
                              .watch<LanguageProvider>()
                              .getString('vibration_subtitle'),
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
                      _buildSectionTitle(context
                          .watch<LanguageProvider>()
                          .getString('notifications')),
                      const SizedBox(height: 12),
                      _buildSettingsCard([
                        _buildSwitchTile(
                          icon: Icons.notifications,
                          title: context
                              .watch<LanguageProvider>()
                              .getString('notifications'),
                          subtitle: context
                              .watch<LanguageProvider>()
                              .getString('notifications_subtitle'),
                          value: _notificationsEnabled,
                          onChanged: (value) {
                            setState(() => _notificationsEnabled = value);
                            _saveSettings();
                          },
                        ),
                      ]),

                      const SizedBox(height: 24),

                      // Yasal
                      _buildSectionTitle(
                          context.watch<LanguageProvider>().getString('legal')),
                      const SizedBox(height: 12),
                      _buildSettingsCard([
                        _buildNavigationTile(
                          icon: Icons.description,
                          title: context
                              .watch<LanguageProvider>()
                              .getString('terms'),
                          onTap: () => _showTermsDialog(),
                        ),
                        const Divider(color: Colors.white12),
                        _buildNavigationTile(
                          icon: Icons.privacy_tip,
                          title: context
                              .watch<LanguageProvider>()
                              .getString('privacy'),
                          onTap: () => _showPrivacyDialog(),
                        ),
                      ]),

                      const SizedBox(height: 24),

                      // Çıkış
                      _buildSettingsCard([
                        _buildNavigationTile(
                          icon: Icons.logout,
                          title: context
                              .watch<LanguageProvider>()
                              .getString('logout'),
                          iconColor: Colors.red,
                          textColor: Colors.red,
                          onTap: () => _handleLogout(),
                        ),
                        const Divider(color: Colors.white12),
                        _buildNavigationTile(
                          icon: Icons.delete_forever,
                          title: context
                              .watch<LanguageProvider>()
                              .getString('delete_account'),
                          iconColor: Colors.red,
                          textColor: Colors.red,
                          onTap: () => _handleDeleteAccount(),
                        ),
                      ]),

                      const SizedBox(height: 24),

                      // Diğer
                      _buildSectionTitle(
                          context.watch<LanguageProvider>().getString('other')),
                      const SizedBox(height: 12),
                      _buildSettingsCard([
                        _buildNavigationTile(
                          icon: Icons.support_agent,
                          title: context
                              .watch<LanguageProvider>()
                              .getString('support'),
                          subtitle: context
                              .watch<LanguageProvider>()
                              .getString('support_subtitle'),
                          onTap: () => _openSupport(),
                        ),
                        const Divider(color: Colors.white12),
                        _buildNavigationTile(
                          icon: Icons.menu_book,
                          title: context
                              .watch<LanguageProvider>()
                              .getString('guide'),
                          onTap: () => _showGuide(),
                        ),
                        const Divider(color: Colors.white12),
                        _buildNavigationTile(
                          icon: Icons.play_circle_outline,
                          title: context
                              .watch<LanguageProvider>()
                              .getString('replay_tutorial'),
                          onTap: () => _showTutorial(),
                        ),
                        const Divider(color: Colors.white12),
                        _buildNavigationTile(
                          icon: Icons.card_giftcard,
                          title: context
                              .watch<LanguageProvider>()
                              .getString('promo_code'),
                          onTap: () => _showPromoCodeDialog(),
                        ),
                      ]),

                      const SizedBox(height: 40),

                      // Version
                      Center(
                        child: Text(
                          '${context.watch<LanguageProvider>().getString('version')} $_version',
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
        title: Text(
          context.read<LanguageProvider>().getString('logout'),
          style: const TextStyle(color: Colors.white),
        ),
        content: Text(
          context.read<LanguageProvider>().getString('confirm_logout'),
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.read<LanguageProvider>().getString('cancel'),
                style: const TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
            ),
            child: Text(context.read<LanguageProvider>().getString('logout'),
                style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await AuthService.instance.signOut();
    }
  }

  void _showTutorial() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const TutorialScreen(),
      ),
    );
  }

  void _showPromoCodeDialog() {
    final codeController = TextEditingController();
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1A3A5C),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.card_giftcard, color: Colors.amber, size: 28),
              const SizedBox(width: 8),
              Text(
                context.read<LanguageProvider>().getString('promo_code_title'),
                style: const TextStyle(color: Colors.white),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                context.read<LanguageProvider>().getString('promo_code_body'),
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: codeController,
                textCapitalization: TextCapitalization.characters,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText:
                      context.read<LanguageProvider>().getString('enter_code'),
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
              child: Text(context.read<LanguageProvider>().getString('cancel'),
                  style: const TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      final code = codeController.text.trim();
                      if (code.isEmpty) return;

                      setDialogState(() => isLoading = true);

                      final result =
                          await ShopService.instance.redeemPromoCode(code);

                      setDialogState(() => isLoading = false);

                      if (!mounted) return;
                      Navigator.pop(dialogContext);

                      // Sonucu göster
                      ScaffoldMessenger.of(context).showSnackBar(
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
                  : Text(context.read<LanguageProvider>().getString('apply')),
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
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    const Icon(Icons.menu_book, color: Colors.amber, size: 28),
                    const SizedBox(width: 12),
                    Text(
                      context.watch<LanguageProvider>().getString('game_guide'),
                      style: const TextStyle(
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
                      title: context
                          .read<LanguageProvider>()
                          .getString('guide_title_1'),
                      description: context
                          .read<LanguageProvider>()
                          .getString('guide_desc_1'),
                      color: const Color(0xFF6C27FF),
                    ),
                    _buildGuideSection(
                      icon: '⚔️',
                      title: context
                          .read<LanguageProvider>()
                          .getString('guide_title_2'),
                      description: context
                          .read<LanguageProvider>()
                          .getString('guide_desc_2'),
                      color: const Color(0xFF2AA7FF),
                    ),
                    _buildGuideSection(
                      icon: '🎯',
                      title: context
                          .read<LanguageProvider>()
                          .getString('guide_title_3'),
                      description: context
                          .read<LanguageProvider>()
                          .getString('guide_desc_3'),
                      color: const Color(0xFFFF6B6B),
                    ),
                    _buildGuideSection(
                      icon: '📚',
                      title: context
                          .read<LanguageProvider>()
                          .getString('guide_title_4'),
                      description: context
                          .read<LanguageProvider>()
                          .getString('guide_desc_4'),
                      color: const Color(0xFF00D9F5),
                    ),
                    _buildGuideSection(
                      icon: '⭐',
                      title: context
                          .read<LanguageProvider>()
                          .getString('guide_title_5'),
                      description: context
                          .read<LanguageProvider>()
                          .getString('guide_desc_5'),
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

  Widget _buildLanguageTile() {
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
            child: const Icon(Icons.language, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              context.watch<LanguageProvider>().getString('language'),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          DropdownButton<String>(
            value: context.watch<LanguageProvider>().currentLanguage,
            dropdownColor: const Color(0xFF1A3A5C),
            style: const TextStyle(color: Colors.white),
            underline: const SizedBox(),
            items: const [
              DropdownMenuItem(value: 'tr', child: Text('Türkçe 🇹🇷')),
              DropdownMenuItem(value: 'en', child: Text('English 🇺🇸')),
            ],
            onChanged: (value) {
              if (value != null) {
                context.read<LanguageProvider>().setLanguage(value);
              }
            },
          ),
        ],
      ),
    );
  }

  Future<void> _handleDeleteAccount() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A3A5C),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.orange),
            const SizedBox(width: 10),
            Text(context.read<LanguageProvider>().getString('delete_account'),
                style: const TextStyle(color: Colors.white)),
          ],
        ),
        content: Text(
          context.read<LanguageProvider>().getString('confirm_delete'),
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.read<LanguageProvider>().getString('cancel'),
                style: const TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
            ),
            child: Text(
                context.read<LanguageProvider>().getString('delete_account'),
                style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      try {
        await AuthService.instance.deleteAccount();
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const LoginScreen()),
            (route) => false,
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AuthService.instance.errorMessage ??
                  'Error deleting account'),
              backgroundColor: Colors.red.shade700,
            ),
          );
        }
      }
    }
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
