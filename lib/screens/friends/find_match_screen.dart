import 'package:flutter/material.dart';
import '../../models/friend.dart';
import '../../services/friend_service.dart';

class FindMatchScreen extends StatefulWidget {
  final String leagueCode;
  final String leagueName;

  const FindMatchScreen({
    super.key,
    this.leagueCode = 'beginner',
    this.leagueName = 'Başlangıç Ligi',
  });

  @override
  State<FindMatchScreen> createState() => _FindMatchScreenState();
}

class _FindMatchScreenState extends State<FindMatchScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _rotateController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _rotateAnimation;

  bool _isSearching = true;
  bool _matchFound = false;
  Friend? _opponent;
  String _statusText = 'Rakip aranıyor...';
  int _searchSeconds = 0;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _rotateController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    _pulseAnimation = Tween<double>(begin: 0.9, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _rotateAnimation = Tween<double>(begin: 0, end: 1).animate(_rotateController);

    _startSearch();
    _startTimer();
  }

  void _startTimer() async {
    while (_isSearching && mounted) {
      await Future.delayed(const Duration(seconds: 1));
      if (mounted && _isSearching) {
        setState(() => _searchSeconds++);
      }
    }
  }

  void _startSearch() async {
    // Durum mesajlarını göster
    _updateStatus();

    // Rastgele rakip ara
    final opponent = await FriendService.instance.findRandomOpponent(widget.leagueCode);

    if (mounted) {
      setState(() {
        _isSearching = false;
        _matchFound = opponent != null;
        _opponent = opponent;
        _statusText = opponent != null ? 'Rakip bulundu!' : 'Rakip bulunamadı';
      });

      if (opponent != null) {
        // 2 saniye bekle ve oyuna başla
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) {
          _startOnlineMatch();
        }
      }
    }
  }

  void _updateStatus() async {
    final messages = [
      'Rakip aranıyor...',
      'Online oyuncular kontrol ediliyor...',
      'Lig seviyesi eşleştiriliyor...',
      'Neredeyse bulduk...',
    ];

    int index = 0;
    while (_isSearching && mounted) {
      await Future.delayed(const Duration(seconds: 3));
      if (mounted && _isSearching) {
        setState(() {
          _statusText = messages[index % messages.length];
          index++;
        });
      }
    }
  }

  void _startOnlineMatch() {
    // TODO: Online düello ekranına git
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${_opponent?.username} ile düello başlıyor! (Demo mod)'),
        backgroundColor: Colors.green,
      ),
    );
    Navigator.pop(context);
  }

  void _cancelSearch() {
    setState(() => _isSearching = false);
    Navigator.pop(context);
  }

  String get _formattedTime {
    final minutes = _searchSeconds ~/ 60;
    final seconds = _searchSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _rotateController.dispose();
    super.dispose();
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
            padding: const EdgeInsets.all(24),
            child: SingleChildScrollView(
              child: Column(
                children: [
                  // Üst bar
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: _cancelSearch,
                      ),
                      Text(
                        widget.leagueName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 48), // Balance için
                    ],
                  ),
                  const SizedBox(height: 48),
                  // Arama animasyonu
                  if (_isSearching) ...[
                    RotationTransition(
                      turns: _rotateAnimation,
                      child: Container(
                        width: 150,
                        height: 150,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.orange.withOpacity(0.3),
                            width: 3,
                          ),
                        ),
                        child: Center(
                          child: ScaleTransition(
                            scale: _pulseAnimation,
                            child: Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.orange.shade600,
                                    Colors.orange.shade400,
                                  ],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.orange.withOpacity(0.5),
                                    blurRadius: 20,
                                    spreadRadius: 5,
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.search,
                                color: Colors.white,
                                size: 50,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
                    Text(
                      _statusText,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _formattedTime,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 16,
                      ),
                    ),
                  ] else if (_matchFound && _opponent != null) ...[
                    // Rakip bulundu
                    Container(
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: Colors.green.withOpacity(0.5),
                          width: 2,
                        ),
                      ),
                      child: Column(
                        children: [
                          const Icon(
                            Icons.check_circle,
                            color: Colors.green,
                            size: 60,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Rakip Bulundu!',
                            style: TextStyle(
                              color: Colors.green,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 24),
                          CircleAvatar(
                            radius: 40,
                            backgroundColor: Colors.blue.shade300,
                            child: Text(
                              _opponent!.username[0].toUpperCase(),
                              style: const TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _opponent!.username,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${_opponent!.eloRating ?? 1500} ELO',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.7),
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    // Rakip bulunamadı
                    Container(
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: Colors.red.withOpacity(0.5),
                          width: 2,
                        ),
                      ),
                      child: Column(
                        children: [
                          const Icon(
                            Icons.error_outline,
                            color: Colors.red,
                            size: 60,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Rakip Bulunamadı',
                            style: TextStyle(
                              color: Colors.red,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Şu anda bu ligde aktif oyuncu yok.\nDaha sonra tekrar dene!',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.7),
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 48),
                  // Alt buton
                  if (_isSearching)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _cancelSearch,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'İptal',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    )
                  else if (!_matchFound)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Geri Dön',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
