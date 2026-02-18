import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/practice_provider.dart';
import 'dart:async';
import '../../models/user_level.dart';
import '../../models/premium.dart';
import '../../services/user_profile_service.dart';
import '../../services/word_pool_service.dart';
import '../../services/shop_service.dart';
import '../../services/firebase/auth_service.dart';
// import '../../services/sound_service.dart';
import '../game/saved_pool_screen.dart';
import '../game/level_selection_screen.dart';
import '../profile/profile_screen_new.dart';
import '../../services/daily_123_service.dart';
import '../../services/friend_service.dart';
import '../../models/cosmetic_item.dart';
import '../friends/friends_screen.dart';
import '../shop/shop_screen.dart';
import '../../widgets/common/daily_reward_dialog.dart'; // Added import

import '../game/daily_123_intro_screen.dart';
import '../game/matchmaking_screen.dart';
import '../onboarding/tutorial_screen.dart';
import '../../services/online_duel_service.dart';
import '../game/online_duel_screen.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> with TickerProviderStateMixin, WidgetsBindingObserver {
  late AnimationController _pulseController;
  // ignore: unused_field - Pulse animasyonu için saklanıyor
  late Animation<double> _pulseAnimation;
  late AnimationController _coinAnimController;
  late Animation<double> _coinScaleAnim;
  late AnimationController _bellAnimController;
  late Animation<double> _bellShakeAnim;
  Timer? _invitationTimer;
  
  bool _isLoading = true;
  // ignore: unused_field - Test tamamlama durumu için saklanıyor
  final bool _hasCompletedTest = false;
  bool _canPlayDaily123 = true;
  UserProfile? _userProfile;
  int _coins = 0;
  int _pendingInvitationsCount = 0;
  // ignore: unused_field - Premium durumu için saklanıyor
  bool _isPremium = false;
  String? _selectedFrameId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      DailyRewardDialog.show(context);
    });
    WidgetsBinding.instance.addObserver(this);
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    
    // Coin animasyonu
    _coinAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _coinScaleAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.3), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.3, end: 1.0), weight: 50),
    ]).animate(CurvedAnimation(parent: _coinAnimController, curve: Curves.easeInOut));
    
    // Zil animasyonu (shake effect)
    _bellAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _bellShakeAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 0.1), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 0.1, end: -0.1), weight: 20),
      TweenSequenceItem(tween: Tween(begin: -0.1, end: 0.1), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 0.1, end: -0.1), weight: 20),
      TweenSequenceItem(tween: Tween(begin: -0.1, end: 0.0), weight: 20),
    ]).animate(CurvedAnimation(parent: _bellAnimController, curve: Curves.easeInOut));
    
    _loadUserData().then((_) {
      // Real-time davetleri dinle
      OnlineDuelService.instance.listenForInvitations((match) {
        if (mounted) {
          _showInvitationDialog(match);
        }
      });
    });
    _invitationTimer = Timer.periodic(const Duration(seconds: 30), (_) => _checkInvitations());
    
    // Profili Firestore ile senkronize et
    // _loadUserData içinde yapılıyor
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Uygulama ön plana geldiğinde coin'i güncelle
    if (state == AppLifecycleState.resumed) {
      _refreshCoins();
    }
  }
  
  /// Sadece coin değerini günceller (hızlı refresh) - animasyonlu
  Future<void> _refreshCoins({bool animate = false}) async {
    final coins = await ShopService.instance.getCoins();
    if (mounted && coins != _coins) {
      final oldCoins = _coins;
      setState(() {
        _coins = coins;
      });
      // Coin arttıysa animasyon ve ses çal
      if (animate || coins > oldCoins) {
        _playCoinAnimation();
      }
    }
  }
  
  /// Coin animasyonu ve sesi
  void _playCoinAnimation() {
    _coinAnimController.forward(from: 0);
    // SoundService.instance.playCoinSound();
  }
  
  /// Davet animasyonu ve sesi
  void _playInviteAnimation() {
    _bellAnimController.forward(from: 0);
    // SoundService.instance.playInviteSound();
  }

  Future<void> _checkInvitations() async {
    final invitations = await FriendService.instance.getDuelInvitations();
    if (mounted && invitations.length != _pendingInvitationsCount) {
      final hadNewInvitations = invitations.length > _pendingInvitationsCount;
      setState(() {
        _pendingInvitationsCount = invitations.length;
      });
      // Yeni davet geldiyse animasyon ve ses çal
      if (hadNewInvitations && invitations.isNotEmpty) {
        _playInviteAnimation();
      }
    }
  }

  void _showInvitationDialog(OnlineDuelMatch match) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2E5A8C),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Düello Daveti!', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text(
          '${match.hostUsername} seni düelloya davet ediyor! (Lig: ${match.leagueCode})',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Reddet', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () async {
              // Context'i kaydet (dialog kapanmadan önce)
              final navigator = Navigator.of(context);
              final scaffoldMessenger = ScaffoldMessenger.of(context);
              
              // Dialog'u kapat
              navigator.pop();
              
              // Maça katıl
              final joinedMatch = await OnlineDuelService.instance.joinMatch(match.matchId);
              
              if (joinedMatch != null && mounted) {
                // Root navigator kullan (daha güvenli)
                Navigator.of(this.context).push(
                  MaterialPageRoute(
                    builder: (context) => OnlineDuelScreen(match: joinedMatch),
                  ),
                );
              } else if (mounted) {
                scaffoldMessenger.showSnackBar(
                  const SnackBar(content: Text('Maça katılamadı. Maç dolmuş veya silinmiş olabilir.')),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Kabul Et', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _loadUserData() async {
    // Otomatik anonim giriş
    if (!AuthService.instance.isAuthenticated) {
      await AuthService.instance.signInAnonymously();
    }

    // TEST GOLD REMOVED

    await WordPoolService.instance.loadWordPool();
    await OnlineDuelService.instance.initialize(); // Eklendi
    var profile = await UserProfileService.instance.loadProfile();
    final canPlayDaily = await Daily123Service.instance.canPlayToday();
    
    // Firebase'den kullanıcı bilgilerini al ve lokal profili güncelle
    final authUser = AuthService.instance.user;
    if (authUser != null) {
      // Eğer username Player ise ve authUser'da bilgi varsa güncelle
      if (profile.username == 'Player') {
        final newUsername = authUser.displayName ?? authUser.email?.split('@').first ?? 'Player';
        final newEmail = authUser.email;
        if (newUsername != 'Player' || (newEmail != null && newEmail.isNotEmpty)) {
          profile = profile.copyWith(
            username: newUsername != 'Player' ? newUsername : profile.username,
            email: newEmail ?? profile.email,
          );
          await UserProfileService.instance.saveProfile(profile);
        }
      }
    }
    
    // Yeni kullanıcıysa A2 set et (Seviye tespit süreci A2'den başlar)
    if (!profile.hasCompletedPlacementTest) {
      if (profile.level != UserLevel.a2) {
        await UserProfileService.instance.updateLevel(UserLevel.a2);
        profile = await UserProfileService.instance.loadProfile();
      }
    }

    // Hoşgeldin hediyesi kontrolü
    final isNewUser = await ShopService.instance.checkAndGiveWelcomeGift();
    
    // Günlük bonus
    final dailyResult = await ShopService.instance.claimDailyBonus();
    
    final coins = await ShopService.instance.getCoins();
    final invitations = await FriendService.instance.getDuelInvitations();
    
    // Premium durumu kontrol et
    final subscription = await ShopService.instance.getSubscription();
    final isPremium = subscription.tier != PremiumTier.free;
    
    // Seçili çerçeveyi yükle
    final selectedFrame = await ShopService.instance.getSelectedCosmetic(CosmeticType.frame);
    
    // Practice provider'ı profile'dan güncelle
    final practiceProvider = Provider.of<PracticeProvider>(context, listen: false);
    await practiceProvider.loadSessionFromProfile();
    
    if (mounted) {
      setState(() {
        _userProfile = profile;
        _coins = coins;
        _pendingInvitationsCount = invitations.length;
        _canPlayDaily123 = canPlayDaily;
        _isPremium = isPremium;
        _selectedFrameId = selectedFrame;
        _isLoading = false;
      });
      
      // İlk girişte tutorial göster
      final shouldShowTutorial = await TutorialScreen.shouldShowTutorial();
      if (shouldShowTutorial && mounted) {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => TutorialScreen(
              onComplete: () async {
                Navigator.of(context).pop();
                // Tutorial bitince hoşgeldin hediyesi dialog'unu göster
                if (isNewUser) {
                  _showWelcomeGiftDialog();
                } else if (dailyResult['coins'] as int > 0) {
                  _showDailyBonusDialog(dailyResult);
                }
                // Sonra practice'e yönlendir
                if (mounted) {
                  Navigator.of(context).pushReplacementNamed('/7030');
                }
              },
            ),
          ),
        );
      } else {
        // Tutorial gösterilmediyse normal şekilde dialog'ları göster
        if (isNewUser) {
          _showWelcomeGiftDialog();
        } else if (dailyResult['coins'] as int > 0) {
          _showDailyBonusDialog(dailyResult);
        }
      }
    }
    
    // Her şey yüklendikten sonra profili sync et (artık Auth ID var)
    await UserProfileService.instance.syncProfileToFirestore();
  }

  void _showWelcomeGiftDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2E5A8C),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Text('🎁', style: TextStyle(fontSize: 28)),
            SizedBox(width: 10),
            Text('Hoşgeldin Hediyesi!', style: TextStyle(color: Colors.white, fontSize: 20)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [const Color(0xFFFFD700).withValues(alpha: 0.3), const Color(0xFFFF8C00).withValues(alpha: 0.2)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'LUGORENA\'ya hoşgeldin! 🎉\n\n💰 100 Altın\n🃏 Tüm jokerlerden 2\'şer adet\n\nHediyeleriniz hesabınıza eklendi!',
                style: TextStyle(color: Colors.white, fontSize: 16, height: 1.5),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2AA7FF),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Harika!', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _showDailyBonusDialog(Map<String, dynamic> result) async {
    final coins = result['coins'] as int;
    final streak = result['streak'] as int;
    final rewards = result['rewards'] as List<String>;
    
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2E5A8C),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Text('🔥', style: TextStyle(fontSize: 28)),
            const SizedBox(width: 10),
            Text('$streak Gün Serisi!', style: const TextStyle(color: Colors.white, fontSize: 20)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [const Color(0xFF00F5A0).withValues(alpha: 0.3), const Color(0xFF00D9F5).withValues(alpha: 0.2)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Text(
                    '+$coins Altın 🪙',
                    style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  if (rewards.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const Divider(color: Colors.white24),
                    const SizedBox(height: 8),
                    ...rewards.map((r) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text(r, style: const TextStyle(color: Colors.amber, fontSize: 14)),
                    )),
                  ],
                ],
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2AA7FF),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Devam', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _refreshProfile() async {
    final profile = await UserProfileService.instance.loadProfile();
    if (mounted) {
      setState(() {
        _userProfile = profile;
        // sessionsInRow ve diğer state güncelleniyor
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pulseController.dispose();
    _coinAnimController.dispose();
    _bellAnimController.dispose();
    _invitationTimer?.cancel();
    super.dispose();
  }

  void _showDuelInfo() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2E5A8C),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Text('⚔️', style: TextStyle(fontSize: 28)),
            SizedBox(width: 12),
            Text('Duel Modu', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildInfoSection('🎯 Nasıl Oynanır?',
                'Rakibinle 1v1 kelime yarışması! '
                'Bot, online rakip veya arkadaşlarınla 10 soruluk maçlarda yarış. '
                'En yüksek skoru alan kazanır!'),
              const SizedBox(height: 16),
              _buildInfoSection('📊 ELO Puanlama Sistemi',
                '• Standart ELO formülü kullanılır (Chess, Lichess gibi)\n'
                '• Galibiyet: +5 ile +50 puan arası\n'
                '• Mağlubiyet: -5 ile -50 puan arası\n'
                '• Beraberlik: Beklenen sonuca göre değişir\n'
                '• Güçlü rakibi yenmek: YÜKSEK kazanç (+25~+40)\n'
                '• Zayıf rakibe kaybetmek: YÜKSEK kayıp (-25~-40)'),
              const SizedBox(height: 16),
              _buildInfoSection('🤖 Mod Seçenekleri',
                '• Online Rakip: Rastgele bir oyuncuyla eşleş\n'
                '• Bot: AI rakibe karşı pratik yap (ELO: 1500)\n'
                '• Arkadaş: Arkadaş listenden birini davet et'),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8FB6D9)),
            child: const Text('Anladım!', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showPracticeInfo() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2E5A8C),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Text('📚', style: TextStyle(fontSize: 28)),
            SizedBox(width: 10),
            Text('Practice (70/30)', style: TextStyle(color: Colors.white, fontSize: 20)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildInfoSection('🎯 Nasıl Oynanır?', 
                'Her oturumda 10 soru cevaplayarak kelime bilginizi pekiştirirsiniz. '
                'Sorular seviyenize göre otomatik olarak belirlenir.'),
              const SizedBox(height: 16),
              _buildInfoSection('📊 Seviye Sistemi',
                '• A2 seviyesinden başlarsınız\n'
                '• %70+ başarı (7-10 doğru): Derhal üst seviyeye geçiş\n'
                '• %30- başarı (0-3 doğru): Derhal alt seviyeye düşüş\n'
                '• 4, 5 veya 6 doğru yaparsan aynı seviyede kalırsın.\n'
                '• Seviyeler: A1 → A2 → B1 → B2 → C1 → C2'),
              const SizedBox(height: 16),
              _buildInfoSection('💰 Puanlama',
                '• A seviyesi: +5 / -3 puan\n'
                '• B seviyesi: +10 / -6 puan\n'
                '• C seviyesi: +15 / -9 puan\n'
                '• Hızlı cevaplar ekstra puan kazandırır!'),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF26A69A)),
            child: const Text('Anladım!', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
  
  void _showDaily123Info() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2E5A8C),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Text('🎲', style: TextStyle(fontSize: 28)),
            SizedBox(width: 10),
            Text('Daily 123', style: TextStyle(color: Colors.white, fontSize: 20)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildInfoSection('🎯 Nasıl Oynanır?',
                'Günde bir kez oynayabileceğin özel yarışma! '
                'A1 seviyesinden başlarsın. Doğru cevaplarsan üst seviyeye, '
                'yanlış cevaplarsan alt seviyeye geçersin.'),
              const SizedBox(height: 16),
              _buildInfoSection('📊 Puanlama Sistemi (Doğru/Yanlış)',
                '• A1: +2 / 0 puan\n'
                '• A2: +3 / -1 puan\n'
                '• B1: +5 / -2 puan\n'
                '• B2: +7 / -3 puan\n'
                '• C1: +9 / -5 puan\n'
                '• C2: +11 / -7 puan'),
              const SizedBox(height: 16),
              _buildInfoSection('⚠️ Önemli',
                '• Ekstra puan bonusu YOK\n'
                '• Seri puanı YOK\n'
                '• Sadece seviye puanları geçerli!'),
              const SizedBox(height: 16),
              _buildInfoSection('⏰ Günlük Sıfırlama',
                'Her gün gece yarısı sıfırlanır. Yeni bir şans için yarını bekle!'),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF8A65)),
            child: const Text('Anladım!', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
  
  Widget _buildInfoSection(String title, String content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.amber,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          content,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.85),
            fontSize: 13,
            height: 1.4,
          ),
        ),
      ],
    );
  }

  void _startPractice({required bool hasCompletedPlacement}) {
    // Artık her iki durumda da (/7030) SeventyThirtyScreen'e gidiyoruz.
    // Tasarım birliği için PlacementTestScreen (Adaptif) kullanımı kaldırıldı.
    Navigator.pushNamed(context, '/7030');
  }

  void _startDuel() {
    // Kullanıcı ELO'su ile eşleşme başlat
    final userProfile = _userProfile;
    if (userProfile == null) return;
    int userElo = 1000;
    // Lig skorlarından uygun olanı seç
    if (userProfile.level == UserLevel.a1 || userProfile.level == UserLevel.a2) {
      userElo = userProfile.leagueScores.beginnerElo;
    } else if (userProfile.level == UserLevel.b1 || userProfile.level == UserLevel.b2) {
      userElo = userProfile.leagueScores.intermediateElo;
    } else if (userProfile.level == UserLevel.c1 || userProfile.level == UserLevel.c2) {
      userElo = userProfile.leagueScores.advancedElo;
    }
    // Online Düello
    Navigator.push(context, MaterialPageRoute(
      builder: (context) => MatchmakingScreen(
        leagueCode: userProfile.level.code ?? 'A1', 
        isBot: false,
      ),
    ));
  }

  void startBotDuel() {
    // Kullanıcı seviyesine/ELO'suna göre lig kodunu otomatik belirle
    final userProfile = _userProfile;
    if (userProfile == null) return;

    int userElo = 1000;
    if (userProfile.level == UserLevel.a1 || userProfile.level == UserLevel.a2) {
      userElo = userProfile.leagueScores.beginnerElo;
    } else if (userProfile.level == UserLevel.b1 || userProfile.level == UserLevel.b2) {
      userElo = userProfile.leagueScores.intermediateElo;
    } else if (userProfile.level == UserLevel.c1 || userProfile.level == UserLevel.c2) {
      userElo = userProfile.leagueScores.advancedElo;
    }
    Navigator.push(context, MaterialPageRoute(
      builder: (context) => MatchmakingScreen(
        leagueCode: userProfile.level.code ?? 'A1', 
        isBot: true,
      ),
    ));
  }

  // ignore: unused_element - Premium dialog için saklanıyor
  void _showPremiumRequiredDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2E5A8C),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Text('👑', style: TextStyle(fontSize: 28)),
            SizedBox(width: 10),
            Text('Premium Gerekli', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'MaxiGame özelliği Premium üyelere özeldir!',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Premium Avantajları:', style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
                  SizedBox(height: 8),
                  Text('✓ 3-4 kişilik MaxiGame', style: TextStyle(color: Colors.white70)),
                  Text('✓ Arkadaş odası oluşturma', style: TextStyle(color: Colors.white70)),
                  Text('✓ Özel avatarlar ve çerçeveler', style: TextStyle(color: Colors.white70)),
                  Text('✓ Reklamsız deneyim', style: TextStyle(color: Colors.white70)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Daha Sonra', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pushNamed(context, '/shop');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFD700),
            ),
            child: const Text('Premium Ol', style: TextStyle(color: Colors.black87)),
          ),
        ],
      ),
    );
  }



  Widget _buildMenuCard({
    required String title,
    required String subtitle,
    required String icon,
    required Color color,
    required VoidCallback onTap,
    bool isLocked = false,
    bool useGradient = true,
    VoidCallback? onInfoTap,
  }) {
    return _MenuCard(
      title: title,
      subtitle: subtitle,
      icon: icon,
      color: color,
      onTap: onTap,
      isLocked: isLocked,
      useGradient: useGradient,
      onInfoTap: onInfoTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF2E5A8C), Color(0xFF1A3A5C)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: const Center(
            child: CircularProgressIndicator(color: Colors.white),
          ),
        ),
      );
    }

    return ChangeNotifierProvider(
      create: (_) => PracticeProvider()..startSession(),
      child: _buildMainScreen(),
    );
  }


  Widget _buildMainScreen() {
    final practiceProvider = Provider.of<PracticeProvider>(context, listen: true);
    final duelUnlocked = practiceProvider.duelUnlocked;
    final sessionsInRow = practiceProvider.sessionsInRow;
    final hasCompletedPlacement = duelUnlocked || sessionsInRow >= 5;
    final progressText = hasCompletedPlacement
      ? 'Seviyene Göre Çalışmaya Devam Et'
      : 'Seviye Tespiti: $sessionsInRow / 5';
      
    // Duel butonu için kalan yarış metni
    String duelSubtitle;
    if (hasCompletedPlacement) {
      duelSubtitle = 'Arkadaşlarınla veya bota karşı yarış';
    } else {
      final kalan = 5 - sessionsInRow;
      duelSubtitle = 'Seviye Tespiti: $sessionsInRow / 5';
    }
    // Motivasyon mesajı seçimi
    // Motivasyon mesajı kaldırıldı
    return Scaffold(
      backgroundColor: const Color(0xFF1A3A5C),
      body: Stack(
        children: [
          // Arka plan gradyanı ve desen (opsiyonel)
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.topRight,
                  radius: 1.5,
                  colors: [Color(0xFF2E5A8C), Color(0xFF1A3A5C)],
                ),
              ),
            ),
          ),
          
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 16),
                        // Üst Bar: Profil ve Para
                        _buildTopBar(),
                        const SizedBox(height: 24),
                        
                        // Karşılama Metni
                        const SizedBox(height: 24),
                        const Text(
                          'Master a new word every day!',
                          style: TextStyle(
                            color: Colors.white60,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 20),
                        
                        // Ana Menü Kartları (Grid)
                        GridView.count(
                          crossAxisCount: 1,
                          childAspectRatio: 2.6,
                          mainAxisSpacing: 12,
                          physics: const NeverScrollableScrollPhysics(), // Kaydırma kaldırıldı
                          shrinkWrap: true,
                          children: [
                            _buildMenuCard(
                              title: hasCompletedPlacement ? 'Practice (70/30)' : 'LEVEL TEST',
                              subtitle: hasCompletedPlacement ? 'Seviyene Göre Çalışmaya Devam Et' : progressText,
                              icon: 'assets/images/menu_practice.jpg',
                              color: const Color(0xFF26A69A), // Ocean Teal
                              onTap: () => _startPractice(hasCompletedPlacement: hasCompletedPlacement),
                              onInfoTap: _showPracticeInfo,
                            ),
                            _buildMenuCard(
                              title: 'Duel',
                              subtitle: duelSubtitle,
                              icon: 'assets/images/menu_duel.jpg',
                              color: const Color(0xFF8FB6D9), // Soft Sky Blue
                              onTap: duelUnlocked ? _startDuel : () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Duel modunu açmak için önce 5 adet Practice (70/30) oturumu tamamlamalısın.'),
                                    duration: Duration(seconds: 3),
                                  ),
                                );
                              },
                              isLocked: !duelUnlocked,
                              onInfoTap: _showDuelInfo,
                              useGradient: false, // Gradyan kaldırıldı
                            ),
                            _buildMenuCard(
                              title: 'Daily 123',
                              subtitle: 'Günün rekorunu kırmak için yarış',
                              icon: 'assets/images/menu_daily123.jpg',
                              color: const Color(0xFFFF8A65), // Vibrant Coral (Davetlerin eski rengi)
                              onTap: () async {
                                if (_canPlayDaily123) {
                                   await Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (context) => const Daily123IntroScreen()),
                                  );
                                  _loadUserData();
                                }
                              },
                              isLocked: !_canPlayDaily123,
                              useGradient: false,
                              onInfoTap: _showDaily123Info,
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 16),
                        
                        // Alt Butonlar (Daha canlı ve belirgin)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: _buildVibrantButton(
                                icon: Icons.bookmark_rounded,
                                label: 'My Words',
                                color: const Color(0xFF4FC3F7), // Daha açık ve canlı bir mavi
                                textColor: Colors.black87,
                                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SavedPoolScreen())),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildVibrantButton(
                                icon: Icons.storefront_rounded,
                                label: 'Market',
                                color: const Color(0xFFFFD700), // Canlı Altın/Sarı
                                textColor: Colors.black87,
                                onTap: () => Navigator.pushNamed(context, '/shop').then((_) => _refreshCoins(animate: true)),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                      ],
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

  /// Ana sayfada çerçeveli avatar widget'ı
  Widget _buildAvatarWithFrame() {
    // Çerçeve rengini belirle
    Color? frameColor;
    double borderWidth = 0;
    
    if (_selectedFrameId != null && _selectedFrameId!.isNotEmpty) {
      final frames = CosmeticItem.availableItems.where((i) => i.id == _selectedFrameId);
      if (frames.isNotEmpty) {
        final frame = frames.first;
        if (frame.previewValue != 'gradient') {
          try {
            // Hex rengi doğrula
            final hexValue = frame.previewValue.replaceAll('#', '');
            if (RegExp(r'^[0-9A-Fa-f]{6}$').hasMatch(hexValue)) {
              frameColor = Color(int.parse('FF$hexValue', radix: 16));
            }
          } catch (_) {}
        }
        borderWidth = frame.borderWidth.toDouble();
      }
    }
    
    return Container(
      padding: EdgeInsets.all(borderWidth > 0 ? borderWidth : 0),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: frameColor != null ? Border.all(color: frameColor, width: borderWidth) : null,
      ),
      child: CircleAvatar(
        radius: 20,
        backgroundColor: (_userProfile?.avatarId != null && _userProfile!.avatarId!.isNotEmpty)
            ? Colors.transparent  // Avatar varsa şeffaf
            : const Color(0xFF2E5A8C),  // Avatar yoksa koyu mavi
        child: _userProfile?.avatarId != null && _userProfile!.avatarId!.isNotEmpty
          ? Text(
              CosmeticItem.availableItems.where((i) => i.id == _userProfile!.avatarId).isNotEmpty
                  ? CosmeticItem.availableItems.firstWhere((i) => i.id == _userProfile!.avatarId).previewValue
                  : '👤',
              style: const TextStyle(fontSize: 18))
          : Text(
              (_userProfile?.username.isNotEmpty == true) 
                  ? _userProfile!.username[0].toUpperCase() 
                  : 'P',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
            ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Profil Bölümü
        Flexible(
          child: GestureDetector(
            onTap: () async {
              await Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfileScreenNew()));
              _refreshProfile();
              // Çerçeveyi de yeniden yükle
              final frame = await ShopService.instance.getSelectedCosmetic(CosmeticType.frame);
              if (mounted) {
                setState(() => _selectedFrameId = frame);
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildAvatarWithFrame(),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      _userProfile?.username ?? 'Player',
                      style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        
        // Davet Bildirimi - Animasyonlu Zil
        AnimatedBuilder(
          animation: _bellShakeAnim,
          builder: (context, child) => Transform.rotate(
            angle: _bellShakeAnim.value,
            child: child,
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                onPressed: () {
                  // Bildirim sayısını sıfırla
                  setState(() {
                    _pendingInvitationsCount = 0;
                  });
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const FriendsScreen()));
                },
                icon: const Icon(Icons.notifications_active_rounded, color: Colors.white, size: 28),
              ),
              if (_pendingInvitationsCount > 0)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.redAccent,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                    child: Text(
                      '$_pendingInvitationsCount',
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        ),

        // Coin Göstergesi - Animasyonlu
        AnimatedBuilder(
          animation: _coinScaleAnim,
          builder: (context, child) => Transform.scale(
            scale: _coinScaleAnim.value,
            child: child,
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFFFD700).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: const Color(0xFFFFD700).withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Text('🪙', style: TextStyle(fontSize: 16)),
                const SizedBox(width: 6),
                Text(
                  '$_coins',
                  style: const TextStyle(color: Color(0xFFFFD700), fontWeight: FontWeight.w900, fontSize: 16),
                ),
                const SizedBox(width: 8),
                // Market coin sayfasına git butonu
                GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ShopScreen(initialTabIndex: 2)),
                  ).then((_) => _refreshCoins(animate: true)),
                  child: const Icon(Icons.add_circle_outline, color: Color(0xFFFFD700), size: 20),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildVibrantButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    Color textColor = Colors.white,
    int badgeCount = 0,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color, color.withValues(alpha: 0.8)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.4),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 5,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: textColor, size: 28),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: TextStyle(color: textColor, fontWeight: FontWeight.w900, fontSize: 17, letterSpacing: 0.5),
                ),
              ],
            ),
            if (badgeCount > 0)
              Positioned(
                top: -10,
                right: 10,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)],
                  ),
                  child: Text(
                    '$badgeCount',
                    style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ignore: unused_element - Icon button yapısı için saklanıyor
  Widget _buildIconButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    Color textColor = Colors.white,
    int badgeCount = 0,
  }) {
    return _MenuCard(
      title: label,
      subtitle: '',
      icon: '', // Kare/Kısa butonlar için bu alanı handle ediyoruz
      color: color,
      onTap: onTap,
      isSmall: true,
      customIcon: icon,
      textColor: textColor,
      badgeCount: badgeCount,
    );
  }

  // ignore: unused_element - Level info dialog için saklanıyor
  void _showLevelInfo(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF2E5A8C), Color(0xFF1A3A5C)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Seviye Bilgisi',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            _buildLevelRow(UserLevel.a1, 'Temel kelimeler'),
            _buildLevelRow(UserLevel.a2, 'Günlük kelimeler'),
            _buildLevelRow(UserLevel.b1, 'Orta düzey'),
            _buildLevelRow(UserLevel.b2, 'İleri düzey'),
            _buildLevelRow(UserLevel.c1, 'Akademik'),
            _buildLevelRow(UserLevel.c2, 'Uzman'),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  Navigator.pop(context);
                  // Seviye seçim ekranına git
                  await UserProfileService.instance.resetAll();
                  if (mounted) {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (context) => const LevelSelectionScreen()),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Seviyemi Değiştir',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Widget _buildLevelRow(UserLevel level, String description) {
    final isCurrentLevel = _userProfile?.level == level;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isCurrentLevel 
            ? _getLevelColor(level).withValues(alpha: 0.2)
            : Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: isCurrentLevel
            ? Border.all(color: _getLevelColor(level), width: 2)
            : null,
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            padding: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(
              color: _getLevelColor(level),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              level.code,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            level.turkishName,
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: isCurrentLevel ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          const Spacer(),
          Text(
            description,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 14,
            ),
          ),
          if (isCurrentLevel) ...[
            const SizedBox(width: 8),
            const Icon(Icons.check_circle, color: Colors.green, size: 20),
          ],
        ],
      ),
    );
  }

  Color _getLevelColor(UserLevel level) {
    switch (level) {
      case UserLevel.a1:
        return Colors.green;
      case UserLevel.a2:
        return Colors.lightGreen;
      case UserLevel.b1:
        return Colors.yellow.shade700;
      case UserLevel.b2:
        return Colors.orange;
      case UserLevel.c1:
        return Colors.deepOrange;
      case UserLevel.c2:
        return Colors.red;
    }
  }
}

