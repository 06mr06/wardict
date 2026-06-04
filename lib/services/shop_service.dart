import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/powerup.dart';
import '../models/premium.dart';
import '../models/cosmetic_item.dart';
import 'achievement_service.dart';
import '../models/achievement.dart';
// import 'sound_service.dart';
import 'quest_service.dart';
import '../models/quest.dart';
import 'user_profile_service.dart';
import 'economy_service.dart';
import 'package:flutter/foundation.dart';
import 'dart:math' as math;

class ShopService {
  static final ShopService instance = ShopService._();
  ShopService._();

  static const String _inventoryKey = 'powerup_inventory';
  static const String _subscriptionKey = 'premium_subscription';
  static const String _unlockedCosmeticsKey = 'unlocked_cosmetics';
  static const String _selectedCosmeticsKey = 'selected_cosmetics';
  static const String _lastLoginBonusKey = 'last_login_bonus';
  static const String _isInitializedKey = 'shop_initialized';
  static const String _usedPromoCodesKey = 'used_promo_codes';
  static const String _streakShieldKey = 'streak_shield_expiry';
  static const String _unlockedPacksKey = 'unlocked_word_packs';
  static const String _lastDuelDateKey = 'last_duel_date';
  static const String _duelsPlayedTodayKey = 'duels_played_today';
  static const String _lastLuckChestKey = 'last_luck_chest_open';
  static const int maxFreeDuels = 5;

  /// Checks if the user can play a duel based on their subscription and daily limit.
  /// Returns a map with 'canPlay' (bool) and 'message' (String).
  Future<Map<String, dynamic>> canPlayDuel() async {
    return {'canPlay': true, 'message': 'Sınırsız düello.'};
  }

  /// Records that a duel has been played for non-premium users.
  Future<void> recordDuelPlay() async {
    // Sınır kaldırıldığı için işlem yapmaya gerek yok
  }

  // Eski hardcoded promo kodları sunucuya taşındı (promoCodes koleksiyonu).
  // Yeni kod eklemek için Firebase Console → Firestore → promoCodes/{CODE}:
  //   { rewardCoins?: int, premiumDays?: int, maxUses?: int, expiresAt?: Timestamp }

  // Get user's coin balance
  Future<int> getCoins() async {
    final profile = await UserProfileService.instance.loadProfile();
    return profile.coins;
  }
  
  // NOT: Eski `_checkLoginBonus` kaldırıldı — bu akış artık sunucu tarafı
  // `claimDailyBonus` içinde ele alınıyor (22h cooldown + streak).

  /// Altın ekleme. Sunucu taraflı (Cloud Function `secureAddCoins`).
  ///
  /// [reason] sunucuda whitelist ile doğrulanır: game_reward / ad_reward /
  /// luck_chest / streak_milestone / welcome_gift.
  ///
  /// Offline veya sunucu hatası durumunda istek `OfflineQueueService`'e düşer.
  /// Yerelde optimistik artış yapılır, bağlantı gelince sunucu bakiyesiyle
  /// hizalanır.
  Future<void> addCoins(int amount, {String reason = 'game_reward'}) async {
    if (amount <= 0) return;

    // YENİ EKLENEN: Geçici olarak local bakiyeyi hemen güncelle ki UI tepki versin
    final tempProfile = await UserProfileService.instance.loadProfile();
    final tempProfileUpdated = tempProfile.copyWith(coins: tempProfile.coins + amount);
    await UserProfileService.instance.saveProfile(tempProfileUpdated);

    // Sunucuda doğrula + ledger yaz
    final serverBalance =
        await EconomyService.instance.addCoins(amount: amount, reason: reason);

    final profile = await UserProfileService.instance.loadProfile();
    // Sunucudan gelen bakiye geçerliyse onu kullan, yoksa yerelde kal
    final int newCoins =
        serverBalance >= 0 ? serverBalance : profile.coins;
    final updatedProfile = profile.copyWith(coins: newCoins);
    await UserProfileService.instance.saveProfile(updatedProfile);
  }

