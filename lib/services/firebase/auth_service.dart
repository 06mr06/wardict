import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firestore_service.dart';
import '../shop_service.dart';
import '../../models/premium.dart';
import '../user_profile_service.dart';
import 'package:google_sign_in/google_sign_in.dart' as gsi;

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

  /// Profilde `createdAt` yoksa katılım tarihi için kullanılır (gerçek hesap açılışı).
  DateTime? get accountCreatedAt => _user?.metadata.creationTime;

  /// Kullanıcının yönetici olup olmadığını kontrol eder
  bool get isAdmin {
    if (_user == null) return false;
    final email = _user?.email?.toLowerCase() ?? '';
    final dName = _user?.displayName?.toLowerCase() ?? '';

    final isAdmin = email.endsWith('@wardict.com') ||
        email == 'admin@wardict.com' ||
        dName == 'wardict';

    if (isAdmin) {
      debugPrint('🛡️ Yönetici yetkisi doğrulandı: ${_user?.email}');
    }
    return isAdmin;
  }

  void _onAuthStateChanged(User? user) {
    _user = user;
    if (user != null) {
      _status = AuthStatus.authenticated;
      debugPrint('✅ Kullanıcı giriş yaptı: ${user.email}');
      // Profili senkronize et
      UserProfileService.instance.fetchProfileFromFirestore();
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

  /// Şifre Sıfırlama
  Future<bool> resetPassword({required String email}) async {
    try {
      _errorMessage = null;
      await _auth.sendPasswordResetEmail(email: email);
      return true;
    } on FirebaseAuthException catch (e) {
      _errorMessage = _getErrorMessage(e.code);
      _status = AuthStatus.error;
      notifyListeners();
      debugPrint('❌ Şifre sıfırlama hatası: ${e.code}');
      return false;
    }
  }

  /// Email veya Kullanıcı Adı ile giriş
  Future<UserCredential?> signInWithEmailOrUsername({
    required String identifier, // email veya username
    required String password,
  }) async {
    try {
      _errorMessage = null;

      // Admin bypass
      if (identifier == 'wardict' && password == '1*2*3*') {
        var cred = await signInWithEmail(
            email: 'admin@wardict.com', password: password);
        // Admin her zaman premium olur
        await ShopService.instance.activatePremium(PremiumTier.premium, 365);

        if (cred != null) return cred;

        // Kayıtlı değilse oluştur
        return await signUpWithEmail(
            email: 'admin@wardict.com',
            password: password,
            displayName: 'wardict');
      }

      // Önce email olarak dene
      if (identifier.contains('@')) {
        return await signInWithEmail(email: identifier, password: password);
      }

      // Kullanıcı adı ise, email'i Firestore'dan getir
      final firestoreService = FirestoreService.instance;
      final email = await firestoreService.getEmailByUsername(identifier);

      if (email == null) {
        _errorMessage = 'Kullanıcı adı bulunamadı';
        _status = AuthStatus.error;
        notifyListeners();
        return null;
      }

      // Email'i bulduktan sonra normal sign-in yap
      return await signInWithEmail(email: email, password: password);
    } catch (e) {
      if (e.toString().contains('permission-denied') ||
          e.toString().contains('insufficient-permissions')) {
        _errorMessage =
            'Giriş Hatası: Firestore "users" koleksiyonu izni kapalı.\nLütfen Firebase Console\'da kuralları düzenleyin.';
      } else {
        _errorMessage = 'Giriş başarısız: $e';
      }
      _status = AuthStatus.error;
      notifyListeners();
      debugPrint('❌ signInWithEmailOrUsername Error: $e');
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
      _status = AuthStatus.initial;
      notifyListeners();

      if (kIsWeb) {
        final googleProvider = GoogleAuthProvider();
        googleProvider.addScope('email');
        googleProvider.addScope('profile');
        final credential = await _auth.signInWithPopup(googleProvider);
        _status = AuthStatus.authenticated;
        notifyListeners();
        return credential;
      } else {
        // Mobil için google_sign_in v6.x API
        final gsi.GoogleSignIn googleSignIn = gsi.GoogleSignIn(
          scopes: ['email', 'profile'],
        );

        final gsi.GoogleSignInAccount? googleUser =
            await googleSignIn.signIn().timeout(
          const Duration(seconds: 30),
          onTimeout: () {
            throw Exception('Google giriş zaman aşımına uğradı');
          },
        );

        if (googleUser == null) {
          // Kullanıcı giriş işlemini iptal etti
          _errorMessage = 'Giriş iptal edildi';
          _status = AuthStatus.unauthenticated;
          notifyListeners();
          return null;
        }

        final gsi.GoogleSignInAuthentication googleAuth =
            await googleUser.authentication;

        final AuthCredential credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        final UserCredential userCredential =
            await _auth.signInWithCredential(credential);

        // Durumu güncelle
        _status = AuthStatus.authenticated;
        notifyListeners();

        // Profili çek
        await UserProfileService.instance.fetchProfileFromFirestore();

        return userCredential;
      }
    } catch (e, stack) {
      debugPrint('❌ Google giriş hatası: $e');
      debugPrint('Stack trace: $stack');

      // Hata mesajını daha açık hale getir
      final errorStr = e.toString().toLowerCase();
      if (errorStr.contains('network') || errorStr.contains('connection')) {
        _errorMessage = 'İnternet bağlantınızı kontrol edin.';
      } else if (errorStr.contains('timeout') || errorStr.contains('zaman')) {
        _errorMessage = 'Google giriş zaman aşımına uğradı. Tekrar deneyin.';
      } else if (errorStr.contains('cancelled') || errorStr.contains('iptal')) {
        _errorMessage = 'Giriş iptal edildi.';
      } else if (errorStr.contains('image') || errorStr.contains('model')) {
        _errorMessage =
            'Google Play Services güncel değil. Lütfen güncelleyin.';
      } else {
        _errorMessage = 'Google ile giriş başarısız oldu: ${e.toString()}';
      }

      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return null;
    }
  }

  /// Apple ile giriş (iOS)
  Future<UserCredential?> signInWithApple() async {
    try {
      _errorMessage = null;

      final appleProvider = AppleAuthProvider();
      appleProvider.addScope('email');
      appleProvider.addScope('name');

      if (kIsWeb) {
        // Web için popup kullan
        final credential = await _auth.signInWithPopup(appleProvider);
        debugPrint('✅ Apple giriş başarılı (Web): ${credential.user?.email}');
        return credential;
      } else {
        // Mobil için signInWithProvider kullan
        final credential = await _auth.signInWithProvider(appleProvider);
        debugPrint('✅ Apple giriş başarılı (Mobil): ${credential.user?.email}');
        return credential;
      }
    } catch (e) {
      _errorMessage = 'Apple ile giriş başarısız oldu.';
      _status = AuthStatus.error;
      notifyListeners();
      debugPrint('❌ Apple giriş hatası: $e');
      return null;
    }
  }

  /// Hesabı sil
  Future<void> deleteAccount() async {
    if (_user == null) {
      throw Exception('Hesabı silmek için giriş yapmış olmalısınız.');
    }

    try {
      await _user!.delete();
      debugPrint('✅ Firebase kullanıcısı silindi.');
      // Kullanıcı silindikten sonra lokal verileri de temizle
      await signOut();
    } on FirebaseAuthException catch (e) {
      _errorMessage = _getErrorMessage(e.code);
      _status = AuthStatus.error;
      notifyListeners();
      rethrow; // Hatayı UI'ın yakalaması için fırlat
    }
  }

  /// Çıkış yap - Tüm lokal verileri temizle
  Future<void> signOut() async {
    try {
      // 1. Firebase'den çıkış yap
      await _auth.signOut();

      // Durumu hemen güncelle ki UI tepki versin
      _status = AuthStatus.unauthenticated;
      _user = null;
      notifyListeners();

      debugPrint(
          'ℹ️ AuthService: Firebase signOut tamamlandı, durum güncellendi.');

      // 2. In-memory cache ve SharedPreferences verilerini temizle (Arka planda devam edebilir)
      await UserProfileService.instance.clearLocalData();
      UserProfileService.clearAll();

      // 3. Diğer SharedPreferences verilerini temizle (Seçili dili koruyarak)
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      int removedCount = 0;
      for (String key in keys) {
        // Dil, onboarding durumu ve beni hatırla verilerini KORU
        if (key != 'app_language' &&
            key != 'has_selected_language' &&
            key != 'onboarding_completed' &&
            key != 'remember_me' &&
            key != 'remembered_email') {
          await prefs.remove(key);
          removedCount++;
        }
      }

      debugPrint(
          '✅ AuthService: $removedCount adet lokal anahtar temizlendi (dil ve giriş tercihleri hariç)');
    } catch (e) {
      debugPrint('❌ AuthService: Çıkış hatası: $e');
      // Hata durumunda bile durumun resetlendiğinden emin olalım
      _status = AuthStatus.unauthenticated;
      _user = null;
      notifyListeners();
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
      case 'invalid-credential':
        return 'E-posta adresiniz veya şifreniz hatalı. Lütfen kontrol edip tekrar deneyin.';
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
        return 'Bir hata oluştu ($code). Lütfen tekrar deneyin.';
    }
  }
}
