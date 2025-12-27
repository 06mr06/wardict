import 'package:flutter/material.dart';
import '../../models/powerup.dart';
import '../../models/premium.dart';
import '../../services/shop_service.dart';

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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    final coins = await ShopService.instance.getCoins();
    final inventory = await ShopService.instance.getInventory();
    final subscription = await ShopService.instance.getSubscription();
    
    if (mounted) {
      setState(() {
        _userCoins = coins;
        _inventory = inventory;
        _subscription = subscription;
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
            colors: [Color(0xFF1a1a2e), Color(0xFF16213e)],
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
                  color: Colors.white.withValues(alpha: 0.1),
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
                  color: const Color(0xFFFFD700).withValues(alpha: 0.3),
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
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
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

  Widget _buildPowerupCard(PowerupType powerup) {
    final canAfford = _userCoins >= powerup.price;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white.withValues(alpha: 0.1),
            Colors.white.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          // Emoji
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: const Color(0xFF6C27FF).withValues(alpha: 0.2),
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
                    color: Colors.white.withValues(alpha: 0.6),
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
                color: canAfford ? null : Colors.grey.withValues(alpha: 0.3),
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
              ? [const Color(0xFFFFD700).withValues(alpha: 0.2), const Color(0xFFFFA000).withValues(alpha: 0.1)]
              : [Colors.white.withValues(alpha: 0.1), Colors.white.withValues(alpha: 0.05)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: pkg.isBestValue ? const Color(0xFFFFD700) : Colors.white.withValues(alpha: 0.2),
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
                    color: Colors.white.withValues(alpha: 0.6),
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
                  const Color(0xFF6C27FF).withValues(alpha: 0.3),
                  const Color(0xFF2AA7FF).withValues(alpha: 0.1),
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
                          color: Colors.white.withValues(alpha: 0.6),
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
              ? [const Color(0xFFFFD700).withValues(alpha: 0.2), const Color(0xFFFFA000).withValues(alpha: 0.1)]
              : [Colors.white.withValues(alpha: 0.1), Colors.white.withValues(alpha: 0.05)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isHighlighted ? const Color(0xFFFFD700) : Colors.white.withValues(alpha: 0.2),
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
                        color: Colors.white.withValues(alpha: 0.6),
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
                color: Colors.white.withValues(alpha: 0.8),
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
    // TODO: In-app purchase entegrasyonu
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${pkg.totalCoins} coin satın alınacak: \$${pkg.priceUSD}'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  Future<void> _subscribeToPremium(PremiumTier tier) async {
    // TODO: Subscription entegrasyonu
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${tier.name} aboneliği: \$${tier.monthlyPriceUSD}/ay'),
        backgroundColor: Colors.purple,
      ),
    );
  }
}
