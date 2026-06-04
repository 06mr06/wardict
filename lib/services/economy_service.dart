import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

import 'firebase/auth_service.dart';
import 'offline_queue_service.dart';

/// TÃ¼m altÄ±n / premium / gÃ¼nlÃ¼k bonus / promo kod iÅŸlemleri bu servis Ã¼zerinden
/// sunucuya gider. BaÅŸarÄ±sÄ±z olursa offline kuyruÄŸa dÃ¼ÅŸer, baÄŸlantÄ± gelince
/// yeniden denenir.
///
/// Client yalnÄ±zca optimistik UI gÃ¶sterir; nihai bakiye sunucudan dÃ¶ner.
class EconomyService {
  static final EconomyService instance = EconomyService._();
  EconomyService._();

  FirebaseFunctions get _fns =>
      FirebaseFunctions.instanceFor(region: 'us-central1');

  bool _handlersRegistered = false;

  /// main.dart'tan Ã§aÄŸrÄ±lÄ±r. Offline kuyruk handler'larÄ±nÄ± kaydeder.
  void registerOfflineHandlers() {
    if (_handlersRegistered) return;
    _handlersRegistered = true;

    OfflineQueueService.instance.registerHandler('addCoins', (payload) async {
      try {
        await _callAddCoins(
          amount: payload['amount'] as int,
          reason: payload['reason'] as String,
        );
        return true;
      } catch (e) {
        debugPrint('âš ï¸ Offline addCoins retry failed: $e');
        return false;
      }
    });

    OfflineQueueService.instance.registerHandler('spendCoins', (payload) async {
      try {
        await _callSpendCoins(
          amount: payload['amount'] as int,
          reason: payload['reason'] as String,
        );
        return true;
      } catch (e) {
        debugPrint('âš ï¸ Offline spendCoins retry failed: $e');
        return false;
      }
    });

    OfflineQueueService.instance.registerHandler('syncProfile', (payload) async {
      try {
        final userId = AuthService.instance.userId;
        if (userId == null) return false;
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .set(
              Map<String, dynamic>.from(payload),
              SetOptions(merge: true),
            );
        return true;
      } catch (e) {
        debugPrint('âš ï¸ Offline syncProfile retry failed: $e');
        return false;
      }
    });
  }

  /// AltÄ±n ekleme â€” sunucu aynÄ± zamanda ledger tutar.
  /// BaÅŸarÄ±lÄ± ise yeni bakiyeyi dÃ¶ndÃ¼rÃ¼r; baÅŸarÄ±sÄ±zsa -1.
  Future<int> addCoins({required int amount, required String reason}) async {
    if (amount <= 0) return -1;
    try {
      final res = await _callAddCoins(amount: amount, reason: reason);
      return res;
    } on FirebaseFunctionsException catch (e) {
      debugPrint('âš ï¸ addCoins error (${e.code}): ${e.message}');
      if (_isRetryableError(e)) {
        await OfflineQueueService.instance.enqueue('addCoins', {
          'amount': amount,
          'reason': reason,
        });
      }
      return -1;
    } catch (e) {
      debugPrint('âš ï¸ addCoins error: $e');
      await OfflineQueueService.instance.enqueue('addCoins', {
        'amount': amount,
        'reason': reason,
      });
      return -1;
    }
  }

  Future<int> _callAddCoins({
    required int amount,
    required String reason,
  }) async {
    final callable = _fns.httpsCallable(
      'secureAddCoins',
      options: HttpsCallableOptions(timeout: const Duration(seconds: 15)),
    );
    final res = await callable.call<Map<String, dynamic>>({
      'amount': amount,
      'reason': reason,
    });
    return (res.data['balance'] as num?)?.toInt() ?? -1;
  }

