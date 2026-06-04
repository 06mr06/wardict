import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';

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

  final List<TutorialPage> _pages = [
    const TutorialPage(
      icon: '🛡️',
      title: 'LUGORENA\'ya Hoş Geldin!',
      description: 'İngilizce kelime bilgini test et ve geliştir!\n'
          'Farklı oyun modlarıyla eğlenerek öğren.',
      color: Color(0xFF6C27FF),
      imageAsset: 'assets/images/tutorial_welcome_lugorena.png',
    ),
    const TutorialPage(
      icon: '⚔️',
      title: 'Duel Modu',
      description:
          'Online rakiplerinle, arkadaşlarınla veya\nseviyene uygun botla 10 soruluk düellolara katıl!',
      color: Color(0xFF2AA7FF),
      imageAsset: 'assets/images/tutorial_duel_lugorena.png',
    ),
    const TutorialPage(
      icon: '🎯',
      title: 'Daily 123',
      description: '123 saniyede 123 puana ulaşmaya çalış!\n'
          'Her gün yeni bir meydan okuma seni bekliyor.\n'
          'Hızlı ol, üst sıraları yakala!',
      color: Color(0xFFFF6B6B),
      imageAsset: 'assets/images/tutorial_daily123_lugorena.png',
    ),
    const TutorialPage(
      icon: '📚',
      title: 'Practice Modu',
      description: 'Kendi hızında pratik yap.\n'
          'A2 seviyesinden başla, başarına göre seviye atla!',
      color: Color(0xFF00D9F5),
      imageAsset: 'assets/images/tutorial_practice_lugorena.png',
    ),
    const TutorialPage(
      icon: '⭐',
      title: 'Arkadaşlarını davet et',
      description:
          'Arkadaşlarınla paylaş: oyuna kayıt olup davet kodunu ilk kez kullanan her arkadaşın için 1000 altın kazanırsın; yeni oyuncu da 250 altın hediye alır!',
      color: Color(0xFF00F5A0),
      imageAsset: 'assets/images/tutorial_achievements_lugorena.png',
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _completeTutorial();
    }
  }

  void _skipTutorial() {
    _completeTutorial();
  }

  void _completeTutorial() async {
    await TutorialScreen.markAsCompleted();
    if (widget.onComplete != null) {
      widget.onComplete!();
    } else if (mounted) {
      Navigator.of(context).pop();
    }
  }

  void _shareLastPage() {
    final String text =
        'Arkadaşlarını davet et\n\nArkadaşlarınla paylaş: oyuna kayıt olup davet kodunu ilk kez kullanan her arkadaşın için 1000 altın kazanırsın; yeni oyuncu da 250 altın hediye alır!';
    Share.share(text);
  }

  @override
  Widget build(BuildContext context) {
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
                      _currentPage < _pages.length - 1 ? 'Atla' : '',
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
                      _currentPage < _pages.length - 1 ? 'İleri' : 'Başla!',
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

  Widget _buildPage(TutorialPage page) {
    final hasImage = page.imageAsset != null;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Büyük görsel bölümü: resim genişlik/yüksekliğiyle ekrana yayılır ve kenarları yuvarlatılır
          if (hasImage)
            ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: SizedBox(
                width: double.infinity,
                height: MediaQuery.of(context).size.height * 0.5,
                child: Image.asset(
                  page.imageAsset!,
                  fit: BoxFit.cover,
                ),
              ),
            )
          else
            TweenAnimationBuilder<double>(
              duration: const Duration(milliseconds: 600),
              tween: Tween(begin: 0.8, end: 1.0),
              curve: Curves.elasticOut,
              builder: (context, value, child) {
                return Transform.scale(
                  scale: value,
                  child: Text(
                    page.icon,
                    style: const TextStyle(fontSize: 100),
                  ),
                );
              },
            ),
          const SizedBox(height: 40),

          // Title
          Text(
            page.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),

          // Description
          Text(
            page.description,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 16,
              height: 1.5,
            ),
          ),
          if (_currentPage == _pages.length - 1) ...[
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _shareLastPage,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black87,
                padding:
                    const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Paylaş'),
            ),
          ],
        ],
      ),
    );
  }
}

class TutorialPage {
  final String icon;
  final String title;
  final String description;
  final Color color;
  final String? imageAsset; // Opsiyonel resim

  const TutorialPage({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
    this.imageAsset,
  });
}
