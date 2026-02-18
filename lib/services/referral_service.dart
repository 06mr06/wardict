import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import 'shop_service.dart';
import 'achievement_service.dart';
import '../models/achievement.dart';

class ReferralService {
  static final ReferralService instance = ReferralService._();
  ReferralService._();

  static const String _userReferralCodeKey = 'user_referral_code';
  static const String _hasUsedReferralKey = 'has_used_referral_code';

  /// Kullanıcının kendi davet kodunu getirir, yoksa oluşturur.
  Future<String> getMyReferralCode() async {
    final prefs = await SharedPreferences.getInstance();
    String? code = prefs.getString(_userReferralCodeKey);
    
    if (code == null) {
      code = _generateRandomCode();
      await prefs.setString(_userReferralCodeKey, code);
    }
    
    return code;
  }

  /// Bir davet kodunu kullanır.
  /// Returns: {'success': bool, 'message': String}
  Future<Map<String, dynamic>> useReferralCode(String code) async {
    final prefs = await SharedPreferences.getInstance();
    
    // Zaten kod kullanılmış mı?
    final hasUsed = prefs.getBool(_hasUsedReferralKey) ?? false;
    if (hasUsed) {
      return {'success': false, 'message': 'Zaten bir davet kodu kullandınız.'};
    }

    final myCode = await getMyReferralCode();
    final inputCode = code.trim().toUpperCase();

    // Kendi kodunu mu girdi?
    if (inputCode == myCode) {
      return {'success': false, 'message': 'Kendi davet kodunuzu kullanamazsınız.'};
    }

    // Basit doğrulama (Projede backend olmadığı için şimdilik format kontrolü yapıyoruz)
    // Gerçekte burada bir API çağrısı olup kodun geçerliliği sorgulanmalı.
    if (inputCode.length != 6) {
      return {'success': false, 'message': 'Geçersiz davet kodu formatı.'};
    }

    // Ödülleri ver
    // Kodu giren kişiye 250 altın
    await ShopService.instance.addCoins(250);
    
    // Davet eden kişiye (backend simülasyonu olarak mesajda belirtiyoruz)
    // Gerçek sistemde burada inviteeId -> inviterId eşleşmesi backend'den yapılır.
    
    await prefs.setBool(_hasUsedReferralKey, true);
    
    // Başarım ilerlemesi (Sosyal Kategori)
    await AchievementService.instance.updateProgress(AchievementCategory.social, 1);

    return {
      'success': true, 
      'message': 'Davet kodu başarıyla uygulandı! 250 Altın kazandınız.'
    };
  }

  /// Kullanıcının daha önce kod kullanıp kullanmadığını kontrol eder.
  Future<bool> hasUsedReferral() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_hasUsedReferralKey) ?? false;
  }

  String _generateRandomCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();
    return List.generate(6, (index) => chars[random.nextInt(chars.length)]).join();
  }
}