  /// Altın harcama. Başarılıysa yeni bakiye (≥0).
  /// `-2` = sunucu yetersiz bakiye (`failed-precondition`); yerel düşüm yapılmamalı.
  /// `-1` = ağ / App Check / iç hata; çağıran isterse yerel düşüm deneyebilir.
  ///
  /// [enqueueIfRetryableFailure]: false ise (ör. mağaza), tekrarlanabilir hatalarda
  /// kuyruğa yazılmaz — çağıran yerel düşüm yapabilir; böylece çift düşüm olmaz.
  Future<int> spendCoins({
    required int amount,
    required String reason,
    bool enqueueIfRetryableFailure = true,
  }) async {
    if (amount <= 0) return -1;
    try {
      return await _callSpendCoins(amount: amount, reason: reason);
    } on FirebaseFunctionsException catch (e) {
      debugPrint('âš ï¸ spendCoins error (${e.code}): ${e.message}');
      // Yetersiz bakiye — kuyruğa atma, yerel fallback yok
      if (e.code == 'failed-precondition') return -2;
      if (enqueueIfRetryableFailure && _isRetryableError(e)) {
        await OfflineQueueService.instance.enqueue('spendCoins', {
          'amount': amount,
          'reason': reason,
        });
      }
      return -1;
    } catch (e) {
      debugPrint('âš ï¸ spendCoins error: $e');
      if (enqueueIfRetryableFailure) {
        await OfflineQueueService.instance.enqueue('spendCoins', {
          'amount': amount,
          'reason': reason,
        });
      }
      return -1;
    }
  }

  Future<int> _callSpendCoins({
    required int amount,
    required String reason,
  }) async {
    final callable = _fns.httpsCallable(
      'secureSpendCoins',
      options: HttpsCallableOptions(timeout: const Duration(seconds: 15)),
    );
    final res = await callable.call<Map<String, dynamic>>({
      'amount': amount,
      'reason': reason,
    });
    return (res.data['balance'] as num?)?.toInt() ?? -1;
  }

  /// Görev ödülü talep et.
  Future<bool> claimQuestReward(String questId) async {
    try {
      final callable = _fns.httpsCallable('claimQuestReward');
      final res = await callable.call<Map<String, dynamic>>({
        'questId': questId,
      });
      return res.data['success'] == true;
    } catch (e) {
      debugPrint('âš ï¸ claimQuestReward error: $e');
      return false;
    }
  }

  /// Promo kod uygula.
  Future<PromoResult> redeemPromoCode(String code) async {
    try {
      final callable = _fns.httpsCallable('redeemPromoCode');
      final res = await callable.call<Map<String, dynamic>>({'code': code});
      final data = res.data;
      return PromoResult(
        success: data['success'] == true,
        rewardCoins: (data['rewardCoins'] as num?)?.toInt() ?? 0,
        premiumDays: (data['premiumDays'] as num?)?.toInt() ?? 0,
      );
    } on FirebaseFunctionsException catch (e) {
      return PromoResult(
        success: false,
        rewardCoins: 0,
        premiumDays: 0,
        errorMessage: e.message,
      );
    } catch (e) {
      return PromoResult(
        success: false,
        rewardCoins: 0,
        premiumDays: 0,
        errorMessage: e.toString(),
      );
    }
  }

  /// Referral kodu kullan.
  Future<PromoResult> redeemReferral(String code) async {
    try {
      final callable = _fns.httpsCallable('redeemReferral');
      final res = await callable.call<Map<String, dynamic>>({'code': code});
      return PromoResult(
        success: res.data['success'] == true,
        rewardCoins: (res.data['rewardCoins'] as num?)?.toInt() ?? 0,
        premiumDays: 0,
      );
    } on FirebaseFunctionsException catch (e) {
      return PromoResult(
        success: false,
        rewardCoins: 0,
        premiumDays: 0,
        errorMessage: e.message,
      );
    } catch (e) {
      return PromoResult(
        success: false,
        rewardCoins: 0,
        premiumDays: 0,
        errorMessage: e.toString(),
      );
    }
  }

