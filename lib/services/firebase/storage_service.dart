import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'auth_service.dart';

class StorageService {
  static final StorageService instance = StorageService._internal();
  StorageService._internal();

  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Profil fotoğrafını Firebase Storage'a yükler (Web + Mobil uyumlu)
  Future<String?> uploadProfileImageBytes(Uint8List imageBytes, {String extension = 'jpg'}) async {
    final userId = AuthService.instance.userId;
    if (userId == null) {
      debugPrint('❌ Storage: userId null, yükleme iptal edildi');
      return null;
    }

    try {
      final ref = _storage.ref().child('profile_photos').child('$userId.$extension');
      
      debugPrint('📤 Storage: "${ref.fullPath}" yoluna yükleme başlıyor... (${imageBytes.length} bytes)');
      
      // SettableMetadata ile dosya türünü net belirtmek Web'de önemlidir
      final metadata = SettableMetadata(
        contentType: 'image/jpeg',
        customMetadata: {'userId': userId},
      );

      // Yükleme işlemini başlattık
      final UploadTask uploadTask = ref.putData(imageBytes, metadata);

      // Yükleme ilerlemesini dinleyelim (opsiyonel ama debug için iyi)
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        double progress = 100 * (snapshot.bytesTransferred / snapshot.totalBytes);
        debugPrint('📊 Yükleme ilerlemesi: %${progress.toStringAsFixed(2)}');
      });

      // 60 saniyelik daha uzun bir süre tanıyalım
      final TaskSnapshot snapshot = await uploadTask.timeout(const Duration(seconds: 60));
      
      final String downloadUrl = await snapshot.ref.getDownloadURL();
      
      debugPrint('✅ Storage: Fotoğraf başarıyla yüklendi! URL: $downloadUrl');
      return downloadUrl;
    } catch (e) {
      debugPrint('❌ Storage yükleme hatası detaylı: $e');
      if (e.toString().contains('canceled')) {
        debugPrint('⚠️ İşlem kullanıcı veya sistem tarafından iptal edildi.');
      } else if (e.toString().contains('not-authorized')) {
        debugPrint('⚠️ Firebase Storage kurallarınız (Rules) bu dosyanın yazılmasına izin vermiyor olabilir.');
      }
      return null;
    }
  }

  /// Geriye uyumluluk API
  Future<String?> uploadProfileImage(dynamic file) async {
    try {
      final Uint8List bytes = await (file as dynamic).readAsBytes();
      return uploadProfileImageBytes(bytes);
    } catch (e) {
      debugPrint('❌ Storage: uploadProfileImage hatası: $e');
      return null;
    }
  }
}
