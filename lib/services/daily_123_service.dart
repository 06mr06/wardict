import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/daily_123.dart';
import 'achievement_service.dart';
import '../models/achievement.dart';
import 'shop_service.dart';

class Daily123Service {
  static final Daily123Service instance = Daily123Service._();
  Daily123Service._();

  static const String _statsKey = 'daily_123_stats';
  static const String _lastPlayedKey = 'daily_123_last_played';
  static const String _adResetKey = 'daily_123_ad_reset';

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

    // Başarım ilerlemesini güncelle (Daily Master)
    if (newStreak > 0) {
      await AchievementService.instance.updateProgress(AchievementCategory.skill, newStreak, setExact: true);
    }
  }

  // Simulated ranking data for the UI
  Future<Map<String, dynamic>> getRankingData() async {
    // In a real app, this would come from a backend.
    // For now, we return mock data based on user performance.
    return {
      'dailyRank': 12, // Mock rank
      'totalDailyPlayers': 450,
      'dailyAvgPoints': 85,
      'globalRank': 1250,
      'totalGlobalPlayers': 15000,
      'globalAvgPoints': 72,
    };
  }
}
