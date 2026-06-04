import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
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
import 'providers/language_provider.dart';
import 'services/firebase/auth_service.dart';
import 'services/analytics_service.dart';
import 'services/connection_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'widgets/global_invitation_overlay.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class LugorenaApp extends StatelessWidget {
  const LugorenaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: AuthService.instance,
      child: Consumer<AuthService>(
        builder: (context, auth, _) {
          return MultiProvider(
            key: ValueKey('${auth.userId ?? 'logged-out'}-${auth.status}'),
            providers: [
              ChangeNotifierProvider(create: (_) => GameProvider()),
              ChangeNotifierProvider(create: (_) => PracticeProvider()),
              ChangeNotifierProvider(create: (_) => Daily123Provider()),
              ChangeNotifierProvider(create: (_) => LanguageProvider()),
              ChangeNotifierProvider.value(value: ConnectionService.instance),
            ],
            child: Consumer<LanguageProvider>(
              builder: (context, lang, _) {
                return MaterialApp(
                  navigatorKey: navigatorKey,
                  debugShowCheckedModeBanner: false,
                  locale: Locale(lang.currentLanguage == 'en' ? 'en' : 'tr'),
                  supportedLocales: const [
                    Locale('en'),
                    Locale('tr'),
                  ],
                  localizationsDelegates: const [
                    GlobalMaterialLocalizations.delegate,
                    GlobalWidgetsLocalizations.delegate,
                    GlobalCupertinoLocalizations.delegate,
                  ],
                  navigatorObservers: [
                    AnalyticsService.instance.navigatorObserver,
                  ],
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
                    if (child == null) return const SizedBox.shrink();
                    return GlobalInvitationOverlay(
                      child: Stack(
                        children: [
                          child,
                          const _OfflineBanner(),
                        ],
                      ),
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
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _OfflineBanner extends StatefulWidget {
  const _OfflineBanner();

  @override
  State<_OfflineBanner> createState() => _OfflineBannerState();
}

class _OfflineBannerState extends State<_OfflineBanner> {
  bool _isMinimized = false;

  @override
  Widget build(BuildContext context) {
    return Consumer2<ConnectionService, LanguageProvider>(
      builder: (context, connection, lang, _) {
        if (connection.isOnline) {
          if (_isMinimized) {
            // İnternet gelince durumu sıfırla
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) setState(() => _isMinimized = false);
            });
          }
          return const SizedBox.shrink();
        }

        return Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            child: _isMinimized
                ? Align(
                    alignment: Alignment.topRight,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 50.0, right: 8.0),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => setState(() => _isMinimized = false),
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.red.shade900.withAlpha(230),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withAlpha(77),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Icon(Icons.wifi_off, color: Colors.white, size: 24),
                          ),
                        ),
                      ),
                    ),
                  )
                : Material(
                    color: Colors.transparent,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                      margin: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red.shade900.withAlpha(230),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(77),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.wifi_off, color: Colors.white, size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              lang.getString('offline_banner_message'),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              setState(() => _isMinimized = true);
                              navigatorKey.currentState?.pushNamed('/7030');
                            },
                            child: Text(
                              lang.getString('offline_banner_practice'),
                              style: const TextStyle(
                                color: Colors.amber,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.white70, size: 20),
                            onPressed: () => setState(() => _isMinimized = true),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
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
