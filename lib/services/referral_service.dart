import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'achievement_service.dart';
import 'economy_service.dart';
import 'firebase/auth_service.dart';
import 'user_profile_service.dart';
import '../models/achievement.dart';

/// Davet kodu servisi — artık tamamen sunucu taraflı.
/// - `getMyReferralCode` kullanıcının kodunu üretir ve Firestore'daki
///   `users/{uid}.referralCode` alanına yazar (ilk sefer). Böylece
///   başka biri bu kodu girdiğinde Cloud Function davet edeni bulabilir.
/// - `useReferralCode` çağrısı `redeemReferral` callable'ını tetikler
///   ve her iki tarafa da güvenilir şekilde ödül verir.
class ReferralService {
  static final ReferralService instance = ReferralService._();
  ReferralService._();

  /// Sunucu [redeemReferral] ile uyumlu — metinlerde kullan.
  static const int inviteeCoins = 250;
  static const int inviterCoins = 1000;

  static const String _localCodeKey = 'user_referral_code';
  static const String _localUsedKey = 'has_used_referral_code';

  /// Kendi davet kodunu al; yoksa üret ve Firestore'daki profile yaz.
  Future<String> getMyReferralCode() async {
    final prefs = await SharedPreferences.getInstance();
    final profile = await UserProfileService.instance.loadProfile();
    final uid = AuthService.instance.userId;

    // Önce yereldeki kod
    String? code = prefs.getString(_localCodeKey);

    // Firestore'dan çek
    if (uid != null) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .get();
        final remote = doc.data()?['referralCode'] as String?;
        if (remote != null && remote.isNotEmpty) {
          code = remote;
          await prefs.setString(_localCodeKey, code);
        }
      } catch (e) {
        debugPrint('⚠️ Referral remote fetch failed: $e');
      }
    }

    if (code == null || code.isEmpty) {
      code = _generateRandomCode();
      await prefs.setString(_localCodeKey, code);

      // Firestore'a yaz (arama için)
      if (uid != null) {
        try {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .set({'referralCode': code}, SetOptions(merge: true));
        } catch (e) {
          debugPrint('⚠️ Referral code persist failed: $e');
        }
      }
    }

    // Profil tarafında güncelle
    if (profile.email != null) {
      // no-op, profil modeli şu an referralCode tutmuyor
    }

    return code;
  }

  /// Davet kodunu kullan — Cloud Function `redeemReferral` çağrılır.
  Future<Map<String, dynamic>> useReferralCode(String code) async {
    final prefs = await SharedPreferences.getInstance();

    if (prefs.getBool(_localUsedKey) == true) {
      return {'success': false, 'message': 'Zaten bir davet kodu kullandın.'};
    }

    final normalized = code.trim().toUpperCase();
    if (normalized.length != 6) {
      return {
        'success': false,
        'message': 'Geçersiz davet kodu formatı (6 karakter olmalı).',
      };
    }

    final myCode = await getMyReferralCode();
    if (normalized == myCode) {
      return {
        'success': false,
        'message': 'Kendi davet kodunu kullanamazsın.',
      };
    }

    final result = await EconomyService.instance.redeemReferral(normalized);
    if (!result.success) {
      return {
        'success': false,
        'message': result.errorMessage ?? 'Davet kodu kullanılamadı.',
      };
    }

    await prefs.setBool(_localUsedKey, true);

    // Bulutta entitlement güncellendi; yerel profili tazele
    await UserProfileService.instance.fetchProfileFromFirestore();

    // Başarım ilerlemesi (Sosyal)
    await AchievementService.instance
        .updateProgress(AchievementCategory.social, 1);

    return {
      'success': true,
      'message':
          'Davet kodu uygulandı! ${result.rewardCoins} altın hesabına eklendi. '
          'Davet eden arkadaşın da ${ReferralService.inviterCoins} altın kazandı.',
    };
  }

  Future<bool> hasUsedReferral() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_localUsedKey) ?? false;
  }

  static String buildShareText({
    required String code,
    required bool turkish,
  }) {
    if (turkish) {
      return 'LUGORENA\'da İngilizce kelime düellosu!\n\n'
          'Davet kodum: $code\n\n'
          'İlk kayıtta bu kodu uygula: sen $inviteeCoins altın kazan, '
          'ben davet olarak $inviterCoins altın kazanırım.';
    }
    return 'LUGORENA vocabulary duels!\n\n'
        'My invite code: $code\n\n'
        'Redeem it on your first signup: you get $inviteeCoins coins '
        'and I get $inviterCoins as your inviter!';
  }

  String _generateRandomCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();
    return List.generate(6, (index) => chars[random.nextInt(chars.length)])
        .join();
  }
}
