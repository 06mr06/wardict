import 'package:flutter/material.dart';
import 'dart:async';
import '../../widgets/matchmaking_lugo_dialog.dart';
import 'matchmaking_screen.dart';
import '../../services/user_profile_service.dart';
import '../../models/online_duel.dart';
import 'package:lugorena/services/online_duel_service.dart';

class DuelOptionsScreen extends StatefulWidget {
  const DuelOptionsScreen({super.key});

  @override
  State<DuelOptionsScreen> createState() => _DuelOptionsScreenState();
}

class _DuelOptionsScreenState extends State<DuelOptionsScreen> {
  StreamSubscription? _invitationSubscription;

  @override
  void initState() {
    super.initState();
    // Davetler GlobalInvitationOverlay tarafından dinleniyor.
  }

  @override
  void dispose() {
    _invitationSubscription?.cancel();
    super.dispose();
  }

  Future<void> _onDuelTap(BuildContext context, {required bool isBotDuel, required String duelMode}) async {
    // Bot düellosu için limit kontrolü yok
    if (isBotDuel) {
      // Navigator.push(context, MaterialPageRoute(builder: (_) => DuelScreen(isBotDuel: true)));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$duelMode başlatılıyor... (Navigasyon ayarlanmalı)')),
      );
      return;
    }

    // Online/Buddy düelloları için artık limit yok
    final profile = await UserProfileService.instance.loadProfile();
    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MatchmakingScreen(
            leagueCode: profile.level.code,
          ),
        ),
      );
    }
  }

  Future<void> _showUserUnreachableDialog(BuildContext context) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1A3A5C),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: Colors.blue.withAlpha(128)),
          ),
          title: const Text(
            'Rakip Bulunamadı',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: const Text(
            'Arkadaşına şu an ulaşılamıyor. Dilersen başka bir modda devam edebilirsin.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70),
          ),
          actions: <Widget>[
            TextButton.icon(
              icon: const Icon(Icons.computer, color: Colors.purpleAccent),
              label: const Text('Bot ile Oyna', style: TextStyle(color: Colors.white)),
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _onDuelTap(context, isBotDuel: true, duelMode: 'Bot Düellosu');
              },
            ),
            TextButton.icon(
              icon: const Icon(Icons.public, color: Colors.lightBlueAccent),
              label: const Text('Online Oyna', style: TextStyle(color: Colors.white)),
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _onDuelTap(context, isBotDuel: false, duelMode: 'Online Düello');
              },
            ),
          ],
          actionsAlignment: MainAxisAlignment.center,
        );
      },
    );
  }

  Future<void> _startBuddyDuel(BuildContext context) async {
    showDialog(context: context, barrierDismissible: false, builder: (_) => const MatchmakingLugoDialog(message: 'Arkadaşın aranıyor...'));
    await Future.delayed(const Duration(seconds: 3));
    if (context.mounted) Navigator.pop(context);
    if (context.mounted) await _showUserUnreachableDialog(context);
  }

  void _showInvitationDialog(DuelInvitation invitation) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A3A5C),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Colors.amber, width: 2),
        ),
        title: const Row(
          children: [
            Icon(Icons.notifications_active, color: Colors.amber),
            SizedBox(width: 10),
            Text('Düello Daveti!', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${invitation.fromUser.username} seni düelloya çağırıyor!',
              style: const TextStyle(color: Colors.white, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(26),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Lig: ${invitation.leagueCode}',
                style: const TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Reddet', style: TextStyle(color: Colors.redAccent)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () async {
              Navigator.pop(context);
              // Kabul etme işlemi ve maça yönlendirme
              final match = await OnlineDuelService.instance.acceptDuelInvitationAndGetMatch(invitation);
              if (match != null && context.mounted) {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => MatchmakingScreen(leagueCode: match.leagueCode, existingMatch: match)),
                );
              }
            },
            child: const Text('KABUL ET', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Arka Plan
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF2E5A8C), Color(0xFF1A3A5C)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          // Arka Plan Resmi
          Container(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: const AssetImage('assets/images/welcome.png'), // Resim yolu
                fit: BoxFit.cover,
                colorFilter: ColorFilter.mode(Colors.black.withAlpha(51), BlendMode.dstATop),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
                      ),
                      const Text('Düello Modu', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                      const Spacer(),
                      // Test Butonu (Geliştirme aşaması için)
                      IconButton(
                        icon: const Icon(Icons.notification_add, color: Colors.amber),
                        tooltip: 'Test Davet Gönder',
                        onPressed: () => OnlineDuelService.instance.simulateIncomingInvitation(),
                      ),
                    ],
                  ),
                  const Spacer(flex: 1),
                  // Butonlar
                  _buildDuelOptionButton(
                    context,
                    icon: Icons.public,
                    title: 'LUGO DUEL',
                    subtitle: 'Rastgele bir rakiple oyna',
                    color: Colors.blue,
                    onTap: () => _onDuelTap(context, isBotDuel: false, duelMode: 'Online Düello'),
                  ),
                  const SizedBox(height: 20),
                  _buildDuelOptionButton(
                    context,
                    icon: Icons.people,
                    title: 'BUDDY DUEL',
                    subtitle: 'Arkadaşlarınla kapış',
                    color: Colors.green,
                    onTap: () => _startBuddyDuel(context),
                  ),
                  const SizedBox(height: 20),
                  _buildDuelOptionButton(
                    context,
                    icon: Icons.computer,
                    title: 'BOT DUEL',
                    subtitle: 'Yapay zekaya karşı antrenman yap',
                    color: Colors.purple,
                    onTap: () => _onDuelTap(context, isBotDuel: true, duelMode: 'Bot Düellosu'),
                  ),
                  const Spacer(flex: 2),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDuelOptionButton(BuildContext context, {required IconData icon, required String title, required String subtitle, required Color color, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [color.withAlpha(179), color], begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: color.withAlpha(102), blurRadius: 15, spreadRadius: 2, offset: const Offset(0, 5))],
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 40),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                  Text(subtitle, style: const TextStyle(color: Colors.white70, fontSize: 14)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, color: Colors.white),
          ],
        ),
      ),
    );
  }
}
