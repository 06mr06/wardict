import 'dart:async';
import 'dart:io' show Platform;
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'ad_service.dart';
import 'analytics_service.dart';
import 'economy_service.dart';
import 'shop_service.dart';
import 'user_profile_service.dart';
import 'firebase/auth_service.dart';

/// Satın alma akışındaki UI-taraflı event türleri. `PurchaseService` bu
/// event'leri broadcast stream üzerinden emit eder; shop/settings ekranı
/// dinleyip kullanıcıya toast/sheet ile cevap verir.
enum PurchaseEventType {
  pending,
  succeeded,
  restored,
  canceled,
  failed,
  serverVerificationFailed,
}

class PurchaseEvent {
  final PurchaseEventType type;
  final String? productId;
  final String? message;
  const PurchaseEvent({required this.type, this.productId, this.message});
}

/// Satın alınabilir ürün türleri
enum ProductType {
  /// Tek seferlik satın alma (coin paketleri gibi)
  consumable,
  /// Kalıcı satın alma (premium özellik açma gibi)
  nonConsumable,
  /// Abonelik (aylık/yıllık premium)
  subscription,
}

/// Ürün bilgisi
class ProductInfo {
  final String id;
  final String title;
  final String description;
  final String price;
  final double priceValue;
  final String currencyCode;
  final ProductType type;
  final int? coinAmount; // Coin paketi ise kaç coin

  /// Pazarlama rozeti — UI'da paketin üstünde gözükür ("+%20 BONUS",
  /// "EN DEĞERLİ", "STARTER PACK" gibi). Boşsa rozet çizilmez.
  final String? badge;

  /// Paketin vurgulu ("best value") olup olmadığı — UI farklı renk/border ile
  /// gösterir. Anchor pricing için kullanılır.
  final bool highlight;

  /// Çizili gösterilecek orijinal fiyat (örn. "₺594" bundle için).
  final String? originalPrice;

  /// Sınırlı süreli teklifse ürünün geçerlilik sonu (epoch ms). UI countdown
  /// gösterir. `null` → süresiz.
  final int? offerExpiresAtMs;

  const ProductInfo({
    required this.id,
    required this.title,
    required this.description,
    required this.price,
    required this.priceValue,
    required this.currencyCode,
    required this.type,
    this.coinAmount,
    this.badge,
    this.highlight = false,
    this.originalPrice,
    this.offerExpiresAtMs,
  });

  ProductInfo copyWith({
    String? badge,
    bool? highlight,
    String? originalPrice,
    int? offerExpiresAtMs,
  }) =>
      ProductInfo(
        id: id,
        title: title,
        description: description,
        price: price,
        priceValue: priceValue,
        currencyCode: currencyCode,
        type: type,
        coinAmount: coinAmount,
        badge: badge ?? this.badge,
        highlight: highlight ?? this.highlight,
        originalPrice: originalPrice ?? this.originalPrice,
        offerExpiresAtMs: offerExpiresAtMs ?? this.offerExpiresAtMs,
      );
}

/// Satın alma sonucu
class PurchaseResult {
  final bool success;
  final String? errorMessage;
  final String? transactionId;
  final ProductInfo? product;

  const PurchaseResult({
    required this.success,
    this.errorMessage,
    this.transactionId,
    this.product,
  });
}

/// Satın alma servisi - In-App Purchases entegrasyonu
/// 
/// Kullanım:
/// 1. pubspec.yaml'a ekle: in_app_purchase: ^3.2.0
/// 2. Android: Google Play Console'da ürünleri tanımla
/// 3. iOS: App Store Connect'te ürünleri tanımla
/// 4. PurchaseService.instance.initialize() çağır
class PurchaseService {
  static final PurchaseService instance = PurchaseService._internal();
  PurchaseService._internal();

  bool _isInitialized = false;
  bool _isPurchasing = false;
  bool _storeAvailable = false;
  bool _restoredAny = false;

  final StreamController<PurchaseEvent> _eventCtrl =
      StreamController<PurchaseEvent>.broadcast();

  /// UI için broadcast purchase event stream.
  Stream<PurchaseEvent> get events => _eventCtrl.stream;

