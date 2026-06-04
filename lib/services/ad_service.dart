import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'shop_service.dart';
import '../models/premium.dart';

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
  Future<void>? _initFuture;
  
  // Test Ad IDs (Debug modunda kullanılır - AdMob politikası gereği)
  static const String _androidBannerTestId = 'ca-app-pub-3940256099942544/6300978111';
  static const String _androidInterstitialTestId = 'ca-app-pub-3940256099942544/1033173712';
  static const String _androidRewardedTestId = 'ca-app-pub-3940256099942544/5224354917';
  
  // Production Ad IDs - LUGORENA App  
  static const String _androidBannerProdId = 'ca-app-pub-7518151017798456/6300978111';
  static const String _androidInterstitialProdId = 'ca-app-pub-7518151017798456/6525598980';
  // AdMob panelinde "Ödüllü (Rewarded)" türündeki birimi kullanın.
  // Not: "Ödüllü geçiş reklamı (Rewarded interstitial)" birimi RewardedAd ile çalışmaz.
  static const String _androidRewardedProdId = 'ca-app-pub-7518151017798456/2167551577';
  
  // iOS Test IDs
  static const String _iosBannerTestId = 'ca-app-pub-3940256099942544/2934735716';
  static const String _iosInterstitialTestId = 'ca-app-pub-3940256099942544/4411468910';
  static const String _iosRewardedTestId = 'ca-app-pub-3940256099942544/1712485313';

  // Production Ad IDs (Environment variables üzerinden yönetilebilir)
  String get _bannerIdEnv => dotenv.get('ADMOB_BANNER_ID', fallback: '');
  String get _interstitialIdEnv => dotenv.get('ADMOB_INTERSTITIAL_ID', fallback: '');
  String get _rewardedIdEnv => dotenv.get('ADMOB_REWARDED_ID', fallback: '');
  String get _coinRewardedIdEnv => dotenv.get('ADMOB_COIN_REWARDED_ID', fallback: '');

  String? _bannerAdUnitId;
  String? _interstitialAdUnitId;
  String? _rewardedAdUnitId;

  /// Arka planda yüklenmiş ödüllü reklam (Daily 123 / mağaza için daha az yükleme hatası).
  RewardedAd? _preloadedRewardedAd;

  /// Reklam servisini başlat
  ///
  /// ÖNEMLİ (politika):
  /// - `tagForChildDirectedTreatment = yes` AdMob tarafında COPPA kısıtlaması
  ///   getirir ve eCPM'yi ciddi düşürür. Oyun yetişkin oyunculara yönelik
  ///   olduğu için bunu DEFAULT OLARAK KAPALI tutuyoruz. Uygulama GDPR/CCPA
  ///   için `nonPersonalizedAds` toggle'ıyla yönetilmelidir (kullanıcıdan
  ///   consent alındıktan sonra `setConsent(granted: true)` çağır).
  /// - Yaşa göre gösterim için `.env` içine `ADMOB_CHILD_DIRECTED=true`
  ///   koyarak etkinleştirilebilir.
  Future<void> initialize({
    String? bannerAdUnitId,
    String? interstitialAdUnitId,
    String? rewardedAdUnitId,
  }) async {
    if (_isInitialized) return;

    try {
      final childDirected =
          dotenv.get('ADMOB_CHILD_DIRECTED', fallback: 'false') == 'true';

      final RequestConfiguration requestConfiguration = RequestConfiguration(
        // Yayında kalan içeriği G-rated tutuyoruz ama COPPA flag'i default kapalı
        maxAdContentRating: MaxAdContentRating.t,
        tagForChildDirectedTreatment: childDirected
            ? TagForChildDirectedTreatment.yes
            : TagForChildDirectedTreatment.no,
        tagForUnderAgeOfConsent: TagForUnderAgeOfConsent.no,
      );
      await MobileAds.instance.updateRequestConfiguration(requestConfiguration);

      await MobileAds.instance.initialize();

      _bannerAdUnitId = bannerAdUnitId;
      _interstitialAdUnitId = interstitialAdUnitId;
      _rewardedAdUnitId = rewardedAdUnitId;

      _isInitialized = true;
      debugPrint('AdService initialized (testMode: $isTestMode, coppa: $childDirected)');

      // Premium durumunu kontrol et
      final subscription = await ShopService.instance.getSubscription();
      _isPremium = subscription.tier != PremiumTier.free;
    } catch (e) {
      debugPrint('AdService initialization error: $e');
    }
  }

  /// Bazı cihaz/akışlarda reklam çağrısı, `main()` içindeki init zinciri bitmeden
  /// tetiklenebiliyor. Bu metot gerekirse initialize eder ve aynı anda birden
  /// fazla init başlamasını engeller.
  Future<void> ensureInitialized() async {
    if (_isInitialized) return;
    _initFuture ??= initialize();
    try {
      await _initFuture;
    } finally {
      // init başarısız olabilir; sonraki denemelerde tekrar deneyebilmek için boşalt.
      if (!_isInitialized) _initFuture = null;
    }
  }

  /// Kullanıcı consent durumuna göre kişiselleştirilmiş reklam tercihi.
  /// `granted = false` → non-personalized (npa=1) gösterilir.
  bool _personalizedAdsConsent = true;
  void setConsent({required bool granted}) {
    _personalizedAdsConsent = granted;
  }

  AdRequest _buildAdRequest() {
    if (_personalizedAdsConsent) return const AdRequest();
    return const AdRequest(nonPersonalizedAds: true);
  }

  /// Test modunda mı? 
  /// Güvenlik için debug build'lerde varsayılan olarak test reklamları gösterilir.
  /// Ancak .env'de ADMOB_FORCE_PRODUCTION=true ise gerçek reklamlar yüklenebilir.
  bool get isTestMode {
    if (dotenv.get('ADMOB_FORCE_PRODUCTION', fallback: 'false') == 'true') {
      return false;
    }
    return kDebugMode;
  }

  /// Banner reklam ID'si
  String get bannerAdUnitId {
    // Önce .env'den (Eğer test ID'si değilse ve Test Modu değilse)
    if (_bannerIdEnv.isNotEmpty && (!isTestMode || !_bannerIdEnv.contains('3940256099942544'))) return _bannerIdEnv;
    
    // Test modu aktifse her zaman test ID döndür
    if (isTestMode) {
      return defaultTargetPlatform == TargetPlatform.iOS
          ? _iosBannerTestId
          : _androidBannerTestId;
    }
    
    // Release modunda/Gerçek reklam modunda: önce .env'den, sonra production ID'den
    if (_bannerAdUnitId != null && _bannerAdUnitId!.isNotEmpty) return _bannerAdUnitId!;
    return defaultTargetPlatform == TargetPlatform.iOS
        ? _iosBannerTestId
        : _androidBannerProdId;
  }

  /// Interstitial reklam ID'si
  String get interstitialAdUnitId {
    if (isTestMode) {
      return defaultTargetPlatform == TargetPlatform.iOS
          ? _iosInterstitialTestId
          : _androidInterstitialTestId;
    }
    if (_interstitialAdUnitId != null && _interstitialAdUnitId!.isNotEmpty) return _interstitialAdUnitId!;
    if (_interstitialIdEnv.isNotEmpty) return _interstitialIdEnv;
    return defaultTargetPlatform == TargetPlatform.iOS
        ? _iosInterstitialTestId
        : _androidInterstitialProdId;
  }

  /// Rewarded reklam ID'si
  String get rewardedAdUnitId {
    if (isTestMode) {
      return defaultTargetPlatform == TargetPlatform.iOS
          ? _iosRewardedTestId
          : _androidRewardedTestId;
    }
    if (_rewardedAdUnitId != null && _rewardedAdUnitId!.isNotEmpty) return _rewardedAdUnitId!;
    if (_rewardedIdEnv.isNotEmpty) return _rewardedIdEnv;
    return defaultTargetPlatform == TargetPlatform.iOS
        ? _iosRewardedTestId
        : _androidRewardedProdId;
  }

  /// Coin ödülü için (mağazadan "reklam izle + coin") ayrı rewarded birimi kullanılabilir.
  /// `.env` içinde `ADMOB_COIN_REWARDED_ID` verilmezse normal rewarded birimine düşer.
  String get coinRewardedAdUnitId {
    if (_coinRewardedIdEnv.isNotEmpty) return _coinRewardedIdEnv;
    return rewardedAdUnitId;
  }

  /// Interstitial reklam yükle ve göster
  Future<bool> showInterstitialAd() async {
    if (_isAdLoading || _isPremium) return false;
    
    try {
      _isAdLoading = true;
      final completer = Completer<bool>();
      
      InterstitialAd.load(
        adUnitId: interstitialAdUnitId,
        request: _buildAdRequest(),
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
            _isAdLoading = false;
            completer.complete(false);
          },
        ),
      );
      
      return await completer.future;
    } catch (e) {
      debugPrint('Error showing interstitial ad: $e');
      return false;
    } finally {
      _isAdLoading = false;
    }
  }

  /// Sonuç / mağaza ekranı açılırken çağrılabilir; reklam gösteriminde ilk yükleme beklemez.
  void preloadRewardedAd({String? adUnitIdOverride}) {
    if (!_isInitialized) {
      // Fire-and-forget: preload için init beklemek zorunda değiliz.
      unawaited(ensureInitialized());
      return;
    }
    if (!_isInitialized || _isPremium || _preloadedRewardedAd != null) return;
    final adUnitId = adUnitIdOverride ?? rewardedAdUnitId;
    try {
      RewardedAd.load(
        adUnitId: adUnitId,
        request: _buildAdRequest(),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (ad) {
            if (_preloadedRewardedAd != null) {
              ad.dispose();
              return;
            }
            _preloadedRewardedAd = ad;
            debugPrint('AdService: Rewarded ad preloaded');
          },
          onAdFailedToLoad: (error) {
            debugPrint('AdService: Rewarded preload failed: $error');
          },
        ),
      );
    } catch (e) {
      debugPrint('AdService: Rewarded preload error: $e');
    }
  }

  Future<RewardedAd?> _loadRewardedAdForShow({required String adUnitId}) async {
    final completer = Completer<RewardedAd?>();
    RewardedAd.load(
      adUnitId: adUnitId,
      request: _buildAdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          if (!completer.isCompleted) completer.complete(ad);
        },
        onAdFailedToLoad: (error) {
          debugPrint('Rewarded ad failed to load: $error');
          if (!completer.isCompleted) completer.complete(null);
        },
      ),
    );
    return completer.future;
  }

  /// Ödül sadece [onAdDismissedFullScreenContent] içinde tamamlanır; aksi halde
  /// dismiss callback'i [onUserEarnedReward]'dan önce gelince kullanıcı haksız yere 0 alıyordu.
  Future<int> _presentRewardedAd(RewardedAd ad, int defaultReward) async {
    final completer = Completer<int>();
    var userEarned = false;
    var rewardAmount = 0;

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        if (!completer.isCompleted) {
          if (userEarned) {
            completer.complete(
              rewardAmount > 0 ? rewardAmount : defaultReward,
            );
          } else {
            completer.complete(0);
          }
        }
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        debugPrint('Rewarded ad failed to show: $error');
        ad.dispose();
        if (!completer.isCompleted) completer.complete(0);
      },
    );

    ad.show(
      onUserEarnedReward: (ad, reward) {
        userEarned = true;
        rewardAmount = reward.amount.toInt();
      },
    );

    return completer.future;
  }

  /// Ödüllü reklam yükle ve göster
  /// Başarılı olursa ödül miktarını döndürür
  Future<int> showRewardedAd({
    int defaultReward = 25,
    String? adUnitIdOverride,
  }) async {
    if (!_isInitialized) {
      await ensureInitialized();
    }
    if (!_isInitialized) return 0;
    if (_isPremium) return 0;
    if (_isAdLoading) return 0;

    try {
      _isAdLoading = true;

      RewardedAd? ad = _preloadedRewardedAd;
      _preloadedRewardedAd = null;

      final adUnitId = adUnitIdOverride ?? rewardedAdUnitId;
      ad ??= await _loadRewardedAdForShow(adUnitId: adUnitId);
      if (ad == null) return 0;

      return await _presentRewardedAd(ad, defaultReward);
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

  // --- Oyun bitişi reklam ritmi ---
  //
  // Kuraldeğişikliği (v1):
  // - Klasik oyunlar (maxi, results, practice): her 5 oyunda bir reklam.
  // - Düello: her 5 düelloda bir; ama 5. maç rövanş zincirinin ortasında
  //   isekullanıcı akışı kesilmesin diye reklam ERTELENİR ve zincirin son
  //   rövanşı bittiğinde gösterilir.
  int _gamesSinceLastAd = 0;
  int _duelsSinceLastAd = 0;
  bool _pendingDuelInterstitial = false;

  /// 5 oyunda bir interstitial.
  Future<void> onGameCompleted() async {
    if (_isPremium) return;
    _gamesSinceLastAd++;
    if (_gamesSinceLastAd >= 5) {
      _gamesSinceLastAd = 0;
      await showInterstitialAd();
    }
  }

  /// Düello tamamlandığında çağrılır.
  ///
  /// [isRematch] — bu maçın bir rövanş zincirinin parçası olup olmadığı.
  /// Rövanş zinciri devam ederken reklam gösterilmez.
  ///
  /// [rematchChainEnded] — rövanş zinciri bitti mi (kullanıcı "Ana menü"ye
  /// döndü ya da rakip rövanş istemeyi reddetti).
  Future<void> onDuelCompleted({
    bool isRematch = false,
    bool rematchChainEnded = false,
  }) async {
    if (_isPremium) return;
    _duelsSinceLastAd++;

    // 5. maçta eşik yakalanırsa pending flag'i aç
    if (_duelsSinceLastAd >= 5) {
      _pendingDuelInterstitial = true;
    }

    final shouldShowNow = _pendingDuelInterstitial &&
        (!isRematch || rematchChainEnded);

    if (shouldShowNow) {
      _pendingDuelInterstitial = false;
      _duelsSinceLastAd = 0;
      await showInterstitialAd();
    }
  }

  /// Rövanş zinciri kullanıcı tarafından kapatıldığında (Ana menüye dönüş vb.)
  /// çağrılır. Bekleyen bir reklam varsa burada gösterilir.
  Future<void> onRematchChainEnded() async {
    if (_isPremium) return;
    if (_pendingDuelInterstitial) {
      _pendingDuelInterstitial = false;
      _duelsSinceLastAd = 0;
      await showInterstitialAd();
    }
  }

  /// Debug amaçlı: bekleyen reklam var mı?
  bool get hasPendingDuelInterstitial => _pendingDuelInterstitial;
}

/// Gerçek Banner Reklam Widget'ı
class BannerAdWidget extends StatefulWidget {
  final AdSize adSize;
  const BannerAdWidget({super.key, this.adSize = AdSize.banner});

  @override
  State<BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends State<BannerAdWidget> {
  BannerAd? _bannerAd;
  bool _isLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadAd();
  }

  void _loadAd() {
    if (AdService.instance.isPremium) return;

    _bannerAd = BannerAd(
      adUnitId: AdService.instance.bannerAdUnitId,
      request: const AdRequest(),
      size: widget.adSize,
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (mounted) {
            setState(() {
              _isLoaded = true;
            });
            debugPrint('✅ Banner Ad yüklendi ve görünür oldu.');
          }
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('❌ Banner Ad yükleme hatası: $error');
          ad.dispose();
          if (mounted) {
            setState(() {
              _isLoaded = false;
            });
          }
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (AdService.instance.isPremium) return const SizedBox.shrink();

    if (_isLoaded && _bannerAd != null) {
      return Container(
        alignment: Alignment.center,
        width: _bannerAd!.size.width.toDouble(),
        height: _bannerAd!.size.height.toDouble(),
        child: AdWidget(ad: _bannerAd!),
      );
    }

    // Reklam yüklenene kadar boşluk bırakma (tasarımın bozulmaması için shrink döndür)
    return const SizedBox.shrink();
  }
}
