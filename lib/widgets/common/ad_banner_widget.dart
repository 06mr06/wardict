import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../services/ad_service.dart';
import '../../services/shop_service.dart';
import '../../models/premium.dart';

// google_mobile_ads sadece mobil platformlarda çalışır
import 'package:google_mobile_ads/google_mobile_ads.dart'
    if (dart.library.html) 'ad_banner_web_stub.dart'
    if (dart.library.js_util) 'ad_banner_web_stub.dart';

/// Oyun sonu ekranlarında gösterilecek banner reklam widget'ı
/// Chess.com tarzında alt kısımda sabit banner
class AdBannerWidget extends StatefulWidget {
  final double height;
  final bool showCloseButton;
  final bool isMediumRectangle; // Chess.com benzeri büyük reklam (300x250)
  
  const AdBannerWidget({
    super.key,
    this.height = 60,
    this.showCloseButton = false,
    this.isMediumRectangle = false,
  });

  @override
  State<AdBannerWidget> createState() => _AdBannerWidgetState();
}

class _AdBannerWidgetState extends State<AdBannerWidget> {
  BannerAd? _bannerAd;
  bool _isLoaded = false;
  bool _isClosed = false;
  bool _isPremium = false;

  @override
  void initState() {
    super.initState();
    _checkPremiumAndLoadAd();
  }

  Future<void> _checkPremiumAndLoadAd() async {
    // Web platformunda reklam gösterme
    if (kIsWeb) {
      return;
    }
    
    // Premium durumunu kontrol et
    final subscription = await ShopService.instance.getSubscription();
    if (subscription.tier != PremiumTier.free) {
      if (mounted) {
        setState(() {
          _isPremium = true;
        });
      }
      return;
    }
    
    _loadBannerAd();
  }

  void _loadBannerAd() {
    // Web'de çalışmaz
    if (kIsWeb) return;
    
    // Eğer isMediumRectangle ise 300x250, değilse standart banner (320x50) kullan
    final adSize = widget.isMediumRectangle ? AdSize.mediumRectangle : AdSize.banner;
    
    _bannerAd = BannerAd(
      adUnitId: AdService.instance.bannerAdUnitId,
      size: adSize,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (mounted) {
            setState(() {
              _isLoaded = true;
            });
          }
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('Banner ad failed to load: $error');
          ad.dispose();
        },
      ),
    );

    _bannerAd?.load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  void _closeAd() {
    setState(() {
      _isClosed = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Web'de gerçek reklam yerine placeholder göster (Test amaçlı)
    if (kIsWeb) {
      return Container(
        width: widget.isMediumRectangle ? 300 : double.infinity,
        height: widget.isMediumRectangle ? 250 : widget.height,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white10,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white24, width: 1),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.ads_click, color: Colors.white24),
            const SizedBox(height: 8),
            Text(
              'AD SPACE (${widget.isMediumRectangle ? "300x250" : "BANNER"})',
              style: const TextStyle(color: Colors.white24, fontSize: 10, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      );
    }
    
    // Premium kullanıcı veya kapatıldıysa gösterme
    if (_isPremium || _isClosed) {
      return const SizedBox.shrink();
    }

    // Standart banner yüksekliği
    final double adHeight = widget.height;

    // Reklam yüklenmediyse yer kaplamasın (SizedBox.shrink döndür)
    if (!_isLoaded || _bannerAd == null) {
      return const SizedBox.shrink();
    }

    // Medium Rectangle için özel yükseklik veya standart banner yüksekliği
    final double realAdHeight = widget.isMediumRectangle ? 250 : widget.height;

    // Gerçek reklam widget'ı
    return Container(
      width: widget.isMediumRectangle ? 300 : double.infinity,
      height: realAdHeight,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Center(child: AdWidget(ad: _bannerAd!)),
          ),
          if (widget.showCloseButton)
            Positioned(
              right: 4,
              top: 4,
              child: GestureDetector(
                onTap: _closeAd,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close,
                    color: Colors.white70,
                    size: 14,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showPremiumDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A3A5C),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.star, color: Colors.amber),
            SizedBox(width: 8),
            Text(
              'Premium Ol',
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Premium üyelikle şu avantajlara sahip ol:',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 12),
            _buildPremiumFeature('Reklamsız deneyim'),
            _buildPremiumFeature('Özel avatarlar'),
            _buildPremiumFeature('2x puan kazanma'),
            _buildPremiumFeature('Sınırsız tekrar'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Daha Sonra', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Premium sayfasına yönlendir
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber,
              foregroundColor: Colors.black,
            ),
            child: const Text('Premium\'a Geç'),
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumFeature(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: Colors.green, size: 18),
          const SizedBox(width: 8),
          Text(text, style: const TextStyle(color: Colors.white)),
        ],
      ),
    );
  }
}
