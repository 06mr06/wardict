import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/home/welcome_screen.dart';
import 'screens/game/game_screen.dart';
import 'screens/game/duel_screen.dart';
import 'screens/game/practice_screen.dart' as seventy_thirty;
import 'screens/profile/profile_screen_new.dart';
import 'screens/shop/shop_screen.dart';
import 'screens/auth/login_screen.dart';
import 'providers/game_provider.dart';
import 'providers/practice_provider.dart';
import 'providers/daily_123_provider.dart';
import 'services/firebase/auth_service.dart';
import 'services/connection_service.dart';
import 'package:google_fonts/google_fonts.dart';

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
        ChangeNotifierProvider.value(value: ConnectionService.instance),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'LUGORENA',
        theme: ThemeData(
          useMaterial3: true,
          textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF6C27FF),
            brightness: Brightness.dark,
          ),
        ),
        home: const AuthWrapper(),
        builder: (context, child) {
          return Stack(
            children: [
              child!,
              const _OfflineBanner(),
            ],
          );
        },
        routes: {
          '/login': (_) => const LoginScreen(),
          '/home': (_) => const WelcomeScreen(),
          '/7030': (_) => const seventy_thirty.SeventyThirtyScreen(),
          '/practice-old': (_) => const GameScreen(),
          '/duel': (_) => const DuelScreen(),
          '/profile': (_) => const ProfileScreenNew(),
          '/shop': (_) => const ShopScreen(),
        },
      ),
    );
  }
}

class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner();

  @override
  Widget build(BuildContext context) {
    return Consumer<ConnectionService>(
      builder: (context, connection, _) {
        if (connection.isOnline) return const SizedBox.shrink();

        return Material(
          color: Colors.transparent,
          child: SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.shade900.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.wifi_off, color: Colors.white, size: 20),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'İnternet bağlantısı kesildi. Bazı özellikler çalışmayabilir.',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        // Alıştırma moduna hızlı geçiş butonu eklenebilir
                      },
                      child: const Text(
                        'PRACTICE',
                        style: TextStyle(
                          color: Colors.amber,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
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
