import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/daily_123.dart';
import '../../models/answered_entry.dart';
import '../../models/question_mode.dart';
import '../../services/daily_123_service.dart';
import '../../providers/daily_123_provider.dart';
import '../../providers/game_provider.dart';
import '../../services/ranking_service.dart';
import '../../services/user_profile_service.dart';

class Daily123ResultsScreen extends StatefulWidget {
  final int finalScore;
  final int timeSpent;
  final bool isWin;
  final List<AnsweredQuestion> correctAnswers;
  final List<AnsweredQuestion> wrongAnswers;

  const Daily123ResultsScreen({
    super.key,
    required this.finalScore,
    required this.timeSpent,
    required this.isWin,
    required this.correctAnswers,
    required this.wrongAnswers,
  });

  @override
  State<Daily123ResultsScreen> createState() => _Daily123ResultsScreenState();
}

class _Daily123ResultsScreenState extends State<Daily123ResultsScreen> {
  Daily123Stats? _stats;
  Map<String, dynamic>? _rankingData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final stats = await Daily123Service.instance.getStats();
    final ranking = await Daily123Service.instance.getRankingData();
    if (mounted) {
      setState(() {
        _stats = stats;
        _rankingData = ranking;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF2E5A8C),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Günün Sonuçları', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.5)),
        actions: [
          IconButton(
            onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
            icon: const Icon(Icons.home, color: Colors.white, size: 28),
            tooltip: 'Ana Sayfa',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                // Üst satır: TIME IS UP + Reklam butonu (eşit boyut)
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: _buildMainResult()),
                      const SizedBox(width: 12),
                      Expanded(child: _buildAdButton()),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                // Alt satır: Puan + Doğru + Yanlış
                _buildScoreAndAnswerRow(),
                const SizedBox(height: 20),
                _buildStatsGrid(),
                const SizedBox(height: 20),
                _buildRankingSection(),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2AA7FF),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text('Ana Menüye Dön', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
    );
  }
  
  // ignore: unused_element - Compact answer boxes için saklanıyor
  Widget _buildCompactAnswerBoxes() {
    return Column(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () => _showAnswerList(true),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.green.withValues(alpha: 0.3), Colors.green.withValues(alpha: 0.1)],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green, width: 2),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 20),
                  const SizedBox(width: 6),
                  Text(
                    '${widget.correctAnswers.length}',
                    style: const TextStyle(color: Colors.green, fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Expanded(
          child: GestureDetector(
            onTap: () => _showAnswerList(false),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.red.withValues(alpha: 0.3), Colors.red.withValues(alpha: 0.1)],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red, width: 2),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.cancel, color: Colors.red, size: 20),
                  const SizedBox(width: 6),
                  Text(
                    '${widget.wrongAnswers.length}',
                    style: const TextStyle(color: Colors.red, fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildScoreAndAnswerRow() {
    // Süre hesapla (salise ile)
    final seconds = widget.timeSpent;
    final timeStr = '$seconds.00 sn';
    
    return Row(
      children: [
        // Süre kutusu
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white24),
            ),
            child: Column(
              children: [
                const Icon(Icons.timer, color: Colors.cyan, size: 28),
                const SizedBox(height: 4),
                Text(
                  timeStr,
                  style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const Text('Süre', style: TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        // Puan kutusu
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white24),
            ),
            child: Column(
              children: [
                const Icon(Icons.stars, color: Colors.amber, size: 28),
                const SizedBox(height: 4),
                Text(
                  '${widget.finalScore}',
                  style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const Text('Puan', style: TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        // Doğru kutusu
        Expanded(
          child: GestureDetector(
            onTap: () => _showAnswerList(true),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.green.withValues(alpha: 0.3), Colors.green.withValues(alpha: 0.1)],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.green, width: 2),
              ),
              child: Column(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 28),
                  const SizedBox(height: 4),
                  Text(
                    '${widget.correctAnswers.length}',
                    style: const TextStyle(color: Colors.green, fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const Text('Doğru', style: TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        // Yanlış kutusu
        Expanded(
          child: GestureDetector(
            onTap: () => _showAnswerList(false),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.red.withValues(alpha: 0.3), Colors.red.withValues(alpha: 0.1)],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.red, width: 2),
              ),
              child: Column(
                children: [
                  const Icon(Icons.cancel, color: Colors.red, size: 28),
                  const SizedBox(height: 4),
                  Text(
                    '${widget.wrongAnswers.length}',
                    style: const TextStyle(color: Colors.red, fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const Text('Yanlış', style: TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAdButton() {
    return GestureDetector(
      onTap: () async {
        // Reklam simülasyonu
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => Center(
            child: Container(
              padding: const EdgeInsets.all(24),
              margin: const EdgeInsets.all(40),
              decoration: BoxDecoration(
                color: const Color(0xFF2E5A8C),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.amber),
              ),
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.play_circle_filled, color: Colors.amber, size: 50),
                  SizedBox(height: 16),
                  Text('Reklam İzleniyor...', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, decoration: TextDecoration.none)),
                  SizedBox(height: 24),
                  CircularProgressIndicator(color: Colors.amber),
                  SizedBox(height: 24),
                  Text('Oyununuz sıfırlanıyor...', style: TextStyle(color: Colors.white70, fontSize: 14, decoration: TextDecoration.none)),
                ],
              ),
            ),
          ),
        );

        await Future.delayed(const Duration(seconds: 3));
        if (mounted) {
          await context.read<Daily123Provider>().resetWithAd();
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFFD700), Color(0xFFFF8C00)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.amber.withValues(alpha: 0.4),
              blurRadius: 15,
              spreadRadius: 3,
            ),
          ],
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.play_circle_filled, color: Colors.white, size: 36),
            SizedBox(height: 6),
            Text('Watch Ad', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
            Text('& Replay', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
  
  // ignore: unused_element - Answer boxes için saklanıyor
  Widget _buildAnswerBoxes() {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () => _showAnswerList(true),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.green.withValues(alpha: 0.3), Colors.green.withValues(alpha: 0.1)],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.green, width: 2),
              ),
              child: Column(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 32),
                  const SizedBox(height: 8),
                  Text(
                    '${widget.correctAnswers.length}',
                    style: const TextStyle(color: Colors.green, fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                  const Text('Doğru', style: TextStyle(color: Colors.white70, fontSize: 14)),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: GestureDetector(
            onTap: () => _showAnswerList(false),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.red.withValues(alpha: 0.3), Colors.red.withValues(alpha: 0.1)],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.red, width: 2),
              ),
              child: Column(
                children: [
                  const Icon(Icons.cancel, color: Colors.red, size: 32),
                  const SizedBox(height: 8),
                  Text(
                    '${widget.wrongAnswers.length}',
                    style: const TextStyle(color: Colors.red, fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                  const Text('Yanlış', style: TextStyle(color: Colors.white70, fontSize: 14)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
  
  void _showAnswerList(bool isCorrect) {
    final answers = isCorrect ? widget.correctAnswers : widget.wrongAnswers;
    final title = isCorrect ? 'Doğru Cevaplar' : 'Yanlış Cevaplar';
    final color = isCorrect ? Colors.green : Colors.red;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _AnswerListSheet(
        answers: answers,
        title: title,
        color: color,
        isCorrect: isCorrect,
      ),
    );
  }

  Widget _buildMainResult() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: widget.isWin 
            ? [const Color(0xFF00F5A0), const Color(0xFF00D9F5)]
            : [const Color(0xFFFF4B2B), const Color(0xFFFF416C)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: (widget.isWin ? Colors.green : Colors.red).withValues(alpha: 0.3),
            blurRadius: 15,
            spreadRadius: 3,
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            widget.isWin ? Icons.emoji_events : Icons.timer_off,
            size: 36,
            color: Colors.white,
          ),
          const SizedBox(height: 6),
          Text(
            widget.isWin ? 'CONGRATS!' : 'TIME IS UP :(',
            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
          ),
          if (!widget.isWin)
            const Text(
              'See You Again Tomorrow',
              style: TextStyle(color: Colors.white70, fontSize: 12, fontStyle: FontStyle.italic),
            ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Kariyer İstatistikleri', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.5,
          children: [
            _statItem('Oyun Sayısı', '${_stats?.totalGames ?? 0}'),
            _statItem('Kazanma Oranı', '%${_stats?.winPercentage.toStringAsFixed(1) ?? '0'}'),
            _statItem('Güncel Seri', '${_stats?.currentStreak ?? 0}🔥'),
            _statItem('En Yüksek Seri', '${_stats?.highestStreak ?? 0}🏆'),
          ],
        ),
      ],
    );
  }

  Widget _statItem(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildRankingSection() {
    return Column(
      children: [
        _rankingRow(
          title: 'GÜNLÜK YARIŞMA',
          rank: _rankingData?['dailyRank'] ?? '-',
          total: _rankingData?['totalDailyPlayers'] ?? '-',
          avg: _rankingData?['dailyAvgPoints'] ?? '-',
          accentColor: const Color(0xFFFFD700),
        ),
        const SizedBox(height: 16),
        _rankingRow(
          title: 'GENEL SIRALAMA',
          rank: _rankingData?['globalRank'] ?? '-',
          total: _rankingData?['totalGlobalPlayers'] ?? '-',
          avg: _rankingData?['globalAvgPoints'] ?? '-',
          accentColor: const Color(0xFF6C27FF),
        ),
      ],
    );
  }

  Widget _rankingRow({
    required String title,
    required dynamic rank,
    required dynamic total,
    required dynamic avg,
    required Color accentColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accentColor.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Text(title, style: TextStyle(color: accentColor, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _rankInfo('Sıralama', '#$rank'),
              _rankInfo('Toplam Oyuncu', '$total'),
              _rankInfo('Ortalama Puan', '$avg'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _rankInfo(String label, String value) {
    return Column(
      children: [
        Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 11)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
      ],
    );
  }
}

/// Cevap listesi bottom sheet widget'ı
class _AnswerListSheet extends StatefulWidget {
  final List<AnsweredQuestion> answers;
  final String title;
  final Color color;
  final bool isCorrect;

  const _AnswerListSheet({
    required this.answers,
    required this.title,
    required this.color,
    required this.isCorrect,
  });

  @override
  State<_AnswerListSheet> createState() => _AnswerListSheetState();
}

class _AnswerListSheetState extends State<_AnswerListSheet> {
  final Set<int> _selectedIndices = {};

  void _toggleItem(int index) {
    setState(() {
      if (_selectedIndices.contains(index)) {
        _selectedIndices.remove(index);
      } else {
        _selectedIndices.add(index);
      }
    });
  }

  void _toggleSelectAll() {
    setState(() {
      if (_selectedIndices.length == widget.answers.length) {
        _selectedIndices.clear();
      } else {
        _selectedIndices.addAll(List.generate(widget.answers.length, (i) => i));
      }
    });
  }

  void _addSelectedToMyWords() {
    final gp = context.read<GameProvider>();
    int addedCount = 0;
    
    for (final index in _selectedIndices) {
      final answer = widget.answers[index];
      final entry = AnsweredEntry(
        prompt: answer.prompt,
        correctText: answer.correctAnswer,
        mode: QuestionMode.trToEn,
        selectedIndex: answer.isCorrect ? 0 : 1,
        correctIndex: 0,
        earnedPoints: 0,
      );
      
      if (!gp.isSaved(entry)) {
        gp.addToPool(entry);
        addedCount++;
      }
    }
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Text('$addedCount kelime "Kelimelerim"e eklendi'),
          ],
        ),
        backgroundColor: const Color(0xFF2E5A8C),
      ),
    );
    
    setState(() {
      _selectedIndices.clear();
    });
  }

  void _removeSelectedFromMyWords() {
    final gp = context.read<GameProvider>();
    int removedCount = 0;
    
    for (final index in _selectedIndices) {
      final answer = widget.answers[index];
      final entry = AnsweredEntry(
        prompt: answer.prompt,
        correctText: answer.correctAnswer,
        mode: QuestionMode.trToEn,
        selectedIndex: answer.isCorrect ? 0 : 1,
        correctIndex: 0,
        earnedPoints: 0,
      );
      
      if (gp.isSaved(entry)) {
        gp.removeFromPool(entry);
        removedCount++;
      }
    }
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$removedCount kelime "Kelimelerim"den çıkarıldı'),
        backgroundColor: Colors.orange,
      ),
    );
    
    setState(() {
      _selectedIndices.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final gp = context.watch<GameProvider>();
    
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Color(0xFF2E5A8C),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Başlık satırı
          Row(
            children: [
              Icon(widget.isCorrect ? Icons.check_circle : Icons.cancel, color: widget.color, size: 28),
              const SizedBox(width: 12),
              Text(widget.title, style: TextStyle(color: widget.color, fontSize: 20, fontWeight: FontWeight.bold)),
              const Spacer(),
              Text('${widget.answers.length} kelime', style: const TextStyle(color: Colors.white70)),
            ],
          ),
          const SizedBox(height: 12),
          
          // Tümünü Seç / Ekle / Çıkar butonları
          if (widget.answers.isNotEmpty)
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: _toggleSelectAll,
                  icon: Icon(
                    _selectedIndices.length == widget.answers.length 
                        ? Icons.deselect 
                        : Icons.select_all,
                    size: 18,
                  ),
                  label: Text(
                    _selectedIndices.length == widget.answers.length 
                        ? 'Tümünü Kaldır' 
                        : 'Tümünü Seç',
                    style: const TextStyle(fontSize: 12),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white70,
                    side: const BorderSide(color: Colors.white30),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
                const Spacer(),
                if (_selectedIndices.isNotEmpty) ...[
                  ElevatedButton.icon(
                    onPressed: _addSelectedToMyWords,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Ekle', style: TextStyle(fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: _removeSelectedFromMyWords,
                    icon: const Icon(Icons.remove, size: 18),
                    label: const Text('Çıkar', style: TextStyle(fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                ],
              ],
            ),
          const SizedBox(height: 12),
          
          // Liste
          Expanded(
            child: widget.answers.isEmpty
                ? Center(
                    child: Text(
                      widget.isCorrect ? 'Henüz doğru cevap yok' : 'Hiç yanlış cevap yok! 🎉',
                      style: const TextStyle(color: Colors.white54, fontSize: 16),
                    ),
                  )
                : ListView.builder(
                    itemCount: widget.answers.length,
                    itemBuilder: (context, index) {
                      final answer = widget.answers[index];
                      final isSelected = _selectedIndices.contains(index);
                      
                      // Check if already saved
                      final entry = AnsweredEntry(
                        prompt: answer.prompt,
                        correctText: answer.correctAnswer,
                        mode: QuestionMode.trToEn,
                        selectedIndex: answer.isCorrect ? 0 : 1,
                        correctIndex: 0,
                        earnedPoints: 0,
                      );
                      final isSaved = gp.isSaved(entry);
                      
                      return GestureDetector(
                        onTap: () => _toggleItem(index),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isSelected 
                                ? widget.color.withValues(alpha: 0.3) 
                                : widget.color.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected 
                                  ? widget.color 
                                  : widget.color.withValues(alpha: 0.3),
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              // Checkbox
                              Checkbox(
                                value: isSelected,
                                onChanged: (_) => _toggleItem(index),
                                activeColor: widget.color,
                              ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      answer.prompt,
                                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        const Text('Doğru: ', style: TextStyle(color: Colors.white54, fontSize: 12)),
                                        Text(answer.correctAnswer, style: const TextStyle(color: Colors.green, fontSize: 14, fontWeight: FontWeight.w600)),
                                      ],
                                    ),
                                    if (!widget.isCorrect && answer.userAnswer != null)
                                      Row(
                                        children: [
                                          const Text('Senin: ', style: TextStyle(color: Colors.white54, fontSize: 12)),
                                          Text(answer.userAnswer!, style: const TextStyle(color: Colors.red, fontSize: 14, fontWeight: FontWeight.w600)),
                                        ],
                                      ),
                                  ],
                                ),
                              ),
                              // Saved indicator
                              if (isSaved)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.bookmark, color: Colors.blue, size: 16),
                                      SizedBox(width: 4),
                                      Text('Kayıtlı', style: TextStyle(color: Colors.blue, fontSize: 11)),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          
          // Alt bilgi
          if (_selectedIndices.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                '${_selectedIndices.length} kelime seçildi',
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ),
        ],
      ),
    );
  }
}
