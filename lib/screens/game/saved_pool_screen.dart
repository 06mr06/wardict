import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/game_provider.dart';
import '../../models/question_mode.dart';
import 'flashcards_screen.dart';

class SavedPoolScreen extends StatelessWidget {
  const SavedPoolScreen({super.key});

  Widget _modeBadge(QuestionMode mode) {
    switch (mode) {
      case QuestionMode.trToEn:
        return const Text('🇹🇷➡️🇬🇧', style: TextStyle(fontSize: 18));
      case QuestionMode.enToTr:
        return const Text('🇬🇧➡️🇹🇷', style: TextStyle(fontSize: 18));
      case QuestionMode.engToEng:
        return const Text('🇬🇧＝🇬🇧', style: TextStyle(fontSize: 18));
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<GameProvider>(context);
    final items = provider.savedPool;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kelime Havuzu'),
        backgroundColor: const Color(0xFF2E5A8C),
        foregroundColor: Colors.white,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF2E5A8C), Color(0xFF1A3A5C)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: items.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.bookmark_border, size: 80, color: Colors.white.withValues(alpha: 0.3)),
                      const SizedBox(height: 16),
                      Text(
                        'Havuz boş',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Sonuçlardan + ile kelime ekleyin',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 14),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final e = items[i];
                    return Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.white.withValues(alpha: 0.1), Colors.white.withValues(alpha: 0.05)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        leading: _modeBadge(e.mode),
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                e.prompt,
                                style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Text('➡️ ', style: TextStyle(fontSize: 14)),
                                Expanded(
                                  child: Text(
                                    e.correctText,
                                    style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
                                  ),
                                ),
                              ],
                            ),
                            if (e.turkishMeaning != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                '🇹🇷 ${e.turkishMeaning}',
                                style: const TextStyle(color: Colors.cyanAccent, fontSize: 13, fontStyle: FontStyle.italic),
                              ),
                            ],
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'LVL ${e.srsLevel}',
                                    style: const TextStyle(color: Colors.amber, fontSize: 10, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Next: ${_formatNextReview(e.lastReviewedAt, e.srsLevel)}',
                                  style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 10),
                                ),
                              ],
                            ),
                          ],
                        ),
                        trailing: IconButton(
                          onPressed: () {
                            provider.removeFromPool(e);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text('Kelime havuzdan çıkarıldı'),
                                duration: const Duration(seconds: 2),
                                action: SnackBarAction(
                                  label: 'Geri Al',
                                  onPressed: () => provider.addToPool(e),
                                ),
                              ),
                            );
                          },
                          icon: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.red.withValues(alpha: 0.5)),
                            ),
                            child: const Icon(Icons.remove, color: Colors.red, size: 20),
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ),
      floatingActionButton: items.isEmpty
          ? null
          : (provider.readyForReview.isNotEmpty
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    FloatingActionButton.extended(
                      heroTag: 'testAllTag',
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const FlashcardsScreen(reviewOnly: false)),
                      ),
                      backgroundColor: Colors.white24,
                      icon: const Icon(Icons.style, color: Colors.white, size: 18),
                      label: const Text('TÜMÜ', style: TextStyle(color: Colors.white, fontSize: 13)),
                    ),
                    const SizedBox(width: 12),
                    FloatingActionButton.extended(
                      heroTag: 'smartReviewTag',
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const FlashcardsScreen(reviewOnly: true)),
                      ),
                      backgroundColor: const Color(0xFF00F5A0),
                      icon: const Icon(Icons.psychology, color: Colors.black, size: 20),
                      label: Text('AKILLI TEKRAR (${provider.readyForReview.length})', style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 13)),
                    ),
                  ],
                )
              : FloatingActionButton.extended(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const FlashcardsScreen(reviewOnly: false)),
                  ),
                  backgroundColor: const Color(0xFF6C27FF),
                  icon: const Icon(Icons.style, color: Colors.white),
                  label: const Text('Test Yourself', style: TextStyle(color: Colors.white)),
                )),
    );
  }

  String _formatNextReview(DateTime? last, int level) {
    if (last == null) return 'Ready';
    final days = _getSrsDays(level);
    final next = last.add(Duration(days: days));
    final diff = next.difference(DateTime.now());
    if (diff.isNegative) return 'Ready';
    if (diff.inHours < 24) return '${diff.inHours}sa kaldı';
    return '${diff.inDays}g kaldı';
  }

  int _getSrsDays(int level) {
    switch (level) {
      case 1: return 1;
      case 2: return 3;
      case 3: return 7;
      case 4: return 14;
      case 5: return 30;
      default: return 0;
    }
  }
}
