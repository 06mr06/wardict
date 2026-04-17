import 'dart:convert';
import 'package:flutter/foundation.dart'; // and debugPrint
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_level.dart';
import '../models/league.dart';
import '../models/premium.dart';
import '../models/practice_session.dart';
import '../models/match_history_item.dart';
import 'firebase/auth_service.dart'; // Added import
import 'shop_service.dart';

/// Kullanıcı profili yönetimi servisi
class UserProfileService {
    /// Seviyeye göre uygun başlangıç LP'si atar
    /// İlk 5 oyun sonrası veya seviye belirleme sonrası çağrılmalı
    Future<void> assignInitialLpByLevel(UserLevel level) async {
      final profile = await loadProfile();
      final initialLp = UserProfile.getInitialLpForLevel(level);
      final updatedProfile = profile.copyWith(lpRating: initialLp);
      await saveProfile(updatedProfile);
    }
  static UserProfileService? _instance;
  static UserProfileService get instance => _instance ??= UserProfileService._();

  UserProfileService._();

  /// Tüm servis durumunu ve cache'i temizle (çıkış yapıldığında çağrılmalı)
  static void clearAll() {
    _instance = null;
  }

  static const String _profileKey = 'user_profile';
  static const String _hasCompletedTestKey = 'has_completed_placement_test';
  static const String _lastLeagueResetKey = 'last_league_reset_date_v1';

  UserProfile? _cachedProfile;

  /// Kullanıcı profilini yükler
  Future<UserProfile> loadProfile() async {
    // Cache varsa ve kullanıcı emaili ile uyumluysa cache döndür
    final authEmail = AuthService.instance.userEmail;
    if (_cachedProfile != null) {
      if (authEmail == null || _cachedProfile!.email == authEmail) {
        return _cachedProfile!;
      }
      // E-posta uyumsuzsa cache geçersizdir
      _cachedProfile = null;
    }

    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_profileKey);

    if (jsonString != null) {
      try {
        final json = jsonDecode(jsonString) as Map<String, dynamic>;
        final profile = UserProfile.fromJson(json);
        
        // KONTROL: Eğer yereldeki profil başka bir kullanıcıya aitse (veya misafir profili değilse ve email farklıysa)
        if (authEmail != null && profile.email != authEmail) {
          debugPrint('⚠️ Yerel profil farklı bir kullanıcıya ait (${profile.email} != $authEmail). Yeni profil oluşturuluyor.');
          _cachedProfile = UserProfile(email: authEmail);
          // Yanlış veriyi hemen üzerine yazalım
          await saveProfile(_cachedProfile!);
        } else {
          _cachedProfile = profile;
          // Eğer profilin emaili yoksa ve kullanıcı giriş yapmışsa emaili ekleyelim (Guest -> User geçişi)
          if (_cachedProfile!.email == null && authEmail != null) {
            _cachedProfile = _cachedProfile!.copyWith(email: authEmail);
            await saveProfile(_cachedProfile!);
          }
        }
      } catch (e) {
        debugPrint('❌ Profil çözümlenirken hata: $e');
        _cachedProfile = UserProfile(email: authEmail);
      }
    } else {
      _cachedProfile = UserProfile(email: authEmail);
    }

