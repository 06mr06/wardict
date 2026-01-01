import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/online_duel_service.dart';
import '../../services/word_pool_service.dart';
import '../../providers/game_provider.dart';
import '../../models/friend.dart';
import '../../models/user_level.dart';
import '../../models/league.dart';
import 'online_duel_screen.dart';
import 'duel_screen.dart';

class MatchmakingScreen extends StatefulWidget {
  final String leagueCode;
  final Friend? invitedFriend;
  final bool isBot;

  const MatchmakingScreen({
    super.key,
    required this.leagueCode,
    this.invitedFriend,
    this.isBot = false,
  });

  @override
  State<MatchmakingScreen> createState() => _MatchmakingScreenState();
}

class _MatchmakingScreenState extends State<MatchmakingScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _rotationController;
  late Animation<double> _pulseAnimation;
  
  bool _isSearching = true;
  bool _matchFound = false;
  String _statusText = 'Rakip aranıyor...';
  OnlineDuelMatch? _match;
  
  StreamSubscription? _matchSubscription;
  Timer? _timeoutTimer;
  Timer? _searchDots;
  int _dotsCount = 0;
  
  // Arama süresi
  int _searchTime = 0;
  Timer? _searchTimer;

  @override
  void initState() {
    super.initState();
    
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    
    _startSearch();
    _startSearchTimer();
    _animateDots();
  }

  void _startSearch() async {
    // Bot modu için hızlı eşleşme
    if (widget.isBot) {
      setState(() {
        _statusText = 'Bot rakip hazırlanıyor...';
      });
      
      // 2 saniye sonra bot ile eşleş
      _timeoutTimer = Timer(const Duration(seconds: 2), () {
        if (mounted) {
          _startBotMatch();
        }
      });
      return;
    }
    
    await OnlineDuelService.instance.initialize();
    
    if (widget.invitedFriend != null) {
      // Arkadaşa davet gönder
      _statusText = '${widget.invitedFriend!.username} davet ediliyor...';
      _match = await OnlineDuelService.instance.inviteFriend(
        widget.invitedFriend!,
        widget.leagueCode,
      );
    } else {
      // Rastgele eşleşme ara
      _match = await OnlineDuelService.instance.findRandomMatch(widget.leagueCode);
    }
    
    _listenToMatch();
    
    // Timeout: 30 saniye sonra demo moduna geç
    _timeoutTimer = Timer(const Duration(seconds: 30), () {
      if (_isSearching && mounted) {
        _startDemoMatch();
      }
    });
  }

  void _listenToMatch() {
    _matchSubscription = OnlineDuelService.instance.matchStream.listen((match) {
      if (match != null && mounted) {
        setState(() {
          _match = match;
        });
        
        if (match.status == OnlineDuelStatus.ready || 
            match.status == OnlineDuelStatus.inProgress) {
          _onMatchFound();
        }
      }
    });
    
    // Eğer maç zaten hazırsa (demo mod gibi)
    if (_match != null && (_match!.isReady || _match!.isInProgress)) {
      _onMatchFound();
    }
  }

  void _onMatchFound() {
    if (!_isSearching || !mounted) return;
    
    setState(() {
      _isSearching = false;
      _matchFound = true;
      _statusText = 'Rakip bulundu!';
    });
    
    _searchTimer?.cancel();
    _timeoutTimer?.cancel();
    _searchDots?.cancel();
    
    // 2 saniye sonra oyuna başla
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted && _match != null) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => OnlineDuelScreen(match: _match!),
          ),
        );
      }
    });
  }

  void _startBotMatch() async {
    if (!mounted) return;
    
    setState(() {
      _isSearching = false;
      _matchFound = true;
      _statusText = 'Bot rakip bulundu!';
    });
    
    _searchTimer?.cancel();
    _searchDots?.cancel();
    
    // Lig'e göre level belirle
    UserLevel level;
    League league;
    switch (widget.leagueCode) {
      case 'A1':
        level = UserLevel.a1;
        league = League.beginner;
        break;
      case 'B1':
        level = UserLevel.b1;
        league = League.intermediate;
        break;
      case 'C1':
        level = UserLevel.c1;
        league = League.advanced;
        break;
      default:
        level = UserLevel.a1;
        league = League.beginner;
    }
    
    // Kelime havuzunu yükle ve soruları oluştur
    await WordPoolService.instance.loadWordPool();
    final questions = WordPoolService.instance.generateQuestions(level);
    
    if (questions.isEmpty) {
      // Hata durumunda geri dön
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sorular yüklenemedi. Lütfen tekrar deneyin.')),
        );
        Navigator.of(context).pop();
      }
      return;
    }
    
    final gameProvider = context.read<GameProvider>();
    gameProvider.startPracticeWithGenerated(questions);
    
    // 2 saniye sonra Bot Duel ekranına git
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => const DuelScreen(),
            settings: RouteSettings(arguments: league),
          ),
        );
      }
    });
  }

  void _startDemoMatch() {
    setState(() {
      _statusText = 'Gerçek rakip bulunamadı. Bot ile eşleşiyorsunuz...';
    });
    
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        _onMatchFound();
      }
    });
  }

  void _startSearchTimer() {
    _searchTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _searchTime++;
        });
      }
    });
  }

  void _animateDots() {
    _searchDots = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (mounted && _isSearching) {
        setState(() {
          _dotsCount = (_dotsCount + 1) % 4;
        });
      }
    });
  }

  void _cancelSearch() {
    OnlineDuelService.instance.cancelMatch();
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _rotationController.dispose();
    _matchSubscription?.cancel();
    _timeoutTimer?.cancel();
    _searchTimer?.cancel();
    _searchDots?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF2E5A8C), Color(0xFF1A3A5C)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Başlık
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: _cancelSearch,
                    ),
                    Expanded(
                      child: Text(
                        widget.isBot ? 'Bot Düello' : 'Online Düello',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
              
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Arama animasyonu
                      _buildSearchAnimation(),
                      
                      const SizedBox(height: 40),
                      
                      // Durum metni
                      Text(
                        _isSearching
                            ? '$_statusText${'.' * _dotsCount}'
                            : _statusText,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Arama süresi
                      if (_isSearching)
                        Text(
                          '${_formatTime(_searchTime)}',
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 16,
                          ),
                        ),
                      
                      const SizedBox(height: 8),
                      
                      // Lig bilgisi
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.amber.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.school, color: Colors.amber, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              'Lig: ${widget.leagueCode}',
                              style: const TextStyle(
                                color: Colors.amber,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      // Rakip bulundu göstergesi
                      if (_matchFound && _match != null) ...[
                        const SizedBox(height: 32),
                        _buildMatchFoundCard(),
                      ],
                    ],
                  ),
                ),
              ),
              
              // İptal butonu
              if (_isSearching)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: OutlinedButton(
                      onPressed: _cancelSearch,
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.white54),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        'Aramayı İptal Et',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchAnimation() {
    if (_matchFound) {
      return TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 500),
        builder: (context, value, child) {
          return Transform.scale(
            scale: 0.5 + (value * 0.5),
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.green.withOpacity(0.3),
                border: Border.all(color: Colors.green, width: 4),
              ),
              child: const Center(
                child: Icon(
                  Icons.check,
                  color: Colors.green,
                  size: 80,
                ),
              ),
            ),
          );
        },
      );
    }
    
    return Stack(
      alignment: Alignment.center,
      children: [
        // Dış halka animasyonu
        AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _pulseAnimation.value,
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.amber.withOpacity(0.3),
                    width: 2,
                  ),
                ),
              ),
            );
          },
        ),
        
        // Dönen halka
        AnimatedBuilder(
          animation: _rotationController,
          builder: (context, child) {
            return Transform.rotate(
              angle: _rotationController.value * 2 * 3.14159,
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.transparent,
                    width: 4,
                  ),
                  gradient: SweepGradient(
                    colors: [
                      Colors.amber.withOpacity(0.0),
                      Colors.amber,
                      Colors.amber.withOpacity(0.0),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
        
        // İç daire
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withOpacity(0.1),
            border: Border.all(color: Colors.white24, width: 2),
          ),
          child: Center(
            child: Icon(
              widget.isBot ? Icons.smart_toy : Icons.person_search,
              color: Colors.white,
              size: 48,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMatchFoundCard() {
    final isBot = widget.isBot;
    final opponentName = isBot ? _getBotName() : (_match?.opponentUsername ?? 'Rakip');
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.green.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: isBot ? Colors.blue : Colors.green,
            child: Icon(isBot ? Icons.smart_toy : Icons.person, color: Colors.white),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                opponentName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Text(
                'Maç başlıyor...',
                style: TextStyle(
                  color: Colors.green,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _getBotName() {
    final names = ['Bot Ahmet', 'Bot Ayşe', 'Bot Mehmet', 'Bot Zeynep', 'Bot Ali'];
    return names[DateTime.now().millisecond % names.length];
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }
}
