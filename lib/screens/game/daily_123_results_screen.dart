import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/daily_123.dart';
import '../../services/daily_123_service.dart';
import '../../providers/daily_123_provider.dart';
import '../../providers/game_provider.dart';
import '../../models/answered_entry.dart';
import '../../models/question_mode.dart';
import '../../widgets/game/game_background.dart';
import '../../services/word_usage_service.dart';
import '../../services/ad_service.dart';
import '../../services/sound_service.dart';

import '../../providers/language_provider.dart';
import '../../widgets/common/ad_banner_widget.dart';
import '../../widgets/common/top_toast.dart';

import '../../services/share_service.dart';
import '../../services/shop_service.dart';
import '../home/widgets/home_dialogs.dart';

import '../../widgets/game/learning_summary_card.dart';

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
  final GlobalKey _boundaryKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final stats = await Daily123Service.instance.getStats();
      final ranking = await Daily123Service.instance.getRankingData(
        score: widget.finalScore,
        seconds: widget.timeSpent
      );
      if (mounted) {
        setState(() {
          _stats = stats;
          _rankingData = ranking;
          if (widget.isWin) {
            SoundService.instance.playSuccess();
          }
        });

        final allWords = [...widget.correctAnswers, ...widget.wrongAnswers]
            .map((e) => e.correctAnswer)
            .cast<String>()
            .toList();
        WordUsageService.instance.markWordsUsed(allWords);
        
        final isNewUser = await ShopService.instance.checkAndGiveWelcomeGift();
        if (isNewUser && mounted) {
          HomeDialogs.showWelcomeGiftDialog(context);
        }
      }
    } catch (e) {
      debugPrint('⚠️ Daily123Results: Data load failed: $e');
      // Başarisiz olsa da kullanıcıyı bekletme, eldeki veriyi (mock/empty) göster
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const GameBackground(
        child: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    final lang = context.watch<LanguageProvider>();
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(lang.getString('daily_results'), style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.5, color: Colors.white)),
        leading: IconButton(
          onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
        ),
        actions: [
          IconButton(
            onPressed: () => ShareService.instance.shareWidgetAsImage(_boundaryKey, 'LUGORENA\'da Daily 123 skoruma bak!'),
            icon: const Icon(Icons.share, color: Colors.white, size: 24),
            tooltip: 'Paylaş',
          ),
          IconButton(
            onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
            icon: const Icon(Icons.home, color: Colors.white, size: 28),
            tooltip: lang.getString('home'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: GameBackground(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(top: 100, left: 24, right: 24, bottom: 24),
          child: Column(
            children: [
                RepaintBoundary(
                  key: _boundaryKey,
                  child: Container(
                    color: const Color(0xFF102A43), // Background for sharing
                    child: Column(
                      children: [
                        IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(child: _buildMainResult(lang)),
                              const SizedBox(width: 12),
                              Expanded(child: _buildAdButton(lang)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildScoreAndAnswerRow(lang),
                        const SizedBox(height: 20),
                        _buildStatsGrid(lang),
                        const SizedBox(height: 20),
                        LearningSummaryCard(answerHistory: [...widget.correctAnswers, ...widget.wrongAnswers].map((q) => AnsweredEntry(
                          prompt: q.prompt,
                          selectedIndex: q.isCorrect ? 1 : 0, // Mock index
                          correctIndex: 1, // Mock index
                          earnedPoints: 0,
                          mode: QuestionMode.trToEn,
                          correctText: q.correctAnswer,
                          selectedText: q.userAnswer,
                          turkishMeaning: q.turkishMeaning,
                        )).toList()),
                        const SizedBox(height: 20),
                        _buildRankingSection(lang),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                // Skor tabloarında kare şeklinde reklam (Medium Rectangle)
                const Center(
                  child: AdBannerWidget(isMediumRectangle: true),
                ),
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
                    child: Text(lang.getString('main_menu'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
  }
  
  Widget _buildScoreAndAnswerRow(LanguageProvider lang) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: MediaQuery.of(context).size.width < 360 ? 2 : 4,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.0,
      children: [
        _resultBox(
          icon: Icons.timer,
          iconColor: Colors.cyan,
          value: '${widget.timeSpent}.00 ${lang.getString('seconds_short')}',
          label: lang.getString('time_short'),
          backgroundColor: Colors.white.withAlpha(26),
        ),
        _resultBox(
          icon: Icons.stars,
          iconColor: Colors.amber,
          value: '${widget.finalScore}',
          label: lang.getString('points'),
          backgroundColor: Colors.white.withAlpha(26),
        ),
        GestureDetector(
          onTap: () => _showAnswerList(true),
          child: _resultBox(
            icon: Icons.check_circle,
            iconColor: Colors.green,
            value: '${widget.correctAnswers.length}',
            label: lang.getString('correct'),
            gradient: LinearGradient(
              colors: [Colors.green.withAlpha(77), Colors.green.withAlpha(26)],
            ),
            borderColor: Colors.green,
          ),
        ),
        GestureDetector(
          onTap: () => _showAnswerList(false),
          child: _resultBox(
            icon: Icons.cancel,
            iconColor: Colors.red,
            value: '${widget.wrongAnswers.length}',
            label: lang.getString('wrong'),
            gradient: LinearGradient(
              colors: [Colors.red.withAlpha(77), Colors.red.withAlpha(26)],
            ),
            borderColor: Colors.red,
          ),
        ),
      ],
    );
  }

  Widget _resultBox({
    required IconData icon,
    required Color iconColor,
    required String value,
    required String label,
    Color? backgroundColor,
    Gradient? gradient,
    Color? borderColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: backgroundColor,
        gradient: gradient,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor ?? Colors.white24, width: borderColor != null ? 2 : 1),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: iconColor, size: 24),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10)),
        ],
      ),
    );
  }

  Widget _buildAdButton(LanguageProvider lang) {
    return GestureDetector(
      onTap: () async {
        if (AdService.instance.isPremium) {
          await context.read<Daily123Provider>().resetWithAd();
          if (mounted) {
            Navigator.of(context).popUntil((route) => route.isFirst);
          }
          return;
        }

        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => Center(
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF2E5A8C),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(color: Colors.amber),
                  const SizedBox(height: 16),
                  Text(lang.getString('loading_ad'), 
                    style: const TextStyle(color: Colors.white, fontSize: 16, decoration: TextDecoration.none)),
                ],
              ),
            ),
          ),
        );

        // Gerçek reklam göster
        final rewardAmount = await AdService.instance.showRewardedAd();
        
        if (!mounted) return;
        Navigator.of(context).pop(); // Yükleniyor diyaloğunu kapat
        
        if (rewardAmount > 0) {
          await context.read<Daily123Provider>().resetWithAd();
          if (mounted) {
            Navigator.of(context).popUntil((route) => route.isFirst);
          }
        } else {
           TopToast.show(
            context,
            title: lang.getString('error'),
            message: lang.getString('ad_failed_or_skipped'),
            icon: Icons.error_outline_rounded,
            color: Colors.redAccent,
          );
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
              color: Colors.amber.withAlpha(102),
              blurRadius: 15,
              spreadRadius: 3,
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.play_circle_filled, color: Colors.white, size: 36),
            const SizedBox(height: 6),
            Text(lang.getString('watch_ad'), style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
            Text('& ${lang.getString('replay')}', style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
  
  void _showAnswerList(bool isCorrect) {
    final lang = context.read<LanguageProvider>();
    final answers = isCorrect ? widget.correctAnswers : widget.wrongAnswers;
    final title = isCorrect ? lang.getString('correct_answers') : lang.getString('wrong_answers');
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

  Widget _buildMainResult(LanguageProvider lang) {
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
            color: (widget.isWin ? Colors.green : Colors.red).withAlpha(77),
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
            widget.isWin ? lang.getString('congrats') : lang.getString('time_up'),
            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
          ),
          if (!widget.isWin)
            Text(
              lang.getString('see_you_tomorrow'),
              style: const TextStyle(color: Colors.white70, fontSize: 12, fontStyle: FontStyle.italic),
            ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid(LanguageProvider lang) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(lang.getString('career_stats'), style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.5,
          children: [
            _statItem(lang.getString('game_count'), '${_stats?.totalGames ?? 0}'),
            _statItem(lang.getString('win_rate'), '%${_stats?.winPercentage.toStringAsFixed(1) ?? '0'}'),
            _statItem(lang.getString('current_streak'), (_stats != null && _stats!.currentStreak > 0) ? '${_stats?.currentStreak}🔥' : '-'),
            _statItem(lang.getString('highest_streak'), (_stats != null && _stats!.highestStreak > 0) ? '${_stats?.highestStreak}🏆' : '-'),
          ],
        ),
      ],
    );
  }

  Widget _statItem(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(13),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withAlpha(26)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, style: TextStyle(color: Colors.white.withAlpha(153), fontSize: 12)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildRankingSection(LanguageProvider lang) {
    return Column(
      children: [
        _rankingRow(
          lang,
          title: lang.getString('daily_competition'),
          rank: _rankingData?['dailyRank'] ?? '-',
          total: _rankingData?['totalDailyPlayers'] ?? '-',
          avg: _rankingData?['dailyAvgPoints'] ?? '-',
          accentColor: const Color(0xFFFFD700),
          prevPlayer: _rankingData?['prevPlayer'],
          nextPlayer: _rankingData?['nextPlayer'],
          myScore: widget.finalScore,
          myTime: widget.timeSpent,
        ),
        const SizedBox(height: 16),
        _rankingRow(
          lang,
          title: lang.getString('global_ranking'),
          rank: _rankingData?['globalRank'] ?? '-',
          total: _rankingData?['totalGlobalPlayers'] ?? '-',
          avg: _rankingData?['globalAvgPoints'] ?? '-',
          accentColor: const Color(0xFF6C27FF),
        ),
      ],
    );
  }

  Widget _rankingRow(
    LanguageProvider lang, {
    required String title,
    required dynamic rank,
    required dynamic total,
    required dynamic avg,
    required Color accentColor,
    Map<String, dynamic>? prevPlayer,
    Map<String, dynamic>? nextPlayer,
    int? myScore,
    int? myTime,
  }) {
    final isDaily = prevPlayer != null || nextPlayer != null;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(13),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: accentColor.withAlpha(51)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: TextStyle(color: accentColor, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
              if (isDaily)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: accentColor.withAlpha(51),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${lang.getString('total_players')}: $total',
                    style: TextStyle(color: accentColor, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          
          if (isDaily) ...[
            // Nearby Players List
            if (prevPlayer != null) _buildNeighborItem(prevPlayer, (rank as int) - 1, false, accentColor),
            _buildNeighborItem({
              'username': 'SİZ',
              'score': myScore,
              'seconds': myTime,
            }, (rank as int), true, accentColor),
            if (nextPlayer != null) _buildNeighborItem(nextPlayer, (rank) + 1, false, accentColor),
            
            const SizedBox(height: 16),
            const Divider(color: Colors.white10),
            const SizedBox(height: 8),
            Center(
              child: _rankInfo(lang.getString('avg_points'), '$avg'),
            ),
          ] else ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _rankInfo(lang.getString('rank_label'), '#$rank'),
                _rankInfo(lang.getString('total_players'), '$total'),
                _rankInfo(lang.getString('avg_points'), '$avg'),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNeighborItem(Map<String, dynamic> data, int rank, bool isMe, Color accentColor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isMe ? accentColor.withAlpha(40) : Colors.white.withAlpha(8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isMe ? accentColor : Colors.white12, width: isMe ? 1.5 : 1),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 30,
            child: Text(
              '#$rank',
              style: TextStyle(
                color: isMe ? accentColor : Colors.white54,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              data['username'] ?? 'Player',
              style: TextStyle(
                color: isMe ? Colors.white : Colors.white70,
                fontWeight: isMe ? FontWeight.bold : FontWeight.normal,
                fontSize: 14,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${data['score']} P',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
              ),
              Text(
                '${data['seconds']} sn',
                style: TextStyle(color: isMe ? accentColor : Colors.cyanAccent, fontSize: 10, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _rankInfo(String label, String value) {
    return Column(
      children: [
        Text(label, style: TextStyle(color: Colors.white.withAlpha(128), fontSize: 11)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
      ],
    );
  }
}

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
        mode: answer.isCorrect ? QuestionMode.enToTr : QuestionMode.trToEn,
        turkishMeaning: answer.turkishMeaning,
        selectedIndex: answer.isCorrect ? 0 : 1,
        correctIndex: 0,
        earnedPoints: 0,
      );
      
      if (!gp.isSaved(entry)) {
        gp.addToPool(entry);
        addedCount++;
      }
    }
    
    TopToast.show(
      context,
      title: 'Koleksiyon Güncellendi',
      message: '$addedCount kelime havuzunuza katıldı.',
      icon: Icons.bookmark_added_rounded,
      color: Colors.amber,
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
        mode: answer.isCorrect ? QuestionMode.enToTr : QuestionMode.trToEn,
        turkishMeaning: answer.turkishMeaning,
        selectedIndex: answer.isCorrect ? 0 : 1,
        correctIndex: 0,
        earnedPoints: 0,
      );
      
      if (gp.isSaved(entry)) {
        gp.removeFromPool(entry);
        removedCount++;
      }
    }
    
    TopToast.show(
      context,
      title: 'Koleksiyondan Çıkarıldı',
      message: '$removedCount kelime havuzdan temizlendi.',
      icon: Icons.bookmark_remove_rounded,
      color: Colors.redAccent,
    );
    
    setState(() {
      _selectedIndices.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final gp = context.watch<GameProvider>();
    final lang = context.watch<LanguageProvider>();
    
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Color(0xFF2E5A8C),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(widget.isCorrect ? Icons.check_circle : Icons.cancel, color: widget.color, size: 28),
              const SizedBox(width: 12),
              Text(widget.title, style: TextStyle(color: widget.color, fontSize: 20, fontWeight: FontWeight.bold)),
              const Spacer(),
              Text(lang.getString('word_count_label').replaceAll('{count}', widget.answers.length.toString()), style: const TextStyle(color: Colors.white70)),
            ],
          ),
          const SizedBox(height: 12),
          
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
                        ? lang.getString('deselect_all') 
                        : lang.getString('select_all'),
                    style: const TextStyle(fontSize: 12),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white70,
                    side: const BorderSide(color: Colors.white24),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const Spacer(),
                Text(
                  _selectedIndices.isNotEmpty 
                      ? '${_selectedIndices.length} SEÇİLDİ' 
                      : '',
                  style: const TextStyle(color: Colors.amber, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          const SizedBox(height: 12),
          
          Expanded(
            child: widget.answers.isEmpty
                ? Center(
                    child: Text(
                      widget.isCorrect 
                          ? lang.getString('no_correct_yet') 
                          : lang.getString('no_wrong_yet'),
                      style: const TextStyle(color: Colors.white54, fontSize: 16),
                    ),
                  )
                : ListView.builder(
                    itemCount: widget.answers.length,
                    itemBuilder: (context, index) {
                      final answer = widget.answers[index];
                      final isSelected = _selectedIndices.contains(index);
                      
                      final entry = AnsweredEntry(
                        prompt: answer.prompt,
                        correctText: answer.correctAnswer,
                        mode: QuestionMode.trToEn,
                        turkishMeaning: answer.turkishMeaning,
                        selectedIndex: answer.isCorrect ? 0 : 1,
                        correctIndex: 0,
                        earnedPoints: 0,
                      );
                      final isSaved = gp.isSaved(entry);
                      
                      return GestureDetector(
                        onTap: () => _toggleItem(index),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isSelected 
                                ? Colors.amber.withAlpha(20) 
                                : widget.color.withAlpha(15),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSelected 
                                  ? Colors.amber 
                                  : widget.color.withAlpha(50),
                              width: isSelected ? 1.5 : 1,
                            ),
                            boxShadow: isSelected ? [
                              BoxShadow(color: Colors.amber.withAlpha(30), blurRadius: 10)
                            ] : null,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                isSelected ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                                color: isSelected ? Colors.amber : Colors.white24,
                                size: 22,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      answer.prompt,
                                      style: TextStyle(
                                        color: isSelected ? Colors.amber : Colors.white, 
                                        fontSize: 15, 
                                        fontWeight: FontWeight.bold
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Text(answer.correctAnswer, style: const TextStyle(color: Colors.greenAccent, fontSize: 13, fontWeight: FontWeight.w600)),
                                        if (answer.turkishMeaning != null) ...[
                                          const SizedBox(width: 8),
                                          Text('•', style: TextStyle(color: Colors.white.withAlpha(50))),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              answer.turkishMeaning!, 
                                              style: TextStyle(color: Colors.white.withAlpha(150), fontSize: 12, fontStyle: FontStyle.italic),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              if (isSaved)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.withAlpha(40),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.blue.withAlpha(100)),
                                  ),
                                  child: const Icon(Icons.bookmark, color: Colors.blueAccent, size: 14),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
          if (widget.answers.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: AnimatedScale(
                  scale: _selectedIndices.isNotEmpty ? 1.02 : 1.0,
                  duration: const Duration(milliseconds: 200),
                  child: ElevatedButton(
                    onPressed: _selectedIndices.isNotEmpty ? _addSelectedToMyWords : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber,
                      foregroundColor: Colors.black,
                      disabledBackgroundColor: Colors.white.withAlpha(26),
                      disabledForegroundColor: Colors.white24,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: _selectedIndices.isNotEmpty ? 12 : 0,
                      shadowColor: Colors.amber.withAlpha(128),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _selectedIndices.isNotEmpty ? Icons.auto_awesome : Icons.bookmark_add_outlined,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          _selectedIndices.isNotEmpty 
                              ? '${_selectedIndices.length} KELİMEYİ KAYDET'
                              : 'KAYDEDİLECEK KELİME SEÇİN',
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 0.5),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
