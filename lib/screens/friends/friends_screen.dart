import 'package:flutter/material.dart';
import '../../models/friend.dart';
import '../../services/friend_service.dart';
import '../../services/online_duel_service.dart';
import '../game/matchmaking_screen.dart';

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
  List<Friend> _searchResults = [];
  
  bool _isLoading = true;
  bool _isSearching = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    final friends = await FriendService.instance.getFriends();
    final pending = await FriendService.instance.getPendingRequests();
    
    setState(() {
      _friends = friends;
      _pendingRequests = pending;
      _isLoading = false;
    });
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
    final success = await FriendService.instance.sendFriendRequest(user.username);
    
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${user.username} kullanıcısına istek gönderildi'),
          backgroundColor: Colors.green,
        ),
      );
      
      // Sonuçlardan kaldır
      setState(() {
        _searchResults.removeWhere((r) => r.oderId == user.oderId);
      });
    }
  }

  Future<void> _acceptRequest(Friend friend) async {
    final success = await FriendService.instance.acceptFriendRequest(friend.oderId);
    if (success) {
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${friend.username} artık arkadaşın! 🎉'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  Future<void> _rejectRequest(Friend friend) async {
    final success = await FriendService.instance.rejectFriendRequest(friend.oderId);
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
      final success = await FriendService.instance.removeFriend(friend.oderId);
      if (success) {
        await _loadData();
      }
    }
  }

  Future<void> _sendDuelInvitation(Friend friend) async {
    final leagueCode = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${friend.username} ile Düello'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Hangi ligde düello yapmak istersin?'),
            const SizedBox(height: 16),
            _LeagueOption(
              icon: '🌱',
              title: 'Beginner',
              subtitle: 'Temel kelimeler',
              onTap: () => Navigator.pop(ctx, 'A'),
            ),
            const SizedBox(height: 8),
            _LeagueOption(
              icon: '⚡',
              title: 'Intermediate',
              subtitle: 'Orta seviye',
              onTap: () => Navigator.pop(ctx, 'B'),
            ),
            const SizedBox(height: 8),
            _LeagueOption(
              icon: '🔥',
              title: 'Advanced',
              subtitle: 'İleri seviye',
              onTap: () => Navigator.pop(ctx, 'C'),
            ),
          ],
        ),
      ),
      ),
    );
    
    if (leagueCode != null && mounted) {
      final invitation = await FriendService.instance.sendDuelInvitation(friend, leagueCode);
      
      if (invitation != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${friend.username} kullanıcısına düello daveti gönderildi! ⚔️'),
            backgroundColor: Colors.orange,
          ),
        );
        
        // Bekleme ekranını göster
        _showWaitingDialog(friend, invitation);
      }
    }
  }

  void _showWaitingDialog(Friend friend, DuelInvitation invitation) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _WaitingDialog(
        friend: friend,
        invitation: invitation,
        onCancel: () => Navigator.pop(ctx),
        onAccepted: () {
          Navigator.pop(ctx);
          // Online düello matchmaking ekranına git
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => MatchmakingScreen(
                leagueCode: invitation.leagueCode,
                invitedFriend: friend,
              ),
            ),
          );
        },
      ),
    );
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
                    Container(
                      margin: const EdgeInsets.only(left: 4),
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${_pendingRequests.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                        ),
                      ),
                    ),
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
            if (friend.eloRating != null) ...[
              const Text(' • '),
              Text('${friend.eloRating} ELO'),
            ],
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (onDuel != null)
              IconButton(
                icon: const Icon(Icons.sports_esports, color: Colors.orange),
                tooltip: 'Düello Daveti Gönder',
                onPressed: onDuel,
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
        subtitle: friend.eloRating != null
            ? Text('${friend.eloRating} ELO • ${friend.currentLeague ?? ""}')
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

  const _SearchResultTile({
    required this.user,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.teal.shade100,
          child: Text(
            user.username[0].toUpperCase(),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(user.username),
        subtitle: user.eloRating != null
            ? Text('${user.eloRating} ELO • ${user.currentLeague ?? ""}')
            : null,
        trailing: ElevatedButton.icon(
          onPressed: onAdd,
          icon: const Icon(Icons.person_add),
          label: const Text('Ekle'),
        ),
      ),
    );
  }
}

// Lig seçim kartı
class _LeagueOption extends StatelessWidget {
  final String icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _LeagueOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Text(icon, style: const TextStyle(fontSize: 28)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                ],
              ),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }
}

// Bekleme dialogu
class _WaitingDialog extends StatefulWidget {
  final Friend friend;
  final DuelInvitation invitation;
  final VoidCallback onCancel;
  final VoidCallback onAccepted;

  const _WaitingDialog({
    required this.friend,
    required this.invitation,
    required this.onCancel,
    required this.onAccepted,
  });

  @override
  State<_WaitingDialog> createState() => _WaitingDialogState();
}

class _WaitingDialogState extends State<_WaitingDialog> {
  int _remainingSeconds = 30;
  bool _isAccepted = false;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  void _startCountdown() async {
    while (_remainingSeconds > 0 && !_isAccepted && mounted) {
      await Future.delayed(const Duration(seconds: 1));
      
      // %20 ihtimalle kabul edilsin (demo için)
      if (_remainingSeconds == 25 && mounted) {
        setState(() => _isAccepted = true);
        await Future.delayed(const Duration(seconds: 1));
        widget.onAccepted();
        return;
      }
      
      if (mounted) {
        setState(() => _remainingSeconds--);
      }
    }
    
    if (_remainingSeconds == 0 && mounted) {
      widget.onCancel();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Düello Daveti Gönderildi'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text('${widget.friend.username} yanıt bekliyor...'),
          const SizedBox(height: 8),
          Text(
            '$_remainingSeconds saniye',
            style: TextStyle(
              color: _remainingSeconds < 10 ? Colors.red : Colors.grey,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: widget.onCancel,
          child: const Text('İptal'),
        ),
      ],
    );
  }
}
