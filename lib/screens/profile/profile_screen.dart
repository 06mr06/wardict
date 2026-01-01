import 'package:flutter/material.dart';
import '../../models/user_level.dart';
import '../../models/league.dart';
import '../../models/match_history_item.dart';
import '../../services/user_profile_service.dart';
import '../../services/firebase/auth_service.dart';
import '../../services/firebase/firestore_service.dart';
import '../friends/friends_screen.dart';
import '../auth/login_screen.dart';
import 'my_words_screen.dart';
import '../../models/cosmetic_item.dart';
import '../../models/achievement.dart';
import '../../services/shop_service.dart';
import '../../services/achievement_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  UserProfile? _profile;
  List<Achievement> _achievements = [];
  Map<String, int> _leagueRanks = {'A': 0, 'B': 0, 'C': 0};
  bool _isLoading = true;
  final _usernameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final profile = await UserProfileService.instance.loadProfile();
    final achievements = await AchievementService.instance.getAchievements();
    
    // Lig sıralamalarını Firestore'dan çek
    Map<String, int> ranks = {'A': 0, 'B': 0, 'C': 0};
    final userId = AuthService.instance.userId;
    if (userId != null) {
      ranks = await FirestoreService.instance.getUserLeagueRanks(userId);
    }
    
    setState(() {
      _profile = profile;
      _achievements = achievements;
      _leagueRanks = ranks;
      _usernameController.text = profile.username;
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _updateUsername(String newUsername) async {
    if (_profile == null || newUsername.trim().isEmpty) return;
    final updatedProfile = _profile!.copyWith(username: newUsername.trim());
    await UserProfileService.instance.saveProfile(updatedProfile);
    setState(() => _profile = updatedProfile);
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
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // Header with back button
                Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                    ),
                    const Expanded(
                      child: Text(
                        'Profil',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 48), // Balance the back button
                  ],
                ),
                const SizedBox(height: 16),

                // Profile Picture
                _buildProfilePicture(),
                const SizedBox(height: 12),

                // Username
                _buildUsernameSection(),
                const SizedBox(height: 16),

                // League Scores
                _buildLeagueScoresSection(),
                const SizedBox(height: 12),

                // Practice Score
                _buildPracticeScoreSection(),
                const SizedBox(height: 12),

                // Statistics
                _buildStatisticsSection(),
                const SizedBox(height: 12),

                // History Section
                _buildMatchHistorySection(),
                const SizedBox(height: 12),

                // Friends Button
                _buildFriendsButton(),
                const SizedBox(height: 12),

                // Awards Section
                _buildAwardsSection(),
                const SizedBox(height: 16),
                
                // Çıkış Yap Butonu
                _buildLogoutButton(),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfilePicture() {
    return GestureDetector(
      onTap: _showAvatarSelectionDialog,
      child: Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            colors: [Color(0xFF6C27FF), Color(0xFF2AA7FF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: Colors.white.withOpacity(0.3), width: 2),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF6C27FF).withOpacity(0.4),
              blurRadius: 16,
              spreadRadius: 1,
            ),
          ],
        ),
        child: _profile?.avatarId != null && _profile!.avatarId!.isNotEmpty
            ? Center(
                child: Text(
                  CosmeticItem.availableItems.where((i) => i.id == _profile!.avatarId).isNotEmpty
                      ? CosmeticItem.availableItems.firstWhere((i) => i.id == _profile!.avatarId).previewValue
                      : '👤',
                  style: const TextStyle(fontSize: 52),
                ),
              )
            : _buildDefaultAvatar(),
      ),
    );
  }

  void _showAvatarSelectionDialog() async {
    final unlocked = await ShopService.instance.getUnlockedCosmetics();
    final avatars = CosmeticItem.availableItems.where((i) => i.type == CosmeticType.avatar).toList();

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Color(0xFF2E5A8C),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Avatar Seç',
              style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            GridView.builder(
              shrinkWrap: true,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
              ),
              itemCount: avatars.length,
              itemBuilder: (context, index) {
                final avatar = avatars[index];
                final isUnlocked = unlocked.contains(avatar.id);
                final isSelected = _profile?.avatarId == avatar.id;

                return GestureDetector(
                  onTap: isUnlocked ? () async {
                    await UserProfileService.instance.updateAvatar(avatar.id);
                    Navigator.pop(context);
                    _loadProfile();
                  } : () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Bu avatar henüz kilitli! Marketten alabilirsin.')),
                    );
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFF6C27FF).withOpacity(0.3) : Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected ? const Color(0xFF6C27FF) : (isUnlocked ? Colors.white24 : Colors.transparent),
                        width: 2,
                      ),
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Text(avatar.previewValue, style: const TextStyle(fontSize: 32)),
                        if (!isUnlocked)
                          Container(
                            decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(16)),
                            child: const Icon(Icons.lock, color: Colors.white, size: 20),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
             const SizedBox(height: 12),
             TextButton(
               onPressed: () async {
                 await UserProfileService.instance.updateAvatar(null);
                 Navigator.pop(context);
                 _loadProfile();
               },
               child: const Text('Avatarı Sıfırla', style: TextStyle(color: Colors.white60)),
             ),
          ],
        ),
      ),
    );
  }

  Widget _buildDefaultAvatar() {
    return Center(
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
    );
  }

  Widget _buildUsernameSection() {
    final email = _profile?.email ?? AuthService.instance.userEmail;
    
    return Column(
      children: [
        GestureDetector(
          onTap: () => _showEditUsernameDialog(),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.2)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _profile?.username ?? 'Player',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 10),
                Icon(
                  Icons.edit,
                  color: Colors.white.withOpacity(0.6),
                  size: 20,
                ),
              ],
            ),
          ),
        ),
        if (email != null && email.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            email,
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 14,
            ),
          ),
        ],
      ],
    );
  }

  void _showEditUsernameDialog() {
    _usernameController.text = _profile?.username ?? '';
    bool isChecking = false;
    String? errorText;
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF2E5A8C),
          title: const Text('Kullanıcı Adını Değiştir', style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _usernameController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Kullanıcı adı (benzersiz olmalı)',
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                  errorText: errorText,
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: Color(0xFF2AA7FF)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: Colors.red),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedErrorBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: Colors.red),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              if (isChecking) ...[
                const SizedBox(height: 12),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white54),
                    ),
                    SizedBox(width: 8),
                    Text('Kontrol ediliyor...', style: TextStyle(color: Colors.white54, fontSize: 12)),
                  ],
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('İptal', style: TextStyle(color: Colors.white70)),
            ),
            ElevatedButton(
              onPressed: isChecking ? null : () async {
                final newUsername = _usernameController.text.trim();
                
                if (newUsername.isEmpty || newUsername.length < 3) {
                  setDialogState(() => errorText = 'En az 3 karakter olmalı');
                  return;
                }
                
                if (newUsername == _profile?.username) {
                  Navigator.pop(context);
                  return;
                }
                
                setDialogState(() {
                  isChecking = true;
                  errorText = null;
                });
                
                // Benzersizlik kontrolü
                final isUnique = await FirestoreService.instance.isUsernameUnique(newUsername);
                
                if (!isUnique) {
                  setDialogState(() {
                    isChecking = false;
                    errorText = 'Bu kullanıcı adı zaten kullanılıyor';
                  });
                  return;
                }
                
                await _updateUsername(newUsername);
                if (context.mounted) Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2AA7FF),
              ),
              child: const Text('Kaydet', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLevelSection() {
    final level = _profile?.level ?? UserLevel.a1;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _getLevelColor(level).withOpacity(0.3),
            _getLevelColor(level).withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _getLevelColor(level), width: 2),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: _getLevelColor(level),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              level.code,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                level.turkishName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Mevcut Seviye',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLeagueScoresSection() {
    final scores = _profile?.leagueScores ?? const LeagueScores();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Lig Puanları',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildLeagueScoreCard(
                League.beginner,
                scores.beginnerElo,
                Colors.green,
                _leagueRanks['A'] ?? 0,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildLeagueScoreCard(
                League.intermediate,
                scores.intermediateElo,
                Colors.orange,
                _leagueRanks['B'] ?? 0,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildLeagueScoreCard(
                League.advanced,
                scores.advancedElo,
                Colors.red,
                _leagueRanks['C'] ?? 0,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLeagueScoreCard(League league, int score, Color color, int rank) {
    final rankText = rank > 0 ? '#$rank' : '-';
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.3), color.withOpacity(0.1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.5), width: 1),
      ),
      child: Column(
        children: [
          Text(
            league.name,
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            '${league.code}$score',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            rankText,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPracticeScoreSection() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFFFF9800).withOpacity(0.3),
            const Color(0xFFFF9800).withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFF9800), width: 1),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.school, color: Color(0xFFFF9800), size: 22),
          const SizedBox(width: 10),
          const Text(
            'Practice Puanı',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 13,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${_profile?.practiceScore ?? 0}',
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

  Widget _buildStatisticsSection() {
    // Duel istatistikleri hesapla
    final matchHistory = _profile?.matchHistory ?? [];
    final totalMatches = matchHistory.length;
    final wins = matchHistory.where((m) => m.userScore > m.opponentScore).length;
    final winRate = totalMatches > 0 ? ((wins / totalMatches) * 100).toStringAsFixed(0) : '0';
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.sports_esports, color: Color(0xFF2AA7FF), size: 20),
              SizedBox(width: 8),
              Text(
                'Duel İstatistik',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildStatCard('Maç', '$totalMatches', const Color(0xFF2AA7FF)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildStatCard('Galibiyet', '$wins', Colors.green),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildStatCard('Oran', '%$winRate', Colors.orange),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 13,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  Widget _buildAwardsSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.emoji_events_rounded, color: Color(0xFFFFD700), size: 28),
                  SizedBox(width: 12),
                  Text(
                    'Başarımlar',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Text(
                '${_achievements.where((a) => a.isUnlocked).length} / 20',
                style: const TextStyle(color: Colors.white60, fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 20),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 0.85,
            ),
            itemCount: _achievements.length,
            itemBuilder: (context, index) {
              final achievement = _achievements[index];
              return _buildAchievementBadge(achievement);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAchievementBadge(Achievement achievement) {
    return GestureDetector(
      onTap: () => _showAchievementDetail(achievement),
      child: Column(
        children: [
          Expanded(
            child: AspectRatio(
              aspectRatio: 1,
              child: Container(
                decoration: BoxDecoration(
                  color: achievement.isUnlocked 
                    ? _getTierColor(achievement.tier).withOpacity(0.15) 
                    : Colors.black.withOpacity(0.3),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: achievement.isUnlocked 
                      ? _getTierColor(achievement.tier) 
                      : Colors.white10,
                    width: 2,
                  ),
                  boxShadow: achievement.isUnlocked ? [
                    BoxShadow(
                      color: _getTierColor(achievement.tier).withOpacity(0.3),
                      blurRadius: 10,
                      spreadRadius: 1,
                    )
                  ] : null,
                ),
                child: Center(
                  child: achievement.isUnlocked
                    ? Text(achievement.badgeIcon, style: const TextStyle(fontSize: 28))
                    : Icon(Icons.lock_rounded, color: Colors.white.withOpacity(0.2), size: 20),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              achievement.title.split(' ')[0], // İlk kelimeyi göster (yer sıkıntısı için)
              style: TextStyle(
                color: achievement.isUnlocked ? Colors.white : Colors.white38,
                fontSize: 10,
                fontWeight: achievement.isUnlocked ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ],
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

  void _showAchievementDetail(Achievement achievement) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2E5A8C),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _getTierColor(achievement.tier).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Text(achievement.badgeIcon, style: const TextStyle(fontSize: 64)),
            ),
            const SizedBox(height: 20),
            Text(
              achievement.title,
              style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              achievement.description,
              style: const TextStyle(color: Colors.white70, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            if (!achievement.isUnlocked) ...[
              LinearProgressIndicator(
                value: achievement.progressPercentage,
                backgroundColor: Colors.white10,
                color: _getTierColor(achievement.tier),
              ),
              const SizedBox(height: 8),
              Text(
                '${achievement.currentProgress} / ${achievement.goal}',
                style: const TextStyle(color: Colors.white60, fontSize: 14),
              ),
            ] else 
              const Text('✅ Açıldı', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Kapat', style: TextStyle(color: Colors.white60)),
          ),
        ],
      ),
    );
  }

  Widget _buildFriendsButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const FriendsScreen()),
          );
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF4CAF50),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 4,
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people, size: 24),
            SizedBox(width: 10),
            Text(
              'Arkadaşlar',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMyWordsButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const MyWordsScreen()),
          );
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF9C27B0), // Purple
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 4,
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.book, size: 24),
            SizedBox(width: 10),
            Text(
              'Kelimelerim',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAwardBadge(String award) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        award,
        style: const TextStyle(
          color: Colors.black87,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
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

  Widget _buildMatchHistorySection() {
    final history = _profile?.matchHistory ?? [];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Son Maçlar',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          if (history.isEmpty)
            Text(
              'Henüz maç geçmişi yok.',
              style: TextStyle(color: Colors.white.withOpacity(0.5)),
            )
          else
            ...history.take(5).map((match) {
              final isWin = match.isWin;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isWin 
                      ? Colors.green.withOpacity(0.1) 
                      : Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isWin 
                        ? Colors.green.withOpacity(0.3) 
                        : Colors.red.withOpacity(0.3)
                  ),
                ),
                child: Row(
                  children: [
                    Text(
                      isWin ? '🏆' : '💀',
                      style: const TextStyle(fontSize: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            match.opponentName,
                            style: const TextStyle(
                              color: Colors.white, 
                              fontWeight: FontWeight.bold
                            ),
                          ),
                          Text(
                            _formatDate(match.date),
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.5), 
                              fontSize: 10
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${match.userScore} - ${match.opponentScore}',
                          style: TextStyle(
                            color: isWin ? Colors.greenAccent : Colors.redAccent,
                            fontSize: 16, 
                            fontWeight: FontWeight.bold
                          ),
                        ),
                        if (match.eloChange != 0)
                          Text(
                            '${match.eloChange > 0 ? '+' : ''}${match.eloChange} LP',
                            style: TextStyle(
                              color: isWin ? Colors.green : Colors.red,
                              fontSize: 10
                            ),
                          ),
                      ],
                    )
                  ],
                ),
              );
            }).toList(),
        ],
      ),
    );
  }

  Widget _buildLogoutButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _handleLogout,
        icon: const Icon(Icons.logout, color: Colors.white),
        label: const Text(
          'Çıkış Yap',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red.shade700,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }

  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2E5A8C),
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