  /// Günlük Şans Sandığı açılabilir mi kontrolü
  Future<bool> canOpenLuckChest() async {
    final prefs = await SharedPreferences.getInstance();
    final lastOpenStr = prefs.getString(_lastLuckChestKey);
    if (lastOpenStr == null) return true;

    final lastOpen = DateTime.parse(lastOpenStr);
    final now = DateTime.now();
    return now.difference(lastOpen).inHours >= 24;
  }

  /// Şans sandığını aç ve ödülü döndür
  Future<Map<String, dynamic>> openLuckChest() async {
    if (!await canOpenLuckChest()) {
      return {'success': false, 'message': 'Sandık için beklemelisin.'};
    }

    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    await prefs.setString(_lastLuckChestKey, now.toIso8601String());

    return _generateChestReward('luck_chest');
  }

  /// Maç sonu ganimet sandığını aç (sürpriz sandık)
  Future<Map<String, dynamic>> openMatchChest() async {
    return _generateChestReward('game_reward'); // Maç sonu sandığı game_reward olarak geçer
  }
  
  /// Ortak sandık ödül üreticisi
  Future<Map<String, dynamic>> _generateChestReward(String reason) async {
    final random = math.Random();
    int rewardType = random.nextInt(10); // 0-9 arası
    
    if (rewardType < 8) {
      // %80 olasılıkla Coin (25-100 arası)
      int coins = 25 + random.nextInt(76);
      await addCoins(coins, reason: reason);
      return {
        'success': true,
        'type': 'coins',
        'amount': coins,
        'icon': '💰',
      };
    } else {
      // %20 olasılıkla rastgele bir Power-up
      final powerups = [PowerupType.fiftyFifty, PowerupType.doubleChance, PowerupType.freezeTime, PowerupType.revealAnswer];
      final selected = powerups[random.nextInt(powerups.length)];
      await addPowerupToInventory(selected, 1); 
      
      return {
        'success': true,
        'type': 'powerup',
        'id': selected.id,
        'amount': 1,
        'icon': selected.emoji,
      };
    }
  }