// Modern, 3D Kart Widget'ı
class _MenuCard extends StatefulWidget {
  final String title;
  final String subtitle;
  final String icon;
  final Color color;
  final VoidCallback onTap;
  final bool isLocked;
  final bool isSmall;
  final IconData? customIcon;
  final Color textColor;
  final bool useGradient;
  final VoidCallback? onInfoTap;

  const _MenuCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
    this.isLocked = false,
    this.isSmall = false,
    this.customIcon,
    this.textColor = Colors.white,
    this.badgeCount = 0,
    this.useGradient = true,
    this.onInfoTap,
  });

  final int badgeCount;

  @override
  State<_MenuCard> createState() => _MenuCardState();
}

class _MenuCardState extends State<_MenuCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.isLocked ? null : widget.onTap,
      child: AnimatedScale(
        scale: _isPressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          padding: EdgeInsets.all(widget.isSmall ? 16 : 20),
          decoration: BoxDecoration(
            gradient: (widget.isLocked || !widget.useGradient)
              ? null 
              : LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color.alphaBlend(Colors.white.withValues(alpha: 0.15), widget.color),
                    widget.color,
                  ],
                ),
            color: widget.isLocked ? Colors.grey.shade900 : (widget.useGradient ? null : widget.color),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.1),
              width: 1,
            ),
            boxShadow: [
              // 3D Gölge Efekti
              BoxShadow(
                color: (widget.isLocked ? Colors.black : widget.color).withValues(alpha: 0.35),
                offset: const Offset(0, 8),
                blurRadius: 16,
                spreadRadius: -4,
              ),
            ],
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              widget.isSmall ? _buildSmallContent() : _buildLargeContent(),
              if (widget.badgeCount > 0)
                Positioned(
                  top: -8,
                  right: -8,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                    child: Text(
                      '${widget.badgeCount}',
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLargeContent() {
    return Row(
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(18),
          ),
          alignment: Alignment.center,
          child: widget.isLocked 
            ? const Text('🔒', style: TextStyle(fontSize: 32))
            : widget.icon.startsWith('assets/')
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.asset(widget.icon, fit: BoxFit.cover, width: 44, height: 44),
                  )
                : Text(widget.icon, style: const TextStyle(fontSize: 32)),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.title,
                style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 4),
              Text(
                widget.subtitle,
                style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13),
              ),
            ],
          ),
        ),
        if (widget.onInfoTap != null)
          GestureDetector(
            onTap: widget.onInfoTap,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.info_outline, color: Colors.white70, size: 20),
            ),
          )
        else
          const Icon(Icons.chevron_right_rounded, color: Colors.white54),
      ],
    );
  }

  Widget _buildSmallContent() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(widget.customIcon, color: widget.textColor, size: 20),
        const SizedBox(width: 8),
        Text(
          widget.title,
          style: TextStyle(color: widget.textColor, fontSize: 15, fontWeight: FontWeight.w800),
        ),
      ],
    );
  }
}
