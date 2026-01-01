import 'package:flutter/foundation.dart';

/// Reklam türleri
enum AdType {
  banner,
  interstitial,
  rewarded,
}

/// Reklam servisi - Google Mobile Ads (AdMob) entegrasyonu
/// 
/// Kullanım:
/// 1. pubspec.yaml'a ekle: google_mobile_ads: ^5.2.0
/// 2. Android: android/app/src/main/AndroidManifest.xml'e AdMob App ID ekle
/// 3. iOS: ios/Runner/Info.plist'e AdMob App ID ekle
/// 4. AdService.instance.initialize() çağır
class AdService {
  static final AdService instance = AdService._internal();
  AdService._internal();

  bool _isInitialized = false;
  bool _isAdLoading = false;
  
  // Test Ad IDs (Production'da gerçek ID'ler kullanılmalı)
  // Android Test IDs
  static const String _androidBannerTestId = 'ca-app-pub-3940256099942544/6300978111';
  static const String _androidInterstitialTestId = 'ca-app-pub-3940256099942544/1033173712';
  static const String _androidRewardedTestId = 'ca-app-pub-3940256099942544/5224354917';
  
  // iOS Test IDs
  static const String _iosBannerTestId = 'ca-app-pub-3940256099942544/2934735716';
  static const String _iosInterstitialTestId = 'ca-app-pub-3940256099942544/4411468910';
  static const String _iosRewardedTestId = 'ca-app-pub-3940256099942544/1712485313';

  // Production Ad IDs (Firebase Remote Config veya .env'den alınabilir)
  String? _bannerAdUnitId;
  String? _interstitialAdUnitId;
  String? _rewardedAdUnitId;

  /// Reklam servisini başlat
  Future<void> initialize({
    String? bannerAdUnitId,
    String? interstitialAdUnitId,
    String? rewardedAdUnitId,
  }) async {
    if (_isInitialized) return;

    try {
      // google_mobile_ads paketi eklendiğinde:
      // await MobileAds.instance.initialize();
      
      _bannerAdUnitId = bannerAdUnitId;
      _interstitialAdUnitId = interstitialAdUnitId;
      _rewardedAdUnitId = rewardedAdUnitId;
      
      _isInitialized = true;
      debugPrint('AdService initialized');
    } catch (e) {
      debugPrint('AdService initialization error: $e');
    }
  }

  /// Test modunda mı?
  bool get isTestMode => kDebugMode;

  /// Banner reklam ID'si
  String get bannerAdUnitId {
    if (isTestMode) {
      return defaultTargetPlatform == TargetPlatform.iOS
          ? _iosBannerTestId
          : _androidBannerTestId;
    }
    return _bannerAdUnitId ?? _androidBannerTestId;
  }

  /// Interstitial reklam ID'si
  String get interstitialAdUnitId {
    if (isTestMode) {
      return defaultTargetPlatform == TargetPlatform.iOS
          ? _iosInterstitialTestId
          : _androidInterstitialTestId;
    }
    return _interstitialAdUnitId ?? _androidInterstitialTestId;
  }

  /// Rewarded reklam ID'si
  String get rewardedAdUnitId {
    if (isTestMode) {
      return defaultTargetPlatform == TargetPlatform.iOS
          ? _iosRewardedTestId
          : _androidRewardedTestId;
    }
    return _rewardedAdUnitId ?? _androidRewardedTestId;
  }

  /// Interstitial reklam yükle ve göster
  Future<bool> showInterstitialAd() async {
    if (_isAdLoading) return false;
    
    try {
      _isAdLoading = true;
      
      // google_mobile_ads paketi eklendiğinde:
      /*
      final completer = Completer<bool>();
      
      InterstitialAd.load(
        adUnitId: interstitialAdUnitId,
        request: const AdRequest(),
        adLoadCallback: InterstitialAdLoadCallback(
          onAdLoaded: (ad) {
            ad.fullScreenContentCallback = FullScreenContentCallback(
              onAdDismissedFullScreenContent: (ad) {
                ad.dispose();
                completer.complete(true);
              },
              onAdFailedToShowFullScreenContent: (ad, error) {
                ad.dispose();
                completer.complete(false);
              },
            );
            ad.show();
          },
          onAdFailedToLoad: (error) {
            debugPrint('Interstitial ad failed to load: $error');
            completer.complete(false);
          },
        ),
      );
      
      return await completer.future;
      */
      
      // Simülasyon modu
      await Future.delayed(const Duration(seconds: 1));
      debugPrint('Interstitial ad shown (simulated)');
      return true;
    } catch (e) {
      debugPrint('Error showing interstitial ad: $e');
      return false;
    } finally {
      _isAdLoading = false;
    }
  }

  /// Ödüllü reklam yükle ve göster
  /// Başarılı olursa ödül miktarını döndürür
  Future<int> showRewardedAd({int defaultReward = 25}) async {
    if (_isAdLoading) return 0;
    
    try {
      _isAdLoading = true;
      
      // google_mobile_ads paketi eklendiğinde:
      /*
      final completer = Completer<int>();
      
      RewardedAd.load(
        adUnitId: rewardedAdUnitId,
        request: const AdRequest(),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (ad) {
            ad.fullScreenContentCallback = FullScreenContentCallback(
              onAdDismissedFullScreenContent: (ad) {
                ad.dispose();
              },
              onAdFailedToShowFullScreenContent: (ad, error) {
                ad.dispose();
                completer.complete(0);
              },
            );
            ad.show(
              onUserEarnedReward: (ad, reward) {
                completer.complete(reward.amount.toInt());
              },
            );
          },
          onAdFailedToLoad: (error) {
            debugPrint('Rewarded ad failed to load: $error');
            completer.complete(0);
          },
        ),
      );
      
      return await completer.future;
      */
      
      // Simülasyon modu
      await Future.delayed(const Duration(seconds: 2));
      debugPrint('Rewarded ad shown (simulated), reward: $defaultReward');
      return defaultReward;
    } catch (e) {
      debugPrint('Error showing rewarded ad: $e');
      return 0;
    } finally {
      _isAdLoading = false;
    }
  }

  /// Reklam yüklenebilir mi kontrol et
  bool get canShowAds => _isInitialized && !_isAdLoading;

  /// Kullanıcı premium mu? Premium kullanıcılar reklam görmez
  bool _isPremium = false;
  
  bool get isPremium => _isPremium;
  
  void setPremiumStatus(bool isPremium) {
    _isPremium = isPremium;
  }

  /// Oyun arası reklam gösterilmeli mi?
  /// Belirli aralıklarla gösterilir (her 3-5 oyunda bir)
  int _gamesSinceLastAd = 0;
  
  Future<void> onGameCompleted() async {
    if (_isPremium) return;
    
    _gamesSinceLastAd++;
    
    // Her 4 oyunda bir reklam göster
    if (_gamesSinceLastAd >= 4) {
      await showInterstitialAd();
      _gamesSinceLastAd = 0;
    }
  }
}

/// Banner reklam widget'ı için placeholder
/// google_mobile_ads paketi eklendiğinde gerçek BannerAd widget'ı kullanılacak
class BannerAdWidget {
  // Placeholder
}
