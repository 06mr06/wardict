
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart' hide Transaction;
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:lugorena/models/friend.dart';
import 'package:lugorena/models/question_mode.dart';
import 'package:lugorena/models/user_level.dart';
import 'package:lugorena/models/online_duel.dart';
import 'user_profile_service.dart';
import 'word_pool_service.dart';
import 'firebase/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Online Düello Servisi
class OnlineDuelService {

  static final OnlineDuelService instance = OnlineDuelService._internal();

  /// Auth listener referansı — dispose/reset sırasında temizlenir.
  late final VoidCallback _authListener;

  OnlineDuelService._internal() {
    _authListener = _handleAuthStatusChange;
    AuthService.instance.addListener(_authListener);

    // Uygulama açılışında zaten giriş yapılmışsa manuel tetikle
    if (AuthService.instance.userId != null) {
      _handleAuthStatusChange();
    }
  }

  /// Tüm servisin yaşam döngüsünü kapat.
  /// Main dispose / çıkış akışında çağrılmalı.
  Future<void> disposeService() async {
    try {
      AuthService.instance.removeListener(_authListener);
    } catch (_) {}
    await _matchSubscription?.cancel();
    await _invitationListener?.cancel();
    await _presenceSubscription?.cancel();
    _matchSubscription = null;
    _invitationListener = null;
    _presenceSubscription = null;
    if (!_matchController.isClosed) {
      await _matchController.close();
    }
    if (!_invitationController.isClosed) {
      await _invitationController.close();
    }
  }

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  FirebaseFirestore get firestore => _firestore;
  
  // RTDB Root Node'u
  static const String _rtdbMatchesNode = 'online_duels';
  static const String _presenceNode = 'presence';
  
  // ignore: unused_field - Waiting queue için saklanıyor
  static const String _waitingCollection = 'waiting_players';

  // Kalıcılık için anahtarlar
  static const String _activeMatchIdKey = 'active_duel_match_id';
  static const String _activeMatchDataKey = 'active_duel_match_data';

  StreamSubscription<DatabaseEvent>? _matchSubscription;
  final StreamController<OnlineDuelMatch?> _matchController = StreamController<OnlineDuelMatch?>.broadcast();
  final Set<String> _readySignalSentForMatchIds = <String>{};
  final Set<String> _inDuelScreenSignalSentForMatchIds = <String>{};
  
  FirebaseDatabase? _cachedRtdb;
  FirebaseDatabase get _rtdb {
    if (_cachedRtdb != null) return _cachedRtdb!;

    final databaseURL =
        dotenv.get('FIREBASE_DATABASE_URL', fallback: '').trim();

    // RTDB bölgesi US değilse varsayılan instance yanlış host'a gider ve
    // düello senkronu sessiz sessiz kopabilir. .env'de URL ZORUNLU.
    if (databaseURL.isEmpty) {
      // Release'de üretim senaryosunda çok kritik → açık hata fırlat.
      if (!kDebugMode) {
        throw StateError(
          'FIREBASE_DATABASE_URL tanımlı değil! .env dosyasına RTDB URL '
          'eklemeden online düello çalışmaz (bölge uyuşmazlığı).',
        );
      }
      debugPrint('⚠️ OnlineDuelService: FIREBASE_DATABASE_URL boş — default instance kullanılıyor (debug). Bölge uyuşmazlığı olabilir!');
      _cachedRtdb = FirebaseDatabase.instance;
      return _cachedRtdb!;
    }

    try {
      final cleanUrl = databaseURL.endsWith('/')
          ? databaseURL.substring(0, databaseURL.length - 1)
          : databaseURL;
      _cachedRtdb = FirebaseDatabase.instanceFor(
        app: Firebase.app(),
        databaseURL: cleanUrl,
      );
      return _cachedRtdb!;
    } catch (e) {
      debugPrint('❌ OnlineDuelService: RTDB instance oluşturulamadı: $e');
      rethrow;
    }
  }
  Stream<OnlineDuelMatch?> get matchStream => _matchController.stream;

  // Invitation listening
  final _invitationController = StreamController<DuelInvitation>.broadcast();
  Stream<DuelInvitation> get onInvitationReceived => _invitationController.stream;
  StreamSubscription<QuerySnapshot>? _invitationListener;
  
  OnlineDuelMatch? _currentMatch;
  OnlineDuelMatch? get currentMatch => _currentMatch;

  /// Mevcut kullanıcı ID'si
  String? _currentUserId;
  String? get currentUserId => _currentUserId;
  String? _currentUsername;
  String? get currentUsername => _currentUsername;

  bool _isInitializing = false;
  Completer<void>? _initCompleter;

  Future<void> initialize() async {
    if (_initCompleter != null && !_initCompleter!.isCompleted) {
      return _initCompleter!.future;
    }
    
    // Eğer zaten initialize edilmişse ve ID varsa tekrar etme
    if (_currentUserId != null && _initCompleter != null && _initCompleter!.isCompleted) {
       return;
    }

    _initCompleter = Completer<void>();
    _isInitializing = true;
    
    try {
      _currentUserId = AuthService.instance.userId;
      
      if (_currentUserId == null) {
        debugPrint('ℹ️ OnlineDuelService: No user logged in. Skipping initialization.');
        return;
      }
      
      // Profilden kullanıcı adını al
      final profile = await UserProfileService.instance.loadProfile();
      _currentUsername = (profile.username != 'Player' && profile.username.isNotEmpty) 
          ? profile.username 
          : (AuthService.instance.displayName ?? 'Player');
      
      debugPrint('🔔 OnlineDuelService: Initialized for user: $_currentUserId as $_currentUsername');
      
      if (_currentUserId != null) {
        // Presence'ı başlat (await etmeden devam et)
        _setupPresence();
        // Davet dinleyiciyi başlat
        _startInvitationListenerInternal();
      }
    } catch (e) {
      debugPrint('❌ OnlineDuelService: Initialization error: $e');
    } finally {
      _isInitializing = false;
      if (_initCompleter != null && !_initCompleter!.isCompleted) {
        _initCompleter!.complete();
      }
    }
  }

  StreamSubscription<DatabaseEvent>? _presenceSubscription;
  
  /// Realtime Database üzerinde varlık (presence) takibi başlat
  Future<void> _setupPresence() async {
    if (_currentUserId == null) return;
    
    try {
      // Önceki varsa iptal et
      _presenceSubscription?.cancel();
      
      final presenceRef = _rtdb.ref(_presenceNode).child(_currentUserId!);
      final connectedRef = _rtdb.ref('.info/connected');
      
      _presenceSubscription = connectedRef.onValue.listen((event) async {
        final connected = event.snapshot.value as bool? ?? false;
        
        if (connected) {
          // Bağlandığımızda: 
          // 1. onDisconnect ayarla (koptuğunda status: offline yapacak)
          await presenceRef.onDisconnect().update({
            'status': 'offline',
            'last_seen': ServerValue.timestamp,
          });
          
          // 2. Şimdi status: online yap
          await presenceRef.update({
            'status': 'online',
            'last_seen': ServerValue.timestamp,
            'username': _currentUsername,
          });
          debugPrint('🟢 OnlineDuelService: Presence established (Online) for $_currentUserId');
        } else {
          debugPrint('🟡 OnlineDuelService: Presence connection lost for $_currentUserId');
        }
      });
    } catch (e) {
      debugPrint('❌ OnlineDuelService: Error setting up presence for $_currentUserId: $e');
    }
  }

