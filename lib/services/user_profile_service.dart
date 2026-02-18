import 'dart:convert';
import 'package:flutter/foundation.dart'; // and debugPrint
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_level.dart';
import '../models/league.dart';
import '../models/practice_session.dart';
import '../models/match_history_item.dart';
import 'firebase/auth_service.dart'; // Added import

/// Kullanıcı profili yönetimi servisi
class UserProfileService {
    /// Seviyeye göre uygun başlangıç ELO'su atar
    /// İlk 5 oyun sonrası veya seviye belirleme sonrası çağrılmalı
    Future<void> assignInitialEloByLevel(UserLevel level) async {
      final profile = await loadProfile();
      final initialElo = UserProfile.getInitialEloForLevel(level);
      final updatedProfile = profile.copyWith(eloRating: initialElo);
      await saveProfile(updatedProfile);
    }
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
    // Seviye güncellendiğinde uygun lig ELO'su ata
    await assignInitialEloByLevel(newLevel);
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



  /// Practice oturumunu günceller
  Future<void> updatePracticeSession(PracticeSession session) async {
    final profile = await loadProfile();
    final updatedProfile = profile.copyWith(practiceSession: session);
    await saveProfile(updatedProfile);
  }

  /// ELO puanını günceller (duel sonrası)
  Future<void> updateEloRating(int eloChange) async {
    final profile = await loadProfile();
    final newElo = (profile.eloRating + eloChange).clamp(100, 3000); // Min 100, Max 3000
    final updatedProfile = profile.copyWith(eloRating: newElo);
    await saveProfile(updatedProfile);
  }

  /// Lig puanını günceller
  Future<void> updateLeagueScore(League league, int eloChange) async {
    final profile = await loadProfile();
    final currentScore = profile.leagueScores.getScore(league);
    final newScore = (currentScore + eloChange).clamp(0, 3000); 
    final updatedScores = profile.leagueScores.updateScore(league, newScore);
    final updatedProfile = profile.copyWith(leagueScores: updatedScores);
    await saveProfile(updatedProfile);
  }

  /// Pratik skorunu günceller
  Future<void> updatePracticeScore(int scoreChange) async {
    final profile = await loadProfile();
    final newScore = (profile.practiceScore + scoreChange).clamp(0, 999999);
    final updatedProfile = profile.copyWith(practiceScore: newScore);
    await saveProfile(updatedProfile);
  }

  /// Kullanıcı adını günceller ve Firestore'a senkronize eder
  Future<void> updateUsername(String newUsername) async {
    final profile = await loadProfile();
    final updatedProfile = profile.copyWith(username: newUsername);
    await saveProfile(updatedProfile);
    // Hemen Firestore'a senkronize et
    await syncProfileToFirestore();
    debugPrint('🔄 Username updated to: $newUsername');
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
  
  /// Kullanıcı profili için varsayılan avatarlar (Emojiler)
  static const List<String> avatars = [
    '🦁', '🐯', '🐻', '🐨', '🐼', '🦊', '🐮', '🦋', '🐸', '🐙'
  ];

  /// Cache'i temizle (yeniden yükleme için)
  void clearCache() {
    _cachedProfile = null;
  }
  
  /// Profili yeniden yükle (cache'i temizleyerek)
  Future<UserProfile> reloadProfile() async {
    clearCache();
    return await loadProfile();
  }
  
  /// Maç sonucunu geçmişe ekler
  Future<void> addMatchHistory(MatchHistoryItem item) async {
    final profile = await loadProfile();
    final newHistory = List<MatchHistoryItem>.from(profile.matchHistory)..add(item);
    
    // Son 20 maçı tutalım
    if (newHistory.length > 20) {
      newHistory.sort((a, b) => b.date.compareTo(a.date)); // Sort desc
      newHistory.removeRange(20, newHistory.length);
    }
    
    final updatedProfile = profile.copyWith(matchHistory: newHistory);
    await saveProfile(updatedProfile);
  }

  /// Avatarı günceller
  Future<void> updateAvatar(String? avatarId) async {
    final profile = await loadProfile();
    final updatedProfile = profile.copyWith(avatarId: avatarId, clearAvatarId: avatarId == null);
    await saveProfile(updatedProfile);
  }
  
  static const String _usersCollection = 'users';
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Profili Firestore ile senkronize eder
  Future<void> syncProfileToFirestore() async {
    final profile = await loadProfile();
    
    // Auth ID al
    final userId = AuthService.instance.userId;
    if (userId == null) {
      debugPrint('⚠️ Sync failed: No authenticated user');
      return;
    }

    try {
      // Document ID olarak userId kullan
      await _firestore.collection(_usersCollection).doc(userId).set({
        ...profile.toJson(),
        'lastOnline': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      
      debugPrint('✅ Profile synced to Firestore: $userId (${profile.username})');
    } catch (e) {
      debugPrint('❌ Error syncing profile to Firestore: $e');
    }
  }
}
