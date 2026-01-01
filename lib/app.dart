import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/home/welcome_screen.dart';
import 'screens/game/game_screen.dart';
import 'screens/game/duel_screen.dart';
import 'screens/game/practice_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'screens/shop/shop_screen.dart';
import 'screens/auth/login_screen.dart';
import 'providers/game_provider.dart';
import 'providers/practice_provider.dart';
import 'providers/daily_123_provider.dart';
import 'services/firebase/auth_service.dart';

class WardictApp extends StatelessWidget {
  const WardictApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => GameProvider()),
        ChangeNotifierProvider(create: (_) => PracticeProvider()),
        ChangeNotifierProvider(create: (_) => Daily123Provider()),
        ChangeNotifierProvider.value(value: AuthService.instance),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'WARDICT',
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF6C27FF),
            brightness: Brightness.dark,
          ),
        ),
        home: const AuthWrapper(),
        routes: {
          '/login': (_) => const LoginScreen(),
          '/home': (_) => const WelcomeScreen(),
          '/practice': (_) => const PracticeScreen(),
          '/practice-old': (_) => const GameScreen(),
          '/duel': (_) => const DuelScreen(),
          '/profile': (_) => const ProfileScreen(),
          '/shop': (_) => const ShopScreen(),
        },
      ),
    );
  }
}

/// Kullanıcı giriş durumuna göre yönlendirme yapan widget
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthService>(
      builder: (context, authService, _) {
        // Auth durumunu kontrol et
        switch (authService.status) {
          case AuthStatus.initial:
            // İlk yükleme - splash ekranı
            return Scaffold(
              backgroundColor: const Color(0xFF1A3A5C),
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(
                      'assets/images/welcome.png',
                      width: 200,
                      height: 200,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(height: 24),
                    const CircularProgressIndicator(
                      color: Color(0xFFFFD700),
                    ),
                  ],
                ),
              ),
            );
          case AuthStatus.authenticated:
            // Giriş yapılmış - ana ekrana yönlendir
            return const WelcomeScreen();
          case AuthStatus.unauthenticated:
          case AuthStatus.error:
            // Giriş yapılmamış - login ekranına yönlendir
            return const LoginScreen();
        }
      },
    );
  }
}
