import 'package:flutter/material.dart';
import '../../models/user_level.dart';
import '../../services/user_profile_service.dart';
import '../../services/firebase/auth_service.dart';
import '../../services/firebase/firestore_service.dart';
import '../friends/friends_screen.dart';
import '../auth/login_screen.dart';
import '../leaderboard/leaderboard_screen.dart';
import '../../models/cosmetic_item.dart';
import '../../models/achievement.dart';
import '../../services/shop_service.dart';
import '../../services/achievement_service.dart';
import '../../providers/language_provider.dart';
import '../support/support_screen.dart';
import 'package:provider/provider.dart';
import '../onboarding/tutorial_screen.dart';
import 'settings_screen.dart';
import '../shop/shop_screen.dart';
import 'widgets/activity_chart.dart';
import 'widgets/duel_performance_card.dart';
import 'widgets/stats_grid.dart';
import 'widgets/language_passport.dart';
import 'widgets/match_history_section.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/ad_service.dart';
import '../../services/firebase/storage_service.dart';
import '../support/admin_support_list_screen.dart';
import '../news/news_screen.dart';

class ProfileScreenNew extends StatefulWidget {
  const ProfileScreenNew({super.key});

  @override
  State<ProfileScreenNew> createState() => _ProfileScreenNewState();
}

class _ProfileScreenNewState extends State<ProfileScreenNew> {
  UserProfile? _profile;
  List<Achievement> _achievements = [];
  List<String> _unlockedCosmetics = [];
  String? _selectedFrameId;
  bool _isLoading = true;
  bool _isPremium = false;