  void _emit(PurchaseEvent e) {
    if (!_eventCtrl.isClosed) _eventCtrl.add(e);
  }

  // Ürün ID'leri (Play Store ve App Store'da aynı olmalı)
  static const String coinPack500Id = 'coins_500';
  static const String coinPack1250Id = 'coins_1250';
  static const String coinPack2500Id = 'coins_2500';
  static const String coinPack3750Id = 'coins_3750';
  static const String premiumMonthlyId = 'premium_monthly';
  static const String premiumYearlyId = 'premium_yearly';
  static const String removeAdsId = 'remove_ads';
  
  // Kelime Paketleri
  static const String packPhrasalsId = 'pack_phrasals';
  static const String packAdjectivesId = 'pack_adjectives';
  static const String packVerbsId = 'pack_verbs';
  static const String packAdverbsId = 'pack_adverbs';
  static const String packIdiomsId = 'pack_idioms';
  static const String packNounsId = 'pack_nouns';

  // Bundle & Promo ürünler
  /// İlk 72 saat — bir kez satın alınır. 7 gün premium + 1000 coin + 3 PU.
  static const String starterPackId = 'starter_pack_72h';

  /// 6 kelime paketi bir arada — çapa fiyat ile güçlü indirim algısı.
  static const String allPacksBundleId = 'all_packs_bundle';

  /// 3 ay premium + özel avatar (nonConsumable, abonelik değil).
  static const String seasonPassId = 'season_pass_3m';

  /// Demo / yedek gösterim: (TRY metni, TRY sayısal, USD metni, USD sayısal).
  static (String, double, String, double)? _coinPackDemoPricing(String id) {
    return switch (id) {
      coinPack500Id => ('₺29,99', 29.99, r'$0.99', 0.99),
      coinPack1250Id => ('₺59,99', 59.99, r'$1.99', 1.99),
      coinPack2500Id => ('₺89,99', 89.99, r'$2.99', 2.99),
      coinPack3750Id => ('₺119,99', 119.99, r'$3.99', 3.99),
      _ => null,
    };
  }

  /// Mağazada SKU yoksa coin kartında gösterilecek fiyat — cihaz diline göre hep TRY **veya** hep USD (karışık sembol kalmaz).
  static String coinPackUiFallbackPrice(String productId) {
    final p = _coinPackDemoPricing(productId);
    if (p == null) return '—';
    final isTurkish =
        ui.PlatformDispatcher.instance.locale.languageCode == 'tr';
    return isTurkish ? p.$1 : p.$3;
  }

  void _addDemoCoinProduct({
    required String id,
    required String title,
    required String description,
    required int coinAmount,
    String? badge,
    bool highlight = false,
  }) {
    final p = _coinPackDemoPricing(id);
    if (p == null) return;
    final isTurkish =
        ui.PlatformDispatcher.instance.locale.languageCode == 'tr';
    _products.add(ProductInfo(
      id: id,
      title: title,
      description: description,
      price: isTurkish ? p.$1 : p.$3,
      priceValue: isTurkish ? p.$2 : p.$4,
      currencyCode: isTurkish ? 'TRY' : 'USD',
      type: ProductType.consumable,
      coinAmount: coinAmount,
      badge: badge,
      highlight: highlight,
    ));
  }

  // Yüklenen ürünler
  final List<ProductInfo> _products = [];
  List<ProductInfo> get products => List.unmodifiable(_products);

  // Premium durumu
  bool _isPremium = false;
  bool _hasRemovedAds = false;
  DateTime? _premiumExpiryDate;

  bool get isPremium => _isPremium;
  bool get hasRemovedAds => _hasRemovedAds || _isPremium;
  DateTime? get premiumExpiryDate => _premiumExpiryDate;

  /// Servisi başlat
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Önceki satın almaları yükle
      await _loadPurchaseState();
      // Premium durumunu AdService'e sync et
      AdService.instance.setPremiumStatus(_isPremium || _hasRemovedAds);
      
      // Web'de in_app_purchase desteklenmez, direkt demo ürünleri yükle
      if (kIsWeb) {
        debugPrint('PurchaseService: Web platform detected, using demo products');
        _loadDemoProducts();
        _isInitialized = true;
        return;
      }

