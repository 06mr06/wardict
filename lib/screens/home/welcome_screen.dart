import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/practice_provider.dart';
import 'dart:async';
import 'dart:math' as math;
import '../../models/user_level.dart';
import '../../models/premium.dart';
import '../../models/quest.dart';
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
import '../leaderboard/leaderboard_screen.dart';
import '../../widgets/common/daily_reward_dialog.dart'; // Added import
import '../../widgets/common/daily_quest_dialog.dart';

import '../game/daily_123_intro_screen.dart';
import '../game/daily_123_results_screen.dart';
import '../game/matchmaking_screen.dart';
import '../onboarding/intro_video_screen.dart';
import '../onboarding/tutorial_screen.dart';
import '../../services/online_duel_service.dart';
import '../../services/weekly_practice_points_service.dart';
import '../../models/online_duel.dart';
import '../game/online_duel_screen.dart';
import 'widgets/home_sheets.dart';
import '../../providers/language_provider.dart';

/// Alt gezinme: yan kareler ve orta pill aynı toplam yükseklik / hizada.
const double _kBottomNavBoxSize = 72;
const double _kBottomNavLabelGap = 6;
const double _kBottomNavLabelHeight = 16;

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
  StreamSubscription<DuelInvitation>? _invitationStreamSub;

  bool _isLoading = true;
  // ignore: unused_field - Test tamamlama durumu için saklanıyor
  final bool _hasCompletedTest = false;
  UserProfile? _userProfile;
  int _coins = 0;
  int _pendingInvitationsCount = 0;
  // ignore: unused_field - Premium durumu için saklanıyor
  bool _isPremium = false;
  String? _selectedFrameId;

  @override
  void initState() {
    super.initState();
    WeeklyPracticePointsService.instance.refreshNotifier();
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
      _invitationStreamSub = OnlineDuelService.instance.onInvitationReceived.listen((invitation) {
        if (mounted) {
          _showInvitationDialog(invitation);
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
    // Uygulama ön plana geldiğinde coin ve seri (profil) güncelle
    if (state == AppLifecycleState.resumed) {
      _refreshCoins();
      unawaited(_refreshProfile());
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

  void _showInvitationDialog(DuelInvitation invitation) {
    final lang = context.read<LanguageProvider>();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2E5A8C),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          lang.getString('duel_invitation_title'),
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          lang.format('duel_invitation_message', {
            'username': invitation.fromUser.username,
            'leagueCode': invitation.leagueCode,
          }),
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(lang.getString('decline'), style: const TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () async {
              // Context'i kaydet (dialog kapanmadan önce)
              final navigator = Navigator.of(context);
              final scaffoldMessenger = ScaffoldMessenger.of(context);
              
              // Dialog'u kapat
              navigator.pop();
              
              // Maça katıl
              final joinedMatch = await OnlineDuelService.instance.acceptDuelInvitationAndGetMatch(invitation);
              
              if (joinedMatch != null && mounted) {
                // Root navigator kullan (daha güvenli)
                Navigator.of(this.context).push(
                  MaterialPageRoute(
                    builder: (context) => OnlineDuelScreen(match: joinedMatch),
                  ),
                );
              } else if (mounted) {
                scaffoldMessenger.showSnackBar(
                  SnackBar(content: Text(lang.getString('match_join_failed_snackbar'))),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(lang.getString('accept'), style: const TextStyle(color: Colors.white)),
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
    await UserProfileService.instance.fetchProfileFromFirestore();
    profile = await UserProfileService.instance.loadProfile();
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
    
    // Günlük bonus (profilde dailyStreak ve coin güncellenir)
    final dailyResult = await ShopService.instance.claimDailyBonus();
    profile = await UserProfileService.instance.loadProfile();

    final coins = await ShopService.instance.getCoins();
    final invitations = await FriendService.instance.getDuelInvitations();
    
    // Premium durumu kontrol et
    final subscription = await ShopService.instance.getSubscription();
    final isPremium = subscription.tier != PremiumTier.free;
    
    // Seçili çerçeveyi yükle
    final selectedFrame = await ShopService.instance.getSelectedCosmetic(CosmeticType.frame);

    if (!mounted) return;
    // Practice provider'ı profile'dan güncelle
    final practiceProvider = Provider.of<PracticeProvider>(context, listen: false);
    await practiceProvider.loadSessionFromProfile();
    
    if (mounted) {
      setState(() {
        _userProfile = profile;
        _coins = coins;
        _pendingInvitationsCount = invitations.length;
        _isPremium = isPremium;
        _selectedFrameId = selectedFrame;
        _isLoading = false;
      });
      
      final homeContext = context;
      // İlk girişte: intro videosu, ardından tutorial
      final shouldShowTutorial = await TutorialScreen.shouldShowTutorial();
      if (!mounted) return;
      if (shouldShowTutorial && mounted) {
        await Navigator.of(homeContext).push(
          MaterialPageRoute<void>(
            fullscreenDialog: true,
            builder: (introContext) => IntroVideoScreen(
              onComplete: () => Navigator.of(introContext).pop(),
            ),
          ),
        );
        if (!mounted) return;
        await Navigator.of(homeContext).push(
          MaterialPageRoute(
            builder: (tutorialContext) => TutorialScreen(
              onComplete: () async {
                Navigator.of(tutorialContext).pop();
                if (!mounted) return;
                // Tutorial bitince hoşgeldin (görsel diyalog; ödüller _loadUserData'da verildi)
                if (isNewUser) {
                  await DailyRewardDialog.showWelcomeGiftVisual(homeContext);
                } else if (dailyResult['coins'] as int > 0) {
                  await _showDailyBonusDialog(dailyResult);
                }
                if (!mounted) return;
                Navigator.of(homeContext).pushReplacementNamed('/7030');
              },
            ),
          ),
        );
      } else {
        // Tutorial gösterilmediyse normal şekilde dialog'ları göster
        if (isNewUser) {
          await DailyRewardDialog.showWelcomeGiftVisual(homeContext);
        } else if (dailyResult['coins'] as int > 0) {
          await _showDailyBonusDialog(dailyResult);
        }
      }
    }
    
    // Her şey yüklendikten sonra profili sync et (artık Auth ID var)
    await UserProfileService.instance.syncProfileToFirestore();
  }

  Future<void> _showDailyBonusDialog(Map<String, dynamic> result) async {
    final coins = result['coins'] as int;
    final streak = result['streak'] as int;
    final rewards = result['rewards'] as List<String>;
    final lang = context.read<LanguageProvider>();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2E5A8C),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Text('🔥', style: TextStyle(fontSize: 28)),
            const SizedBox(width: 10),
            Text(
              lang.format('daily_bonus_streak', {'streak': '$streak'}),
              style: const TextStyle(color: Colors.white, fontSize: 20),
            ),
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
                    lang.format('coins_added', {'coins': '$coins'}),
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
            child: Text(lang.getString('continue_btn'), style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _refreshProfile() async {
    final profile = await UserProfileService.instance.loadProfile();
    final frame = await ShopService.instance.getSelectedCosmetic(CosmeticType.frame);
    if (mounted) {
      setState(() {
        _userProfile = profile;
        _selectedFrameId = frame;
      });
    }
  }

  /// Mağazadan dönünce avatar/çerçeve ve coin ana ekranda güncellensin
  Future<void> _refreshAfterShopVisit() async {
    await _refreshProfile();
    await _refreshCoins(animate: true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pulseController.dispose();
    _coinAnimController.dispose();
    _bellAnimController.dispose();
    _invitationTimer?.cancel();
    _invitationStreamSub?.cancel();
    super.dispose();
  }

  // ignore: unused_element - İleride duel kartı info ile bağlanabilir
  void _showDuelInfo() {
    final lang = context.read<LanguageProvider>();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2E5A8C),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Text('⚔️', style: TextStyle(fontSize: 28)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                lang.getString('duel_mode'),
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildInfoSection(lang.getString('ws_duel_how_title'), lang.getString('ws_duel_how_body')),
              const SizedBox(height: 16),
              _buildInfoSection(lang.getString('ws_duel_lp_title'), lang.getString('ws_duel_lp_body')),
              const SizedBox(height: 16),
              _buildInfoSection(lang.getString('ws_duel_modes_title'), lang.getString('ws_duel_modes_body')),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8FB6D9)),
            child: Text(lang.getString('info_got_it'), style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showPracticeInfo() {
    final lang = context.read<LanguageProvider>();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2E5A8C),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Text('📚', style: TextStyle(fontSize: 28)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                lang.getString('ws_practice_dialog_title'),
                style: const TextStyle(color: Colors.white, fontSize: 20),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildInfoSection(lang.getString('ws_practice_how_title'), lang.getString('ws_practice_how_body')),
              const SizedBox(height: 16),
              _buildInfoSection(lang.getString('ws_practice_level_title'), lang.getString('ws_practice_level_body')),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF26A69A)),
            child: Text(lang.getString('info_got_it'), style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  /// Bugün oynanmışsa tam sonuç ekranı; değilse intro animasyonu.
  Future<void> _navigateDaily123() async {
    final latest = await Daily123Service.instance.getLatestResultForToday();
    if (!mounted) return;
    if (latest != null) {
      final cached = await Daily123Service.instance.loadCachedAnswersForToday();
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => Daily123ResultsScreen(
            finalScore: latest.score,
            timeSpent: latest.timeSeconds,
            isWin: latest.isWin,
            correctAnswers: cached.$1,
            wrongAnswers: cached.$2,
          ),
        ),
      );
    } else {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const Daily123IntroScreen()),
      );
    }
    if (mounted) _loadUserData();
  }

  void _showDaily123Info() {
    final lang = context.read<LanguageProvider>();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2E5A8C),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Text('🎲', style: TextStyle(fontSize: 28)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                lang.getString('daily_123'),
                style: const TextStyle(color: Colors.white, fontSize: 20),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildInfoSection(lang.getString('ws_daily_how_title'), lang.getString('ws_daily_how_body')),
              const SizedBox(height: 16),
              _buildInfoSection(lang.getString('ws_daily_score_title'), lang.getString('ws_daily_score_body')),
              const SizedBox(height: 16),
              _buildInfoSection(lang.getString('ws_daily_important_title'), lang.getString('ws_daily_important_body')),
              const SizedBox(height: 16),
              _buildInfoSection(lang.getString('ws_daily_reset_title'), lang.getString('ws_daily_reset_body')),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF8A65)),
            child: Text(lang.getString('info_got_it'), style: const TextStyle(color: Colors.white)),
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

  /// Kelime paketi seçim alt sayfası → Practice (/7030).
  Future<void> _openPracticePackSelection() async {
    final unlocked = await ShopService.instance.getUnlockedPacks();
    if (!mounted) return;
    final duelLevel = _userProfile?.level.code ?? 'A2';
    final practiceLevel =
        Provider.of<PracticeProvider>(context, listen: false).currentLevel;
    HomeSheets.showCategorySelection(
      context: context,
      unlockedPacks: unlocked,
      userLevel: duelLevel,
      practiceLevelCode: practiceLevel,
      onUserDataRefresh: _loadUserData,
    );
  }

  /// Lugo (online) / Arkadaş / Bot alt menüsü.
  void _openDuelSelection() {
    final userProfile = _userProfile;
    if (userProfile == null) return;
    final league = userProfile.level.code;
    HomeSheets.showDuelSelectionDialog(
      context: context,
      onLugoDuel: () {
        Navigator.of(context).pop();
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => MatchmakingScreen(
              leagueCode: league,
              isBot: false,
            ),
          ),
        );
      },
      onBotDuel: () {
        Navigator.of(context).pop();
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => MatchmakingScreen(
              leagueCode: league,
              isBot: true,
            ),
          ),
        );
      },
      onUserDataRefresh: _loadUserData,
    );
  }

  // ignore: unused_element - Premium dialog için saklanıyor
  void _showPremiumRequiredDialog() {
    final lang = context.read<LanguageProvider>();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2E5A8C),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Text('👑', style: TextStyle(fontSize: 28)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                lang.getString('premium_required_title'),
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              lang.getString('premium_required_body'),
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    lang.getString('premium_benefits'),
                    style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(lang.getString('benefit_maxigame'), style: const TextStyle(color: Colors.white70)),
                  Text(lang.getString('benefit_friends'), style: const TextStyle(color: Colors.white70)),
                  Text(lang.getString('benefit_cosmetics'), style: const TextStyle(color: Colors.white70)),
                  Text(lang.getString('benefit_ads'), style: const TextStyle(color: Colors.white70)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(lang.getString('later'), style: const TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pushNamed(context, '/shop').then((_) => _refreshAfterShopVisit());
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFD700),
            ),
            child: Text(lang.getString('go_premium'), style: const TextStyle(color: Colors.black87)),
          ),
        ],
      ),
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

    // Kök uygulama [app.dart] PracticeProvider kullan; ikinci instance
    // /7030 ile çakışıp boş oturum / sonsuz yüklenme yaratıyordu.
    return _buildMainScreen();
  }


  Widget _buildMainScreen() {
    final practiceProvider = Provider.of<PracticeProvider>(context, listen: true);
    final lang = context.watch<LanguageProvider>();
    final duelUnlocked = practiceProvider.duelUnlocked;
    final sessionsInRow = practiceProvider.sessionsInRow;
    const placementTarget = 3;
    final hasCompletedPlacement = duelUnlocked || sessionsInRow >= placementTarget;
    final progressText = hasCompletedPlacement
        ? lang.getString('continue_practice')
        : lang.format('level_test_progress_label', {
            'current': '$sessionsInRow',
            'total': '$placementTarget',
          });
    final duelSubtitle = hasCompletedPlacement
        ? lang.getString('duel_desc')
        : lang.format('level_test_progress_label', {
            'current': '$sessionsInRow',
            'total': '$placementTarget',
          });
    final levelCode = _userProfile?.level.code ?? 'A2';
    final practiceLevelCode = practiceProvider.currentLevel;

    return Scaffold(
      backgroundColor: const Color(0xFF102A57),
      body: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF193F78), Color(0xFF122B57), Color(0xFF0C1F43)],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: CustomPaint(painter: _HomeStarfieldPainter()),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0, -0.2),
                    radius: 0.58,
                    colors: [
                      const Color(0xFF4D8DDF).withValues(alpha: 0.55),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 24),
                  child: Column(
                    children: [
                      _buildTopBar(),
                      const SizedBox(height: 28),
                      ValueListenableBuilder<int>(
                        valueListenable:
                            WeeklyPracticePointsService.instance.pointsNotifier,
                        builder: (context, weeklyPts, _) {
                          const cap = WeeklyPracticePointsService.displayMax;
                          return _HomeShowcaseCard(
                            title: lang.getString('home_showcase_practice'),
                            subtitle: progressText,
                            badgeText: practiceLevelCode,
                            badgeTrailing: _WeeklyPracticeScoreBox(
                              points: weeklyPts,
                              cap: cap,
                            ),
                            imagePath: 'assets/images/menu_practice.jpg',
                            fallbackIcon: Icons.menu_book_rounded,
                            accentColor: const Color(0xFF53D5D1),
                            backgroundColors: const [
                              Color(0xFF1C9EB5),
                              Color(0xFF0C4878),
                            ],
                            imageSide: _CardImageSide.left,
                            onTap: _openPracticePackSelection,
                            onInfoTap: _showPracticeInfo,
                          );
                        },
                      ),
                      const SizedBox(height: 18),
                      _HomeShowcaseCard(
                        title: lang.getString('home_showcase_duel'),
                        subtitle: duelSubtitle,
                        badgeText: levelCode,
                        imagePath: 'assets/images/menu_duel.jpg',
                        fallbackIcon: Icons.sports_kabaddi_rounded,
                        accentColor: const Color(0xFF90AFFF),
                        backgroundColors: const [Color(0xFF1D2E7E), Color(0xFF121D59)],
                        imageSide: _CardImageSide.right,
                        imageWidth: 0.44,
                        imageContentScale: 0.84,
                        isLocked: !duelUnlocked,
                        onTap: duelUnlocked
                            ? _openDuelSelection
                            : () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(lang.getString('duel_locked_message')),
                                    duration: const Duration(seconds: 3),
                                  ),
                                );
                              },
                        onInfoTap: _showDuelInfo,
                      ),
                      const SizedBox(height: 18),
                      _HomeShowcaseCard(
                        title: lang.getString('home_showcase_daily'),
                        subtitle: lang.getString('daily_123_subtitle'),
                        imagePath: 'assets/images/menu_daily123.jpg',
                        fallbackIcon: Icons.emoji_events_rounded,
                        accentColor: const Color(0xFFFFB254),
                        backgroundColors: const [Color(0xFFE57E12), Color(0xFF8F4307)],
                        imageSide: _CardImageSide.left,
                        imageWidth: 0.62,
                        imageContentScale: 0.84,
                        imageAlignment: const Alignment(0, 0.16),
                        onTap: _navigateDaily123,
                        onInfoTap: _showDaily123Info,
                      ),
                      const SizedBox(height: 128),
                      _buildBottomNavigation(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Daire içini tam doldurur: kare görseller [BoxFit.cover] ile kırpılır, boşluk kalmaz.
  Widget _buildHomeAvatarFill() {
    const placeholder = Color(0xFF2E5A8C);
    final avatarId = _userProfile?.avatarId;
    if (avatarId == null || avatarId.isEmpty) {
      return ColoredBox(
        color: placeholder,
        child: Center(
          child: Text(
            (_userProfile?.username.isNotEmpty == true)
                ? _userProfile!.username[0].toUpperCase()
                : 'P',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ),
      );
    }

    String? assetPath;
    if (avatarId.startsWith('assets/')) {
      assetPath = avatarId;
    } else {
      final match =
          CosmeticItem.availableItems.where((i) => i.id == avatarId).toList();
      if (match.isNotEmpty) {
        final preview = match.first.previewValue;
        if (preview.startsWith('assets/')) assetPath = preview;
      }
    }

    if (assetPath != null) {
      return Stack(
        fit: StackFit.expand,
        children: [
          const ColoredBox(color: placeholder),
          Image.asset(
            assetPath,
            fit: BoxFit.cover,
            alignment: Alignment.center,
            filterQuality: FilterQuality.medium,
            errorBuilder: (_, __, ___) => const Center(
              child: Text('👤', style: TextStyle(fontSize: 18)),
            ),
          ),
        ],
      );
    }

    final match =
        CosmeticItem.availableItems.where((i) => i.id == avatarId).toList();
    if (match.isEmpty) {
      return const ColoredBox(
        color: placeholder,
        child: Center(child: Text('👤', style: TextStyle(fontSize: 18))),
      );
    }

    final preview = match.first.previewValue;
    return ColoredBox(
      color: placeholder,
      child: Center(
        child: Text(preview, style: const TextStyle(fontSize: 18)),
      ),
    );
  }

  /// Ana sayfada çerçeveli avatar — görsel dış daireyi [diameter] ile tam doldurur.
  Widget _buildAvatarWithFrame(double diameter) {
    Color? frameColor;
    double frameBorderWidth = 0;
    bool isGradientFrame = false;

    if (_selectedFrameId != null && _selectedFrameId!.isNotEmpty) {
      final frames = CosmeticItem.availableItems.where((i) => i.id == _selectedFrameId);
      if (frames.isNotEmpty) {
        final frame = frames.first;
        if (frame.previewValue == 'gradient') {
          isGradientFrame = true;
          frameBorderWidth = frame.borderWidth.toDouble();
        } else {
          try {
            final hexValue = frame.previewValue.replaceAll('#', '');
            if (RegExp(r'^[0-9A-Fa-f]{6}$').hasMatch(hexValue)) {
              frameColor = Color(int.parse('FF$hexValue', radix: 16));
            }
          } catch (_) {}
          frameBorderWidth = frame.borderWidth.toDouble();
        }
      }
    }

    final fill = SizedBox(
      width: diameter,
      height: diameter,
      child: ClipOval(
        child: SizedBox.expand(
          child: _buildHomeAvatarFill(),
        ),
      ),
    );

    if (isGradientFrame && frameBorderWidth > 0) {
      return SizedBox(
        width: diameter,
        height: diameter,
        child: Container(
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: SweepGradient(
              colors: [
                Color(0xFFFF0044),
                Color(0xFFFF8C00),
                Color(0xFFFFD600),
                Color(0xFF00E676),
                Color(0xFF00B0FF),
                Color(0xFF7C4DFF),
                Color(0xFFFF0044),
              ],
            ),
          ),
          padding: EdgeInsets.all(frameBorderWidth),
          child: ClipOval(
            child: SizedBox.expand(
              child: _buildHomeAvatarFill(),
            ),
          ),
        ),
      );
    }

    if (frameColor != null && frameBorderWidth > 0) {
      return SizedBox(
        width: diameter,
        height: diameter,
        child: Stack(
          fit: StackFit.expand,
          children: [
            fill,
            IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: frameColor, width: frameBorderWidth),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return fill;
  }

  Widget _buildTopBar() {
    final lang = context.watch<LanguageProvider>();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        GestureDetector(
          onTap: () async {
            await Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfileScreenNew()));
            _refreshProfile();
            final frame = await ShopService.instance.getSelectedCosmetic(CosmeticType.frame);
            if (mounted) {
              setState(() => _selectedFrameId = frame);
            }
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withValues(alpha: 0.45), width: 1.5),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.28), blurRadius: 14, offset: const Offset(0, 6)),
                  ],
                ),
                child: ClipOval(
                  clipBehavior: Clip.antiAlias,
                  child: _buildAvatarWithFrame(70),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _userProfile?.username ?? 'Player',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  shadows: [Shadow(color: Colors.black45, blurRadius: 4, offset: Offset(0, 2))],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF10244C).withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Colors.white.withValues(alpha: 0.18), width: 1.2),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.22), blurRadius: 16, offset: const Offset(0, 6)),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('🔥', style: TextStyle(fontSize: 16)),
                      const SizedBox(width: 4),
                      Text(
                        '${_userProfile?.dailyStreak ?? 0}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: GestureDetector(
                    onTap: () => DailyQuestDialog.show(
                      context,
                      onRefresh: () => _refreshCoins(animate: true),
                      onNavigate: (QuestType type) {
                        switch (type) {
                          case QuestType.winDuels:
                          case QuestType.buddyDuel:
                            final duelUnlocked = context.read<PracticeProvider>().duelUnlocked;
                            if (duelUnlocked) {
                              _openDuelSelection();
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(lang.getString('duel_locked_message')),
                                  duration: const Duration(seconds: 3),
                                ),
                              );
                            }
                            break;
                          case QuestType.daily123Play:
                            unawaited(_navigateDaily123());
                            break;
                          case QuestType.buyItem:
                          case QuestType.usePowerup:
                          case QuestType.equipItem:
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const ShopScreen(initialTabIndex: 0)),
                            ).then((_) => _refreshAfterShopVisit());
                            break;
                          default:
                            unawaited(_openPracticePackSelection());
                            break;
                        }
                      },
                    ),
                    child: Container(
                      height: 42,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFF6CCB17), Color(0xFF2F8D0B)]),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFA9F55D), width: 1.4),
                        boxShadow: [
                          BoxShadow(color: const Color(0xFF88E230).withValues(alpha: 0.24), blurRadius: 10),
                        ],
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Padding(
                                padding: const EdgeInsets.only(left: 10),
                                child: Text(
                                  context.watch<LanguageProvider>().getString('home_quest_pill'),
                                  maxLines: 1,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.check_rounded, color: Color(0xFFD8FF89), size: 18),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                AnimatedBuilder(
                  animation: _bellShakeAnim,
                  builder: (context, child) => Transform.rotate(angle: _bellShakeAnim.value, child: child),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      _TopCapsuleIconButton(
                        icon: Icons.notifications_none_rounded,
                        onTap: () {
                          setState(() {
                            _pendingInvitationsCount = 0;
                          });
                          Navigator.push(context, MaterialPageRoute(builder: (context) => const FriendsScreen()));
                        },
                      ),
                      if (_pendingInvitationsCount > 0)
                        Positioned(
                          top: -4,
                          right: -4,
                          child: Container(
                            width: 20,
                            height: 20,
                            decoration: const BoxDecoration(color: Color(0xFFF36C2E), shape: BoxShape.circle),
                            alignment: Alignment.center,
                            child: Text(
                              '$_pendingInvitationsCount',
                              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                AnimatedBuilder(
                  animation: _coinScaleAnim,
                  builder: (context, child) => Transform.scale(scale: _coinScaleAnim.value, child: child),
                  child: GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const ShopScreen(initialTabIndex: 2)),
                    ).then((_) => _refreshAfterShopVisit()),
                    child: Container(
                      height: 42,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0C1D3D),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.monetization_on_rounded, color: Color(0xFFFFC83D), size: 22),
                          const SizedBox(width: 8),
                          Text(
                            '$_coins',
                            style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomNavigation() {
    final lang = context.watch<LanguageProvider>();
    final myWordsLabel = lang.getString('my_words').toUpperCase();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _BottomNavSquareButton(
          icon: Icons.storefront_rounded,
          label: lang.getString('shop'),
          onTap: () => Navigator.pushNamed(context, '/shop').then((_) => _refreshAfterShopVisit()),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: _BottomNavPillButton(
            icon: Icons.edit_note_rounded,
            label: myWordsLabel,
            badgeCount: 0,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SavedPoolScreen())),
          ),
        ),
        const SizedBox(width: 14),
        _BottomNavSquareButton(
          icon: Icons.star_rounded,
          label: lang.getString('ranking'),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const LeaderboardScreen())),
        ),
      ],
    );
  }

  // ignore: unused_element - Eski menü varyantı; tekrar kullanılabilir
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

  String _levelRowDescription(UserLevel level, LanguageProvider lang) {
    switch (level) {
      case UserLevel.a1:
        return lang.getString('level_row_a1');
      case UserLevel.a2:
        return lang.getString('level_row_a2');
      case UserLevel.b1:
        return lang.getString('level_row_b1');
      case UserLevel.b2:
        return lang.getString('level_row_b2');
      case UserLevel.c1:
        return lang.getString('level_row_c1');
      case UserLevel.c2:
        return lang.getString('level_row_c2');
    }
  }

  // ignore: unused_element - Level info dialog için saklanıyor
  void _showLevelInfo(BuildContext context) {
    final lang = context.read<LanguageProvider>();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (modalContext) => Container(
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
            Text(
              lang.getString('level_info_title'),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            _buildLevelRow(UserLevel.a1, lang),
            _buildLevelRow(UserLevel.a2, lang),
            _buildLevelRow(UserLevel.b1, lang),
            _buildLevelRow(UserLevel.b2, lang),
            _buildLevelRow(UserLevel.c1, lang),
            _buildLevelRow(UserLevel.c2, lang),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  final rootContext = context;
                  Navigator.pop(modalContext);
                  await UserProfileService.instance.resetAll();
                  if (!rootContext.mounted) return;
                  Navigator.pushReplacement(
                    rootContext,
                    MaterialPageRoute(builder: (context) => const LevelSelectionScreen()),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  lang.getString('level_change_button'),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Widget _buildLevelRow(UserLevel level, LanguageProvider lang) {
    final description = _levelRowDescription(level, lang);
    final levelName =
        lang.currentLanguage == 'en' ? level.englishName : level.turkishName;
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
            levelName,
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
  final bool isSmall;
  final IconData? customIcon;
  final Color textColor;

  const _MenuCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
    this.isSmall = false,
    this.customIcon,
    this.textColor = Colors.white,
    this.badgeCount = 0,
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
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _isPressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          padding: EdgeInsets.all(widget.isSmall ? 16 : 20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color.alphaBlend(Colors.white.withValues(alpha: 0.15), widget.color),
                widget.color,
              ],
            ),
            color: null,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.1),
              width: 1,
            ),
            boxShadow: [
              // 3D Gölge Efekti
              BoxShadow(
                color: widget.color.withValues(alpha: 0.35),
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
          child: widget.icon.startsWith('assets/')
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

enum _CardImageSide { left, right }

/// Ana menü vitrin kartları — tüm köşe yarıçapları bu değerle (clip uyumu).
const double _kShowcaseCardRadius = 28;

/// Seviye rozeti (yeşil) ile aynı satırda; turkuaz zemin, beyaz yazı.
class _WeeklyPracticeScoreBox extends StatelessWidget {
  final int points;
  final int cap;

  const _WeeklyPracticeScoreBox({
    required this.points,
    required this.cap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2AB7C8), Color(0xFF1780A0)],
        ),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.85),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        '$points/$cap',
        style: GoogleFonts.firaCode(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: 12,
          height: 1.1,
        ),
      ),
    );
  }
}

