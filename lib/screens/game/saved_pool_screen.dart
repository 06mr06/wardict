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
        backgroundColor: const Color(0xFF1a1a2e),
        foregroundColor: Colors.white,
        actions: [
          TextButton.icon(
            onPressed: items.isEmpty
                ? null
                : () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const FlashcardsScreen()),
                    ),
            icon: const Icon(Icons.style, color: Colors.white),
            label: const Text('Test Yourself', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1a1a2e), Color(0xFF16213e)],
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
                        title: Text(
                          e.prompt,
                          style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
                        ),
                        subtitle: Row(
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
          : FloatingActionButton.extended(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const FlashcardsScreen()),
              ),
              backgroundColor: const Color(0xFF6C27FF),
              icon: const Icon(Icons.style, color: Colors.white),
              label: const Text('Test Yourself', style: TextStyle(color: Colors.white)),
            ),
    );
  }
}
