import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/powerup.dart';
import '../models/premium.dart';
import '../models/cosmetic_item.dart';
import 'achievement_service.dart';
import '../models/achievement.dart';

class ShopService {
  static final ShopService instance = ShopService._();
  ShopService._();

  static const String _coinsKey = 'user_coins';
  static const String _inventoryKey = 'powerup_inventory';
  static const String _subscriptionKey = 'premium_subscription';
  static const String _unlockedCosmeticsKey = 'unlocked_cosmetics';
  static const String _selectedCosmeticsKey = 'selected_cosmetics';
  static const String _lastLoginBonusKey = 'last_login_bonus';
  static const String _isInitializedKey = 'shop_initialized';

  // Get user's coin balance
  Future<int> getCoins() async {
    final prefs = await SharedPreferences.getInstance();
    
    // İlk kez açılıyorsa 100 altın ver
    final isInitialized = prefs.getBool(_isInitializedKey) ?? false;
    if (!isInitialized) {
      await prefs.setInt(_coinsKey, 100);
      await prefs.setBool(_isInitializedKey, true);
      await prefs.setString(_lastLoginBonusKey, DateTime.now().toIso8601String());
      return 100;
    }
    
    // 24 saatlik giriş bonusu kontrolü (birikme olmadan)
    await _checkLoginBonus();
    
    return prefs.getInt(_coinsKey) ?? 100;
  }
  
  // Her 24 saatte giriş yapılırsa 25 altın (birikme yok)
  Future<void> _checkLoginBonus() async {
    final prefs = await SharedPreferences.getInstance();
    final lastBonusStr = prefs.getString(_lastLoginBonusKey);
    
    if (lastBonusStr == null) {
      // İlk giriş - bonus ver ve tarihi kaydet
      final current = prefs.getInt(_coinsKey) ?? 100;
      await prefs.setInt(_coinsKey, current + 25);
      await prefs.setString(_lastLoginBonusKey, DateTime.now().toIso8601String());
      return;
    }
    
    final lastBonus = DateTime.parse(lastBonusStr);
    final now = DateTime.now();
    final difference = now.difference(lastBonus);
    
    // Son bonustan 24 saat geçtiyse bonus ver (sadece 1 kez, birikme yok)
    if (difference.inHours >= 24) {
      final current = prefs.getInt(_coinsKey) ?? 100;
      await prefs.setInt(_coinsKey, current + 25);
      await prefs.setString(_lastLoginBonusKey, now.toIso8601String());
    }
  }

  // Add coins
  Future<void> addCoins(int amount) async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getInt(_coinsKey) ?? 100;
    await prefs.setInt(_coinsKey, current + amount);
    
