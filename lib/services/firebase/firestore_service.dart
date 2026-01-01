import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../models/user_level.dart';
import '../../models/league.dart';
import '../../models/practice_session.dart';
import 'auth_service.dart';

/// Firestore kullanıcı profili modeli
class CloudUserProfile {
  final String odlevel;
  final String level;
  final String username;
  final String? email;
  final int totalScore;
  final int practiceScore;
  final int gamesPlayed;
  final int duelWins;
  final int duelLosses;
  final Map<String, int> leagueScores;
  final List<String> achievements;
  final List<String> friends;
  final DateTime createdAt;
  final DateTime lastPlayedAt;
  final String? avatarId;
  final String? photoURL;

  CloudUserProfile({
    required this.odlevel,
    required this.level,
    required this.username,
    this.email,
    this.totalScore = 0,
    this.practiceScore = 0,
    this.gamesPlayed = 0,
    this.duelWins = 0,
    this.duelLosses = 0,
    this.leagueScores = const {},
    this.achievements = const [],
    this.friends = const [],
    DateTime? createdAt,
    DateTime? lastPlayedAt,
    this.avatarId,
    this.photoURL,
  })  : createdAt = createdAt ?? DateTime.now(),
        lastPlayedAt = lastPlayedAt ?? DateTime.now();

  factory CloudUserProfile.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CloudUserProfile(
      odlevel: doc.id,
      level: data['level'] ?? 'A1',
      username: data['username'] ?? 'Player',
      email: data['email'],
      totalScore: data['totalScore'] ?? 0,
      practiceScore: data['practiceScore'] ?? 0,
      gamesPlayed: data['gamesPlayed'] ?? 0,
      duelWins: data['duelWins'] ?? 0,
      duelLosses: data['duelLosses'] ?? 0,
      leagueScores: Map<String, int>.from(data['leagueScores'] ?? {}),
      achievements: List<String>.from(data['achievements'] ?? []),
      friends: List<String>.from(data['friends'] ?? []),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      lastPlayedAt: (data['lastPlayedAt'] as Timestamp?)?.toDate(),
      avatarId: data['avatarId'],
      photoURL: data['photoURL'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'level': level,
      'username': username,
      'email': email,
      'totalScore': totalScore,
      'practiceScore': practiceScore,
      'gamesPlayed': gamesPlayed,
      'duelWins': duelWins,
      'duelLosses': duelLosses,
      'leagueScores': leagueScores,
      'achievements': achievements,
      'friends': friends,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastPlayedAt': Timestamp.fromDate(lastPlayedAt),
      'avatarId': avatarId,
      'photoURL': photoURL,
    };
  }

  CloudUserProfile copyWith({
    String? level,
    String? username,
    int? totalScore,
    int? practiceScore,
    int? gamesPlayed,
    int? duelWins,
    int? duelLosses,
    Map<String, int>? leagueScores,
    List<String>? achievements,
    List<String>? friends,
    DateTime? lastPlayedAt,
    String? avatarId,
    String? photoURL,
  }) {
    return CloudUserProfile(
      odlevel: odlevel,
      level: level ?? this.level,
      username: username ?? this.username,
      totalScore: totalScore ?? this.totalScore,
      practiceScore: practiceScore ?? this.practiceScore,
      gamesPlayed: gamesPlayed ?? this.gamesPlayed,
      duelWins: duelWins ?? this.duelWins,
      duelLosses: duelLosses ?? this.duelLosses,
      leagueScores: leagueScores ?? this.leagueScores,
      achievements: achievements ?? this.achievements,
      friends: friends ?? this.friends,
      createdAt: createdAt,
      lastPlayedAt: lastPlayedAt ?? this.lastPlayedAt,
      avatarId: avatarId ?? this.avatarId,
      photoURL: photoURL ?? this.photoURL,
    );
  }
}

/// Firestore veritabanı servisi
class FirestoreService {
  static FirestoreService? _instance;
  static FirestoreService get instance => _instance ??= FirestoreService._();

  FirestoreService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Collection referansları
  CollectionReference<Map<String, dynamic>> get _usersCollection =>
      _db.collection('users');

  CollectionReference<Map<String, dynamic>> get _leaderboardCollection =>
      _db.collection('leaderboard');

  // ==================== KULLANICI PROFİLİ ====================