  /// Bir kullanıcının online olup olmadığını RTDB üzerinden kontrol et
  Future<bool> isUserOnline(String userId) async {
    try {
      final snapshot = await _rtdb.ref(_presenceNode).child(userId).get();
      if (snapshot.exists && snapshot.value != null) {
        final data = Map<dynamic, dynamic>.from(snapshot.value as Map);
        final status = data['status']?.toString();
        
        if (status == 'online') return true;
        
        // Yedek kontrol: Eğer son görülme 2 dakikadan daha yeniyse online sayılabilir (status güncellenmemiş olabilir)
        final lastSeen = data['last_seen'];
        if (lastSeen is int) {
          final now = DateTime.now().millisecondsSinceEpoch;
          if (now - lastSeen < 120000) { // 2 dakika
             return true;
          }
        }
      }
    } catch (e) {
      debugPrint('⚠️ OnlineDuelService: Error checking online status for $userId: $e');
    }
    return false;
  }

  void _handleAuthStatusChange() async {
    final newId = AuthService.instance.userId;

    if (newId != _currentUserId) {
      debugPrint('👤 OnlineDuelService: Auth status changed. User: $newId');
      _currentUserId = newId;
      
      if (_currentUserId != null) {
        initialize();
      } else {
        reset();
      }
    } else if (_currentUserId != null) {
        // ID değişmedi ama presence tazele (hot restart veya reconnect için)
        _setupPresence();
    }
  }

  /// Servisi sıfırla (Çıkış yapıldığında çağrılmalı)
  void reset() {
    debugPrint('👤 OnlineDuelService: Resetting service state');
    _currentUserId = null;
    _currentUsername = null;
    // _isInitialized = false; // Removed
    stopInvitationListener();
    _currentMatch = null;
    _matchController.add(null);
  }

  /// LP puanına göre rastgele eşleşme bul
  Future<OnlineDuelMatch?> findRandomMatchByLp(int lp, String currentLeague) async {
    return findRandomMatch(lp, currentLeague);
  }

  /// Arkadaşı LP'ye uygun lige davet et
  Future<OnlineDuelMatch?> inviteFriendByLp(Friend friend, int lp) async {
    // LP'ye göre lig belirle
    String leagueCode = 'A1';
    if (lp >= 2000) {
      leagueCode = 'C1';
    } else if (lp >= 1500) leagueCode = 'B1';
    
    return inviteFriend(friend, leagueCode);
  }

  /// Rematch daveti gönder
  Future<OnlineDuelMatch?> inviteRematch(OnlineDuelMatch oldMatch) async {
    if (_currentUserId == null) await initialize();
    if (_currentUserId == null) return null;

    final opponentUserId = _currentUserId == oldMatch.hostUserId ? oldMatch.guestUserId : oldMatch.hostUserId;
    final opponentUsername = _currentUserId == oldMatch.hostUserId ? oldMatch.guestUsername : oldMatch.hostUsername;

    if (opponentUserId == null || opponentUsername == null) {
      debugPrint('⚠️ Rematch opponent data missing: ID=$opponentUserId, Name=$opponentUsername');
      return null;
    }

    final opponent = Friend(
      userId: opponentUserId,
      username: opponentUsername,
    );

    debugPrint('🔄 Inviting rematch to $opponentUsername ($opponentUserId)');
    return inviteFriend(opponent, oldMatch.leagueCode);
  }

  /// Mevcut yarım kalmış maçı getir
  Future<OnlineDuelMatch?> getResumableMatch() async {
    try {
      if (_currentUserId == null) await initialize();
      final prefs = await SharedPreferences.getInstance();
      final matchId = prefs.getString(_activeMatchIdKey);
      if (matchId == null) return null;

      debugPrint('⏮️ OnlineDuelService: Attempting to resume match: $matchId');

      // Demo maçı mı? (Sadece lokalde saklanır)
      if (matchId.startsWith('demo_')) {
        final data = prefs.getString(_activeMatchDataKey);
        if (data != null) {
          final match = OnlineDuelMatch.fromJson(jsonDecode(data), matchId);
          if (match.status != OnlineDuelStatus.finished && match.status != OnlineDuelStatus.cancelled) {
            _currentMatch = match;
            _matchController.add(match);
            return match;
          }
        }
        await clearResumableMatch();
        return null;
      }

      // Online maçı RTDB'den çek
      final snapshot = await _rtdb.ref(_rtdbMatchesNode).child(matchId).get();
      if (snapshot.exists && snapshot.value != null) {
        final data = Map<String, dynamic>.from(snapshot.value as Map);
        final match = OnlineDuelMatch.fromJson(data, matchId);
        
        // Eğer maç hala aktifse dinlemeyi başlat
        if (match.status == OnlineDuelStatus.waiting || 
            match.status == OnlineDuelStatus.ready || 
            match.status == OnlineDuelStatus.inProgress) {
          _currentMatch = match;
          _listenToMatch(matchId);
          return match;
        }
      }
      
      // Maç bitmiş veya silinmiş
      await clearResumableMatch();
    } catch (e) {
      debugPrint('⚠️ OnlineDuelService: Error getting resumable match: $e');
    }
    return null;
  }

