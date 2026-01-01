import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

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
    if (kIsWeb) {
      return const FirebaseOptions(
        apiKey: 'AIzaSyBXizglIJTCuJfR25OdbfKnVyr11cBaDj0',
        authDomain: 'wardict-app.firebaseapp.com',
        projectId: 'wardict-app',
        storageBucket: 'wardict-app.firebasestorage.app',
        messagingSenderId: '241339661354',
        appId: '1:241339661354:web:7aae4ed632b4d4cfc75753',
        measurementId: 'G-WWS6CZNLM0',
      );
    }
    
    // Android için (google-services.json'dan otomatik alınır ama fallback olarak)
    return const FirebaseOptions(
      apiKey: 'AIzaSyBXizglIJTCuJfR25OdbfKnVyr11cBaDj0',
      appId: '1:241339661354:web:7aae4ed632b4d4cfc75753',
      messagingSenderId: '241339661354',
      projectId: 'wardict-app',
      storageBucket: 'wardict-app.firebasestorage.app',
    );
  }
}
