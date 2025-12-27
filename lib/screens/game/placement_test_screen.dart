import 'package:flutter/material.dart';
import '../../models/user_level.dart';
import '../../services/word_pool_service.dart';
import '../../services/user_profile_service.dart';
import 'dart:async';

/// Seviye belirleme testi ekranı
class PlacementTestScreen extends StatefulWidget {
  const PlacementTestScreen({super.key});

  @override
  State<PlacementTestScreen> createState() => _PlacementTestScreenState();
}

class _PlacementTestScreenState extends State<PlacementTestScreen>
    with TickerProviderStateMixin {
  List<GeneratedQuestion> _questions = [];
  int _currentIndex = 0;
  int? _selectedIndex;
  bool _isLoading = true;

  // Her seviyede doğru sayısı
  final Map<String, int> _correctByLevel = {
    'A1': 0,
    'A2': 0,
    'B1': 0,
    'B2': 0,
    'C1': 0,
    'C2': 0,
  };

  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _loadQuestions();
  }

  Future<void> _loadQuestions() async {
    await WordPoolService.instance.loadWordPool();
    final questions = WordPoolService.instance.generatePlacementTestQuestions();
    setState(() {
      _questions = questions;
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _answer(int index) {
    if (_selectedIndex != null) return;

    setState(() {
      _selectedIndex = index;
    });

    final question = _questions[_currentIndex];
    if (index == question.correctIndex) {
      _correctByLevel[question.level] = (_correctByLevel[question.level] ?? 0) + 1;
    }

    // Kısa gecikme sonrası sonraki soruya geç
    Future.delayed(const Duration(milliseconds: 800), () {
      if (!mounted) return;

      if (_currentIndex < _questions.length - 1) {
        setState(() {
          _currentIndex++;
          _selectedIndex = null;
        });
      } else {
        _finishTest();
      }
    });
  }

  void _finishTest() {
    // Seviye hesapla
    final determinedLevel = _calculateLevel();

    // Seviyeyi kaydet
    UserProfileService.instance.updateLevel(determinedLevel);
    UserProfileService.instance.markPlacementTestCompleted();

    // Sonuç ekranına git
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => PlacementResultScreen(
          level: determinedLevel,
          correctByLevel: _correctByLevel,
        ),
      ),
    );
  }

  UserLevel _calculateLevel() {
    // Seviye belirleme algoritması:
    // Hangi seviyede en yüksek başarı oranı varsa o seviye
    // Eşitlik durumunda daha yüksek seviye seçilir

    int maxCorrect = 0;
    String bestLevel = 'A1';

    // C2'den A1'e doğru kontrol et (eşitlikte yüksek seviye öncelikli)
    for (final level in ['C2', 'C1', 'B2', 'B1', 'A2', 'A1']) {
      final correct = _correctByLevel[level] ?? 0;
      if (correct > maxCorrect) {
        maxCorrect = correct;
        bestLevel = level;
      }
    }

    // Eğer hiç doğru yoksa A1
    if (maxCorrect == 0) {
      return UserLevel.a1;
    }

    // En az %50 başarı oranı gereken seviye (her seviyeden 2 soru var)
    // 2 sorudan en az 1 doğru = %50
    // Yukarıdan aşağı kontrol et, ilk %50+ olan seviye
    for (final level in ['C2', 'C1', 'B2', 'B1', 'A2', 'A1']) {
      final correct = _correctByLevel[level] ?? 0;
      if (correct >= 1) {
        // En az 1 doğru (%50+)
        return UserLevel.fromCode(level);
      }
    }

    return UserLevel.a1;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1a1a2e), Color(0xFF16213e)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(color: Colors.white),
                SizedBox(height: 20),
                Text(
                  'Sorular hazırlanıyor...',
                  style: TextStyle(color: Colors.white, fontSize: 18),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_questions.isEmpty) {
      return Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1a1a2e), Color(0xFF16213e)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 60),
                const SizedBox(height: 20),
                const Text(
                  'Sorular yüklenemedi',
                  style: TextStyle(color: Colors.white, fontSize: 18),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Geri Dön'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final question = _questions[_currentIndex];

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1a1a2e), Color(0xFF16213e)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'SEVİYE BELİRLEME',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${_currentIndex + 1} / ${_questions.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                // Progress bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: (_currentIndex + 1) / _questions.length,
                    backgroundColor: Colors.white.withValues(alpha: 0.2),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Color(0xFF2AA7FF),
                    ),
                    minHeight: 8,
                  ),
                ),

                const SizedBox(height: 30),

                // Seviye göstergesi
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: _getLevelColor(question.level).withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _getLevelColor(question.level),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      question.level,
                      style: TextStyle(
                        color: _getLevelColor(question.level),
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Soru kartı
                ScaleTransition(
                  scale: _pulseAnim,
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.white.withValues(alpha: 0.15),
                          Colors.white.withValues(alpha: 0.05),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.2),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      question.prompt,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),

                const SizedBox(height: 30),

                // Seçenekler
                Expanded(
                  child: ListView.builder(
                    itemCount: question.options.length,
                    itemBuilder: (context, index) {
                      final isSelected = _selectedIndex == index;
                      final isCorrect = index == question.correctIndex;
                      final showResult = _selectedIndex != null;

                      Color bgColor = Colors.white.withValues(alpha: 0.1);
                      Color borderColor = Colors.white.withValues(alpha: 0.3);
                      IconData? icon;

                      if (showResult) {
                        if (isCorrect) {
                          bgColor = Colors.green.withValues(alpha: 0.3);
                          borderColor = Colors.green;
                          icon = Icons.check_circle;
                        } else if (isSelected && !isCorrect) {
                          bgColor = Colors.red.withValues(alpha: 0.3);
                          borderColor = Colors.red;
                          icon = Icons.cancel;
                        }
                      } else if (isSelected) {
                        bgColor = const Color(0xFF2AA7FF).withValues(alpha: 0.3);
                        borderColor = const Color(0xFF2AA7FF);
                      }

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: GestureDetector(
                          onTap: () => _answer(index),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: bgColor,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: borderColor, width: 2),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: borderColor.withValues(alpha: 0.3),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Text(
                                      String.fromCharCode(65 + index),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    question.options[index],
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                                if (icon != null)
                                  Icon(icon, color: borderColor, size: 24),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _getLevelColor(String level) {
    switch (level) {
      case 'A1':
        return Colors.green;
      case 'A2':
        return Colors.lightGreen;
      case 'B1':
        return Colors.yellow;
      case 'B2':
        return Colors.orange;
      case 'C1':
        return Colors.deepOrange;
      case 'C2':
        return Colors.red;
      default:
        return Colors.blue;
    }
  }
}

/// Seviye belirleme sonuç ekranı
class PlacementResultScreen extends StatelessWidget {
  final UserLevel level;
  final Map<String, int> correctByLevel;

  const PlacementResultScreen({
    super.key,
    required this.level,
    required this.correctByLevel,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1a1a2e), Color(0xFF16213e)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  '🎉',
                  style: TextStyle(fontSize: 60),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Seviye Belirlendi!',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 30),

                // Seviye kartı
                Container(
                  padding: const EdgeInsets.all(30),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        _getLevelColor(level).withValues(alpha: 0.3),
                        _getLevelColor(level).withValues(alpha: 0.1),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: _getLevelColor(level),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _getLevelColor(level).withValues(alpha: 0.3),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Text(
                        level.code,
                        style: TextStyle(
                          color: _getLevelColor(level),
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        level.turkishName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 30),

                // Seviye açıklaması
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    _getLevelDescription(level),
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

                const Spacer(),

                // Başla butonu
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pushNamedAndRemoveUntil(
                        '/',
                        (route) => false,
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2AA7FF),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      'Oyuna Başla',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _getLevelColor(UserLevel level) {
    switch (level) {
      case UserLevel.a1:
        return Colors.green;
      case UserLevel.a2:
        return Colors.lightGreen;
      case UserLevel.b1:
        return Colors.yellow;
      case UserLevel.b2:
        return Colors.orange;
      case UserLevel.c1:
        return Colors.deepOrange;
      case UserLevel.c2:
        return Colors.red;
    }
  }

  String _getLevelDescription(UserLevel level) {
    switch (level) {
      case UserLevel.a1:
        return 'Temel seviye - Günlük yaşamda en sık kullanılan kelimeleri öğreniyorsun.';
      case UserLevel.a2:
        return 'Başlangıç seviye - Basit cümleler kurabilecek kelime dağarcığına sahipsin.';
      case UserLevel.b1:
        return 'Orta seviye - Karmaşık fikirlerini ifade edebilecek seviyedesin.';
      case UserLevel.b2:
        return 'Orta-üst seviye - Akademik ve profesyonel konuları anlayabilirsin.';
      case UserLevel.c1:
        return 'İleri seviye - Nüansları anlayabilir, etkili iletişim kurabilirsin.';
      case UserLevel.c2:
        return 'Uzman seviye - Anadil seviyesine yakın bir hakimiyet!';
    }
  }
}
