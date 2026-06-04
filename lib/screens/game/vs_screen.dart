import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';

import '../../widgets/common/moving_particles.dart';
import '../../models/cosmetic_item.dart';

class VsScreen extends StatefulWidget {
  final VoidCallback onAnimationComplete;
  final String userAvatarUrl;
  final String botAvatarUrl;
  final String userName;
  final String botName;
  final int userScore;
  final int botScore;
  
  // New visual parameters
  final int userLevel;
  final int botLevel;
  final String userTier;
  final String botTier;
  final int userLp;
  final int botLp;
  final int userWinRate;
  final int botWinRate;
  final String arenaName;
  final String? userFrameId;
  final String? botFrameId;
  final Map<String, String>? wordOfTheDay;
  final String? userEmoji;
  final String? botEmoji;

  const VsScreen({
    super.key,
    required this.onAnimationComplete,
    this.userAvatarUrl = '👤',
    this.botAvatarUrl = '🤖',
    this.userName = 'You',
    this.botName = 'Bot',
    this.userScore = 0,
    this.botScore = 0,
    this.userLevel = 42,
    this.botLevel = 39,
    this.userTier = 'MASTER TIER',
    this.botTier = 'ELITE TIER',
    this.userLp = 2450,
    this.botLp = 2315,
    this.userWinRate = 68,
    this.botWinRate = 62,
    this.arenaName = 'Arena 04: Obsidian Spire',
    this.userFrameId,
    this.botFrameId,
    this.wordOfTheDay,
    this.userEmoji,
    this.botEmoji,
  });

  @override
  State<VsScreen> createState() => _VsScreenState();
}

