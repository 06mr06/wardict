import 'package:flutter/material.dart';
import '../../services/firebase/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../onboarding/tutorial_screen.dart';
import '../../services/firebase/firestore_service.dart';
import '../../services/user_profile_service.dart';
import '../home/welcome_screen.dart';
import '../support/privacy_policy_screen.dart';
import '../support/terms_of_service_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _usernameController = TextEditingController();
  
  bool _isLoading = false;
  bool _isLogin = true; // true = giriş, false = kayıt
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      if (_isLogin) {
        // Giriş yap
        final credential = await AuthService.instance.signInWithEmailOrUsername(
          identifier: _emailController.text.trim(),
          password: _passwordController.text,
        );

        if (credential != null && mounted) {
          _navigateToHome();
        } else {
          _showError(AuthService.instance.errorMessage ?? 'Giriş başarısız');
        }
      } else {
        // Kayıt ol - önce kullanıcı adı kontrolü yap
        final username = _usernameController.text.trim();
        
        // Kullanıcı adı benzersizlik kontrolü
        final isUnique = await FirestoreService.instance.isUsernameUnique(username);
        if (!isUnique) {
          _showError('Bu kullanıcı adı zaten kullanılıyor. Lütfen farklı bir kullanıcı adı seçin.');
          return;
        }
        
        final credential = await AuthService.instance.signUpWithEmail(
          email: _emailController.text.trim(),
          password: _passwordController.text,
          displayName: username,
        );

        if (credential != null && mounted) {
          // Firestore'da profil oluştur (hata olursa devam et)
          try {
            await FirestoreService.instance.createUserProfile(
              odlevel: credential.user!.uid,
              username: username,
              email: _emailController.text.trim(),
            );
            
            // Lokal profili cloud'a senkronize et
            final localProfile = await UserProfileService.instance.loadProfile();
            final updatedProfile = localProfile.copyWith(username: username);
            await UserProfileService.instance.saveProfile(updatedProfile);
            await FirestoreService.instance.syncFromLocal(updatedProfile);
          } catch (e) {
            debugPrint('⚠️ Firestore profil oluşturulamadı (devam ediliyor): $e');
            // Lokal profili güncelle - username'i kaydet
            final localProfile = await UserProfileService.instance.loadProfile();
            final updatedProfile = localProfile.copyWith(username: username);
            await UserProfileService.instance.saveProfile(updatedProfile);
          }

          _navigateToHome();
        } else {
          _showError(AuthService.instance.errorMessage ?? 'Kayıt başarısız');
        }
      }
    } catch (e) {
      _showError('Bir hata oluştu: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ignore: unused_element - Misafir girişi için saklanıyor
  Future<void> _handleGuestLogin() async {
    setState(() => _isLoading = true);

    try {
      final credential = await AuthService.instance.signInAnonymously();
      
      if (credential != null && mounted) {
        final guestUsername = 'Misafir${DateTime.now().millisecondsSinceEpoch % 10000}';
        
        // Anonim kullanıcı için profil oluştur (hata olursa devam et)
        try {
          await FirestoreService.instance.createUserProfile(
            odlevel: credential.user!.uid,
            username: guestUsername,
          );
        } catch (e) {
          debugPrint('⚠️ Firestore profil oluşturulamadı (devam ediliyor): $e');
        }

        // Lokal profili güncelle
        final localProfile = await UserProfileService.instance.loadProfile();
        final updatedProfile = localProfile.copyWith(username: guestUsername);
        await UserProfileService.instance.saveProfile(updatedProfile);

        _navigateToHome();
      } else {
        _showError('Misafir girişi başarısız');
      }
    } catch (e) {
      _showError('Bir hata oluştu: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);

    try {
      final credential = await AuthService.instance.signInWithGoogle();
      
      if (credential != null && mounted) {
        final user = credential.user!;
        final username = user.displayName ?? user.email?.split('@').first ?? 'GoogleUser';
        final email = user.email ?? '';
        
        debugPrint('🔥 Google Giriş - Username: $username, Email: $email');
        
        // Firestore'da profil oluştur (hata olursa devam et)
        try {
          await FirestoreService.instance.createUserProfile(
            odlevel: user.uid,
            username: username,
            email: email,
          );
        } catch (e) {
          debugPrint('⚠️ Firestore profil oluşturulamadı (devam ediliyor): $e');
          // Firestore hatası olsa bile giriş devam etsin
        }

        // Lokal profili yükle ve güncelle
        final localProfile = await UserProfileService.instance.loadProfile();
        final updatedProfile = localProfile.copyWith(
          username: username,
          email: email,
        );
        await UserProfileService.instance.saveProfile(updatedProfile);
        
        // Profili yeniden yükle
        await UserProfileService.instance.reloadProfile();

        _navigateToHome();
      } else {
        _showError(AuthService.instance.errorMessage ?? 'Google girişi başarısız');
      }
    } catch (e) {
      _showError('Bir hata oluştu: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleAppleSignIn() async {
    setState(() => _isLoading = true);

    try {
      final credential = await AuthService.instance.signInWithApple();
      
      if (credential != null && mounted) {
        final user = credential.user!;
        final username = user.displayName ?? user.email?.split('@').first ?? 'AppleUser';
        final email = user.email ?? '';
        
        debugPrint('🍎 Apple Giriş - Username: $username, Email: $email');
        
        // Firestore'da profil oluştur (hata olursa devam et)
        try {
          await FirestoreService.instance.createUserProfile(
            odlevel: user.uid,
            username: username,
            email: email,
          );
        } catch (e) {
          debugPrint('⚠️ Firestore profil oluşturulamadı (devam ediliyor): $e');
        }

        // Lokal profili yükle ve güncelle
        final localProfile = await UserProfileService.instance.loadProfile();
        final updatedProfile = localProfile.copyWith(
          username: username,
          email: email,
        );
        await UserProfileService.instance.saveProfile(updatedProfile);
        
        // Profili yeniden yükle
        await UserProfileService.instance.reloadProfile();

        _navigateToHome();
      } else {
        _showError(AuthService.instance.errorMessage ?? 'Apple girişi başarısız');
      }
    } catch (e) {
      _showError('Bir hata oluştu: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _navigateToHome() async {
    // Tutorial tamamlanmadıysa önce tutorial'a yönlendir
    final prefs = await SharedPreferences.getInstance();
    final showTutorial = !(prefs.getBool('tutorial_completed') ?? false);
    if (showTutorial) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const TutorialScreen()),
      );
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const WelcomeScreen()),
      );
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _handleForgotPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      _showError('Lütfen email adresinizi girin');
      return;
    }

    final success = await AuthService.instance.sendPasswordResetEmail(email);
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 8),
              Text('Şifre sıfırlama emaili gönderildi'),
            ],
          ),
          backgroundColor: Color(0xFF2E5A8C),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      _showError(AuthService.instance.errorMessage ?? 'Email gönderilemedi');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Arka plan - tam ekran resim (contain ile tamamı görünsün)
          Positioned.fill(
            child: Image.asset(
              'assets/images/welcome.png',
              fit: BoxFit.contain,
              alignment: Alignment.topCenter,
              errorBuilder: (context, error, stack) {
                return Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF2E5A8C), Color(0xFF1A3A5C)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                );
              },
            ),
          ),
          
          // Gradient overlay (altta form görünür olsun)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    Colors.black.withOpacity(0.3),
                    Colors.black.withOpacity(0.7),
                    Colors.black.withOpacity(0.9),
                  ],
                  stops: const [0.0, 0.3, 0.5, 0.7],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),
          
          // İçerik
          SafeArea(
            child: Column(
              children: [
                // Üst boşluk - resim görünsün (daha fazla alan)
                const Spacer(flex: 4),
                
                // Alt kısım - Form ve Butonlar (daha az alan)
                Expanded(
                  flex: 6,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Form kartı
                        _buildFormCard(),
                        const SizedBox(height: 12),

                        // Misafir girişi
                        _buildGuestButton(),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ignore: unused_element - Alternatif logo widget'ı olarak saklanıyor
  Widget _buildLogo() {
    return Column(
      children: [
        // Welcome image
        Image.asset(
          'assets/images/welcome.png',
          width: 160,
          height: 160,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stack) {
            // Fallback to icon if image not found
            return Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6C27FF), Color(0xFF2AA7FF)],
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF6C27FF).withOpacity(0.4),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Text(
                '⚔️',
                style: TextStyle(fontSize: 48),
              ),
            );
          },
        ),
        const SizedBox(height: 16),
        ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [Color(0xFF6C27FF), Color(0xFF2AA7FF)],
          ).createShader(bounds),
          child: const Text(
            'LUGORENA',
            style: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 4,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Kelime Düello Oyunu',
          style: TextStyle(
            fontSize: 14,
            color: Colors.white.withOpacity(0.7),
          ),
        ),
      ],
    );
  }

  Widget _buildFormCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            // Tab seçimi
            Row(
              children: [
                Expanded(
                  child: _buildTabButton('Giriş Yap', _isLogin, () {
                    setState(() => _isLogin = true);
                  }),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildTabButton('Kayıt Ol', !_isLogin, () {
                    setState(() => _isLogin = false);
                  }),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Kullanıcı adı (sadece kayıtta)
            if (!_isLogin) ...[
              _buildTextField(
                controller: _usernameController,
                label: 'Kullanıcı Adı',
                icon: Icons.person_outline,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Kullanıcı adı gerekli';
                  }
                  if (value.length < 3) {
                    return 'En az 3 karakter';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
            ],

            // Email veya Kullanıcı Adı
            _buildTextField(
              controller: _emailController,
              label: 'Email veya Kullanıcı Adı',
              icon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Email veya kullanıcı adı gerekli';
                }
                // Eğer @ içeriyorsa email olarak doğrula
                if (value.contains('@')) {
                  if (!value.contains('@') || !value.contains('.')) {
                    return 'Geçerli bir email girin';
                  }
                } else {
                  // Kullanıcı adı ise minimum uzunluk kontrolü
                  if (value.length < 3) {
                    return 'Kullanıcı adı en az 3 karakter olmalı';
                  }
                }
                return null;
              },
            ),
            const SizedBox(height: 12),

            // Şifre
            _buildTextField(
              controller: _passwordController,
              label: 'Şifre',
              icon: Icons.lock_outline,
              obscureText: _obscurePassword,
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off : Icons.visibility,
                  color: Colors.white54,
                ),
                onPressed: () {
                  setState(() => _obscurePassword = !_obscurePassword);
                },
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Şifre gerekli';
                }
                if (value.length < 6) {
                  return 'En az 6 karakter';
                }
                return null;
              },
            ),

            // Şifremi unuttum (sadece girişte)
            if (_isLogin) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _handleForgotPassword,
                  child: Text(
                    'Şifremi Unuttum',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),

            // Submit butonu
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _handleSubmit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6C27FF),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 4,
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        _isLogin ? 'Giriş Yap' : 'Kayıt Ol',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabButton(String text, bool isActive, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          gradient: isActive
              ? const LinearGradient(
                  colors: [Color(0xFF6C27FF), Color(0xFF2AA7FF)],
                )
              : null,
          color: isActive ? null : Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Center(
          child: Text(
            text,
            style: TextStyle(
              color: Colors.white,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscureText = false,
    Widget? suffixIcon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      validator: validator,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
        prefixIcon: Icon(icon, color: Colors.white54),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: Colors.white.withOpacity(0.15),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.4), width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.4), width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF6C27FF), width: 2.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red, width: 1.5),
        ),
      ),
    );
  }

  Widget _buildGuestButton() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: Divider(color: Colors.white.withOpacity(0.3))),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'veya',
                style: TextStyle(color: Colors.white.withOpacity(0.5)),
              ),
            ),
            Expanded(child: Divider(color: Colors.white.withOpacity(0.3))),
          ],
        ),
        const SizedBox(height: 16),
        
        // Google ve Apple ile Giriş - Yan yana simge butonları
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Google butonu - Apple gibi beyaz çerçeveli siyah zemin
            Container(
              width: 60,
              height: 50,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: ElevatedButton(
                onPressed: _isLoading ? null : _handleGoogleSignIn,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 0,
                ),
                child: ShaderMask(
                  shaderCallback: (bounds) => const SweepGradient(
                    center: Alignment.center,
                    startAngle: 0.5,
                    endAngle: 6.0,
                    colors: [
                      Color(0xFF4285F4), // Mavi
                      Color(0xFF34A853), // Yeşil
                      Color(0xFFFBBC05), // Sarı
                      Color(0xFFEA4335), // Kırmızı
                      Color(0xFF4285F4), // Mavi (döngü)
                    ],
                  ).createShader(bounds),
                  child: const Text(
                    'G',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            // Apple butonu - Her platformda göster
            Container(
              width: 60,
              height: 50,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: ElevatedButton(
                onPressed: _isLoading ? null : _handleAppleSignIn,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 0,
                ),
                child: const Icon(Icons.apple, size: 28),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Privacy Policy ve Terms of Service linkleri
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()),
              ),
              child: Text(
                'Gizlilik',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 11,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
            Text(
              ' • ',
              style: TextStyle(color: Colors.white.withOpacity(0.4)),
            ),
            GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TermsOfServiceScreen()),
              ),
              child: Text(
                'Kullanım Şartları',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 11,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
