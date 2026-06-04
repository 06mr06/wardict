import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lugorena/services/online_duel_service.dart';
import '../../services/user_profile_service.dart';
import '../../services/word_pool_service.dart';
import '../../services/friend_service.dart';
import '../../providers/game_provider.dart';
import '../../models/friend.dart';
import '../../models/user_level.dart';
import '../../models/league.dart';
import 'package:lugorena/models/online_duel.dart';
import '../game/online_duel_screen.dart';
import '../../providers/language_provider.dart';
import 'duel_screen.dart';
import '../../models/quest.dart';
import '../../services/quest_service.dart';

class MatchmakingScreen extends StatefulWidget {
  final String leagueCode;
  final Friend? invitedFriend;
  final bool isBot;
  final OnlineDuelMatch? existingMatch;
  /// Bu düello bir rövanş maçıysa true. Reklam ritmi için online_duel_screen'e
  /// aktarılır.
  final bool isRematch;

  const MatchmakingScreen({
    super.key,
    required this.leagueCode,
    this.invitedFriend,
    this.isBot = false,
    this.existingMatch,
    this.isRematch = false,
  });

  @override
  State<MatchmakingScreen> createState() => _MatchmakingScreenState();
}

class _MatchmakingScreenState extends State<MatchmakingScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _rotationController;
  
  bool _isSearching = true;
  bool _matchFound = false;
  OnlineDuelMatch? _match;
  
  StreamSubscription? _matchSubscription;
  Timer? _retryTimer;

  // Bot identity (fixed for this search session)
  String? _botName;
  String? _botAvatar;

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
    
    // Her güne özel sabit bir indeks seçmek için .day kullanıldı
    _currentFact = _funFacts[DateTime.now().day % _funFacts.length];
    
    _startSearch();
    _startSearchTimer();
    _animateDots();
    
    // Rastgele eşleşme için her 10 saniyede bir odayı tazele (çakışmaları önlemek için)
    if (!widget.isBot && widget.invitedFriend == null && widget.existingMatch == null) {
      _retryTimer = Timer.periodic(const Duration(seconds: 10), (_) => _retryMatchmaking());
    }
  }

  final List<Map<String, String>> _funFacts = [
    {
      'word': 'Pioneer',
      'meaning': 'Öncü, yol açan kişi',
      'example': 'She was a pioneer in the field of medicine.'
    },
    {
      'word': 'Relentless',
      'meaning': 'Aralıksız, amansız',
      'example': 'The relentless sun beat down on them.'
    },
    {
      'word': 'Sustainable',
      'meaning': 'Sürdürülebilir',
      'example': 'We need a sustainable solution.'
    },
    {
      'word': 'Incentive',
      'meaning': 'Teşvik, özendirme',
      'example': 'The bonus is an incentive to work harder.'
    },
    {
      'word': 'Coherent',
      'meaning': 'Tutarlı, uyumlu',
      'example': 'He made a coherent argument.'
    },
  ];
  late Map<String, String> _currentFact;

  Timer? _timeoutTimer;
  Timer? _searchDots;
  int _dotsCount = 0;
  
  // Arama süresi
  int _searchTime = 0;
  Timer? _searchTimer;

  // Helper getters for opponent info
  String? get _currentUserId => OnlineDuelService.instance.currentUserId;
  bool get _isHost => _match?.hostUserId == _currentUserId;
  String? get _opponentUsername => 
      (_isHost ? _match?.guestUsername : _match?.hostUsername) ?? widget.invitedFriend?.username;

  void _startSearch() async {
    if (widget.existingMatch != null) {
      _match = widget.existingMatch;
      _listenToMatch();
      return;
    }

    // Bot modu için hızlı eşleşme
    if (widget.isBot) {
      _initBotIdentity();
      setState(() {
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
      if (widget.invitedFriend!.userId == _currentUserId) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Kendi kendinize düello yapamazsınız. Başka bir hesapla deneyin.')),
          );
          Navigator.of(context).pop();
        }
        return;
      }
      
      // Arkadaş listesine ekle (eğer yoksa)
      await FriendService.instance.sendFriendRequest(widget.invitedFriend!);
      
      // Arkadaşa davet gönder
      _match = await OnlineDuelService.instance.inviteFriend(
        widget.invitedFriend!,
        widget.leagueCode,
        wordOfTheDay: _currentFact,
      );
    } else {
      // LP'ye göre rastgele eşleşme ara
      final profile = await UserProfileService.instance.loadProfile();
      _match = await OnlineDuelService.instance.findRandomMatch(
        profile.lpRating, 
        widget.leagueCode,
        wordOfTheDay: _currentFact,
      );
    }
    
    if (_match == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Maç oluşturulamadı. Lütfen tekrar deneyin.')),
        );
        Navigator.of(context).pop();
      }
      return;
    }
    
    _listenToMatch();
    
    // Timeout: Tüm düellolar için 30 saniye (Kullanıcı isteği)
    const timeoutDuration = Duration(seconds: 30);
        
    _timeoutTimer = Timer(timeoutDuration, () {
      if (_isSearching && mounted) {
        if (widget.invitedFriend != null) {
          // Arkadaş davetinde süre dolarsa bota geçmek yerine çıkış yap (Kullanıcı isteği)
          _cancelSearch();
        } else {
          _initBotIdentity();
          _startBotMatch(); // Rastgele düelloda rakip gelmezse bot ile başlat
        }
      }
    });
  }

  void _initBotIdentity() {
    if (_botName != null) return;

    final names = ['Bot Can', 'Bot Ayşe', 'Bot Mehmet', 'Bot Zeynep', 'Bot Ali', 'Bot Fatma', 'Bot Cem', 'Bot Elif'];
    const avatars = UserProfileService.avatars;
    final rng = Random();
    _botName = names[rng.nextInt(names.length)];
    _botAvatar = avatars[rng.nextInt(avatars.length)];
  }

  void _listenToMatch() {
    // Eski aboneliği iptal et (hafıza sızıntısı ve çakışmayı önle)
    _matchSubscription?.cancel();
    
    _matchSubscription = OnlineDuelService.instance.matchStream.listen((match) {
      if (match != null && mounted) {
        setState(() {
          _match = match;
        });
        
        // Eğer maç durumu 'waiting' değilse veya rakip geldiyse başla
        if (match.status != OnlineDuelStatus.waiting && 
            match.status != OnlineDuelStatus.cancelled) {
          debugPrint('🏁 MatchmakingScreen: Match is ready! Starting transition... (Status: ${match.status})');
          _onMatchFound();
        }
      }
    });

    // Servisteki son durumu kontrol et (Stream kaçırılmış olabilir)
    final serviceMatch = OnlineDuelService.instance.currentMatch;
    if (serviceMatch != null) {
      setState(() => _match = serviceMatch);
      if (serviceMatch.isReady || serviceMatch.isInProgress) {
        _onMatchFound();
      }
    }
  }

  void _onMatchFound() {
    if (!_isSearching || !mounted) return;
    
    debugPrint('🎉 MatchmakingScreen: MATCH FOUND! Transitioning to VS Screen...');
    
    setState(() {
      _isSearching = false;
      _matchFound = true;
    });
    
    _searchTimer?.cancel();
    _timeoutTimer?.cancel();
    _searchDots?.cancel();
    
    // Görev: Sosyal Kelebek (Arkadaşla düello daveti kabul edildi veya davet edildi)
    if (widget.invitedFriend != null || (_match != null && _match!.invitedUserId != null)) {
      QuestService.instance.updateProgress(QuestType.buddyDuel, 1);
    }
    
    // 1 saniye sonra oyuna başla (daha hızlı geçiş)
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted && _match != null) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => OnlineDuelScreen(
              match: _match!,
              wordOfTheDay: _currentFact,
              isRematch: widget.isRematch,
            ),
          ),
        );
      }
    });
  }

  /// Eğer 10 saniye boyunca kimse gelmezse, başka birinin odası var mı diye tekrar bakarız
  void _retryMatchmaking() async {
    if (!mounted || !_isSearching || _matchFound || _match == null) return;
    if (widget.invitedFriend != null || widget.isBot) return;

    // Sadece Host (odayı kurup bekleyen) isek başkasının odasına girmeyi deneriz
    if (_isHost && _match!.status == OnlineDuelStatus.waiting) {
      debugPrint('🔄 MatchmakingScreen: Retrying search to find other waiting opponents...');
      
      final profile = await UserProfileService.instance.loadProfile();
      final newMatch = await OnlineDuelService.instance.findRandomMatch(
        profile.lpRating, 
        widget.leagueCode,
        wordOfTheDay: _currentFact,
      );

      if (newMatch != null && newMatch.matchId != _match?.matchId) {
        debugPrint('🤝 MatchmakingScreen: Found another match while waiting! Switching to ${newMatch.matchId}');
        
        // ÖNEMLİ: Kendi oluşturduğumuz (Host olduğumuz) eski odayı iptal et.
        // İptal etmezsek RTDB'de 'waiting' kalır ve 5 dk sonra başkası girebilir (Ghost Match).
        if (_isHost && _match != null) {
          debugPrint('🧹 MatchmakingScreen: Cancelling old ghost match: ${_match!.matchId}');
          OnlineDuelService.instance.cancelMatch(); // Mevcut (eski) maçı iptal eder
        }
        
        if (mounted) {
          setState(() {
            _match = newMatch;
            _listenToMatch(); // Yeni maçı dinle
          });
        }
      }
    }
  }

  void _startBotMatch() async {
    // Online matchmaking'i temizle ki ana ekranda 'devam et' butonu çıkmasın
    OnlineDuelService.instance.cancelMatch();
    
    if (!mounted) return;
    
    setState(() {
      _isSearching = false;
      _matchFound = true;
    });
    
    _searchTimer?.cancel();
    _searchDots?.cancel();
    
    // Lig koduna göre seviye ve havuz belirle
    UserLevel level = UserLevel.a1;
    League league = League.beginner;
    if (widget.leagueCode.startsWith('C')) {
      level = UserLevel.c1;
      league = League.advanced;
    } else if (widget.leagueCode.startsWith('B')) {
      level = UserLevel.b1;
      league = League.intermediate;
    }
    // Kelime havuzunu yükle ve soruları oluştur
    await WordPoolService.instance.loadWordPool();
    var questions = WordPoolService.instance.generateQuestions(level);
    final injected = WordPoolService.instance.createQuestionFromFact(_currentFact, level.code.toUpperCase());
    if (questions.isNotEmpty) {
      questions[0] = injected;
      questions.shuffle();
    }
      
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
            builder: (context) => DuelScreen(
              wordOfTheDay: _currentFact,
              botName: _botName,
              botAvatar: _botAvatar,
            ),
            settings: RouteSettings(arguments: league),
          ),
        );
      }
    });
  }

  void _startDemoMatch() {
    setState(() {
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
    // Eğer maç bulunmadan önce (veya bot maçı başlamadan önce) ekrandan çıkılırsa,
    // online eşleşmeyi iptal et ki sistemde 'waiting' olarak kalmasın.
    if (_isSearching && !_matchFound) {
      OnlineDuelService.instance.cancelMatch();
    }
    
    _pulseController.dispose();
    _rotationController.dispose();
    _matchSubscription?.cancel();
    _timeoutTimer?.cancel();
    _searchTimer?.cancel();
    _searchDots?.cancel();
    _retryTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 1. Arka Plan Gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF1A3A5C), Color(0xFF0D1B2A)],
              ),
            ),
          ),

          // 2. Oyuncu aranırken: düello kahramanları, düşük opaklıkla arka planda
          Positioned.fill(
            child: Opacity(
              opacity: 0.15,
              child: Image.asset(
                'assets/images/duel_matchmaking_heroes_bg.png',
                fit: BoxFit.cover,
                alignment: Alignment.center,
                errorBuilder: (context, error, stackTrace) => Image.asset(
                  'assets/images/lugo.png',
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),

          // 3. İçerik
          SafeArea(
            child: Column(
              children: [
                // Üst Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white70, size: 28),
                        onPressed: _cancelSearch,
                      ),
                      const Spacer(),
                      if (_isSearching)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.black26,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            _formatTime(_searchTime),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                      const Spacer(),
                      const SizedBox(width: 48), // Close butonu ile dengelemek için
                    ],
                  ),
                ),

                const Spacer(flex: 1),

                // Mesaj Balonu (Küçük maskot kaldırıldı, sadece mesaj kaldı)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(230),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(51),
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Text(
                      widget.isBot 
                        ? context.watch<LanguageProvider>().getString('bot_ready_message')
                        : (widget.invitedFriend != null 
                            ? context.watch<LanguageProvider>().getString('waiting_for_friend').replaceAll('{username}', widget.invitedFriend!.username)
                            : context.watch<LanguageProvider>().getString('searching_optimal_opponent')),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFF1A3A5C),
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        height: 1.4,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 40),

                // Arama Animasyonu
                if (_isSearching)
                  _buildSearchingAnimation(),

                // Maç Bulundu Kartı
                if (_matchFound)
                  _buildMatchFoundCard(),

                if (_isSearching || _matchFound) ...[
                  const SizedBox(height: 24),
                  _buildWordOfTheDay(),
                ],

                const Spacer(flex: 2),

                // Lig Bilgisi (Alt Kısım)
                Container(
                  margin: const EdgeInsets.only(bottom: 40),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.amber.withAlpha(26),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: Colors.amber.withAlpha(77)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.stars, color: Colors.amber, size: 22),
                      const SizedBox(width: 10),
                      Text(
                        '${context.watch<LanguageProvider>().getString('league_prefix')} ${League.fromCode(widget.leagueCode).name.toUpperCase()}',
                        style: TextStyle(
                          color: Colors.white.withAlpha(179),
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchingAnimation() {
    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            RotationTransition(
              turns: _rotationController,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.blue.withAlpha(51),
                    width: 2,
                  ),
                ),
              ),
            ),
            ScaleTransition(
              scale: _pulseController,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.blue.withAlpha(26),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.withAlpha(77),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: const Icon(Icons.radar, color: Colors.blue, size: 40),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Text(
          '${context.watch<LanguageProvider>().getString('searching_opponent')}${'.' * (_dotsCount + 1)}',
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
          ),
        ),
      ],
    );
  }


  Widget _buildMatchFoundCard() {
    final isBot = _botName != null;
    final opponentName = isBot ? _botName! : (_opponentUsername ?? 'Rakip');
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.green.withAlpha(51),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.green.withAlpha(128)),
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
              Text(
                context.watch<LanguageProvider>().getString('match_starting'),
                style: const TextStyle(
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

  Widget _buildWordOfTheDay() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(13),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lightbulb_outline, color: Colors.amber, size: 20),
              const SizedBox(width: 8),
              Text(
                context.watch<LanguageProvider>().getString('word_of_the_day').toUpperCase(),
                style: const TextStyle(
                  color: Colors.amber,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            _currentFact['word']!,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _currentFact['meaning']!,
            style: TextStyle(
              color: Colors.white.withAlpha(179),
              fontSize: 16,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black12,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _currentFact['example']!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }


  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }
}
