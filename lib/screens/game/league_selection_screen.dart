import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/league.dart';
import '../../models/user_level.dart';
import '../../providers/game_provider.dart';
import '../../services/user_profile_service.dart';
import '../../services/word_pool_service.dart';
import '../friends/find_match_screen.dart';

class LeagueSelectionScreen extends StatefulWidget {
  const LeagueSelectionScreen({super.key});

  @override
  State<LeagueSelectionScreen> createState() => _LeagueSelectionScreenState();
}

class _LeagueSelectionScreenState extends State<LeagueSelectionScreen> 
    with SingleTickerProviderStateMixin {
  LeagueScores? _leagueScores;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  
  // Devam eden oyunlar listesi (simüle)
  final List<Map<String, dynamic>> _ongoingGames = [];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _loadScores();
  }

  Future<void> _loadScores() async {
    final profile = await UserProfileService.instance.loadProfile();
    setState(() {
      _leagueScores = profile.leagueScores;
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _startDuelWithBot(League league) {
    // Seçilen lige göre seviyeler belirle
    UserLevel level;
    switch (league) {
      case League.beginner:
        level = UserLevel.a1;
        break;
      case League.intermediate:
        level = UserLevel.b1;
        break;
      case League.advanced:
        level = UserLevel.c1;
        break;
    }

    // Soruları oluştur
    final questions = WordPoolService.instance.generateQuestions(level);
    final gameProvider = context.read<GameProvider>();
    gameProvider.startPracticeWithGenerated(questions);
    
    // Duel ekranına git (lig bilgisiyle)
    Navigator.pushReplacementNamed(
      context, 
      '/duel',
      arguments: league,
    );
  }

  void _findOnlineMatch(League league) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FindMatchScreen(
          leagueCode: league.code,
          leagueName: league.name,
        ),
      ),
    );
  }

  void _showOngoingGames() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF2E5A8C),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Devam Eden Oyunlar',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            if (_ongoingGames.isEmpty)
              Container(
                padding: const EdgeInsets.all(30),
                child: Column(
                  children: [
                    Icon(Icons.games_outlined, size: 60, color: Colors.white.withOpacity(0.3)),
                    const SizedBox(height: 12),
                    Text(
                      'Devam eden oyun yok',
                      style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 16),
                    ),
                  ],
                ),
              )
            else
              ...List.generate(_ongoingGames.length, (i) {
                final game = _ongoingGames[i];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.blue,
                    child: Text(game['opponent'][0]),
                  ),
                  title: Text(game['opponent'], style: const TextStyle(color: Colors.white)),
                  subtitle: Text(game['league'], style: TextStyle(color: Colors.white.withOpacity(0.6))),
                  trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white54, size: 16),
                  onTap: () {
                    Navigator.pop(context);
                    // Oyuna devam et
                  },
                );
              }),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF2E5A8C), Color(0xFF1A3A5C)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // Header
                Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                    ),
                    const Expanded(
                      child: Text(
                        'Düello Modu',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    // Devam eden oyunlar butonu
                    Stack(
                      children: [
                        IconButton(
                          onPressed: _showOngoingGames,
                          icon: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.white.withOpacity(0.2)),
                            ),
                            child: const Icon(Icons.inbox, color: Colors.white, size: 20),
                          ),
                        ),
                        if (_ongoingGames.isNotEmpty)
                          Positioned(
                            right: 8,
                            top: 8,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                '${_ongoingGames.length}',
                                style: const TextStyle(color: Colors.white, fontSize: 10),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'Seviye seç ve rakibini bul!',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 24),

                // League Cards
                Expanded(
                  child: ListView(
                    children: [
                      _buildLeagueCard(
                        League.beginner,
                        Colors.green,
                        Icons.eco,
                        'Temel kelimeler ve günlük konuşma',
                        '🤖',
                      ),
                      const SizedBox(height: 16),
                      _buildLeagueCard(
                        League.intermediate,
                        Colors.orange,
                        Icons.trending_up,
                        'Orta ve ileri düzey kelimeler',
                        '🤖',
                      ),
                      const SizedBox(height: 16),
                      _buildLeagueCard(
                        League.advanced,
                        Colors.red,
                        Icons.whatshot,
                        'Akademik ve uzman düzey kelimeler',
                        '🤖',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLeagueCard(League league, Color color, IconData icon, String description, String botEmoji) {
    final score = _leagueScores?.getScore(league) ?? 1500;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.25), color.withOpacity(0.1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.5), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Üst satır: icon, isim, skor
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      league.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        league.levelRange,
                        style: TextStyle(
                          color: color,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Skor
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: color.withOpacity(0.5)),
                ),
                child: Column(
                  children: [
                    Text(
                      '$score',
                      style: TextStyle(
                        color: color,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'ELO',
                      style: TextStyle(
                        color: color.withOpacity(0.7),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 12),
          // Butonlar satırı
          Row(
            children: [
              // Online Rakip Bul butonu
              Expanded(
                flex: 2,
                child: ScaleTransition(
                  scale: _pulseAnimation,
                  child: ElevatedButton(
                    onPressed: () => _findOnlineMatch(league),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: color,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 4,
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.person_search, color: Colors.white, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Rakip Bul',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Bot ile oyna butonu
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _startDuelWithBot(league),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: color, width: 2),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(botEmoji, style: const TextStyle(fontSize: 18)),
                      const SizedBox(width: 4),
                      Text(
                        'Bot',
                        style: TextStyle(
                          color: color,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
