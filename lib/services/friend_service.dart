import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/friend.dart';

/// Arkadaş yönetim servisi
/// Not: Bu şu anda offline simülasyon modunda çalışır.
/// Gerçek backend entegrasyonu için Firebase/Supabase eklenebilir.
class FriendService {
  static final FriendService instance = FriendService._();
  FriendService._();

  static const String _friendsKey = 'wardict_friends';
  static const String _invitationsKey = 'wardict_duel_invitations';
  static const String _pendingRequestsKey = 'wardict_pending_requests';

  // Demo arkadaşlar (simülasyon için)
  static final List<Friend> _demoFriends = [
    Friend(
      oderId: 'demo_1',
      username: 'WordMaster42',
      status: OnlineStatus.online,
      friendStatus: FriendStatus.accepted,
      eloRating: 1650,
      currentLeague: 'Intermediate',
      lastOnline: DateTime.now(),
    ),
    Friend(
      oderId: 'demo_2',
      username: 'VocabNinja',
      status: OnlineStatus.away,
      friendStatus: FriendStatus.accepted,
      eloRating: 1420,
      currentLeague: 'Beginner',
      lastOnline: DateTime.now().subtract(const Duration(minutes: 15)),
    ),
    Friend(
      oderId: 'demo_3',
      username: 'EnglishPro',
      status: OnlineStatus.offline,
      friendStatus: FriendStatus.accepted,
      eloRating: 1890,
      currentLeague: 'Advanced',
      lastOnline: DateTime.now().subtract(const Duration(hours: 3)),
    ),
    Friend(
      oderId: 'demo_4',
      username: 'LexiconLord',
      status: OnlineStatus.online,
      friendStatus: FriendStatus.accepted,
      eloRating: 1550,
      currentLeague: 'Intermediate',
      lastOnline: DateTime.now(),
    ),
    Friend(
      oderId: 'demo_5',
      username: 'GrammarGuru',
      status: OnlineStatus.busy,
      friendStatus: FriendStatus.accepted,
      eloRating: 1720,
      currentLeague: 'Intermediate',
      lastOnline: DateTime.now().subtract(const Duration(minutes: 5)),
    ),
  ];

  // Demo gelen istekler
  static final List<Friend> _demoPendingRequests = [
    Friend(
      oderId: 'pending_1',
      username: 'NewLearner2024',
      status: OnlineStatus.online,
      friendStatus: FriendStatus.requested,
      eloRating: 1350,
      currentLeague: 'Beginner',
    ),
    Friend(
      oderId: 'pending_2',
      username: 'WordWizard',
      status: OnlineStatus.offline,
      friendStatus: FriendStatus.requested,
      eloRating: 1600,
      currentLeague: 'Intermediate',
      lastOnline: DateTime.now().subtract(const Duration(days: 1)),
    ),
  ];

