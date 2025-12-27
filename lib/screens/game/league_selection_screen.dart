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
  League? _selectedLeague;
  LeagueScores? _leagueScores;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

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

  void _startDuel() {
    if (_selectedLeague == null) return;

    // Seçilen lige göre seviyeler belirle
    UserLevel level;
    switch (_selectedLeague!) {
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
      arguments: _selectedLeague,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1a1a2e), Color(0xFF16213e)],
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
                        'Lig Seç',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'Yarışmak istediğin ligi seç',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 30),

                // League Cards
                Expanded(
                  child: ListView(
                    children: [
                      _buildLeagueCard(
                        League.beginner,
                        Colors.green,
                        Icons.eco,
                        'Temel kelimeler ve günlük konuşma',
                      ),
                      const SizedBox(height: 16),
                      _buildLeagueCard(
                        League.intermediate,
                        Colors.orange,
                        Icons.trending_up,
                        'Orta ve ileri düzey kelimeler',
                      ),
                      const SizedBox(height: 16),
                      _buildLeagueCard(
                        League.advanced,
                        Colors.red,
                        Icons.whatshot,
                        'Akademik ve uzman düzey kelimeler',
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Start Button
                if (_selectedLeague != null)
                  ScaleTransition(
                    scale: _pulseAnimation,
                    child: Column(
                      children: [
                        // Offline Duel Button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _startDuel,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2AA7FF),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 8,
                              shadowColor: const Color(0xFF2AA7FF).withValues(alpha: 0.5),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.sports_mma, color: Colors.white, size: 24),
                                const SizedBox(width: 10),
                                Text(
                                  '${_selectedLeague!.name} Liginde Düello!',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Online Match Button
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => FindMatchScreen(
                                    leagueCode: _selectedLeague!.code,
                                    leagueName: _selectedLeague!.name,
                                  ),
                                ),
                              );
                            },
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFF4CAF50), width: 2),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.public, color: Color(0xFF4CAF50), size: 24),
                                SizedBox(width: 10),
                                Text(
                                  'Online Rakip Bul',
                                  style: TextStyle(
                                    color: Color(0xFF4CAF50),
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
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

  Widget _buildLeagueCard(League league, Color color, IconData icon, String description) {
    final isSelected = _selectedLeague == league;
    final score = _leagueScores?.getScore(league) ?? 1500;

    return GestureDetector(
      onTap: () => setState(() => _selectedLeague = league),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isSelected
                ? [color.withValues(alpha: 0.4), color.withValues(alpha: 0.2)]
                : [Colors.white.withValues(alpha: 0.1), Colors.white.withValues(alpha: 0.05)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? color : Colors.white.withValues(alpha: 0.2),
            width: isSelected ? 3 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.3),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Üst satır: icon, isim, seviye aralığı
            Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.2),
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
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.3),
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
                // Skor ve seçim işareti
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: color.withValues(alpha: 0.5)),
                      ),
                      child: Text(
                        '${league.code}$score',
                        style: TextStyle(
                          color: color,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (isSelected)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Icon(
                          Icons.check_circle,
                          color: color,
                          size: 20,
                        ),
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Alt satır: açıklama
            Text(
              description,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