class _HomeShowcaseCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String? badgeText;
  final Widget? badgeTrailing;
  final String imagePath;
  final IconData fallbackIcon;
  final List<Color> backgroundColors;
  final Color accentColor;
  final _CardImageSide imageSide;
  final double imageWidth;
  final bool isLocked;
  final VoidCallback onTap;
  final VoidCallback? onInfoTap;
  /// Kapak görselinin [BoxFit.cover] hizası; null ise sol/sağ panele göre merkezlenir.
  final Alignment? imageAlignment;

  /// 1.0 = düz cover. 0.94 gibi: gerçek zoom out (bitmap’te daha fazla alan görünür) — slot boyutu değişmez,
  /// kenarda boşluk olmaz; içeride [SizedBox] w/s,h/s + [Transform.scale](s) ile dengelenir.
  final double imageContentScale;

  const _HomeShowcaseCard({
    required this.title,
    required this.subtitle,
    this.badgeText,
    this.badgeTrailing,
    required this.imagePath,
    required this.fallbackIcon,
    required this.backgroundColors,
    required this.accentColor,
    required this.imageSide,
    required this.onTap,
    this.onInfoTap,
    this.imageWidth = 0.5,
    this.isLocked = false,
    this.imageAlignment,
    this.imageContentScale = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxW = constraints.maxWidth;
        final isNarrow = maxW < 420;
        // Dar ekranda kapak görselini daralt; başlık / alt başlık için alan aç
        final effImageWidth = isNarrow ? math.min(imageWidth, 0.44) : imageWidth;
        final imagePaneWidth = maxW * effImageWidth;
        // Görseli metne hafif bindir; asıl yumuşak geçiş dar tutuldu (karakterler uzun soluk alanda kaybolmasın).
        const seamOverlap = 12.0;
        final imageSlotW = imagePaneWidth + seamOverlap;

        Widget buildPhoto() {
          final alignment = imageAlignment ??
              (imageSide == _CardImageSide.right
                  ? Alignment.centerRight
                  : Alignment.centerLeft);

          Widget imageLayer(BoxConstraints c) {
            final w = c.maxWidth;
            final h = c.maxHeight;
            final img = Image.asset(
              imagePath,
              fit: BoxFit.cover,
              alignment: alignment,
              filterQuality: FilterQuality.medium,
              errorBuilder: (context, error, stackTrace) => ColoredBox(
                color: Colors.white.withValues(alpha: 0.08),
                child: Center(
                  child: Icon(fallbackIcon, color: Colors.white70, size: 42),
                ),
              ),
            );
            final s = imageContentScale;
            if (s < 1.0 && s > 0.5) {
              // Zoom out: daha büyük sanal tuval + scale(s) → çizilen alan w×h; kenarda boşluk yok.
              // OverflowBox ile sıkı (tight) parent constraintlerini eziyoruz ki w/s gerçekten w/s olabilsin.
              return ClipRect(
                child: OverflowBox(
                  minWidth: w / s,
                  maxWidth: w / s,
                  minHeight: h / s,
                  maxHeight: h / s,
                  child: Transform.scale(
                    scale: s,
                    alignment: Alignment.center,
                    child: SizedBox(
                      width: w / s,
                      height: h / s,
                      child: img,
                    ),
                  ),
                ),
              );
            }
            return img;
          }

          return LayoutBuilder(
            builder: (context, constraints) {
              final layered = imageLayer(constraints);
              return ShaderMask(
                blendMode: BlendMode.dstIn,
                shaderCallback: (Rect bounds) {
                  if (imageSide == _CardImageSide.left) {
                    return const LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        Color(0xFFFFFFFF),
                        Color(0xFFFFFFFF),
                        Color(0xCCFFFFFF),
                        Color(0x66FFFFFF),
                        Color(0x00FFFFFF),
                        Color(0x00FFFFFF),
                      ],
                      stops: [0.0, 0.50, 0.75, 0.90, 0.98, 1.0],
                    ).createShader(bounds);
                  }
                  return const LinearGradient(
                    begin: Alignment.centerRight,
                    end: Alignment.centerLeft,
                    colors: [
                      Color(0xFFFFFFFF),
                      Color(0xFFFFFFFF),
                      Color(0xCCFFFFFF),
                      Color(0x66FFFFFF),
                      Color(0x00FFFFFF),
                      Color(0x00FFFFFF),
                    ],
                    stops: [0.0, 0.50, 0.75, 0.90, 0.98, 1.0],
                  ).createShader(bounds);
                },
                child: layered,
              );
            },
          );
        }

        final image = Stack(
          fit: StackFit.expand,
          children: [
            buildPhoto(),
            if (isLocked)
              Positioned.fill(
                child: ColoredBox(
                  color: Colors.black.withValues(alpha: 0.4),
                  child: const Center(
                    child: Icon(Icons.lock_rounded, color: Colors.white70, size: 34),
                  ),
                ),
              ),
          ],
        );

        final textBlock = Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: isNarrow ? 19 : 24,
                      fontWeight: FontWeight.w900,
                      height: 1.05,
                      shadows: const [
                        Shadow(color: Colors.black38, blurRadius: 5, offset: Offset(0, 2)),
                      ],
                    ),
                  ),
                ),
                if (onInfoTap != null) ...[
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: onInfoTap,
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.15),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                      ),
                      alignment: Alignment.center,
                      child: const Icon(Icons.info_outline, color: Colors.white, size: 16),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              maxLines: isNarrow ? 3 : 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.88),
                fontSize: isNarrow ? 12.5 : 14,
                fontWeight: FontWeight.w500,
                height: 1.25,
              ),
            ),
            if (badgeText != null || badgeTrailing != null) ...[
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (badgeText != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF66D143), Color(0xFF2D8A1F)],
                        ),
                        borderRadius: BorderRadius.circular(7),
                        border: Border.all(color: const Color(0xFFA8F46E), width: 1),
                      ),
                      child: Text(
                        badgeText!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  if (badgeText != null && badgeTrailing != null)
                    const SizedBox(width: 8),
                  if (badgeTrailing != null) badgeTrailing!,
                ],
              ),
            ],
          ],
        );

        return GestureDetector(
          onTap: onTap,
          child: Container(
            height: isNarrow ? 136 : 128,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: backgroundColors,
              ),
              borderRadius: BorderRadius.circular(_kShowcaseCardRadius),
              // Kontur çizgisi yok (referans tasarım); derinlik için gölge yeterli
              boxShadow: [
                BoxShadow(color: accentColor.withValues(alpha: 0.22), blurRadius: 20, offset: const Offset(0, 10)),
                BoxShadow(color: Colors.black.withValues(alpha: 0.22), blurRadius: 14, offset: const Offset(0, 5)),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(_kShowcaseCardRadius),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: backgroundColors,
                        ),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.white.withValues(alpha: 0.07),
                            Colors.transparent,
                            Colors.white.withValues(alpha: 0.03),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                    ),
                  ),
                  if (imageSide == _CardImageSide.left)
                    Positioned(
                      left: 0,
                      top: 0,
                      bottom: 0,
                      width: imageSlotW,
                      child: image,
                    ),
                  if (imageSide == _CardImageSide.right)
                    Positioned(
                      right: 0,
                      top: 0,
                      bottom: 0,
                      width: imageSlotW,
                      child: image,
                    ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      imageSide == _CardImageSide.left ? imagePaneWidth + 16 : 18,
                      14,
                      imageSide == _CardImageSide.right
                          ? imagePaneWidth + 18
                          : 22,
                      14,
                    ),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: SizedBox(
                        width: double.infinity,
                        child: textBlock,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _TopCapsuleIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _TopCapsuleIconButton({
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: const Color(0xFF0C1D3D),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        alignment: Alignment.center,
        child: Icon(icon, color: Colors.white, size: 24),
      ),
    );
  }
}