  /// Maç durumunu kaydet
  Future<void> _saveActiveMatch(OnlineDuelMatch? match) async {
    if (match == null) return;
    
    // Sadece aktif maçları kaydet
    if (match.status == OnlineDuelStatus.finished || 
        match.status == OnlineDuelStatus.cancelled ||
        match.status == OnlineDuelStatus.timeout) {
      await clearResumableMatch();
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_activeMatchIdKey, match.matchId);
      // Demo maç ise tüm veriyi de kaydetmeliyiz (RTDB'de yok)
      if (match.matchId.startsWith('demo_')) {
        await prefs.setString(_activeMatchDataKey, jsonEncode(match.toJson()));
      } else {
        await prefs.remove(_activeMatchDataKey);
      }
      debugPrint('💾 OnlineDuelService: Active match saved: ${match.matchId}');
    } catch (e) {
      debugPrint('⚠️ OnlineDuelService: Error saving active match: $e');
    }
  }

  /// Aktif maç bilgisini temizle
  Future<void> clearResumableMatch() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_activeMatchIdKey);
      await prefs.remove(_activeMatchDataKey);
      debugPrint('🧹 OnlineDuelService: Active match cleared');
    } catch (e) {
      debugPrint('⚠️ OnlineDuelService: Error clearing active match: $e');
    }
  }

  /// İki oyuncu arasındaki skoru getir (Head-to-head)
  Future<Map<String, int>> getHeadToHeadScore(String opponentId) async {
    if (_currentUserId == null) return {'me': 0, 'opponent': 0};
    
    try {
      int myWins = 0;
      int opponentWins = 0;
      
      // Ben host olduğum maçlar
      final hostSnapshot = await _rtdb.ref(_rtdbMatchesNode).orderByChild('hostUserId').equalTo(_currentUserId).get();
      if (hostSnapshot.exists) {
        final matches = Map<String, dynamic>.from(hostSnapshot.value as Map);
        for (var value in matches.values) {
          final data = Map<String, dynamic>.from(value as Map);
          if (data['guestUserId'] == opponentId && data['status'] == OnlineDuelStatus.finished.name) {
            final hostScore = data['hostScore'] as int? ?? 0;
            final guestScore = data['guestScore'] as int? ?? 0;
            if (hostScore > guestScore) {
              myWins++;
            } else if (hostScore < guestScore) {
              opponentWins++;
            }
          }
        }
      }

      // Ben guest olduğum maçlar
      final guestSnapshot = await _rtdb.ref(_rtdbMatchesNode).orderByChild('guestUserId').equalTo(_currentUserId).get();
      if (guestSnapshot.exists) {
        final matches = Map<String, dynamic>.from(guestSnapshot.value as Map);
        for (var value in matches.values) {
          final data = Map<String, dynamic>.from(value as Map);
          if (data['hostUserId'] == opponentId && data['status'] == OnlineDuelStatus.finished.name) {
            final hostScore = data['hostScore'] as int? ?? 0;
            final guestScore = data['guestScore'] as int? ?? 0;
            if (guestScore > hostScore) {
              myWins++;
            } else if (guestScore < hostScore) {
              opponentWins++;
            }
          }
        }
      }
      
      return {'me': myWins, 'opponent': opponentWins};
    } catch (e) {
      debugPrint('Error getting head-to-head score: $e');
      return {'me': 0, 'opponent': 0};
    }
  }

  /// Rastgele eşleşme ara (LP tabanlı ve Global)
  Future<OnlineDuelMatch?> findRandomMatch(int currentLp, String preferredLeagueCode, {Map<String, String>? wordOfTheDay}) async {
    if (_currentUserId == null) {
      await initialize();
    }
    
    // Edge/Web için ek bir güvenlik beklemesi (race condition önlemek için)
    if (_currentUserId == null) {
       await Future.delayed(const Duration(milliseconds: 500));
       _currentUserId = AuthService.instance.userId;
    }
    
    if (_currentUserId == null) {
        debugPrint('❌ OnlineDuelService: Cannot find match because User ID is still null after init');
        return null;
    }

    try {
      final String normalLeague = preferredLeagueCode.length == 1 ? '${preferredLeagueCode}1' : preferredLeagueCode;
      debugPrint('🔍 OnlineDuelService: Searching matches for league: $normalLeague (LP: $currentLp)');
      debugPrint('🌐 Database URL: ${_rtdb.app.options.databaseURL}');
      
      final waitingMatches = await _rtdb
          .ref(_rtdbMatchesNode)
          .orderByChild('status')
          .equalTo(OnlineDuelStatus.waiting.name)
          .get();

      List<MapEntry<String, Map<String, dynamic>>> publicMatches = [];
      List<String> staleMatchIds = [];
      final now = DateTime.now();
      
      if (waitingMatches.exists && waitingMatches.value != null) {
        final rawData = waitingMatches.value;
        Map<String, dynamic> matchesMap = {};
        
        if (rawData is Map) {
          matchesMap = Map<String, dynamic>.from(rawData);
        } else if (rawData is List) {
          for (int i = 0; i < rawData.length; i++) {
            if (rawData[i] != null) matchesMap[i.toString()] = rawData[i];
          }
        }

        debugPrint('🔍 OnlineDuelService: Scanning ${matchesMap.length} raw matches...');
        
        for (var entry in matchesMap.entries) {
          try {
            final dataMap = entry.value;
            if (dataMap == null || dataMap is! Map) continue;
            
            final data = Map<String, dynamic>.from(dataMap);
            final hostId = data['hostUserId']?.toString();
            final invitedUserId = data['invitedUserId']?.toString();
            final matchLeague = data['leagueCode']?.toString();
            
            // 1. Zaman kontrolü (10 dakikadan eski hayalet maçları temizle)
            final createdAtStr = data['createdAt']?.toString();
            if (createdAtStr != null) {
              final createdAt = DateTime.tryParse(createdAtStr);
              if (createdAt != null && now.difference(createdAt).inMinutes > 10) {
                staleMatchIds.add(entry.key);
                continue;
              }
            }

            // 2. Kendi maçım mı?
            if (hostId == _currentUserId) continue;
            
            // 3. Özel davet mi?
            if (invitedUserId != null && invitedUserId.trim().isNotEmpty) continue;
            
            // 4. Maç zaten dolmuş mu?
            if (data['guestUserId'] != null || data['status'] != OnlineDuelStatus.waiting.name) continue;

            // Eşleşme kriterlerine uygun
            bool leagueMatch = (matchLeague == preferredLeagueCode);
            data['isLeagueMatch'] = leagueMatch;
            data['createdTime'] = DateTime.tryParse(createdAtStr ?? '')?.millisecondsSinceEpoch ?? 0;
            
            publicMatches.add(MapEntry(entry.key, data));
          } catch (e) {
            debugPrint('⚠️ OnlineDuelService: Error parsing match ${entry.key}: $e');
          }
        }
      }

      // Hayalet maçları temizle (performans için o an yapıyoruz)
      if (staleMatchIds.isNotEmpty) {
        debugPrint('🧹 OnlineDuelService: Cleaning up ${staleMatchIds.length} stale matches.');
        for (var sid in staleMatchIds) {
          _rtdb.ref(_rtdbMatchesNode).child(sid).remove();
        }
      }

      if (publicMatches.isNotEmpty) {
        debugPrint('🤝 OnlineDuelService: Found ${publicMatches.length} valid matches to join.');
        
        // Sıralama: Lig önceliği ve en yeni olan
        publicMatches.sort((a, b) {
          final isLeagueA = a.value['isLeagueMatch'] as bool? ?? false;
          final isLeagueB = b.value['isLeagueMatch'] as bool? ?? false;
          if (isLeagueA != isLeagueB) return isLeagueA ? -1 : 1;
          
          final timeA = a.value['createdTime'] as int? ?? 0;
          final timeB = b.value['createdTime'] as int? ?? 0;
          return timeB.compareTo(timeA); // En yeni olan en üstte
        });

        // Tüm uygun maçları sırayla dene (Eskiden sadece ilkini deneyip pes ediyordu)
        for (var matchEntry in publicMatches) {
          final targetMatchId = matchEntry.key;
          debugPrint('🚀 OnlineDuelService: Attempting to join match $targetMatchId');
          
          final result = await joinMatch(targetMatchId);
          if (result != null) return result; // Başarılı olursa dön
        }
        
        debugPrint('⚠️ OnlineDuelService: All join attempts failed, fallback to creation.');
        return await _createMatch(preferredLeagueCode, currentLp: currentLp, wordOfTheDay: wordOfTheDay);
      } else {
        debugPrint('🆕 OnlineDuelService: No valid matches found. Creating a new host...');
        return await _createMatch(preferredLeagueCode, currentLp: currentLp, wordOfTheDay: wordOfTheDay);
      }
    } catch (e) {
      debugPrint('❌ OnlineDuelService: Matchmaking search error: $e');
      return await _createMatch(preferredLeagueCode, currentLp: currentLp, wordOfTheDay: wordOfTheDay);
    }
  }

  /// Arkadaşa düello daveti gönder
  Future<OnlineDuelMatch?> inviteFriend(Friend friend, String leagueCode, {Map<String, String>? wordOfTheDay}) async {
    if (_currentUserId == null) await initialize();
    if (_currentUserId == null) return null;

    // Online kontrolü
    final isOnline = await isUserOnline(friend.userId);
    if (!isOnline) {
      debugPrint('⚠️ Arkadaş çevrimdışı, davet gönderilemez.');
      return null;
    }

    // Aynı kullanıcı kontrolü (Test sırasında sıkça yapılabilecek hata)
    if (friend.userId == _currentUserId) {
      debugPrint('⚠️ Kendi kendine davet gönderemezsin! Farklı bir hesap kullanmalısın.');
      return null;
    }

    // Demo ID kontrolü - Demo arkadaşlara gerçek davet gidemez
    if (friend.userId.startsWith('demo_')) {
      debugPrint('ℹ️ Demo friendship detected, creating a local match with Bot simulation');
      return _createDemoMatch(leagueCode);
    }

    try {
      // İsmi tazelemek için profili tekrar yükle (opsiyonel ama güvenli)
      final profile = await UserProfileService.instance.loadProfile();
      _currentUsername = profile.username;
      
      debugPrint('🚀 OnlineDuelService: Inviting real friend: ${friend.username} (ID: ${friend.userId}) from $_currentUsername ($_currentUserId)');
      
      final match = await _createMatch(leagueCode, invitedUserId: friend.userId, currentLp: profile.lpRating, wordOfTheDay: wordOfTheDay);
      
      if (match != null) {
        try {
          debugPrint('📝 OnlineDuelService: Creating notification for ${friend.username} (ID: ${friend.userId}) for match: ${match.matchId}');
          final docRef = await _firestore.collection('notifications').add({
            'toUserId': friend.userId,
            'fromUserId': _currentUserId,
            'fromUsername': _currentUsername ?? 'Bir Oyuncu',
            'type': 'duel_invite',
            'matchId': match.matchId,
            'matchDocId': match.matchId,
            'leagueCode': leagueCode,
            'createdAt': FieldValue.serverTimestamp(),
            'read': false,
            'status': 'pending',
          });
          debugPrint('✅ OnlineDuelService: Davet bildirimi Firestore\'a yazıldı (Doc ID: ${docRef.id})');
        } catch (notifierr) {
          debugPrint('⚠️ OnlineDuelService: Davet bildirimi gönderilemedi: $notifierr');
        }
      } else {
        debugPrint('❌ OnlineDuelService: Match creation failed for invite.');
      }
      
      return match;
    } catch (e) {
      debugPrint('❌ OnlineDuelService: Error inviting friend: $e');
      return null;
    }
  }

  /// Maç oluştur
  Future<OnlineDuelMatch?> _createMatch(String leagueCode, {String? invitedUserId, int currentLp = 1500, Map<String, String>? wordOfTheDay}) async {
    if (_currentUserId == null) {
      _currentUserId = AuthService.instance.userId;
      if (_currentUserId == null) return null;
    }

    final matchId = 'match_${DateTime.now().millisecondsSinceEpoch}_$_currentUserId';
    
    final questions = _generateQuestions(leagueCode, wordOfTheDay: wordOfTheDay);
    
    final match = OnlineDuelMatch(
      matchId: matchId,
      hostUserId: _currentUserId!,
      hostUsername: _currentUsername ?? 'Player',
      hostLp: currentLp,
      // guestUserId is null when created; guest will fill it when joining
      leagueCode: leagueCode,
      status: OnlineDuelStatus.waiting,
      hostReady: false,
      guestReady: false,
      hostInDuelScreen: false,
      guestInDuelScreen: false,
      hostFinished: false,
      guestFinished: false,
      questions: questions,
      playerAnswers: {},
      createdAt: DateTime.now(),
      wordOfTheDay: wordOfTheDay,
    );

    try {
      final matchData = match.toJson();
      // Davet edilen kişi varsa Firestore belgesine invitedUserId alını ekle
      if (invitedUserId != null) {
        matchData['invitedUserId'] = invitedUserId;
      }
      final matchRef = _rtdb.ref(_rtdbMatchesNode).child(matchId);
      await matchRef.set(matchData);
      
      // ÖNEMLİ: Host bağlantısı kesilirse (uçak modu, crash vb.) bekleyen maçı RTDB'den sil
      // Bu sayede "ghost" maçların oluşması ve kullanıcıların asılı kalması önlenir.
      matchRef.onDisconnect().remove();

      _currentMatch = match;
      
      debugPrint('🆕 OnlineDuelService: Created Match $matchId as HOST. Waiting for guest...');
      
      try {
        await _saveActiveMatch(match);
      } catch (e) {
        debugPrint('⚠️ Non-critical: Could not save match locally: $e');
      }
      
      _listenToMatch(matchId);
      return match;
    } catch (e) {
      debugPrint('Error creating match: $e');
      return match; // Offline modda devam et
    }
  }

  /// Maça katıl
  Future<OnlineDuelMatch?> joinMatch(String matchId) async {
    int retryCount = 0;
    while (retryCount < 3) {
      if (retryCount > 0) {
        debugPrint('🔄 OnlineDuelService: Retrying join (${retryCount + 1}/3) for $matchId...');
        await Future.delayed(Duration(milliseconds: 400 * retryCount));
      }

      try {
        if (_currentUserId == null) await initialize();
        if (_currentUserId == null) return null;
        
        // Maçı kontrol et
        final doc = await _rtdb.ref(_rtdbMatchesNode).child(matchId).get();
        if (!doc.exists || doc.value == null) {
          debugPrint('⚠️ Match $matchId not found.');
          return null;
        }

        final data = Map<String, dynamic>.from(doc.value as Map);
        final hostUserId = data['hostUserId']?.toString();
        
        // Host kendi maçına katılamaz
        if (hostUserId?.trim() == _currentUserId?.trim()) {
          debugPrint('⚠️ Cannot join your own match! (ID: $_currentUserId)');
          return null;
        }
        
        final profile = await UserProfileService.instance.loadProfile();
        final matchRef = _rtdb.ref(_rtdbMatchesNode).child(matchId);
        
        final transactionResult = await matchRef.runTransaction((Object? matchData) {
          if (matchData == null) {
            // KRİTİK DÜZELTME: Web ortamında Firebase ilk okumayı yerel önbellekten (boş) yapabilir.
            // Eğer burada abort edersek Firebase "kullanıcı iptal etti" sanıp sunucuya hiç sormaz!
            // success() dönmeliyiz ki sunucu "Veri boş değil, al sana yeni veri" diyerek burayı yeniden tetiklesin.
            return Transaction.success(matchData);
          }
          
          late Map<String, dynamic> dataMap;
          try {
            if (matchData is Map) {
              dataMap = matchData.map((k, v) => MapEntry(k.toString(), v));
            } else {
              return Transaction.abort();
            }
          } catch (e) {
            return Transaction.abort();
          }
          
          final String? status = dataMap['status']?.toString();
          final String? guestId = dataMap['guestUserId']?.toString();
          
          // Eğer makul bir durum değilse retry yapma (Abort)
          if (status != OnlineDuelStatus.waiting.name || (guestId != null && guestId.isNotEmpty)) {
            return Transaction.abort();
          }
          
          dataMap['guestUserId'] = _currentUserId;
          dataMap['guestUsername'] = _currentUsername;
          dataMap['guestLp'] = profile.lpRating;
          dataMap['status'] = OnlineDuelStatus.ready.name;

          // Handshake safety: Eski/yarım kalmış maçlardan kalan ready bayraklarını temizle.
          // Bu sayede host, guest stream'e gerçekten bağlanmadan oyunu başlatamaz.
          dataMap['hostReady'] = false;
          dataMap['guestReady'] = false;
          dataMap.remove('hostReadyAt');
          dataMap.remove('guestReadyAt');
          dataMap.remove('startedAtServer');

          // Lichess benzeri senkron başlangıç/bitiş için ekran/presence + bitiş bayraklarını da temizle.
          dataMap['hostInDuelScreen'] = false;
          dataMap['guestInDuelScreen'] = false;
          dataMap.remove('hostInDuelScreenAt');
          dataMap.remove('guestInDuelScreenAt');
          dataMap['hostFinished'] = false;
          dataMap['guestFinished'] = false;
          dataMap.remove('hostFinishedAt');
          dataMap.remove('guestFinishedAt');
          dataMap.remove('finishedAtServer');
          
          return Transaction.success(dataMap);
        });

        if (transactionResult.committed) {
          final updatedData = jsonDecode(jsonEncode(transactionResult.snapshot.value)) as Map<String, dynamic>;
          _currentMatch = OnlineDuelMatch.fromJson(updatedData, matchId);
          debugPrint('✅✅✅ MATCH SUCCESS! Join to: $matchId as Guest. Status: ${_currentMatch?.status}');
          
          try {
            await _saveActiveMatch(_currentMatch);
          } catch (e) { /* ignore */ }
          
          _listenToMatch(matchId);
          _matchController.add(_currentMatch);
          return _currentMatch;
        } else {
          // Eğer statü zaten ready ise (bir başkası girdiyse) retry yapma
          final checkAgain = await _rtdb.ref(_rtdbMatchesNode).child(matchId).get();
          if (checkAgain.exists && checkAgain.value != null) {
             final checkData = Map<String, dynamic>.from(checkAgain.value as Map);
             if (checkData['status'] != OnlineDuelStatus.waiting.name) {
                debugPrint('⚠️ OnlineDuelService: Match $matchId is already taken, stopping retries.');
                return null;
             }
          }
        }
      } catch (e) {
        debugPrint('⚠️ OnlineDuelService: Join attempt $retryCount error: $e');
      }
      
      retryCount++;
    }
    
    debugPrint('❌ OnlineDuelService: Join failed after retries for match $matchId');
    return null;
  }

  /// Maç değişikliklerini dinle
  void _listenToMatch(String matchId) {
    _matchSubscription?.cancel();
    
    try {
      _matchSubscription = _rtdb
          .ref(_rtdbMatchesNode)
          .child(matchId)
          .onValue
          .listen((event) {
        if (event.snapshot.exists && event.snapshot.value != null) {
          final data = Map<String, dynamic>.from(event.snapshot.value as Map);
          final match = OnlineDuelMatch.fromJson(data, event.snapshot.key);
          
          // Önemli durum değişikliklerini logla
          if (_currentMatch?.status != match.status) {
            debugPrint('📡 OnlineDuelService: Status changed in Match $matchId: ${_currentMatch?.status} -> ${match.status}');
            if (match.status == OnlineDuelStatus.ready) {
              debugPrint('✅✅✅ MATCH SUCCESS (HOST SIDE)! Opponent Found: ${match.guestUsername}');
            }
          }
          
          _currentMatch = match;
          _matchController.add(_currentMatch);

          // Handshake: stream'in gerçekten aktif olduğunu RTDB'ye bildir.
          _maybeSignalReady(matchId, match);

          // İki taraf da hazırsa yalnızca Host oyunu başlatır.
          if (_currentUserId != null &&
              match.status == OnlineDuelStatus.ready &&
              match.hostUserId == _currentUserId &&
              match.hostReady &&
              match.guestReady &&
              match.hostInDuelScreen &&
              match.guestInDuelScreen) {
            // Transaction ile idempotent hale getireceğiz (startGame içinde).
            startGame();
          }

          // Durum değişirse (Biterse) temizle
          if (_currentMatch!.isFinished || _currentMatch!.status == OnlineDuelStatus.cancelled) {
             clearResumableMatch();
          } else {
             try {
               _saveActiveMatch(_currentMatch);
             } catch (e) { /* ignore */ }
          }
        } else {
          // Maç silinmiş olabilir
          debugPrint('ℹ️ OnlineDuelService: Match monitor triggered but snapshot value is null.');
        }
      }, onError: (e) {
        debugPrint('❌ OnlineDuelService: Match Subscription Error: $e');
      });
    } catch (e) {
      debugPrint('Error listening to match: $e');
    }
  }

  void _maybeSignalReady(String matchId, OnlineDuelMatch match) {
    if (_currentUserId == null) return;
    if (_readySignalSentForMatchIds.contains(matchId)) return;

    final isHost = match.hostUserId == _currentUserId;
    final isGuest = match.guestUserId != null && match.guestUserId == _currentUserId;

    // Ready sinyali sadece waiting/ready evresinde anlamlı.
    if (!(match.status == OnlineDuelStatus.waiting || match.status == OnlineDuelStatus.ready)) {
      return;
    }

    if (isHost && !match.hostReady) {
      _readySignalSentForMatchIds.add(matchId);
      _rtdb.ref(_rtdbMatchesNode).child(matchId).update({
        'hostReady': true,
        'hostReadyAt': ServerValue.timestamp,
      }).catchError((e) {
        _readySignalSentForMatchIds.remove(matchId);
        debugPrint('⚠️ OnlineDuelService: Failed to set hostReady for $matchId: $e');
      });
      return;
    }

    if (isGuest && !match.guestReady) {
      _readySignalSentForMatchIds.add(matchId);
      _rtdb.ref(_rtdbMatchesNode).child(matchId).update({
        'guestReady': true,
        'guestReadyAt': ServerValue.timestamp,
      }).catchError((e) {
        _readySignalSentForMatchIds.remove(matchId);
        debugPrint('⚠️ OnlineDuelService: Failed to set guestReady for $matchId: $e');
      });
      return;
    }
  }

  /// Oyuncunun duello ekranında olup olmadığını RTDB'ye bildirir.
  /// Başlangıç/bitiş senkronizasyonunda "sadece duello ekranındaki oyuncular yarışabilir" şartı için kullanılır.
  Future<void> setInDuelScreen(bool inDuel) async {
    if (_currentMatch == null || _currentUserId == null) return;
    final matchId = _currentMatch!.matchId;
    if (matchId.startsWith('demo_')) return;

    final isHost = _currentMatch!.hostUserId == _currentUserId;
    final key = isHost ? 'hostInDuelScreen' : 'guestInDuelScreen';
    final atKey = isHost ? 'hostInDuelScreenAt' : 'guestInDuelScreenAt';

    // Aynı değeri spam'lemeyelim (özellikle rebuild/hot reload sırasında).
    final already = isHost ? _currentMatch!.hostInDuelScreen : _currentMatch!.guestInDuelScreen;
    if (already == inDuel && _inDuelScreenSignalSentForMatchIds.contains(matchId)) return;
    _inDuelScreenSignalSentForMatchIds.add(matchId);

    try {
      await _rtdb.ref(_rtdbMatchesNode).child(matchId).update({
        key: inDuel,
        atKey: ServerValue.timestamp,
      });
    } catch (e) {
      _inDuelScreenSignalSentForMatchIds.remove(matchId);
      debugPrint('⚠️ OnlineDuelService: Failed to set $key=$inDuel for $matchId: $e');
    }
  }

  /// Cevap gönder
  Future<void> submitAnswer(int questionIndex, int selectedOption, int timeMs, {int points = 0}) async {
    if (_currentMatch == null || _currentUserId == null) return;

    final question = _currentMatch!.questions[questionIndex];
    final isCorrect = selectedOption == question.correctIndex;

    final answer = PlayerAnswer(
      userId: _currentUserId!,
      questionIndex: questionIndex,
      selectedOption: selectedOption,
      isCorrect: isCorrect,
      timeMs: timeMs,
      answeredAt: DateTime.now(),
    );

    try {
      // RTDB'ye cevabı ekle ve atomik olarak güncelle
      final matchRef = _rtdb.ref(_rtdbMatchesNode).child(_currentMatch!.matchId);
      
      await matchRef.runTransaction((Object? postData) {
        if (postData == null) return Transaction.success(postData);
        
        // Güvenli tip dönüşümü (JSON hilesi ile)
        final data = jsonDecode(jsonEncode(postData)) as Map<String, dynamic>;
        
        final playerAnswers = Map<String, dynamic>.from(data['playerAnswers'] ?? {});
        
        final answers = List<Map<String, dynamic>>.from(playerAnswers[_currentUserId] ?? []);
        answers.add(answer.toJson());
        playerAnswers[_currentUserId!] = answers;

        // Skoru güncelle (Puanları ekle)
        int hostScore = data['hostScore'] ?? 0;
        int guestScore = data['guestScore'] ?? 0;
        
        if (_currentUserId == data['hostUserId']) {
          hostScore += points;
        } else {
          guestScore += points;
        }

        data['playerAnswers'] = playerAnswers;
        data['hostScore'] = hostScore;
        data['guestScore'] = guestScore;

        return Transaction.success(data);
      });
    } catch (e) {
      debugPrint('Error submitting answer: $e');
      // Offline modda lokal güncelle
      _updateLocalScore(points);
    }
  }

  /// Emote gönder
  Future<void> sendEmote(String emote) async {
    if (_currentMatch == null || _currentUserId == null) return;

    try {
      final matchRef = _rtdb.ref(_rtdbMatchesNode).child(_currentMatch!.matchId);
      await matchRef.update({
        'lastEmote': {
          'userId': _currentUserId,
          'emoji': emote,
          'timestamp': ServerValue.timestamp,
        }
      });
    } catch (e) {
      debugPrint('Error sending emote: $e');
    }
  }

  void _updateLocalScore(int points) {
    if (_currentMatch == null || points <= 0) return;
    
    final isHost = _currentMatch!.hostUserId == _currentUserId;
    _currentMatch = _currentMatch!.copyWith(
      hostScore: isHost ? _currentMatch!.hostScore + points : _currentMatch!.hostScore,
      guestScore: !isHost ? _currentMatch!.guestScore + points : _currentMatch!.guestScore,
    );
    _matchController.add(_currentMatch);
  }

  /// Oyunu başlat
  Future<void> startGame() async {
    if (_currentMatch == null) return;

    try {
      // Handshake'li, idempotent başlangıç:
      // - Guest, stream ilk snapshot'ı aldıktan sonra guestReady=true yazar
      // - Host da hostReady=true yazar
      // - Yalnızca host, (hostReady && guestReady && status == ready) iken inProgress'a geçirir
      final matchId = _currentMatch!.matchId;
      final nowIso = DateTime.now().toIso8601String();

      await _rtdb.ref(_rtdbMatchesNode).child(matchId).runTransaction((Object? matchData) {
        if (matchData == null) return Transaction.abort();

        final data = jsonDecode(jsonEncode(matchData)) as Map<String, dynamic>;
        final status = data['status']?.toString();

        // Zaten başlamış/bitmiş ise dokunma
        if (status == OnlineDuelStatus.inProgress.name || status == OnlineDuelStatus.finished.name) {
          return Transaction.abort();
        }

        final hostUserId = data['hostUserId']?.toString();
        if (hostUserId == null || hostUserId.isEmpty) return Transaction.abort();
        if (_currentUserId == null || _currentUserId != hostUserId) {
          return Transaction.abort();
        }

        final hostReady = data['hostReady'] == true;
        final guestReady = data['guestReady'] == true;
        final hostInDuel = data['hostInDuelScreen'] == true;
        final guestInDuel = data['guestInDuelScreen'] == true;
        if (!hostReady || !guestReady || !hostInDuel || !guestInDuel) {
          return Transaction.abort();
        }

        if (status != OnlineDuelStatus.ready.name) {
          return Transaction.abort();
        }

        data['status'] = OnlineDuelStatus.inProgress.name;
        data['startedAt'] = nowIso;
        data['startedAtServer'] = ServerValue.timestamp;
        return Transaction.success(data);
      });

      if (_currentMatch != null) {
        _currentMatch = _currentMatch!.copyWith(status: OnlineDuelStatus.inProgress, startedAt: DateTime.now());
        await _saveActiveMatch(_currentMatch);
      }
    } catch (e) {
      debugPrint('Error starting game: $e');
    }
  }

  /// Oyunu bitir
  Future<void> finishGame() async {
    if (_currentMatch == null) return;

    try {
      await _rtdb.ref(_rtdbMatchesNode).child(_currentMatch!.matchId).update({
        'status': OnlineDuelStatus.finished.name,
        'finishedAt': DateTime.now().toIso8601String(),
      });
      await clearResumableMatch();
    } catch (e) {
      debugPrint('Error finishing game: $e');
    }
  }

  /// Lichess benzeri bitiş: Her oyuncu "ben bittim" der; ikisi de bitince match finished olur.
  Future<void> markPlayerFinished() async {
    if (_currentMatch == null || _currentUserId == null) return;
    final matchId = _currentMatch!.matchId;
    if (matchId.startsWith('demo_')) return;

    final isHost = _currentMatch!.hostUserId == _currentUserId;
    final flagKey = isHost ? 'hostFinished' : 'guestFinished';
    final atKey = isHost ? 'hostFinishedAt' : 'guestFinishedAt';

    try {
      await _rtdb.ref(_rtdbMatchesNode).child(matchId).runTransaction((Object? matchData) {
        if (matchData == null) return Transaction.abort();
        final data = jsonDecode(jsonEncode(matchData)) as Map<String, dynamic>;

        final status = data['status']?.toString();
        if (status == OnlineDuelStatus.cancelled.name) return Transaction.abort();

        data[flagKey] = true;
        data[atKey] = ServerValue.timestamp;

        final hostFinished = data['hostFinished'] == true;
        final guestFinished = data['guestFinished'] == true;

        if (hostFinished && guestFinished) {
          data['status'] = OnlineDuelStatus.finished.name;
          data['finishedAt'] = DateTime.now().toIso8601String();
          data['finishedAtServer'] = ServerValue.timestamp;
        }

        return Transaction.success(data);
      });
    } catch (e) {
      debugPrint('⚠️ OnlineDuelService: markPlayerFinished error: $e');
    }
  }

  /// Maçı iptal et
  Future<void> cancelMatch() async {
    if (_currentMatch == null) return;

    try {
      await _rtdb.ref(_rtdbMatchesNode).child(_currentMatch!.matchId).update({
        'status': OnlineDuelStatus.cancelled.name,
        'cancelledBy': currentUserId,
      });
      await clearResumableMatch();
    } catch (e) {
      debugPrint('Error cancelling match: $e');
    }

    _matchSubscription?.cancel();
    _currentMatch = null;
    _matchController.add(null);
  }

  /// Belirli bir maçı iptal et (Gereksiz Ghost maçları önlemek için)
  Future<void> cancelMatchById(String matchId) async {
    try {
      await _rtdb.ref(_rtdbMatchesNode).child(matchId).update({
        'status': OnlineDuelStatus.cancelled.name,
        'cancelledBy': _currentUserId,
      });
      debugPrint('🧹 OnlineDuelService: Match $matchId cancelled by ID.');
    } catch (e) {
      debugPrint('⚠️ OnlineDuelService: Error cancelling match by ID ($matchId): $e');
    }
  }

  /// Maç dinleyicisini kapat
  void dispose() {
    _matchSubscription?.cancel();
    _matchController.close();
    stopInvitationListener();
    _invitationController.close();
  }

  /// Davet dinleyiciyi başlat
  void startInvitationListener() {
    _startInvitationListenerInternal();
  }

  void _startInvitationListenerInternal() {
    // Current ID'yi tazele
    _currentUserId = AuthService.instance.userId;

    if (_currentUserId == null) {
      debugPrint('🔔 OnlineDuelService: ID null, skipping listener start.');
      return;
    }
    _startInvitationListener();
  }

  void _startInvitationListener() {
    // Mevcut bir dinleyici varsa ve farklı bir kullanıcı içinse durdur
    if (_invitationListener != null) {
        debugPrint('🔔 OnlineDuelService: Stopping previous listener before starting new one');
        stopInvitationListener();
    }

    if (_currentUserId == null) return;
    
    debugPrint('🔔 OnlineDuelService: STARTING invitation listener for User: $_currentUserId');
    
    _invitationListener = _firestore
        .collection('notifications')
        .where('toUserId', isEqualTo: _currentUserId)
        .where('type', isEqualTo: 'duel_invite')
        .where('read', isEqualTo: false)
        .snapshots()
        .listen((snapshot) {
      debugPrint('🔔 OnlineDuelService: Snapshot received. Documents found: ${snapshot.docs.length} for user $_currentUserId');
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final data = change.doc.data()!;
          debugPrint('🔔 OnlineDuelService: Processing NEW Notification: ${change.doc.id}');
          final fromUserId = data['fromUserId']?.toString() ?? '';
          final fromUsername = data['fromUsername']?.toString() ?? 'Rakip';
          final matchId = data['matchId']?.toString() ?? '';
          
          debugPrint('🔔 OnlineDuelService: NEW INVITATION DETECTED! From: $fromUsername (ID: $fromUserId), Match: $matchId');
          final leagueCode = data['leagueCode']?.toString() ?? 'A1';
          final rawCreatedAt = data['createdAt'];
          final createdAt = (rawCreatedAt is Timestamp) 
              ? rawCreatedAt.toDate() 
              : (rawCreatedAt is String ? DateTime.tryParse(rawCreatedAt) : null) ?? DateTime.now();
          
          final now = DateTime.now();
          // Timeout: Arkadaş daveti için 5 dakika, rastgele için 60 saniye (yükseltildi)
          // Bu listener'da gelen davetin türünü doğrudan bilemeyiz, bu yüzden genel bir timeout uygulayalım.
          // Davet oluşturulurken belirlenen expiresAt değeri daha doğru olacaktır.
          // Şimdilik, 1 dakikadan eski bildirimleri yoksaymaya devam edelim.
          // Timeout: Çok eski davetleri (60 dakikadan eski) yoksay. 
          // Not: 5 dakikadan 60 dakikaya çıkardık ki telefonlar arası saat farkı kesinlikle sorun olmasın.
          if (now.difference(createdAt).inMinutes >= 60) {
            debugPrint('🔔 OnlineDuelService: IGNORING OLD INVITATION from $fromUsername ($matchId) - Created at: $createdAt, Now: $now');
            markNotificationAsRead(matchId);
            continue;
          }
          
          final invitation = DuelInvitation(
            id: matchId,
            fromUser: Friend(
              userId: fromUserId,
              username: fromUsername,
              status: OnlineStatus.online,
              friendStatus: FriendStatus.accepted,
            ),
            leagueCode: leagueCode,
            createdAt: createdAt,
            expiresAt: createdAt.add(const Duration(minutes: 5)),
          );
          _invitationController.add(invitation);
          debugPrint('🔔 OnlineDuelService: Invitation sent to UI stream.');
        }
      }
    }, onError: (e) {
        debugPrint('❌ OnlineDuelService: Invitation Listener Error! Details: $e');
        if (e.toString().contains('FAILED_PRECONDITION')) {
          debugPrint('⚠️ OnlineDuelService: Missing Firestore Index for Notifications! Please check the error message for the creation link.');
        }
    });
  }

  /// Yeni bir davet simüle et (test için)
  void simulateIncomingInvitation() {
    debugPrint('🧪 OnlineDuelService: Simulating incoming invitation...');
    final invitation = DuelInvitation(
      id: 'sim_${DateTime.now().millisecondsSinceEpoch}',
      fromUser: const Friend(
        userId: 'demo_2',
        username: 'VocabNinja',
        status: OnlineStatus.online,
        friendStatus: FriendStatus.accepted,
      ),
      leagueCode: 'B2',
      createdAt: DateTime.now(),
      expiresAt: DateTime.now().add(const Duration(seconds: 30)),
    );
    _invitationController.add(invitation);
    debugPrint('🧪 OnlineDuelService: Simulated invitation added to stream');
  }

  /// Davet dinleyiciyi durdur
  void stopInvitationListener() {
    _invitationListener?.cancel();
    _invitationListener = null;
  }

  /// Düello davetini kabul et ve maç objesini döndür (Gerçek Veri)
  Future<OnlineDuelMatch?> acceptDuelInvitationAndGetMatch(DuelInvitation invitation) async {
    try {
      final match = await joinMatch(invitation.id);
      if (match != null) {
        // Bildirimi okundu olarak işaretle
        await markNotificationAsRead(invitation.id);
        return match;
      }
    } catch (e) {
      debugPrint('Error accepting invitation: $e');
    }
    return null;
  }

  /// Düello davetini reddet
  Future<bool> declineDuelInvitation(DuelInvitation invitation) async {
    await markNotificationAsRead(invitation.id);
    return true;
  }

  /// Bildirimi okundu yap
  Future<void> markNotificationAsRead(String matchId) async {
    final userId = AuthService.instance.userId;
    if (userId == null) return;
    
    try {
      final snapshot = await _firestore
          .collection('notifications')
          .where('toUserId', isEqualTo: userId)
          .where('matchId', isEqualTo: matchId)
          .get();
          
      for (var doc in snapshot.docs) {
        await doc.reference.update({'read': true});
      }
    } catch (e) {
      debugPrint('Error marking notification as read: $e');
    }
  }

  OnlineDuelMatch _createDemoMatch(String leagueCode) {
    final matchId = 'demo_${DateTime.now().millisecondsSinceEpoch}';
    final questions = _generateQuestions(leagueCode);
    
    final match = OnlineDuelMatch(
      matchId: matchId,
      hostUserId: _currentUserId ?? 'demo_user',
      hostUsername: _currentUsername ?? 'Player',
      guestUserId: 'bot_user',
      guestUsername: 'Bot 🤖',
      leagueCode: leagueCode,
      status: OnlineDuelStatus.ready,
      questions: questions,
      playerAnswers: {},
      createdAt: DateTime.now(),
    );
    
    _saveActiveMatch(match);
    return match;
  }

  /// Sorular oluştur
  /// Sorular oluştur (Dinamik)
  List<OnlineDuelQuestion> _generateQuestions(String leagueCode, {Map<String, String>? wordOfTheDay}) {
    // League code'u UserLevel'a çevir
    UserLevel level = UserLevel.a1;
    final code = leagueCode.toUpperCase();
    
    if (code.contains('C2')) {
      level = UserLevel.c2;
    } else if (code.contains('C1') || code == 'C') level = UserLevel.c1;
    else if (code.contains('B2')) level = UserLevel.b2;
    else if (code.contains('B1') || code == 'B') level = UserLevel.b1;
    else if (code.contains('A2')) level = UserLevel.a2;
    else level = UserLevel.a1;

    // WordPoolService ile soruları oluştur
    var generated = WordPoolService.instance.generateQuestions(level);
    if (wordOfTheDay != null) {
      final injected = WordPoolService.instance.createQuestionFromFact(wordOfTheDay, level.code.toUpperCase());
      if (generated.isNotEmpty) {
        generated[0] = injected;
        generated.shuffle();
      }
    }
    
    // OnlineDuelQuestion formatına çevir
    final onlineQuestions = <OnlineDuelQuestion>[];
    for (int i = 0; i < generated.length; i++) {
        if (i >= 10) break; // Max 10 soru
      final g = generated[i];
      
      // QuestionType to QuestionMode mapping
      QuestionMode mode = QuestionMode.enToTr;
      if (g.mode.name == 'enToTr') {
        mode = QuestionMode.enToTr;
      } else if (g.mode.name == 'trToEn') mode = QuestionMode.trToEn;
      else if (g.mode.name == 'synonym' || g.mode.name == 'antonym') mode = QuestionMode.engToEng;

      onlineQuestions.add(OnlineDuelQuestion(
        id: 'q_$i',
        prompt: g.prompt,
        options: g.options,
        correctIndex: g.correctIndex,
        mode: mode,
        turkishMeaning: g.turkishMeaning,
      ));
    }

    // Eğer yeterli soru oluşmadıysa demo sorulardan ekle (Güvenlik)
    if (onlineQuestions.length < 10) {
      final demos = getDemoQuestions();
      for (int i = onlineQuestions.length; i < 10; i++) {
        final d = demos[i % demos.length];
        onlineQuestions.add(OnlineDuelQuestion(
          id: 'q_demo_$i',
          prompt: d['english'],
          options: List<String>.from(d['options']),
          correctIndex: d['correctIndex'],
          mode: QuestionMode.enToTr,
        ));
      }
    }

    return onlineQuestions;
  }
  
  /// Demo sorular - MaxiGame için public erişim
  List<Map<String, dynamic>> getDemoQuestions() {
    final allQuestions = <Map<String, dynamic>>[
      {'english': 'abandon', 'options': ['terk etmek', 'kabul etmek', 'başarmak', 'reddetmek'], 'correctIndex': 0},
      {'english': 'brilliant', 'options': ['karanlık', 'parlak', 'yavaş', 'sakin'], 'correctIndex': 1},
      {'english': 'courage', 'options': ['korku', 'şüphe', 'cesaret', 'utanç'], 'correctIndex': 2},
      {'english': 'diligent', 'options': ['tembel', 'yorgun', 'kızgın', 'çalışkan'], 'correctIndex': 3},
      {'english': 'enormous', 'options': ['devasa', 'küçücük', 'orta', 'dar'], 'correctIndex': 0},
      {'english': 'fierce', 'options': ['nazik', 'azgın', 'sakin', 'yavaş'], 'correctIndex': 1},
      {'english': 'generous', 'options': ['cimri', 'zalim', 'cömert', 'korkak'], 'correctIndex': 2},
      {'english': 'hesitate', 'options': ['acele etmek', 'karar vermek', 'emin olmak', 'tereddüt etmek'], 'correctIndex': 3},
      {'english': 'immense', 'options': ['muazzam', 'minik', 'normal', 'kısa'], 'correctIndex': 0},
      {'english': 'jealous', 'options': ['mutlu', 'kıskanç', 'sakin', 'nazik'], 'correctIndex': 1},
      {'english': 'keen', 'options': ['yorgun', 'üzgün', 'hevesli', 'korkak'], 'correctIndex': 2},
      {'english': 'loyal', 'options': ['hain', 'yabancı', 'düşman', 'sadık'], 'correctIndex': 3},
      {'english': 'magnificent', 'options': ['muhteşem', 'sıradan', 'kötü', 'korkunç'], 'correctIndex': 0},
      {'english': 'noble', 'options': ['kaba', 'asil', 'fakir', 'acı'], 'correctIndex': 1},
      {'english': 'obvious', 'options': ['gizli', 'karmaşık', 'açık', 'belirsiz'], 'correctIndex': 2},
      {'english': 'precious', 'options': ['ucuz', 'eski', 'kirli', 'değerli'], 'correctIndex': 3},
      {'english': 'quiet', 'options': ['sessiz', 'gürültülü', 'hızlı', 'parlak'], 'correctIndex': 0},
      {'english': 'rapid', 'options': ['yavaş', 'hızlı', 'sakin', 'ağır'], 'correctIndex': 1},
      {'english': 'sincere', 'options': ['sahte', 'kurnaz', 'samimi', 'yalancı'], 'correctIndex': 2},
      {'english': 'tremendous', 'options': ['küçük', 'zayıf', 'yavaş', 'muazzam'], 'correctIndex': 3},
    ];
    allQuestions.shuffle();
    return allQuestions;
  }
}
