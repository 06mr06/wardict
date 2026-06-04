import 'dart:async';
import 'package:flutter/material.dart';
import '../../widgets/game/game_background.dart';
import '../../services/sound_service.dart';

abstract class BaseGameScreen extends StatefulWidget {
  const BaseGameScreen({super.key});
}

abstract class BaseGameScreenState<T extends BaseGameScreen> extends State<T>
    with TickerProviderStateMixin {
  // Common State
  bool showPreScreen = true;
  bool showCountdown = true;
  int countdown = 3;
  int timeLeft = 7;
  Timer? timer;
  
  // Animation Controllers
  late AnimationController animController;
  late Animation<double> fadeAnim;
  late Animation<Offset> slideAnim;
  
  // Background customization
  String? get backgroundImage => null;
  double get imageOpacity => 0.3;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    // Subclasses should call startPreGame() or similar
  }

  void _initAnimations() {
    animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    fadeAnim = Tween<double>(begin: 1, end: 0).animate(animController);
    slideAnim = Tween<Offset>(
      begin: const Offset(0, 0),
      end: const Offset(0, -0.6),
    ).animate(CurvedAnimation(
      parent: animController,
      curve: Curves.easeOut,
    ));
  }

  void startPreGame() {
    setState(() {
      showPreScreen = true;
      showCountdown = true;
      countdown = 3;
    });
    SoundService.instance.playCountdown();
    _runCountdown();
  }

  void _runCountdown() {
    Future.delayed(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      SoundService.instance.playCountdown();
      setState(() => countdown = 2);
      Future.delayed(const Duration(milliseconds: 300), () {
        if (!mounted) return;
        SoundService.instance.playCountdown();
        setState(() => countdown = 1);
        Future.delayed(const Duration(milliseconds: 300), () {
          if (!mounted) return;
          setState(() {
            showCountdown = false;
            showPreScreen = false;
          });
          onGameStart();
          startTimer();
        });
      });
    });
  }

  void startTimer() {
    timer?.cancel();
    setState(() => timeLeft = 7);
    timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (timeLeft == 0) {
        t.cancel();
        onTimeUp();
      } else {
        setState(() => timeLeft--);
      }
    });
  }

  // Abstract / Hook methods
  void onGameStart(); // Called when countdown finishes
  void onTimeUp();    // Called when timer hits 0

  @override
  void dispose() {
    timer?.cancel();
    animController.dispose();
    super.dispose();
  }

  // UI Building Blocks
  Widget buildHeader(BuildContext context);
  
  Widget buildContent(BuildContext context);

  @override
  Widget build(BuildContext context) {
    if (showPreScreen) {
      return buildPreScreen(context);
    }
    
    return Scaffold(
      body: GameBackground(
        backgroundImage: backgroundImage,
        imageOpacity: imageOpacity,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              buildHeader(context),
              const SizedBox(height: 16),
              buildContent(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildPreScreen(BuildContext context) {
    // Default implementation, can be overridden
    return Scaffold(
      body: GameBackground(
        backgroundImage: backgroundImage,
        imageOpacity: imageOpacity,
        child: Center(
           child: buildCountdown(),
        ),
      ),
    );
  }

  Widget buildCountdown() {
      if (!showCountdown) return const SizedBox.shrink();
      return TweenAnimationBuilder<double>(
        key: ValueKey(countdown),
        tween: Tween(begin: 0.5, end: 1.0),
        duration: const Duration(milliseconds: 400),
        curve: Curves.elasticOut,
        builder: (context, scale, child) {
          return Transform.scale(
            scale: scale,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: countdown == 1
                      ? [Colors.green.shade400, Colors.green.shade700]
                      : countdown == 2
                          ? [Colors.orange.shade400, Colors.orange.shade700]
                          : [Colors.red.shade400, Colors.red.shade700],
                ),
                boxShadow: [
                  BoxShadow(
                    color: (countdown == 1
                            ? Colors.green
                            : countdown == 2
                                ? Colors.orange
                                : Colors.red)
                        .withAlpha(128),
                    blurRadius: 30,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '$countdown',
                    style: const TextStyle(
                      fontSize: 64,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      );
  }
}
