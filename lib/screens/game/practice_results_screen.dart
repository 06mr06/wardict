import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/answered_entry.dart';
import '../../models/question_mode.dart';
import '../../providers/game_provider.dart';
import '../../providers/practice_provider.dart';
import '../../services/word_pool_service.dart';

class PracticeResultsScreen extends StatefulWidget {
  final PracticeSessionResult result;
  
  const PracticeResultsScreen({super.key, required this.result});
  
  @override
  State<PracticeResultsScreen> createState() => _PracticeResultsScreenState();
}

class _PracticeResultsScreenState extends State<PracticeResultsScreen> {
  final Set<int> _savedIndices = {};
  
  PracticeSessionResult get result => widget.result;

  bool get allSelected => _savedIndices.length == result.answerHistory.length && result.answerHistory.isNotEmpty;

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
                // Header
                const Text(
                  'Oturum Tamamlandı!',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                
                // Level change banner (if any)
                if (result.leveledUp)
                  _buildLevelChangeBanner(
                    isLevelUp: true,
                    newLevel: result.newLevel!,
                  )
                else if (result.leveledDown)
                  _buildLevelChangeBanner(
                    isLevelUp: false,
                    newLevel: result.newLevel!,
                  ),
                
                if (result.leveledUp || result.leveledDown)
                  const SizedBox(height: 12),
                
                // Score card
                _buildScoreCard(),
                const SizedBox(height: 12),
                
                // Statistics
                _buildStatisticsRow(),
                const SizedBox(height: 12),
                
                // Current level
                _buildCurrentLevelCard(),
                const SizedBox(height: 12),
                
                // Answer history
                Expanded(
                  child: _buildAnswerHistory(),
                ),
                
                const SizedBox(height: 16),
                
                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white.withValues(alpha: 0.1),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
                          ),
                        ),
                        child: const Text(
                          'Ana Sayfa',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pushReplacementNamed('/practice');
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF9800),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: const Text(
                          'Devam Et',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLevelChangeBanner({required bool isLevelUp, required String newLevel}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isLevelUp
              ? [Colors.green.shade400, Colors.green.shade600]
              : [Colors.red.shade400, Colors.red.shade600],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: (isLevelUp ? Colors.green : Colors.red).withValues(alpha: 0.5),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isLevelUp ? Icons.arrow_upward : Icons.arrow_downward,
            color: Colors.white,
            size: 28,
          ),
          const SizedBox(width: 12),
          Column(
            children: [
              Text(
                isLevelUp ? 'Seviye Atladın!' : 'Seviye Düştü',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Yeni Seviye: $newLevel',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildScoreCard() {
    final isPositive = result.sessionScore >= 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isPositive
              ? [Colors.green.shade400.withValues(alpha: 0.3), Colors.green.shade600.withValues(alpha: 0.1)]
              : [Colors.red.shade400.withValues(alpha: 0.3), Colors.red.shade600.withValues(alpha: 0.1)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isPositive ? Colors.green : Colors.red,
          width: 2,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.school,
            color: isPositive ? Colors.green : Colors.red,
            size: 26,
          ),
          const SizedBox(width: 12),
          Column(
            children: [
              const Text(
                'Oturum Puanı',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                ),
              ),
              Text(
                isPositive ? '+${result.sessionScore}' : '${result.sessionScore}',
                style: TextStyle(
                  color: isPositive ? Colors.green : Colors.red,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatisticsRow() {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'Doğru',
            '${result.correctAnswers}',
            Colors.green,
            Icons.check_circle,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            'Yanlış',
            '${result.totalQuestions - result.correctAnswers}',
            Colors.red,
            Icons.cancel,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            'Başarı',
            '%${(result.accuracy * 100).round()}',
            Colors.blue,
            Icons.analytics,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: color.withValues(alpha: 0.8),
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentLevelCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.school, color: Colors.amber, size: 20),
          const SizedBox(width: 8),
          const Text(
            'Seviye:',
            style: TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.amber),
            ),
            child: Text(
              result.currentLevel,
              style: const TextStyle(
                color: Colors.amber,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnswerHistory() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          // Header with Tümünü Seç/Kaldır
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Cevaplar',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                // Tümünü Seç / Tümünü Kaldır butonu
                GestureDetector(
                  onTap: _toggleAll,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: allSelected 
                          ? Colors.orange.withValues(alpha: 0.3)
                          : const Color(0xFF6C27FF).withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: allSelected ? Colors.orange : const Color(0xFF6C27FF),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          allSelected ? Icons.remove_circle : Icons.add_circle,
                          color: allSelected ? Colors.orange : const Color(0xFF6C27FF),
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          allSelected ? 'Tümünü Kaldır' : 'Tümünü Seç',
                          style: TextStyle(
                            color: allSelected ? Colors.orange : const Color(0xFF6C27FF),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              itemCount: result.answerHistory.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final answer = result.answerHistory[index];
                final isSaved = _savedIndices.contains(index);
                
                return GestureDetector(
                  onTap: () => _toggleItem(index, answer),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isSaved
                            ? [Colors.green.withValues(alpha: 0.2), Colors.green.withValues(alpha: 0.1)]
                            : answer.isCorrect
                                ? [Colors.green.withValues(alpha: 0.15), Colors.green.withValues(alpha: 0.05)]
                                : [Colors.red.withValues(alpha: 0.15), Colors.red.withValues(alpha: 0.05)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSaved
                            ? Colors.green.withValues(alpha: 0.5)
                            : answer.isCorrect
                                ? Colors.green.withValues(alpha: 0.3)
                                : Colors.red.withValues(alpha: 0.3),
                        width: isSaved ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        // Checkbox style indicator
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: isSaved ? Colors.green : Colors.transparent,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: isSaved ? Colors.green : Colors.white54,
                              width: 2,
                            ),
                          ),
                          child: isSaved 
                              ? const Icon(Icons.check, color: Colors.white, size: 16)
                              : null,
                        ),
                        const SizedBox(width: 10),
                        // Seviye badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            answer.level,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        // Soru ve cevap
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                answer.prompt,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                '➡️ ${answer.correctAnswer}',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Puan
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: answer.isCorrect
                                  ? [Colors.green.shade400, Colors.green.shade600]
                                  : [Colors.red.shade400, Colors.red.shade600],
                            ),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            answer.points > 0 ? '+${answer.points}' : '${answer.points}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _toggleItem(int index, PracticeAnswerRecord answer) {
    final provider = context.read<GameProvider>();
    
    setState(() {
      if (_savedIndices.contains(index)) {
        // Kaldır
        _savedIndices.remove(index);
        // QuestionType -> QuestionMode dönüşümü
        final questionMode = _convertToQuestionMode(answer.mode);
        final entry = AnsweredEntry(
          prompt: answer.prompt,
          correctText: answer.correctAnswer,
          selectedText: answer.selectedAnswer,
          selectedIndex: answer.isCorrect ? 0 : 1,
          correctIndex: 0,
          earnedPoints: answer.points,
          mode: questionMode,
        );
        provider.removeFromPool(entry);
      } else {
        // Ekle
        _savedIndices.add(index);
        // QuestionType -> QuestionMode dönüşümü
        final questionMode = _convertToQuestionMode(answer.mode);
        final entry = AnsweredEntry(
          prompt: answer.prompt,
          correctText: answer.correctAnswer,
          selectedText: answer.selectedAnswer,
          selectedIndex: answer.isCorrect ? 0 : 1,
          correctIndex: 0,
          earnedPoints: answer.points,
          mode: questionMode,
        );
        provider.addToPool(entry);
      }
    });
  }

  void _toggleAll() {
    final provider = context.read<GameProvider>();
    
    setState(() {
      if (allSelected) {
        // Tümünü kaldır
        for (int i = 0; i < result.answerHistory.length; i++) {
          final answer = result.answerHistory[i];
          final questionMode = _convertToQuestionMode(answer.mode);
          final entry = AnsweredEntry(
            prompt: answer.prompt,
            correctText: answer.correctAnswer,
            selectedText: answer.selectedAnswer,
            selectedIndex: answer.isCorrect ? 0 : 1,
            correctIndex: 0,
            earnedPoints: answer.points,
            mode: questionMode,
          );
          provider.removeFromPool(entry);
        }
        _savedIndices.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tüm kelimeler havuzdan çıkarıldı'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 1),
          ),
        );
      } else {
        // Tümünü seç
        for (int i = 0; i < result.answerHistory.length; i++) {
          if (!_savedIndices.contains(i)) {
            final answer = result.answerHistory[i];
            final questionMode = _convertToQuestionMode(answer.mode);
            final entry = AnsweredEntry(
              prompt: answer.prompt,
              correctText: answer.correctAnswer,
              selectedText: answer.selectedAnswer,
              selectedIndex: answer.isCorrect ? 0 : 1,
              correctIndex: 0,
              earnedPoints: answer.points,
              mode: questionMode,
            );
            provider.addToPool(entry);
            _savedIndices.add(i);
          }
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${result.answerHistory.length} kelime havuza eklendi'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 1),
          ),
        );
      }
    });
  }

  /// QuestionType'ı QuestionMode'a dönüştürür
  QuestionMode _convertToQuestionMode(QuestionType type) {
    switch (type) {
      case QuestionType.enToTr:
        return QuestionMode.enToTr;
      case QuestionType.trToEn:
        return QuestionMode.trToEn;
      case QuestionType.synonym:
      case QuestionType.antonym:
      case QuestionType.relation:
        return QuestionMode.engToEng;
    }
  }
}