class _BottomNavSquareButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _BottomNavSquareButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: _kBottomNavBoxSize,
            height: _kBottomNavBoxSize,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF122D59), Color(0xFF0B1A39)]),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.22), blurRadius: 10, offset: const Offset(0, 6)),
              ],
            ),
            child: Icon(icon, color: const Color(0xFFFFC62D), size: 34),
          ),
          const SizedBox(height: _kBottomNavLabelGap),
          SizedBox(
            height: _kBottomNavLabelHeight,
            child: Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontSize: 12, height: 1.1),
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomNavPillButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final int badgeCount;
  final VoidCallback onTap;

  const _BottomNavPillButton({
    required this.icon,
    required this.label,
    required this.badgeCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: _kBottomNavBoxSize,
            child: Center(
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  Container(
                    height: 60,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFF162D64), Color(0xFF0A1735)]),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: const Color(0xFFE0B640), width: 2),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 12, offset: const Offset(0, 6)),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(icon, color: const Color(0xFFFFCF49), size: 24),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (badgeCount > 0)
                    Positioned(
                      top: 0,
                      right: 8,
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: const BoxDecoration(
                          color: Color(0xFFFFC92D),
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '$badgeCount',
                          style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: _kBottomNavLabelGap),
          const SizedBox(height: _kBottomNavLabelHeight),
        ],
      ),
    );
  }
}

