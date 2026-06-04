import 'package:flutter/material.dart';
import '../../models/friend.dart';
import '../../services/friend_service.dart';
import '../../services/user_profile_service.dart';
import '../../models/league.dart';
import '../../models/online_duel.dart';
import '../../services/online_duel_service.dart';
import '../game/matchmaking_screen.dart';
import '../game/online_duel_screen.dart';
import 'dart:async';
import '../../services/quest_service.dart';
import '../../models/quest.dart';

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  
  List<Friend> _friends = [];
  List<Friend> _pendingRequests = [];
  List<DuelInvitation> _duelInvitations = [];
  List<Friend> _searchResults = [];
  
  bool _isLoading = true;
  bool _isSearching = false;
  String _searchQuery = '';
  StreamSubscription? _invitationSubscription;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
    _listenToDuelInvitations();
  }

  @override
  void dispose() {
    _invitationSubscription?.cancel();
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _listenToDuelInvitations() {
    _invitationSubscription = OnlineDuelService.instance.onInvitationReceived.listen((invitation) {
      if (mounted) {
        _loadDuelInvitations();
      }
    });
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    final friends = await FriendService.instance.getFriends();
    final pending = await FriendService.instance.getPendingRequests();
    await _loadDuelInvitations();
    
    setState(() {
      _friends = friends;
      _pendingRequests = pending;
      _isLoading = false;
    });
  }

  Future<void> _loadDuelInvitations() async {
    final invitations = await FriendService.instance.getDuelInvitations();
    if (mounted) {
      setState(() {
        _duelInvitations = invitations;
      });
    }
  }

  Future<void> _acceptDuel(DuelInvitation invitation) async {
    setState(() => _isLoading = true);
    final match = await OnlineDuelService.instance.acceptDuelInvitationAndGetMatch(invitation);
    
    if (mounted) {
      setState(() => _isLoading = false);
      if (match != null) {
        // Görev: Sosyal Kelebek
        QuestService.instance.updateProgress(QuestType.buddyDuel, 1);
        
        // MAÇI BAŞLAT VE OYUN EKRANINA GİT
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => OnlineDuelScreen(match: match),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Maça katılamadınız. Maç iptal edilmiş olabilir.')),
        );
        _loadDuelInvitations();
      }
    }
  }

  Future<void> _searchUsers(String query) async {
    if (query.length < 3) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }
    
    setState(() => _isSearching = true);
    
    final results = await FriendService.instance.searchUsers(query);
    
    setState(() {
      _searchResults = results;
      _isSearching = false;
    });
  }

  Future<void> _sendFriendRequest(Friend user) async {
    final success = await FriendService.instance.sendFriendRequest(user);
    
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${user.username} arkadaş listesine eklendi.')),
      );
      // Arkadaşlık eklendikten sonra listeyi güncelle
      _loadData();
      // Sonuçlardan kaldır
      setState(() {
        _searchResults.removeWhere((r) => r.userId == user.userId);
      });
    }
  }

  Future<void> _acceptRequest(Friend friend) async {
    final success = await FriendService.instance.acceptFriendRequest(friend.userId);
    if (success) {
      await _loadData();
      // Sessiz onay - SnackBar gösterilmiyor
    }
  }

  Future<void> _rejectRequest(Friend friend) async {
    final success = await FriendService.instance.rejectFriendRequest(friend.userId);
    if (success) {
      await _loadData();
    }
  }

  Future<void> _removeFriend(Friend friend) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Arkadaşı Sil'),
        content: Text('${friend.username} arkadaşlıktan çıkarılsın mı?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    
    if (confirm == true) {
      final success = await FriendService.instance.removeFriend(friend.userId);
      if (success) {
        await _loadData();
      }
    }
  }

  Future<void> _sendDuelInvitation(Friend friend) async {
    // Show a small loading or processing indicator if needed, 
    // but the request is to skip asking for level.
    
    // Get current user's LP
    final profile = await UserProfileService.instance.loadProfile();
    final myLp = profile.lpRating;
    final friendLp = friend.lpRating ?? 1500;
    
    // Calculate average LP
    final averageLp = (myLp + friendLp) ~/ 2;
    
    // Determine league code automatically
    final leagueCode = League.getLeagueCodeFromLp(averageLp);
    
    if (mounted) {
      // Use real MatchmakingScreen which handles the invitation via OnlineDuelService
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => MatchmakingScreen(
            leagueCode: leagueCode, 
            invitedFriend: friend,
            isBot: false,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Arkadaşlar'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: [
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.people, size: 20),
                  const SizedBox(width: 6),
                  Text('Arkadaşlar (${_friends.length})'),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.person_add, size: 20),
                  const SizedBox(width: 6),
                  Text('İstekler (${_pendingRequests.length})'),
                  if (_pendingRequests.isNotEmpty)
                    _buildBadge(_pendingRequests.length),
                ],
              ),
            ),
            const Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.search, size: 20),
                  SizedBox(width: 6),
                  Text('Ara'),
                ],
              ),
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildFriendsList(),
                _buildRequestsList(),
                _buildSearchTab(),
              ],
            ),
    );
  }

  Widget _buildBadge(int count, {Color color = Colors.red}) {
    return Container(
      margin: const EdgeInsets.only(left: 4),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
      child: Text(
        '$count',
        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildDuelInvitationsList() {
    if (_duelInvitations.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.sports_esports_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Gelen düello daveti yok',
              style: TextStyle(color: Colors.grey[600], fontSize: 16),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadDuelInvitations,
      child: ListView.builder(
        itemCount: _duelInvitations.length,
        itemBuilder: (context, index) {
          final invitation = _duelInvitations[index];
          return _DuelInvitationTile(
            invitation: invitation,
            onAccept: () => _acceptDuel(invitation),
            onDecline: () async {
              await OnlineDuelService.instance.declineDuelInvitation(invitation);
              _loadDuelInvitations();
            },
          );
        },
      ),
    );
  }

  Widget _buildFriendsList() {
    if (_friends.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Henüz arkadaşın yok',
              style: TextStyle(color: Colors.grey[600], fontSize: 16),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: () => _tabController.animateTo(2),
              icon: const Icon(Icons.person_add),
              label: const Text('Arkadaş Ara'),
            ),
          ],
        ),
      );
    }

    // Online olanları üste al
    final sortedFriends = List<Friend>.from(_friends)
      ..sort((a, b) {
        if (a.isOnline && !b.isOnline) return -1;
        if (!a.isOnline && b.isOnline) return 1;
        return a.username.compareTo(b.username);
      });

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        itemCount: sortedFriends.length,
        itemBuilder: (context, index) {
          final friend = sortedFriends[index];
          return _FriendTile(
            friend: friend,
            onDuel: friend.canDuel ? () => _sendDuelInvitation(friend) : null,
            onRemove: () => _removeFriend(friend),
          );
        },
      ),
    );
  }

  Widget _buildRequestsList() {
    if (_pendingRequests.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.mail_outline, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Bekleyen istek yok',
              style: TextStyle(color: Colors.grey[600], fontSize: 16),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _pendingRequests.length,
      itemBuilder: (context, index) {
        final request = _pendingRequests[index];
        return _RequestTile(
          friend: request,
          onAccept: () => _acceptRequest(request),
          onReject: () => _rejectRequest(request),
        );
      },
    );
  }

  Widget _buildSearchTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Kullanıcı adı ara (min 3 karakter)',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _searchQuery = '';
                          _searchResults = [];
                        });
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onChanged: (value) {
              setState(() => _searchQuery = value);
              _searchUsers(value);
            },
          ),
        ),
        Expanded(
          child: _isSearching
              ? const Center(child: CircularProgressIndicator())
              : _searchResults.isEmpty
                  ? Center(
                      child: Text(
                        _searchQuery.length < 3
                            ? 'Aramak için en az 3 karakter girin'
                            : 'Sonuç bulunamadı',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _searchResults.length,
                      itemBuilder: (context, index) {
                        final user = _searchResults[index];
                        return _SearchResultTile(
                          user: user,
                          onAdd: () => _sendFriendRequest(user),
                          onDuel: () => _sendDuelInvitation(user), // Direct duel
                        );
                      },
                    ),
        ),
      ],
    );
  }
}

