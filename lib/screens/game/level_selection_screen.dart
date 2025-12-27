import 'package:flutter/material.dart';
import '../../models/user_level.dart';
import '../../services/user_profile_service.dart';

/// Seviye seçim ekranı - Kullanıcı kendi seviyesini seçer
class LevelSelectionScreen extends StatefulWidget {
  const LevelSelectionScreen({super.key});

  @override
  State<LevelSelectionScreen> createState() => _LevelSelectionScreenState();
}

class _LevelSelectionScreenState extends State<LevelSelectionScreen>
    with SingleTickerProviderStateMixin {
  UserLevel? _selectedLevel;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _selectLevel(UserLevel level) {
    setState(() {
      _selectedLevel = level;
    });
  }

  Future<void> _confirmSelection() async {
    if (_selectedLevel == null) return;

    await UserProfileService.instance.updateLevel(_selectedLevel!);
    await UserProfileService.instance.markPlacementTestCompleted();

    if (mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
    }
  }

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
              children: [
                const SizedBox(height: 20),
                // Başlık
                const Text(
                  '🎯',
                  style: TextStyle(fontSize: 50),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Seviyeni Seç',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'İngilizce seviyeni en iyi sen bilirsin!',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 30),

                // Seviye kartları
                Expanded(
                  child: ListView(
                    children: UserLevel.values.map((level) {
                      return _buildLevelCard(level);
                    }).toList(),
                  ),
                ),

                const SizedBox(height: 20),

                // Devam butonu
                ScaleTransition(
                  scale: _selectedLevel != null ? _pulseAnim : const AlwaysStoppedAnimation(1.0),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _selectedLevel != null ? _confirmSelection : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _selectedLevel != null
                            ? _getLevelColor(_selectedLevel!)
                            : Colors.grey,
                        disabledBackgroundColor: Colors.grey.shade700,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        _selectedLevel != null
                            ? '${_selectedLevel!.turkishName} ile Başla'
                            : 'Seviye Seçin',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLevelCard(UserLevel level) {
    final isSelected = _selectedLevel == level;
    final color = _getLevelColor(level);

    return GestureDetector(
      onTap: () => _selectLevel(level),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isSelected
                ? [color.withValues(alpha: 0.4), color.withValues(alpha: 0.2)]
                : [Colors.white.withValues(alpha: 0.1), Colors.white.withValues(alpha: 0.05)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? color : Colors.white.withValues(alpha: 0.2),
            width: isSelected ? 3 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.3),
                    blurRadius: 12,
                    spreadRadius: 2,
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            // Seviye kodu
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.4),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  level.code,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            // Seviye bilgisi
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    level.turkishName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _getLevelDescription(level),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            // Seçim ikonu
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? color : Colors.transparent,
                border: Border.all(
                  color: isSelected ? color : Colors.white.withValues(alpha: 0.3),
                  width: 2,
                ),
              ),
              child: isSelected
                  ? const Icon(Icons.check, color: Colors.white, size: 18)
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Color _getLevelColor(UserLevel level) {
    switch (level) {
      case UserLevel.a1:
        return const Color(0xFF4CAF50); // Yeşil
      case UserLevel.a2:
        return const Color(0xFF8BC34A); // Açık yeşil
      case UserLevel.b1:
        return const Color(0xFFFFEB3B); // Sarı
      case UserLevel.b2:
        return const Color(0xFFFF9800); // Turuncu
      case UserLevel.c1:
        return const Color(0xFFFF5722); // Koyu turuncu
      case UserLevel.c2:
        return const Color(0xFFF44336); // Kırmızı
    }
  }

  String _getLevelDescription(UserLevel level) {
    switch (level) {
      case UserLevel.a1:
        return 'Temel kelimeler: hello, book, water, eat...';
      case UserLevel.a2:
        return 'Günlük kelimeler: government, customer, agree...';
      case UserLevel.b1:
        return 'Orta seviye: establish, distinguish, crucial...';
      case UserLevel.b2:
        return 'İleri seviye: undermine, coherent, mitigate...';
      case UserLevel.c1:
        return 'Akademik: discern, pervasive, corroborate...';
      case UserLevel.c2:
        return 'Uzman: enigmatic, inexorably, jurisprudence...';
    }
  }
}
