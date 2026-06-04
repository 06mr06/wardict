import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import '../models/user_level.dart';
import 'word_pool_service.dart';
import 'word_category_service.dart';

class ClozeQuestion {
  final String sentenceDisplay;
  final String correctEnglish;
  final String? turkishHint;
  final String? sentenceTurkish;
  /// Cümle içinde yeşil boyanacak Türkçe yüzey biçimi (ör. çekimli fiil).
  final String? turkishHighlight;
  final String questionLevel;
  final List<String> options;
  final List<String> optionMeanings;
  final int correctIndex;

  const ClozeQuestion({
    required this.sentenceDisplay,
    required this.correctEnglish,
    this.turkishHint,
    this.sentenceTurkish,
    this.turkishHighlight,
    required this.questionLevel,
    required this.options,
    required this.optionMeanings,
    required this.correctIndex,
  });
}

class SentenceClozeService {
  SentenceClozeService._();
  static final SentenceClozeService instance = SentenceClozeService._();

  List<Map<String, dynamic>> _items = [];
  final Random _random = Random();

  /// UTF-8 JSON expected; accepts UTF-16 LE (legacy Windows saves).
  static String _decodeSentenceClozeJson(Uint8List bytes) {
    if (bytes.length >= 2 && bytes[0] == 0xFF && bytes[1] == 0xFE) {
      return _decodeUtf16Le(ByteData.sublistView(bytes, 2));
    }
    if (bytes.length >= 4 && bytes[0] == 0x5B && bytes[1] == 0) {
      return _decodeUtf16Le(ByteData.sublistView(bytes));
    }
    return utf8.decode(bytes);
  }

  static String _decodeUtf16Le(ByteData bd) {
    final n = bd.lengthInBytes ~/ 2;
    final codeUnits = Uint16List(n);
    for (var i = 0; i < n; i++) {
      codeUnits[i] = bd.getUint16(i * 2, Endian.little);
    }
    return String.fromCharCodes(codeUnits);
  }