// Arkadaş listesi tile'ı
class _FriendTile extends StatelessWidget {
  final Friend friend;
  final VoidCallback? onDuel;
  final VoidCallback onRemove;

  const _FriendTile({
    required this.friend,
    required this.onDuel,
    required this.onRemove,
  });

  String _getLeagueIcon(String? league) {
    switch (league?.toLowerCase()) {
      case 'beginner':
        return '🌱';
      case 'intermediate':
        return '⚡';
      case 'advanced':
        return '🔥';
      default:
        return '🎯';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: Stack(
          children: [
            CircleAvatar(
              backgroundColor: Colors.blue.shade100,
              child: Text(
                friend.username[0].toUpperCase(),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: Color(friend.status.colorValue),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
              ),
            ),
          ],
        ),
        title: Row(
          children: [
            Flexible(
              child: Text(
                friend.username,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              _getLeagueIcon(friend.currentLeague),
              style: const TextStyle(fontSize: 16),
            ),
          ],
        ),
        subtitle: Row(
          children: [
            Text(friend.lastSeenText),
            if (friend.lpRating != null) ...[
              const Text(' • '),
              Text('${friend.lpRating} LP'),
            ],
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (onDuel != null)
              IconButton(
                icon: Icon(
                  Icons.sports_esports, 
                  color: friend.isOnline ? Colors.orange : Colors.grey,
                ),
                tooltip: friend.isOnline ? 'Düello Daveti Gönder' : 'Arkadaş Çevrimdışı',
                onPressed: friend.isOnline ? onDuel : () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Arkadaşınız çevrimdışı olduğu için düello başlatılamaz.')),
                  );
                },
              ),
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'remove') onRemove();
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'remove',
                  child: Row(
                    children: [
                      Icon(Icons.person_remove, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Arkadaşlıktan Çıkar'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// İstek tile'ı
class _RequestTile extends StatelessWidget {
  final Friend friend;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  const _RequestTile({
    required this.friend,
    required this.onAccept,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.purple.shade100,
          child: Text(
            friend.username[0].toUpperCase(),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(friend.username),
        subtitle: friend.lpRating != null
            ? Text('${friend.lpRating} LP • ${friend.currentLeague ?? ""}')
            : null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.check_circle, color: Colors.green),
              tooltip: 'Kabul Et',
              onPressed: onAccept,
            ),
            IconButton(
              icon: const Icon(Icons.cancel, color: Colors.red),
              tooltip: 'Reddet',
              onPressed: onReject,
            ),
          ],
        ),
      ),
    );
  }
}

// Arama sonucu tile'ı
class _SearchResultTile extends StatelessWidget {
  final Friend user;
  final VoidCallback onAdd;
  final VoidCallback onDuel;

  const _SearchResultTile({
    required this.user,
    required this.onAdd,
    required this.onDuel,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: Stack(
          children: [
            CircleAvatar(
              backgroundColor: Colors.teal.shade100,
              child: Text(
                user.username[0].toUpperCase(),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: Color(user.status.colorValue),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
              ),
            ),
          ],
        ),
        title: Text(user.username),
        subtitle: user.lpRating != null
            ? Text('${user.lpRating} LP • ${user.currentLeague ?? ""}')
            : null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(
                Icons.sports_esports, 
                color: user.isOnline ? Colors.orange : Colors.grey,
              ),
              tooltip: user.isOnline ? 'Düello Yap' : 'Oyuncu Çevrimdışı',
              onPressed: user.isOnline ? onDuel : () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Oyuncu çevrimdışı olduğu için düello başlatılamaz.')),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.person_add, color: Colors.blue),
              tooltip: 'Arkadaş Ekle',
              onPressed: onAdd,
            ),
          ],
        ),
      ),
    );
  }
}

// Düello davet tile'ı
class _DuelInvitationTile extends StatelessWidget {
  final DuelInvitation invitation;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  const _DuelInvitationTile({
    required this.invitation,
    required this.onAccept,
    required this.onDecline,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      color: Colors.orange.shade50,
      elevation: 2,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.orange.shade100,
          child: const Icon(Icons.sports_esports, color: Colors.orange),
        ),
        title: Text(
          '${invitation.fromUser.username} seni düelloya davet etti!',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: const Text('Kabul et ve hemen yarışmaya başla!'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.check_circle, color: Colors.green, size: 30),
              tooltip: 'Kabul Et',
              onPressed: onAccept,
            ),
            IconButton(
              icon: const Icon(Icons.cancel, color: Colors.red, size: 30),
              tooltip: 'Reddet',
              onPressed: onDecline,
            ),
          ],
        ),
      ),
    );
  }
}
