import 'dart:convert';
import 'dart:math';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/quest.dart';
import '../models/powerup.dart';
import 'shop_service.dart';
import 'user_profile_service.dart';
import 'friend_service.dart';

class QuestService {
  static final QuestService instance = QuestService._();
  QuestService._();

  static const String _questsKey = 'user_daily_quests';
  static const String _lastResetKey = 'quests_last_reset';
  static const String _lastWeeklyResetKey = 'weekly_quests_last_reset';
  final Random _random = Random();

  // --- Real-time updates ---
  final _questUpdateController = StreamController<List<Quest>>.broadcast();
  Stream<List<Quest>> get questStream => _questUpdateController.stream;

  /// Günlük ve haftalık görevleri birleşik getirir. Gerekirse yenilerini oluşturur.
  Future<List<Quest>> getQuests() async {
    final prefs = await SharedPreferences.getInstance();
    final lastResetStr = prefs.getString(_lastResetKey);
    final lastWeeklyStr = prefs.getString(_lastWeeklyResetKey);
    final now = DateTime.now();

    bool shouldResetDaily = false;
    if (lastResetStr == null) {
      shouldResetDaily = true;
    } else {
      final lastReset = DateTime.parse(lastResetStr);
      if (lastReset.day != now.day || lastReset.month != now.month || lastReset.year != now.year) {
        shouldResetDaily = true;
      }
    }

    bool shouldResetWeekly = false;
    if (lastWeeklyStr == null) {
      shouldResetWeekly = true;
    } else {
      final lastWeekly = DateTime.parse(lastWeeklyStr);
      // Aynı haftada mıyız kontrolü (Pazartesi başlangıçlı)
      final diff = now.difference(lastWeekly).inDays;
      if (diff >= 7 || now.weekday < lastWeekly.weekday) {
        shouldResetWeekly = true;
      }
    }

    List<Quest> currentQuests = [];
    final jsonStr = prefs.getString(_questsKey);
    if (jsonStr != null) {
      final List<dynamic> list = jsonDecode(jsonStr);
      currentQuests = list.map((e) => Quest.fromJson(e)).toList();
    }

    if (shouldResetDaily || shouldResetWeekly || currentQuests.isEmpty) {
      currentQuests = await _generateQuests(
        currentQuests, 
        resetDaily: shouldResetDaily, 
        resetWeekly: shouldResetWeekly,
      );
    }

    return currentQuests;
  }