  /// Arkadaş listesini getir
  Future<List<Friend>> getFriends() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_friendsKey);
    
    if (json != null) {
      final List<dynamic> list = jsonDecode(json);
      return list.map((e) => Friend.fromJson(e)).toList();
    }
    
    // İlk kullanımda demo arkadaşları kaydet
    await _saveFriends(_demoFriends);
    return _demoFriends;
  }

  /// Arkadaşları kaydet
  Future<void> _saveFriends(List<Friend> friends) async {
    final prefs = await SharedPreferences.getInstance();
    final json = jsonEncode(friends.map((f) => f.toJson()).toList());
    await prefs.setString(_friendsKey, json);
  }

  /// Bekleyen arkadaşlık isteklerini getir
  Future<List<Friend>> getPendingRequests() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_pendingRequestsKey);
    
    if (json != null) {
      final List<dynamic> list = jsonDecode(json);
      return list.map((e) => Friend.fromJson(e)).toList();
    }
    
    // İlk kullanımda demo istekleri kaydet
    await _savePendingRequests(_demoPendingRequests);
    return _demoPendingRequests;
  }

  /// Bekleyen istekleri kaydet
  Future<void> _savePendingRequests(List<Friend> requests) async {
    final prefs = await SharedPreferences.getInstance();
    final json = jsonEncode(requests.map((f) => f.toJson()).toList());
    await prefs.setString(_pendingRequestsKey, json);
  }

  /// Arkadaşlık isteği gönder
  Future<bool> sendFriendRequest(String username) async {
    // Simülasyon: İstek gönderildi
    // Gerçek uygulamada backend'e API çağrısı yapılır
    await Future.delayed(const Duration(milliseconds: 500));
    return true;
  }

  /// Arkadaşlık isteğini kabul et
  Future<bool> acceptFriendRequest(String oderId) async {
    final requests = await getPendingRequests();
    final friends = await getFriends();
    
    final requestIndex = requests.indexWhere((r) => r.oderId == oderId);
    if (requestIndex == -1) return false;
    
    final request = requests[requestIndex];
    
    // İsteği listeden kaldır
    requests.removeAt(requestIndex);
    await _savePendingRequests(requests);
    
    // Arkadaş listesine ekle
    final newFriend = request.copyWith(friendStatus: FriendStatus.accepted);
    friends.add(newFriend);
    await _saveFriends(friends);
    
    return true;
  }

  /// Arkadaşlık isteğini reddet
  Future<bool> rejectFriendRequest(String oderId) async {
    final requests = await getPendingRequests();
    requests.removeWhere((r) => r.oderId == oderId);
    await _savePendingRequests(requests);
    return true;
  }

  /// Arkadaşı sil
  Future<bool> removeFriend(String oderId) async {
    final friends = await getFriends();
    friends.removeWhere((f) => f.oderId == oderId);
    await _saveFriends(friends);
    return true;
  }

  /// Kullanıcı ara (simülasyon)
  Future<List<Friend>> searchUsers(String query) async {
    if (query.length < 3) return [];
    
    // Simülasyon: Arama sonuçları
    await Future.delayed(const Duration(milliseconds: 300));
    
    return [
      Friend(
        oderId: 'search_1',
        username: 'Player_${query}123',
        status: OnlineStatus.online,
        friendStatus: FriendStatus.none,
        eloRating: 1500,
        currentLeague: 'Beginner',
      ),
      Friend(
        oderId: 'search_2',
        username: '${query}_Master',
        status: OnlineStatus.offline,
        friendStatus: FriendStatus.none,
        eloRating: 1650,
        currentLeague: 'Intermediate',
        lastOnline: DateTime.now().subtract(const Duration(hours: 2)),
      ),
    ];
  }

  /// Bekleyen düello davetlerini getir
  Future<List<DuelInvitation>> getDuelInvitations() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_invitationsKey);
    
    if (json != null) {
      final List<dynamic> list = jsonDecode(json);
      // Not: DuelInvitation için toJson/fromJson eklenmesi gerekebilir 
      // veya burada manuel eşleme yapılabilir. 
      // Basitlik için şu an demo dönelim.
    }
    
    // Simülasyon için bazen bir davet varmış gibi yapalım
    final now = DateTime.now();
    if (now.second % 10 == 0) { // Her 10 saniyede bir şans
       return [
         DuelInvitation(
           id: 'demo_inv',
           fromUser: _demoFriends[0],
           leagueCode: 'B1',
           createdAt: now,
           expiresAt: now.add(const Duration(minutes: 2)),
         )
       ];
    }
    
    return [];
  }

  /// Yeni bir davet simüle et (test için)
  Future<void> simulateIncomingInvitation() async {
    // Bu metod UI'da bir bildirimi tetiklemek için kullanılabilir
  }

  /// Düello daveti gönder
  Future<DuelInvitation?> sendDuelInvitation(Friend friend, String leagueCode) async {
    // Simülasyon
    await Future.delayed(const Duration(milliseconds: 300));
    
    final invitation = DuelInvitation(
      id: 'inv_${DateTime.now().millisecondsSinceEpoch}',
      fromUser: Friend(
        oderId: 'current_user',
        username: 'Sen',
        status: OnlineStatus.online,
        friendStatus: FriendStatus.accepted,
      ),
      leagueCode: leagueCode,
      createdAt: DateTime.now(),
      expiresAt: DateTime.now().add(const Duration(seconds: 30)),
    );
    
    return invitation;
  }

  /// Düello davetini kabul et (simülasyon)
  Future<String?> acceptDuelInvitation(DuelInvitation invitation) async {
    await Future.delayed(const Duration(milliseconds: 500));
    // Gerçek uygulamada matchId döndürülür
    return 'match_${DateTime.now().millisecondsSinceEpoch}';
  }

  /// Düello davetini reddet
  Future<bool> declineDuelInvitation(DuelInvitation invitation) async {
    await Future.delayed(const Duration(milliseconds: 200));
    return true;
  }

  /// Online arkadaşları getir
  Future<List<Friend>> getOnlineFriends() async {
    final friends = await getFriends();
    return friends.where((f) => f.status == OnlineStatus.online).toList();
  }

  /// Rastgele eşleşme ara (simülasyon)
  Future<Friend?> findRandomOpponent(String leagueCode) async {
    // Simülasyon: 2-5 saniye bekle
    await Future.delayed(Duration(seconds: 2 + DateTime.now().second % 3));
    
    // Demo rakip
    return Friend(
      oderId: 'random_${DateTime.now().millisecondsSinceEpoch}',
      username: 'RandomPlayer${DateTime.now().second}',
      status: OnlineStatus.online,
      friendStatus: FriendStatus.none,
      eloRating: 1450 + (DateTime.now().millisecond % 200),
      currentLeague: leagueCode == 'A' ? 'Beginner' : leagueCode == 'B' ? 'Intermediate' : 'Advanced',
    );
  }
}