      final bool available = await InAppPurchase.instance.isAvailable();
      _storeAvailable = available;
      if (!available) {
        debugPrint('In-app purchases not available');
        _loadDemoProducts();
        return;
      }

      // Ürünleri yükle
      const Set<String> productIds = {
        coinPack500Id,
        coinPack1250Id,
        coinPack2500Id,
        coinPack3750Id,
        premiumMonthlyId,
        premiumYearlyId,
        removeAdsId,
        packPhrasalsId,
        packAdjectivesId,
        packVerbsId,
        packAdverbsId,
        packIdiomsId,
        packNounsId,
        starterPackId,
        allPacksBundleId,
        seasonPassId,
      };

      final ProductDetailsResponse response = 
          await InAppPurchase.instance.queryProductDetails(productIds);
      
      if (response.notFoundIDs.isNotEmpty) {
        debugPrint('Products not found: ${response.notFoundIDs}');
      }

      _products.clear();
      if (response.productDetails.isEmpty) {
         _loadDemoProducts();
      } else {
        for (final product in response.productDetails) {
          _products.add(ProductInfo(
            id: product.id,
            title: product.title,
            description: product.description,
            price: product.price,
            priceValue: product.rawPrice,
            currencyCode: product.currencyCode,
            type: _getProductType(product.id),
            coinAmount: _getCoinAmount(product.id),
          ));
        }
      }

      // Satın alma akışını dinle
      InAppPurchase.instance.purchaseStream.listen(_onPurchaseUpdated);
      
      // Önceki satın almaları doğrula
      await InAppPurchase.instance.restorePurchases();

