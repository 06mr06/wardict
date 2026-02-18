import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/user_level.dart';
import '../../models/practice_session.dart';
import '../../services/user_profile_service.dart';
// Konuşma balonu import'u kaldırıldı

/// Tutorial ekranı - İlk girişte gösterilir
class TutorialScreen extends StatefulWidget {
  final VoidCallback? onComplete;
  
  const TutorialScreen({super.key, this.onComplete});

  /// İlk kez mi açılıyor kontrolü
  static Future<bool> shouldShowTutorial() async {
    final prefs = await SharedPreferences.getInstance();
    return !(prefs.getBool('tutorial_completed') ?? false);
  }

  /// Tutorial tamamlandı olarak işaretle
  static Future<void> markAsCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('tutorial_completed', true);
  }

  /// Tutorial'ı sıfırla (tekrar izleme için)
  static Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('tutorial_completed', false);
  }

  @override
  State<TutorialScreen> createState() => _TutorialScreenState();
}

class _TutorialScreenState extends State<TutorialScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  String? _selectedLanguage; // 'tr' or 'en'
  bool _showEndSequence = false;
  String _endSequenceText = '';

  List<TutorialPage> _pages = [];

  void _selectLanguage(String lang) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_language', lang);
    setState(() {
      _selectedLanguage = lang;
      _pages = _generatePages(lang);
    });
  }

  List<TutorialPage> _generatePages(String lang) {
    bool isTr = lang == 'tr';
    return [
      TutorialPage(
        title: isTr ? 'LUGORENA\'ya Hoş Geldin!' : 'Welcome to LUGORENA!',
        description: isTr 
            ? 'İngilizce kelime bilgini test et ve geliştir!\nFarklı oyun modlarıyla eğlenerek öğren.'
            : 'Test and improve your English vocabulary!\nLearn while having fun with different game modes.',
        color: const Color(0xFF6C27FF),
      ),
      TutorialPage(
        title: isTr ? 'Duel Modu' : 'Duel Mode',
        description: isTr
            ? 'Online rakiplerinle, arkadaşlarınla veya\nseviyene uygun botla 10 soruluk düellolara katıl!'
            : 'Join 10-question duels with online opponents,\nfriends, or a bot matching your level!',
        color: const Color(0xFF2AA7FF),
      ),
      TutorialPage(
        title: 'Daily 123',
        description: isTr
            ? '123 saniyede 123 puana ulaşmaya çalış!'
            : 'Try to reach 123 points in 123 seconds!',
        color: const Color(0xFF00C6AE),
      ),
      TutorialPage(
        title: isTr ? 'Practice (70/30)' : 'Practice (70/30)',
        description: isTr
            ? 'Kendi seviyene uygun kelimelerle\npratik yap, ilerlemeni takip et!'
            : 'Practice with words suitable for your level\nand track your progress!',
        color: const Color(0xFFFD7E14),
      ),
      TutorialPage(
        title: isTr ? 'Başarılar' : 'Achievements',
        description: isTr
            ? 'Başarımlar kazan, rozetler topla ve\narkadaşlarınla yarış!'
            : 'Earn achievements, collect badges and\ncompete with your friends!',
        color: const Color(0xFFFFC300),
      ),
    ];
  }

  void _nextPage() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _startEndSequence();
    }
  }

  Future<void> _startEndSequence() async {
    setState(() {
      _showEndSequence = true;
      _endSequenceText = _selectedLanguage == 'tr' 
          ? "Şimdi Sıra Seviye Tespitinde\nBaşlıyoruz" 
          : "Now Placement Test\nStarting"; 
    });

    // 1. "Şimdi sıra..."
    await Future.delayed(const Duration(seconds: 3));

    if (!mounted) return;
    setState(() {
      _endSequenceText = "Level Test";
    });

    // 2. "Level Test"
    await Future.delayed(const Duration(seconds: 2));

    // 3. Countdown 3, 2, 1
    for (int i = 3; i > 0; i--) {
      if (!mounted) return;
      setState(() {
        _endSequenceText = i.toString();
      });
      await Future.delayed(const Duration(seconds: 1));
    }

    _completeTutorial();
  }

  void _skipTutorial() {
    if (_selectedLanguage == null) {
      _selectLanguage('tr'); 
    }
    _startEndSequence();
  }

  void _completeTutorial() async {
    await TutorialScreen.markAsCompleted();
    // Seviye tespit süreci A2'den başlar
    final currentProfile = await UserProfileService.instance.loadProfile();
    final currentSession = currentProfile.practiceSession;
    if (currentSession.totalSessionsCompleted == 0 && 
        currentSession.sessionsInRow == 0) {
      await UserProfileService.instance.updateLevel(UserLevel.a2);
      await UserProfileService.instance.updatePracticeSession(
        const PracticeSession(currentLevel: 'A2'),
      );
    }
    if (widget.onComplete != null) {
      widget.onComplete!();
    } else if (mounted) {
      // Tutorial bitince direkt seviye testine (Practice 70/30) yönlendir
      Navigator.of(context).pushReplacementNamed('/7030');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_showEndSequence) {
      return Scaffold(
        backgroundColor: const Color(0xFF1A3A5C),
        body: Center(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (Widget child, Animation<double> animation) {
              return ScaleTransition(scale: animation, child: child);
            },
            child: Text(
              _endSequenceText,
              key: ValueKey<String>(_endSequenceText),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      );
    }

    if (_selectedLanguage == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF1A3A5C),
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.language, size: 60, color: Colors.white),
                const SizedBox(height: 30),
                const Text(
                  'Lütfen Dil Seçiniz\nPlease Select Language',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 40),
                _buildLanguageOption('Türkçe', 'tr', '🇹🇷'),
                const SizedBox(height: 20),
                _buildLanguageOption('English', 'en', '🇺🇸'),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              _pages[_currentPage].color,
              _pages[_currentPage].color.withOpacity(0.7),
              const Color(0xFF1A3A5C),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Skip Button
              Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: TextButton(
                  onPressed: _skipTutorial,
                  child: Text(
                    _selectedLanguage == 'tr' ? 'Atla' : 'Skip',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ),

            // Page Content
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _pages.length,
                onPageChanged: (index) {
                  setState(() => _currentPage = index);
                },
                itemBuilder: (context, index) {
                  return _buildPage(_pages[index]);
                },
              ),
            ),

            // Page Indicators
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_pages.length, (index) {
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: _currentPage == index ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _currentPage == index
                          ? Colors.white
                          : Colors.white.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                }),
              ),
            ),

            // Next/Start Button
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _nextPage,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: _pages[_currentPage].color,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 8,
                  ),
                  child: Text(
                    _currentPage < _pages.length - 1 
                        ? (_selectedLanguage == 'tr' ? 'İleri' : 'Next') 
                        : (_selectedLanguage == 'tr' ? 'Başla!' : 'Start!'),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLanguageOption(String label, String code, String flag) {
    return InkWell(
      onTap: () => _selectLanguage(code),
      child: Container(
        width: 200,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white30),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(flag, style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 12),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPage(TutorialPage page) {
    String? bgImage;
    if (page.title == "LUGORENA'ya Hoş Geldin!" || page.title == 'Welcome to LUGORENA!') {
      bgImage = 'assets/images/tutorial_giris_tamboy.png';
    } else if (page.title == 'Duel Modu' || page.title == 'Duel Mode') {
      bgImage = 'assets/images/tutorial_duel_tamboy.png';
    } else if (page.title == 'Daily 123') {
      bgImage = 'assets/images/tutorial_123_tamboy.png';
    } else if (page.title == 'Practice (70/30)') {
      bgImage = 'assets/images/tutorial_practice_tamboy.png';
    } else if (page.title == 'Başarılar' || page.title == 'Achievements') {
      bgImage = 'assets/images/tutorial_achievements_tamboy.png';
    }
    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final double screenHeight = constraints.maxHeight;
          final double topSpace = screenHeight * 0.10;
          final double bottomSpace = screenHeight * 0.10;
          return Column(
            children: [
              SizedBox(height: topSpace),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                  decoration: BoxDecoration(
                    color: page.color.withOpacity(0.92),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        page.title,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        page.description,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          height: 1.4,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: Center(
                  child: (bgImage != null)
                      ? FractionallySizedBox(
                          widthFactor: 0.7,
                          child: AspectRatio(
                            aspectRatio: 1,
                            child: Image.asset(
                              bgImage,
                              fit: BoxFit.contain,
                              alignment: Alignment.center,
                            ),
                          ),
                        )
                      : const SizedBox(),
                ),
              ),
              SizedBox(height: bottomSpace),
            ],
          );
        },
      ),
    );
  }
}

class TutorialPage {
  final String title;
  final String description;
  final Color color;

  const TutorialPage({
    required this.title,
    required this.description,
    required this.color,
  });
}
