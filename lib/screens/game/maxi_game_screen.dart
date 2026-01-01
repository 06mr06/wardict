import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/shop_service.dart';
import '../../services/user_profile_service.dart';
import '../../models/cosmetic_item.dart';
import '../../services/online_duel_service.dart';
import '../../widgets/game/question_card.dart';
import '../../widgets/game/options_grid.dart';
import '../../widgets/game/game_timer.dart';
import '../../widgets/game/game_background.dart';
import '../../widgets/game/game_confetti.dart';

enum MaxiGameMode {
  quickMatch,
  createRoom,
  joinRoom,
}

class MaxiGameScreen extends StatefulWidget {
  final MaxiGameMode mode;
  final String? roomCode;

  const MaxiGameScreen({
    super.key,
    required this.mode,
    this.roomCode,
  });

  @override
  State<MaxiGameScreen> createState() => _MaxiGameScreenState();
}

class _MaxiGameScreenState extends State<MaxiGameScreen> with TickerProviderStateMixin {
  // Game state
  bool _isLoading = true;
  bool _isMatchmaking = true;
  bool _isGameStarted = false;
  bool _isGameEnded = false;
  
  // Room info
  String _roomCode = '';
  int _playerCount = 0;
  int _maxPlayers = 4;
  
  // Players
  final List<_Player> _players = [];
  String _myPlayerId = '';
  
  // Questions
  List<Map<String, dynamic>> _questions = [];
  int _currentQuestionIndex = 0;
  int _selectedOption = -1;
  bool _answered = false;
  int _timeRemaining = 15;
  Timer? _questionTimer;
  
  // My stats
  int _myScore = 0;
  int _myStreak = 0;
  
  // Animations
  late AnimationController _countdownController;
  late Animation<double> _countdownAnimation;
  int _countdownValue = 3;
  bool _showCountdown = false;
  
  final _random = Random();

  @override
  void initState() {
    super.initState();
    _countdownController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _countdownAnimation = Tween<double>(begin: 0.5, end: 1.5).animate(
      CurvedAnimation(parent: _countdownController, curve: Curves.elasticOut),
    );
    
    _initGame();
  }

  @override
  void dispose() {
    _questionTimer?.cancel();
    _countdownController.dispose();
    super.dispose();
  }

  Future<void> _initGame() async {
    // Generate room code if creating
    if (widget.mode == MaxiGameMode.createRoom) {
      _roomCode = _generateRoomCode();
    } else if (widget.mode == MaxiGameMode.joinRoom && widget.roomCode != null) {
      _roomCode = widget.roomCode!;
    }
    
    // Load my info
    final profile = await UserProfileService.instance.loadProfile();
    final avatarId = await ShopService.instance.getSelectedCosmetic(CosmeticType.avatar);
    String myAvatar = '👤';
    if (avatarId != null) {
      final items = CosmeticItem.availableItems.where((i) => i.id == avatarId);
      if (items.isNotEmpty) myAvatar = items.first.previewValue;
    }
    
    _myPlayerId = 'player_${_random.nextInt(10000)}';
    
    setState(() {
      _isLoading = false;
      _players.add(_Player(
        id: _myPlayerId,
        name: profile.username,
        avatar: myAvatar,
        score: 0,
        isMe: true,
      ));
      _playerCount = 1;
    });
    
    if (widget.mode == MaxiGameMode.quickMatch) {
      _startQuickMatchmaking();
    }
  }

