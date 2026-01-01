import 'package:flutter/material.dart';
import '../../models/powerup.dart';
import '../../models/premium.dart';
import '../../models/cosmetic_item.dart';
import '../../services/shop_service.dart';
import '../../services/ad_service.dart';
import '../../services/purchase_service.dart';
import '../../services/user_profile_service.dart';

class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key});

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _userCoins = 0;
  PowerupInventory _inventory = const PowerupInventory();
  PremiumSubscription _subscription = const PremiumSubscription();
  List<String> _unlockedCosmetics = [];
  Map<CosmeticType, String?> _selectedCosmetics = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    final coins = await ShopService.instance.getCoins();
    final inventory = await ShopService.instance.getInventory();
    final subscription = await ShopService.instance.getSubscription();
    final unlocked = await ShopService.instance.getUnlockedCosmetics();
    
    Map<CosmeticType, String?> selected = {};
    for (final type in CosmeticType.values) {
      selected[type] = await ShopService.instance.getSelectedCosmetic(type);
    }
    
    if (mounted) {
      setState(() {
        _userCoins = coins;
        _inventory = inventory;
        _subscription = subscription;
        _unlockedCosmetics = unlocked;
        _selectedCosmetics = selected;
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF2E5A8C), Color(0xFF1A3A5C)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header with coins
              _buildHeader(),
              
              // Tab bar
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicator: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6C27FF), Color(0xFF2AA7FF)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white60,
                  dividerColor: Colors.transparent,
                  tabs: const [
                    Tab(text: 'Powerups'),
                    Tab(text: 'Özelleştir'),
                    Tab(text: 'Coinler'),
                    Tab(text: 'Premium'),
                  ],
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Tab content
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildPowerupsTab(),
                    _buildCustomizeTab(),
                    _buildCoinsTab(),
                    _buildPremiumTab(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          ),
          const Text(
            'Market',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          // Coin balance
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFFD700), Color(0xFFFFA000)],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFFD700).withOpacity(0.3),
                  blurRadius: 10,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🪙', style: TextStyle(fontSize: 18)),
                const SizedBox(width: 6),
                Text(
                  '$_userCoins',
                  style: const TextStyle(
                    color: Colors.black87,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPowerupsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Inventory section
        if (_inventory.items.isNotEmpty) ...[
          const Text(
            'Envanterim',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _inventory.items.entries.map((e) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(0.2)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(e.key.emoji, style: const TextStyle(fontSize: 20)),
                    const SizedBox(width: 6),
                    Text(
                      'x${e.value}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
        ],
        
        // Reklam izle bölümü
        _buildWatchAdSection(),
        const SizedBox(height: 24),
        
        // Shop items
        const Text(
          'Satın Al',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        ...PowerupType.values.map((powerup) => _buildPowerupCard(powerup)),
      ],
    );
  }
  
  Widget _buildWatchAdSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF4CAF50).withOpacity(0.2),
            const Color(0xFF8BC34A).withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF4CAF50).withOpacity(0.5)),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: const Color(0xFF4CAF50).withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: Icon(Icons.play_circle_fill, color: Colors.white, size: 30),
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Reklam İzle',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Kısa bir reklam izleyerek altın kazan!',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: _watchAdForCoins,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF4CAF50), Color(0xFF8BC34A)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.videocam, color: Colors.white, size: 18),
                  SizedBox(width: 6),
                  Text('🪙', style: TextStyle(fontSize: 14)),
                  SizedBox(width: 2),
                  Text(
                    '+25',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Future<void> _watchAdForCoins() async {
    // Loading dialog göster
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2E5A8C),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.play_circle_fill, color: Color(0xFF4CAF50), size: 60),
            SizedBox(height: 16),
            Text(
              'Reklam Yükleniyor...',
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
            SizedBox(height: 16),
            CircularProgressIndicator(color: Color(0xFF4CAF50)),
          ],
        ),
      ),
    );
    
    // AdService üzerinden ödüllü reklam göster
    final reward = await AdService.instance.showRewardedAd(defaultReward: 25);
    
    if (mounted) {
      Navigator.pop(context);
      
      if (reward > 0) {
        // Ödül kazanıldı
        await ShopService.instance.addCoins(reward);
        await _loadData();
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Text('🪙', style: TextStyle(fontSize: 18)),
                const SizedBox(width: 8),
                Text('+$reward altın kazandınız!'),
              ],
            ),
            backgroundColor: const Color(0xFF4CAF50),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        // Reklam başarısız oldu
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Reklam yüklenemedi. Lütfen tekrar deneyin.'),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  /// Gerçek para ile coin satın alma
  Future<void> _purchaseCoins(ProductInfo product) async {
    // Satın alma onay dialogu
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2E5A8C),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          product.title,
          style: const TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🪙', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 12),
            Text(
              product.description,
              style: const TextStyle(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                product.price,
                style: const TextStyle(
                  color: Colors.amber,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İptal', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4CAF50),
            ),
            child: const Text('Satın Al'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    // Yükleniyor göster
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        backgroundColor: Color(0xFF2E5A8C),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 16),
            Text('İşlem yapılıyor...', style: TextStyle(color: Colors.white)),
          ],
        ),
      ),
    );

    // Satın alma işlemi
    final result = await PurchaseService.instance.purchase(product.id);

    if (mounted) {
      Navigator.pop(context);

      if (result.success && product.coinAmount != null) {
        await ShopService.instance.addCoins(product.coinAmount!);
        await _loadData();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Text('🎉', style: TextStyle(fontSize: 18)),
                const SizedBox(width: 8),
                Text('+${product.coinAmount} altın eklendi!'),
              ],
            ),
            backgroundColor: const Color(0xFF4CAF50),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else if (!result.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.errorMessage ?? 'Satın alma başarısız'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Widget _buildPowerupCard(PowerupType powerup) {
    final canAfford = _userCoins >= powerup.price;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(0.1),
            Colors.white.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          // Emoji
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: const Color(0xFF6C27FF).withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(powerup.emoji, style: const TextStyle(fontSize: 24)),
            ),
          ),
          const SizedBox(width: 12),
          
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  powerup.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  powerup.description,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          
          // Buy button
          GestureDetector(
            onTap: canAfford ? () => _buyPowerup(powerup) : null,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                gradient: canAfford
                    ? const LinearGradient(
                        colors: [Color(0xFFFFD700), Color(0xFFFFA000)],
                      )
                    : null,
                color: canAfford ? null : Colors.grey.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🪙', style: TextStyle(fontSize: 14)),
                  const SizedBox(width: 4),
                  Text(
                    '${powerup.price}',
                    style: TextStyle(
                      color: canAfford ? Colors.black87 : Colors.white38,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCoinsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: CoinPackage.packages.map((pkg) => _buildCoinPackageCard(pkg)).toList(),
    );
  }

  Widget _buildCoinPackageCard(CoinPackage pkg) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: pkg.isBestValue
              ? [const Color(0xFFFFD700).withOpacity(0.2), const Color(0xFFFFA000).withOpacity(0.1)]
              : [Colors.white.withOpacity(0.1), Colors.white.withOpacity(0.05)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: pkg.isBestValue ? const Color(0xFFFFD700) : Colors.white.withOpacity(0.2),
          width: pkg.isBestValue ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          // Coin stack
          Column(
            children: [
              const Text('🪙', style: TextStyle(fontSize: 32)),
              if (pkg.isBestValue)
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFD700),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'EN İYİ',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 16),
          
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '${pkg.coins}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (pkg.bonusCoins != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.green,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '+${pkg.bonusCoins} BONUS',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                Text(
                  'Coin',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          
          // Price button
          GestureDetector(
            onTap: () => _buyCoinPackage(pkg),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF2AA7FF), Color(0xFF6C27FF)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '\$${pkg.priceUSD.toStringAsFixed(2)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Current status
        if (_subscription.tier != PremiumTier.free)
          Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF6C27FF).withOpacity(0.3),
                  const Color(0xFF2AA7FF).withOpacity(0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF6C27FF)),
            ),
            child: Row(
              children: [
                const Icon(Icons.star, color: Color(0xFFFFD700), size: 32),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${_subscription.tier.name} Üye',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${_subscription.daysRemaining} gün kaldı',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        
        // Premium tier
        _buildPremiumTierCard(
          tier: PremiumTier.premium,
          features: [
            '📸 Profil fotoğrafı yükleme',
            '🎮 Sınırsız duel',
            '🚫 Reklamsız deneyim',
            '🏆 Liderlik tablosu rozeti',
            '📊 İstatistik dışa aktarma',
          ],
        ),
        const SizedBox(height: 16),
        
        // VIP tier
        _buildPremiumTierCard(
          tier: PremiumTier.vip,
          features: [
            '✨ Tüm Premium özellikleri',
            '⚡ Özel VIP powerup\'lar',
            '🎨 Özel temalar',
            '⏱️ Öncelikli eşleşme',
            '📱 Çevrimdışı mod',
          ],
          isHighlighted: true,
        ),
      ],
    );
  }

  Widget _buildPremiumTierCard({
    required PremiumTier tier,
    required List<String> features,
    bool isHighlighted = false,
  }) {
    final isCurrentTier = _subscription.tier == tier;
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isHighlighted
              ? [const Color(0xFFFFD700).withOpacity(0.2), const Color(0xFFFFA000).withOpacity(0.1)]
              : [Colors.white.withOpacity(0.1), Colors.white.withOpacity(0.05)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isHighlighted ? const Color(0xFFFFD700) : Colors.white.withOpacity(0.2),
          width: isHighlighted ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                tier == PremiumTier.vip ? '👑' : '⭐',
                style: const TextStyle(fontSize: 28),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tier.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '\$${tier.monthlyPriceUSD.toStringAsFixed(2)}/ay',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              if (isHighlighted)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFD700),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'ÖNERİLEN',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Features
          ...features.map((f) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(
              f,
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 14,
              ),
            ),
          )),
          
          const SizedBox(height: 16),
          
          // Subscribe button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: isCurrentTier ? null : () => _subscribeToPremium(tier),
              style: ElevatedButton.styleFrom(
                backgroundColor: isCurrentTier 
                    ? Colors.grey 
                    : (isHighlighted ? const Color(0xFFFFD700) : const Color(0xFF6C27FF)),
                foregroundColor: isHighlighted ? Colors.black87 : Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(
                isCurrentTier ? 'Mevcut Plan' : 'Abone Ol',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomizeTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Görünümünü Özelleştir',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Profilini unvanlar ve çerçevelerle süsle',
          style: TextStyle(
            color: Colors.white.withOpacity(0.6),
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 16),
        ...CosmeticItem.availableItems.map((item) => _buildCosmeticCard(item)),
      ],
    );
  }

  Widget _buildCosmeticCard(CosmeticItem item) {
    final isUnlocked = _unlockedCosmetics.contains(item.id);
    final isSelected = _selectedCosmetics[item.type] == item.id;
    final canAfford = _userCoins >= item.price;
    final isLockedPremium = item.isPremiumOnly && _subscription.tier == PremiumTier.free;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFF6C27FF).withOpacity(0.1) : Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected ? const Color(0xFF6C27FF) : (isUnlocked ? Colors.green.withOpacity(0.5) : Colors.white.withOpacity(0.1)),
          width: isSelected ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          // Preview container
          Stack(
            children: [
              Builder(
                builder: (context) {
                  // Frame için renk hesaplama
                  Color? frameColor;
                  Gradient? frameGradient;
                  if (item.type == CosmeticType.frame) {
                    if (item.previewValue == 'gradient') {
                      frameGradient = const LinearGradient(
                        colors: [Colors.red, Colors.orange, Colors.yellow, Colors.green, Colors.blue, Colors.purple],
                      );
                    } else {
                      // Hex değerinin valid olup olmadığını kontrol et
                      final hexRegex = RegExp(r'^[0-9a-fA-F]{6}$');
                      if (hexRegex.hasMatch(item.previewValue)) {
                        frameColor = Color(int.parse('FF${item.previewValue}', radix: 16));
                      } else {
                        frameColor = Colors.white;
                      }
                    }
                  }
                  
                  return Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      gradient: item.type == CosmeticType.frame ? frameGradient : null,
                      border: item.type == CosmeticType.frame && frameColor != null
                          ? Border.all(color: frameColor, width: 3)
                          : null,
                    ),
                    child: Center(
                      child: item.type == CosmeticType.title
                          ? const Icon(Icons.title, color: Colors.white)
                          : (item.type == CosmeticType.frame 
                              ? null  // Frame için içerik yok
                              : Text(item.previewValue, style: const TextStyle(fontSize: 28))),
                    ),
                  );
                },
              ),
              if (isUnlocked)
                Positioned(
                  right: -2,
                  top: -2,
                  child: Container(
                    decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                    child: const Icon(Icons.check_circle, color: Colors.green, size: 20),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 16),
          
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      item.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (item.isPremiumOnly) ...[
                      const SizedBox(width: 4),
                      const Icon(Icons.star, color: Color(0xFFFFD700), size: 14),
                    ],
                  ],
                ),
                Text(
                  item.description,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          
          // Action button
          if (isUnlocked)
            ElevatedButton(
              onPressed: isSelected ? null : () => _selectCosmetic(item),
              style: ElevatedButton.styleFrom(
                backgroundColor: isSelected ? Colors.green : const Color(0xFF6C27FF),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text(isSelected ? 'Seçili' : 'Kullan'),
            )
          else
            GestureDetector(
              onTap: (canAfford && !isLockedPremium) ? () => _buyCosmetic(item) : null,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  gradient: (canAfford && !isLockedPremium)
                      ? const LinearGradient(colors: [Color(0xFFFFD700), Color(0xFFFFA000)])
                      : null,
                  color: (canAfford && !isLockedPremium) ? null : Colors.grey.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Text('🪙', style: TextStyle(fontSize: 14)),
                    const SizedBox(width: 4),
                    Text(
                      '${item.price}',
                      style: TextStyle(
                        color: (canAfford && !isLockedPremium) ? Colors.black87 : Colors.white38,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _buyCosmetic(CosmeticItem item) async {
    final success = await ShopService.instance.buyCosmetic(item);
    if (success) {
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${item.name} başarıyla satın alındı! ✨'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  Future<void> _selectCosmetic(CosmeticItem item) async {
    await ShopService.instance.setSelectedCosmetic(item.id, item.type);
    
    // Avatar seçildiyse profil fotoğrafını da güncelle
    if (item.type == CosmeticType.avatar) {
      await UserProfileService.instance.updateAvatar(item.id);
    }
    
    await _loadData();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${item.name} seçildi!'),
          backgroundColor: Colors.blue,
        ),
      );
    }
  }

  Future<void> _buyPowerup(PowerupType powerup) async {
    final success = await ShopService.instance.buyPowerup(powerup);
    if (success) {
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${powerup.emoji} ${powerup.name} satın alındı!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Satın alma başarısız'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _buyCoinPackage(CoinPackage pkg) async {
    // PurchaseService üzerinden ürün bul
    final products = PurchaseService.instance.coinProducts;
    final matchingProduct = products.where((p) => 
      p.coinAmount != null && p.coinAmount! >= pkg.coins
    ).firstOrNull;

    if (matchingProduct != null) {
      await _purchaseCoins(matchingProduct);
    } else {
      // Fallback - eski simülasyon
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF2E5A8C),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            '${pkg.totalCoins} Altın',
            style: const TextStyle(color: Colors.white),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🪙', style: TextStyle(fontSize: 48)),
              const SizedBox(height: 12),
              Text(
                '\$${pkg.priceUSD.toStringAsFixed(2)}',
                style: const TextStyle(
                  color: Colors.amber,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('İptal', style: TextStyle(color: Colors.white70)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4CAF50),
              ),
              child: const Text('Satın Al'),
            ),
          ],
        ),
      );

      if (confirm == true && mounted) {
        // Demo satın alma
        await ShopService.instance.addCoins(pkg.totalCoins);
        await _loadData();
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('🎉 +${pkg.totalCoins} altın eklendi!'),
            backgroundColor: const Color(0xFF4CAF50),
          ),
        );
      }
    }
  }

  Future<void> _subscribeToPremium(PremiumTier tier) async {
    // PurchaseService üzerinden abonelik ürünü bul
    final products = PurchaseService.instance.subscriptionProducts;
    final productId = tier == PremiumTier.premium 
        ? PurchaseService.premiumMonthlyId 
        : PurchaseService.premiumYearlyId;
    
    final product = products.where((p) => p.id == productId).firstOrNull;

    if (product != null) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF2E5A8C),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            product.title,
            style: const TextStyle(color: Colors.white),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('⭐', style: TextStyle(fontSize: 48)),
              const SizedBox(height: 12),
              Text(
                product.description,
                style: const TextStyle(color: Colors.white70),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                product.price,
                style: const TextStyle(
                  color: Colors.amber,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('İptal', style: TextStyle(color: Colors.white70)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6C27FF),
              ),
              child: const Text('Abone Ol'),
            ),
          ],
        ),
      );

      if (confirm != true) return;

      // Yükleniyor göster
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          backgroundColor: Color(0xFF2E5A8C),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Colors.white),
              SizedBox(height: 16),
              Text('İşlem yapılıyor...', style: TextStyle(color: Colors.white)),
            ],
          ),
        ),
      );

      final result = await PurchaseService.instance.purchase(product.id);

      if (mounted) {
        Navigator.pop(context);

        if (result.success) {
          // Abonelik durumunu güncelle
          await _loadData();
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Text('🎉', style: TextStyle(fontSize: 18)),
                  const SizedBox(width: 8),
                  Text('${tier.name} aboneliği aktif!'),
                ],
              ),
              backgroundColor: const Color(0xFF6C27FF),
              behavior: SnackBarBehavior.floating,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.errorMessage ?? 'Abonelik başarısız'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } else {
      // Fallback
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${tier.name} aboneliği: \$${tier.monthlyPriceUSD}/ay'),
          backgroundColor: Colors.purple,
        ),
      );
    }
  }
}
