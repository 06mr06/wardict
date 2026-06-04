import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../models/user_level.dart';
import 'auth_service.dart';
import '../online_duel_service.dart';

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
  final int weeklyGained;
  final DateTime createdAt;
  final DateTime lastPlayedAt;
  final String? avatarId;
  final String? photoURL;
  final int coins;
  final String? frameId;
  final bool isOnline;
  final bool hasReceivedWelcomeGift;

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
    this.leagueScores = const {'A': 1500, 'B': 1500, 'C': 1500},
    this.achievements = const [],
    this.friends = const [],
    this.weeklyGained = 0,
    DateTime? createdAt,
    DateTime? lastPlayedAt,
    this.avatarId,
    this.photoURL,
    this.coins = 0,
    this.frameId,
    this.isOnline = false,
    this.hasReceivedWelcomeGift = false,
  })  : createdAt = createdAt ?? DateTime.now(),
        lastPlayedAt = lastPlayedAt ?? DateTime.now();

  factory CloudUserProfile.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final rawCreatedAt = data['createdAt'];
    final rawLastPlayedAt = data['lastPlayedAt'];
    
    return CloudUserProfile(
      odlevel: doc.id,
      level: data['level'] ?? 'A1',
      username: data['username'] ?? 'Player',
      email: data['email'],
      totalScore: (data['totalScore'] as num?)?.toInt() ?? 0,
      practiceScore: (data['practiceScore'] as num?)?.toInt() ?? 0,
      gamesPlayed: (data['gamesPlayed'] as num?)?.toInt() ?? 0,
      duelWins: (data['duelWins'] as num?)?.toInt() ?? 0,
      duelLosses: (data['duelLosses'] as num?)?.toInt() ?? 0,
      leagueScores: (data['leagueScores'] != null && (data['leagueScores'] as Map).isNotEmpty)
          ? Map<String, int>.from(data['leagueScores'])
          : const {'A': 1500, 'B': 1500, 'C': 1500},
      achievements: List<String>.from(data['achievements'] ?? []),
      friends: List<String>.from(data['friends'] ?? []),
      weeklyGained: (data['weeklyGained'] as num?)?.toInt() ?? 0,
      createdAt: (rawCreatedAt is Timestamp) 
          ? rawCreatedAt.toDate() 
          : (rawCreatedAt is String ? DateTime.tryParse(rawCreatedAt) : null) ?? DateTime.now(),
      lastPlayedAt: (rawLastPlayedAt is Timestamp) 
          ? rawLastPlayedAt.toDate() 
          : (rawLastPlayedAt is String ? DateTime.tryParse(rawLastPlayedAt) : null) ?? DateTime.now(),
      avatarId: data['avatarId'],
      photoURL: data['photoURL'] ?? data['profileImagePath'],
      coins: (data['coins'] as num?)?.toInt() ?? 0,
      frameId: data['frameId'],
      isOnline: false,
      hasReceivedWelcomeGift: data['hasReceivedWelcomeGift'] ?? false,
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
      'weeklyGained': weeklyGained,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastPlayedAt': Timestamp.fromDate(lastPlayedAt),
      'avatarId': avatarId,
      'photoURL': photoURL,
      'coins': coins,
      'frameId': frameId,
      'hasReceivedWelcomeGift': hasReceivedWelcomeGift,
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
    int? weeklyGained,
    DateTime? lastPlayedAt,
    String? avatarId,
    String? photoURL,
    int? coins,
    String? frameId,
    bool? isOnline,
    bool? hasReceivedWelcomeGift,
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
      weeklyGained: weeklyGained ?? this.weeklyGained,
      createdAt: createdAt,
      lastPlayedAt: lastPlayedAt ?? this.lastPlayedAt,
      avatarId: avatarId ?? this.avatarId,
      photoURL: photoURL ?? this.photoURL,
      coins: coins ?? this.coins,
      frameId: frameId ?? this.frameId,
      isOnline: isOnline ?? this.isOnline,
      hasReceivedWelcomeGift: hasReceivedWelcomeGift ?? this.hasReceivedWelcomeGift,
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

  // ignore: unused_element - Leaderboard için saklanıyor
  CollectionReference<Map<String, dynamic>> get _leaderboardCollection =>
      _db.collection('leaderboard');

  CollectionReference<Map<String, dynamic>> get _daily123Collection =>
      _db.collection('daily_123_results');

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
      
      // Eğer sonuç yoksa unique
      if (query.docs.isEmpty) {
        return true;
      }
      
      // Mevcut kullanıcının kendisi mi kontrol et
      final currentUserId = AuthService.instance.userId;
      if (currentUserId != null && query.docs.first.id == currentUserId) {
        return true;
      }
      
      return false;
    } catch (e) {
      debugPrint('❌ Username kontrol hatası: $e');
      return true;
    }
  }

  /// Toplam kullanıcı sayısını getir
  Future<int> getTotalUsersCount() async {
    try {
      final query = await _usersCollection.count().get();
      return query.count ?? 1;
    } catch (e) {
      return 1; // Hata durumunda en az 1 oyuncu (sen)
    }
  }

  /// Genel ortalama skoru hesapla
  Future<int> getGlobalAverageScore() async {
    try {
      // Not: cloud_firestore aggregate desteği (average) kullanılabilir.
      // Eğer mevcut değilse döküman sayısına bölerek basit bir hesaplama yapılır.
      final totalScoreQuery = await _usersCollection.aggregate(sum('totalScore')).get();
      final totalPlayers = await getTotalUsersCount();
      
      if (totalPlayers == 0) return 0;
      final totalScore = (totalScoreQuery.getSum('totalScore') ?? 0).toInt();
      
      return (totalScore / totalPlayers).round();
    } catch (e) {
      debugPrint('⚠️ Ortalama skor hesaplanamadı (aggregate unsupported?), fallback: 72');
      return 72;
    }
  }

  /// Kullanıcı adına göre email adresini getir
  Future<String?> getEmailByUsername(String username) async {
    try {
      final query = await _usersCollection.where('username', isEqualTo: username).get();
      if (query.docs.isNotEmpty) {
        final data = query.docs.first.data();
        return data['email'];
      }
      return null;
    } catch (e) {
      debugPrint('❌ Username email getirme hatası: $e');
      if (e.toString().contains('permission-denied')) {
        rethrow; // AuthService'in bunu yakalayıp kullanıcıya doğru bilgi vermesini sağlarız
      }
      return null;
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
    int? lpChange,
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

    if (leagueId != null && lpChange != null) {
      updates['leagueScores.$leagueId'] = FieldValue.increment(lpChange);
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
      // MALİYET OPTİMİZASYONU: Yüzlerce kullanıcı dökümanı indirmek yerine tek bir cache dökümanı oku
      final doc = await _leaderboardCollection.doc('global_$sortBy').get();
      if (doc.exists && doc.data() != null && doc.data()!['topUsers'] != null) {
        final List<dynamic> topUsers = doc.data()!['topUsers'];
        return topUsers.take(limit).map((data) => CloudUserProfile(
          odlevel: data['uid'] ?? '',
          level: data['level'] ?? 'A1',
          username: data['username'] ?? 'Player',
          totalScore: (data['totalScore'] as num?)?.toInt() ?? 0,
          weeklyGained: (data['weeklyGained'] as num?)?.toInt() ?? 0,
          avatarId: data['avatarId'],
        )).toList();
      }

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
      // MALİYET OPTİMİZASYONU: Tekil lig dökümanından oku
      final doc = await _leaderboardCollection.doc('league_$leagueId').get();
      if (doc.exists && doc.data() != null && doc.data()!['topUsers'] != null) {
        final List<dynamic> topUsers = doc.data()!['topUsers'];
        return topUsers.take(limit).map((data) => CloudUserProfile(
          odlevel: data['uid'] ?? '',
          level: data['level'] ?? 'A1',
          username: data['username'] ?? 'Player',
          totalScore: (data['totalScore'] as num?)?.toInt() ?? 0,
          leagueScores: {leagueId: (data['score'] as num?)?.toInt() ?? 1500},
          avatarId: data['avatarId'],
        )).toList();
      }

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

  /// Haftalık liderlik tablosunu getir
  Future<List<CloudUserProfile>> getWeeklyLeaderboard({
    int limit = 50,
  }) async {
    try {
      // MALİYET OPTİMİZASYONU: Tekil haftalık dökümandan oku
      final doc = await _leaderboardCollection.doc('weekly_top').get();
      if (doc.exists && doc.data() != null && doc.data()!['topUsers'] != null) {
        final List<dynamic> topUsers = doc.data()!['topUsers'];
        return topUsers.take(limit).map((data) => CloudUserProfile(
          odlevel: data['uid'] ?? '',
          level: data['level'] ?? 'A1',
          username: data['username'] ?? 'Player',
          totalScore: (data['totalScore'] as num?)?.toInt() ?? 0,
          weeklyGained: (data['weeklyGained'] as num?)?.toInt() ?? 0,
          avatarId: data['avatarId'],
        )).toList();
      }

      final snapshot = await _usersCollection
          .orderBy('weeklyGained', descending: true)
          .where('weeklyGained', isGreaterThan: 0)
          .limit(limit)
          .get();

      return snapshot.docs
          .map((doc) => CloudUserProfile.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('❌ Haftalık liderlik tablosu hatası: $e');
      return [];
    }
  }

  /// Kullanıcının haftalık sıralamasını getir
  Future<int?> getUserWeeklyRank(String odlevel) async {
    try {
      final userDoc = await _usersCollection.doc(odlevel).get();
      if (!userDoc.exists) return null;

      final userWeeklyScore = (userDoc.data()?['weeklyGained'] ?? 0) as int;
      if (userWeeklyScore <= 0) return null;

      final higherScores = await _usersCollection
          .where('weeklyGained', isGreaterThan: userWeeklyScore)
          .count()
          .get();

      return (higherScores.count ?? 0) + 1;
    } catch (e) {
      debugPrint('❌ Haftalık sıralama hatası: $e');
      return null;
    }
  }

  /// Tüm haftalık skorları sıfırla
  Future<void> resetWeeklyScores() async {
    try {
      final snapshot = await _usersCollection.where('weeklyGained', isGreaterThan: 0).get();
      final batch = _db.batch();
      
      for (final doc in snapshot.docs) {
        batch.update(doc.reference, {'weeklyGained': 0});
      }
      
      await batch.commit();
      debugPrint('✅ Haftalık skorlar sıfırlandı');
    } catch (e) {
      debugPrint('❌ Haftalık skor sıfırlama hatası: $e');
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
    
    // Firestore 'whereIn' sorgusu bir seferde maksimum 30 eleman kabul eder.
    // N+1 sorgusu problemini çözmek için listeyi 30'lu parçalara bölerek tek sorgu atıyoruz.
    for (var i = 0; i < profile.friends.length; i += 30) {
      final end = (i + 30 < profile.friends.length) ? i + 30 : profile.friends.length;
      final chunk = profile.friends.sublist(i, end);
      
      final snapshot = await _usersCollection
          .where(FieldPath.documentId, whereIn: chunk)
          .get();
          
      friends.addAll(snapshot.docs.map((doc) => CloudUserProfile.fromFirestore(doc)));
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

      final results = await Future.wait(snapshot.docs
          .map((doc) async {
        final profile = CloudUserProfile.fromFirestore(doc);
        final isOnline = await OnlineDuelService.instance.isUserOnline(doc.id);
        return profile.copyWith(isOnline: isOnline);
      }));

      // Unique results by userId
      final uniqueById = <String, CloudUserProfile>{};
      for (var r in results) {
        uniqueById[r.odlevel] = r;
      }

      // Unique results by (username + level + score) to hide potential data duplicates
      final uniqueByStats = <String, CloudUserProfile>{};
      for (var r in uniqueById.values) {
        final key = '${r.username.toLowerCase()}_${r.level}_${r.totalScore}';
        if (!uniqueByStats.containsKey(key)) {
          uniqueByStats[key] = r;
        }
      }

      return uniqueByStats.values.toList();
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
      // Güvenlik Düzeltmesi: Zaten cloud profili varsa cihazdaki veriyi
      // buluta zorla (en yüksek diyerek) yazdırmak, skor manipülasyonuna ve
      // senkronizasyon kayıplarına yol açar. Cloud verisi her zaman master kabul edilir.
    }

    debugPrint('✅ Lokal profil senkronize edildi');
  }

  // ==================== DAILY 123 GLOBAL ====================

  /// Günlük 123 skorunu kaydet
  Future<void> recordDaily123Result(int score, int seconds, bool isWin) async {
    final userId = AuthService.instance.userId;
    if (userId == null) return;

    final now = DateTime.now();
    final dateStr = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
    final docId = "${dateStr}_$userId";

    try {
      final profile = await getCurrentUserProfile();
      final username = profile?.username ?? 'Anonim';

      await _daily123Collection.doc(docId).set({
        'userId': userId,
        'username': username,
        'score': score,
        'seconds': seconds,
        'isWin': isWin,
        'date': dateStr,
        'timestamp': FieldValue.serverTimestamp(),
      });
      debugPrint('✅ Daily 123 skoru kaydedildi: $score ($dateStr)');
    } catch (e) {
      debugPrint('❌ Daily 123 skor kaydetme hatası: $e');
    }
  }

  /// Günlük 123 sıralama ve istatistiklerini getir
  Future<Map<String, dynamic>> getDaily123GlobalRanking(int currentScore, int currentSeconds) async {
    final now = DateTime.now();
    final dateStr = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
    final userId = AuthService.instance.userId;

    try {
      final snapshot = await _daily123Collection
          .where('date', isEqualTo: dateStr)
          .get();
      
      final docs = snapshot.docs;
      final totalPlayers = docs.isEmpty ? 1 : docs.length;

      // Tüm dökümanları bir listeye alalım ve sıralayalım
      final List<Map<String, dynamic>> results = docs.map((d) => d.data()).toList();
      
      // Sıralama Kriteri: Önce süre (KÜÇÜK olan üstte), eşitse skor (BÜYÜK olan üstte)
      results.sort((a, b) {
        final tA = (a['seconds'] as num?)?.toInt() ?? 123;
        final tB = (b['seconds'] as num?)?.toInt() ?? 123;
        if (tA != tB) return tA.compareTo(tB);
        final sA = (a['score'] as num?)?.toInt() ?? 0;
        final sB = (b['score'] as num?)?.toInt() ?? 0;
        return sB.compareTo(sA);
      });

      // Mevcut kullanıcının indexini bul (veya performansı iyileştirmek için tahmini)
      int myIndex = results.indexWhere((r) => r['userId'] == userId);
      
      // Eğer kullanıcı listede yoksa (çok düşük ihtimal ama güvenli olsun), nerede olması gerektiğini bul
      if (myIndex == -1) {
         myIndex = results.length; // Sona ekle
      }

      int totalSum = 0;
      for (var r in results) {
        totalSum += (r['score'] as num?)?.toInt() ?? 0;
      }

      final rank = myIndex + 1;
      final avgPoints = totalPlayers > 0 ? (totalSum / totalPlayers).round() : 75;

      // Bir üstteki ve bir alttaki oyuncuları al
      Map<String, dynamic>? prev;
      Map<String, dynamic>? next;
      
      if (myIndex > 0) prev = results[myIndex - 1];
      if (myIndex < results.length - 1) next = results[myIndex + 1];

      return {
        'rank': rank,
        'totalPlayers': totalPlayers,
        'avgPoints': avgPoints,
        'prevPlayer': prev,
        'nextPlayer': next,
      };
    } catch (e) {
      debugPrint('❌ Daily 123 global ranking failed: $e');
      return {
        'rank': 1,
        'totalPlayers': 1,
        'avgPoints': 75,
      };
    }
  }

  /// Günlük 123 Liderlik Tablosunu getir (Top 50)
  Future<List<Map<String, dynamic>>> getDaily123Leaderboard({int limit = 50}) async {
    final now = DateTime.now();
    final dateStr = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

    try {
      final query = await _daily123Collection
          .where('date', isEqualTo: dateStr)
          .orderBy('seconds', descending: false)
          .orderBy('score', descending: true)
          .limit(limit)
          .get();
      
      return query.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      debugPrint('❌ Daily 123 leaderboard listeleme hatası: $e');
      return [];
    }
  }
}