  String _generateRoomCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    return List.generate(6, (_) => chars[_random.nextInt(chars.length)]).join();
  }

  void _startQuickMatchmaking() async {
    // Simulate finding players
    final playerNames = ['Ahmet', 'Mehmet', 'Ayşe', 'Fatma', 'Ali', 'Zeynep', 'Mustafa', 'Elif'];
    final avatars = ['🦊', '🐼', '🦁', '🐱', '🐶', '🦄', '🐲', '🦉'];
    
    // Add 2-3 more players with delays
    final playersToAdd = 2 + _random.nextInt(2); // 3 or 4 total
    
    for (int i = 0; i < playersToAdd; i++) {
      await Future.delayed(Duration(milliseconds: 800 + _random.nextInt(1500)));
      if (!mounted) return;
      
      final name = playerNames[_random.nextInt(playerNames.length)];
      final avatar = avatars[_random.nextInt(avatars.length)];
      
      setState(() {
        _players.add(_Player(
          id: 'bot_$i',
          name: name,
          avatar: avatar,
          score: 0,
          isMe: false,
        ));
        _playerCount = _players.length;
      });
    }
    
    // Start game after finding players
    await Future.delayed(const Duration(seconds: 1));
    if (mounted) {
      _startCountdown();
    }
  }

  void _startCountdown() async {
    setState(() {
      _isMatchmaking = false;
      _showCountdown = true;
      _countdownValue = 3;
    });
    
    // Load questions
    _questions = OnlineDuelService.instance.getDemoQuestions();
    _questions.shuffle();
    _questions = _questions.take(10).toList();
    
    for (int i = 3; i >= 1; i--) {
      if (!mounted) return;
      setState(() => _countdownValue = i);
      _countdownController.forward(from: 0);
      await Future.delayed(const Duration(seconds: 1));
    }
    
    if (mounted) {
      setState(() {
        _showCountdown = false;
        _isGameStarted = true;
      });
      _startQuestion();
    }
  }

  void _startQuestion() {
    if (_currentQuestionIndex >= _questions.length) {
      _endGame();
      return;
    }
    
    setState(() {
      _selectedOption = -1;
      _answered = false;
      _timeRemaining = 15;
    });
    
    _questionTimer?.cancel();
    _questionTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      
      setState(() => _timeRemaining--);
      
      if (_timeRemaining <= 0) {
        timer.cancel();
        if (!_answered) {
          _handleTimeout();
        }
      }
    });
    
    // Schedule bot answers
    _scheduleBotAnswers();
  }

  void _scheduleBotAnswers() {
    for (final player in _players.where((p) => !p.isMe)) {
      final delay = Duration(milliseconds: 2000 + _random.nextInt(8000));
      Future.delayed(delay, () {
        if (!mounted || _answered || _currentQuestionIndex >= _questions.length) return;
        
        final isCorrect = _random.nextDouble() < 0.65; // 65% correct rate for bots
        final correctIndex = _questions[_currentQuestionIndex]['correctIndex'] as int;
        
        if (isCorrect) {
          final timeBonus = _timeRemaining;
          final baseScore = 10;
          player.score += baseScore + timeBonus;
          player.streak++;
          if (player.streak > 1) {
            player.score += (player.streak - 1) * 2;
          }
        } else {
          player.streak = 0;
        }
        
        if (mounted) setState(() {});
      });
    }
  }

  void _handleAnswer(int optionIndex) {
    if (_answered) return;
    
    final correctIndex = _questions[_currentQuestionIndex]['correctIndex'] as int;
    final isCorrect = optionIndex == correctIndex;
    
    setState(() {
      _selectedOption = optionIndex;
      _answered = true;
    });
    
    if (isCorrect) {
      final timeBonus = _timeRemaining;
      final baseScore = 10;
      _myScore += baseScore + timeBonus;
      _myStreak++;
      if (_myStreak > 1) {
        _myScore += (_myStreak - 1) * 2;
      }
      
      // Update my player score
      final myPlayer = _players.firstWhere((p) => p.isMe);
      myPlayer.score = _myScore;
      myPlayer.streak = _myStreak;
    } else {
      _myStreak = 0;
      final myPlayer = _players.firstWhere((p) => p.isMe);
      myPlayer.streak = 0;
    }
    
    _questionTimer?.cancel();
    
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        _nextQuestion();
      }
    });
  }

  void _handleTimeout() {
    setState(() {
      _answered = true;
      _myStreak = 0;
      final myPlayer = _players.firstWhere((p) => p.isMe);
      myPlayer.streak = 0;
    });
    
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        _nextQuestion();
      }
    });
  }

  void _nextQuestion() {
    setState(() {
      _currentQuestionIndex++;
    });
    
    if (_currentQuestionIndex < _questions.length) {
      _startQuestion();
    } else {
      _endGame();
    }
  }

  void _endGame() {
    _questionTimer?.cancel();
    
    // Sort players by score
    _players.sort((a, b) => b.score.compareTo(a.score));
    
    setState(() {
      _isGameEnded = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return _buildLoadingScreen();
    }
    
    if (_isMatchmaking) {
      return _buildMatchmakingScreen();
    }
    
    if (_showCountdown) {
      return _buildCountdownScreen();
    }
    
    if (_isGameEnded) {
      return _buildResultsScreen();
    }
    
    return _buildGameScreen();
  }

  Widget _buildLoadingScreen() {
    return Scaffold(
      body: GameBackground(
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('👑', style: TextStyle(fontSize: 60)),
              SizedBox(height: 20),
              Text(
                'MaxiGame',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 20),
              CircularProgressIndicator(color: Color(0xFFFFD700)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMatchmakingScreen() {
    return Scaffold(
      body: GameBackground(
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, color: Colors.white),
                    ),
                    const Spacer(),
                    const Text('👑', style: TextStyle(fontSize: 28)),
                    const SizedBox(width: 8),
                    const Text(
                      'MaxiGame',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
              
              const Spacer(),
              
              // Room code (for create/join modes)
              if (widget.mode != MaxiGameMode.quickMatch) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'Oda Kodu',
                        style: TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _roomCode,
                            style: const TextStyle(
                              color: Color(0xFFFFD700),
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 8,
                            ),
                          ),
                          const SizedBox(width: 12),
                          IconButton(
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: _roomCode));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Oda kodu kopyalandı!'),
                                  duration: Duration(seconds: 1),
                                ),
                              );
                            },
                            icon: const Icon(Icons.copy, color: Colors.white70),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
              ],
              
              // Status
              Text(
                widget.mode == MaxiGameMode.quickMatch
                    ? 'Oyuncular aranıyor...'
                    : 'Oyuncular bekleniyor...',
                style: const TextStyle(color: Colors.white70, fontSize: 16),
              ),
              const SizedBox(height: 24),
              
              // Player count
              Text(
                '$_playerCount / $_maxPlayers',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 32),
              
              // Players list
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 32),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    for (int i = 0; i < _maxPlayers; i++)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: i < _players.length
                                    ? Colors.green.withOpacity(0.2)
                                    : Colors.white.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: i < _players.length
                                    ? Text(_players[i].avatar, style: const TextStyle(fontSize: 24))
                                    : const Icon(Icons.hourglass_empty, color: Colors.white30, size: 20),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              i < _players.length
                                  ? _players[i].name + (_players[i].isMe ? ' (Sen)' : '')
                                  : 'Bekleniyor...',
                              style: TextStyle(
                                color: i < _players.length ? Colors.white : Colors.white38,
                                fontSize: 16,
                                fontWeight: i < _players.length && _players[i].isMe
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                            const Spacer(),
                            if (i < _players.length && _players[i].isMe)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFD700),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  'SEN',
                                  style: TextStyle(
                                    color: Colors.black87,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              
              const Spacer(),
              
              // Start button (for room creator)
              if (widget.mode == MaxiGameMode.createRoom && _playerCount >= 3)
                Padding(
                  padding: const EdgeInsets.all(32),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _startCountdown,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4CAF50),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        'Oyunu Başlat',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                )
              else
                const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCountdownScreen() {
    return Scaffold(
      body: GameBackground(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Hazır Ol!',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 20,
                ),
              ),
              const SizedBox(height: 20),
              ScaleTransition(
                scale: _countdownAnimation,
                child: Text(
                  '$_countdownValue',
                  style: const TextStyle(
                    color: Color(0xFFFFD700),
                    fontSize: 120,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGameScreen() {
    if (_currentQuestionIndex >= _questions.length) {
      return const SizedBox();
    }
    
    final question = _questions[_currentQuestionIndex];
    final options = question['options'] as List<String>;
    final correctIndex = question['correctIndex'] as int;
    
    return Scaffold(
      body: GameBackground(
        child: SafeArea(
          child: Column(
            children: [
              // Header with timer and scores
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // Timer and question count
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Soru ${_currentQuestionIndex + 1}/${_questions.length}',
                          style: const TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: _timeRemaining <= 5
                                ? Colors.red.withOpacity(0.3)
                                : Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.timer,
                                color: _timeRemaining <= 5 ? Colors.red : Colors.white70,
                                size: 18,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '$_timeRemaining',
                                style: TextStyle(
                                  color: _timeRemaining <= 5 ? Colors.red : Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    // Scoreboard
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: _players.map((player) {
                          return Column(
                            children: [
                              Text(player.avatar, style: const TextStyle(fontSize: 24)),
                              const SizedBox(height: 4),
                              Text(
                                '${player.score}',
                                style: TextStyle(
                                  color: player.isMe ? const Color(0xFFFFD700) : Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
              
              // Question
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Question text
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          children: [
                            Text(
                              question['english'] as String,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Türkçe karşılığını seç',
                              style: TextStyle(color: Colors.white54, fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                      
                      // Options
                      ...List.generate(options.length, (index) {
                        Color bgColor = Colors.white.withOpacity(0.1);
                        Color borderColor = Colors.transparent;
                        
                        if (_answered) {
                          if (index == correctIndex) {
                            bgColor = Colors.green.withOpacity(0.3);
                            borderColor = Colors.green;
                          } else if (index == _selectedOption) {
                            bgColor = Colors.red.withOpacity(0.3);
                            borderColor = Colors.red;
                          }
                        } else if (index == _selectedOption) {
                          bgColor = const Color(0xFF6C27FF).withOpacity(0.3);
                          borderColor = const Color(0xFF6C27FF);
                        }
                        
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Material(
                            color: bgColor,
                            borderRadius: BorderRadius.circular(16),
                            child: InkWell(
                              onTap: _answered ? null : () => _handleAnswer(index),
                              borderRadius: BorderRadius.circular(16),
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: borderColor, width: 2),
                                ),
                                child: Text(
                                  options[index],
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResultsScreen() {
    final myRank = _players.indexWhere((p) => p.isMe) + 1;
    final isWinner = myRank == 1;
    
    return Scaffold(
      body: GameBackground(
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 40),
              
              // Winner celebration
              Text(
                isWinner ? '🏆' : myRank == 2 ? '🥈' : myRank == 3 ? '🥉' : '💪',
                style: const TextStyle(fontSize: 80),
              ),
              const SizedBox(height: 16),
              Text(
                isWinner ? 'Şampiyon!' : '$myRank. Sırada Bitirdin!',
                style: TextStyle(
                  color: isWinner ? const Color(0xFFFFD700) : Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Skorun: $_myScore',
                style: const TextStyle(color: Colors.white70, fontSize: 18),
              ),
              
              const SizedBox(height: 40),
              
              // Leaderboard
              Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Sıralama',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: ListView.builder(
                          itemCount: _players.length,
                          itemBuilder: (context, index) {
                            final player = _players[index];
                            final rank = index + 1;
                            
                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: player.isMe
                                    ? const Color(0xFFFFD700).withOpacity(0.2)
                                    : Colors.white.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(16),
                                border: player.isMe
                                    ? Border.all(color: const Color(0xFFFFD700), width: 2)
                                    : null,
                              ),
                              child: Row(
                                children: [
                                  // Rank
                                  Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: rank == 1
                                          ? const Color(0xFFFFD700)
                                          : rank == 2
                                              ? Colors.grey.shade300
                                              : rank == 3
                                                  ? const Color(0xFFCD7F32)
                                                  : Colors.white.withOpacity(0.2),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Center(
                                      child: Text(
                                        '$rank',
                                        style: TextStyle(
                                          color: rank <= 3 ? Colors.black87 : Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  
                                  // Avatar
                                  Text(player.avatar, style: const TextStyle(fontSize: 28)),
                                  const SizedBox(width: 12),
                                  
                                  // Name
                                  Expanded(
                                    child: Text(
                                      player.name + (player.isMe ? ' (Sen)' : ''),
                                      style: TextStyle(
                                        color: player.isMe ? const Color(0xFFFFD700) : Colors.white,
                                        fontSize: 16,
                                        fontWeight: player.isMe ? FontWeight.bold : FontWeight.normal,
                                      ),
                                    ),
                                  ),
                                  
                                  // Score
                                  Text(
                                    '${player.score}',
                                    style: TextStyle(
                                      color: player.isMe ? const Color(0xFFFFD700) : Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              // Actions
              Padding(
                padding: const EdgeInsets.all(24),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          side: const BorderSide(color: Colors.white54),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text(
                          'Ana Sayfa',
                          style: TextStyle(color: Colors.white, fontSize: 16),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => MaxiGameScreen(mode: widget.mode),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4CAF50),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text(
                          'Tekrar Oyna',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
    );
  }
}

class _Player {
  final String id;
  final String name;
  final String avatar;
  int score;
  int streak;
  final bool isMe;

  _Player({
    required this.id,
    required this.name,
    required this.avatar,
    required this.score,
    this.streak = 0,
    required this.isMe,
  });
}
