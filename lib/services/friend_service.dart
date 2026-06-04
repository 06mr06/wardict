import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase/auth_service.dart';
import 'online_duel_service.dart';
import '../models/friend.dart';
import '../models/online_duel.dart';

/// Arkadaş yönetim servisi
/// Not: Bu şu anda offline simülasyon modunda çalışır.
/// Gerçek backend entegrasyonu için Firebase/Supabase eklenebilir.
class FriendService {
  static final FriendService instance = FriendService._();
  FriendService._();

  static const String _friendsKey = 'lugorena_friends';
  static const String _invitationsKey = 'lugorena_duel_invitations';
  static const String _pendingRequestsKey = 'lugorena_pending_requests';



  // Demo veriler tamamen kaldırıldı.
  static final List<Friend> _demoFriends = [];
  static final List<Friend> _demoPendingRequests = [];

  /// Arkadaş listesini getir
  Future<List<Friend>> getFriends() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_friendsKey);
    
    if (json != null) {
      final List<dynamic> list = jsonDecode(json);
      final friends = list
          .map((e) => Friend.fromJson(e))
          .where((f) => !f.userId.startsWith('demo_'))
          .toList();
          
      // Online durumlarını güncelle
      final updatedFriends = await Future.wait(friends.map((f) async {
        final isOnline = await OnlineDuelService.instance.isUserOnline(f.userId);
        return f.copyWith(status: isOnline ? OnlineStatus.online : OnlineStatus.offline);
      }));
      
      return updatedFriends.toList();
    }
    
    return []; // Demo verisi yok, boş liste döndür.
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
    
    return []; // Demo verisi yok, boş liste döndür.
  }

  /// Bekleyen istekleri kaydet
  Future<void> _savePendingRequests(List<Friend> requests) async {
    final prefs = await SharedPreferences.getInstance();
    final json = jsonEncode(requests.map((f) => f.toJson()).toList());
    await prefs.setString(_pendingRequestsKey, json);
  }

  /// Arkadaşlık isteği gönder / Arkadaş olarak ekle
  Future<bool> sendFriendRequest(Friend friend) async {
    try {
      final friends = await getFriends();
      if (!friends.any((f) => f.userId == friend.userId)) {
        friends.add(friend.copyWith(friendStatus: FriendStatus.accepted, status: OnlineStatus.online));
        await _saveFriends(friends);
      }
      return true;
    } catch (e) {
      debugPrint('Error adding friend: $e');
      return false;
    }
  }

  /// Arkadaşlık isteğini kabul et
  Future<bool> acceptFriendRequest(String userId) async {
    final requests = await getPendingRequests();
    final friends = await getFriends();
    
    final requestIndex = requests.indexWhere((r) => r.userId == userId);
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
  Future<bool> rejectFriendRequest(String userId) async {
    final requests = await getPendingRequests();
    requests.removeWhere((r) => r.userId == userId);
    await _savePendingRequests(requests);
    return true;
  }

  /// Arkadaşı sil
  Future<bool> removeFriend(String userId) async {
    final friends = await getFriends();
    friends.removeWhere((f) => f.userId == userId);
    await _saveFriends(friends);
    return true;
  }

  /// Kullanıcı ara (Firestore)
  Future<List<Friend>> searchUsers(String query) async {
    if (query.trim().length < 3) return [];
    
    try {
      debugPrint('🔍 Searching for: "$query"');
      
      // Küçük harfe çevir (case-insensitive arama için)
      final lowerQuery = query.toLowerCase();
      
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('username', isGreaterThanOrEqualTo: query)
          .where('username', isLessThanOrEqualTo: '$query\uf8ff')
          .limit(10)
          .get();

      debugPrint('📦 Raw results: ${snapshot.docs.length} documents');
      
      final results = await Future.wait(snapshot.docs
          .where((doc) {
            final data = doc.data();
            final username = (data['username'] ?? '').toString();
            final matches = username.toLowerCase().contains(lowerQuery);
            return matches;
          })
          .map((doc) async {
        final data = doc.data();
        final userId = doc.id;
        
        // RTDB'den online durumunu çek
        final isOnline = await OnlineDuelService.instance.isUserOnline(userId);
        
        // Level string veya map olabilir, güvenli şekilde işle
        String leagueName = 'Beginner';
        final levelData = data['level'];
        if (levelData != null) {
          if (levelData is String) {
            leagueName = levelData;
          } else if (levelData is Map) {
            leagueName = levelData['turkishName'] ?? 'Beginner';
          }
        }
        
        return Friend(
          userId: userId,
          username: data['username'] ?? 'Unknown',
          status: isOnline ? OnlineStatus.online : OnlineStatus.offline,
          friendStatus: FriendStatus.none,
          lpRating: (data['lpRating'] ?? data['eloRating'] as num?)?.toInt() ?? 1000,
          currentLeague: leagueName,
        );
      }));
      
      debugPrint('🎯 Raw results count: ${results.length}');
      
      // Filter unique users by userId first
      final uniqueResults = <String, Friend>{};
      for (var friend in results) {
        uniqueResults[friend.userId] = friend;
      }
      
      // Secondary filter: deduplicate by (username + league + LP) to hide accidental duplicates in case of data sync errors
      final deduplicatedByStats = <String, Friend>{};
      for (var friend in uniqueResults.values) {
        final key = '${friend.username.toLowerCase()}_${friend.currentLeague}_${friend.lpRating}';
        if (!deduplicatedByStats.containsKey(key)) {
          deduplicatedByStats[key] = friend;
        }
      }
      
      final finalResults = deduplicatedByStats.values.toList();
      debugPrint('🎯 Returning ${finalResults.length} unique users');
      return finalResults;
    } catch (e) {
      debugPrint('❌ Search users error: $e');
      return [];
    }
  }

  /// Bekleyen düello davetlerini getir (Gerçek Veri)
  Future<List<DuelInvitation>> getDuelInvitations() async {
    final userId = AuthService.instance.userId;
    if (userId == null) return [];
    
    try {
      // Not: orderBy kullanmıyoruz çünkü compound index gerektirebilir. 
      // Dart tarafında sıralama yapacağız.
      final snapshot = await FirebaseFirestore.instance
          .collection('notifications')
          .where('toUserId', isEqualTo: userId)
          .where('type', isEqualTo: 'duel_invite')
          .where('read', isEqualTo: false)
          .limit(10)
          .get();
          
      final List<DuelInvitation> invitations = [];
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final fromUserId = (data['fromUserId'] ?? '').toString();
        final fromUsername = (data['fromUsername'] ?? 'Rakip').toString();
        final matchId = (data['matchId'] ?? '').toString();
        final leagueCode = (data['leagueCode'] ?? 'A1').toString();
        final rawCreatedAt = data['createdAt'];
        final createdAt = (rawCreatedAt is Timestamp) 
            ? rawCreatedAt.toDate() 
            : (rawCreatedAt is String ? DateTime.tryParse(rawCreatedAt) : null) ?? DateTime.now();
        
        invitations.add(DuelInvitation(
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
        ));
      }
      
      // En yeni daveti başa al
      invitations.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      
      return invitations;
    } catch (e) {
      debugPrint('❌ FriendService: Error fetching invitations: $e');
      return [];
    }
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
      userId: 'random_${DateTime.now().millisecondsSinceEpoch}',
      username: 'RandomPlayer${DateTime.now().second}',
      status: OnlineStatus.online,
      friendStatus: FriendStatus.none,
      lpRating: 1450 + (DateTime.now().millisecond % 200),
      currentLeague: leagueCode == 'A' ? 'Beginner' : leagueCode == 'B' ? 'Intermediate' : 'Advanced',
    );
  }
}
