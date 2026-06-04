import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/firebase/firestore_service.dart';
import '../../services/firebase/auth_service.dart';
import '../../models/league.dart';
import '../../widgets/common/ad_banner_widget.dart';
import 'package:provider/provider.dart';
import '../../providers/language_provider.dart';
import '../../services/league_service.dart';
import '../../services/friend_service.dart';
import '../../services/online_duel_service.dart';
import '../../models/friend.dart';
import '../game/matchmaking_screen.dart';

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
  List<Map<String, dynamic>> _daily123Leaders = [];
  final Map<String, List<CloudUserProfile>> _leagueLeaders = {};
  int? _userGlobalRank;
  int? _userDailyRank;
  Map<String, int> _userLeagueRanks = {};
  bool _isLoading = true;
  String? _currentUserId;

  bool _isSearching = false;
  final _searchController = TextEditingController();
  List<CloudUserProfile> _searchResults = [];
  bool _isSearchLoading = false;

  final List<String> _leagues = ['Elmas', 'Altın', 'Gümüş'];

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
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadLeaderboard() async {
    setState(() => _isLoading = true);

    try {
      // Global liderlik
      _globalLeaders =
          await FirestoreService.instance.getLeaderboard(limit: 100);

      // Daily 123 liderlik
      _daily123Leaders =
          await FirestoreService.instance.getDaily123Leaderboard(limit: 50);

      // Lig bazlı liderlik
      for (final league in _leagues) {
        final leagueCode = _getLeagueCode(league);
        _leagueLeaders[leagueCode] = await FirestoreService.instance
            .getLeagueLeaderboard(leagueCode, limit: 50);
      }

      // Kullanıcı sıralamaları
      if (_currentUserId != null) {
        _userGlobalRank =
            await FirestoreService.instance.getUserRank(_currentUserId!);

        // Firestore'dan gerçek verileri çek
        final globalData =
            await FirestoreService.instance.getDaily123GlobalRanking(0, 999);
        _userDailyRank = globalData['rank'] is int ? globalData['rank'] : null;

        _userLeagueRanks =
            await FirestoreService.instance.getUserLeagueRanks(_currentUserId!);
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
    final languageProvider = context.watch<LanguageProvider>();
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
              _buildHeader(languageProvider),
              if (_isSearching) _buildSearchField(languageProvider),
              if (!_isSearching) _buildTabBar(languageProvider),
              Expanded(
                child: _isSearching
                    ? _buildSearchResults()
                    : (_isLoading
                        ? const Center(
                            child:
                                CircularProgressIndicator(color: Colors.amber),
                          )
                        : TabBarView(
                            controller: _tabController,
                            children: [
                              _buildGlobalTab(),
                              _buildLeagueTab('Elmas'),
                              _buildLeagueTab('Altın'),
                              _buildLeagueTab('Gümüş'),
                            ],
                          )),
              ),
              // Skor tabloarında kare şeklinde reklam (Medium Rectangle)
              const Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: AdBannerWidget(isMediumRectangle: true),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(LanguageProvider lp) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 16, 20, 16),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.arrow_back_ios_new,
                  color: Colors.white, size: 20),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    lp.getString('leaderboard').toUpperCase(),
                    maxLines: 1,
                    softWrap: false,
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                Text(
                  'Sıfırlamaya: ${LeagueService.instance.formattedTimeUntilReset}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.outfit(
                    color: Colors.amber,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.1),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
              ),
              child: const Icon(Icons.emoji_events_rounded,
                  color: Colors.amber, size: 20),
            ),
            onPressed: () => _showLeaguePrizesInfo(),
            tooltip: 'Haftalık Ödüller',
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                shape: BoxShape.circle,
              ),
              child: Icon(_isSearching ? Icons.close : Icons.search,
                  color: Colors.white, size: 20),
            ),
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) {
                  _searchController.clear();
                  _searchResults.clear();
                }
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar(LanguageProvider lp) {
    return Container(
      height: 44,
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: const LinearGradient(
            colors: [Color(0xFF6C27FF), Color(0xFFB392FF)],
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF6C27FF).withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            )
          ],
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white54,
        labelStyle:
            GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13),
        unselectedLabelStyle:
            GoogleFonts.outfit(fontWeight: FontWeight.w500, fontSize: 13),
        dividerColor: Colors.transparent,
        padding: const EdgeInsets.all(4),
        tabs: [
          Tab(text: lp.getString('global')),
          const Tab(text: '💎 Elmas'),
          const Tab(text: '🥇 Altın'),
          const Tab(text: '🥈 Gümüş'),
        ],
      ),
    );
  }

  Widget _buildGlobalTab() {
    final sorted = List<CloudUserProfile>.from(_globalLeaders)
      ..sort((a, b) => b.totalScore.compareTo(a.totalScore));
    final top3 = sorted.take(3).toList();

    return RefreshIndicator(
      onRefresh: _loadLeaderboard,
      color: Colors.amber,
      backgroundColor: const Color(0xFF1a1a2e),
      child: ListView(
        children: [
          if (_userGlobalRank != null)
            _buildUserRankCard(_userGlobalRank!, 'Global'),
          if (top3.isNotEmpty) _buildTopThree(top3, leagueCode: null),
          _buildLeaderList(sorted, shrinkWrap: true, leagueCode: null),
        ],
      ),
    );
  }

  Widget _buildLeagueTab(String league) {
    final leagueCode = _getLeagueCode(league);
    final leaders = _leagueLeaders[leagueCode] ?? [];
    final sorted = List<CloudUserProfile>.from(leaders)
      ..sort((a, b) =>
          _leaderScore(b, leagueCode).compareTo(_leaderScore(a, leagueCode)));
    final top3 = sorted.take(3).toList();
    final rank = _userLeagueRanks[leagueCode];

    return RefreshIndicator(
      onRefresh: _loadLeaderboard,
      color: Colors.amber,
      backgroundColor: const Color(0xFF1a1a2e),
      child: ListView(
        children: [
          if (rank != null) _buildUserRankCard(rank, league),
          if (top3.isNotEmpty) _buildTopThree(top3, leagueCode: leagueCode),
          _buildLeaderList(sorted, shrinkWrap: true, leagueCode: leagueCode),
        ],
      ),
    );
  }

  Widget _buildUserRankCard(int rank, String category) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1a1a2e), Color(0xFF16213e)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.amber.withValues(alpha: 0.1),
            blurRadius: 15,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.stars, color: Colors.amber, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  category.toUpperCase(),
                  style: GoogleFonts.outfit(
                    color: Colors.white54,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                  ),
                ),
                Text(
                  context.read<LanguageProvider>().getString('your_rank'),
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '#$rank',
            style: GoogleFonts.firaCode(
              color: Colors.amber,
              fontSize: 32,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopThree(List<CloudUserProfile> top3,
      {required String? leagueCode}) {
    if (top3.length < 3) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _buildPodiumPlayer(
              top3[1], _rankAtIndex(1, top3, leagueCode), 50, leagueCode),
          _buildPodiumPlayer(
              top3[0], _rankAtIndex(0, top3, leagueCode), 65, leagueCode),
          _buildPodiumPlayer(
              top3[2], _rankAtIndex(2, top3, leagueCode), 40, leagueCode),
        ],
      ),
    );
  }

  void _showPlayerDetails(CloudUserProfile player) {
    if (player.odlevel == _currentUserId) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1a1a2e),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: const BorderSide(color: Colors.white24, width: 1)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 40,
              backgroundColor: Colors.white.withValues(alpha: 0.1),
              backgroundImage: player.photoURL != null
                  ? NetworkImage(player.photoURL!)
                  : null,
              child: player.photoURL == null
                  ? Text(player.username[0].toUpperCase(),
                      style: const TextStyle(
                          fontSize: 32,
                          color: Colors.white,
                          fontWeight: FontWeight.bold))
                  : null,
            ),
            const SizedBox(height: 16),
            Text(player.username,
                style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold)),
            Text(player.level,
                style: const TextStyle(
                    color: Colors.amber, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildSimpleStat('🏆', '${player.duelWins}'),
                _buildSimpleStat('🔥', '${player.totalScore}'),
                _buildSimpleStat('📊', '${player.gamesPlayed}'),
              ],
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  final fr = Friend(
                    userId: player.odlevel,
                    username: player.username,
                    status: player.isOnline
                        ? OnlineStatus.online
                        : OnlineStatus.offline,
                    friendStatus: FriendStatus.none,
                    lpRating: player.totalScore, // Yaklaşık
                    currentLeague: player.level,
                  );
                  final success =
                      await FriendService.instance.sendFriendRequest(fr);
                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(success
                          ? '${player.username} arkadaş olarak eklendi!'
                          : 'Hata oluştu.'),
                      backgroundColor: success ? Colors.green : Colors.red,
                    ));
                  }
                },
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6C27FF),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12))),
                child: const Text('ARKADAŞ EKLE',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () async {
                  final fr = Friend(
                    userId: player.odlevel,
                    username: player.username,
                  );
                  Navigator.pop(context);
                  final match = await OnlineDuelService.instance
                      .inviteFriend(fr, player.level);
                  if (mounted) {
                    if (match != null) {
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => MatchmakingScreen(
                                    leagueCode: player.level,
                                    existingMatch: match,
                                  )));
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text(
                              'Davet gönderilemedi (Oyuncu çevrimdışı olabilir)')));
                    }
                  }
                },
                style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white24),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12))),
                child: const Text('DÜELLOYA DAVET ET',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSimpleStat(String emoji, String val) {
    return Column(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 20)),
        const SizedBox(height: 4),
        Text(val,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildPodiumPlayer(CloudUserProfile player, int rank,
      double platformHeight, String? leagueCode) {
    final colors = {
      1: const Color(0xFFFFD700),
      2: const Color(0xFFC0C0C0),
      3: const Color(0xFFCD7F32),
    };

    final lp = context.read<LanguageProvider>();
    final rankPts = _leaderScore(player, leagueCode);
    final isCurrentUser = player.odlevel == _currentUserId;

    return GestureDetector(
      onTap: () => _showPlayerDetails(player),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Avatar with Glow
          Stack(
            alignment: Alignment.center,
            children: [
              if (rank == 1)
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: colors[rank]!.withValues(alpha: 0.3),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                ),
              Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: colors[rank]!.withValues(alpha: 0.8),
                    width: rank == 1 ? 3 : 2,
                  ),
                ),
                child: CircleAvatar(
                  radius: rank == 1 ? 34 : 28,
                  backgroundColor: Colors.white.withValues(alpha: 0.1),
                  backgroundImage: player.photoURL != null
                      ? NetworkImage(player.photoURL!)
                      : null,
                  child: player.photoURL == null
                      ? Text(
                          player.username.isNotEmpty
                              ? player.username[0].toUpperCase()
                              : '👤',
                          style: GoogleFonts.outfit(
                            fontSize: rank == 1 ? 28 : 22,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : null,
                ),
              ),
              Positioned(
                bottom: -2,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                  decoration: BoxDecoration(
                    color: colors[rank],
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 4,
                      )
                    ],
                  ),
                  child: Text(
                    '#$rank',
                    style: GoogleFonts.outfit(
                      color: Colors.black,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Name and Score
          SizedBox(
            width: 90,
            child: Column(
              children: [
                Text(
                  player.username,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    color: isCurrentUser ? Colors.amber : Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Text(
                  '$rankPts',
                  style: GoogleFonts.firaCode(
                    color: colors[rank],
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
                Text(
                  lp.getString('leaderboard_rank_score_label'),
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    color: Colors.white54,
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    height: 1.1,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Podium Platform
          Container(
            width: 80,
            height: platformHeight * 1.5,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  colors[rank]!.withValues(alpha: 0.4),
                  colors[rank]!.withValues(alpha: 0.1),
                ],
              ),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(15)),
              border: Border(
                top:
                    BorderSide(color: colors[rank]!.withValues(alpha: 0.5), width: 2),
                left: BorderSide(color: colors[rank]!.withValues(alpha: 0.2)),
                right: BorderSide(color: colors[rank]!.withValues(alpha: 0.2)),
              ),
            ),
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Opacity(
                  opacity: 0.3,
                  child: Text(
                    rank == 1 ? '1ST' : (rank == 2 ? '2ND' : '3RD'),
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeaderList(
    List<CloudUserProfile> leaders, {
    bool shrinkWrap = false,
    String? leagueCode,
    bool omitTopThreeFromList = true,
  }) {
    final lp = context.read<LanguageProvider>();
    if (leaders.isEmpty) {
      if (shrinkWrap) return const SizedBox.shrink();
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('📊', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 16),
            Text(
              lp.getString('no_data_yet'),
              style: GoogleFonts.outfit(color: Colors.white70, fontSize: 16),
            ),
          ],
        ),
      );
    }

    final sorted = List<CloudUserProfile>.from(leaders)
      ..sort((a, b) =>
          _leaderScore(b, leagueCode).compareTo(_leaderScore(a, leagueCode)));

    final listItems = omitTopThreeFromList && sorted.length > 3
        ? sorted.skip(3).toList()
        : sorted;

    return ListView.builder(
      padding: shrinkWrap
          ? EdgeInsets.zero
          : const EdgeInsets.fromLTRB(20, 8, 20, 100),
      shrinkWrap: shrinkWrap,
      physics: shrinkWrap
          ? const NeverScrollableScrollPhysics()
          : const AlwaysScrollableScrollPhysics(),
      itemCount: listItems.length,
      itemBuilder: (context, index) {
        final player = listItems[index];
        final sortedIndex = omitTopThreeFromList && sorted.length > 3
            ? index + 3
            : index;
        final rank = _rankAtIndex(sortedIndex, sorted, leagueCode);
        final isCurrentUser = player.odlevel == _currentUserId;
        final leagueTier = LeagueTier.fromScore(player.totalScore);
        final rankPts = _leaderScore(player, leagueCode);

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: isCurrentUser
                ? const Color(0xFF6C27FF).withValues(alpha: 0.15)
                : Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isCurrentUser
                  ? const Color(0xFF6C27FF).withValues(alpha: 0.4)
                  : Colors.white.withValues(alpha: 0.08),
              width: isCurrentUser ? 1.5 : 1,
            ),
          ),
          child: ListTile(
            onTap: () => _showPlayerDetails(player),
            isThreeLine: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            leading: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 30,
                  child: Text(
                    rank.toString(),
                    style: GoogleFonts.firaCode(
                      color: isCurrentUser ? Colors.white : Colors.white38,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: Colors.white.withValues(alpha: 0.1),
                      backgroundImage: player.photoURL != null
                          ? NetworkImage(player.photoURL!)
                          : null,
                      child: player.photoURL == null
                          ? Text(
                              player.username.isNotEmpty
                                  ? player.username[0].toUpperCase()
                                  : '👤',
                              style: GoogleFonts.outfit(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold),
                            )
                          : null,
                    ),
                    if (player.isOnline)
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.black, width: 2),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
            title: Row(
              children: [
                Text(
                  leagueTier.icon,
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    player.username,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontWeight:
                          isCurrentUser ? FontWeight.w800 : FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  lp.getString('leaderboard_row_secondary_hint'),
                  style: GoogleFonts.outfit(
                    color: Colors.white38,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    _buildStatBadge(
                      '🏆',
                      '${player.duelWins}',
                      lp.getString('leaderboard_badge_wins'),
                    ),
                    const SizedBox(width: 8),
                    _buildStatBadge(
                      '⭐',
                      player.level,
                      lp.getString('leaderboard_badge_course'),
                    ),
                  ],
                ),
              ],
            ),
            trailing: _buildRankPointsHighlight(rankPts, lp),
          ),
        );
      },
    );
  }

  /// Global için [leagueCode] null (totalScore); lig sekmeleri için A/B/C.
  int _leaderScore(CloudUserProfile player, String? leagueCode) {
    if (leagueCode == null) return player.totalScore;
    return player.leagueScores[leagueCode] ?? 0;
  }

  /// [sorted] azalan sıralı liste; eşit puanda aynı sıra (1,1,3 kuralı).
  int _rankAtIndex(int index, List<CloudUserProfile> sorted, String? leagueCode) {
    if (index <= 0) return 1;
    final s = _leaderScore(sorted[index], leagueCode);
    final prev = _leaderScore(sorted[index - 1], leagueCode);
    if (s == prev) return _rankAtIndex(index - 1, sorted, leagueCode);
    return index + 1;
  }

  Widget _buildRankPointsHighlight(int score, LanguageProvider lp) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.amber.withValues(alpha: 0.45),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.amber.withValues(alpha: 0.12),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            lp.getString('leaderboard_rank_score_label'),
            style: GoogleFonts.outfit(
              color: Colors.white60,
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '$score',
            style: GoogleFonts.firaCode(
              color: Colors.amber,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  String _getLeagueCode(String leagueName) {
    switch (leagueName) {
      case 'Elmas':
        return 'A';
      case 'Altın':
        return 'B';
      case 'Gümüş':
        return 'C';
      default:
        return 'A';
    }
  }

  Widget _buildStatBadge(String icon, String value, String caption) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            caption,
            style: GoogleFonts.outfit(
              color: Colors.white38,
              fontSize: 8,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 2),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(icon, style: const TextStyle(fontSize: 10)),
              const SizedBox(width: 4),
              Text(
                value,
                style: GoogleFonts.outfit(
                  color: Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField(LanguageProvider languageProvider) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: TextField(
        controller: _searchController,
        autofocus: true,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: languageProvider.getString('search_username'),
          hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
          border: InputBorder.none,
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, color: Colors.white70),
                  onPressed: () {
                    setState(() {
                      _searchController.clear();
                      _searchResults.clear();
                    });
                  },
                )
              : null,
        ),
        onChanged: (value) async {
          if (value.length >= 3) {
            setState(() => _isSearchLoading = true);
            final results = await FirestoreService.instance.searchUsers(value);
            if (mounted) {
              setState(() {
                _searchResults = results;
                _isSearchLoading = false;
              });
            }
          } else {
            setState(() => _searchResults = []);
          }
        },
      ),
    );
  }

  Widget _buildSearchResults() {
    final lp = context.read<LanguageProvider>();
    if (_isSearchLoading) {
      return const Center(
          child: CircularProgressIndicator(color: Colors.amber));
    }

    if (_searchController.text.length < 3) {
      return Center(
        child: Text(
          lp.getString('search_min_chars'),
          style: const TextStyle(color: Colors.white70),
        ),
      );
    }

    if (_searchResults.isEmpty) {
      return Center(
        child: Text(
          lp.getString('user_not_found'),
          style: const TextStyle(color: Colors.white70),
        ),
      );
    }

    final sorted = List<CloudUserProfile>.from(_searchResults)
      ..sort((a, b) => b.totalScore.compareTo(a.totalScore));
    return _buildLeaderList(
      sorted,
      leagueCode: null,
      omitTopThreeFromList: false,
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

  Widget _buildDaily123Tab() {
    return RefreshIndicator(
      onRefresh: _loadLeaderboard,
      color: Colors.amber,
      backgroundColor: const Color(0xFF1a1a2e),
      child: ListView(
        children: [
          if (_userDailyRank != null)
            _buildUserRankCard(_userDailyRank!, 'DAILY 123'),
          _buildDaily123List(_daily123Leaders),
        ],
      ),
    );
  }

  Widget _buildDaily123List(List<Map<String, dynamic>> leaders) {
    if (leaders.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40.0),
          child: Text(
            context.read<LanguageProvider>().getString('no_data_yet'),
            style: const TextStyle(color: Colors.white54),
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      itemCount: leaders.length,
      itemBuilder: (context, index) {
        final player = leaders[index];
        final isCurrentUser = player['userId'] == _currentUserId;
        final rank = index + 1;
        final score = player['score'];
        final seconds = player['seconds'];

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isCurrentUser
                ? const Color(0xFF6C27FF).withValues(alpha: 0.1)
                : Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isCurrentUser
                  ? const Color(0xFF6C27FF).withValues(alpha: 0.3)
                  : Colors.white.withValues(alpha: 0.05),
            ),
          ),
          child: Row(
            children: [
              _buildRankBadge(rank),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      player['username'] ?? 'Anonim',
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      '$seconds sn',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5), fontSize: 12),
                    ),
                  ],
                ),
              ),
              Text(
                '$score',
                style: GoogleFonts.outfit(
                  color: const Color(0xFF00F5A0),
                  fontWeight: FontWeight.w900,
                  fontSize: 20,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRankBadge(int rank) {
    Color bgColor;
    Color textColor = Colors.white;

    if (rank == 1) {
      bgColor = Colors.amber;
      textColor = Colors.black;
    } else if (rank == 2) {
      bgColor = const Color(0xFFC0C0C0);
      textColor = Colors.black;
    } else if (rank == 3) {
      bgColor = const Color(0xFFCD7F32);
      textColor = Colors.black;
    } else {
      bgColor = Colors.white.withValues(alpha: 0.1);
    }

    return Container(
      width: 32,
      height: 32,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bgColor,
        shape: BoxShape.circle,
      ),
      child: Text(
        '$rank',
        style: TextStyle(
            color: textColor, fontWeight: FontWeight.bold, fontSize: 14),
      ),
    );
  }

  void _showLeaguePrizesInfo() {
    final rules = LeagueService.instance.leagueRules;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1a1a2e),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: const BorderSide(color: Colors.amber, width: 1)),
        title: Row(
          children: [
            const Icon(Icons.emoji_events_rounded,
                color: Colors.amber, size: 28),
            const SizedBox(width: 12),
            Text(
              'LİG ÖDÜLLERİ',
              style: GoogleFonts.outfit(
                  color: Colors.white, fontWeight: FontWeight.w900),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Her Pazar 23:59\'da ligler sıfırlanır, derecene göre ödül kazanırsın!',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 20),
              ...rules.map((r) => Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              r['league'] as String,
                              style: const TextStyle(fontSize: 22),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                r['tierName'] as String? ?? '',
                                style: const TextStyle(
                                  color: Colors.amber,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                r['promotion'] as String,
                                style: const TextStyle(
                                    color: Colors.greenAccent,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold),
                              ),
                              Text(
                                'Ödül: ${r['reward']}',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  )),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('TAMAM',
                style: TextStyle(
                    color: Colors.amber, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
