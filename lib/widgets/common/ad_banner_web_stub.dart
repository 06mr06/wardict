// Web platformu için stub dosyası
// google_mobile_ads web'de desteklenmediği için boş sınıflar

import 'package:flutter/widgets.dart';

class BannerAd {
  final String adUnitId;
  final AdSize size;
  final AdRequest request;
  final BannerAdListener listener;

  BannerAd({
    required this.adUnitId,
    required this.size,
    required this.request,
    required this.listener,
  });

  void load() {}
  void dispose() {}
}

class AdSize {
  final int width;
  final int height;

  const AdSize({required this.width, required this.height});

  static const AdSize banner = AdSize(width: 320, height: 50);
  static const AdSize mediumRectangle = AdSize(width: 300, height: 250);
}

class AdRequest {
  const AdRequest();
}

class BannerAdListener {
  final Function(dynamic)? onAdLoaded;
  final Function(dynamic, dynamic)? onAdFailedToLoad;

  const BannerAdListener({
    this.onAdLoaded,
    this.onAdFailedToLoad,
  });
}

class AdWidget extends StatelessWidget {
  final dynamic ad;
  const AdWidget({super.key, required this.ad});
  
  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
