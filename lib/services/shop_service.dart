import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/powerup.dart';
import '../models/premium.dart';

class ShopService {
  static final ShopService instance = ShopService._();
  ShopService._();

  static const String _coinsKey = 'user_coins';
  static const String _inventoryKey = 'powerup_inventory';
  static const String _subscriptionKey = 'premium_subscription';

  // Get user's coin balance
  Future<int> getCoins() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_coinsKey) ?? 100; // Start with 100 coins
  }

  // Add coins
  Future<void> addCoins(int amount) async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getInt(_coinsKey) ?? 100;
    await prefs.setInt(_coinsKey, current + amount);
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

  // Award daily login bonus
  Future<int> claimDailyBonus() async {
    final prefs = await SharedPreferences.getInstance();
    final lastClaim = prefs.getString('last_daily_claim');
    final now = DateTime.now();
    
    if (lastClaim != null) {
      final lastDate = DateTime.parse(lastClaim);
      if (lastDate.year == now.year && 
          lastDate.month == now.month && 
          lastDate.day == now.day) {
        return 0; // Already claimed today
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
    
    return bonusCoins;
  }
}