  Future<void> load() async {
    if (_items.isNotEmpty) return;
    try {
      final data = await rootBundle.load('assets/data/sentence_cloze.json');
      final raw = _decodeSentenceClozeJson(data.buffer.asUint8List());
      final list = json.decode(raw) as List<dynamic>;
      _items = list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (e) {
      debugPrint('SentenceClozeService load error: $e');
      _items = [];
    }
  }

  String? lookupTurkish(String english) {
    final key = english.trim().toLowerCase();
    const codes = ['A1', 'A2', 'B1', 'B2', 'C1', 'C2'];
    for (final code in codes) {
      for (final w in WordPoolService.instance.getWordsForLevel(code)) {
        if ((w['english'] ?? '').toLowerCase() == key) {
          return w['turkish'];
        }
      }
    }
    return null;
  }

  bool _sameCategory(String target, String candidate) {
    final t = WordCategoryService.instance.getCategory(target);
    if (t == 'other') return true;
    return WordCategoryService.instance.getCategory(candidate) == t;
  }

  List<String> _pickDistractors({
    required String answer,
    required String primaryLevel,
    required int count,
  }) {
    final ans = answer.toLowerCase();
    final pool = <Map<String, String>>[];
    for (final lv in _levelsForDistractors(primaryLevel)) {
      pool.addAll(WordPoolService.instance.getWordsForLevel(lv));
    }
    var candidates = pool
        .map((w) => w['english'] ?? '')
        .where(
          (e) =>
              e.isNotEmpty &&
              e.toLowerCase() != ans &&
              _sameCategory(answer, e),
        )
        .toList();
    candidates.shuffle(_random);
    final out = <String>[];
    for (final c in candidates) {
      if (!out.any((x) => x.toLowerCase() == c.toLowerCase())) {
        out.add(c);
      }
      if (out.length >= count) break;
    }
    if (out.length < count) {
      final fallback = pool
          .map((w) => w['english'] ?? '')
          .where((e) => e.isNotEmpty && e.toLowerCase() != ans)
          .toList();
      fallback.shuffle(_random);
      for (final c in fallback) {
        if (!out.any((x) => x.toLowerCase() == c.toLowerCase())) {
          out.add(c);
        }
        if (out.length >= count) break;
      }
    }
    return out;
  }

  List<String> _levelsByProximity(String userCode) {
    const order = ['A1', 'A2', 'B1', 'B2', 'C1', 'C2'];
    final idx = order.indexOf(userCode.toUpperCase());
    if (idx < 0) return List<String>.from(order);
    final seen = <String>{};
    final out = <String>[];
    void addLv(String lv) {
      if (seen.add(lv)) out.add(lv);
    }

    addLv(order[idx]);
    for (var d = 1; d < order.length; d++) {
      if (idx - d >= 0) addLv(order[idx - d]);
      if (idx + d < order.length) addLv(order[idx + d]);
    }
    return out;
  }

  List<Map<String, dynamic>> _clozeRowsForUser(String userCode,
      {required int minCount}) {
    if (_items.isEmpty) return [];
    final byLevel = <String, List<Map<String, dynamic>>>{};
    for (final e in _items) {
      final lv = (e['level'] as String? ?? 'A2').toUpperCase();
      byLevel.putIfAbsent(lv, () => []).add(e);
    }
    final merged = <Map<String, dynamic>>[];
    final seenKey = <String>{};
    void addAllFrom(String lv) {
      for (final e in byLevel[lv] ?? const []) {
        final k = '${e['sentence']}|${e['answer']}';
        if (seenKey.add(k)) merged.add(e);
      }
    }

    for (final lv in _levelsByProximity(userCode)) {
      addAllFrom(lv);
      if (merged.length >= minCount) break;
    }
    if (merged.length < minCount) {
      for (final e in _items) {
        final k = '${e['sentence']}|${e['answer']}';
        if (seenKey.add(k)) merged.add(e);
      }
    }
    return merged;
  }

  List<String> _levelsForDistractors(String code) {
    return _levelsByProximity(code);
  }

  List<Map<String, String>> _wordMapsAroundLevel(String userCode) {
    final pool = <Map<String, String>>[];
    for (final lv in _levelsByProximity(userCode)) {
      pool.addAll(WordPoolService.instance.getWordsForLevel(lv));
      if (pool.length >= 400) break;
    }
    return pool;
  }

  List<ClozeQuestion> buildSession(UserLevel userLevel,
      {int questionCount = 10}) {
    final code = userLevel.code.toUpperCase();
    var primary =
        _clozeRowsForUser(code, minCount: questionCount);
    primary.shuffle(_random);
    final picked = primary.take(questionCount).toList();
    final questions = <ClozeQuestion>[];
    for (final row in picked) {
      final sentence = row['sentence'] as String? ?? '';
      final answer = (row['answer'] as String? ?? '').trim();
      if (sentence.isEmpty || answer.isEmpty) continue;
      var distractors = _pickDistractors(
        answer: answer,
        primaryLevel: (row['level'] as String? ?? code).toUpperCase(),
        count: 3,
      );
      final ansLower = answer.toLowerCase();
      var guard = 0;
      final fallbackWords = _wordMapsAroundLevel(code);
      while (distractors.length < 3 && guard < 200) {
        guard++;
        if (fallbackWords.isEmpty) break;
        final w = fallbackWords[_random.nextInt(fallbackWords.length)]
                ['english'] ??
            '';
        if (w.isNotEmpty &&
            w.toLowerCase() != ansLower &&
            !distractors.any((d) => d.toLowerCase() == w.toLowerCase())) {
          distractors.add(w);
        }
      }
      if (distractors.length < 3) {
        const allLevels = ['A1', 'A2', 'B1', 'B2', 'C1', 'C2'];
        final panic = <String>[];
        for (final lv in allLevels) {
          for (final w in WordPoolService.instance.getWordsForLevel(lv)) {
            final e = w['english'] ?? '';
            if (e.isEmpty || e.toLowerCase() == ansLower) continue;
            if (!panic.any((x) => x.toLowerCase() == e.toLowerCase())) {
              panic.add(e);
            }
            if (panic.length >= 64) break;
          }
          if (panic.length >= 64) break;
        }
        panic.shuffle(_random);
        for (final w in panic) {
          if (distractors.length >= 3) break;
          if (!distractors.any((d) => d.toLowerCase() == w.toLowerCase())) {
            distractors.add(w);
          }
        }
      }
      if (distractors.length < 3) continue;
      final options = <String>[answer, ...distractors.take(3)];
      options.shuffle(_random);
      final correctIndex = options.indexWhere(
        (o) => o.toLowerCase() == answer.toLowerCase(),
      );
      if (correctIndex < 0) continue;
      final meanings =
          options.map((o) => lookupTurkish(o) ?? '').toList();
      final display = sentence.replaceAll('___', '______');
      final turkishFromRow = row['turkish'] as String?;
      final hint = turkishFromRow ?? lookupTurkish(answer);
      final lv = (row['level'] as String? ?? code).toUpperCase();
      String? pickSentenceTr(String? s) {
        if (s == null) return null;
        final t = s.trim();
        return t.isEmpty ? null : t;
      }

      final sentenceTr = pickSentenceTr(row['sentence_tr'] as String?) ??
          pickSentenceTr(row['sentence_turkish'] as String?) ??
          pickSentenceTr(row['tr'] as String?);
      String? pickHighlight(String? s) {
        if (s == null) return null;
        final t = s.trim();
        return t.isEmpty ? null : t;
      }

      final highlightTr = pickHighlight(row['tr_highlight'] as String?) ??
          pickHighlight(row['answer_tr'] as String?);
      questions.add(
        ClozeQuestion(
          sentenceDisplay: display,
          correctEnglish: answer,
          turkishHint: hint,
          sentenceTurkish: sentenceTr,
          turkishHighlight: highlightTr,
          questionLevel: lv,
          options: options,
          optionMeanings: meanings,
          correctIndex: correctIndex,
        ),
      );
    }
    return questions;
  }
}