    // Başarım ilerlemesi
    AchievementService.instance.updateProgress(AchievementCategory.economy, amount);
  }

  // Spend coins
  Future<bool> spendCoins(int amount) async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getInt(_coinsKey) ?? 100;
    if (current >= amount) {
      await prefs.setInt(_coinsKey, current - amount);
      return true;
    }
    return false;
  }

  // Get powerup inventory
  Future<PowerupInventory> getInventory() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_inventoryKey);
    if (json != null) {
      return PowerupInventory.fromJson(jsonDecode(json));
    }
    return const PowerupInventory();
  }

  // Save inventory
  Future<void> saveInventory(PowerupInventory inventory) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_inventoryKey, jsonEncode(inventory.toJson()));
  }

  // Buy a powerup
  Future<bool> buyPowerup(PowerupType powerup) async {
    final canSpend = await spendCoins(powerup.price);
    if (canSpend) {
      final inventory = await getInventory();
      final newInventory = inventory.add(powerup, 1);
      await saveInventory(newInventory);
      return true;
    }
    return false;
  }

  // Use a powerup
  Future<bool> usePowerup(PowerupType powerup) async {
    final inventory = await getInventory();
    if (inventory.hasAny(powerup)) {
      final newInventory = inventory.use(powerup);
      await saveInventory(newInventory);
      return true;
    }
    return false;
  }

  // Get premium subscription
  Future<PremiumSubscription> getSubscription() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_subscriptionKey);
    if (json != null) {
      return PremiumSubscription.fromJson(jsonDecode(json));
    }
    return const PremiumSubscription();
  }

  // Save subscription
  Future<void> saveSubscription(PremiumSubscription subscription) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_subscriptionKey, jsonEncode(subscription.toJson()));
  }

  // Activate premium (for testing)
  Future<void> activatePremium(PremiumTier tier, int days) async {
    final subscription = PremiumSubscription(
      tier: tier,
      expiresAt: DateTime.now().add(Duration(days: days)),
      autoRenew: true,
    );
    await saveSubscription(subscription);
  }

  // Check if user has premium feature
  Future<bool> hasFeature(String featureId) async {
    final subscription = await getSubscription();
    return PremiumFeatures.hasAccess(subscription.tier, featureId);
  }

  // Award coins for game completion
  Future<void> awardCoinsForGame({
    required bool isWin,
    required bool isPerfect,
    required int correctAnswers,
  }) async {
    int coins = correctAnswers * 2; // 2 coins per correct answer
    
    if (isWin) {
      coins += 10; // Bonus for winning
    }
    
    if (isPerfect) {
      coins += 20; // Bonus for perfect game
    }
    
    await addCoins(coins);
  }

  // Award daily login bonus with streak rewards
  Future<Map<String, dynamic>> claimDailyBonus() async {
    final prefs = await SharedPreferences.getInstance();
    final lastClaim = prefs.getString('last_daily_claim');
    final now = DateTime.now();
    
    if (lastClaim != null) {
      final lastDate = DateTime.parse(lastClaim);
      if (lastDate.year == now.year && 
          lastDate.month == now.month && 
          lastDate.day == now.day) {
        return {'coins': 0, 'streak': prefs.getInt('daily_streak') ?? 0, 'rewards': <String>[]}; // Already claimed today
      }
    }
    
    // Get streak
    int streak = prefs.getInt('daily_streak') ?? 0;
    final yesterday = now.subtract(const Duration(days: 1));
    
    if (lastClaim != null) {
      final lastDate = DateTime.parse(lastClaim);
      if (lastDate.year == yesterday.year && 
          lastDate.month == yesterday.month && 
          lastDate.day == yesterday.day) {
        streak++; // Continue streak
      } else {
        streak = 1; // Reset streak
      }
    } else {
      streak = 1;
    }
    
    // Bonus coins based on streak (max 7 days)
    final bonusCoins = 10 + (streak.clamp(1, 7) * 5);
    
    await addCoins(bonusCoins);
    await prefs.setString('last_daily_claim', now.toIso8601String());
    await prefs.setInt('daily_streak', streak);
    
    // Rozet ilerlemesini güncelle (Sadakat)
    await AchievementService.instance.updateProgress(AchievementCategory.skill, streak, setExact: true);
    
    // Streak milestone rewards
    List<String> rewards = [];
    final claimedMilestones = prefs.getStringList('claimed_milestones') ?? [];
    
    // 3 days: Second chance joker
    if (streak >= 3 && !claimedMilestones.contains('streak_3')) {
      final inventory = await getInventory();
      final newInventory = inventory.add(PowerupType.doubleChance, 1);
      await saveInventory(newInventory);
      claimedMilestones.add('streak_3');
      rewards.add('🔄 İkinci Şans jokeri kazandınız!');
    }
    
    // 7 days: Second chance + 50% joker
    if (streak >= 7 && !claimedMilestones.contains('streak_7')) {
      final inventory = await getInventory();
      var newInventory = inventory.add(PowerupType.doubleChance, 1);
      newInventory = newInventory.add(PowerupType.fiftyFifty, 1);
      await saveInventory(newInventory);
      claimedMilestones.add('streak_7');
      rewards.add('🔄 İkinci Şans + ✂️ %50 jokeri kazandınız!');
    }
    
    // 15 days: 100 gold
    if (streak >= 15 && !claimedMilestones.contains('streak_15')) {
      await addCoins(100);
      claimedMilestones.add('streak_15');
      rewards.add('🪙 100 altın kazandınız!');
    }
    
    await prefs.setStringList('claimed_milestones', claimedMilestones);
    
    return {'coins': bonusCoins, 'streak': streak, 'rewards': rewards};
  }

  // Check and give welcome gift for first time users
  Future<bool> checkAndGiveWelcomeGift() async {
    final prefs = await SharedPreferences.getInstance();
    final hasReceivedGift = prefs.getBool('welcome_gift_received') ?? false;
    
    if (!hasReceivedGift) {
      // Give 2 of each powerup as welcome gift
      var inventory = await getInventory();
      for (final powerup in PowerupType.values) {
        inventory = inventory.add(powerup, 2);
      }
      await saveInventory(inventory);
      await prefs.setBool('welcome_gift_received', true);
      return true;
    }
    return false;
  }

  // Get unlocked cosmetic IDs
  Future<List<String>> getUnlockedCosmetics() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_unlockedCosmeticsKey) ?? [];
  }

  // Buy a cosmetic item
  Future<bool> buyCosmetic(CosmeticItem item) async {
    final unlocked = await getUnlockedCosmetics();
    if (unlocked.contains(item.id)) return true;

    if (item.isPremiumOnly) {
       final subscription = await getSubscription();
       if (subscription.tier == PremiumTier.free) return false;
    }

    final canSpend = await spendCoins(item.price);
    if (canSpend) {
      unlocked.add(item.id);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_unlockedCosmeticsKey, unlocked);
      
      // Başarım ilerlemesini güncelle (Koleksiyoncu)
      await AchievementService.instance.updateProgress(AchievementCategory.economy, 1);
      
      return true;
    }
    return false;
  }

  // Get selected cosmetic for a type
  Future<String?> getSelectedCosmetic(CosmeticType type) async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_selectedCosmeticsKey);
    if (data != null) {
      final Map<String, dynamic> map = jsonDecode(data);
      return map[type.name];
    }
    return null;
  }

  // Set selected cosmetic
  Future<void> setSelectedCosmetic(String id, CosmeticType type) async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_selectedCosmeticsKey);
    Map<String, dynamic> map = {};
    if (data != null) {
      map = jsonDecode(data);
    }
    map[type.name] = id;
    await prefs.setString(_selectedCosmeticsKey, jsonEncode(map));
  }
}