  Future<void> _pickAndUploadImage() async {
    if (!_isPremium) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF2E5A8C),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Text('⭐', style: TextStyle(fontSize: 24)),
              const SizedBox(width: 10),
              Text(
                  context.read<LanguageProvider>().getString('premium_feature'),
                  style: const TextStyle(color: Colors.white, fontSize: 18)),
            ],
          ),
          content: Text(
            context.read<LanguageProvider>().getString('premium_info'),
            style: const TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(context.read<LanguageProvider>().getString('close'),
                  style: const TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) =>
                            const ShopScreen(initialTabIndex: 4)));
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
              child: Text(
                  context.read<LanguageProvider>().getString('go_premium'),
                  style: const TextStyle(color: Colors.black)),
            ),
          ],
        ),
      );
      return;
    }

    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 75,
    );

    if (image == null) return;

    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) =>
          const Center(child: CircularProgressIndicator(color: Colors.white)),
    );

    try {
      debugPrint('📸 Fotoğraf seçme işlemi başladı...');
      final bytes = await image.readAsBytes();
      debugPrint('📸 Fotoğraf bytes okundu. Boyut: ${bytes.length} bytes');

      debugPrint('📤 StorageService yükleme başlıyor...');
      final String? downloadUrl =
          await StorageService.instance.uploadProfileImageBytes(bytes);
      debugPrint('📥 StorageService cevabı: $downloadUrl');

      if (mounted) {
        Navigator.pop(context); // Yükleme animasyonunu kapat
        debugPrint('🔄 Loading dialog kapatıldı.');
      }

      if (downloadUrl != null) {
        debugPrint('✅ Fotoğraf başarıyla yüklendi: $downloadUrl');

        // Firestore güncellemesi
        try {
          debugPrint('📝 Firestore profil güncelleniyor...');
          await UserProfileService.instance.updateProfileImage(downloadUrl);
          await UserProfileService.instance.updateAvatar(null);
          await UserProfileService.instance.syncProfileToFirestore();
          debugPrint('✅ Firestore senkronizasyonu tamam.');
        } catch (syncError) {
          debugPrint(
              '⚠️ Fotoğraf yüklendi ama Firestore senkronizasyonunda hata: $syncError');
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context
                  .read<LanguageProvider>()
                  .getString('profile_updated')),
              backgroundColor: Colors.green,
            ),
          );
          _loadProfile();
        }
      } else {
        debugPrint('❌ Fotoğraf yükleme başarısız (downloadUrl null)');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  context.read<LanguageProvider>().getString('upload_failed')),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('❌ Hata: Fotoğraf yüklenemedi: $e');
      if (mounted) {
        // Hata durumunda dialog'un açık kalmadığından emin ol
        try {
          Navigator.pop(context);
        } catch (_) {}

        String errorMsg =
            'Fotoğraf yüklenirken bir hata oluştu: ${e.toString()}';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      debugPrint('🏁 Fotoğraf yükleme işlemi bitti.');
    }
  }

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final profile = await UserProfileService.instance.loadProfile();
    final achievements = await AchievementService.instance.getAchievements();
    final unlockedCosmetics = await ShopService.instance.getUnlockedCosmetics();
    final selectedFrame =
        await ShopService.instance.getSelectedCosmetic(CosmeticType.frame);
    final subscription = await ShopService.instance.getSubscription();

    setState(() {
      _profile = profile;
      _achievements = achievements;
      _unlockedCosmetics = unlockedCosmetics;
      _selectedFrameId = selectedFrame;
      _isPremium = subscription.isActive || (profile.isPremium);
      _isLoading = false;
    });
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
          child: Column(
            children: [
              // Header with back and settings
              _buildHeader(),

              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      const SizedBox(height: 16),

                      // Profile Picture
                      _buildProfilePicture(),
                      const SizedBox(height: 12),

                      // Username & Join Date
                      _buildUserInfo(),
                      const SizedBox(height: 20),

                      // İstatistikler Header
                      _buildSectionHeader(context
                          .watch<LanguageProvider>()
                          .getString('statistics')),
                      const SizedBox(height: 12),

                      // Statistics Cards
                      _buildStatisticsGrid(),
                      const SizedBox(height: 24),

                      // Ödüller
                      _buildSectionHeader(context
                          .watch<LanguageProvider>()
                          .getString('awards')),
                      const SizedBox(height: 24),

                      // Maç Geçmişi
                      if (_profile != null) ...[
                        MatchHistorySection(profile: _profile!),
                        const SizedBox(height: 32),
                      ],
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

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          ),
          IconButton(
            onPressed: () => _showSettingsMenu(),
            icon: const Icon(Icons.settings, color: Colors.white, size: 28),
          ),
        ],
      ),
    );
  }

  void _showSettingsMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF4A7FB8), Color(0xFF2E5A8C)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white30,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            _buildMenuItem(
                Icons.settings,
                context
                    .watch<LanguageProvider>()
                    .getString('settings')
                    .toUpperCase(),
                Colors.deepPurple, () {
              Navigator.pop(context);
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen()));
            }),
            _buildMenuItem(
                Icons.people,
                context
                    .watch<LanguageProvider>()
                    .getString('friends')
                    .toUpperCase(),
                Colors.pink, () {
              Navigator.pop(context);
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const FriendsScreen()));
            }),
            _buildMenuItem(
                Icons.leaderboard,
                context
                    .watch<LanguageProvider>()
                    .getString('leaderboard')
                    .toUpperCase(),
                Colors.green, () {
              Navigator.pop(context);
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const LeaderboardScreen()));
            }),
            _buildMenuItem(Icons.newspaper, 'HABERLER', Colors.orange, () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const NewsScreen()));
            }),
            _buildMenuItem(
                Icons.menu_book,
                context
                    .watch<LanguageProvider>()
                    .getString('guide')
                    .toUpperCase(),
                Colors.teal, () {
              Navigator.pop(context);
              _showGuide();
            }),
            _buildMenuItem(Icons.play_circle_outline, 'TUTORIAL', Colors.cyan,
                () {
              Navigator.pop(context);
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const TutorialScreen()));
            }),
            _buildMenuItem(
                Icons.card_giftcard,
                context
                    .watch<LanguageProvider>()
                    .getString('promo_code_title')
                    .toUpperCase(),
                Colors.amber, () {
              Navigator.pop(context);
              _showPromoCodeDialog();
            }),
            _buildMenuItem(
                Icons.support_agent,
                context
                    .watch<LanguageProvider>()
                    .getString('support')
                    .toUpperCase(),
                Colors.indigo, () {
              Navigator.pop(context);
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const SupportScreen()));
            }),
            if (AuthService.instance.isAdmin) ...[
              _buildMenuItem(Icons.admin_panel_settings, 'YÖNETİCİ PANELİ',
                  Colors.amber.shade900, () {
                Navigator.pop(context);
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const AdminSupportListScreen()));
              }),
            ],
            _buildMenuItem(
                Icons.logout,
                context
                    .watch<LanguageProvider>()
                    .getString('logout')
                    .toUpperCase(),
                Colors.red, () {
              Navigator.pop(context);
              _handleLogout();
            }),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem(
      IconData icon, String title, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 16),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfilePicture() {
    // Seçili frame'i bul
    CosmeticItem? selectedFrame;
    if (_selectedFrameId != null) {
      final frames =
          CosmeticItem.availableItems.where((i) => i.id == _selectedFrameId);
      if (frames.isNotEmpty) {
        selectedFrame = frames.first;
      }
    }

    // Frame rengi ve kalınlığı - varsayılan mor
    Color frameColor = const Color(0xFF6C27FF);
    double borderWidth = 3.0;
    bool isRainbow = false;

    if (selectedFrame != null) {
      if (selectedFrame.previewValue == 'gradient') {
        isRainbow = true;
      } else {
        frameColor =
            Color(int.parse('FF${selectedFrame.previewValue}', radix: 16));
      }
      borderWidth = selectedFrame.borderWidth.toDouble();
    }

    return GestureDetector(
      onTap: () => _showOwnedAvatars(),
      child: Stack(
        children: [
          Container(
            width: 100 + borderWidth * 2,
            height: 100 + borderWidth * 2,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: isRainbow
                  ? const LinearGradient(
                      colors: [
                        Colors.red,
                        Colors.orange,
                        Colors.yellow,
                        Colors.green,
                        Colors.blue,
                        Colors.purple
                      ],
                    )
                  : null,
              color: isRainbow ? null : frameColor,
              boxShadow: [
                BoxShadow(
                  color:
                      (isRainbow ? Colors.purple : frameColor).withAlpha(128),
                  blurRadius: 15,
                  spreadRadius: 3,
                ),
                if (selectedFrame != null) ...[
                  BoxShadow(
                    color: (isRainbow ? Colors.cyan : frameColor).withAlpha(77),
                    blurRadius: 25,
                    spreadRadius: 5,
                  ),
                ],
              ],
            ),
            child: Center(
              child: ClipOval(
                child: SizedBox(
                  width: 100,
                  height: 100,
                  child: Builder(builder: (context) {
                    const placeholder = Color(0xFF1A3A5C);
                    final profile = _profile;
                    if (profile == null) {
                      return const ColoredBox(
                        color: placeholder,
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }

                    final hasPhoto = profile.profileImagePath != null &&
                        profile.profileImagePath!.isNotEmpty;
                    if (hasPhoto) {
                      return Stack(
                        fit: StackFit.expand,
                        children: [
                          const ColoredBox(color: placeholder),
                          Image.network(
                            profile.profileImagePath!,
                            fit: BoxFit.cover,
                            alignment: Alignment.center,
                            errorBuilder: (context, error, stackTrace) =>
                                const Icon(Icons.person,
                                    size: 50, color: Colors.white),
                          ),
                        ],
                      );
                    }

                    final avatarId = profile.avatarId;
                    if (avatarId != null && avatarId.isNotEmpty) {
                      String? assetPath;
                      if (avatarId.startsWith('assets/')) {
                        assetPath = avatarId;
                      } else {
                        final items = CosmeticItem.availableItems
                            .where((i) => i.id == avatarId);
                        if (items.isNotEmpty) {
                          final pv = items.first.previewValue;
                          if (pv.startsWith('assets/')) assetPath = pv;
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
                              errorBuilder: (context, error, stackTrace) =>
                                  const Icon(Icons.person,
                                      size: 50, color: Colors.white),
                            ),
                          ],
                        );
                      }
                      final items = CosmeticItem.availableItems
                          .where((i) => i.id == avatarId);
                      if (items.isNotEmpty) {
                        final previewValue = items.first.previewValue;
                        if (!previewValue.startsWith('assets/')) {
                          return ColoredBox(
                            color: placeholder,
                            child: Center(
                              child: Text(
                                previewValue,
                                style: const TextStyle(fontSize: 52),
                              ),
                            ),
                          );
                        }
                      }
                    }

                    return ColoredBox(
                      color: placeholder,
                      child: Center(
                        child: Text(
                          profile.username.isNotEmpty == true
                              ? profile.username[0].toUpperCase()
                              : 'P',
                          style: const TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ),
          ),
          // Premium ikonu (sol üst köşe)
          if (_isPremium)
            Positioned(
              left: 0,
              top: 0,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFD700), Color(0xFFFFA000)],
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFFD700).withAlpha(128),
                      blurRadius: 8,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Icon(Icons.star, color: Colors.white, size: 16),
              ),
            ),
          // Düzenleme ikonu
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF6C27FF),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: const Icon(Icons.edit, color: Colors.white, size: 14),
            ),
          ),
        ],
      ),
    );
  }

  void _showOwnedAvatars() {
    // Sahip olunan avatarları filtrele
    final ownedAvatars = CosmeticItem.availableItems
        .where((item) =>
            item.type == CosmeticType.avatar &&
            _unlockedCosmetics.contains(item.id))
        .toList();

    // Sahip olunan frame'leri filtrele
    final ownedFrames = CosmeticItem.availableItems
        .where((item) =>
            item.type == CosmeticType.frame &&
            _unlockedCosmetics.contains(item.id))
        .toList();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF2E5A8C), Color(0xFF1A3A5C)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(77),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    const Icon(Icons.person, color: Colors.white, size: 28),
                    const SizedBox(width: 12),
                    Text(
                      Provider.of<LanguageProvider>(context, listen: false)
                          .getString('change_appearance'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    // Banner Reklam
                    const Center(child: BannerAdWidget()),
                    const SizedBox(height: 16),

                    // Avatarlar Bölümü (Profil Fotoğrafı Yükleme dahil)
                    Text(
                      '👤 ${context.read<LanguageProvider>().getString('profile_view')}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Profil Fotoğrafı Yükleme (Her zaman görünür, premium kontrolü tıklamada)
                    GestureDetector(
                      onTap: () => _pickAndUploadImage(),
                      child: Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: _isPremium
                              ? const Color(0xFF6C27FF).withAlpha(26)
                              : Colors.white.withAlpha(13),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color: _isPremium
                                  ? const Color(0xFF6C27FF).withAlpha(128)
                                  : Colors.white10),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.camera_alt,
                                color: _isPremium
                                    ? const Color(0xFF6C27FF)
                                    : Colors.white24),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    context
                                        .read<LanguageProvider>()
                                        .getString('upload_profile_photo'),
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold),
                                  ),
                                  if (!_isPremium)
                                    Text(
                                      context
                                          .read<LanguageProvider>()
                                          .getString('only_premium'),
                                      style: TextStyle(
                                          color: Colors.white.withAlpha(102),
                                          fontSize: 11),
                                    ),
                                ],
                              ),
                            ),
                            if (!_isPremium)
                              const Icon(Icons.lock_rounded,
                                  color: Colors.amber, size: 16)
                            else if (_profile?.profileImagePath != null)
                              const Icon(Icons.check_circle,
                                  color: Colors.green, size: 20),
                          ],
                        ),
                      ),
                    ),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '🎭 ${context.watch<LanguageProvider>().getString('purchased_avatars')}',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) =>
                                        const ShopScreen(initialTabIndex: 2)));
                          },
                          icon: const Icon(Icons.shopping_cart,
                              size: 14, color: Colors.amber),
                          label: Text(
                            context
                                .read<LanguageProvider>()
                                .getString('go_to_market'),
                            style: const TextStyle(
                                color: Colors.amber, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (ownedAvatars.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(13),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            const Text('😢', style: TextStyle(fontSize: 40)),
                            const SizedBox(height: 8),
                            Text(
                              context
                                  .read<LanguageProvider>()
                                  .getString('no_avatars'),
                              style:
                                  TextStyle(color: Colors.white.withAlpha(128)),
                            ),
                            const SizedBox(height: 12),
                            ElevatedButton(
                              onPressed: () {
                                Navigator.pop(context);
                                Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (context) => const ShopScreen(
                                            initialTabIndex: 2)));
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF6C27FF),
                              ),
                              child: Text(context
                                  .read<LanguageProvider>()
                                  .getString('go_to_market')),
                            ),
                          ],
                        ),
                      )
                    else
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: ownedAvatars.map((avatar) {
                          final isSelected = _profile?.avatarId == avatar.id;
                          return GestureDetector(
                            onTap: () async {
                              await ShopService.instance.setSelectedCosmetic(
                                  avatar.id, CosmeticType.avatar);
                              await UserProfileService.instance
                                  .updateAvatar(avatar.id);
                              Navigator.pop(context);
                              _loadProfile();
                            },
                            child: Container(
                              width: 70,
                              height: 70,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? Colors.green.withAlpha(77)
                                    : Colors.white.withAlpha(26),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isSelected
                                      ? Colors.green
                                      : Colors.transparent,
                                  width: 3,
                                ),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: avatar.previewValue.startsWith('assets/')
                                    ? ColoredBox(
                                        color: const Color(0xFF1A3A5C),
                                        child: Image.asset(
                                          avatar.previewValue,
                                          fit: BoxFit.cover,
                                          width: 70,
                                          height: 70,
                                          alignment: Alignment.center,
                                        ),
                                      )
                                    : Center(
                                        child: Text(avatar.previewValue,
                                            style:
                                                const TextStyle(fontSize: 36)),
                                      ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),

                    const SizedBox(height: 24),

                    // Çerçeveler Bölümü
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '🖼️ ${context.watch<LanguageProvider>().getString('frames')}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) => const ShopScreen(
                                        initialTabIndex: 2,
                                        scrollToFrames: true)));
                          },
                          icon: const Icon(Icons.shopping_cart,
                              size: 14, color: Colors.amber),
                          label: Text(
                            context
                                .read<LanguageProvider>()
                                .getString('go_to_market'),
                            style: const TextStyle(
                                color: Colors.amber, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (ownedFrames.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(13),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            const Text('🖼️', style: TextStyle(fontSize: 40)),
                            const SizedBox(height: 8),
                            Text(
                              context
                                  .read<LanguageProvider>()
                                  .getString('no_frames'),
                              style:
                                  TextStyle(color: Colors.white.withAlpha(128)),
                            ),
                            const SizedBox(height: 12),
                            ElevatedButton(
                              onPressed: () {
                                Navigator.pop(context);
                                Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (context) => const ShopScreen(
                                            initialTabIndex: 2,
                                            scrollToFrames: true)));
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF6C27FF),
                              ),
                              child: const Text('Markete Git'),
                            ),
                          ],
                        ),
                      )
                    else
                      Column(
                        children: [
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              // Çerçeve yok seçeneği
                              GestureDetector(
                                onTap: () async {
                                  await ShopService.instance
                                      .setSelectedCosmetic(
                                          '', CosmeticType.frame);
                                  Navigator.pop(context);
                                  _loadProfile();
                                },
                                child: Container(
                                  width: 70,
                                  height: 70,
                                  decoration: BoxDecoration(
                                    color: _selectedFrameId == null ||
                                            _selectedFrameId!.isEmpty
                                        ? Colors.green.withAlpha(77)
                                        : Colors.white.withAlpha(26),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: _selectedFrameId == null ||
                                              _selectedFrameId!.isEmpty
                                          ? Colors.green
                                          : Colors.transparent,
                                      width: 3,
                                    ),
                                  ),
                                  child: const Center(
                                    child: Icon(Icons.block,
                                        color: Colors.white54, size: 32),
                                  ),
                                ),
                              ),
                              ...ownedFrames.map((frame) {
                                final isSelected = _selectedFrameId == frame.id;
                                Color frameColor;
                                if (frame.previewValue == 'gradient') {
                                  frameColor = Colors.purple;
                                } else {
                                  frameColor = Color(int.parse(
                                      'FF${frame.previewValue}',
                                      radix: 16));
                                }
                                return GestureDetector(
                                  onTap: () async {
                                    await ShopService.instance
                                        .setSelectedCosmetic(
                                            frame.id, CosmeticType.frame);
                                    Navigator.pop(context);
                                    _loadProfile();
                                  },
                                  child: Container(
                                    width: 70,
                                    height: 70,
                                    decoration: BoxDecoration(
                                      gradient: frame.previewValue == 'gradient'
                                          ? const LinearGradient(
                                              colors: [
                                                Colors.red,
                                                Colors.orange,
                                                Colors.yellow,
                                                Colors.green,
                                                Colors.blue,
                                                Colors.purple
                                              ],
                                            )
                                          : null,
                                      color: frame.previewValue != 'gradient'
                                          ? Colors.white.withAlpha(26)
                                          : null,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: isSelected
                                            ? Colors.green
                                            : frameColor,
                                        width: isSelected
                                            ? 4
                                            : frame.borderWidth.toDouble(),
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: frameColor.withAlpha(128),
                                          blurRadius: 8,
                                          spreadRadius: 1,
                                        ),
                                      ],
                                    ),
                                    child: Center(
                                      child: Text(
                                        isSelected ? '✓' : '',
                                        style: const TextStyle(
                                          color: Colors.green,
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }),
                            ],
                          ),
                        ],
                      ),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Profil kaydı ile Firebase hesap açılışından erken olanı göster (üye olma tarihi).
  DateTime? _effectiveJoinDate() {
    final p = _profile?.createdAt;
    final a = AuthService.instance.accountCreatedAt;
    if (p != null && a != null) {
      return p.isBefore(a) ? p : a;
    }
    return p ?? a;
  }

  Widget _buildUserInfo() {
    final lang = context.watch<LanguageProvider>();
    final joinDate = _effectiveJoinDate();
    final String joinSubtitle;
    if (joinDate != null) {
      final formattedDate =
          '${joinDate.day} ${_getMonthName(joinDate.month)} ${joinDate.year}';
      joinSubtitle =
          lang.getString('joining_date').replaceAll('{date}', formattedDate);
    } else {
      joinSubtitle = lang.getString('joining_date_unknown');
    }

    return Column(
      children: [
        GestureDetector(
          onTap: _showEditUsernameDialog,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _profile?.username ?? 'Player',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(26),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(Icons.edit, color: Colors.white54, size: 16),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          joinSubtitle,
          style: TextStyle(
            color: Colors.white.withAlpha(179),
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  void _showEditUsernameDialog() {
    final controller = TextEditingController(text: _profile?.username ?? '');
    String? errorText;
    bool isChecking = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF2E5A8C),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.edit, color: Colors.white, size: 24),
              SizedBox(width: 10),
              Text('İsim Değiştir', style: TextStyle(color: Colors.white)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: controller,
                style: const TextStyle(color: Colors.white),
                maxLength: 20,
                decoration: InputDecoration(
                  hintText: 'Yeni kullanıcı adı',
                  hintStyle: TextStyle(color: Colors.white.withAlpha(77)),
                  filled: true,
                  fillColor: Colors.white.withAlpha(26),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  errorText: errorText,
                  errorStyle: const TextStyle(color: Colors.redAccent),
                  counterStyle: TextStyle(color: Colors.white.withAlpha(128)),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '⚠️ Kullanıcı adınızı tamamen değiştiremezsiniz.\n• Sadece harflerin büyük/küçük durumunu değiştirebilirsiniz.\n• Örnek: "player" -> "Player"',
                style: TextStyle(
                  color: Colors.white.withAlpha(200),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child:
                  const Text('İptal', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              onPressed: isChecking
                  ? null
                  : () async {
                      final newName = controller.text.trim();

                      // Validasyon
                      if (newName.length < 3) {
                        setDialogState(
                            () => errorText = 'En az 3 karakter olmalı');
                        return;
                      }
                      if (newName.length > 20) {
                        setDialogState(
                            () => errorText = 'En fazla 20 karakter olabilir');
                        return;
                      }
                      // Sadece harf, rakam ve alt çizgi (Eski Regex'e dönüldü)
                      final validChars =
                          RegExp(r'^[a-zA-Z0-9_\u00C0-\u017F]+$');
                      if (!validChars.hasMatch(newName)) {
                        setDialogState(
                            () => errorText = 'Özel karakterler kullanılamaz');
                        return;
                      }
                      // Aynı isimse (harf harf kontrolü)
                      if (newName == _profile?.username) {
                        Navigator.pop(ctx);
                        return;
                      }

                      // Sadece büyük/küçük harf değişikliğine izin ver
                      if (newName.toLowerCase() !=
                          _profile?.username.toLowerCase()) {
                        setDialogState(() => errorText =
                            'Sadece harf büyüklüğünü değiştirebilirsiniz (Örn: isim -> İsim)');
                        return;
                      }

                      setDialogState(() {
                        isChecking = true;
                        errorText = null;
                      });

                      // Benzersizlik kontrolü (Firebase'den)
                      final isUnique = await FirestoreService.instance
                          .isUsernameUnique(newName);

                      if (!isUnique) {
                        setDialogState(() {
                          isChecking = false;
                          errorText = 'Bu kullanıcı adı zaten alınmış';
                        });
                        return;
                      }

                      // İsmi güncelle
                      await UserProfileService.instance.updateUsername(newName);
                      await FirestoreService.instance.updateUsername(newName);

                      if (mounted) {
                        Navigator.pop(ctx);
                        _loadProfile();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Row(
                              children: [
                                Icon(Icons.check_circle, color: Colors.white),
                                SizedBox(width: 8),
                                Text('Kullanıcı adı güncellendi!'),
                              ],
                            ),
                            backgroundColor: Color(0xFF2E5A8C),
                          ),
                        );
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6C27FF),
              ),
              child: isChecking
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2),
                    )
                  : const Text('Kaydet'),
            ),
          ],
        ),
      ),
    );
  }

  String _getMonthName(int month) {
    const months = [
      'Oca',
      'Şub',
      'Mar',
      'Nis',
      'May',
      'Haz',
      'Tem',
      'Ağu',
      'Eyl',
      'Eki',
      'Kas',
      'Ara'
    ];
    return months[month - 1];
  }

  // ignore: unused_element - Member badge için saklanıyor
  Widget _buildMemberBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.cyan.withAlpha(51),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.cyan, width: 1),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.diamond, color: Colors.cyan, size: 18),
          SizedBox(width: 6),
          Text(
            'Elmas Üye',
            style: TextStyle(
              color: Colors.cyan,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // ignore: unused_element - Add Friends button için saklanıyor
  Widget _buildAddFriendsButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () {
          Navigator.push(context,
              MaterialPageRoute(builder: (_) => const FriendsScreen()));
        },
        icon: const Icon(Icons.person_add, size: 20),
        label: const Text('Add Friends',
            style: TextStyle(fontWeight: FontWeight.bold)),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF3D7AB8),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildStatisticsGrid() {
    if (_profile == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. StatsGrid (2x2 Layout) - PUANLAR ARTIK EN ÜSTTE
        StatsGrid(profile: _profile!),
        const SizedBox(height: 24),

        // Dil Pasaportu (Öğrenme Haritası)
        LanguagePassport(profile: _profile!),
        const SizedBox(height: 24),

        // 2. ActivityChart (Weekly Activity)
        ActivityChart(profile: _profile!),
        const SizedBox(height: 16),

        // 3. DuelPerformanceCard (Win Rate & Circular Indicators)
        DuelPerformanceCard(profile: _profile!),
      ],
    );
  }

  Widget _buildAwardsSection() {
    final unlockedAchievements =
        _achievements.where((a) => a.isUnlocked).toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(26),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.emoji_events, color: Colors.amber, size: 24),
                  SizedBox(width: 8),
                  Text(
                    'Ödüller',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  Text(
                    '${unlockedAchievements.length} / ${_achievements.length}',
                    style: TextStyle(
                      color: Colors.white.withAlpha(179),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: () => _showAllAchievements(),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.amber.withAlpha(51),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.amber.withAlpha(128)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Tümünü Gör',
                            style: TextStyle(
                              color: Colors.amber,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(width: 4),
                          Icon(Icons.arrow_forward_ios,
                              color: Colors.amber, size: 12),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (unlockedAchievements.isEmpty)
            Center(
              child: Text(
                'Henüz ödül kazanılmadı',
                style: TextStyle(color: Colors.white.withAlpha(128)),
              ),
            )
          else
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: unlockedAchievements.take(8).map((achievement) {
                return GestureDetector(
                  onTap: () => _showAchievementDetail(achievement),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _getTierColor(achievement.tier).withAlpha(51),
                      borderRadius: BorderRadius.circular(12),
                      border:
                          Border.all(color: _getTierColor(achievement.tier)),
                    ),
                    child: Text(achievement.badgeIcon,
                        style: const TextStyle(fontSize: 28)),
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  void _showAchievementDetail(Achievement achievement) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2E5A8C),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Badge icon büyük
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: _getTierColor(achievement.tier).withAlpha(77),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: _getTierColor(achievement.tier), width: 3),
              ),
              child: Center(
                child: Text(achievement.badgeIcon,
                    style: const TextStyle(fontSize: 44)),
              ),
            ),
            const SizedBox(height: 16),
            // Başlık
            Text(
              achievement.title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            // Açıklama
            Text(
              achievement.description,
              style: TextStyle(
                color: Colors.white.withAlpha(179),
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            // Ödül bilgisi
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.amber.withAlpha(51),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.withAlpha(128)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🪙', style: TextStyle(fontSize: 18)),
                  const SizedBox(width: 8),
                  Text(
                    '+${achievement.rewardCoins} altın kazandınız!',
                    style: const TextStyle(
                      color: Colors.amber,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Tier badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _getTierColor(achievement.tier),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                achievement.tier.name.toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Tamam', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showAllAchievements() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF2E5A8C), Color(0xFF1A3A5C)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(77),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    const Icon(Icons.emoji_events,
                        color: Colors.amber, size: 28),
                    const SizedBox(width: 12),
                    const Text(
                      'Tüm Rozetler',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${_achievements.where((a) => a.isUnlocked).length} / ${_achievements.length}',
                      style: TextStyle(
                        color: Colors.white.withAlpha(179),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              // Achievements list
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _achievements.length,
                  itemBuilder: (context, index) {
                    final achievement = _achievements[index];
                    final isUnlocked = achievement.isUnlocked;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isUnlocked
                            ? _getTierColor(achievement.tier).withAlpha(51)
                            : Colors.white.withAlpha(13),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isUnlocked
                              ? _getTierColor(achievement.tier)
                              : Colors.white.withAlpha(26),
                        ),
                      ),
                      child: Row(
                        children: [
                          // Badge icon
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: isUnlocked
                                  ? _getTierColor(achievement.tier)
                                      .withAlpha(77)
                                  : Colors.white.withAlpha(26),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: Text(
                                achievement.badgeIcon,
                                style: TextStyle(
                                  fontSize: 28,
                                  color: isUnlocked ? null : Colors.grey,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          // Details
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  achievement.title,
                                  style: TextStyle(
                                    color: isUnlocked
                                        ? Colors.white
                                        : Colors.white54,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  achievement.description,
                                  style: TextStyle(
                                    color: isUnlocked
                                        ? Colors.white.withAlpha(179)
                                        : Colors.white38,
                                    fontSize: 12,
                                  ),
                                ),
                                if (!isUnlocked) ...[
                                  const SizedBox(height: 8),
                                  // Progress bar
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: LinearProgressIndicator(
                                      value: achievement.currentProgress /
                                          achievement.goal,
                                      backgroundColor:
                                          Colors.white.withAlpha(26),
                                      valueColor: AlwaysStoppedAnimation(
                                        _getTierColor(achievement.tier)
                                            .withAlpha(179),
                                      ),
                                      minHeight: 6,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${achievement.currentProgress} / ${achievement.goal}',
                                    style: TextStyle(
                                      color: Colors.white.withAlpha(128),
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          // Tier badge
                          if (isUnlocked)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: _getTierColor(achievement.tier),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                achievement.tier.name.toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            )
                          else
                            Icon(
                              Icons.lock_outline,
                              color: Colors.white.withAlpha(77),
                              size: 24,
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
    );
  }

  Color _getTierColor(AchievementTier tier) {
    switch (tier) {
      case AchievementTier.bronze:
        return const Color(0xFFCD7F32);
      case AchievementTier.silver:
        return const Color(0xFFC0C0C0);
      case AchievementTier.gold:
        return const Color(0xFFFFD700);
      case AchievementTier.platinum:
        return const Color(0xFFE5E4E2);
    }
  }

  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A3A5C),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          context.watch<LanguageProvider>().getString('logout'),
          style:
              const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        content: Text(
          context.watch<LanguageProvider>().getString('confirm_logout'),
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.watch<LanguageProvider>().getString('cancel'),
                style: const TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
            ),
            child: Text(context.watch<LanguageProvider>().getString('logout'),
                style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await AuthService.instance.signOut();
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
      }
    }
  }

  void _showGuide() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF2E5A8C), Color(0xFF1A3A5C)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white30,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Oyun Rehberi',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildGuideSection(
                        'Nasıl Oynanır?',
                        Icons.games,
                        '• Her turda bir İngilizce kelime ve 4 Türkçe seçenek görürsün\n'
                            '• Doğru Türkçe anlamı 10 saniye içinde seç\n'
                            '• Hızlı ve doğru cevaplar daha çok puan kazandırır\n'
                            '• Arka arkaya doğru cevaplar combo yapar',
                      ),
                      _buildGuideSection(
                        'Duel Modu',
                        Icons.sports_kabaddi,
                        '• Bot rakibe karşı yarış\n'
                            '• Her oyun 10 soru içerir\n'
                            '• Kazanan WP (War Points) kazanır\n'
                            '• Kaybeden WP kaybeder',
                      ),
                      _buildGuideSection(
                        'Online Duel',
                        Icons.wifi,
                        '• Gerçek oyunculara karşı yarış\n'
                            '• Arkadaşlarını davet edebilirsin\n'
                            '• Eşleşme rastgele de olabilir',
                      ),
                      _buildGuideSection(
                        'Ligler & Sıralama',
                        Icons.emoji_events,
                        '• Bronz → Gümüş → Altın → Platin → Elmas → Efsane\n'
                            '• Her lig belirli WP aralığına sahip\n'
                            '• Lider tablosunda en iyiler görünür',
                      ),
                      _buildGuideSection(
                        'Mağaza',
                        Icons.store,
                        '• Altın ile yeni avatarlar, çerçeveler, temalar satın al\n'
                            '• Özel efektler ve güç artırıcıları keşfet\n'
                            '• Premium üyelik ile reklamsız oyna',
                      ),
                      _buildGuideSection(
                        'Günlük Görevler',
                        Icons.task_alt,
                        '• Her gün yeni görevler\n'
                            '• Görevleri tamamla, altın kazan\n'
                            '• Streak bonusu ile ekstra ödüller',
                      ),
                      const SizedBox(height: 32),
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

  Widget _buildGuideSection(String title, IconData icon, String content) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(26),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withAlpha(51)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.amber, size: 24),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            content,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  void _showPromoCodeDialog() {
    final codeController = TextEditingController();
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1A3A5C),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.card_giftcard, color: Colors.amber, size: 28),
              const SizedBox(width: 8),
              Text(
                context.read<LanguageProvider>().getString('promo_code_title'),
                style: const TextStyle(color: Colors.white),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                context.read<LanguageProvider>().getString('promo_code_body'),
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: codeController,
                textCapitalization: TextCapitalization.characters,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText:
                      context.read<LanguageProvider>().getString('enter_code'),
                  hintStyle: const TextStyle(color: Colors.white38),
                  filled: true,
                  fillColor: Colors.white.withAlpha(26),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  prefixIcon: const Icon(Icons.code, color: Colors.white54),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(context.read<LanguageProvider>().getString('cancel'),
                  style: const TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      final code = codeController.text.trim();
                      if (code.isEmpty) return;

                      setDialogState(() => isLoading = true);

                      final result =
                          await ShopService.instance.redeemPromoCode(code);

                      setDialogState(() => isLoading = false);

                      if (!mounted) return;
                      Navigator.pop(dialogContext);

                      // Sonucu göster
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(result['message'] as String),
                          backgroundColor: result['success'] == true
                              ? Colors.green
                              : Colors.red.shade700,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(context.read<LanguageProvider>().getString('apply')),
            ),
          ],
        ),
      ),
    );
  }
}