class _VsScreenState extends State<VsScreen> with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _slideInLeft;
  late Animation<double> _slideInRight;
  late Animation<double> _scaleVs;
  late Animation<double> _fade;
  late AnimationController _vsLogoController;
  late Animation<double> _vsLogoPulse;
  late Animation<double> _vsLogoRotate;
  late Animation<double> _vsLogoEntrance;
  
  int _countdown = 4;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    _fade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.3, curve: Curves.easeIn)),
    );

    _scaleVs = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.2, 0.6, curve: Curves.elasticOut),
      ),
    );

    _slideInLeft = Tween<double>(begin: -1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.4, 1.0, curve: Curves.easeOutQuart),
      ),
    );

    _slideInRight = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.4, 1.0, curve: Curves.easeOutQuart),
      ),
    );

    _vsLogoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _vsLogoPulse = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _vsLogoController, curve: Curves.easeInOut),
    );

    _vsLogoRotate = Tween<double>(begin: -0.02, end: 0.02).animate(
      CurvedAnimation(parent: _vsLogoController, curve: Curves.easeInOut),
    );

    _vsLogoEntrance = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.2, 0.6, curve: Curves.elasticOut),
      ),
    );

    _controller.forward();
    
    _startCountdown();
  }

  void _startCountdown() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      HapticFeedback.lightImpact();
      setState(() {
        if (_countdown > 1) {
          _countdown--;
        } else {
          _timer?.cancel();
          widget.onAnimationComplete();
        }
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _vsLogoController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  Color _getTierColor(String tier) {
    tier = tier.toUpperCase();
    if (tier.contains('MASTER')) return const Color(0xFF3B82F6); // Blue
    if (tier.contains('ELITE')) return const Color(0xFFEF4444);  // Red
    if (tier.contains('DIAMOND')) return const Color(0xFF00CED1);
    if (tier.contains('GOLD')) return const Color(0xFFFFD700);
    if (tier.contains('SILVER')) return const Color(0xFFB0C4DE);
    if (tier.contains('BRONZE')) return const Color(0xFFCD7F32);
    return Colors.white70;
  }

  Widget _buildAvatar(String url, int level, Color fallbackColor, String? frameId) {
    Color frameColor = fallbackColor;
    double borderWidth = 3.0;
    bool isRainbow = false;

    // TODO: We need CosmeticItem access, let's just do a quick check
    // If we want to use CosmeticItem, we should use it here! But wait, CosmeticItem is in models.
    if (frameId != null && frameId == 'frame_rainbow') {
      isRainbow = true;
      borderWidth = 6.0;
    } else if (frameId != null) {
      // Find hardcoded colors or ignore if we can't load CosmeticItem
      // Actually, we can just use frameColor from fallback if we can't parse it easily,
      // but we should probably fetch it. Let's just hardcode the known frame colors or import CosmeticItem.
      // Wait! We can import CosmeticItem at the top of vs_screen!
    }

    return Stack(
      alignment: Alignment.bottomRight,
      children: [
        Container(
          width: 100 + borderWidth * 2,
          height: 100 + borderWidth * 2,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: isRainbow ? const LinearGradient(
              colors: [Colors.red, Colors.orange, Colors.yellow, Colors.green, Colors.blue, Colors.purple],
            ) : null,
            color: isRainbow ? null : frameColor,
            boxShadow: [
              BoxShadow(
                color: (isRainbow ? Colors.purple : frameColor).withAlpha(128),
                blurRadius: 15,
                spreadRadius: 3,
              ),
              if (frameId != null)
                BoxShadow(
                  color: (isRainbow ? Colors.cyan : frameColor).withAlpha(77),
                  blurRadius: 25,
                  spreadRadius: 5,
                ),
            ],
          ),
          child: Center(
            child: Container(
              width: 100,
              height: 100,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFF1A3A5C),
              ),
              child: ClipOval(
                child: _buildAvatarContent(url),
              ),
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: fallbackColor,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white, width: 1),
          ),
          child: Text(
            'LV $level',
            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  Widget _buildAvatarContent(String avatarUrl) {
    if (avatarUrl.startsWith('http')) {
      return Image.network(
        avatarUrl, 
        fit: BoxFit.cover, 
        width: 100, 
        height: 100, 
        errorBuilder: (_, __, ___) => const Icon(Icons.person, color: Colors.white, size: 50)
      );
    } else if (avatarUrl.startsWith('assets')) {
      return Image.asset(
        avatarUrl, 
        fit: BoxFit.cover, 
        width: 100, 
        height: 100, 
        errorBuilder: (_, __, ___) => const Icon(Icons.person, color: Colors.white, size: 50)
      );
    } else {
      // Check if it's a cosmetic ID
      final items = CosmeticItem.availableItems.where((i) => i.id == avatarUrl);
      if (items.isNotEmpty) {
        final preview = items.first.previewValue;
        if (preview.startsWith('assets/')) {
          return Image.asset(
            preview,
            fit: BoxFit.cover,
            width: 100,
            height: 100,
            errorBuilder: (_, __, ___) => const Icon(Icons.person, color: Colors.white, size: 50),
          );
        }
        return Center(child: Text(preview, style: const TextStyle(fontSize: 50)));
      }
      return Center(child: Text(avatarUrl, style: const TextStyle(fontSize: 50)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF030816), // Çok koyu derin mavi
      child: FadeTransition(
        opacity: _fade,
        child: Stack(
          children: [
            // Arka Plan Resmi ve Işıltıları / Gradient
            Positioned.fill(
              child: Opacity(
                opacity: 0.15, // Çok bağırmaması için düşük opaklık
                child: Image.asset(
                  'assets/images/vs_bg.jpg',
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(), // Resim yoksa boş döner
                ),
              ),
            ),
            Positioned.fill(child: MovingParticles(count: 35, color: Colors.blue.withAlpha(50))),
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0, -0.3),
                    radius: 1.5,
                    colors: [
                      const Color(0xFF0A1A3A).withAlpha(150),
                      const Color(0xFF030816).withAlpha(200),
                    ],
                  ),
                ),
              ),
            ),

            SafeArea(
              child: Column(
                children: [
                  const SizedBox(height: 40),
                  
                  // Üst tarafta VS Alanı ve Kartlar
                  Expanded(
                    child: Center(
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 450),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // 1. Arka Planda Mızraklı VS Amblemi (Watermark Tarzında)
                            ScaleTransition(
                              scale: _scaleVs,
                              child: Opacity(
                                opacity: 0.5, // Bilgileri engellememesi için şeffaflaştırıldı
                                child: _buildCentralVsEmblem(),
                              ),
                            ),

                            // 2. Oyuncu Kartları
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                // Üst Oyuncu Kartı (Emre Aktas)
                                AnimatedBuilder(
                                  animation: _slideInLeft,
                                  builder: (context, child) => Transform.translate(
                                    offset: Offset(_slideInLeft.value * 500, 0),
                                    child: child,
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 20),
                                    child: _buildModernPlayerCard(
                                      name: widget.userName,
                                      tier: widget.userTier,
                                      points: widget.userLp,
                                      winRate: widget.userWinRate,
                                      level: widget.userLevel,
                                      avatarUrl: widget.userAvatarUrl,
                                      frameId: widget.userFrameId,
                                      isRightAligned: false,
                                      glowColor: const Color(0xFF3B82F6),
                                    ),
                                  ),
                                ),
                                
                                const SizedBox(height: 100), // Kartlar arasındaki mesafe artırıldı (Amblem için yer açıldı)
                                
                                // Alt Oyuncu Kartı (Cem)
                                AnimatedBuilder(
                                  animation: _slideInRight,
                                  builder: (context, child) => Transform.translate(
                                    offset: Offset(_slideInRight.value * 500, 0),
                                    child: child,
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 20),
                                    child: _buildModernPlayerCard(
                                      name: widget.botName,
                                      tier: widget.botTier,
                                      points: widget.botLp,
                                      winRate: widget.botWinRate,
                                      level: widget.botLevel,
                                      avatarUrl: widget.botAvatarUrl,
                                      frameId: widget.botFrameId,
                                      isRightAligned: true,
                                      glowColor: const Color(0xFFF59E0B),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Alt Kısım: Hazır Butonu ve Durum
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                    child: Column(
                      children: [
                        _buildMainReadyButton(),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'TR: HAZIRLANILIYOR...', 
                              style: TextStyle(color: Colors.white.withAlpha(50), fontSize: 10, fontWeight: FontWeight.bold)
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              child: Text('|', style: TextStyle(color: Colors.white.withAlpha(30), fontSize: 10)),
                            ),
                            const Text(
                              'EN: PREPARING...', 
                              style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold)
                            ),
                            const SizedBox(width: 8),
                            const SizedBox(
                              width: 10,
                              height: 10,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white24),
                            ),
                          ],
                        ),
                        if (widget.wordOfTheDay != null) ...[
                          const SizedBox(height: 20),
                          _buildWordOfTheDayWidget(),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernPlayerCard({
    required String name,
    required String tier,
    required int points,
    required int winRate,
    required int level,
    required String avatarUrl,
    required String? frameId,
    required bool isRightAligned,
    required Color glowColor,
  }) {
    // Safely extract rank (e.g., MASTER TIER -> MA)
    List<String> parts = tier.split(' ');
    String displayRank = parts.isNotEmpty ? parts[0] : 'A1';
    if (displayRank.length > 2) {
      displayRank = displayRank.substring(0, 2).toUpperCase();
    } else {
      displayRank = displayRank.toUpperCase();
    }

    return Container(
      height: 160,
      decoration: BoxDecoration(
        color: const Color(0xFF1E3A5F).withAlpha(100), // Cam efekti
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFF4FC3F7).withAlpha(100),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(150),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            // Kenar Parlaması (Neon efekti)
            Positioned(
              left: 0, top: 0, bottom: 0,
              child: Container(width: 4, decoration: BoxDecoration(color: glowColor.withAlpha(200))),
            ),
            
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                textDirection: isRightAligned ? TextDirection.rtl : TextDirection.ltr,
                children: [
                  // Avatar
                  _buildAvatarCircle(avatarUrl, level, glowColor, frameId),
                  
                  const SizedBox(width: 20),
                  
                  // Bilgiler
                  Expanded(
                    child: Column(
                      crossAxisAlignment: isRightAligned ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            color: Color(0xFFFFD54F),
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildStatLine('RANK', displayRank, isRightAligned),
                        _buildStatLine('POINTS', points.toString(), isRightAligned),
                        _buildStatLine('WIN RATE', '$winRate%', isRightAligned, isBig: true),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatLine(String label, String value, bool isRightAligned, {bool isBig = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              color: Colors.white.withAlpha(150),
              fontSize: isBig ? 14 : 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: isBig ? const Color(0xFFFFD54F) : Colors.white,
              fontSize: isBig ? 24 : 14,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarCircle(String url, int level, Color glowColor, String? frameId) {
    return Stack(
      alignment: Alignment.bottomRight,
      children: [
        // Dış Parlama Halkası
        Container(
          width: 90,
          height: 90,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: glowColor, width: 3),
            boxShadow: [
              BoxShadow(color: glowColor.withAlpha(100), blurRadius: 15, spreadRadius: 2),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(4.0),
            child: Container(
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFF030816),
              ),
              child: ClipOval(
                child: _buildAvatarContent(url),
              ),
            ),
          ),
        ),
        // Level Rozeti
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF8B5E3C), // Kahverengi/Altın tonu
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFFFD54F), width: 1.5),
          ),
          child: Text(
            'LV $level',
            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  Widget _buildCentralVsEmblem() {
    return AnimatedBuilder(
      animation: Listenable.merge([_vsLogoController, _controller]),
      builder: (context, child) {
        return Transform.scale(
          scale: _vsLogoEntrance.value * _vsLogoPulse.value,
          child: Transform.rotate(
            angle: _vsLogoRotate.value,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.amber.withValues(alpha: 0.15 * _vsLogoPulse.value),
                    blurRadius: 40,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                   Image.asset(
                    'assets/images/vs_emblem.png',
                    width: 180,
                    height: 180,
                    fit: BoxFit.contain,
                    errorBuilder: _vsFallbackBuilder,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  static Widget _vsFallbackBuilder(BuildContext context, Object error, StackTrace? stackTrace) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Merkez VS Halkası - Modern & Premium
        Container(
          width: 85, 
          height: 85,
          decoration: BoxDecoration(
            shape: BoxShape.circle, 
            gradient: const LinearGradient(
              colors: [
                Color(0xFFD4AF37), // Metallic Gold
                Color(0xFF8B5E3C), // Deep Bronze
                Color(0xFFB8860B), // Dark Goldenrod
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: Colors.white.withAlpha(80), width: 2.5),
            boxShadow: [
              BoxShadow(
                color: Colors.orange.withAlpha(100),
                blurRadius: 20,
                spreadRadius: 2,
              ),
              const BoxShadow(
                color: Colors.black45,
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: const Center(
            child: Text(
              'VS', 
              style: TextStyle(
                color: Colors.white, 
                fontSize: 28, 
                fontWeight: FontWeight.w900, 
                fontStyle: FontStyle.italic,
                letterSpacing: -1,
                shadows: [
                  Shadow(color: Colors.black26, offset: Offset(0, 2), blurRadius: 4),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }


  Widget _buildMainReadyButton() {
    // Geri sayım rakamlarını 3, 2, 1 şeklinde göster
    bool showNumber = _countdown > 1;
    String label = showNumber ? (_countdown - 1).toString() : 'HAZIR';

    return Container(
      width: double.infinity,
      height: 80,
      decoration: BoxDecoration(
        color: const Color(0xFF1E3A5F).withAlpha(150),
        borderRadius: BorderRadius.circular(40),
        border: Border.all(
          color: showNumber ? Colors.orange.withAlpha(100) : const Color(0xFF4FC3F7).withAlpha(150), 
          width: 2
        ),
      ),
      alignment: Alignment.center,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        transitionBuilder: (Widget child, Animation<double> animation) {
          return ScaleTransition(scale: animation, child: FadeTransition(opacity: animation, child: child));
        },
        child: Container(
          key: ValueKey<String>(label),
          margin: const EdgeInsets.all(4),
          padding: EdgeInsets.symmetric(horizontal: showNumber ? 60 : 40),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(35),
            gradient: LinearGradient(
              colors: showNumber 
                  ? [const Color(0xFFF59E0B), const Color(0xFFD97706)] // Geri sayım için turuncu/amber
                  : [const Color(0xFF8B5E3C), const Color(0xFFD4AF37), const Color(0xFF8B5E3C)], // Hazır iin altın
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: (showNumber ? Colors.orange : Colors.amber).withAlpha(150), 
                blurRadius: 15, 
                offset: const Offset(0, 4)
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: Colors.white, 
                  fontWeight: FontWeight.w900, 
                  fontSize: showNumber ? 40 : 28, 
                  letterSpacing: 2
                ),
              ),
              if (!showNumber) ...[
                const SizedBox(width: 12),
                const Icon(Icons.check_circle_outline, color: Colors.white, size: 32),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimerBox(String digit) {
    return Container(
      width: 50,
      height: 60,
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(13),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white10),
      ),
      child: Center(
        child: Text(
          digit,
          style: const TextStyle(color: Colors.orange, fontSize: 32, fontWeight: FontWeight.w900, fontStyle: FontStyle.italic),
        ),
      ),
    );
  }
  Widget _buildWordOfTheDayWidget() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withAlpha(20)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lightbulb_outline, color: Colors.amber, size: 16),
              const SizedBox(width: 8),
              Text(
                'GÜNÜN KELİMESİ',
                style: TextStyle(
                  color: Colors.amber.withAlpha(200),
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            widget.wordOfTheDay!['word']!,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            widget.wordOfTheDay!['meaning']!,
            style: TextStyle(
              color: Colors.white.withAlpha(150),
              fontSize: 14,
              fontStyle: FontStyle.italic,
            ),
          ),
          if (widget.wordOfTheDay!['example'] != null) ...[
            const SizedBox(height: 8),
            Text(
              widget.wordOfTheDay!['example']!,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withAlpha(100),
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