  /// Altın harcama — sunucu tarafında atomik kontrol.
  /// Bakiye yetersizse false döner ve yerel profil değişmez.
  ///
  /// Cloud Function (App Check, ağ, `internal`) başarısız olursa kuyruğa yazılmaz;
  /// yerelde yeterli coin varsa mağaza işleminin aksamaması için yerel düşüm yapılır.
  Future<bool> spendCoins(int amount, {String reason = 'purchase'}) async {
    if (amount <= 0) return true;
    final profile = await UserProfileService.instance.loadProfile();
    if (profile.coins < amount) return false; // erken hata

    final serverBalance = await EconomyService.instance.spendCoins(
      amount: amount,
      reason: reason,
      enqueueIfRetryableFailure: false,
    );

    if (serverBalance >= 0) {
      final int expectedAfter = (profile.coins - amount).clamp(0, 2000000000);
      int newCoins = serverBalance;
      // Sunucu bazen bakiyeyi düşürmeden önceki değeri döndürebilir; yerel düşümle hizala.
      if (newCoins > expectedAfter) {
        newCoins = expectedAfter;
        debugPrint(
          '⚠️ spendCoins: sunucu bakiyesi ($serverBalance) beklenen ($expectedAfter) üstünde — yerel düşüm uygulanıyor.',
        );
      }
      final updated = profile.copyWith(coins: newCoins);
      await UserProfileService.instance.saveProfile(updated);
      // Firestore’daki coins alanı güncel kalsın; aksi halde mağaza yenilenince
      // fetchProfileFromFirestore eski bakiyeyle üzerine yazar.
      await UserProfileService.instance.syncProfileToFirestore();
      return true;
    }

    // Sunucu açıkça yetersiz bakiye dedi — yereli eşitlemeyiz
    if (serverBalance == -2) {
      return false;
    }

    // Sunucu yanıt veremedi; UI’da görünen bakiye genelde yerel — satın alımı tamamla
    if (profile.coins >= amount) {
      final updated = profile.copyWith(coins: profile.coins - amount);
      await UserProfileService.instance.saveProfile(updated);
      debugPrint(
        '⚠️ spendCoins: sunucu yok, yerel düşüm ($amount coin). İleride CF ile hizalanır.',
      );
      await UserProfileService.instance.syncProfileToFirestore();
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

  /// Belirli bir powerup'ı envantere ekle (ödüller için)
  Future<void> addPowerupToInventory(PowerupType type, int count) async {
    final inventory = await getInventory();
    final updatedInventory = inventory.add(type, count);
    await saveInventory(updatedInventory);
    debugPrint('📦 Envantere eklendi: ${type.name} x$count');
  }

  // Buy a powerup
  Future<bool> buyPowerup(PowerupType powerup) async {
    final canSpend = await spendCoins(powerup.price);
    if (canSpend) {
      final inventory = await getInventory();
      final newInventory = inventory.add(powerup, 1);
      await saveInventory(newInventory);
      // Görev: Alışveriş Zamanı
      QuestService.instance.updateProgress(QuestType.buyItem, 1);
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

  // Activate premium (for testing or purchase)
  Future<void> activatePremium(PremiumTier tier, int days) async {
    final subscription = PremiumSubscription(
      tier: tier,
      expiresAt: DateTime.now().add(Duration(days: days)),
      autoRenew: true,
    );
    await saveSubscription(subscription);
    
    // Profili güncelle ve Firestore'a senkronize et
    try {
      final profile = await UserProfileService.instance.loadProfile();
      final updatedProfile = profile.copyWith(isPremium: true);
      await UserProfileService.instance.saveProfile(updatedProfile);
      await UserProfileService.instance.syncProfileToFirestore();
    } catch (e) {
      debugPrint('⚠️ Premium profile sync error: $e');
    }
  }

  /// Promosyon kodu kullan — SUNUCU doğrulamalı.
  /// Artık client'ta hardcoded kod listesi yok. Kodlar Firestore'da
  /// `promoCodes/{code}` belgesinde tanımlıdır.
  /// Returns: {'success': bool, 'message': String, 'days': int?}
  Future<Map<String, dynamic>> redeemPromoCode(String code) async {
    final normalizedCode = code.trim().toUpperCase();
    final result = await EconomyService.instance.redeemPromoCode(normalizedCode);

    if (!result.success) {
      return {
        'success': false,
        'message': result.errorMessage ?? 'Kod geçersiz veya zaten kullanılmış.',
        'days': null,
      };
    }

    // Bulutta entitlement güncellendi; yerel profili tazele
    await UserProfileService.instance.fetchProfileFromFirestore();

    return {
      'success': true,
      'message': result.premiumDays > 0
          ? 'Promosyon kodu uygulandı! ${result.premiumDays} gün premium kazandın.'
          : 'Promosyon kodu uygulandı! ${result.rewardCoins} altın kazandın.',
      'days': result.premiumDays,
      'coins': result.rewardCoins,
    };
  }

  /// Kullanılmış promosyon kodlarını getir
  Future<List<String>> getUsedPromoCodes() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_usedPromoCodesKey) ?? [];
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
    
    await addCoins(coins, reason: 'game_reward');
  }

  // Award daily login bonus with streak rewards
  Future<Map<String, dynamic>> claimDailyBonus() async {
    final prefs = await SharedPreferences.getInstance();

    // Sunucuda günlük bonus + streak hesabı
    final result = await EconomyService.instance.claimDailyBonus();

    final profile = await UserProfileService.instance.loadProfile();
    int streak = profile.dailyStreak;
    int bonusCoins = 0;
    int newBalance = profile.coins;

    if (result.success) {
      streak = result.streak;
      bonusCoins = result.bonusCoins;
      newBalance = result.balance;
    } else {
      // Aynı gün veya hata: mevcut değerleri koru
      return {
        'coins': 0,
        'streak': profile.dailyStreak,
        'rewards': <String>[],
      };
    }

    final now = DateTime.now();
    final updatedProfile = profile.copyWith(
      coins: newBalance,
      lastPlayed: now,
      dailyStreak: streak,
      lastDailyRewardClaimed: now,
    );
    await UserProfileService.instance.saveProfile(updatedProfile);
    
    // SharedPreferences yedeği (Gerekli değil ama kalsın)
    await prefs.setString('last_daily_claim', now.toIso8601String());
    
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
      await addCoins(100, reason: 'streak_milestone');
      claimedMilestones.add('streak_15');
      rewards.add('🪙 100 altın kazandınız!');
    }
    
    await prefs.setStringList('claimed_milestones', claimedMilestones);
    
    return {'coins': bonusCoins, 'streak': streak, 'rewards': rewards};
  }

  /// Hoşgeldin hediyesi altın miktarı (UI ile aynı olmalı).
  static const int welcomeGiftCoins = 200;

  // Check and give welcome gift for first time users
  Future<bool> checkAndGiveWelcomeGift() async {
    final profile = await UserProfileService.instance.loadProfile();
    
    if (!profile.hasReceivedWelcomeGift) {
      await addCoins(welcomeGiftCoins, reason: 'welcome_gift');
      
      // Give 2 of each powerup as welcome gift
      var inventory = await getInventory();
      for (final powerup in PowerupType.values) {
        inventory = inventory.add(powerup, 2);
      }
      await saveInventory(inventory);
      
      // Profili tekrar yükle (addCoins güncelledi)
      final currentProfile = await UserProfileService.instance.loadProfile();
      
      // Profili güncelle ve Firestore'a senkronize et
      final updatedProfile = currentProfile.copyWith(hasReceivedWelcomeGift: true);
      await UserProfileService.instance.saveProfile(updatedProfile);
      await UserProfileService.instance.syncProfileToFirestore();
      
      debugPrint('🎁 Welcome gift granted ($welcomeGiftCoins coins + powerups)');
      return true;
    }
    return false;
  }

  // Get unlocked cosmetic IDs
  Future<List<String>> getUnlockedCosmetics() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> unlocked = prefs.getStringList(_unlockedCosmeticsKey) ?? [];
    
    // Cloud sync check for persistence
    final profile = await UserProfileService.instance.loadProfile();
    if (profile.unlockedCosmetics.isNotEmpty) {
      bool changed = false;
      for (final id in profile.unlockedCosmetics) {
        if (!unlocked.contains(id)) {
          unlocked.add(id);
          changed = true;
        }
      }
      if (changed) {
        await prefs.setStringList(_unlockedCosmeticsKey, unlocked);
      }
    }
    
    return unlocked;
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
      
      // Sync to UserProfile
      final profile = await UserProfileService.instance.loadProfile();
      final updatedProfile = profile.copyWith(unlockedCosmetics: unlocked);
      await UserProfileService.instance.saveProfile(updatedProfile);
      
      // Başarım ilerlemesini güncelle (Koleksiyoncu)
      await AchievementService.instance.updateProgress(AchievementCategory.economy, 1);
      // Görev: Alışveriş Zamanı
      QuestService.instance.updateProgress(QuestType.buyItem, 1);
      
      return true;
    }
    return false;
  }

  // Get selected cosmetic for a type
  Future<String?> getSelectedCosmetic(CosmeticType type) async {
    final prefs = await SharedPreferences.getInstance();
    
    // Önce yerel tercihi kontrol et
    final data = prefs.getString(_selectedCosmeticsKey);
    String? localId;
    if (data != null) {
      final Map<String, dynamic> map = jsonDecode(data);
      localId = map[type.name];
    }
    
    // Eğer yerelde yoksa veya bulutla senkronize değilse Profile bak
    final profile = await UserProfileService.instance.loadProfile();
    final profileId = type == CosmeticType.avatar ? profile.avatarId : profile.frameId;

    // Eğer yerel ve profil farklıysa (veya yerelde yoksa) senkronizasyon yapalım
    if (localId != profileId && profileId != null) {
      debugPrint('🔄 Syncing selected ${type.name} from profile: $profileId');
      await setSelectedCosmetic(profileId, type);
      return profileId;
    }
    
    return localId;
  }

  // Get all selected cosmetics
  Future<Map<CosmeticType, String?>> getSelectedCosmetics() async {
    Map<CosmeticType, String?> selected = {};
    for (final type in CosmeticType.values) {
      selected[type] = await getSelectedCosmetic(type);
    }
    return selected;
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
    
    // Görev: Yeni Görünüm
    QuestService.instance.updateProgress(QuestType.equipItem, 1);
  }

  // ============ STREAK SHIELD (Seri Koruma) ============

  /// Seri Koruma satın al (150 altın, 3 gün koruma)
  Future<bool> buyStreakShield() async {
    const price = 150;
    final canSpend = await spendCoins(price);
    if (canSpend) {
      await activateStreakShield();
      // Görev: Alışveriş Zamanı
      QuestService.instance.updateProgress(QuestType.buyItem, 1);
      return true;
    }
    return false;
  }

  /// Seri Koruma'yı aktifleştir (3 gün)
  Future<void> activateStreakShield() async {
    final prefs = await SharedPreferences.getInstance();
    final expiry = DateTime.now().add(const Duration(days: 3));
    await prefs.setString(_streakShieldKey, expiry.toIso8601String());
  }

  /// Seri Koruma aktif mi?
  Future<bool> hasActiveStreakShield() async {
    final prefs = await SharedPreferences.getInstance();
    final expiryStr = prefs.getString(_streakShieldKey);
    if (expiryStr == null) return false;
    
    final expiry = DateTime.parse(expiryStr);
    return DateTime.now().isBefore(expiry);
  }

  /// Seri Koruma bitiş tarihi
  Future<DateTime?> getStreakShieldExpiry() async {
    final prefs = await SharedPreferences.getInstance();
    final expiryStr = prefs.getString(_streakShieldKey);
    if (expiryStr == null) return null;
    
    final expiry = DateTime.parse(expiryStr);
    if (DateTime.now().isAfter(expiry)) return null;
    return expiry;
  }

  /// Seri Koruma'yı kullan (bir seferlik koruma harcandı mı kontrolü için)
  Future<bool> useStreakShield() async {
    final hasShield = await hasActiveStreakShield();
    if (hasShield) {
      // Kalkan hala aktif, kullanıldı olarak işaretle ama süre dolana kadar aktif kalsın
      return true;
    }
    return false;
  }

  /// Kalan gün sayısı
  Future<int> getStreakShieldRemainingDays() async {
    final expiry = await getStreakShieldExpiry();
    if (expiry == null) return 0;
    return expiry.difference(DateTime.now()).inDays + 1;
  }

  // ============ WORD PACKS (Kelime Paketleri) ============

  /// Satın alınan paketleri getir
  Future<List<String>> getUnlockedPacks() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_unlockedPacksKey) ?? [];
  }

  /// Paket satın al (49 TL - Simüle edilmiş veya Coin ile)
  /// Kullanıcı 49 TL dediği için normalde PurchaseService kullanmalı.
  /// Ama burada ShopService içinde de takibini yapıyoruz.
  Future<void> unlockPack(String packId) async {
    final unlocked = await getUnlockedPacks();
    if (!unlocked.contains(packId)) {
      unlocked.add(packId);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_unlockedPacksKey, unlocked);
      
      // Başarım ilerlemesini güncelle
      await AchievementService.instance.updateProgress(AchievementCategory.economy, 1);
    }
  }

  /// Pakete sahip mi?
  Future<bool> holdsPack(String packId) async {
    final unlocked = await getUnlockedPacks();
    return unlocked.contains(packId);
  }
}
