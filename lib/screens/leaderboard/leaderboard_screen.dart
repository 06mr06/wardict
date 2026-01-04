import 'package:flutter/material.dart';
import '../../services/firebase/firestore_service.dart';
import '../../services/firebase/auth_service.dart';

/// Liderlik Tablosu Ekranı
class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  List<CloudUserProfile> _globalLeaders = [];
  Map<String, List<CloudUserProfile>> _leagueLeaders = {};
  int? _userGlobalRank;
  Map<String, int> _userLeagueRanks = {};
  bool _isLoading = true;
  String? _currentUserId;

  final List<String> _leagues = ['A', 'B', 'C'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _currentUserId = AuthService.instance.userId;
    _loadLeaderboard();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadLeaderboard() async {
    setState(() => _isLoading = true);

    try {
      // Global liderlik
      _globalLeaders = await FirestoreService.instance.getLeaderboard(limit: 100);

      // Lig bazlı liderlik
      for (final league in _leagues) {
        _leagueLeaders[league] = await FirestoreService.instance
            .getLeagueLeaderboard(league, limit: 50);
      }

      // Kullanıcı sıralamaları
      if (_currentUserId != null) {
        _userGlobalRank = await FirestoreService.instance.getUserRank(_currentUserId!);
        _userLeagueRanks = await FirestoreService.instance.getUserLeagueRanks(_currentUserId!);
      }
    } catch (e) {
      debugPrint('Leaderboard yükleme hatası: $e');
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1a1a2e), Color(0xFF16213e)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              _buildTabBar(),
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(color: Colors.amber),
                      )
                    : TabBarView(
                        controller: _tabController,
                        children: [
                          _buildGlobalTab(),
                          _buildLeagueTab('A'),
                          _buildLeagueTab('B'),
                          _buildLeagueTab('C'),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 8),
          const Text(
            '🏆',
            style: TextStyle(fontSize: 32),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Liderlik Tablosu',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white70),
            onPressed: _loadLeaderboard,
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: Colors.amber,
          borderRadius: BorderRadius.circular(10),
        ),
        labelColor: Colors.black,
        unselectedLabelColor: Colors.white70,
        labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        tabs: const [
          Tab(text: '🌍 Global'),
          Tab(text: '🅰️ A Ligi'),
          Tab(text: '🅱️ B Ligi'),
          Tab(text: '©️ C Ligi'),
        ],
      ),
    );
  }

  Widget _buildGlobalTab() {
    return Column(
      children: [
        // Kullanıcının kendi sırası
        if (_userGlobalRank != null) _buildUserRankCard(_userGlobalRank!, 'Global'),
        
        // Top 3
        if (_globalLeaders.length >= 3) _buildTopThree(_globalLeaders.take(3).toList()),
        
        // Liste
        Expanded(
          child: _buildLeaderList(_globalLeaders),
        ),
      ],
    );
  }

  Widget _buildLeagueTab(String league) {
    final leaders = _leagueLeaders[league] ?? [];
    final userRank = _userLeagueRanks[league];

    return Column(
      children: [
        // Kullanıcının kendi sırası
        if (userRank != null && userRank > 0) _buildUserRankCard(userRank, '$league Ligi'),
        
        // Top 3
        if (leaders.length >= 3) _buildTopThree(leaders.take(3).toList()),
        
        // Liste
        Expanded(
          child: _buildLeaderList(leaders),
        ),
      ],
    );
  }

  Widget _buildUserRankCard(int rank, String category) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6C27FF), Color(0xFF9D4EDD)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6C27FF).withValues(alpha: 0.4),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.person, color: Colors.white, size: 24),
          const SizedBox(width: 12),
          Text(
            'Senin Sıran ($category):',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '#$rank',
            style: const TextStyle(
              color: Colors.amber,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopThree(List<CloudUserProfile> top3) {
    if (top3.length < 3) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // 2. sıra (sol)
          _buildPodiumPlayer(top3[1], 2, 80),
          // 1. sıra (orta - en yüksek)
          _buildPodiumPlayer(top3[0], 1, 100),
          // 3. sıra (sağ)
          _buildPodiumPlayer(top3[2], 3, 65),
        ],
      ),
    );
  }

  Widget _buildPodiumPlayer(CloudUserProfile player, int rank, double height) {
    final colors = {
      1: const Color(0xFFFFD700), // Altın
      2: const Color(0xFFC0C0C0), // Gümüş
      3: const Color(0xFFCD7F32), // Bronz
    };

    final medals = {1: '🥇', 2: '🥈', 3: '🥉'};
    final isCurrentUser = player.odlevel == _currentUserId;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Madalya
        Text(
          medals[rank] ?? '',
          style: const TextStyle(fontSize: 28),
        ),
        const SizedBox(height: 4),
        
        // Avatar
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: isCurrentUser ? Colors.amber : colors[rank]!,
              width: 3,
            ),
            boxShadow: [
              BoxShadow(
                color: colors[rank]!.withValues(alpha: 0.5),
                blurRadius: 10,
              ),
            ],
          ),
          child: CircleAvatar(
            radius: rank == 1 ? 35 : 28,
            backgroundColor: const Color(0xFF2E5A8C),
            backgroundImage: player.photoURL != null
                ? NetworkImage(player.photoURL!)
                : null,
            child: player.photoURL == null
                ? Text(
                    player.avatarId ?? '👤',
                    style: TextStyle(fontSize: rank == 1 ? 30 : 24),
                  )
                : null,
          ),
        ),
        const SizedBox(height: 8),
        
        // İsim
        SizedBox(
          width: 80,
          child: Text(
            player.username,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: isCurrentUser ? Colors.amber : Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
        
        // Skor
        Text(
          '${player.totalScore}',
          style: TextStyle(
            color: colors[rank],
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        
        // Platform
        Container(
          width: 70,
          height: height,
          margin: const EdgeInsets.only(top: 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                colors[rank]!,
                colors[rank]!.withValues(alpha: 0.6),
              ],
            ),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(8),
              topRight: Radius.circular(8),
            ),
          ),
          child: Center(
            child: Text(
              '$rank',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLeaderList(List<CloudUserProfile> leaders) {
    if (leaders.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('📊', style: TextStyle(fontSize: 48)),
            SizedBox(height: 16),
            Text(
              'Henüz veri yok',
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
          ],
        ),
      );
    }

    // İlk 3'ü atla (podiumda gösterildi)
    final listItems = leaders.length > 3 ? leaders.skip(3).toList() : leaders;

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: listItems.length,
      itemBuilder: (context, index) {
        final player = listItems[index];
        final rank = leaders.length > 3 ? index + 4 : index + 1;
        final isCurrentUser = player.odlevel == _currentUserId;

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: isCurrentUser
                ? Colors.amber.withValues(alpha: 0.2)
                : Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: isCurrentUser
                ? Border.all(color: Colors.amber, width: 2)
                : null,
          ),
          child: ListTile(
            leading: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Sıra numarası
                SizedBox(
                  width: 35,
                  child: Text(
                    '#$rank',
                    style: TextStyle(
                      color: isCurrentUser ? Colors.amber : Colors.white54,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
                // Avatar
                CircleAvatar(
                  radius: 20,
                  backgroundColor: const Color(0xFF2E5A8C),
                  backgroundImage: player.photoURL != null
                      ? NetworkImage(player.photoURL!)
                      : null,
                  child: player.photoURL == null
                      ? Text(
                          player.avatarId ?? '👤',
                          style: const TextStyle(fontSize: 18),
                        )
                      : null,
                ),
              ],
            ),
            title: Text(
              player.username,
              style: TextStyle(
                color: isCurrentUser ? Colors.amber : Colors.white,
                fontWeight: isCurrentUser ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            subtitle: Row(
              children: [
                _buildStatChip('🎮', '${player.gamesPlayed}'),
                const SizedBox(width: 8),
                _buildStatChip('🏆', '${player.duelWins}'),
                const SizedBox(width: 8),
                Text(
                  player.level,
                  style: const TextStyle(
                    color: Colors.amber,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${player.totalScore}',
                style: const TextStyle(
                  color: Colors.amber,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatChip(String emoji, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(emoji, style: const TextStyle(fontSize: 10)),
        const SizedBox(width: 2),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}
