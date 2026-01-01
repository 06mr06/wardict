import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/league.dart';
import '../../models/user_level.dart';
import '../../services/user_profile_service.dart';
import '../../services/firebase/auth_service.dart';
import '../../services/firebase/firestore_service.dart';
import '../friends/friends_screen.dart';
import '../auth/login_screen.dart';
import '../../models/cosmetic_item.dart';
import '../../models/achievement.dart';
import '../../services/shop_service.dart';
import '../../services/achievement_service.dart';
import 'settings_screen.dart';

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

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final profile = await UserProfileService.instance.loadProfile();
    final achievements = await AchievementService.instance.getAchievements();
    final unlockedCosmetics = await ShopService.instance.getUnlockedCosmetics();
    final selectedFrame = await ShopService.instance.getSelectedCosmetic(CosmeticType.frame);
    
    setState(() {
      _profile = profile;
      _achievements = achievements;
      _unlockedCosmetics = unlockedCosmetics;
      _selectedFrameId = selectedFrame;
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
                      _buildSectionHeaderNoAction('İstatistikler'),
                      const SizedBox(height: 12),
                      
                      // Statistics Cards
                      _buildStatisticsGrid(),
                      const SizedBox(height: 24),

                      // Ödüller
                      _buildAwardsSection(),
                      const SizedBox(height: 24),
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
            _buildMenuItem(Icons.settings, 'AYARLAR', Colors.deepPurple, () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
            }),
            _buildMenuItem(Icons.people, 'ARKADAŞLAR', Colors.pink, () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const FriendsScreen()));
            }),
            _buildMenuItem(Icons.leaderboard, 'LİDERLER SIRALAMASI', Colors.green, () {
              Navigator.pop(context);
              // TODO: Leaderboard screen
            }),
            _buildMenuItem(Icons.newspaper, 'HABERLER', Colors.orange, () {
              Navigator.pop(context);
              // TODO: News screen
            }),
            _buildMenuItem(Icons.support_agent, 'DESTEK', Colors.indigo, () {
              Navigator.pop(context);
              // TODO: Support screen
            }),
            _buildMenuItem(Icons.logout, 'ÇIKIŞ', Colors.red, () {
              Navigator.pop(context);
              _handleLogout();
            }),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem(IconData icon, String title, Color color, VoidCallback onTap) {
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
      final frames = CosmeticItem.availableItems.where((i) => i.id == _selectedFrameId);
      if (frames.isNotEmpty) {
        selectedFrame = frames.first;
      }
    }
    
    // Frame rengi ve kalınlığı
    Color frameColor = Colors.white;
    double borderWidth = 3.0;
    bool isRainbow = false;
    
    if (selectedFrame != null) {
      if (selectedFrame.previewValue == 'gradient') {
        isRainbow = true;
      } else {
        frameColor = Color(int.parse('FF${selectedFrame.previewValue}', radix: 16));
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
              gradient: isRainbow ? const LinearGradient(
                colors: [Colors.red, Colors.orange, Colors.yellow, Colors.green, Colors.blue, Colors.purple],
              ) : null,
              color: isRainbow ? null : frameColor,
              boxShadow: [
                BoxShadow(
                  color: (isRainbow ? Colors.purple : frameColor).withOpacity(0.5),
                  blurRadius: 15,
                  spreadRadius: 3,
                ),
                if (selectedFrame != null) ...[
                  BoxShadow(
                    color: (isRainbow ? Colors.cyan : frameColor).withOpacity(0.3),
                    blurRadius: 25,
                    spreadRadius: 5,
                  ),
                ],
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
                  child: _profile?.avatarId != null && _profile!.avatarId!.isNotEmpty
                      ? Center(
                          child: Text(
                            CosmeticItem.availableItems.where((i) => i.id == _profile!.avatarId).isNotEmpty
                                ? CosmeticItem.availableItems.firstWhere((i) => i.id == _profile!.avatarId).previewValue
                                : '👤',
                            style: const TextStyle(fontSize: 52),
                          ),
                        )
                      : Center(
                          child: Text(
                            _profile?.username.isNotEmpty == true
                                ? _profile!.username[0].toUpperCase()
                                : 'P',
                            style: const TextStyle(
                              fontSize: 48,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                ),
              ),
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
        .where((item) => item.type == CosmeticType.avatar && _unlockedCosmetics.contains(item.id))
        .toList();
    
    // Sahip olunan frame'leri filtrele
    final ownedFrames = CosmeticItem.availableItems
        .where((item) => item.type == CosmeticType.frame && _unlockedCosmetics.contains(item.id))
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
                  color: Colors.white.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header
              const Padding(
                padding: EdgeInsets.all(20),
                child: Row(
                  children: [
                    Icon(Icons.person, color: Colors.white, size: 28),
                    SizedBox(width: 12),
                    Text(
                      'Görünümünü Değiştir',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              // Content
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    // Avatarlar Bölümü
                    const Text(
                      '👤 Avatarlar',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (ownedAvatars.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            const Text('😢', style: TextStyle(fontSize: 40)),
                            const SizedBox(height: 8),
                            Text(
                              'Henüz avatar satın almadınız',
                              style: TextStyle(color: Colors.white.withOpacity(0.5)),
                            ),
                            const SizedBox(height: 12),
                            ElevatedButton(
                              onPressed: () {
                                Navigator.pop(context);
                                Navigator.pushNamed(context, '/shop');
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
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: ownedAvatars.map((avatar) {
                          final isSelected = _profile?.avatarId == avatar.id;
                          return GestureDetector(
                            onTap: () async {
                              await ShopService.instance.setSelectedCosmetic(avatar.id, CosmeticType.avatar);
                              await UserProfileService.instance.updateAvatar(avatar.id);
                              Navigator.pop(context);
                              _loadProfile();
                            },
                            child: Container(
                              width: 70,
                              height: 70,
                              decoration: BoxDecoration(
                                color: isSelected 
                                    ? Colors.green.withOpacity(0.3)
                                    : Colors.white.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isSelected ? Colors.green : Colors.transparent,
                                  width: 3,
                                ),
                              ),
                              child: Center(
                                child: Text(avatar.previewValue, style: const TextStyle(fontSize: 36)),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    
                    const SizedBox(height: 24),
                    
                    // Çerçeveler Bölümü
                    const Text(
                      '🖼️ Çerçeveler',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (ownedFrames.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            const Text('🖼️', style: TextStyle(fontSize: 40)),
                            const SizedBox(height: 8),
                            Text(
                              'Henüz çerçeve satın almadınız',
                              style: TextStyle(color: Colors.white.withOpacity(0.5)),
                            ),
                            const SizedBox(height: 12),
                            ElevatedButton(
                              onPressed: () {
                                Navigator.pop(context);
                                Navigator.pushNamed(context, '/shop');
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
                                  await ShopService.instance.setSelectedCosmetic('', CosmeticType.frame);
                                  Navigator.pop(context);
                                  _loadProfile();
                                },
                                child: Container(
                                  width: 70,
                                  height: 70,
                                  decoration: BoxDecoration(
                                    color: _selectedFrameId == null || _selectedFrameId!.isEmpty
                                        ? Colors.green.withOpacity(0.3)
                                        : Colors.white.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: _selectedFrameId == null || _selectedFrameId!.isEmpty
                                          ? Colors.green
                                          : Colors.transparent,
                                      width: 3,
                                    ),
                                  ),
                                  child: const Center(
                                    child: Icon(Icons.block, color: Colors.white54, size: 32),
                                  ),
                                ),
                              ),
                              ...ownedFrames.map((frame) {
                                final isSelected = _selectedFrameId == frame.id;
                                Color frameColor;
                                if (frame.previewValue == 'gradient') {
                                  frameColor = Colors.purple;
                                } else {
                                  frameColor = Color(int.parse('FF${frame.previewValue}', radix: 16));
                                }
                                return GestureDetector(
                                  onTap: () async {
                                    await ShopService.instance.setSelectedCosmetic(frame.id, CosmeticType.frame);
                                    Navigator.pop(context);
                                    _loadProfile();
                                  },
                                  child: Container(
                                    width: 70,
                                    height: 70,
                                    decoration: BoxDecoration(
                                      gradient: frame.previewValue == 'gradient'
                                          ? const LinearGradient(
                                              colors: [Colors.red, Colors.orange, Colors.yellow, Colors.green, Colors.blue, Colors.purple],
                                            )
                                          : null,
                                      color: frame.previewValue != 'gradient' ? Colors.white.withOpacity(0.1) : null,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: isSelected ? Colors.green : frameColor,
                                        width: isSelected ? 4 : frame.borderWidth.toDouble(),
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: frameColor.withOpacity(0.5),
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

  Widget _buildUserInfo() {
    final joinDate = _profile?.createdAt ?? DateTime.now();
    final formattedDate = '${joinDate.day} ${_getMonthName(joinDate.month)} ${joinDate.year}';
    
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
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(Icons.edit, color: Colors.white54, size: 16),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '$formattedDate tarihinde katıldı',
          style: TextStyle(
            color: Colors.white.withOpacity(0.7),
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.1),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  errorText: errorText,
                  errorStyle: const TextStyle(color: Colors.redAccent),
                  counterStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '• En az 3, en fazla 20 karakter\n• Özel karakterler kullanılamaz\n• Benzersiz olmalı',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.5),
                  fontSize: 12,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('İptal', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              onPressed: isChecking ? null : () async {
                final newName = controller.text.trim();
                
                // Validasyon
                if (newName.length < 3) {
                  setDialogState(() => errorText = 'En az 3 karakter olmalı');
                  return;
                }
                if (newName.length > 20) {
                  setDialogState(() => errorText = 'En fazla 20 karakter olabilir');
                  return;
                }
                // Sadece harf, rakam ve alt çizgi
                final validChars = RegExp(r'^[a-zA-Z0-9_\u00C0-\u017F]+$');
                if (!validChars.hasMatch(newName)) {
                  setDialogState(() => errorText = 'Geçersiz karakterler içeriyor');
                  return;
                }
                // Aynı isimse
                if (newName == _profile?.username) {
                  Navigator.pop(ctx);
                  return;
                }
                
                setDialogState(() {
                  isChecking = true;
                  errorText = null;
                });
                
                // Benzersizlik kontrolü (Firebase'den)
                final isUnique = await FirestoreService.instance.isUsernameUnique(newName);
                
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
                      content: Text('Kullanıcı adı güncellendi!'),
                      backgroundColor: Colors.green,
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
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Text('Kaydet'),
            ),
          ],
        ),
      ),
    );
  }

  String _getMonthName(int month) {
    const months = ['Oca', 'Şub', 'Mar', 'Nis', 'May', 'Haz', 'Tem', 'Ağu', 'Eyl', 'Eki', 'Kas', 'Ara'];
    return months[month - 1];
  }

  Widget _buildMemberBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.cyan.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.cyan, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.diamond, color: Colors.cyan, size: 18),
          const SizedBox(width: 6),
          const Text(
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

  Widget _buildAddFriendsButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const FriendsScreen()));
        },
        icon: const Icon(Icons.person_add, size: 20),
        label: const Text('Add Friends', style: TextStyle(fontWeight: FontWeight.bold)),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF3D7AB8),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, String action) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        TextButton(
          onPressed: () {
            // TODO: Show all stats
          },
          child: Text(
            action,
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildSectionHeaderNoAction(String title) {
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
    final leagueScores = _profile?.leagueScores ?? const LeagueScores();
    final practiceScore = _profile?.practiceScore ?? 0;
    
    // Duel stats
    final matchHistory = _profile?.matchHistory ?? [];
    final totalMatches = matchHistory.length;
    final wins = matchHistory.where((m) => m.userScore > m.opponentScore).length;
    final winRate = totalMatches > 0 ? ((wins / totalMatches) * 100).toStringAsFixed(0) : '0';
    
    return Column(
      children: [
        // Lig Puanları
        _buildSectionTitle('Lig Puanları'),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildLeagueCard('A', leagueScores.beginnerElo, Colors.green),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildLeagueCard('B', leagueScores.intermediateElo, Colors.orange),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildLeagueCard('C', leagueScores.advancedElo, Colors.red),
            ),
          ],
        ),
        const SizedBox(height: 16),
        
        // Practice Puanı
        _buildSectionTitle('Practice Puanı'),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [const Color(0xFFFF9800).withOpacity(0.3), const Color(0xFFFF9800).withOpacity(0.1)],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFFF9800), width: 1),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.school, color: Color(0xFFFF9800), size: 22),
              const SizedBox(width: 10),
              Text(
                '$practiceScore',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 6),
              const Text(
                'puan',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        
        // Practice Seviyesi
        _buildSectionTitle('Practice Seviyesi'),
        const SizedBox(height: 8),
        _buildPracticeLevelCard(),
        const SizedBox(height: 16),
        
        // Duel İstatistikleri
        _buildSectionTitle('Duel İstatistikleri'),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                icon: Icons.sports_esports,
                iconColor: Colors.blue,
                value: '$totalMatches',
                label: 'Toplam Maç',
                bgColor: const Color(0xFF3D7AB8),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildStatCard(
                icon: Icons.emoji_events,
                iconColor: Colors.amber,
                value: '$wins',
                label: 'Galibiyet',
                bgColor: const Color(0xFF4A8C5C),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildStatCard(
                icon: Icons.percent,
                iconColor: Colors.orange,
                value: '%$winRate',
                label: 'Kazanım',
                bgColor: const Color(0xFF8C5A4A),
              ),
            ),
          ],
        ),
      ],
    );
  }
  
  Widget _buildSectionTitle(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildPracticeLevelCard() {
    final currentLevel = _profile?.practiceSession.currentLevel ?? 'A2';
    
    // Seviye rengi
    Color levelColor;
    if (currentLevel.startsWith('A')) {
      levelColor = Colors.green;
    } else if (currentLevel.startsWith('B')) {
      levelColor = Colors.orange;
    } else {
      levelColor = Colors.red;
    }
    
    // Seviye açıklaması
    String levelDescription;
    switch (currentLevel) {
      case 'A1':
        levelDescription = 'Başlangıç';
        break;
      case 'A2':
        levelDescription = 'Temel';
        break;
      case 'B1':
        levelDescription = 'Orta Öncesi';
        break;
      case 'B2':
        levelDescription = 'Orta';
        break;
      case 'C1':
        levelDescription = 'İleri';
        break;
      case 'C2':
        levelDescription = 'Uzman';
        break;
      default:
        levelDescription = 'Temel';
    }
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [levelColor.withOpacity(0.3), levelColor.withOpacity(0.1)],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: levelColor, width: 1),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: levelColor.withOpacity(0.3),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: levelColor, width: 1),
            ),
            child: Text(
              currentLevel,
              style: TextStyle(
                color: levelColor,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                levelDescription,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Mevcut seviye',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildLeagueCard(String league, int score, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.3), color.withOpacity(0.1)],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color, width: 1),
      ),
      child: Column(
        children: [
          Text(
            league,
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$score',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required Color iconColor,
    required String value,
    required String label,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(icon, color: iconColor, size: 28),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAwardsSection() {
    final unlockedAchievements = _achievements.where((a) => a.isUnlocked).toList();
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
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
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: () => _showAllAchievements(),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.amber.withOpacity(0.5)),
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
                          Icon(Icons.arrow_forward_ios, color: Colors.amber, size: 12),
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
                style: TextStyle(color: Colors.white.withOpacity(0.5)),
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
                      color: _getTierColor(achievement.tier).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _getTierColor(achievement.tier)),
                    ),
                    child: Text(achievement.badgeIcon, style: const TextStyle(fontSize: 28)),
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
                color: _getTierColor(achievement.tier).withOpacity(0.3),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _getTierColor(achievement.tier), width: 3),
              ),
              child: Center(
                child: Text(achievement.badgeIcon, style: const TextStyle(fontSize: 44)),
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
                color: Colors.white.withOpacity(0.7),
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            // Ödül bilgisi
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.withOpacity(0.5)),
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
                  color: Colors.white.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    const Icon(Icons.emoji_events, color: Colors.amber, size: 28),
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
                        color: Colors.white.withOpacity(0.7),
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
                            ? _getTierColor(achievement.tier).withOpacity(0.2)
                            : Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isUnlocked 
                              ? _getTierColor(achievement.tier)
                              : Colors.white.withOpacity(0.1),
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
                                  ? _getTierColor(achievement.tier).withOpacity(0.3)
                                  : Colors.white.withOpacity(0.1),
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
                                    color: isUnlocked ? Colors.white : Colors.white54,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  achievement.description,
                                  style: TextStyle(
                                    color: isUnlocked 
                                        ? Colors.white.withOpacity(0.7)
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
                                      value: achievement.currentProgress / achievement.goal,
                                      backgroundColor: Colors.white.withOpacity(0.1),
                                      valueColor: AlwaysStoppedAnimation(
                                        _getTierColor(achievement.tier).withOpacity(0.7),
                                      ),
                                      minHeight: 6,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${achievement.currentProgress} / ${achievement.goal}',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.5),
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
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                              color: Colors.white.withOpacity(0.3),
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
      case AchievementTier.bronze: return const Color(0xFFCD7F32);
      case AchievementTier.silver: return const Color(0xFFC0C0C0);
      case AchievementTier.gold: return const Color(0xFFFFD700);
      case AchievementTier.platinum: return const Color(0xFFE5E4E2);
    }
  }

  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A3A5C),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Çıkış Yap',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Hesabınızdan çıkış yapmak istediğinize emin misiniz?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İptal', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
            ),
            child: const Text('Çıkış Yap', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await AuthService.instance.signOut();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
    }
  }
}
