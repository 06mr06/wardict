import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/daily_123.dart';
import '../providers/daily_123_provider.dart' show AnsweredQuestion;
import 'achievement_service.dart';
import '../models/achievement.dart';
import 'shop_service.dart';
import 'firebase/firestore_service.dart';
import 'firebase/auth_service.dart';
import 'quest_service.dart';
import '../models/quest.dart';

class Daily123Service {
  static final Daily123Service instance = Daily123Service._();
  Daily123Service._();

  static const String _statsKey = 'daily_123_stats';
  static const String _lastPlayedKey = 'daily_123_last_played';
  static const String _adResetKey = 'daily_123_ad_reset';
  static const String _lastCorrectAnswersKey = 'daily_123_last_correct_json';
  static const String _lastWrongAnswersKey = 'daily_123_last_wrong_json';
  static const String _lastAnswersDayKey = 'daily_123_last_answers_day_iso';

  /// Bugünkü en son Daily 123 sonucu (aynı gün birden fazla oynandıysa en günceli).
  Future<Daily123Result?> getLatestResultForToday() async {
    final stats = await getStats();
    final now = DateTime.now();
    Daily123Result? latest;
    for (final r in stats.history) {
      final d = r.date;
      if (d.year != now.year || d.month != now.month || d.day != now.day) {
        continue;
      }
      if (latest == null || r.date.isAfter(latest.date)) {
        latest = r;
      }
    }
    return latest;
  }

  Map<String, dynamic> _answeredToJson(AnsweredQuestion e) => {
        'prompt': e.prompt,
        'correctAnswer': e.correctAnswer,
        'userAnswer': e.userAnswer,
        'isCorrect': e.isCorrect,
        'turkishMeaning': e.turkishMeaning,
      };

  AnsweredQuestion _answeredFromJson(Map<String, dynamic> j) => AnsweredQuestion(
        prompt: j['prompt'] as String,
        correctAnswer: j['correctAnswer'] as String,
        userAnswer: j['userAnswer'] as String?,
        isCorrect: j['isCorrect'] as bool,
        turkishMeaning: j['turkishMeaning'] as String?,
      );

