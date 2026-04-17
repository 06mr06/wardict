import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:confetti/confetti.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/sound_service.dart';
import '../../models/powerup.dart';
import '../../models/premium.dart';
import '../../models/cosmetic_item.dart';
import '../../services/shop_service.dart';
import '../../services/ad_service.dart';
import '../../services/purchase_service.dart';
import '../../services/user_profile_service.dart';
import 'package:provider/provider.dart';
import '../../providers/language_provider.dart';

class ShopScreen extends StatefulWidget {
  final int initialTabIndex;
  final bool scrollToFrames;
  
  const ShopScreen({super.key, this.initialTabIndex = 2, this.scrollToFrames = false});

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ScrollController _customizeScrollController = ScrollController();
  final GlobalKey _framesKey = GlobalKey();
  late ConfettiController _confettiController;
  int _userCoins = 0;
  PowerupInventory _inventory = const PowerupInventory();
  PremiumSubscription _subscription = const PremiumSubscription();
  List<String> _unlockedCosmetics = [];
  Map<CosmeticType, String?> _selectedCosmetics = {};
  List<String> _unlockedPacks = [];
  bool _starterPackClaimed = false;
  StreamSubscription<PurchaseEvent>? _purchaseSub;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 1));
    _tabController = TabController(length: 5, vsync: this, initialIndex: widget.initialTabIndex);
    
    // Satın alma akışı dinleyicisi
    _purchaseSub = PurchaseService.instance.events.listen((event) {
      if (!mounted) return;
      _handlePurchaseEvent(event);
    });

    _loadData().then((_) {
      if (widget.scrollToFrames && widget.initialTabIndex == 2) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollToFrames();
        });
      }
    });
  }

  void _scrollToFrames() {
    // Biraz gecikme ekleyerek sayfanın tamamen render olduğundan emin olalım (lazy-loading için önemli)
    for (int delay in [500, 1000, 1500]) {
      Future.delayed(Duration(milliseconds: delay), () {
        if (!mounted) return;
        final ctx = _framesKey.currentContext;
        if (ctx != null) {
          Scrollable.ensureVisible(
            ctx,
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeInOut,
          );
        }
      });
    }
  }

  Future<void> _loadData() async {
    // Önce Firebase'den senkronize et (Coin doğruluğu için)
    await UserProfileService.instance.fetchProfileFromFirestore();
    
    final coins = await ShopService.instance.getCoins();
    final inventory = await ShopService.instance.getInventory();
    final subscription = await ShopService.instance.getSubscription();
    final unlockedCosmetics = await ShopService.instance.getUnlockedCosmetics();
    final selectedCosmetics = await ShopService.instance.getSelectedCosmetics(); // Simplified call
    final packs = await ShopService.instance.getUnlockedPacks(); // Retained from original
    final prefs = await SharedPreferences.getInstance();
    final starterClaimed = prefs.getBool('starter_pack_claimed') ?? false;

    if (mounted) {
      setState(() {
        _userCoins = coins;
        _inventory = inventory;
        _subscription = subscription;
        _unlockedCosmetics = unlockedCosmetics;
        _selectedCosmetics = selectedCosmetics;
        _unlockedPacks = packs; // Retained from original
        _starterPackClaimed = starterClaimed;
        _isLoading = false;
      });
    }
  }
 
  bool _isLoading = true;
 
  String _getLocalizedPrice(String productId, String fallbackPrice) {
    final product = PurchaseService.instance.getProduct(productId);
    return product?.price ?? fallbackPrice;
  }
 
  @override
  void dispose() {
    _purchaseSub?.cancel();
    _tabController.dispose();
    _customizeScrollController.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  void _handlePurchaseEvent(PurchaseEvent event) {
    if (!mounted) return;
    
    switch (event.type) {
      case PurchaseEventType.failed:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Satın alma hatası: ${event.message ?? "Bilinmeyen hata"}'),
            backgroundColor: Colors.red.shade700,
          ),
        );
        break;
      case PurchaseEventType.canceled:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Satın alma iptal edildi.'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 2),
          ),
        );
        break;
      case PurchaseEventType.serverVerificationFailed:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sunucu onayı başarısız: ${event.message ?? ""}'),
            backgroundColor: Colors.red.shade900,
          ),
        );
        break;
      case PurchaseEventType.succeeded:
        SoundService.instance.playLevelUp();
        _confettiController.play();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🎉 Satın alma başarılı! İçerikler yüklendi.'),
            backgroundColor: Colors.green,
          ),
        );
        _loadData();
        break;
      case PurchaseEventType.restored:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Satın almalar geri yüklendi.'),
            backgroundColor: Colors.green,
          ),
        );
        _loadData();
        break;
      case PurchaseEventType.pending:
        // Loading vs gösterebiliriz, şimdilik arkada bekliyor
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              Align(
                alignment: Alignment.topCenter,
                child: ConfettiWidget(
                  confettiController: _confettiController,
                  blastDirectionality: BlastDirectionality.explosive,
                  maxBlastForce: 15,
                  minBlastForce: 10,
                  emissionFrequency: 0.1,
                  shouldLoop: false,
                  colors: const [Colors.amber, Colors.orange, Colors.yellow, Colors.blue],
                ),
              ),
              Column(
                children: [
              // Header
              _buildModernHeader(),
              
              // Custom Tab bar
              Container(
                height: 50,
                margin: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                ),
                child: Consumer<LanguageProvider>(
                  builder: (context, lp, _) => TabBar(
                    controller: _tabController,
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    indicator: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6C27FF), Color(0xFFB392FF)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF6C27FF).withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        )
                      ],
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.white54,
                    labelStyle: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13),
                    unselectedLabelStyle: GoogleFonts.outfit(fontWeight: FontWeight.w500, fontSize: 13),
                    dividerColor: Colors.transparent,
                    padding: const EdgeInsets.all(4),
                    tabs: [
                      Tab(text: lp.getString('powerups')),
                      Tab(text: lp.getString('packs')),
                      Tab(text: lp.getString('customize')),
                      Tab(text: lp.getString('coins')),
                      Tab(text: lp.getString('premium')),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Tab content
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildPowerupsTab(),
                    _buildPacksTab(),
                    _buildCustomizeTab(),
                    _buildCoinsTab(),
                    _buildPremiumTab(),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  ),
);
}

  Widget _buildModernHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 16, 20, 16),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
            ),
          ),
          const SizedBox(width: 4),
          Text(
            context.read<LanguageProvider>().getString('market').toUpperCase(),
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
            ),
          ),
          const Spacer(),
          // Coin balance
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.amber.withValues(alpha: 0.2)),
              boxShadow: [
                BoxShadow(
                  color: Colors.amber.withValues(alpha: 0.05),
                  blurRadius: 10,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🪙', style: TextStyle(fontSize: 18)),
                const SizedBox(width: 8),
                Text(
                  '$_userCoins',
                  style: GoogleFonts.firaCode(
                    color: Colors.amber,
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
          children: PowerupType.values.map((type) {
            final count = _inventory.getCount(type);
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(26),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withAlpha(51)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(type.emoji, style: const TextStyle(fontSize: 20)),
                  const SizedBox(width: 6),
                  Text(
                    'x$count',
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
        
        // Seri Koruma özel bölümü
        _buildStreakShieldSection(),
        const SizedBox(height: 24),
        
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
        ...PowerupType.values.where((p) => p != PowerupType.streakShield).map((powerup) => _buildPowerupCard(powerup)),
      ],
    );
  }

  Widget _buildStreakShieldSection() {
    return FutureBuilder<DateTime?>(
      future: ShopService.instance.getStreakShieldExpiry(),
      builder: (context, snapshot) {
        final expiry = snapshot.data;
        final isActive = expiry != null;
        final remainingDays = isActive ? expiry.difference(DateTime.now()).inDays + 1 : 0;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isActive
                  ? [const Color(0xFF4CAF50).withAlpha(77), const Color(0xFF2E7D32).withAlpha(51)]
                  : [const Color(0xFFFF9800).withAlpha(51), const Color(0xFFF57C00).withAlpha(26)],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isActive ? const Color(0xFF4CAF50).withAlpha(128) : const Color(0xFFFF9800).withAlpha(128),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: isActive 
                      ? const Color(0xFF4CAF50).withAlpha(77) 
                      : const Color(0xFFFF9800).withAlpha(77),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: Text('🛡️', style: TextStyle(fontSize: 28)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Seri Koruma',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      isActive
                          ? '✅ Aktif! $remainingDays gün kaldı'
                          : 'Kaybetsen de serin bozulmasın!',
                      style: TextStyle(
                        color: isActive ? const Color(0xFF4CAF50) : Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (!isActive)
                GestureDetector(
                  onTap: _buyStreakShield,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF9800), Color(0xFFF57C00)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('🪙', style: TextStyle(fontSize: 14)),
                        SizedBox(width: 4),
                        Text(
                          '150',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4CAF50).withAlpha(77),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    '3 Gün ✓',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _buyStreakShield() async {
    if (_userCoins < 150) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Yeterli altın yok! 🪙'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2E5A8C),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Text('🛡️', style: TextStyle(fontSize: 28)),
            SizedBox(width: 8),
            Text('Seri Koruma', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '3 gün boyunca seriler korunur!',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
            SizedBox(height: 12),
            Text(
              '• Daily123 kaybetsen de seri bozulmaz\n• Düello kaybetsen de galibiyet serisi korunur',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
            SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('🪙', style: TextStyle(fontSize: 20)),
                SizedBox(width: 4),
                Text(
                  '150 Altın',
                  style: TextStyle(color: Colors.amber, fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
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
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF9800)),
            child: const Text('Satın Al'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      final success = await ShopService.instance.buyStreakShield();
      if (success) {
        SoundService.instance.playCoinSound();
        _confettiController.play();
        await _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Text('🛡️', style: TextStyle(fontSize: 18)),
                  SizedBox(width: 8),
                  Text('Seri Koruma 3 gün aktif!'),
                ],
              ),
              backgroundColor: Color(0xFF4CAF50),
            ),
          );
        }
      }
    }
  }
  
  Widget _buildWatchAdSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF4CAF50).withAlpha(51),
            const Color(0xFF8BC34A).withAlpha(26),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF4CAF50).withAlpha(128)),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: const Color(0xFF4CAF50).withAlpha(77),
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
        await ShopService.instance.addCoins(reward, reason: 'ad_reward');
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
                color: Colors.white.withAlpha(26),
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

    // Satın alma işlemi başlatılıyor — sonucu stream'den (PurchaseEventType)
    // dinliyoruz. Sadece pending için UI bloklama yapılabilir, ama in_app_purchase
    // kendi native dialogunu göstereceği için burada dialog göstermiyoruz.
    await PurchaseService.instance.purchase(product.id);
  }

  Widget _buildPowerupCard(PowerupType powerup) {
    final canAfford = _userCoins >= powerup.price;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Row(
        children: [
          // Icon Container
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF6C27FF).withValues(alpha: 0.2),
                  const Color(0xFF6C27FF).withValues(alpha: 0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF6C27FF).withValues(alpha: 0.3)),
            ),
            child: Center(
              child: Text(powerup.emoji, style: const TextStyle(fontSize: 28)),
            ),
          ),
          const SizedBox(width: 16),
          
          // Info Section
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  powerup.name,
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  powerup.description,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.4),
                    fontSize: 12,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(width: 12),
          
          // Action Button
          GestureDetector(
            onTap: canAfford ? () => _buyPowerup(powerup) : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                gradient: canAfford
                    ? const LinearGradient(
                        colors: [Color(0xFF6C27FF), Color(0xFF8A55FF)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                color: canAfford ? null : Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                boxShadow: canAfford ? [
                  BoxShadow(
                    color: const Color(0xFF6C27FF).withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  )
                ] : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                    Text(
                    '🪙', 
                    style: TextStyle(
                      fontSize: 14,
                      color: canAfford ? Colors.white : Colors.white.withValues(alpha: 0.4),
                    )
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${powerup.price}',
                    style: GoogleFonts.firaCode(
                      color: canAfford ? Colors.white : Colors.white24,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
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
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: pkg.isBestValue ? Colors.amber.withValues(alpha: 0.5) : Colors.white.withValues(alpha: 0.1),
          width: pkg.isBestValue ? 2 : 1,
        ),
        boxShadow: [
          if (pkg.isBestValue)
            BoxShadow(
              color: Colors.amber.withValues(alpha: 0.1),
              blurRadius: 15,
              spreadRadius: 2,
            ),
        ],
      ),
      child: Row(
        children: [
          // Icon Container
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: pkg.isBestValue 
                  ? [Colors.amber.withValues(alpha: 0.2), Colors.amber.withValues(alpha: 0.05)]
                  : [Colors.white.withValues(alpha: 0.1), Colors.white.withValues(alpha: 0.05)],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Center(
              child: Text('🪙', style: TextStyle(fontSize: 32)),
            ),
          ),
          const SizedBox(width: 16),
          
          // Info Section
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (pkg.isBestValue)
                  Container(
                    margin: const EdgeInsets.only(bottom: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.amber,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'EN İYİ TEKLİF',
                      style: GoogleFonts.outfit(
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        color: Colors.black,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      '${pkg.coins}',
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'COIN',
                      style: GoogleFonts.outfit(
                        color: Colors.white38,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                if (pkg.bonusCoins != null)
                  Text(
                    '+${pkg.bonusCoins} BONUS COIN',
                    style: GoogleFonts.outfit(
                      color: Colors.greenAccent,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
              ],
            ),
          ),
          
          // Price Button
          GestureDetector(
            onTap: () => _buyCoinPackage(pkg),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: pkg.isBestValue 
                    ? [Colors.amber, Colors.orange]
                    : [const Color(0xFF2C5364), const Color(0xFF203A43)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: (pkg.isBestValue ? Colors.amber : Colors.black).withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  )
                ],
              ),
              child: Text(
                _getLocalizedPrice(pkg.id, '\$${pkg.priceUSD}'),
                style: GoogleFonts.firaCode(
                  color: pkg.isBestValue ? Colors.black : Colors.white,
                  fontWeight: FontWeight.w900,
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
                  const Color(0xFF6C27FF).withAlpha(77),
                  const Color(0xFF2AA7FF).withAlpha(26),
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
                          color: Colors.white.withAlpha(153),
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
            '⚡ Özel powerup\'lar',
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isHighlighted
              ? [const Color(0xFFFFD700).withAlpha(51), const Color(0xFFFFA000).withAlpha(26)]
              : [Colors.white.withAlpha(26), Colors.white.withAlpha(13)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isHighlighted ? const Color(0xFFFFD700) : Colors.white.withAlpha(51),
          width: isHighlighted ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                '⭐',
                style: TextStyle(fontSize: 28),
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
                      tier == PremiumTier.premium ? 'Aylık: ${tier.monthlyPriceLabel} / Yıllık: ${tier.yearlyPriceLabel}' : '',
                      style: TextStyle(
                        color: Colors.white.withAlpha(153),
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
          
          // Features - 2 columns
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 4,
              crossAxisSpacing: 8,
              childAspectRatio: 5,
            ),
            itemCount: features.length,
            itemBuilder: (context, index) {
              return Text(
                features[index],
                style: TextStyle(
                  color: Colors.white.withAlpha(204),
                  fontSize: 12,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              );
            },
          ),
          
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
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(
                isCurrentTier ? 'Mevcut Plan' : 'Abone Ol (${_getLocalizedPrice(PurchaseService.premiumMonthlyId, '99 TL')})',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ),
          if (!isCurrentTier) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => _subscribeToPremium(tier), // Logic should handle yearly vs monthly if needed
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFFFFD700)),
                  foregroundColor: const Color(0xFFFFD700),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(
                  'Yıllık Abone Ol (${_getLocalizedPrice(PurchaseService.premiumYearlyId, '799 TL')})',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCustomizeTab() {
    final avatars = CosmeticItem.availableItems.where((i) => i.type == CosmeticType.avatar).toList();
    final frames = CosmeticItem.availableItems.where((i) => i.type == CosmeticType.frame).toList();
    final titles = CosmeticItem.availableItems.where((i) => i.type == CosmeticType.title).toList();

    return ListView(
      controller: _customizeScrollController,
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Karakterler',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        ...avatars.map((item) => _buildCosmeticCard(item)),

        const SizedBox(height: 24),
        Text(
          'Çerçeveler',
          key: _framesKey,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        ...frames.map((item) => _buildCosmeticCard(item)),
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
        color: isSelected ? const Color(0xFF6C27FF).withAlpha(26) : Colors.white.withAlpha(13),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected ? const Color(0xFF6C27FF) : (isUnlocked ? Colors.green.withAlpha(128) : Colors.white.withAlpha(26)),
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
                      color: Colors.white.withAlpha(26),
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
                              : (item.previewValue.startsWith('assets/')
                                  ? Padding(
                                      padding: const EdgeInsets.all(4.0),
                                      child: Image.asset(item.previewValue, fit: BoxFit.contain),
                                    )
                                  : Text(item.previewValue, style: const TextStyle(fontSize: 28)))),
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
                    color: Colors.white.withAlpha(128),
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
          else if (isLockedPremium)
            // Premium kilitli - tıklanabilir yaparak bilgi ver
            GestureDetector(
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Bu ürün sadece Premium üyeler için! ⭐'),
                    backgroundColor: Colors.orange,
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.orange.withAlpha(51),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.orange.withAlpha(128)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.lock, color: Colors.orange, size: 14),
                    SizedBox(width: 4),
                    Text(
                      'Premium',
                      style: TextStyle(
                        color: Colors.orange,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            GestureDetector(
              onTap: canAfford ? () => _buyCosmetic(item) : null,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  gradient: canAfford
                      ? const LinearGradient(colors: [Color(0xFFFFD700), Color(0xFFFFA000)])
                      : null,
                  color: canAfford ? null : Colors.grey.withAlpha(51),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Text('🪙', style: TextStyle(fontSize: 14)),
                    const SizedBox(width: 4),
                    Text(
                      '${item.price}',
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

  Future<void> _buyCosmetic(CosmeticItem item) async {
    // Premium kontrolü UI tarafında da yap
    if (item.isPremiumOnly && _subscription.tier == PremiumTier.free) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bu ürün sadece Premium üyeler için! ⭐'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }
    
    // Coin kontrolü
    if (_userCoins < item.price) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Yeterli coin yok! 🪙'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }
    
    final success = await ShopService.instance.buyCosmetic(item);
    if (success) {
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Text('${item.name} başarıyla satın alındı! ✨'),
              ],
            ),
            backgroundColor: const Color(0xFF2E5A8C),
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Satın alma başarısız!'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _selectCosmetic(CosmeticItem item) async {
    await ShopService.instance.setSelectedCosmetic(item.id, item.type);
    
    // Avatar veya Frame seçildiyse profili de güncelle
    if (item.type == CosmeticType.avatar) {
      await UserProfileService.instance.updateAvatar(item.id);
    } else if (item.type == CosmeticType.frame) {
      await UserProfileService.instance.updateFrame(item.id);
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
      SoundService.instance.playCoinSound();
      _confettiController.play();
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Text('${powerup.emoji} ${powerup.name} satın alındı!'),
              ],
            ),
            backgroundColor: const Color(0xFF2E5A8C),
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
          title: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${pkg.coins} Altın',
                style: const TextStyle(color: Colors.white),
              ),
              if (pkg.bonusCoins != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '+${pkg.bonusCoins}',
                    style: const TextStyle(fontSize: 12, color: Colors.white),
                  ),
                ),
              ],
            ],
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
              if (pkg.bonusCoins != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Toplam: ${pkg.totalCoins} altın',
                  style: TextStyle(
                    color: Colors.white.withAlpha(179),
                    fontSize: 12,
                  ),
                ),
              ],
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
        // Demo satın alma — sunucu tarafından `iap_coinpack` olarak kayıt edilir.
        await ShopService.instance
            .addCoins(pkg.totalCoins, reason: 'iap_coinpack');
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

      // Satın alma akışı başlatılıyor.
      await PurchaseService.instance.purchase(product.id);
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

  Widget _buildPacksTab() {
    final all = PurchaseService.instance.products;
    final bundle =
        all.where((p) => p.id == PurchaseService.allPacksBundleId).firstOrNull;
    final starter = _starterPackClaimed
        ? null
        : all
            .where((p) => p.id == PurchaseService.starterPackId)
            .firstOrNull;
    final seasonPass =
        all.where((p) => p.id == PurchaseService.seasonPassId).firstOrNull;
    final packProducts = PurchaseService.instance.wordPackProducts;

    if (packProducts.isEmpty &&
        bundle == null &&
        starter == null &&
        seasonPass == null) {
      return const Center(
        child: Text(
          'Paketler yükleniyor...',
          style: TextStyle(color: Colors.white),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (starter != null &&
            (starter.offerExpiresAtMs == null ||
                starter.offerExpiresAtMs! >
                    DateTime.now().millisecondsSinceEpoch)) ...[
          _buildHighlightCard(starter, icon: Icons.rocket_launch),
          const SizedBox(height: 12),
        ],
        if (seasonPass != null) ...[
          _buildHighlightCard(seasonPass, icon: Icons.workspace_premium),
          const SizedBox(height: 12),
        ],
        if (bundle != null) ...[
          _buildHighlightCard(bundle, icon: Icons.all_inclusive),
          const SizedBox(height: 20),
        ],
        const Text(
          'Kelime Paketleri',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Özel kelime paketleri ile öğrenmeye odaklan',
          style: TextStyle(
            color: Colors.white.withAlpha(153),
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 16),
        ...packProducts.map((pkg) => _buildPackCard(pkg)),
      ],
    );
  }

  /// Öne çıkan teklif kartı (Starter / Bundle / Season Pass).
  Widget _buildHighlightCard(ProductInfo product, {required IconData icon}) {
    final hasExpiry = product.offerExpiresAtMs != null;
    final remaining = hasExpiry
        ? Duration(
            milliseconds:
                product.offerExpiresAtMs! - DateTime.now().millisecondsSinceEpoch,
          )
        : null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFB347), Color(0xFFFF6A3D)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withAlpha(80),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (product.badge != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.black.withAlpha(110),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    product.badge!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              const Spacer(),
              if (remaining != null && remaining.inSeconds > 0)
                Text(
                  _formatCountdown(remaining),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(60),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      product.description,
                      style: TextStyle(
                        color: Colors.white.withAlpha(220),
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              if (product.originalPrice != null) ...[
                Text(
                  product.originalPrice!,
                  style: TextStyle(
                    color: Colors.white.withAlpha(170),
                    fontSize: 13,
                    decoration: TextDecoration.lineThrough,
                  ),
                ),
                const SizedBox(width: 6),
              ],
              Text(
                product.price,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => _purchasePack(product),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 18, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'SATIN AL',
                    style: TextStyle(
                      color: Color(0xFFFF6A3D),
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatCountdown(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  Widget _buildPackCard(ProductInfo pkg) {
    final packId = pkg.id.replaceFirst('pack_', '');
    final isUnlocked = _unlockedPacks.contains(packId);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isUnlocked ? const Color(0xFF4CAF50).withAlpha(26) : Colors.white.withAlpha(13),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isUnlocked ? const Color(0xFF4CAF50) : Colors.white.withAlpha(26),
          width: isUnlocked ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          // Icon
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: isUnlocked ? const Color(0xFF4CAF50).withAlpha(51) : const Color(0xFF2AA7FF).withAlpha(51),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: Icon(Icons.library_books, color: Colors.white, size: 24),
            ),
          ),
          const SizedBox(width: 16),
          
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  pkg.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  pkg.description,
                  style: TextStyle(
                    color: Colors.white.withAlpha(128),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          
          // Action button
          if (isUnlocked)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.green,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text('Sahipsin', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            )
          else
            GestureDetector(
              onTap: () => _purchasePack(pkg),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF2AA7FF), Color(0xFF6C27FF)]),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  pkg.price,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _purchasePack(ProductInfo product) async {
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
            const Icon(Icons.library_books, color: Colors.amber, size: 48),
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
                color: Colors.white.withAlpha(26),
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

    // Satın alma akışı başlatılıyor.
    await PurchaseService.instance.purchase(product.id);
  }
}