      _isInitialized = true;
      debugPrint('PurchaseService initialized');
    } catch (e) {
      debugPrint('PurchaseService initialization error: $e');
      _loadDemoProducts();
    }
  }

  /// Demo ürünleri yükle
  void _loadDemoProducts() {
    final languageCode = ui.PlatformDispatcher.instance.locale.languageCode;
    final isTurkish = languageCode == 'tr';
    
    _products.clear();
    
    // Coin Paketleri — fiyat tablosu [_coinPackDemoPricing] ile tek kaynak
    _addDemoCoinProduct(
      id: coinPack500Id,
      title: '500 Altın',
      description: 'Başlangıç altın paketi',
      coinAmount: 500,
    );
    _addDemoCoinProduct(
      id: coinPack1250Id,
      title: '1250 Altın',
      description: '+%20 BONUS — sık oynayanların tercihi',
      coinAmount: 1250,
      badge: '+%20 BONUS',
    );
    _addDemoCoinProduct(
      id: coinPack2500Id,
      title: '2500 Altın',
      description: '+%40 BONUS — en popüler seçim',
      coinAmount: 2500,
      badge: '+%40 BONUS',
      highlight: true,
    );
    _addDemoCoinProduct(
      id: coinPack3750Id,
      title: '3750 Altın',
      description: '+%60 BONUS — en değerli paket',
      coinAmount: 3750,
      badge: 'EN DEĞERLİ',
    );

    // Premium abonelikler — yeniden fiyatlandırıldı (2.5 görev)
    _products.add(ProductInfo(
      id: premiumMonthlyId,
      title: 'Premium Aylık',
      description: 'Reklamsız · 2× LP · Günlük 50 coin bonus',
      price: isTurkish ? '₺59,00/ay' : '\$2.99/mo',
      priceValue: isTurkish ? 59.00 : 2.99,
      currencyCode: isTurkish ? 'TRY' : 'USD',
      type: ProductType.subscription,
    ));
    _products.add(ProductInfo(
      id: premiumYearlyId,
      title: 'Premium Yıllık',
      description: '₺708 yerine ₺399 — 9 ay hediye',
      price: isTurkish ? '₺399,00/yıl' : '\$19.99/yr',
      priceValue: isTurkish ? 399.00 : 19.99,
      currencyCode: isTurkish ? 'TRY' : 'USD',
      type: ProductType.subscription,
      badge: 'EN AVANTAJLI',
      originalPrice: isTurkish ? '₺708' : null,
      highlight: true,
    ));

    // Reklamları kaldır — premium aylık ile çakışmayacak şekilde konumlandırıldı
    _products.add(ProductInfo(
      id: removeAdsId,
      title: 'Reklamları Kaldır',
      description: 'Tek seferlik — tüm reklamları kalıcı kapatır',
      price: isTurkish ? '₺149,00' : '\$4.99',
      priceValue: isTurkish ? 149.00 : 4.99,
      currencyCode: isTurkish ? 'TRY' : 'USD',
      type: ProductType.nonConsumable,
    ));

    // Kelime paketleri — tek tek ₺99
    final List<String> packIds = [
      packPhrasalsId, packAdjectivesId, packVerbsId,
      packAdverbsId, packIdiomsId, packNounsId,
    ];
    final List<String> packTitles = [
      'Phrasal Verbs', 'Sıfatlar (Adjectives)', 'Fiiller (Verbs)',
      'Zarflar (Adverbs)', 'Deyimler (Idioms)', 'İsimler (Nouns)',
    ];
    for (int i = 0; i < packIds.length; i++) {
      _products.add(ProductInfo(
        id: packIds[i],
        title: '${packTitles[i]} Paketi',
        description: '300+ kelime ile uzmanlaşın',
        price: isTurkish ? '₺99,00' : '\$2.99',
        priceValue: isTurkish ? 99.00 : 2.99,
        currencyCode: isTurkish ? 'TRY' : 'USD',
        type: ProductType.nonConsumable,
      ));
    }

    // Starter Pack — ilk 72 saat limited offer (tek seferlik)
    _products.add(ProductInfo(
      id: starterPackId,
      title: 'Starter Pack',
      description: '7 gün Premium + 1000 altın + 3 power-up',
      price: isTurkish ? '₺49,00' : '\$1.99',
      priceValue: isTurkish ? 49.00 : 1.99,
      currencyCode: isTurkish ? 'TRY' : 'USD',
      type: ProductType.nonConsumable,
      coinAmount: 1000,
      badge: 'STARTER — %70 İNDİRİM',
      originalPrice: isTurkish ? '₺169' : null,
      highlight: true,
      offerExpiresAtMs: DateTime.now()
          .add(const Duration(hours: 72))
          .millisecondsSinceEpoch,
    ));

    // Kelime paketleri bundle — 6×99 yerine 299 (çapa fiyat).
    _products.add(ProductInfo(
      id: allPacksBundleId,
      title: 'Tüm Kelime Paketleri',
      description: '6 paket birden — ₺594 yerine ₺299',
      price: isTurkish ? '₺299,00' : '\$9.99',
      priceValue: isTurkish ? 299.00 : 9.99,
      currencyCode: isTurkish ? 'TRY' : 'USD',
      type: ProductType.nonConsumable,
      badge: 'BUNDLE — %50 İNDİRİM',
      originalPrice: isTurkish ? '₺594' : null,
      highlight: true,
    ));

    // Season Pass — 3 ay premium + özel avatar (kalıcı)
    _products.add(ProductInfo(
      id: seasonPassId,
      title: 'Season Pass',
      description: '3 ay Premium + özel sezon avatarı',
      price: isTurkish ? '₺199,00' : '\$6.99',
      priceValue: isTurkish ? 199.00 : 6.99,
      currencyCode: isTurkish ? 'TRY' : 'USD',
      type: ProductType.nonConsumable,
      badge: 'SEASON PASS',
    ));
  }

  // ignore: unused_element - İleride ürün tipi belirleme için kullanılacak
  ProductType _getProductType(String productId) {
    if (productId.startsWith('coins_')) return ProductType.consumable;
    if (productId.startsWith('premium_')) return ProductType.subscription;
    return ProductType.nonConsumable;
  }

  // ignore: unused_element - İleride coin miktarı hesaplama için kullanılacak
  int? _getCoinAmount(String productId) {
    switch (productId) {
      case coinPack500Id: return 500;
      case coinPack1250Id: return 1250;
      case coinPack2500Id: return 2500;
      case coinPack3750Id: return 3750;
      default: return null;
    }
  }

  /// Satın alma durumunu kaydet/yükle
  Future<void> _loadPurchaseState() async {
    final prefs = await SharedPreferences.getInstance();
    _isPremium = prefs.getBool('is_premium') ?? false;
    _hasRemovedAds = prefs.getBool('has_removed_ads') ?? false;
    
    final expiryMs = prefs.getInt('premium_expiry');
    if (expiryMs != null) {
      _premiumExpiryDate = DateTime.fromMillisecondsSinceEpoch(expiryMs);
      // Süresi dolmuşsa premium'u kaldır
      if (_premiumExpiryDate!.isBefore(DateTime.now())) {
        _isPremium = false;
        await prefs.setBool('is_premium', false);
      }
    }
  }

  Future<void> _savePurchaseState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_premium', _isPremium);
    await prefs.setBool('has_removed_ads', _hasRemovedAds);
    if (_premiumExpiryDate != null) {
      await prefs.setInt('premium_expiry', _premiumExpiryDate!.millisecondsSinceEpoch);
    }
  }

  /// Ürün satın al
  Future<PurchaseResult> purchase(String productId) async {
    if (_isPurchasing) {
      return const PurchaseResult(
        success: false,
        errorMessage: 'Bir satın alma işlemi devam ediyor',
      );
    }

    final product = _products.where((p) => p.id == productId).firstOrNull;
    if (product == null) {
      return const PurchaseResult(
        success: false,
        errorMessage: 'Ürün bulunamadı',
      );
    }

    try {
      _isPurchasing = true;

      // Web bypass (Chrome debugging için)
      if (kIsWeb) {
        debugPrint('PurchaseService: Web simulation success');
        await Future.delayed(const Duration(seconds: 1));
        await _handleSuccessfulPurchase(product);
        _isPurchasing = false;
        return PurchaseResult(success: true, product: product);
      }

      // Admin Bypass
      if (AuthService.instance.userEmail == 'admin@wardict.com') {
        debugPrint('Admin user detected, bypassing actual purchase flow...');
        await Future.delayed(const Duration(seconds: 1));
        await _handleSuccessfulPurchase(product);
        _isPurchasing = false;
        return PurchaseResult(success: true, product: product);
      }

      final bool available = await InAppPurchase.instance.isAvailable();
      if (!available) {
        // Fallback to demo mode for simulator testing if needed, or error
        debugPrint('In-app purchases not available, using demo fallback');
        await Future.delayed(const Duration(seconds: 1));
        await _handleSuccessfulPurchase(product);
        _isPurchasing = false;
        return PurchaseResult(success: true, product: product);
      }

      final ProductDetails? productDetails = 
          (await InAppPurchase.instance.queryProductDetails({productId}))
              .productDetails
              .firstOrNull;
      
      if (productDetails == null) {
        // SKELETON TEST DESTEĞİ: Ürün ID'si Play/App Store'da tanımlı değilse bile
        // yerel demo ürünlerinden biriyse simülasyona izin ver.
        debugPrint('ℹ️ Product $productId not found in store, falling back to simulation.');
        await Future.delayed(const Duration(seconds: 1));
        await _handleSuccessfulPurchase(product);
        _isPurchasing = false;
        return PurchaseResult(success: true, product: product);
      }

      final PurchaseParam purchaseParam = PurchaseParam(
        productDetails: productDetails,
      );

      // Consumable ürünler için
      if (product.type == ProductType.consumable) {
        await InAppPurchase.instance.buyConsumable(purchaseParam: purchaseParam);
      } else {
        await InAppPurchase.instance.buyNonConsumable(purchaseParam: purchaseParam);
      }
      
      // Sonuç purchaseStream'den gelecek, biz şimdilik true dönüyoruz
      return const PurchaseResult(success: true);
    } catch (e) {
      debugPrint('Purchase error: $e');
      _isPurchasing = false;
      return PurchaseResult(
        success: false,
        errorMessage: e.toString(),
      );
    }
  }

  /// Satın alma başarılı olduğunda — SUNUCUDA doğrula ve entitlement'ı uygula.
  ///
  /// SUNUCU tarafı `verifyPurchase` Google Play / App Store üzerinden receipt'i
  /// doğrular ve altını/premium'u yazar. Client sadece UI'yi günceller.
  Future<void> _verifyOnServerAndApply(
    ProductInfo product,
    PurchaseDetails? purchase,
  ) async {
    String platform = 'android';
    try {
      if (Platform.isIOS) platform = 'ios';
    } catch (_) {
      // web / desktop
      platform = 'web';
    }

    String? purchaseToken;
    String? receiptData;
    if (purchase != null) {
      try {
        purchaseToken = purchase.verificationData.serverVerificationData;
        receiptData = purchase.verificationData.localVerificationData;
      } catch (e) {
        debugPrint('⚠️ Could not read purchase verification data: $e');
      }
    }

    final result = await EconomyService.instance.verifyPurchase(
      platform: platform,
      productId: product.id,
      purchaseToken: purchaseToken,
      receipt: receiptData,
    );

    if (!result.success) {
      debugPrint('❌ verifyPurchase failed: ${result.errorMessage}');
      AnalyticsService.instance.logEvent(
        'iap_verify_failed',
        {
          'product_id': product.id,
          'platform': platform,
          'message': result.errorMessage ?? 'unknown',
        },
      );
      _emit(PurchaseEvent(
        type: PurchaseEventType.serverVerificationFailed,
        productId: product.id,
        message: result.errorMessage,
      ));
      return;
    }

    AnalyticsService.instance.logEvent(
      'iap_verify_success',
      {
        'product_id': product.id,
        'platform': platform,
        'price_value': product.priceValue,
        'currency': product.currencyCode,
      },
    );
    _emit(PurchaseEvent(
      type: PurchaseEventType.succeeded,
      productId: product.id,
    ));

    // Entitlement durumunu local'e yansıt
    _isPremium = result.isPremium;
    _hasRemovedAds = result.hasRemovedAds;
    if (result.premiumExpiresAtMs != null) {
      _premiumExpiryDate = DateTime.fromMillisecondsSinceEpoch(
        result.premiumExpiresAtMs!,
      );
    }

    // AdService güncelle
    AdService.instance.setPremiumStatus(_isPremium || _hasRemovedAds);

    // Non-consumable pack unlocks (simülasyonda da senkron tutmak için)
    if (product.type == ProductType.nonConsumable &&
        product.id.startsWith('pack_') &&
        product.id != allPacksBundleId) {
      final packId = product.id.replaceFirst('pack_', '');
      await ShopService.instance.unlockPack(packId);
    }

    // All-packs bundle → tüm kelime paketlerini aç
    if (product.id == allPacksBundleId) {
      for (final packId in const [
        'phrasals',
        'adjectives',
        'verbs',
        'adverbs',
        'idioms',
        'nouns',
      ]) {
        await ShopService.instance.unlockPack(packId);
      }
    }

    // Season pass → 90 günlük premium local mirror (sunucu asıl kaydı tutar)
    if (product.id == seasonPassId) {
      _isPremium = true;
      _premiumExpiryDate = DateTime.now().add(const Duration(days: 90));
    }

    // Starter pack → 7 gün premium mirror + local bilgi olarak satın alınma
    // damgası (yeniden gösterilmesin diye).
    if (product.id == starterPackId) {
      _isPremium = true;
      _premiumExpiryDate = DateTime.now().add(const Duration(days: 7));
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('starter_pack_claimed', true);
    }

    // Bulut profilini çek (yeni bakiye için)
    await UserProfileService.instance.fetchProfileFromFirestore();

    await _savePurchaseState();
  }

  @Deprecated(
      'Use _verifyOnServerAndApply instead — client-side entitlement insecure.')
  Future<void> _handleSuccessfulPurchase(ProductInfo product) async {
    await _verifyOnServerAndApply(product, null);
  }

  /// Önceki satın almaları geri yükle.
  ///
  /// Apple guideline 3.1.1 gereği ayarlar ekranında bu butonun olması
  /// zorunludur. Mağazadan purchased/restored event'leri `_onPurchaseUpdated`'e
  /// düşer ve sunucu doğrulaması sonrası entitlement tekrar uygulanır.
  ///
  /// [timeout] süresi içinde hiç restore event'i gelmezse `false` döner —
  /// UI "restore edilecek işlem yok" mesajı gösterebilir.
  Future<bool> restorePurchases({
    Duration timeout = const Duration(seconds: 12),
  }) async {
    try {
      _restoredAny = false;
      if (_storeAvailable) {
        await InAppPurchase.instance.restorePurchases();
      } else {
        debugPrint('ℹ️ Store unavailable — local state reload only');
      }
      await _loadPurchaseState();
      final deadline = DateTime.now().add(timeout);
      while (!_restoredAny && DateTime.now().isBefore(deadline)) {
        await Future.delayed(const Duration(milliseconds: 400));
      }
      debugPrint('✅ restorePurchases completed (restored=$_restoredAny)');
      return _restoredAny;
    } catch (e) {
      debugPrint('⚠️ Restore purchases error: $e');
      return false;
    }
  }

  /// Satın alma işlemi bittiğinde (stream listener)
  void _onPurchaseUpdated(List<PurchaseDetails> purchaseDetailsList) {
    for (final PurchaseDetails purchase in purchaseDetailsList) {
      if (purchase.status == PurchaseStatus.pending) {
        _isPurchasing = true;
        _emit(PurchaseEvent(
          type: PurchaseEventType.pending,
          productId: purchase.productID,
        ));
      } else if (purchase.status == PurchaseStatus.error ||
                 purchase.status == PurchaseStatus.canceled) {
        _isPurchasing = false;
        if (purchase.status == PurchaseStatus.error) {
          debugPrint('Purchase error: ${purchase.error}');
          AnalyticsService.instance.logEvent(
            'iap_error',
            {
              'product_id': purchase.productID,
              'code': purchase.error?.code ?? 'unknown',
              'message': purchase.error?.message ?? '',
            },
          );
          _emit(PurchaseEvent(
            type: PurchaseEventType.failed,
            productId: purchase.productID,
            message: purchase.error?.message,
          ));
        } else {
          debugPrint('Purchase canceled by user');
          AnalyticsService.instance.logEvent(
            'iap_canceled',
            {'product_id': purchase.productID},
          );
          _emit(PurchaseEvent(
            type: PurchaseEventType.canceled,
            productId: purchase.productID,
          ));
        }
      } else if (purchase.status == PurchaseStatus.purchased ||
                 purchase.status == PurchaseStatus.restored) {
        if (purchase.status == PurchaseStatus.restored) {
          _restoredAny = true;
          _emit(PurchaseEvent(
            type: PurchaseEventType.restored,
            productId: purchase.productID,
          ));
        }
        final product = getProduct(purchase.productID);
        if (product != null) {
          _verifyOnServerAndApply(product, purchase);
        }
        _isPurchasing = false;
      }

      if (purchase.pendingCompletePurchase) {
        InAppPurchase.instance.completePurchase(purchase);
      }
    }
  }

  /// Coin paketi ürünlerini al
  List<ProductInfo> get coinProducts => 
      _products.where((p) => p.type == ProductType.consumable).toList();

  /// Abonelik ürünlerini al
  List<ProductInfo> get subscriptionProducts => 
      _products.where((p) => p.type == ProductType.subscription).toList();

  /// Tek seferlik satın alma ürünlerini al
  List<ProductInfo> get nonConsumableProducts =>
      _products.where((p) => p.type == ProductType.nonConsumable).toList();

  /// Öne çıkan promo ürünler (Starter/Bundle/Season Pass) — highlight
  /// banner'ı için kullanılır. Starter Pack'in süresi dolmuşsa gösterilmez.
  List<ProductInfo> get highlightedProducts {
    final now = DateTime.now().millisecondsSinceEpoch;
    return _products.where((p) {
      if (!p.highlight && p.badge == null) return false;
      if (p.id == starterPackId) {
        if (p.offerExpiresAtMs == null) return true;
        return p.offerExpiresAtMs! > now;
      }
      return p.highlight;
    }).toList();
  }

  /// Kelime paketleri (sadece bundle dahil değil — tek tek paketler)
  List<ProductInfo> get wordPackProducts => _products
      .where((p) =>
          p.id.startsWith('pack_') && p.id != allPacksBundleId)
      .toList();

  /// Belirli bir ürünü al
  ProductInfo? getProduct(String productId) =>
      _products.where((p) => p.id == productId).firstOrNull;
}
