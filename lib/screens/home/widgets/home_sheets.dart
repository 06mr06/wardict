import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../providers/language_provider.dart';
import '../../../models/user_level.dart';
import 'package:lugorena/models/online_duel.dart';
import 'package:lugorena/services/firebase/auth_service.dart';
import '../../game/matchmaking_screen.dart';
import '../../friends/friends_screen.dart';
import '../../../providers/practice_provider.dart';
import '../../../providers/fill_blank_practice_provider.dart';
import '../../game/fill_blank_practice_screen.dart';
import '../../../widgets/home/weekly_practice_progress_bar.dart';
import '../../shop/shop_screen.dart';

class HomeSheets {
  static void showCategorySelection({
    required BuildContext context,
    required List<String> unlockedPacks,
    required String userLevel,
    required String practiceLevelCode,
    required VoidCallback onUserDataRefresh,
  }) {
    Set<String> selectedPacks = {'base'};

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(builder: (context, setModalState) {
        final language = context.read<LanguageProvider>();

        final allPacks = [
          {
            'id': 'phrasals',
            'name': 'Phrasal Verbs',
            'icon': Icons.bolt,
            'color': Colors.blue
          },
          {
            'id': 'adjectives',
            'name': 'Sıfatlar (Adjectives)',
            'icon': Icons.star,
            'color': Colors.purple
          },
          {
            'id': 'verbs',
            'name': 'Fiiller (Verbs)',
            'icon': Icons.directions_run,
            'color': Colors.green
          },
          {
            'id': 'adverbs',
            'name': 'Zarflar (Adverbs)',
            'icon': Icons.fast_forward,
            'color': Colors.teal
          },
          {
            'id': 'idioms',
            'name': 'Deyimler (Idioms)',
            'icon': Icons.format_quote,
            'color': Colors.amber
          },
          {
            'id': 'nouns',
            'name': 'İsimler (Nouns)',
            'icon': Icons.category,
            'color': Colors.deepOrange
          },
        ];

        final mq = MediaQuery.of(context);
        final sheetH = mq.size.height * 0.94;

        return Container(
          height: sheetH,
          decoration: const BoxDecoration(
            color: Color(0xFF1A3A5C),
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          padding: EdgeInsets.fromLTRB(24, mq.padding.top + 10, 24, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                language.getString('select_category'),
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                language.getString('select_category_desc'),
                style: const TextStyle(color: Colors.white60, fontSize: 14),
              ),
              const SizedBox(height: 10),
              const WeeklyPracticeProgressBar(compact: true),
              const SizedBox(height: 14),
              _buildCategoryItem(
                title: language.getString('practice_fill_blank_title'),
                subtitle: language.format('practice_fill_blank_sheet_subtitle', {
                  'level': practiceLevelCode,
                }),
                icon: Icons.article_outlined,
                color: const Color(0xFF7E57C2),
                isActive: true,
                isSelected: false,
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push<void>(
                    context,
                    MaterialPageRoute<void>(
                      builder: (ctx) => ChangeNotifierProvider(
                        create: (_) => FillBlankPracticeProvider(),
                        child: FillBlankPracticeScreen(
                          userLevelCode: practiceLevelCode,
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 10),
              _buildCategoryItem(
                title: '$userLevel TEST',
                subtitle: 'Seviyene uygun tüm kelimeler',
                icon: Icons.auto_awesome,
                color: const Color(0xFF26A69A),
                isSelected: selectedPacks.contains('base'),
                onTap: () {
                  setModalState(() {
                    if (selectedPacks.contains('base')) {
                      selectedPacks.remove('base');
                    } else {
                      selectedPacks.add('base');
                    }
                  });
                },
                isActive: true,
              ),
              const SizedBox(height: 10),
              Text(
                language.getString('special_packs'),
                style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ListView.builder(
                        padding: const EdgeInsets.only(bottom: 28),
                        physics: const BouncingScrollPhysics(
                          parent: AlwaysScrollableScrollPhysics(),
                        ),
                        itemCount: allPacks.length,
                        itemBuilder: (context, index) {
                          final pack = allPacks[index];
                          final String packId = pack['id'] as String;
                          final bool isUnlocked =
                              unlockedPacks.contains(packId);

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _buildCategoryItem(
                              title: pack['name'] as String,
                              subtitle: isUnlocked
                                  ? language.getString('pack_desc_unlocked')
                                  : language.getString('pack_desc_locked'),
                              icon: pack['icon'] as IconData,
                              color: pack['color'] as Color,
                              isActive: isUnlocked,
                              isSelected: selectedPacks.contains(packId),
                              dense: true,
                              onTap: () {
                                if (isUnlocked) {
                                  setModalState(() {
                                    if (selectedPacks.contains(packId)) {
                                      selectedPacks.remove(packId);
                                    } else {
                                      selectedPacks.add(packId);
                                    }
                                  });
                                } else {
                                  Navigator.pop(context);
                                  Navigator.of(context)
                                      .push(
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              const ShopScreen(
                                                  initialTabIndex: 1),
                                        ),
                                      )
                                      .then((_) => onUserDataRefresh());
                                }
                              },
                            ),
                          );
                        },
                      ),
                      if (allPacks.length > 2)
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          height: 40,
                          child: IgnorePointer(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    const Color(0xFF1A3A5C)
                                        .withValues(alpha: 0),
                                    const Color(0xFF1A3A5C)
                                        .withValues(alpha: 0.92),
                                  ],
                                ),
                              ),
                              child: Align(
                                alignment: Alignment.bottomCenter,
                                child: Padding(
                                  padding: const EdgeInsets.only(bottom: 2),
                                  child: Icon(
                                    Icons.keyboard_arrow_down_rounded,
                                    color: Colors.white
                                        .withValues(alpha: 0.55),
                                    size: 28,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: selectedPacks.isEmpty
                      ? null
                      : () {
                          Provider.of<PracticeProvider>(context, listen: false)
                              .setSelectedPacks(selectedPacks.toList());
                          Navigator.pop(context);
                          Navigator.pushNamed(context, '/7030');
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    disabledBackgroundColor: Colors.grey.withValues(alpha: 0.3),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Text(
                    language.getString('start_practice_btn'),
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  static void showDuelSelectionDialog({
    required BuildContext context,
    required VoidCallback onLugoDuel,
    required VoidCallback onBotDuel,
    required VoidCallback onUserDataRefresh,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF2E5A8C), Color(0xFF1A3A5C)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  context
                      .read<LanguageProvider>()
                      .getString('select_duel_mode'),
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white54),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              context.read<LanguageProvider>().getString('how_to_compete'),
              style: const TextStyle(color: Colors.white60, fontSize: 16),
            ),
            const SizedBox(height: 24),
            _buildDuelOption(
              title:
                  context.read<LanguageProvider>().getString('lugo_duel_title'),
              subtitle:
                  context.read<LanguageProvider>().getString('lugo_duel_desc'),
              icon: Icons.public,
              color: Colors.blue,
              onTap: onLugoDuel,
            ),
            const SizedBox(height: 16),
            _buildDuelOption(
              title: context
                  .read<LanguageProvider>()
                  .getString('buddy_duel_title'),
              subtitle:
                  context.read<LanguageProvider>().getString('buddy_duel_desc'),
              icon: Icons.people,
              color: Colors.pink,
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const FriendsScreen()),
                ).then((_) => onUserDataRefresh());
              },
            ),
            const SizedBox(height: 16),
            _buildDuelOption(
              title:
                  context.read<LanguageProvider>().getString('bot_duel_title'),
              subtitle:
                  context.read<LanguageProvider>().getString('bot_duel_desc'),
              icon: Icons.smart_toy,
              color: Colors.teal,
              onTap: onBotDuel,
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  static Widget _buildCategoryItem({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    bool isActive = true,
    bool isSelected = false,
    bool dense = false,
  }) {
    final double opacity = isActive ? 1.0 : 0.4;
    final pad = dense ? 12.0 : 16.0;
    final iconPad = dense ? 8.0 : 10.0;
    final titleSize = dense ? 15.0 : 16.0;
    final subSize = dense ? 11.0 : 12.0;
    final trailing = dense ? 22.0 : 24.0;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: EdgeInsets.all(pad),
        decoration: BoxDecoration(
          color: isActive
              ? (isSelected
                  ? color.withValues(alpha: 0.15)
                  : Colors.white.withValues(alpha: 0.05))
              : Colors.black.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected && isActive
                ? color.withValues(alpha: 0.5)
                : Colors.white.withValues(alpha: 0.1),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Opacity(
          opacity: opacity,
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(iconPad),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: dense ? 22 : 24),
              ),
              SizedBox(width: dense ? 12 : 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: titleSize,
                            fontWeight: FontWeight.bold)),
                    Text(subtitle,
                        style: TextStyle(
                            color: Colors.white60, fontSize: subSize)),
                  ],
                ),
              ),
              if (isActive)
                Icon(
                    isSelected
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    color: isSelected ? color : Colors.white24,
                    size: trailing)
              else
                Icon(Icons.lock,
                    color: Colors.white24, size: dense ? 18 : 20),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _buildDuelOption({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(subtitle,
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6), fontSize: 14)),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios,
                color: Colors.white.withValues(alpha: 0.3), size: 16),
          ],
        ),
      ),
    );
  }

  static void showNotificationMenu({
    required BuildContext context,
    required UserProfile? userProfile,
    required OnlineDuelMatch? resumableDuel,
    required int pendingInvitationsCount,
    required VoidCallback onUserDataRefresh,
  }) {
    final lp = context.read<LanguageProvider>();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1E3A5F), Color(0xFF0F2027)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                const Icon(Icons.notifications_active_rounded,
                    color: Colors.amber, size: 28),
                const SizedBox(width: 12),
                Text(
                  lp.getString('notifications').toUpperCase(),
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            if (resumableDuel != null) ...[
              _buildNotificationItem(
                title: lp.getString('resume_duel'),
                subtitle:
                    '${resumableDuel.opponentUsername(context.read<AuthService>().userId) ?? (lp.currentLanguage == 'tr' ? 'Rakip Bekleniyor' : 'Searching for Opponent')} ile devam eden oyun',
                icon: Icons.bolt,
                color: const Color(0xFF2AA7FF),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => MatchmakingScreen(
                                leagueCode: userProfile?.level.code ?? 'A1',
                                existingMatch: resumableDuel,
                              )));
                },
              ),
              const SizedBox(height: 12),
            ],
            _buildNotificationItem(
              title: lp.getString('friends'),
              subtitle: pendingInvitationsCount > 0
                  ? '$pendingInvitationsCount yeni düello daveti'
                  : 'Düello davetlerini ve arkadaşlarını gör',
              icon: Icons.people_alt_rounded,
              color: const Color(0xFFFF4081),
              badge: pendingInvitationsCount,
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const FriendsScreen()))
                    .then((_) => onUserDataRefresh());
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  static Widget _buildNotificationItem({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    int badge = 0,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
                border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            if (badge > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.red.withValues(alpha: 0.4), blurRadius: 8),
                  ],
                ),
                child: Text(
                  '$badge',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold),
                ),
              )
            else
              const Icon(Icons.chevron_right_rounded,
                  color: Colors.white24, size: 20),
          ],
        ),
      ),
    );
  }
}
