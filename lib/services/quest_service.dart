import 'dart:convert';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/quest.dart';
import 'shop_service.dart';

class QuestService {
  static final QuestService instance = QuestService._();
  QuestService._();

  static const String _questsKey = 'user_daily_quests';
  static const String _lastResetKey = 'quests_last_reset';
  final Random _random = Random();

  /// Günlük görevleri getirir. Eğer bugün için görev yoksa yenilerini oluşturur.
  Future<List<Quest>> getQuests() async {
    final prefs = await SharedPreferences.getInstance();
    final lastResetStr = prefs.getString(_lastResetKey);
    final now = DateTime.now();

    bool shouldReset = false;
    if (lastResetStr == null) {
      shouldReset = true;
    } else {
      final lastReset = DateTime.parse(lastResetStr);
      if (lastReset.day != now.day || lastReset.month != now.month || lastReset.year != now.year) {
        shouldReset = true;
      }
    }

    if (shouldReset) {
      return await _generateDailyQuests();
    }

    final jsonStr = prefs.getString(_questsKey);
    if (jsonStr == null) {
      return await _generateDailyQuests();
    }

    final List<dynamic> list = jsonDecode(jsonStr);
    return list.map((e) => Quest.fromJson(e)).toList();
  }

  /// Yeni günlük görevler oluşturur.
  Future<List<Quest>> _generateDailyQuests() async {
    final pool = _getQuestPool();
    pool.shuffle(_random);
    
    // Her gün 3 farklı tipte görev seç (unique types)
    final selectedTypes = <QuestType>{};
    final quests = <Quest>[];
    final now = DateTime.now();

    for (var template in pool) {
      if (quests.length >= 3) break;
      if (!selectedTypes.contains(template.type)) {
        selectedTypes.add(template.type);
        quests.add(template.copyWith(
          id: 'q_${template.type.toString().split('.').last}_${now.millisecondsSinceEpoch}',
          lastUpdated: now,
        ));
      }
    }

    await _saveQuests(quests);
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastResetKey, now.toIso8601String());
    
    return quests;
  }

  /// Mevcut görev havuzunu döndürür.
  List<Quest> _getQuestPool() {
    final now = DateTime.now();
    return [
      Quest(id: '1', title: 'Düello Ustası', description: '3 düello kazan', type: QuestType.winDuels, goal: 3, rewardCoins: 100, lastUpdated: now),
      Quest(id: '2', title: 'Kelime Avcısı', description: '20 soruyu doğru yanıtla', type: QuestType.answerQuestions, goal: 20, rewardCoins: 50, lastUpdated: now),
      Quest(id: '3', title: 'Hırslı Oyuncu', description: 'Toplam 1000 puan kazan', type: QuestType.earnPoints, goal: 1000, rewardCoins: 80, lastUpdated: now),
      Quest(id: '4', title: 'Düzenli Pratik', description: '3 adet pratik modu bitir', type: QuestType.playPractice, goal: 3, rewardCoins: 60, lastUpdated: now),
      Quest(id: '5', title: 'Seri Katili', description: 'Bir seferde 10 soru serisi yap', type: QuestType.streakCount, goal: 10, rewardCoins: 120, lastUpdated: now),
      Quest(id: '6', title: 'Hızlı Düşünür', description: '3 saniye altında 5 cevap ver', type: QuestType.speedAnswer, goal: 5, rewardCoins: 150, lastUpdated: now),
      Quest(id: '7', title: 'Kusursuz', description: 'Bir pratiği 10/10 tamamla', type: QuestType.perfectPractice, goal: 1, rewardCoins: 200, lastUpdated: now),
      Quest(id: '8', title: 'Günün Sorusu', description: 'Daily 123 modunu oyna', type: QuestType.daily123Play, goal: 1, rewardCoins: 100, lastUpdated: now),
      Quest(id: '9', title: 'Kelime Dağarcığı', description: 'Havuza 5 kelime ekle', type: QuestType.addWord, goal: 5, rewardCoins: 70, lastUpdated: now),
      Quest(id: '10', title: 'Alışveriş Zamanı', description: 'Marketten bir şey satın al', type: QuestType.buyItem, goal: 1, rewardCoins: 50, lastUpdated: now),
      Quest(id: '11', title: 'Teknoloji Dostu', description: 'Düelloda 3 güçlendirici kullan', type: QuestType.usePowerup, goal: 3, rewardCoins: 90, lastUpdated: now),
      Quest(id: '12', title: 'Düello Canavarı', description: '10 düello kazan', type: QuestType.winDuels, goal: 10, rewardCoins: 300, lastUpdated: now),
      Quest(id: '13', title: 'Gerçek Bilge', description: '50 soruyu doğru yanıtla', type: QuestType.answerQuestions, goal: 50, rewardCoins: 150, lastUpdated: now),
    ];
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
    await ShopService.instance.addCoins(quests[index].rewardCoins);

    // Görevi tamamlandı olarak işaretle
    quests[index] = quests[index].copyWith(
      isCompleted: true,
      lastUpdated: DateTime.now(),
    );

    await _saveQuests(quests);
    return true;
  }
}
