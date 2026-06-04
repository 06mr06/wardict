import 'dart:async';
import 'package:flutter/material.dart';
import 'package:lugorena/models/online_duel.dart';
import '../app.dart';
import '../screens/game/matchmaking_screen.dart';
import 'package:lugorena/services/online_duel_service.dart';
import '../services/firebase/auth_service.dart';

class GlobalInvitationOverlay extends StatefulWidget {
  final Widget child;

  const GlobalInvitationOverlay({super.key, required this.child});

  @override
  State<GlobalInvitationOverlay> createState() => _GlobalInvitationOverlayState();
}

class _GlobalInvitationOverlayState extends State<GlobalInvitationOverlay> with SingleTickerProviderStateMixin {
  StreamSubscription? _sub;
  OverlayEntry? _overlayEntry;
  late AnimationController _animController;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutBack,
    ));

    // Davetleri dinlemeye başla
    _initListener();
    
    // Auth durumunu dinle, değişince dinleyiciyi yenile
    AuthService.instance.addListener(_handleAuthChange);
    
    _sub = OnlineDuelService.instance.onInvitationReceived.listen((invitation) {
      debugPrint('🔥 GlobalInvitationOverlay: Invitation received in stream!');
      if (mounted) {
        _showOverlay(invitation);
      } else {
        debugPrint('🔥 GlobalInvitationOverlay: Error - Widget NOT mounted!');
      }
    });
  }

  void _handleAuthChange() {
    if (AuthService.instance.isAuthenticated) {
      debugPrint('👤 GlobalInvitationOverlay: User authenticated, refreshing listener');
      _initListener();
    } else {
      debugPrint('👤 GlobalInvitationOverlay: User unauthenticated, stopping listener');
      OnlineDuelService.instance.stopInvitationListener();
    }
  }

  void _initListener() {
    OnlineDuelService.instance.startInvitationListener();
  }

  @override
  void dispose() {
    AuthService.instance.removeListener(_handleAuthChange);
    _sub?.cancel();
    _animController.dispose();
    super.dispose();
  }

  void _showOverlay(DuelInvitation invitation) {
    debugPrint('🔥 GlobalInvitationOverlay: _showOverlay called for ${invitation.fromUser.username}');
    if (_overlayEntry != null) {
        debugPrint('🔥 GlobalInvitationOverlay: Overlay already showing!');
        return;
    }
    
    final contextForOverlay = navigatorKey.currentState?.overlay?.context;
    if (contextForOverlay == null) {
        debugPrint('🔥 GlobalInvitationOverlay: ERROR - contextForOverlay is NULL! (Navigator state: ${navigatorKey.currentState})');
        return;
    }

    double topPadding = 20;
    try {
      topPadding = MediaQuery.of(context).padding.top + 10;
    } catch (e) {
      debugPrint('⚠️ MediaQuery failed in overlay: $e');
    }

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: topPadding,
        left: 16,
        right: 16,
        child: Material(
          color: Colors.transparent,
          child: SlideTransition(
            position: _slideAnimation,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF2E5A8C),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(128),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
                border: Border.all(color: Colors.orange, width: 2),
              ),
              child: Row(
                children: [
                  const Icon(Icons.notifications_active, color: Colors.orange, size: 32),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Düello Daveti!',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        Text(
                          '${invitation.fromUser.username} seni maça davet ediyor.',
                          style: const TextStyle(color: Colors.white70, fontSize: 13),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.redAccent),
                        onPressed: () async {
                          await _animController.reverse();
                          OnlineDuelService.instance.declineDuelInvitation(invitation);
                          _removeOverlay();
                        },
                      ),
                      ElevatedButton(
                        onPressed: () async {
                          await _animController.reverse();
                          _removeOverlay();
                          
                          final navContext = navigatorKey.currentContext;
                          if (navContext == null) return;
                          
                          // Loading Indicator
                          showDialog(
                            context: navContext,
                            barrierDismissible: false,
                            builder: (c) => const Center(child: CircularProgressIndicator(color: Colors.orange)),
                          );
                          
                          final match = await OnlineDuelService.instance.acceptDuelInvitationAndGetMatch(invitation);
                          
                          // Hide Loading Indicator
                          if (navigatorKey.currentContext != null) {
                            Navigator.pop(navigatorKey.currentContext!);
                          }
                          
                          if (match != null) {
                            Navigator.of(navContext).push(
                              MaterialPageRoute(builder: (_) => MatchmakingScreen(leagueCode: match.leagueCode, existingMatch: match)),
                            );
                          } else {
                            ScaffoldMessenger.of(navContext).showSnackBar(
                              const SnackBar(content: Text('Maça katılamadım.')),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text('Kabul Et', style: TextStyle(color: Colors.white, fontSize: 13)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    navigatorKey.currentState?.overlay?.insert(_overlayEntry!);
    _animController.forward();
    
    // Ses çal (Zil işareti olarak isteniyordu, eğer sistemde sound service var ise kullanılabilir)
    // Şimdilik UI ile sınırlandırıyoruz.
    
    // Oto-kapanma 15 saniye sonra
    Future.delayed(const Duration(seconds: 15), () {
      if (_overlayEntry != null) {
        _animController.reverse().then((_) {
          OnlineDuelService.instance.declineDuelInvitation(invitation);
          _removeOverlay();
        });
      }
    });
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
