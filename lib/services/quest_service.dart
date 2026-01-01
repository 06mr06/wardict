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
    final random = Random();
    final quests = <Quest>[];
    final now = DateTime.now();

    // 1. Düello Görevi
    quests.add(Quest(
      id: 'q_duel_${now.millisecondsSinceEpoch}',
      title: 'Düello Ustası',
      description: '3 düello kazan',
      type: QuestType.winDuels,
      goal: 3,
      rewardCoins: 50,
      lastUpdated: now,
    ));

    // 2. Soru Cevaplama Görevi
    quests.add(Quest(
      id: 'q_questions_${now.millisecondsSinceEpoch}',
      title: 'Kelime Avcısı',
      description: '20 soruyu doğru yanıtla',
      type: QuestType.answerQuestions,
      goal: 20,
      rewardCoins: 30,
      lastUpdated: now,
    ));

    // 3. Puan Kazanma Görevi
    quests.add(Quest(
      id: 'q_points_${now.millisecondsSinceEpoch}',
      title: 'Hırslı Oyuncu',
      description: 'Toplam 500 puan kazan',
      type: QuestType.earnPoints,
      goal: 500,
      rewardCoins: 40,
      lastUpdated: now,
    ));

    await _saveQuests(quests);
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastResetKey, now.toIso8601String());
    
    return quests;
  }

  /// Görevleri kaydeder.
  Future<void> _saveQuests(List<Quest> quests) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_questsKey, jsonEncode(quests.map((q) => q.toJson()).toList()));
  }

  /// Belirli bir tipteki görevlerin ilerlemesini günceller.
  Future<void> updateProgress(QuestType type, int amount) async {
    final quests = await getQuests();
    bool changed = false;

    for (int i = 0; i < quests.length; i++) {
      if (quests[i].type == type && !quests[i].isCompleted) {
        int newProgress = quests[i].currentProgress + amount;
        if (newProgress >= quests[i].goal) {
          newProgress = quests[i].goal;
          // Otomatik tamamlanmasın, kullanıcı ödülü kendisi alsın veya otomatik olsun mu?
          // Şimdilik sadece ilerlemeyi kaydedelim.
        }
        quests[i] = quests[i].copyWith(
          currentProgress: newProgress,
          lastUpdated: DateTime.now(),
        );
        changed = true;
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