  /// Kullanıcı profilini getir
  Future<CloudUserProfile?> getUserProfile(String odlevel) async {
    try {
      final doc = await _usersCollection.doc(odlevel).get();
      if (doc.exists) {
        return CloudUserProfile.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      debugPrint('❌ Profil getirme hatası: $e');
      return null;
    }
  }

  /// Mevcut kullanıcının profilini getir
  Future<CloudUserProfile?> getCurrentUserProfile() async {
    final odlevel = AuthService.instance.userId;
    if (odlevel == null) return null;
    return getUserProfile(odlevel);
  }

  /// Kullanıcı profili oluştur
  Future<void> createUserProfile({
    required String odlevel,
    required String username,
    String? email,
    String level = 'A1',
  }) async {
    try {
      final profile = CloudUserProfile(
        odlevel: odlevel,
        level: level,
        username: username,
        email: email,
      );

      await _usersCollection.doc(odlevel).set(profile.toFirestore());
      debugPrint('✅ Kullanıcı profili oluşturuldu: $odlevel ($username - $email)');
    } catch (e) {
      debugPrint('❌ Profil oluşturma hatası: $e');
      rethrow;
    }
  }

  /// Kullanıcı adının benzersiz olup olmadığını kontrol et
  Future<bool> isUsernameUnique(String username) async {
    try {
      final query = await _usersCollection
          .where('username', isEqualTo: username)
          .limit(1)
          .get();
      
      // Eğer sonuç yoksa veya sadece mevcut kullanıcıya aitse unique
      if (query.docs.isEmpty) {
        return true;
      }
      
      // Mevcut kullanıcının kendisi mi kontrol et
      final currentUserId = AuthService.instance.userId;
      if (query.docs.first.id == currentUserId) {
        return true;
      }
      
      return false;
    } catch (e) {
      debugPrint('❌ Username kontrol hatası: $e');
      return false;
    }
  }
  
  /// Kullanıcı adını güncelle
  Future<void> updateUsername(String newUsername) async {
    final odlevel = AuthService.instance.userId;
    if (odlevel == null) return;
    
    try {
      await _usersCollection.doc(odlevel).update({
        'username': newUsername,
        'lastPlayedAt': FieldValue.serverTimestamp(),
      });
      debugPrint('✅ Kullanıcı adı güncellendi: $newUsername');
    } catch (e) {
      debugPrint('❌ Kullanıcı adı güncelleme hatası: $e');
      rethrow;
    }
  }

  /// Kullanıcı profilini güncelle
  Future<void> updateUserProfile(String odlevel, Map<String, dynamic> data) async {
    try {
      data['lastPlayedAt'] = FieldValue.serverTimestamp();
      await _usersCollection.doc(odlevel).update(data);
      debugPrint('✅ Profil güncellendi');
    } catch (e) {
      debugPrint('❌ Profil güncelleme hatası: $e');
      rethrow;
    }
  }

  /// Oyun sonrası skor güncelle
  Future<void> updateGameScore({
    required int scoreEarned,
    required bool isDuel,
    bool? duelWon,
    String? leagueId,
    int? eloChange,
  }) async {
    final odlevel = AuthService.instance.userId;
    if (odlevel == null) return;

    final updates = <String, dynamic>{
      'totalScore': FieldValue.increment(scoreEarned),
      'gamesPlayed': FieldValue.increment(1),
    };

    if (isDuel && duelWon != null) {
      if (duelWon) {
        updates['duelWins'] = FieldValue.increment(1);
      } else {
        updates['duelLosses'] = FieldValue.increment(1);
      }
    }

    if (leagueId != null && eloChange != null) {
      updates['leagueScores.$leagueId'] = FieldValue.increment(eloChange);
    }

    await updateUserProfile(odlevel, updates);
  }

  /// Practice skor güncelle
  Future<void> updatePracticeScore(int scoreChange) async {
    final odlevel = AuthService.instance.userId;
    if (odlevel == null) return;

    await updateUserProfile(odlevel, {
      'practiceScore': FieldValue.increment(scoreChange),
    });
  }

  /// Seviye güncelle
  Future<void> updateLevel(String newLevel) async {
    final odlevel = AuthService.instance.userId;
    if (odlevel == null) return;

    await updateUserProfile(odlevel, {'level': newLevel});
  }

  // ==================== LİDERLİK TABLOSU ====================

  /// Global liderlik tablosunu getir
  Future<List<CloudUserProfile>> getLeaderboard({
    int limit = 100,
    String sortBy = 'totalScore',
  }) async {
    try {
      final snapshot = await _usersCollection
          .orderBy(sortBy, descending: true)
          .limit(limit)
          .get();

      return snapshot.docs
          .map((doc) => CloudUserProfile.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('❌ Liderlik tablosu hatası: $e');
      return [];
    }
  }

  /// Lig bazlı liderlik tablosu
  Future<List<CloudUserProfile>> getLeagueLeaderboard(
    String leagueId, {
    int limit = 50,
  }) async {
    try {
      final snapshot = await _usersCollection
          .orderBy('leagueScores.$leagueId', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs
          .map((doc) => CloudUserProfile.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('❌ Lig liderlik tablosu hatası: $e');
      return [];
    }
  }

  /// Kullanıcının sıralamasını getir
  Future<int?> getUserRank(String odlevel, {String sortBy = 'totalScore'}) async {
    try {
      final userDoc = await _usersCollection.doc(odlevel).get();
      if (!userDoc.exists) return null;

      final userScore = (userDoc.data()?[sortBy] ?? 0) as int;

      final higherScores = await _usersCollection
          .where(sortBy, isGreaterThan: userScore)
          .count()
          .get();

      return (higherScores.count ?? 0) + 1;
    } catch (e) {
      debugPrint('❌ Sıralama hatası: $e');
      return null;
    }
  }

  /// Lig bazlı kullanıcı sıralamasını getir (A, B, C ligleri için)
  Future<Map<String, int>> getUserLeagueRanks(String odlevel) async {
    try {
      final userDoc = await _usersCollection.doc(odlevel).get();
      if (!userDoc.exists) return {'A': 0, 'B': 0, 'C': 0};

      final leagueScores = Map<String, int>.from(userDoc.data()?['leagueScores'] ?? {});
      final ranks = <String, int>{};

      for (final league in ['A', 'B', 'C']) {
        final userScore = leagueScores[league] ?? 1500;
        
        // Bu ligdeki daha yüksek skorları say
        final snapshot = await _usersCollection.get();
        int higherCount = 0;
        
        for (final doc in snapshot.docs) {
          final docScores = Map<String, int>.from(doc.data()['leagueScores'] ?? {});
          final docScore = docScores[league] ?? 1500;
          if (docScore > userScore) {
            higherCount++;
          }
        }
        
        ranks[league] = higherCount + 1;
      }

      return ranks;
    } catch (e) {
      debugPrint('❌ Lig sıralaması hatası: $e');
      return {'A': 0, 'B': 0, 'C': 0};
    }
  }

  // ==================== ARKADAŞLAR ====================

  /// Arkadaş ekle
  Future<void> addFriend(String friendId) async {
    final odlevel = AuthService.instance.userId;
    if (odlevel == null) return;

    await _usersCollection.doc(odlevel).update({
      'friends': FieldValue.arrayUnion([friendId]),
    });

    // Karşılıklı arkadaşlık
    await _usersCollection.doc(friendId).update({
      'friends': FieldValue.arrayUnion([odlevel]),
    });
  }

  /// Arkadaş çıkar
  Future<void> removeFriend(String friendId) async {
    final odlevel = AuthService.instance.userId;
    if (odlevel == null) return;

    await _usersCollection.doc(odlevel).update({
      'friends': FieldValue.arrayRemove([friendId]),
    });

    await _usersCollection.doc(friendId).update({
      'friends': FieldValue.arrayRemove([odlevel]),
    });
  }

  /// Arkadaş listesini getir
  Future<List<CloudUserProfile>> getFriends() async {
    final odlevel = AuthService.instance.userId;
    if (odlevel == null) return [];

    final profile = await getUserProfile(odlevel);
    if (profile == null || profile.friends.isEmpty) return [];

    final friends = <CloudUserProfile>[];
    for (final friendId in profile.friends) {
      final friendProfile = await getUserProfile(friendId);
      if (friendProfile != null) {
        friends.add(friendProfile);
      }
    }

    return friends;
  }

  /// Kullanıcı adına göre ara
  Future<List<CloudUserProfile>> searchUsers(String query) async {
    if (query.length < 3) return [];

    try {
      final snapshot = await _usersCollection
          .where('username', isGreaterThanOrEqualTo: query)
          .where('username', isLessThanOrEqualTo: '$query\uf8ff')
          .limit(20)
          .get();

      return snapshot.docs
          .map((doc) => CloudUserProfile.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('❌ Kullanıcı arama hatası: $e');
      return [];
    }
  }

  // ==================== BAŞARIMLAR ====================

  /// Başarım ekle
  Future<void> addAchievement(String achievementId) async {
    final odlevel = AuthService.instance.userId;
    if (odlevel == null) return;

    await _usersCollection.doc(odlevel).update({
      'achievements': FieldValue.arrayUnion([achievementId]),
    });
  }

  /// Lokal profili cloud'a senkronize et
  Future<void> syncFromLocal(UserProfile localProfile) async {
    final odlevel = AuthService.instance.userId;
    if (odlevel == null) return;

    final cloudProfile = await getUserProfile(odlevel);
    
    // Cloud profil yoksa oluştur
    if (cloudProfile == null) {
      await createUserProfile(
        odlevel: odlevel,
        username: localProfile.username,
        level: localProfile.level.code,
      );
      
      // Tüm lokal veriyi yükle
      await updateUserProfile(odlevel, {
        'totalScore': localProfile.totalScore,
        'practiceScore': localProfile.practiceScore,
        'gamesPlayed': localProfile.gamesPlayed,
        'avatarId': localProfile.avatarId,
      });
    } else {
      // Mevcut cloud profili lokal ile birleştir (en yüksek skorları tut)
      await updateUserProfile(odlevel, {
        'totalScore': cloudProfile.totalScore > localProfile.totalScore 
            ? cloudProfile.totalScore 
            : localProfile.totalScore,
        'practiceScore': cloudProfile.practiceScore > localProfile.practiceScore
            ? cloudProfile.practiceScore
            : localProfile.practiceScore,
        'gamesPlayed': cloudProfile.gamesPlayed > localProfile.gamesPlayed
            ? cloudProfile.gamesPlayed
            : localProfile.gamesPlayed,
      });
    }

    debugPrint('✅ Lokal profil senkronize edildi');
  }
}
