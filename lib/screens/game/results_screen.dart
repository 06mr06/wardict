import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/game_provider.dart';
import '../../models/question_mode.dart';

class ResultsScreen extends StatelessWidget {
  const ResultsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<GameProvider>(context);
    final total = provider.totalScore;
    final items = provider.history;

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
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Score Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.white.withValues(alpha: 0.15), Colors.white.withValues(alpha: 0.05)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'Toplam Puan',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white70),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '$total',
                        style: const TextStyle(fontSize: 48, fontWeight: FontWeight.w900, color: Colors.white),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.green.shade400.withValues(alpha: 0.3), Colors.green.shade600.withValues(alpha: 0.1)],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.green.shade400),
                        ),
                        child: Column(
                          children: [
                            const Text('Doğruluk', style: TextStyle(color: Colors.white70, fontSize: 12)),
                            Text(
                              '${provider.answeredCount == 0 ? 0 : (provider.accuracy * 100).toStringAsFixed(0)}%',
                              style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.orange.shade400.withValues(alpha: 0.3), Colors.orange.shade600.withValues(alpha: 0.1)],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.orange.shade400),
                        ),
                        child: Column(
                          children: [
                            const Text('Maks Seri', style: TextStyle(color: Colors.white70, fontSize: 12)),
                            Text(
                              '🔥 ${provider.maxStreak}',
                              style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: items.isEmpty
                      ? const Center(child: Text('Kayıt bulunamadı', style: TextStyle(color: Colors.white70)))
                      : ListView.separated(
                          itemCount: items.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, i) {
                            final e = items[i];
                            final isCorrect = e.selectedIndex == e.correctIndex && e.selectedIndex != -1;
                            final op = _modeOperator(e.mode);
                            final answerLine = '$op ${e.correctText}';
                            return Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [Colors.white.withValues(alpha: 0.1), Colors.white.withValues(alpha: 0.05)],
                                ),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          _modeBadgeWidget(e.mode),
                                          const SizedBox(width: 6),
                                          Text(
                                            _modeLabel(e.mode),
                                            style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
                                          ),
                                        ],
                                      ),
                                      Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                colors: isCorrect
                                                    ? [Colors.green.shade400, Colors.green.shade600]
                                                    : [Colors.red.shade400, Colors.red.shade600],
                                              ),
                                              borderRadius: BorderRadius.circular(999),
                                            ),
                                            child: Text(
                                              '+${e.earnedPoints}',
                                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Builder(
                                            builder: (context) {
                                              final gp = Provider.of<GameProvider>(context);
                                              final saved = gp.isSaved(e);
                                              return SizedBox(
                                                height: 28,
                                                width: 28,
                                                child: ElevatedButton(
                                                  style: ElevatedButton.styleFrom(
                                                    padding: EdgeInsets.zero,
                                                    backgroundColor: saved ? Colors.green : Colors.transparent,
                                                    foregroundColor: Colors.white,
                                                    side: BorderSide(color: saved ? Colors.green : Colors.white54),
                                                  ),
                                                  onPressed: () {
                                                    gp.toggleInPool(e);
                                                    final added = gp.isSaved(e);
                                                    final messenger = ScaffoldMessenger.of(context);
                                                    messenger.hideCurrentMaterialBanner();
                                                    messenger.showMaterialBanner(
                                                      MaterialBanner(
                                                        content: Text(added ? 'Kelime havuza eklendi' : 'Kelime havuzdan çıkarıldı'),
                                                        actions: [
                                                          TextButton(
                                                            onPressed: () => messenger.hideCurrentMaterialBanner(),
                                                            child: const Text('Kapat'),
                                                          )
                                                        ],
                                                      ),
                                                    );
                                                    Future.delayed(const Duration(seconds: 2), () => messenger.hideCurrentMaterialBanner());
                                                  },
                                                  child: const Text('+'),
                                                ),
                                              );
                                            },
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    '${e.prompt} $answerLine',
                                    style: const TextStyle(fontSize: 16, color: Colors.white),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6C27FF),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
                    child: const Text('Ana Sayfaya Dön', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  String _modeLabel(QuestionMode mode) {
    switch (mode) {
      case QuestionMode.trToEn:
        return 'TR → EN';
      case QuestionMode.enToTr:
        return 'EN → TR';
      case QuestionMode.engToEng:
        return 'Eş Anlam';
    }
  }

  String _modeOperator(QuestionMode mode) {
    switch (mode) {
      case QuestionMode.trToEn:
      case QuestionMode.enToTr:
        return '➡️';
      case QuestionMode.engToEng:
        return '＝';
    }
  }

  Widget _modeBadgeWidget(QuestionMode mode) {
    switch (mode) {
      case QuestionMode.trToEn:
        return const Text('🇹🇷➡️🇬🇧', style: TextStyle(fontSize: 18));
      case QuestionMode.enToTr:
        return const Text('🇬🇧➡️🇹🇷', style: TextStyle(fontSize: 18));
      case QuestionMode.engToEng:
        return const Text('🇬🇧＝🇬🇧', style: TextStyle(fontSize: 18));
    }
  }
}