    return _cachedProfile!;
  }

  /// Haftalık lig puanını kontrol eder ve gerekirse sıfırlar.
  /// Uygulama her açıldığında WelcomeScreen'den çağrılmalı.
  Future<UserProfile> checkAndResetWeeklyLeague(UserProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    final lastResetStr = prefs.getString(_lastLeagueResetKey);
    final now = DateTime.now();

    if (lastResetStr == null) {
      // İlk çalıştırma, tarihi kaydet ve devam et.
      await prefs.setString(_lastLeagueResetKey, now.toIso8601String());
      return profile;
    }

    final lastResetDate = DateTime.parse(lastResetStr);
    // Son sıfırlamadan bu yana 7 günden fazla geçtiyse VEYA yeni bir haftanın Pazartesi günüyse
    if (now.difference(lastResetDate).inDays >= 7 || (now.weekday == DateTime.monday && now.day != lastResetDate.day)) {
      // Lig puanını (totalScore) sıfırla ve galibiyet serisini de sıfırla
      final updatedProfile = profile.copyWith(totalScore: 0, duelWinStreak: 0);
      await saveProfile(updatedProfile);
      await prefs.setString(_lastLeagueResetKey, now.toIso8601String());
      return updatedProfile;
    }
    return profile;
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
    await syncProfileToFirestore();
    // Seviye güncellendiğinde uygun lig LP'si ata
    await assignInitialLpByLevel(newLevel);
  }

  /// Oyun sonrası profili günceller
  Future<void> updateAfterGame({
    required int scoreEarned,
    UserLevel? newLevel,
  }) async {
    final profile = await loadProfile();
    final now = DateTime.now();
    
    // Günlük seri (Streak) mantığı
    int newStreak = profile.dailyStreak;
    final lastPlayed = profile.lastPlayed;
    
    if (lastPlayed != null) {
      final nowDay = DateTime(now.year, now.month, now.day);
      final lastPlayDay = DateTime(lastPlayed.year, lastPlayed.month, lastPlayed.day);
      final diff = nowDay.difference(lastPlayDay).inDays;
      
      if (diff == 1) {
        // Dün oynamış, seriyi artır
        newStreak++;
      } else if (diff > 1) {
        // Arada gün geçmiş, seriyi 1'e çek
        newStreak = 1;
      }
      // Aynı gün (diff == 0) ise seriyi değiştirme
    } else {
      newStreak = 1;
    }

    final updatedProfile = profile.copyWith(
      level: newLevel ?? profile.level,
      totalScore: profile.totalScore + scoreEarned,
      gamesPlayed: profile.gamesPlayed + 1,
      lastPlayed: now,
      dailyStreak: newStreak,
    );
    await saveProfile(updatedProfile);
    await syncProfileToFirestore();
  }



  /// Practice oturumunu günceller
  Future<void> updatePracticeSession(PracticeSession session) async {
    final profile = await loadProfile();
    final updatedProfile = profile.copyWith(
      practiceSession: session,
      lastPlayed: DateTime.now(), // Senkronizasyon için tarihi her zaman güncelle
    );
    await saveProfile(updatedProfile);
    await syncProfileToFirestore();
  }

  /// Yanlış kelimeler listesini günceller (SRS için)
  Future<void> updateWrongWords(List<String> words) async {
    final profile = await loadProfile();
    // Liste çok büyürse (örn: 200+) en eskileri temizle
    List<String> updatedList = words.toSet().toList(); // Tekil yap
    if (updatedList.length > 200) {
      updatedList = updatedList.sublist(updatedList.length - 200);
    }
    final updatedProfile = profile.copyWith(wrongWords: updatedList);
    await saveProfile(updatedProfile);
    await syncProfileToFirestore();
  }

  /// LP puanını günceller (duel sonrası)
  Future<void> updateLpRating(int lpChange) async {
    final profile = await loadProfile();
    final newLp = (profile.lpRating + lpChange).clamp(100, 3000); // Min 100, Max 3000
    final updatedProfile = profile.copyWith(lpRating: newLp);
    await saveProfile(updatedProfile);
  }

  /// Lig puanını günceller
  Future<void> updateLeagueScore(League league, int lpChange) async {
    final profile = await loadProfile();
    final currentScore = profile.leagueScores.getScore(league);
    final newScore = (currentScore + lpChange).clamp(0, 3000); 
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

  /// Kategori bazlı istatistikleri günceller
  Future<void> updateCategoryStats(String category, bool isCorrect) async {
    final profile = await loadProfile();
    final currentStats = Map<String, Map<String, int>>.from(
      profile.categoryStats.map((k, v) => MapEntry(k, Map<String, int>.from(v))),
    );

    if (!currentStats.containsKey(category)) {
      currentStats[category] = {'correct': 0, 'wrong': 0};
    }

    final catStats = currentStats[category]!;
    if (isCorrect) {
      catStats['correct'] = (catStats['correct'] ?? 0) + 1;
    } else {
      catStats['wrong'] = (catStats['wrong'] ?? 0) + 1;
    }

    final updatedProfile = profile.copyWith(categoryStats: currentStats);
    await saveProfile(updatedProfile);
    // Genelde toplu senkronizasyon yapılıyor ama önemli veri olduğu için tetikleyebiliriz
    await syncProfileToFirestore();
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

  /// Yanlış kelimeyi SRS listesine ekler
  Future<void> addWrongWord(String word) async {
    final profile = await loadProfile();
    if (!profile.wrongWords.contains(word)) {
      final updatedWords = List<String>.from(profile.wrongWords)..add(word);
      await saveProfile(profile.copyWith(wrongWords: updatedWords));
    }
  }

  /// Tüm verileri yerel olarak sıfırla (Çıkış yapıldığında çağrılmalı)
  Future<void> clearLocalData() async {
    _cachedProfile = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_profileKey);
    await prefs.remove(_hasCompletedTestKey);
    await prefs.remove(_lastLeagueResetKey);
    debugPrint('🧹 Yerel profil verileri temizlendi');
  }

  /// Tüm verileri sıfırla (test amaçlı)
  Future<void> resetAll() async {
    await clearLocalData();
  }

  /// Mevcut kullanıcı seviyesini döndürür
  Future<UserLevel> getCurrentLevel() async {
    final profile = await loadProfile();
    return profile.level;
  }
  
  /// Kullanıcı profili için varsayılan avatarlar
  static const List<String> avatars = [
    'assets/images/avatars/dino_nerd.png',
    'assets/images/avatars/dino_sleepy.png',
    'assets/images/avatars/dino_cowboy.png',
    'assets/images/avatars/dino_artist.png',
    'assets/images/avatars/dino_farmer.png',
    'assets/images/avatars/dino_rocker.png',
    'assets/images/avatars/dino_ninja.png',
    'assets/images/avatars/dino_chef.png',
    'assets/images/avatars/dino_king.png',
    'assets/images/avatars/dino_astronaut.png',
    'assets/images/avatars/dino_librarian.png',
    'assets/images/avatars/dino_wizard.png',
    'assets/images/avatars/dino_painter.png',
    'assets/images/avatars/dino_footballer.png',
    'assets/images/avatars/dino_detective.png',
    'assets/images/avatars/dino_scientist.png',
    'assets/images/avatars/dino_doctor.png',
    'assets/images/avatars/dino_cyber.png',
    'assets/images/avatars/dino_peaceful.png',
    'assets/images/avatars/dino_thunder.png',
    'assets/images/avatars/dino_red_wing.png',
    '🦁', '🐯', '🐻', '🐨', '🐼'
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

  Future<void> updateAvatar(String? avatarId) async {
    final profile = await loadProfile();
    // Avatar seçilince profil fotoğrafını temizle (münhasırlık)
    final updatedProfile = profile.copyWith(
      avatarId: avatarId, 
      clearAvatarId: avatarId == null,
      clearProfileImagePath: avatarId != null
    );
    await saveProfile(updatedProfile);
    await syncProfileToFirestore();
  }

  /// Çerçeveyi günceller
  Future<void> updateFrame(String? frameId) async {
    final profile = await loadProfile();
    final updatedProfile = profile.copyWith(
      frameId: frameId,
      clearFrameId: frameId == null,
    );
    await saveProfile(updatedProfile);
    await syncProfileToFirestore();
  }

  /// Profil fotoğrafını günceller
  Future<void> updateProfileImage(String? imagePath) async {
    final profile = await loadProfile();
    // Profil fotoğrafı seçilince avatarı temizle
    final updatedProfile = profile.copyWith(
      profileImagePath: imagePath,
      clearProfileImagePath: imagePath == null,
      clearAvatarId: imagePath != null
    );
    await saveProfile(updatedProfile);
  }
  
  static const String _usersCollection = 'users';
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Profili Firestore ile senkronize eder
  Future<void> syncProfileToFirestore() async {
    // Önce premium durumunu ShopService'den al ve profile yansıt
    final profile = await loadProfile();
    final subscription = await ShopService.instance.getSubscription();
    final isPremium = subscription.isActive;
    
    final updatedProfile = profile.copyWith(isPremium: isPremium);
    if (profile.isPremium != isPremium) {
      await saveProfile(updatedProfile);
    }
    
    // Auth ID al
    final userId = AuthService.instance.userId;
    if (userId == null) return;

    try {
      final json = updatedProfile.toJson();
      // Önemli: null olan kritik alanları sil (Firestore'u null ile ezmesin)
      if (json['email'] == null) json.remove('email');
      
      // Document ID olarak userId kullan
      await _firestore.collection(_usersCollection).doc(userId).set({
        ...json,
        'lastOnline': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      
      debugPrint('✅ Profile synced to Firestore: $userId (${updatedProfile.username})');
    } catch (e) {
      debugPrint('❌ Error syncing profile to Firestore: $e');
    }
  }

  /// Profili Firestore'dan çeker (Giriş sonrası)
  Future<void> fetchProfileFromFirestore() async {
    final userId = AuthService.instance.userId;
    if (userId == null) return;

    try {
      final doc = await _firestore.collection(_usersCollection).doc(userId).get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        final remoteProfile = UserProfile.fromJson(data);
        
        // Mevcut yerel profili al
        final localProfile = await loadProfile();
        
        // KONTROL: Eğer yerel profil mevcut kullanıcıya ait değilse senkronizasyon yapma, 
        // doğrudan buluttakini kullan.
        final authEmail = AuthService.instance.userEmail;
        if (authEmail != null && localProfile.email != authEmail) {
          debugPrint('⚠️ Yerel profil farklı bir kullanıcıya ait. Bulut verisi ile eziliyor.');
          await saveProfile(remoteProfile);
          return;
        }

        // SENKRONİZASYON KONTROLÜ: 
        // Sadece uzak veri daha yeniyse yerel veriyi güncelle (veya yerel veri "boş" ise)
        final remoteLastPlayed = remoteProfile.lastPlayed ?? DateTime(2000);
        final localHistoryEmpty = localProfile.matchHistory.isEmpty;

        if (remoteLastPlayed.isAfter(localProfile.lastPlayed ?? DateTime(1999)) || localHistoryEmpty) {
          debugPrint('🔄 Remote profile is newer or local is empty. Updating local profile.');
          await saveProfile(remoteProfile);
          
          if (remoteProfile.isPremium) {
            await ShopService.instance.activatePremium(PremiumTier.premium, 30);
          }
        } else {
          debugPrint('ℹ️ Local profile is newer. Merging and syncing up.');
          // Eğer yerel daha yeniyse, buluta gönderelim (birleştirme mantığı daha komplex olabilir ama şimdilik sync yeterli)
          await syncProfileToFirestore();
        }
      } else {
        // Kullanıcı Firestore'da yok (Yeni kullanıcı)
        debugPrint('🆕 User does not exist in Firestore. Creating new profile in cloud.');
        await syncProfileToFirestore();
      }
    } catch (e) {
      debugPrint('❌ Error fetching profile from Firestore: $e');
    }
  }
}
