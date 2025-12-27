import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_level.dart';
import '../models/league.dart';
import '../models/practice_session.dart';

/// Kullanıcı profili yönetimi servisi
class UserProfileService {
  static UserProfileService? _instance;
  static UserProfileService get instance => _instance ??= UserProfileService._();

  UserProfileService._();

  static const String _profileKey = 'user_profile';
  static const String _hasCompletedTestKey = 'has_completed_placement_test';

  UserProfile? _cachedProfile;

  /// Kullanıcı profilini yükler
  Future<UserProfile> loadProfile() async {
    if (_cachedProfile != null) return _cachedProfile!;

    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_profileKey);

    if (jsonString != null) {
      try {
        final json = jsonDecode(jsonString) as Map<String, dynamic>;
        _cachedProfile = UserProfile.fromJson(json);
      } catch (e) {
        _cachedProfile = UserProfile();
      }
    } else {
      _cachedProfile = UserProfile();
    }

    return _cachedProfile!;
  }

  /// Kullanıcı profilini kaydeder
  Future<void> saveProfile(UserProfile profile) async {
    _cachedProfile = profile;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_profileKey, jsonEncode(profile.toJson()));
  }

  /// Kullanıcı seviyesini günceller
  Future<void> updateLevel(UserLevel newLevel) async {
    final profile = await loadProfile();
    final updatedProfile = profile.copyWith(level: newLevel);
    await saveProfile(updatedProfile);
  }

  /// Oyun sonrası profili günceller
  Future<void> updateAfterGame({
    required int scoreEarned,
    UserLevel? newLevel,
  }) async {
    final profile = await loadProfile();
    final updatedProfile = profile.copyWith(
      level: newLevel ?? profile.level,
      totalScore: profile.totalScore + scoreEarned,
      gamesPlayed: profile.gamesPlayed + 1,
      lastPlayed: DateTime.now(),
    );
    await saveProfile(updatedProfile);
  }

  /// Practice puanı günceller
  Future<void> updatePracticeScore(int scoreChange) async {
    final profile = await loadProfile();
    final newScore = (profile.practiceScore + scoreChange).clamp(0, 999999);
    final updatedProfile = profile.copyWith(practiceScore: newScore);
    await saveProfile(updatedProfile);
  }

  /// Practice oturumunu günceller
  Future<void> updatePracticeSession(PracticeSession session) async {
    final profile = await loadProfile();
    final updatedProfile = profile.copyWith(practiceSession: session);
    await saveProfile(updatedProfile);
  }

  /// Lig puanını günceller (duel sonrası)
  Future<void> updateLeagueScore(League league, int eloChange) async {
    final profile = await loadProfile();
    final currentScore = profile.leagueScores.getScore(league);
    final newScore = (currentScore + eloChange).clamp(100, 3000); // Min 100, Max 3000
    final updatedScores = profile.leagueScores.updateScore(league, newScore);
    final updatedProfile = profile.copyWith(leagueScores: updatedScores);
    await saveProfile(updatedProfile);
  }

  /// Seviye belirleme testinin tamamlanıp tamamlanmadığını kontrol eder
  Future<bool> hasCompletedPlacementTest() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_hasCompletedTestKey) ?? false;
  }

  /// Seviye belirleme testinin tamamlandığını işaretle
  Future<void> markPlacementTestCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_hasCompletedTestKey, true);
  }

  /// Tüm verileri sıfırla (test amaçlı)
  Future<void> resetAll() async {
    _cachedProfile = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_profileKey);
    await prefs.remove(_hasCompletedTestKey);
  }

  /// Mevcut kullanıcı seviyesini döndürür
  Future<UserLevel> getCurrentLevel() async {
    final profile = await loadProfile();
    return profile.level;
  }
  
  /// Cache'i temizle (yeniden yükleme için)
  void clearCache() {
    _cachedProfile = null;
  }
}