  /// IAP receipt doÄŸrula.
  Future<VerifyPurchaseResult> verifyPurchase({
    required String platform,
    required String productId,
    String? purchaseToken,
    String? receipt,
  }) async {
    try {
      final callable = _fns.httpsCallable(
        'verifyPurchase',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 30)),
      );
      final res = await callable.call<Map<String, dynamic>>({
        'platform': platform,
        'productId': productId,
        if (purchaseToken != null) 'purchaseToken': purchaseToken,
        if (receipt != null) 'receipt': receipt,
      });
      final data = res.data;
      final ent = Map<String, dynamic>.from(data['entitlements'] ?? {});
      return VerifyPurchaseResult(
        success: data['success'] == true,
        simulation: data['simulation'] == true,
        coins: (ent['coins'] as num?)?.toInt() ?? 0,
        isPremium: ent['isPremium'] == true,
        hasRemovedAds: ent['hasRemovedAds'] == true,
        premiumExpiresAtMs:
            (ent['premiumExpiresAt'] as num?)?.toInt(),
      );
    } on FirebaseFunctionsException catch (e) {
      return VerifyPurchaseResult(
        success: false,
        simulation: false,
        coins: 0,
        isPremium: false,
        hasRemovedAds: false,
        errorMessage: '${e.code}: ${e.message}',
      );
    } catch (e) {
      return VerifyPurchaseResult(
        success: false,
        simulation: false,
        coins: 0,
        isPremium: false,
        hasRemovedAds: false,
        errorMessage: e.toString(),
      );
    }
  }

  /// Günlük bonus talep et.
  Future<DailyBonusResult> claimDailyBonus({bool hasShield = false}) async {
    try {
      final callable = _fns.httpsCallable('claimDailyBonus');
      final res = await callable.call<Map<String, dynamic>>({
        'hasShield': hasShield,
      });
      final data = res.data;
      return DailyBonusResult(
        success: data['success'] == true,
        bonusCoins: (data['bonusCoins'] as num?)?.toInt() ?? 0,
        streak: (data['streak'] as num?)?.toInt() ?? 0,
        balance: (data['balance'] as num?)?.toInt() ?? 0,
        streakBroken: data['streakBroken'] == true,
        previousStreak: (data['previousStreak'] as num?)?.toInt() ?? 0,
        shieldUsed: data['shieldUsed'] == true,
      );
    } on FirebaseFunctionsException catch (e) {
      return DailyBonusResult(
        success: false,
        bonusCoins: 0,
        streak: 0,
        balance: 0,
        errorMessage: e.message,
      );
    } catch (e) {
      return DailyBonusResult(
        success: false,
        bonusCoins: 0,
        streak: 0,
        balance: 0,
        errorMessage: e.toString(),
      );
    }
  }

  /// Kırılan seriyi kurtar (500 coin).
  Future<bool> restoreStreak(int previousStreak) async {
    try {
      final callable = _fns.httpsCallable('restoreStreak');
      final res = await callable.call<Map<String, dynamic>>({
        'previousStreak': previousStreak,
      });
      return res.data['success'] == true;
    } catch (e) {
      debugPrint('⚠️ restoreStreak error: $e');
      return false;
    }
  }

  bool _isRetryableError(FirebaseFunctionsException e) {
    // Ä°stemcide oluÅŸmuÅŸ bir hata (invalid-argument vb.) retry edilmez.
    switch (e.code) {
      case 'unavailable':
      case 'deadline-exceeded':
      case 'internal':
      case 'aborted':
      case 'resource-exhausted':
        return true;
      default:
        return false;
    }
  }
}

class DailyBonusResult {
  final bool success;
  final int bonusCoins;
  final int streak;
  final int balance;
  final bool streakBroken;
  final int previousStreak;
  final bool shieldUsed;
  final String? errorMessage;

  const DailyBonusResult({
    required this.success,
    required this.bonusCoins,
    required this.streak,
    required this.balance,
    this.streakBroken = false,
    this.previousStreak = 0,
    this.shieldUsed = false,
    this.errorMessage,
  });
}

class PromoResult {
  final bool success;
  final int rewardCoins;
  final int premiumDays;
  final String? errorMessage;

  const PromoResult({
    required this.success,
    required this.rewardCoins,
    required this.premiumDays,
    this.errorMessage,
  });
}

class VerifyPurchaseResult {
  final bool success;
  final bool simulation;
  final int coins;
  final bool isPremium;
  final bool hasRemovedAds;
  final int? premiumExpiresAtMs;
  final String? errorMessage;

  const VerifyPurchaseResult({
    required this.success,
    required this.simulation,
    required this.coins,
    required this.isPremium,
    required this.hasRemovedAds,
    this.premiumExpiresAtMs,
    this.errorMessage,
  });
}
