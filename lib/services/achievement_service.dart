import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/achievement.dart';
import 'shop_service.dart';
import 'feed_service.dart';
import '../models/feed_item.dart';

class AchievementService {
  static final AchievementService instance = AchievementService._();
  AchievementService._();

  static const String _achievementsKey = 'user_achievements';

  /// Tüm başarımları getirir. Eğer henüz oluşturulmamışsa varsayılanları döner.
  Future<List<Achievement>> getAchievements() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_achievementsKey);

    if (jsonStr == null) {
      return await _initializeAchievements();
    }

    final List<dynamic> list = jsonDecode(jsonStr);
    return list.map((e) => Achievement.fromJson(e)).toList();
  }

  /// Başlangıç başarımlarını oluşturur.
  Future<List<Achievement>> _initializeAchievements() async {
    final achievements = <Achievement>[
      // --- SEVİYE ROZETLERİ (LEVEL) ---
      Achievement(
        id: 'lvl_a1',
        title: 'Harf (A1)',
        description: 'Kelime yolculuğuna başladın!',
        category: AchievementCategory.level,
        tier: AchievementTier.bronze,
        goal: 1,
        rewardCoins: 50,
        badgeIcon: '👶',
      ),
      Achievement(
        id: 'lvl_a2',
        title: 'Hece (A2)',
        description: 'Practice modunda 7 kez A2 seviyesinde kal.',
        category: AchievementCategory.level,
        tier: AchievementTier.bronze,
        goal: 7,
        rewardCoins: 100,
        badgeIcon: '🧱',
      ),
      Achievement(
        id: 'lvl_b1',
        title: 'Kelime (B1)',
        description: 'Practice modunda 7 kez B1 seviyesinde kal.',
        category: AchievementCategory.level,
        tier: AchievementTier.silver,
        goal: 7,
        rewardCoins: 150,
        badgeIcon: '📚',
      ),
      Achievement(
        id: 'lvl_b2',
        title: 'Cümle (B2)',
        description: 'Practice modunda 7 kez B2 seviyesinde kal.',
        category: AchievementCategory.level,
        tier: AchievementTier.silver,
        goal: 7,
        rewardCoins: 200,
        badgeIcon: '✍️',
      ),
      Achievement(
        id: 'lvl_c1',
        title: 'Roman (C1)',
        description: 'Practice modunda 7 kez C1 seviyesinde kal.',
        category: AchievementCategory.level,
        tier: AchievementTier.gold,
        goal: 7,
        rewardCoins: 300,
        badgeIcon: '📖',
      ),
      Achievement(
        id: 'lvl_c2',
        title: 'Yazar (C2)',
        description: 'Practice modunda 7 kez C2 seviyesinde kal.',
        category: AchievementCategory.level,
        tier: AchievementTier.platinum,
        goal: 7,
        rewardCoins: 500,
        badgeIcon: '✒️',
      ),

      // --- DÜELLO (CAREER) ---
      Achievement(
        id: 'duel_win_3',
        title: 'Üçleme',
        description: '3 düello kazan',
        category: AchievementCategory.career,
        tier: AchievementTier.bronze,
        goal: 3,
        rewardCoins: 50,
        badgeIcon: '🥉',
      ),
      Achievement(
        id: 'duel_win_10',
        title: 'Savaşçı',
        description: '10 düello kazan',
        category: AchievementCategory.career,
        tier: AchievementTier.silver,
        goal: 10,
        rewardCoins: 200,
        badgeIcon: '🥈',
      ),
      Achievement(
        id: 'duel_win_50',
        title: 'Gladyatör',
        description: '50 düello kazan',
        category: AchievementCategory.career,
        tier: AchievementTier.gold,
        goal: 50,
        rewardCoins: 1000,
        badgeIcon: '🥇',
      ),
      Achievement(
        id: 'duel_streak_5',
        title: 'Yenilmez',
        description: '5 düello üst üste kazan',
        category: AchievementCategory.career,
        tier: AchievementTier.platinum,
        goal: 5,
        rewardCoins: 300,
        badgeIcon: '🤜',
      ),

      // --- SOSYAL (SOCIAL) ---
      Achievement(
        id: 'social_friend_5',
        title: 'Popüler',
        description: '5 arkadaş davet et veya maç yap',
        category: AchievementCategory.social,
        tier: AchievementTier.bronze,
        goal: 5,
        rewardCoins: 100,
        badgeIcon: '🤝',
      ),
      Achievement(
        id: 'social_friend_15',
        title: 'Sosyal Kelebek',
        description: '15 arkadaşla etkileşime geç',
        category: AchievementCategory.social,
        tier: AchievementTier.silver,
        goal: 15,
        rewardCoins: 300,
        badgeIcon: '🦋',
      ),

      // --- EKONOMİ (ECONOMY) ---
      Achievement(
        id: 'econ_collector_5',
        title: 'Koleksiyoncu',
        description: '5 market öğesi satın al',
        category: AchievementCategory.economy,
        tier: AchievementTier.bronze,
        goal: 5,
        rewardCoins: 150,
        badgeIcon: '🎨',
      ),
      Achievement(
        id: 'econ_collector_10',
        title: 'Müze Müdürü',
        description: '10 market öğesi satın al',
        category: AchievementCategory.economy,
        tier: AchievementTier.silver,
        goal: 10,
        rewardCoins: 400,
        badgeIcon: '🏛️',
      ),

      // --- DAILY 123 (SKILL) ---
      Achievement(
        id: 'daily_123_3',
        title: 'Günün Ustası',
        description: '3 gün üst üste 123 puan yap',
        category: AchievementCategory.skill,
        tier: AchievementTier.silver,
        goal: 3,
        rewardCoins: 300,
        badgeIcon: '🎯',
      ),
      Achievement(
        id: 'daily_123_10',
        title: 'Efsanevi 123',
        description: '10 gün üst üste 123 puan yap',
        category: AchievementCategory.skill,
        tier: AchievementTier.platinum,
        goal: 10,
        rewardCoins: 1000,
        badgeIcon: '👑',
      ),

      // --- SADAKAT (SKILL) ---
      Achievement(
        id: 'loyalty_3',
        title: 'Sadık Oyuncu',
        description: '3 gün üst üste giriş yap',
        category: AchievementCategory.skill,
        tier: AchievementTier.bronze,
        goal: 3,
        rewardCoins: 50,
        badgeIcon: '📅',
      ),
      Achievement(
        id: 'loyalty_7',
        title: 'Vazgeçilmez',
        description: '7 gün üst üste giriş yap',
        category: AchievementCategory.skill,
        tier: AchievementTier.silver,
        goal: 7,
        rewardCoins: 200,
        badgeIcon: '🔥',
      ),
      Achievement(
        id: 'loyalty_30',
        title: 'Müdavim',
        description: '30 gün üst üste giriş yap',
        category: AchievementCategory.skill,
        tier: AchievementTier.gold,
        goal: 30,
        rewardCoins: 1000,
        badgeIcon: '🎖️',
      ),
    ];

    await _saveAchievements(achievements);
    return achievements;
  }

  /// Başarımları kaydeder.
  Future<void> _saveAchievements(List<Achievement> achievements) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_achievementsKey, jsonEncode(achievements.map((a) => a.toJson()).toList()));
  }
  
  /// Son oyundan bu yana yeni açılan ödülleri getirir ve işaretler
  Future<List<Achievement>> getNewlyUnlockedAchievements() async {
    final prefs = await SharedPreferences.getInstance();
    final lastCheck = prefs.getString('last_achievement_check_time');
    final lastCheckTime = lastCheck != null ? DateTime.parse(lastCheck) : DateTime.now().subtract(const Duration(days: 365));
    
    final achievements = await getAchievements();
    final newlyUnlocked = achievements
        .where((a) => a.isUnlocked && a.unlockedAt != null && a.unlockedAt!.isAfter(lastCheckTime))
        .toList();
    
    // Son kontrol zamanını güncelle
    await prefs.setString('last_achievement_check_time', DateTime.now().toIso8601String());
    
    return newlyUnlocked;
  }
  
  /// Belirli zamandan sonra açılan ödülleri döndürür (oyun sonu kutlama için)
  Future<List<Achievement>> checkNewAchievementsSince(DateTime since) async {
    final achievements = await getAchievements();
    return achievements
        .where((a) => a.isUnlocked && a.unlockedAt != null && a.unlockedAt!.isAfter(since))
        .toList();
  }

  /// Belirli bir kategoride ilerleme kaydeder.
  Future<void> updateProgress(AchievementCategory category, int amount, {bool setExact = false}) async {
    final achievements = await getAchievements();
    bool changed = false;

    for (int i = 0; i < achievements.length; i++) {
      if (achievements[i].category == category && !achievements[i].isUnlocked) {
        int newProgress;
        if (setExact) {
          // Bazı başarımlar (örn. en yüksek seri) için direkt değer atanır.
          if (amount > achievements[i].currentProgress) {
             newProgress = amount;
          } else {
             continue; // Daha yüksek bir değer değilse güncelleme
          }
        } else {
          newProgress = achievements[i].currentProgress + amount;
        }

        if (newProgress >= achievements[i].goal) {
          newProgress = achievements[i].goal;
          // Kilit açma işlemi
          achievements[i] = achievements[i].copyWith(
            currentProgress: newProgress,
            isUnlocked: true,
            unlockedAt: DateTime.now(),
          );
          
          // Aktivite akışına ekle
          FeedService.instance.logUserActivity(
            FeedType.achievementUnlock, 
            '"${achievements[i].title}" başarısını açtın! ✨'
          );

          // Ödülü ver
           await ShopService.instance.addCoins(achievements[i].rewardCoins);
        } else {
          achievements[i] = achievements[i].copyWith(
            currentProgress: newProgress,
          );
        }
        changed = true;
      }
    }

    if (changed) {
      await _saveAchievements(achievements);
    }
  }

  /// Belirli bir ID'ye sahip başarının ilerlemesini güncelleyerek kaydeder.
  Future<void> updateAchievementProgressById(String id, int amount, {bool setExact = false}) async {
    final achievements = await getAchievements();
    int index = achievements.indexWhere((a) => a.id == id);
    
    if (index != -1 && !achievements[index].isUnlocked) {
      int newProgress;
      if (setExact) {
        newProgress = amount;
      } else {
        newProgress = achievements[index].currentProgress + amount;
      }

      if (newProgress >= achievements[index].goal) {
        newProgress = achievements[index].goal;
        achievements[index] = achievements[index].copyWith(
          currentProgress: newProgress,
          isUnlocked: true,
          unlockedAt: DateTime.now(),
        );
        
        FeedService.instance.logUserActivity(
          FeedType.achievementUnlock, 
          '"${achievements[index].title}" başarısını açtın! ✨'
        );
        await ShopService.instance.addCoins(achievements[index].rewardCoins);
      } else {
        achievements[index] = achievements[index].copyWith(
          currentProgress: newProgress,
        );
      }
      
      await _saveAchievements(achievements);
    }
  }
}
