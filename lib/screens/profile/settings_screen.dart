import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../services/firebase/auth_service.dart';
import '../auth/login_screen.dart';

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
            activeColor: const Color(0xFF00D9F5),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
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
              child: Text(
                title,
                style: TextStyle(
                  color: textColor ?? Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
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

  void _showTermsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A3A5C),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Terms and Conditions', style: TextStyle(color: Colors.white)),
        content: SingleChildScrollView(
          child: Text(
            '''WARDICT KULLANIM KOŞULLARI

1. Kabul
Bu uygulamayı kullanarak aşağıdaki şartları kabul etmiş sayılırsınız.

2. Kullanım Hakları
Uygulama yalnızca kişisel ve ticari olmayan amaçlarla kullanılabilir.

3. Hesap Güvenliği
Hesabınızın güvenliğinden siz sorumlusunuz.

4. İçerik
Kullanıcılar uygunsuz içerik paylaşamaz.

5. Sorumluluk Reddi
Uygulama "olduğu gibi" sunulmaktadır.

Son güncelleme: 31 Aralık 2025''',
            style: TextStyle(color: Colors.white.withOpacity(0.8)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Kapat', style: TextStyle(color: Colors.white70)),
          ),
        ],
      ),
    );
  }

  void _showPrivacyDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A3A5C),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Privacy Policy', style: TextStyle(color: Colors.white)),
        content: SingleChildScrollView(
          child: Text(
            '''GİZLİLİK POLİTİKASI

1. Toplanan Veriler
- E-posta adresi
- Kullanıcı adı
- Oyun istatistikleri

2. Veri Kullanımı
Verileriniz yalnızca uygulama deneyimini iyileştirmek için kullanılır.

3. Veri Güvenliği
Verileriniz Firebase üzerinde güvenli şekilde saklanır.

4. Üçüncü Taraflar
Verileriniz üçüncü taraflarla paylaşılmaz.

5. İletişim
sorular için: support@wardict.com

Son güncelleme: 31 Aralık 2025''',
            style: TextStyle(color: Colors.white.withOpacity(0.8)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Kapat', style: TextStyle(color: Colors.white70)),
          ),
        ],
      ),
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
