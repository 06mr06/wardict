import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  const ProductInfo({
    required this.id,
    required this.title,
    required this.description,
    required this.price,
    required this.priceValue,
    required this.currencyCode,
    required this.type,
    this.coinAmount,
  });
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

  // Ürün ID'leri (Play Store ve App Store'da aynı olmalı)
  static const String coinPack100Id = 'coins_100';
  static const String coinPack500Id = 'coins_500';
  static const String coinPack1500Id = 'coins_1500';
  static const String coinPack5000Id = 'coins_5000';
  static const String premiumMonthlyId = 'premium_monthly';
  static const String premiumYearlyId = 'premium_yearly';
  static const String removeAdsId = 'remove_ads';

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
      
      // in_app_purchase paketi eklendiğinde:
      /*
      final bool available = await InAppPurchase.instance.isAvailable();
      if (!available) {
        debugPrint('In-app purchases not available');
        return;
      }

      // Ürünleri yükle
      const Set<String> productIds = {
        coinPack100Id,
        coinPack500Id,
        coinPack1500Id,
        coinPack5000Id,
        premiumMonthlyId,
        premiumYearlyId,
        removeAdsId,
      };

      final ProductDetailsResponse response = 
          await InAppPurchase.instance.queryProductDetails(productIds);
      
      if (response.notFoundIDs.isNotEmpty) {
        debugPrint('Products not found: ${response.notFoundIDs}');
      }

      _products.clear();
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

      // Satın alma akışını dinle
      InAppPurchase.instance.purchaseStream.listen(_onPurchaseUpdated);
      
      // Önceki satın almaları doğrula
      await InAppPurchase.instance.restorePurchases();
      */

      // Demo ürünler (gerçek entegrasyonda store'dan yüklenir)
      _loadDemoProducts();

      _isInitialized = true;
      debugPrint('PurchaseService initialized');
    } catch (e) {
      debugPrint('PurchaseService initialization error: $e');
    }
  }

  /// Demo ürünleri yükle
  void _loadDemoProducts() {
    _products.clear();
    _products.addAll([
      const ProductInfo(
        id: coinPack100Id,
        title: '100 Altın',
        description: 'Küçük altın paketi',
        price: '₺9,99',
        priceValue: 9.99,
        currencyCode: 'TRY',
        type: ProductType.consumable,
        coinAmount: 100,
      ),
      const ProductInfo(
        id: coinPack500Id,
        title: '500 Altın',
        description: 'Orta altın paketi (+%10 bonus)',
        price: '₺44,99',
        priceValue: 44.99,
        currencyCode: 'TRY',
        type: ProductType.consumable,
        coinAmount: 550, // 500 + 50 bonus
      ),
      const ProductInfo(
        id: coinPack1500Id,
        title: '1500 Altın',
        description: 'Büyük altın paketi (+%20 bonus)',
        price: '₺119,99',
        priceValue: 119.99,
        currencyCode: 'TRY',
        type: ProductType.consumable,
        coinAmount: 1800, // 1500 + 300 bonus
      ),
      const ProductInfo(
        id: coinPack5000Id,
        title: '5000 Altın',
        description: 'Mega altın paketi (+%40 bonus)',
        price: '₺349,99',
        priceValue: 349.99,
        currencyCode: 'TRY',
        type: ProductType.consumable,
        coinAmount: 7000, // 5000 + 2000 bonus
      ),
      const ProductInfo(
        id: premiumMonthlyId,
        title: 'Premium Aylık',
        description: 'Reklamsız deneyim + Bonus özellikler',
        price: '₺29,99/ay',
        priceValue: 29.99,
        currencyCode: 'TRY',
        type: ProductType.subscription,
      ),
      const ProductInfo(
        id: premiumYearlyId,
        title: 'Premium Yıllık',
        description: 'Reklamsız deneyim + Bonus özellikler (%40 indirim)',
        price: '₺219,99/yıl',
        priceValue: 219.99,
        currencyCode: 'TRY',
        type: ProductType.subscription,
      ),
      const ProductInfo(
        id: removeAdsId,
        title: 'Reklamları Kaldır',
        description: 'Tüm reklamları kalıcı olarak kaldır',
        price: '₺79,99',
        priceValue: 79.99,
        currencyCode: 'TRY',
        type: ProductType.nonConsumable,
      ),
    ]);
  }

  ProductType _getProductType(String productId) {
    if (productId.startsWith('coins_')) return ProductType.consumable;
    if (productId.startsWith('premium_')) return ProductType.subscription;
    return ProductType.nonConsumable;
  }

  int? _getCoinAmount(String productId) {
    switch (productId) {
      case coinPack100Id: return 100;
      case coinPack500Id: return 550;
      case coinPack1500Id: return 1800;
      case coinPack5000Id: return 7000;
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

      // in_app_purchase paketi eklendiğinde:
      /*
      final ProductDetails? productDetails = 
          (await InAppPurchase.instance.queryProductDetails({productId}))
              .productDetails
              .firstOrNull;
      
      if (productDetails == null) {
        return const PurchaseResult(
          success: false,
          errorMessage: 'Ürün detayları alınamadı',
        );
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
      
      // Sonuç purchaseStream'den gelecek
      return const PurchaseResult(success: true);
      */

      // Demo mod - simüle edilmiş satın alma
      await Future.delayed(const Duration(seconds: 1));
      
      // Demo'da her zaman başarılı
      await _handleSuccessfulPurchase(product);
      
      return PurchaseResult(
        success: true,
        transactionId: 'demo_${DateTime.now().millisecondsSinceEpoch}',
        product: product,
      );
    } catch (e) {
      debugPrint('Purchase error: $e');
      return PurchaseResult(
        success: false,
        errorMessage: e.toString(),
      );
    } finally {
      _isPurchasing = false;
    }
  }

  /// Satın alma başarılı olduğunda
  Future<void> _handleSuccessfulPurchase(ProductInfo product) async {
    switch (product.type) {
      case ProductType.consumable:
        // Coin ekle
        if (product.coinAmount != null) {
          // ShopService.instance.addCoins(product.coinAmount!) çağrılabilir
          debugPrint('Added ${product.coinAmount} coins');
        }
        break;
        
      case ProductType.nonConsumable:
        if (product.id == removeAdsId) {
          _hasRemovedAds = true;
        }
        break;
        
      case ProductType.subscription:
        _isPremium = true;
        if (product.id == premiumMonthlyId) {
          _premiumExpiryDate = DateTime.now().add(const Duration(days: 30));
        } else if (product.id == premiumYearlyId) {
          _premiumExpiryDate = DateTime.now().add(const Duration(days: 365));
        }
        break;
    }
    
    await _savePurchaseState();
  }

  /// Önceki satın almaları geri yükle
  Future<void> restorePurchases() async {
    try {
      // in_app_purchase paketi eklendiğinde:
      // await InAppPurchase.instance.restorePurchases();
      
      // Demo mod
      await _loadPurchaseState();
      debugPrint('Purchases restored');
    } catch (e) {
      debugPrint('Restore purchases error: $e');
    }
  }

  /// Satın alma işlemi bittiğinde (stream listener)
  void _onPurchaseUpdated(List<dynamic> purchaseDetailsList) {
    // in_app_purchase paketi eklendiğinde implement edilecek
    /*
    for (final PurchaseDetails purchase in purchaseDetailsList) {
      if (purchase.status == PurchaseStatus.pending) {
        // Bekleniyor
      } else if (purchase.status == PurchaseStatus.error) {
        // Hata
      } else if (purchase.status == PurchaseStatus.purchased ||
                 purchase.status == PurchaseStatus.restored) {
        // Başarılı - ürünü ver ve onayla
        _deliverProduct(purchase);
      }
      
      if (purchase.pendingCompletePurchase) {
        InAppPurchase.instance.completePurchase(purchase);
      }
    }
    */
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

  /// Belirli bir ürünü al
  ProductInfo? getProduct(String productId) =>
      _products.where((p) => p.id == productId).firstOrNull;
}
