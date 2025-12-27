import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/home/welcome_screen.dart';
import 'screens/game/game_screen.dart';
import 'screens/game/duel_screen.dart';
import 'screens/game/practice_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'screens/shop/shop_screen.dart';
import 'providers/game_provider.dart';
import 'providers/practice_provider.dart';

class WardictApp extends StatelessWidget {
  const WardictApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => GameProvider()),
        ChangeNotifierProvider(create: (_) => PracticeProvider()),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'WARDICT',
        initialRoute: '/',
        routes: {
          '/': (_) => const WelcomeScreen(),
          '/practice': (_) => const PracticeScreen(),
          '/practice-old': (_) => const GameScreen(), // Eski practice screen
          '/duel': (_) => const DuelScreen(),
          '/profile': (_) => const ProfileScreen(),
          '/shop': (_) => const ShopScreen(),
        },
      ),
    );
  }
}
