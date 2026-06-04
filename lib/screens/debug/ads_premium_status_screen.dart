import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../../services/ad_service.dart';
import '../../services/purchase_service.dart';
import '../../services/shop_service.dart';

class AdsPremiumStatusScreen extends StatefulWidget {
  const AdsPremiumStatusScreen({super.key});

  @override
  State<AdsPremiumStatusScreen> createState() => _AdsPremiumStatusScreenState();
}

class _AdsPremiumStatusScreenState extends State<AdsPremiumStatusScreen> {
  late Future<void> _loadDataFuture;

  @override
  void initState() {
    super.initState();
    _loadDataFuture = _loadData();
  }

  Future<void> _loadData() async {
    // Tüm durumları kontrol et
    await Future.delayed(const Duration(milliseconds: 500));
    setState(() {});
  }

  Future<void> _testInterstitialAd() async {
    final success = await AdService.instance.showInterstitialAd();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(success ? 'Reklam Başarıyla Gösterildi' : 'Reklam Gösterilemedi')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reklam & Premium Kontrol')),
      body: FutureBuilder<void>(
        future: _loadDataFuture,
        builder: (context, snapshot) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Ad Service Durumu
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '🎬 Reklam Servisi Durumu',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 12),
                        _buildStatusTile('Premium Durum', AdService.instance.isPremium),
                        _buildStatusTile('Reklam Gösterilebilir', AdService.instance.canShowAds),
                        _buildStatusTile('Test Modu', AdService.instance.isTestMode),
                        const SizedBox(height: 12),
                        _buildInfoTile(
                          'Banner Ad ID',
                          AdService.instance.bannerAdUnitId,
                        ),
                        _buildInfoTile(
                          'Interstitial Ad ID',
                          AdService.instance.interstitialAdUnitId,
                        ),
                        _buildInfoTile(
                          'Rewarded Ad ID',
                          AdService.instance.rewardedAdUnitId,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Purchase Service Durumu
                FutureBuilder<int>(
                  future: Future.value(0), // Dummy, sadece rebuild için
                  builder: (context, _) {
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '💳 Satın Alma Servisi Durumu',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 12),
                            _buildStatusTile('Premium Satın Alındı', PurchaseService.instance.isPremium),
                            _buildStatusTile('Reklamlar Kaldırıldı', PurchaseService.instance.hasRemovedAds),
                            const SizedBox(height: 12),
                            if (PurchaseService.instance.premiumExpiryDate != null)
                              _buildInfoTile(
                                'Premium Bitiş Tarihi',
                                PurchaseService.instance.premiumExpiryDate!.toString(),
                              ),
                            const SizedBox(height: 12),
                            Text('Ürünler: ${PurchaseService.instance.products.length} yüklendi'),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),

                // Shop Service Durumu
                FutureBuilder<String>(
                  future: Future.value(''),
                  builder: (context, _) {
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '🏪 Shop Servisi Durumu',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 12),
                            FutureBuilder<int>(
                              future: ShopService.instance.getCoins(),
                              builder: (context, snapshot) {
                                final coins = snapshot.data ?? 0;
                                return _buildInfoTile('Altın', '$coins');
                              },
                            ),
                            FutureBuilder<List<String>>(
                              future: ShopService.instance.getUsedPromoCodes(),
                              builder: (context, snapshot) {
                                final codes = snapshot.data ?? [];
                                return _buildInfoTile('Kullanılan Kodlar', codes.join(', '));
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),

                // Environment Variables
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '🔧 Ortam Değişkenleri (.env)',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 12),
                        _buildInfoTile(
                          'ADMOB_BANNER_ID',
                          dotenv.get('ADMOB_BANNER_ID', fallback: '(tanımlanmadı)'),
                        ),
                        _buildInfoTile(
                          'ADMOB_INTERSTITIAL_ID',
                          dotenv.get('ADMOB_INTERSTITIAL_ID', fallback: '(tanımlanmadı)'),
                        ),
                        _buildInfoTile(
                          'ADMOB_REWARDED_ID',
                          dotenv.get('ADMOB_REWARDED_ID', fallback: '(tanımlanmadı)'),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Test Butonları
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '⚙️ Test İşlemleri',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          onPressed: _testInterstitialAd,
                          icon: const Icon(Icons.play_arrow),
                          label: const Text('Geçiş Reklamını Test Et'),
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton.icon(
                          onPressed: () {
                            AdService.instance.setPremiumStatus(true);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Premium Aktifleştirildi (Test)')),
                            );
                            setState(() {});
                          },
                          icon: const Icon(Icons.star),
                          label: const Text('Premium Aktifleştir (Test)'),
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton.icon(
                          onPressed: () {
                            AdService.instance.setPremiumStatus(false);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Premium Devreden Çıkarıldı (Test)')),
                            );
                            setState(() {});
                          },
                          icon: const Icon(Icons.cancel),
                          label: const Text('Premium Kaldır (Test)'),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // Açıklama
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '📋 Sistem Açıklaması',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 8),
                      Text(
                        '• Reklam Gösterimi: Her 4 oturum (40 soru) bittiğinde geçiş reklamı gösterilir\n'
                        '• Premium Özellik: Premium üyelerin reklamları görmez\n'
                        '• Reklamları Kaldır: "Reklamları Kaldır" paketi satın alıp premium gibi davranır\n'
                        '• Satın Alma Senkronizasyonu: Satın alma sonrası otomatik AdService güncellenır',
                        style: TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatusTile(String label, bool value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: value ? Colors.green : Colors.red,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              value ? '✓ Aktif' : '✗ İnaktif',
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoTile(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Text(
              value.isEmpty ? '(boş)' : value,
              style: const TextStyle(fontSize: 11, fontFamily: 'Courier'),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