class _HomeStarfieldPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    final stars = <Offset>[
      const Offset(0.06, 0.08), const Offset(0.18, 0.12), const Offset(0.84, 0.1), const Offset(0.92, 0.18),
      const Offset(0.12, 0.26), const Offset(0.28, 0.2), const Offset(0.74, 0.28), const Offset(0.88, 0.34),
      const Offset(0.07, 0.42), const Offset(0.26, 0.5), const Offset(0.62, 0.46), const Offset(0.94, 0.54),
      const Offset(0.1, 0.68), const Offset(0.23, 0.76), const Offset(0.76, 0.74), const Offset(0.9, 0.82),
      const Offset(0.04, 0.92), const Offset(0.17, 0.88), const Offset(0.58, 0.9), const Offset(0.84, 0.96),
    ];

    for (var i = 0; i < stars.length; i++) {
      final offset = Offset(stars[i].dx * size.width, stars[i].dy * size.height);
      final radius = i.isEven ? 1.8 : 1.1;
      final alpha = i % 3 == 0 ? 0.65 : 0.32;
      paint.color = Colors.white.withValues(alpha: alpha);
      canvas.drawCircle(offset, radius, paint);
      if (i % 4 == 0) {
        paint.color = const Color(0xFFB7D9FF).withValues(alpha: 0.2);
        canvas.drawCircle(offset, radius * 2.8, paint);
      }
    }

    final random = math.Random(7);
    for (var i = 0; i < 90; i++) {
      final offset = Offset(random.nextDouble() * size.width, random.nextDouble() * size.height);
      final radius = random.nextDouble() * 1.2 + 0.35;
      paint.color = Colors.white.withValues(alpha: 0.06 + random.nextDouble() * 0.14);
      canvas.drawCircle(offset, radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
