import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Firebase başlatma ve yönetim servisi
class FirebaseService {
  static FirebaseService? _instance;
  static FirebaseService get instance => _instance ??= FirebaseService._();

  FirebaseService._();

  bool _initialized = false;
  bool get isInitialized => _initialized;

  /// Firebase'i başlatır
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      // Zaten başlatılmış mı kontrol et
      if (Firebase.apps.isNotEmpty) {
        _initialized = true;
        debugPrint('✅ Firebase zaten başlatılmış');
        return;
      }
      
      await Firebase.initializeApp(
        options: _getFirebaseOptions(),
      );

      // App Check başlat: client'ın gerçek uygulama olduğunu sunucuya kanıtlar.
      // Callable fonksiyonlar bu token'ı zorunlu tutuyor.
      await _initAppCheck();

      _initialized = true;
      debugPrint('✅ Firebase başarıyla başlatıldı');
    } catch (e) {
      // Duplicate app hatası ise yoksay
      if (e.toString().contains('duplicate-app')) {
        _initialized = true;
        debugPrint('✅ Firebase zaten başlatılmış (duplicate-app)');
        return;
      }
      debugPrint('❌ Firebase başlatma hatası: $e');
      rethrow;
    }
  }

  /// Platform bazlı Firebase ayarları
  FirebaseOptions _getFirebaseOptions() {
    // Load credentials from environment variables
    final apiKey = dotenv.get('FIREBASE_API_KEY', fallback: '');
    final appId = dotenv.get('FIREBASE_APP_ID', fallback: '');
    final messagingSenderId = dotenv.get('FIREBASE_MESSAGING_SENDER_ID', fallback: '');
    final projectId = dotenv.get('FIREBASE_PROJECT_ID', fallback: '');
    final storageBucket = dotenv.get('FIREBASE_STORAGE_BUCKET', fallback: '');
    final authDomain = dotenv.get('FIREBASE_AUTH_DOMAIN', fallback: '');
    final measurementId = dotenv.get('FIREBASE_MEASUREMENT_ID', fallback: '');
    final databaseURL = dotenv.get('FIREBASE_DATABASE_URL', fallback: '');

    if (apiKey.isEmpty || projectId.isEmpty) {
      throw Exception(
        'Firebase configuration not found. Please create a .env file with required credentials. '
        'See .env.example for the required format.'
      );
    }

    if (kIsWeb) {
      return FirebaseOptions(
        apiKey: apiKey,
        authDomain: authDomain,
        projectId: projectId,
        storageBucket: storageBucket,
        messagingSenderId: messagingSenderId,
        appId: appId,
        measurementId: measurementId,
        databaseURL: databaseURL.isNotEmpty ? databaseURL : null,
      );
    }
    
    // Android/iOS
    return FirebaseOptions(
      apiKey: apiKey,
      appId: appId,
      messagingSenderId: messagingSenderId,
      projectId: projectId,
      storageBucket: storageBucket,
      databaseURL: databaseURL.isNotEmpty ? databaseURL : null,
    );
  }

  /// Firebase App Check'i uygun provider ile aktifleştir.
  ///
  /// - Debug build: `AndroidProvider.debug` / `AppleProvider.debug`
  /// - Release build: `AndroidProvider.playIntegrity` / `AppleProvider.appAttest`
  ///
  /// Play Integrity production'da imza doğrular; emülatör veya rootlu cihazda
  /// başarısız olur. Bu durumlarda Firebase Console → App Check → "Debug"
  /// sekmesinde cihaz tokenı ekleyerek test edilebilir.
  Future<void> _initAppCheck() async {
    try {
      await FirebaseAppCheck.instance.activate(
        providerAndroid: kDebugMode
            ? const AndroidDebugProvider()
            : const AndroidPlayIntegrityProvider(),
        providerApple: kDebugMode
            ? const AppleDebugProvider()
            : const AppleAppAttestProvider(),
        providerWeb: kIsWeb
            ? ReCaptchaV3Provider(dotenv.get('RECAPTCHA_V3_SITE_KEY', fallback: 'RECAPTCHA_V3_SITE_KEY_PLACEHOLDER'))
            : null,
      );
      debugPrint(
          '🛡️ App Check aktif (${kDebugMode ? "debug" : "play integrity"})');
    } catch (e) {
      debugPrint('⚠️ App Check aktivasyonu başarısız: $e');
    }
  }
}
