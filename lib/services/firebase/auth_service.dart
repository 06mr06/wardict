import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Kimlik doğrulama durumu
enum AuthStatus {
  initial,
  authenticated,
  unauthenticated,
  error,
}

/// Firebase Authentication servisi
class AuthService extends ChangeNotifier {
  static AuthService? _instance;
  static AuthService get instance => _instance ??= AuthService._();

  AuthService._() {
    // Auth durumu değişikliklerini dinle
    _auth.authStateChanges().listen(_onAuthStateChanged);
  }

  final FirebaseAuth _auth = FirebaseAuth.instance;

  User? _user;
  AuthStatus _status = AuthStatus.initial;
  String? _errorMessage;

  // Getters
  User? get user => _user;
  AuthStatus get status => _status;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _status == AuthStatus.authenticated;
  String? get userId => _user?.uid;
  String? get userEmail => _user?.email;
  String? get displayName => _user?.displayName;
  String? get photoURL => _user?.photoURL;

  void _onAuthStateChanged(User? user) {
    _user = user;
    if (user != null) {
      _status = AuthStatus.authenticated;
      debugPrint('✅ Kullanıcı giriş yaptı: ${user.email}');
    } else {
      _status = AuthStatus.unauthenticated;
      debugPrint('ℹ️ Kullanıcı çıkış yaptı');
    }
    notifyListeners();
  }

  /// Email/Password ile kayıt
  Future<UserCredential?> signUpWithEmail({
    required String email,
    required String password,
    String? displayName,
  }) async {
    try {
      _errorMessage = null;
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Display name güncelle
      if (displayName != null && credential.user != null) {
        await credential.user!.updateDisplayName(displayName);
      }

      return credential;
    } on FirebaseAuthException catch (e) {
      _errorMessage = _getErrorMessage(e.code);
      _status = AuthStatus.error;
      notifyListeners();
      debugPrint('❌ Kayıt hatası: ${e.code}');
      return null;
    }
  }

  /// Email/Password ile giriş
  Future<UserCredential?> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      _errorMessage = null;
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return credential;
    } on FirebaseAuthException catch (e) {
      _errorMessage = _getErrorMessage(e.code);
      _status = AuthStatus.error;
      notifyListeners();
      debugPrint('❌ Giriş hatası: ${e.code}');
      return null;
    }
  }

  /// Anonim giriş (misafir olarak oyna)
  Future<UserCredential?> signInAnonymously() async {
    try {
      _errorMessage = null;
      final credential = await _auth.signInAnonymously();
      debugPrint('✅ Anonim giriş başarılı');
      return credential;
    } on FirebaseAuthException catch (e) {
      _errorMessage = _getErrorMessage(e.code);
      _status = AuthStatus.error;
      notifyListeners();
      debugPrint('❌ Anonim giriş hatası: ${e.code}');
      return null;
    }
  }

  /// Google ile giriş
  Future<UserCredential?> signInWithGoogle() async {
    try {
      _errorMessage = null;
      
      if (kIsWeb) {
        // Web için popup kullan
        final googleProvider = GoogleAuthProvider();
        googleProvider.addScope('email');
        googleProvider.addScope('profile');
        final credential = await _auth.signInWithPopup(googleProvider);
        debugPrint('✅ Google giriş başarılı (Web): ${credential.user?.email}');
        return credential;
      } else {
        // Mobil için signInWithProvider kullan (daha basit)
        final googleProvider = GoogleAuthProvider();
        googleProvider.addScope('email');
        googleProvider.addScope('profile');
        
        try {
          final credential = await _auth.signInWithProvider(googleProvider);
          debugPrint('✅ Google giriş başarılı (Mobil): ${credential.user?.email}');
          return credential;
        } catch (e) {
          debugPrint('⚠️ signInWithProvider hatası, alternatif yöntem deneniyor: $e');
          
          // Fallback: google_sign_in paketi ile dene
          // Not: Bu çalışması için SHA-1 fingerprint Firebase'e eklenmeli
          throw Exception('Google Sign-In için SHA-1 fingerprint Firebase Console\'a eklenmeli. FIREBASE_SETUP.md dosyasına bakın.');
        }
      }
    } catch (e) {
      _errorMessage = 'Google ile giriş başarısız oldu. Lütfen SHA-1 fingerprint\'i Firebase\'e ekleyin.';
      _status = AuthStatus.error;
      notifyListeners();
      debugPrint('❌ Google giriş hatası: $e');
      return null;
    }
  }

  /// Çıkış yap
  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      debugPrint('❌ Çıkış hatası: $e');
    }
  }

  /// Şifre sıfırlama emaili gönder
  Future<bool> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      return true;
    } on FirebaseAuthException catch (e) {
      _errorMessage = _getErrorMessage(e.code);
      notifyListeners();
      return false;
    }
  }

  /// Display name güncelle
  Future<void> updateDisplayName(String name) async {
    if (_user == null) return;
    await _user!.updateDisplayName(name);
    await _user!.reload();
    _user = _auth.currentUser;
    notifyListeners();
  }

  /// Profil fotoğrafı güncelle
  Future<void> updatePhotoURL(String url) async {
    if (_user == null) return;
    await _user!.updatePhotoURL(url);
    await _user!.reload();
    _user = _auth.currentUser;
    notifyListeners();
  }

  /// Anonim hesabı email hesabına bağla
  Future<UserCredential?> linkAnonymousToEmail({
    required String email,
    required String password,
  }) async {
    if (_user == null || !_user!.isAnonymous) return null;

    try {
      final credential = EmailAuthProvider.credential(
        email: email,
        password: password,
      );
      return await _user!.linkWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      _errorMessage = _getErrorMessage(e.code);
      notifyListeners();
      return null;
    }
  }

  /// Hata mesajlarını Türkçe'ye çevir
  String _getErrorMessage(String code) {
    switch (code) {
      case 'user-not-found':
        return 'Bu email adresi ile kayıtlı kullanıcı bulunamadı.';
      case 'wrong-password':
        return 'Hatalı şifre girdiniz.';
      case 'email-already-in-use':
        return 'Bu email adresi zaten kullanılıyor.';
      case 'weak-password':
        return 'Şifre çok zayıf. En az 6 karakter kullanın.';
      case 'invalid-email':
        return 'Geçersiz email adresi.';
      case 'user-disabled':
        return 'Bu hesap devre dışı bırakılmış.';
      case 'too-many-requests':
        return 'Çok fazla deneme yaptınız. Lütfen bekleyin.';
      case 'operation-not-allowed':
        return 'Bu işlem şu anda kullanılamıyor.';
      case 'network-request-failed':
        return 'İnternet bağlantınızı kontrol edin.';
      default:
        return 'Bir hata oluştu. Lütfen tekrar deneyin.';
    }
  }
}