  /// Oyun bittiğinde sonuç ekranında doğru/yanlış listelerini tekrar göstermek için.
  Future<void> cacheLastSessionAnswers(
    List<AnsweredQuestion> correct,
    List<AnsweredQuestion> wrong,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _lastCorrectAnswersKey,
      jsonEncode(correct.map(_answeredToJson).toList()),
    );
    await prefs.setString(
      _lastWrongAnswersKey,
      jsonEncode(wrong.map(_answeredToJson).toList()),
    );
    await prefs.setString(_lastAnswersDayKey, DateTime.now().toIso8601String());
  }

  Future<(List<AnsweredQuestion>, List<AnsweredQuestion>)>
      loadCachedAnswersForToday() async {
    final prefs = await SharedPreferences.getInstance();
    final dayStr = prefs.getString(_lastAnswersDayKey);
    if (dayStr == null) {
      return (<AnsweredQuestion>[], <AnsweredQuestion>[]);
    }
    final stored = DateTime.parse(dayStr);
    final now = DateTime.now();
    if (stored.year != now.year ||
        stored.month != now.month ||
        stored.day != now.day) {
      return (<AnsweredQuestion>[], <AnsweredQuestion>[]);
    }
    List<AnsweredQuestion> decode(String? raw) {
      if (raw == null || raw.isEmpty) return [];
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => _answeredFromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    }

    return (
      decode(prefs.getString(_lastCorrectAnswersKey)),
      decode(prefs.getString(_lastWrongAnswersKey)),
    );
  }

  Future<Daily123Stats> getStats() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_statsKey);
    if (jsonStr == null) return Daily123Stats();
    return Daily123Stats.fromJson(jsonDecode(jsonStr));
  }

  Future<void> _saveStats(Daily123Stats stats) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_statsKey, jsonEncode(stats.toJson()));
  }

  Future<bool> canPlayToday() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Reklam ile reset atılmış mı?
    final hasAdReset = prefs.getBool(_adResetKey) ?? false;
    if (hasAdReset) return true;

    final lastPlayedStr = prefs.getString(_lastPlayedKey);
    if (lastPlayedStr == null) return true;

    final lastPlayed = DateTime.parse(lastPlayedStr);
    final now = DateTime.now();
    return lastPlayed.day != now.day || 
           lastPlayed.month != now.month || 
           lastPlayed.year != now.year;
  }

  /// Reklam izlendiğinde tekrar oynama hakkı verir
  Future<void> grantAdReplay() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_adResetKey, true);
  }

  Future<void> recordGame(Daily123Result result) async {
    final stats = await getStats();
    final newHistory = List<Daily123Result>.from(stats.history)..add(result);
    
    int newStreak;
    
    if (result.isWin) {
      // Kazandı - seri artar
      newStreak = stats.currentStreak + 1;
    } else {
      // Kaybetti - Seri Koruma var mı kontrol et
      final hasShield = await ShopService.instance.hasActiveStreakShield();
      if (hasShield) {
        // Kalkan aktif - seri korunur!
        newStreak = stats.currentStreak;
      } else {
        // Kalkan yok - seri sıfırlanır
        newStreak = 0;
      }
    }
    
    int newHighest = newStreak > stats.highestStreak ? newStreak : stats.highestStreak;

    final newStats = Daily123Stats(
      totalGames: stats.totalGames + 1,
      totalWins: stats.totalWins + (result.isWin ? 1 : 0),
      currentStreak: newStreak,
      highestStreak: newHighest,
      history: newHistory,
    );

    await _saveStats(newStats);
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastPlayedKey, result.date.toIso8601String());
    await prefs.setBool(_adResetKey, false); // Oynadığı için reklam hakkını harcadı

    // --- GLOBAL INTEGRATION ---
    // Skorları Firestore'a kaydet (Hem günlük hem genel)
    await FirestoreService.instance.recordDaily123Result(
      result.score, 
      result.timeSeconds, 
      result.isWin
    );

    // Kullanıcının toplam skorunu da artır (Genel sıralama için)
    await FirestoreService.instance.updateGameScore(
      scoreEarned: result.score, 
      isDuel: false,
    );

    // Başarım ilerlemesini güncelle (Daily Master)
    if (newStreak > 0) {
      await AchievementService.instance.updateProgress(AchievementCategory.skill, newStreak, setExact: true);
    }

    // Görev ilerlemesini güncelle (Daily 123 Ustası)
    if (result.isWin) {
      await QuestService.instance.updateProgress(QuestType.daily123Play, 1);
    }
  }

  // Real ranking data from Firestore
  Future<Map<String, dynamic>> getRankingData({int? score, int? seconds}) async {
    final userId = AuthService.instance.userId;
    if (userId == null) return _getMockRanking();

    // Firestore'dan gerçek verileri çek
    final globalData = await FirestoreService.instance.getDaily123GlobalRanking(
      score ?? 0, 
      seconds ?? 123
    );

    // Genel sıralama hesaplama (totalScore bazlı)
    final globalRank = await FirestoreService.instance.getUserRank(userId);
    
    // Gerçek toplam kullanıcı sayısı
    final totalGlobalPlayers = await FirestoreService.instance.getTotalUsersCount();
    
    // Gerçek genel ortalama (Firestore'dan çekilebilir veya basitleştirilmiş hesaplama)
    // Şimdilik 123 için toplam skoru oyuncu sayısına bölebiliriz veya Firestore aggregate kullanabiliriz.
    final globalAvg = await FirestoreService.instance.getGlobalAverageScore();

    return {
      'dailyRank': globalData['rank'],
      'totalDailyPlayers': globalData['totalPlayers'],
      'dailyAvgPoints': globalData['avgPoints'],
      'prevPlayer': globalData['prevPlayer'],
      'nextPlayer': globalData['nextPlayer'],
      'globalRank': globalRank ?? '-',
      'totalGlobalPlayers': totalGlobalPlayers, 
      'globalAvgPoints': globalAvg,
    };
  }

  Map<String, dynamic> _getMockRanking() {
    return {
      'dailyRank': '-',
      'totalDailyPlayers': '-',
      'dailyAvgPoints': '-',
      'globalRank': '-',
      'totalGlobalPlayers': '-',
      'globalAvgPoints': '-',
    };
  }
}