  Future<List<Quest>> _generateQuests(
    List<Quest> currentQuests, {
    required bool resetDaily,
    required bool resetWeekly,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    List<Quest> finalQuests = List.from(currentQuests);

    // Profil ve arkadaş bilgisini al (kişiselleştirme için)
    final profile = await UserProfileService.instance.loadProfile();
    final isAdvanced = profile.lpRating > 500; // Örnek koşul
    final friends = await FriendService.instance.getFriends();
    final hasFriends = friends.isNotEmpty;

    if (resetDaily || finalQuests.isEmpty) {
      // Sadece günlük görevleri temizle
      finalQuests.removeWhere((q) => !q.id.startsWith('w_'));

      final pool = _getDailyQuestPool(isAdvanced: isAdvanced, hasFriends: hasFriends);
      final int daysSinceEpoch = now.difference(DateTime(1970)).inDays;
      final int weekNumber = (daysSinceEpoch / 7).floor();
      final weekRandom = Random(weekNumber);
      pool.shuffle(weekRandom);

      final int dayOfWeek = now.weekday;
      final int startIndex = ((dayOfWeek - 1) * 3) % pool.length;

      for (int i = 0; i < 3; i++) {
        final idx = (startIndex + i) % pool.length;
        final template = pool[idx];
        finalQuests.add(template.copyWith(
          id: 'd_${template.type.index}_${dayOfWeek}_$i',
          lastUpdated: now,
        ));
      }
      await prefs.setString(_lastResetKey, now.toIso8601String());
    }

    if (resetWeekly || !finalQuests.any((q) => q.id.startsWith('w_'))) {
      // Sadece haftalık görevleri temizle
      finalQuests.removeWhere((q) => q.id.startsWith('w_'));

      final wPool = _getWeeklyQuestPool(isAdvanced: isAdvanced, hasFriends: hasFriends);
      final int daysSinceEpoch = now.difference(DateTime(1970)).inDays;
      final int weekNumber = (daysSinceEpoch / 7).floor();
      final wRandom = Random(weekNumber);
      wPool.shuffle(wRandom);

      // Haftalık 1 görev
      final template = wPool.first;
      finalQuests.add(template.copyWith(
        id: 'w_${template.type.index}_$weekNumber',
        lastUpdated: now,
      ));
      await prefs.setString(_lastWeeklyResetKey, now.toIso8601String());
    }

    await _saveQuests(finalQuests);
    return finalQuests;
  }

  /// Günlük görev havuzu (Kişiselleştirilmiş)
  List<Quest> _getDailyQuestPool({required bool isAdvanced, required bool hasFriends}) {
    final now = DateTime.now();
    final pool = [
      Quest(id: '1', title: 'Düello Ustası', description: '3 düello kazan', type: QuestType.winDuels, goal: 3, rewardCoins: 150, rewardPowerupType: 'double', rewardPowerupCount: 1, lastUpdated: now),
      Quest(id: '2', title: 'Kelime Avcısı', description: '20 soruyu doğru yanıtla', type: QuestType.answerQuestions, goal: 20, rewardCoins: 50, rewardPowerupType: 'reveal', rewardPowerupCount: 2, lastUpdated: now),
      Quest(id: '3', title: 'Hırslı Oyuncu', description: 'Toplam 1000 puan kazan', type: QuestType.earnPoints, goal: 1000, rewardCoins: 100, rewardPowerupType: 'fifty', rewardPowerupCount: 1, lastUpdated: now),
      Quest(id: '4', title: 'Düzenli Pratik', description: '3 adet pratik modu bitir', type: QuestType.playPractice, goal: 3, rewardCoins: 80, rewardPowerupType: 'freeze', rewardPowerupCount: 1, lastUpdated: now),
      Quest(id: '7', title: 'Günün Sorusu', description: 'Daily 123 modunu oyna', type: QuestType.daily123Play, goal: 1, rewardCoins: 120, rewardPowerupType: 'reveal', rewardPowerupCount: 1, lastUpdated: now),
      Quest(id: '11', title: 'Düello Canavarı', description: '5 düello kazan', type: QuestType.winDuels, goal: 5, rewardCoins: 300, rewardPowerupType: 'reveal', rewardPowerupCount: 2, lastUpdated: now),
      Quest(id: '12', title: 'Yorulmak Yok', description: '50 soruyu doğru yanıtla', type: QuestType.answerQuestions, goal: 50, rewardCoins: 200, rewardPowerupType: 'fifty', rewardPowerupCount: 3, lastUpdated: now),
      Quest(id: '15', title: 'Seri Ustası', description: '15 soruluk bir seri yap', type: QuestType.streakCount, goal: 15, rewardCoins: 150, rewardPowerupType: 'freeze', rewardPowerupCount: 2, lastUpdated: now),
      Quest(id: '16', title: 'Keskin Zeka', description: '10 soruyu 2 saniye altında yanıtla', type: QuestType.speedAnswer, goal: 10, rewardCoins: 250, rewardPowerupType: 'double', rewardPowerupCount: 3, lastUpdated: now),
    ];

    if (isAdvanced) {
      pool.addAll([
        Quest(id: 'a1', title: 'Büyük Kazanç', description: 'Toplam 2500 puan kazan', type: QuestType.earnPoints, goal: 2500, rewardCoins: 250, rewardPowerupType: 'double', rewardPowerupCount: 2, lastUpdated: now),
        Quest(id: 'a2', title: 'Kusursuz Performans', description: 'Bir pratiği 10/10 tamamla', type: QuestType.perfectPractice, goal: 1, rewardCoins: 250, rewardPowerupType: 'double', rewardPowerupCount: 2, lastUpdated: now),
        Quest(id: 'a3', title: 'Hızlı Düşünür', description: '5 soruyu 3 saniye altında yanıtla', type: QuestType.speedAnswer, goal: 5, rewardCoins: 75, rewardPowerupType: 'freeze', rewardPowerupCount: 2, lastUpdated: now),
      ]);
    } else {
      pool.addAll([
        Quest(id: 'b1', title: 'Alışveriş Zamanı', description: 'Marketten bir şey satın al', type: QuestType.buyItem, goal: 1, rewardCoins: 100, rewardPowerupType: 'double', rewardPowerupCount: 1, lastUpdated: now),
        Quest(id: 'b2', title: 'Yeni Görünüm', description: 'Çerçeve veya karakter kuşan', type: QuestType.equipItem, goal: 1, rewardCoins: 100, rewardPowerupType: 'double', rewardPowerupCount: 1, lastUpdated: now),
        Quest(id: 'b3', title: 'Kütüphaneci', description: 'Havuza 10 kelime ekle', type: QuestType.addWord, goal: 10, rewardCoins: 150, rewardPowerupType: 'fifty', rewardPowerupCount: 2, lastUpdated: now),
      ]);
    }

    if (hasFriends) {
      pool.add(Quest(id: 'f1', title: 'Sosyal Kelebek', description: 'Arkadaşınla düello yap', type: QuestType.buddyDuel, goal: 1, rewardCoins: 150, rewardPowerupType: 'freeze', rewardPowerupCount: 3, lastUpdated: now));
    }

    return pool;
  }

  /// Haftalık görev havuzu (Kişiselleştirilmiş)
  List<Quest> _getWeeklyQuestPool({required bool isAdvanced, required bool hasFriends}) {
    final now = DateTime.now();
    final pool = [
      Quest(id: 'w1', title: 'Haftanın Fatihi', description: '25 düello kazan', type: QuestType.winDuels, goal: 25, rewardCoins: 1000, rewardPowerupType: 'double', rewardPowerupCount: 5, lastUpdated: now),
      Quest(id: 'w2', title: 'Kelime Gurusu', description: '250 soruyu doğru yanıtla', type: QuestType.answerQuestions, goal: 250, rewardCoins: 800, rewardPowerupType: 'reveal', rewardPowerupCount: 5, lastUpdated: now),
      Quest(id: 'w3', title: 'Puan Zengini', description: 'Toplam 15.000 puan kazan', type: QuestType.earnPoints, goal: 15000, rewardCoins: 1200, rewardPowerupType: 'fifty', rewardPowerupCount: 5, lastUpdated: now),
    ];
    
    if (hasFriends) {
      pool.add(Quest(id: 'wf1', title: 'Gerçek Dost', description: 'Arkadaşlarınla 10 düello yap', type: QuestType.buddyDuel, goal: 10, rewardCoins: 800, rewardPowerupType: 'freeze', rewardPowerupCount: 5, lastUpdated: now));
    }

    return pool;
  }

  /// Görevleri kaydeder.
  Future<void> _saveQuests(List<Quest> quests) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_questsKey, jsonEncode(quests.map((q) => q.toJson()).toList()));
  }

  /// Belirli bir tipteki görevlerin ilerlemesini günceller.
  Future<void> updateProgress(QuestType type, int amount, {bool setExact = false}) async {
    final quests = await getQuests();
    bool changed = false;

    for (int i = 0; i < quests.length; i++) {
        if (quests[i].type == type && !quests[i].isCompleted) {
            int newProgress;
            if (setExact) {
                newProgress = amount > quests[i].currentProgress ? amount : quests[i].currentProgress;
            } else {
                newProgress = quests[i].currentProgress + amount;
            }

            if (newProgress >= quests[i].goal) {
                newProgress = quests[i].goal;
            }

            if (newProgress != quests[i].currentProgress) {
                quests[i] = quests[i].copyWith(
                    currentProgress: newProgress,
                    lastUpdated: DateTime.now(),
                );
                changed = true;
            }
        }
    }

    if (changed) {
      await _saveQuests(quests);
      _questUpdateController.add(quests);

      // Görev tamamlandıysa otomatik ödül ver ve bildir
      for (var quest in quests) {
        if (quest.currentProgress >= quest.goal && !quest.isCompleted) {
          await claimReward(quest.id);
        }
      }
    }
  }

  /// Görev ödülünü alır.
  Future<bool> claimReward(String questId) async {
    final quests = await getQuests();
    final index = quests.indexWhere((q) => q.id == questId);
    
    if (index == -1) return false;
    if (quests[index].isCompleted) return false;
    if (quests[index].currentProgress < quests[index].goal) return false;

    // Ödülü ver
    if (quests[index].rewardCoins > 0) {
      await ShopService.instance.addCoins(
        quests[index].rewardCoins,
        reason: 'quest_reward',
      );
    }
    
    // Powerup ödülünü ver
    if (quests[index].rewardPowerupType != null && (quests[index].rewardPowerupCount ?? 0) > 0) {
      final powerup = PowerupType.fromId(quests[index].rewardPowerupType!);
      await ShopService.instance.addPowerupToInventory(powerup, quests[index].rewardPowerupCount!);
    }

    // Görevi tamamlandı olarak işaretle
    quests[index] = quests[index].copyWith(
      isCompleted: true,
      lastUpdated: DateTime.now(),
    );

    await _saveQuests(quests);
    _questUpdateController.add(quests);
    return true;
  }
}
