import 'dart:async';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

import 'crashlytics_supported.dart';

/// Uygulama genelinde analytics + crashlytics facade'i.
///
/// Kullanım:
/// ```dart
/// AnalyticsService.instance.logEvent('duel_start', {'league': 'B1'});
/// ```
class AnalyticsService {
  static final AnalyticsService instance = AnalyticsService._();
  AnalyticsService._();

  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;
  late final FirebaseAnalyticsObserver navigatorObserver =
      FirebaseAnalyticsObserver(analytics: _analytics);

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    try {
      await _analytics.setAnalyticsCollectionEnabled(!kDebugMode);
    } catch (e) {
      debugPrint('⚠️ Analytics collection toggle failed: $e');
    }

    // Crashlytics: yalnızca Android/iOS (masaüstü/web'de assert hatası önlenir)
    if (isCrashlyticsNativeSdkSupported) {
      try {
        await FirebaseCrashlytics.instance
            .setCrashlyticsCollectionEnabled(!kDebugMode);

        FlutterError.onError = (details) {
          FirebaseCrashlytics.instance.recordFlutterFatalError(details);
        };

        PlatformDispatcher.instance.onError = (error, stack) {
          FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
          return true;
        };
      } catch (e) {
        debugPrint('⚠️ Crashlytics init failed: $e');
      }
    } else {
      FlutterError.onError = FlutterError.presentError;
      PlatformDispatcher.instance.onError = (error, stack) {
        debugPrint('⚠️ Uncaught async error: $error\n$stack');
        return true;
      };
    }
  }

  /// Kullanıcı kimliğini ata (auth sonrası).
  Future<void> setUser({required String? uid, String? username}) async {
    try {
      await _analytics.setUserId(id: uid);
      if (username != null) {
        await _analytics.setUserProperty(name: 'username', value: username);
      }
      if (uid != null && isCrashlyticsNativeSdkSupported) {
        await FirebaseCrashlytics.instance.setUserIdentifier(uid);
      }
    } catch (e) {
      debugPrint('⚠️ setUser failed: $e');
    }
  }

  /// Seviye / premium gibi user property'leri set et.
  Future<void> setUserProperty(String name, String? value) async {
    try {
      await _analytics.setUserProperty(name: name, value: value);
    } catch (e) {
      debugPrint('⚠️ setUserProperty($name) failed: $e');
    }
  }

  /// Genel event log.
  Future<void> logEvent(
    String name, [
    Map<String, Object>? params,
  ]) async {
    try {
      await _analytics.logEvent(name: name, parameters: params);
    } catch (e) {
      debugPrint('⚠️ logEvent($name) failed: $e');
    }
  }

  Future<void> logScreenView(String screenName) async {
    try {
      await _analytics.logScreenView(screenName: screenName);
    } catch (e) {
      debugPrint('⚠️ logScreenView failed: $e');
    }
  }

  // -------- Uygulama-özel kısayollar --------

  Future<void> logAppOpen() => _analytics.logAppOpen();

  Future<void> logLogin(String method) =>
      _analytics.logLogin(loginMethod: method);

  Future<void> logSignUp(String method) =>
      _analytics.logSignUp(signUpMethod: method);

  Future<void> logPracticeStart({required String level}) =>
      logEvent('practice_start', {'level': level});

  Future<void> logPracticeFinish({
    required String level,
    required int correct,
    required int wrong,
    required int score,
  }) =>
      logEvent('practice_finish', {
        'level': level,
        'correct': correct,
        'wrong': wrong,
        'score': score,
      });

  Future<void> logDuelStart({
    required String mode, // online / bot / friend
    required String league,
  }) =>
      logEvent('duel_start', {'mode': mode, 'league': league});

  Future<void> logDuelEnd({
    required String mode,
    required String league,
    required bool win,
    required int lpChange,
    required int durationSec,
    required bool isRematch,
  }) =>
      logEvent('duel_end', {
        'mode': mode,
        'league': league,
        'win': win ? 1 : 0,
        'lp_change': lpChange,
        'duration_sec': durationSec,
        'is_rematch': isRematch ? 1 : 0,
      });

  Future<void> logDaily123({
    required int tier,
    required bool won,
  }) =>
      logEvent('daily_123', {'tier': tier, 'won': won ? 1 : 0});

  Future<void> logPurchaseStart({required String productId}) =>
      logEvent('purchase_start', {'product_id': productId});

  Future<void> logPurchaseSuccess({
    required String productId,
    required double value,
    required String currency,
  }) =>
      _analytics.logPurchase(
        currency: currency,
        value: value,
        transactionId: null,
        items: [
          AnalyticsEventItem(
            itemId: productId,
            itemName: productId,
            price: value,
            quantity: 1,
          )
        ],
      );

  Future<void> logPurchaseFail({
    required String productId,
    required String reason,
  }) =>
      logEvent('purchase_fail', {
        'product_id': productId,
        'reason': reason,
      });

  Future<void> logAdImpression({
    required String adUnit, // banner / interstitial / rewarded
    String? placement,
  }) =>
      logEvent('ad_impression', {
        'ad_unit': adUnit,
        if (placement != null) 'placement': placement,
      });

  Future<void> logStreakUpdate({required int streak}) =>
      logEvent('streak_update', {'streak': streak});

  Future<void> logTutorialBegin() => _analytics.logTutorialBegin();
  Future<void> logTutorialComplete() => _analytics.logTutorialComplete();

  Future<void> recordError(
    Object error,
    StackTrace? stack, {
    String? reason,
    bool fatal = false,
  }) async {
    if (!isCrashlyticsNativeSdkSupported) {
      debugPrint('⚠️ recordError (no Crashlytics): $error');
      return;
    }
    try {
      await FirebaseCrashlytics.instance.recordError(
        error,
        stack,
        reason: reason,
        fatal: fatal,
      );
    } catch (e) {
      debugPrint('⚠️ recordError failed: $e');
    }
  }
}
