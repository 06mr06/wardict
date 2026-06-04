import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../app.dart';
import '../../models/answered_entry.dart';
import '../../models/question_mode.dart';
import '../../providers/game_provider.dart';
import '../../providers/fill_blank_practice_provider.dart';
import '../../providers/language_provider.dart';
import '../../services/weekly_practice_points_service.dart';
import '../../widgets/home/weekly_milestone_reward_dialog.dart';
import '../../services/ranking_service.dart';
import '../../services/user_profile_service.dart';
import 'fill_blank_practice_screen.dart';

TextSpan _reviewSentenceSpans(FillBlankAnswerRecord r) {
  const base = TextStyle(
    color: Colors.white,
    fontSize: 15,
    fontWeight: FontWeight.w600,
    height: 1.35,
  );
  const green = TextStyle(
    color: Color(0xFF69F0AE),
    fontSize: 15,
    fontWeight: FontWeight.w800,
    height: 1.35,
  );
  final blank = RegExp(r'_{2,}');
  final m = blank.firstMatch(r.sentence);
  if (m == null) {
    final t = r.englishFilled.trim().isNotEmpty
        ? r.englishFilled
        : r.sentence;
    return TextSpan(text: t, style: base);
  }
  return TextSpan(
    children: [
      TextSpan(text: r.sentence.substring(0, m.start), style: base),
      TextSpan(text: r.correctAnswer, style: green),
      TextSpan(text: r.sentence.substring(m.end), style: base),
    ],
  );
}

const TextStyle _kReviewTrPlain = TextStyle(
  color: Colors.white70,
  fontSize: 13.5,
  fontWeight: FontWeight.w500,
  height: 1.35,
);

const TextStyle _kReviewPairGreen = TextStyle(
  color: Color(0xFF69F0AE),
  fontSize: 13.5,
  fontWeight: FontWeight.w800,
  height: 1.35,
);

const TextStyle _kReviewPairRed = TextStyle(
  color: Colors.redAccent,
  fontSize: 13.5,
  fontWeight: FontWeight.w700,
  height: 1.35,
);

const TextStyle _kReviewPairSep = TextStyle(
  color: Colors.white54,
  fontSize: 13.5,
  fontWeight: FontWeight.w500,
  height: 1.35,
);

String _correctAnswerPairLine(FillBlankAnswerRecord r) {
  final en = r.correctAnswer.trim();
  final trMean = r.wordTurkish.trim();
  if (en.isEmpty) return trMean;
  if (trMean.isEmpty) return en;
  return '$en — $trMean';
}

String _wrongSelectionPairLine(FillBlankAnswerRecord r) {
  final en = r.selectedAnswer!.trim();
  final tr = r.selectedMeaningTurkish?.trim() ?? '';
  if (tr.isEmpty) return en;
  return '$en — $tr';
}

String _fillBlankPrompt(FillBlankAnswerRecord r) {
  final e = r.englishFilled.trim();
  if (e.isNotEmpty) return e;
  return r.sentence.trim();
}

AnsweredEntry _myWordsEntryForTarget(FillBlankAnswerRecord r) {
  final trMean = r.wordTurkish.trim();
  return AnsweredEntry(
    prompt: _fillBlankPrompt(r),
    selectedIndex: r.isCorrect ? 0 : 1,
    correctIndex: 0,
    earnedPoints: r.points,
    mode: QuestionMode.enToTr,
    selectedText: r.selectedAnswer,
    correctText: r.correctAnswer.trim(),
    turkishMeaning: trMean.isNotEmpty ? trMean : null,
  );
}

AnsweredEntry? _myWordsEntryForWrongPick(FillBlankAnswerRecord r) {
  if (r.isCorrect) return null;
  final w = r.selectedAnswer?.trim();
  if (w == null || w.isEmpty) return null;
  if (w == r.correctAnswer.trim()) return null;
  final tr = r.selectedMeaningTurkish?.trim() ?? '';
  return AnsweredEntry(
    prompt: _fillBlankPrompt(r),
    selectedIndex: 1,
    correctIndex: 0,
    earnedPoints: 0,
    mode: QuestionMode.enToTr,
    selectedText: w,
    correctText: w,
    turkishMeaning: tr.isNotEmpty ? tr : null,
  );
}

List<InlineSpan> _reviewPairLineSpans(FillBlankAnswerRecord r) {
  final correctLine = _correctAnswerPairLine(r);
  final spans = <InlineSpan>[
    TextSpan(text: correctLine, style: _kReviewPairGreen),
  ];
  if (!r.isCorrect &&
      r.selectedAnswer != null &&
      r.selectedAnswer!.trim().isNotEmpty) {
    final wrongLine = _wrongSelectionPairLine(r);
    if (wrongLine != correctLine) {
      spans.add(const TextSpan(text: ' · ', style: _kReviewPairSep));
      spans.add(TextSpan(text: wrongLine, style: _kReviewPairRed));
    }
  }
  return spans;
}

class FillBlankResultsScreen extends StatefulWidget {
  final int totalQuestions;
  final int sessionPoints;
  final List<FillBlankAnswerRecord> records;
  final String userLevelCode;

  const FillBlankResultsScreen({
    super.key,
    required this.totalQuestions,
    required this.sessionPoints,
    required this.records,
    this.userLevelCode = 'A2',
  });

  @override
  State<FillBlankResultsScreen> createState() => _FillBlankResultsScreenState();
}

class _FillBlankResultsScreenState extends State<FillBlankResultsScreen> {
  bool _done = false;
  ScaffoldMessengerState? _scaffoldMessenger;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scaffoldMessenger ??= ScaffoldMessenger.maybeOf(context);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _applyRewards());
  }

  @override
  void dispose() {
    _scaffoldMessenger?.clearSnackBars();
    super.dispose();
  }

  Future<void> _applyRewards() async {
    if (_done || !mounted) return;
    _done = true;
    final pts = widget.sessionPoints;
    if (pts > 0) {
      final profile = await UserProfileService.instance.loadProfile();
      await RankingService.instance.addScore(profile.username, pts);
      final hits =
          await WeeklyPracticePointsService.instance.addSessionPoints(pts);
      await WeeklyPracticePointsService.instance.refreshNotifier();
      if (!mounted) return;
      for (final t in hits) {
        if (!mounted) return;
        await WeeklyMilestoneRewardDialog.show(context, t);
      }
    }
  }

  void _goHome() {
    final nav = navigatorKey.currentState ?? Navigator.of(context);
    nav.pushNamedAndRemoveUntil('/home', (_) => false);
  }

  void _playAgain() {
    final level = widget.userLevelCode;
    final nav = navigatorKey.currentState ?? Navigator.of(context);
    nav.pushReplacement(
      MaterialPageRoute(
        builder: (ctx) => ChangeNotifierProvider(
          create: (_) => FillBlankPracticeProvider(),
          child: FillBlankPracticeScreen(userLevelCode: level),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    final c = widget.records.where((r) => r.isCorrect).length;
    final t = widget.totalQuestions;
    final pts = widget.sessionPoints;

    return Scaffold(
      backgroundColor: const Color(0xFF1A3A5C),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A3A5C),
        foregroundColor: Colors.white,
        title: Text(lang.getString('fill_blank_results_title')),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF7E57C2).withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF7E57C2)),
            ),
            child: Column(
              children: [
                Text(
                  lang.format('fill_blank_score_summary', {
                    'c': '$c',
                    't': '$t',
                  }),
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.stars, color: Colors.amber),
                    const SizedBox(width: 8),
                    Text(
                      '${lang.getString('points')}: $pts',
                      style: const TextStyle(
                          color: Colors.amber,
                          fontSize: 22,
                          fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            lang.getString('fill_blank_review'),
            style: const TextStyle(
                color: Colors.white70,
                fontSize: 16,
                fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ...widget.records.map((r) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: r.isCorrect
                      ? Colors.green.withAlpha(51)
                      : Colors.red.withAlpha(51),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: r.isCorrect ? Colors.green : Colors.red,
                    width: 2,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Icon(
                            r.isCorrect
                                ? Icons.check_circle_rounded
                                : Icons.cancel_rounded,
                            color: r.isCorrect
                                ? Colors.greenAccent
                                : Colors.redAccent,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text.rich(_reviewSentenceSpans(r)),
                              if (r.sentenceTurkish != null &&
                                  r.sentenceTurkish!.trim().isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text(
                                  r.sentenceTurkish!.trim(),
                                  style: _kReviewTrPlain,
                                ),
                              ],
                              if (r.correctAnswer.trim().isNotEmpty ||
                                  r.wordTurkish.trim().isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Text.rich(
                                        TextSpan(
                                            children: _reviewPairLineSpans(r)),
                                      ),
                                    ),
                                    Consumer<GameProvider>(
                                      builder: (context, gp, _) {
                                        final targetEntry =
                                            _myWordsEntryForTarget(r);
                                        final wrongEntry =
                                            _myWordsEntryForWrongPick(r);
                                        return Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IconButton(
                                              tooltip: lang.getString(
                                                  'fill_blank_save_target_tooltip'),
                                              visualDensity:
                                                  VisualDensity.compact,
                                              padding: EdgeInsets.zero,
                                              constraints:
                                                  const BoxConstraints(
                                                minWidth: 36,
                                                minHeight: 36,
                                              ),
                                              icon: Icon(
                                                gp.isSaved(targetEntry)
                                                    ? Icons.bookmark_added
                                                    : Icons
                                                        .bookmark_add_outlined,
                                                size: 22,
                                                color: gp.isSaved(targetEntry)
                                                    ? Colors.amber
                                                    : Colors.white54,
                                              ),
                                              onPressed: () =>
                                                  gp.toggleInPool(targetEntry),
                                            ),
                                            if (wrongEntry != null)
                                              IconButton(
                                                tooltip: lang.getString(
                                                    'fill_blank_save_wrong_pick_tooltip'),
                                                visualDensity:
                                                    VisualDensity.compact,
                                                padding: EdgeInsets.zero,
                                                constraints:
                                                    const BoxConstraints(
                                                  minWidth: 36,
                                                  minHeight: 36,
                                                ),
                                                icon: Icon(
                                                  gp.isSaved(wrongEntry)
                                                      ? Icons.bookmark_added
                                                      : Icons
                                                          .bookmark_add_outlined,
                                                  size: 22,
                                                  color: gp.isSaved(wrongEntry)
                                                      ? Colors.redAccent
                                                      : Colors.white54,
                                                ),
                                                onPressed: () => gp
                                                    .toggleInPool(wrongEntry),
                                              ),
                                          ],
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (r.isCorrect)
                      Text(
                        '+${r.points} ${lang.getString('points')}',
                        style: const TextStyle(
                          color: Color(0xFF69F0AE),
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      )
                    else ...[
                      if (r.selectedAnswer == null ||
                          r.selectedAnswer!.trim().isEmpty)
                        Text(
                          lang.getString('fill_blank_no_answer'),
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _goHome,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3F51B5),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 48),
                  ),
                  child: Text(lang.getString('home')),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _playAgain,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7E57C2),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 48),
                  ),
                  child: Text(lang.getString('play_again')),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
