import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart';
import '../models/user_level.dart';
import 'word_usage_service.dart';

/// Kelime havuzu ve soru üretimi servisi
class WordPoolService {
  static WordPoolService? _instance;
  static WordPoolService get instance => _instance ??= WordPoolService._();

  WordPoolService._();

  Map<String, List<Map<String, String>>>? _wordsByLevel;
  Map<String, List<SynonymAntonymWord>>? _synonymAntonymsByLevel;
  final Random _random = Random();

  /// Kelime havuzunu yükler
  Future<void> loadWordPool() async {
    if (_wordsByLevel != null) return;

    _wordsByLevel = {};
    
    // Her seviye için ayrı dosyadan yükle
    final levels = ['A1', 'A2', 'B1', 'B2', 'C1', 'C2'];
    for (final level in levels) {
      try {
        final jsonString = await rootBundle.loadString('assets/data/words_${level.toLowerCase()}.json');
        final wordList = json.decode(jsonString) as List<dynamic>;
        _wordsByLevel![level] = wordList
            .map((e) => Map<String, String>.from(e as Map))
            .toList();
      } catch (e) {
        // Dosya yoksa boş liste
        _wordsByLevel![level] = [];
      }
    }

    // Eş anlam / zıt anlam havuzunu yükle
    await _loadSynonymAntonyms();
  }

  /// Eş anlam / zıt anlam havuzunu yükler
  Future<void> _loadSynonymAntonyms() async {
    try {
      final jsonString = await rootBundle.loadString('assets/data/synonyms_antonyms.json');
      final data = json.decode(jsonString) as Map<String, dynamic>;

      _synonymAntonymsByLevel = {};
      for (final entry in data.entries) {
        _synonymAntonymsByLevel![entry.key] = (entry.value as List)
            .map((e) => SynonymAntonymWord.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      // Dosya yoksa veya hata varsa boş havuz kullan
      _synonymAntonymsByLevel = {};
    }
  }

  /// Belirli seviyedeki eş/zıt anlam kelimelerini döndürür
  List<SynonymAntonymWord> getSynonymAntonymWords(String levelCode) {
    return _synonymAntonymsByLevel?[levelCode] ?? [];
  }

  /// Belirli seviyedeki kelime listesini döndürür
  List<Map<String, String>> getWordsForLevel(String levelCode) {
    return _wordsByLevel?[levelCode] ?? [];
  }

  /// Kullanıcı seviyesine göre soru dağılımını hesaplar
  /// 10 soru: 5 kendi seviyesi, 3 bir üst, 2 iki üst
  /// C1: 5 C1 + 5 C2 (iki üst olmadığı için)
  /// C2: 10 C2 (hepsi kendi seviyesi)
  Map<String, int> getQuestionDistribution(UserLevel userLevel) {
    switch (userLevel) {
      case UserLevel.a1:
        return {'A1': 5, 'A2': 3, 'B1': 2};
      case UserLevel.a2:
        return {'A2': 5, 'B1': 3, 'B2': 2};
      case UserLevel.b1:
        return {'B1': 5, 'B2': 3, 'C1': 2};
      case UserLevel.b2:
        return {'B2': 5, 'C1': 3, 'C2': 2};
      case UserLevel.c1:
        return {'C1': 5, 'C2': 5}; // C1'de iki üst olmadığı için 5-5
      case UserLevel.c2:
        return {'C2': 10}; // C2'de tüm sorular C2
    }
  }

  /// Kullanıcı seviyesine göre 10 soru üretir
  /// 7 çeviri (en-tr veya tr-en), 3 eş/zıt anlam
  List<GeneratedQuestion> generateQuestions(UserLevel userLevel) {
    final distribution = getQuestionDistribution(userLevel);
    final questions = <GeneratedQuestion>[];

    // Tüm seviyeleri ve sayıları düz listeye çevir
    final levelCounts = <MapEntry<String, int>>[];
    for (final entry in distribution.entries) {
      levelCounts.add(entry);
    }

    // Her seviyeden gerekli sayıda kelime seç - az kullanılanlara öncelik ver
    final selectedWords = <MapEntry<String, Map<String, String>>>[];
    for (final entry in levelCounts) {
      final levelWords = getWordsForLevel(entry.key);
      if (levelWords.isEmpty) continue;

      // Ağırlıklı rastgele seçim - az kullanılan kelimeler daha çok seçilir
      final selected = WordUsageService.instance.weightedRandomSelect<Map<String, String>>(
        levelWords,
        (word) => word['english'] ?? '',
        entry.value,
      );
      
      for (final word in selected) {
        selectedWords.add(MapEntry(entry.key, word));
      }
    }

    // Karıştır
    selectedWords.shuffle(_random);

    // İlk 7 çeviri sorusu
    for (int i = 0; i < min(7, selectedWords.length); i++) {
      final entry = selectedWords[i];
      final word = entry.value;
      final isEnToTr = _random.nextBool();

      questions.add(_createTranslationQuestion(
        word: word,
        level: entry.key,
        isEnToTr: isEnToTr,
      ));
    }

    // Son 3 eş anlam sorusu (İngilizce → İngilizce)
    for (int i = 7; i < min(10, selectedWords.length); i++) {
      final entry = selectedWords[i];

      questions.add(_createSynonymQuestion(
        level: entry.key,
      ));
    }

    // Kullanılan kelimeleri işaretle (tekrar önceliklendirmesi için)
    final usedWords = selectedWords.map((e) => e.value['english'] ?? '').toList();
    WordUsageService.instance.markWordsUsed(usedWords);

    return questions;
  }

  /// Çeviri sorusu oluşturur
  GeneratedQuestion _createTranslationQuestion({
    required Map<String, String> word,
    required String level,
    required bool isEnToTr,
  }) {
    final prompt = isEnToTr ? word['english']! : word['turkish']!;
    final correctAnswer = isEnToTr ? word['turkish']! : word['english']!;

    // Yanlış seçenekler için aynı seviyeden rastgele kelimeler
    final levelWords = getWordsForLevel(level);
    final wrongOptions = <String>[];

    final shuffledWords = List<Map<String, String>>.from(levelWords)..shuffle(_random);
    for (final w in shuffledWords) {
      if (wrongOptions.length >= 3) break;
      final option = isEnToTr ? w['turkish']! : w['english']!;
      if (option != correctAnswer && !wrongOptions.contains(option)) {
        wrongOptions.add(option);
      }
    }

    // Eğer yeterli seçenek yoksa diğer seviyelerden al
    if (wrongOptions.length < 3) {
      for (final lvl in ['A1', 'A2', 'B1', 'B2', 'C1', 'C2']) {
        if (wrongOptions.length >= 3) break;
        if (lvl == level) continue;
        final otherWords = getWordsForLevel(lvl);
        for (final w in otherWords) {
          if (wrongOptions.length >= 3) break;
          final option = isEnToTr ? w['turkish']! : w['english']!;
          if (option != correctAnswer && !wrongOptions.contains(option)) {
            wrongOptions.add(option);
          }
        }
      }
    }

    // Seçenekleri karıştır
    final options = [correctAnswer, ...wrongOptions]..shuffle(_random);
    final correctIndex = options.indexOf(correctAnswer);

    return GeneratedQuestion(
      prompt: prompt,
      options: options,
      correctIndex: correctIndex,
      level: level,
      mode: isEnToTr ? QuestionType.enToTr : QuestionType.trToEn,
    );
  }

  /// Sadece eş anlamlı kelime sorusu oluşturur (İngilizce → İngilizce)
  GeneratedQuestion _createSynonymQuestion({
    required String level,
  }) {
    // Önce bu seviyeden, yoksa diğer seviyelerden kelime bul
    List<SynonymAntonymWord> words = getSynonymAntonymWords(level);
    if (words.isEmpty) {
      for (final lvl in ['A2', 'A1', 'B1', 'B2', 'C1', 'C2']) {
        words = getSynonymAntonymWords(lvl);
        if (words.isNotEmpty) break;
      }
    }

    // Hala kelime yoksa fallback: eski sisteme dön
    if (words.isEmpty) {
      return _createFallbackRelationQuestion(level);
    }

    // Eş anlamlı kelimesi olan bir kelime bul
    final shuffledWords = List<SynonymAntonymWord>.from(words)..shuffle(_random);
    SynonymAntonymWord? selectedWord;
    for (final w in shuffledWords) {
      if (w.synonyms.isNotEmpty) {
        selectedWord = w;
        break;
      }
    }

    if (selectedWord == null) {
      return _createFallbackRelationQuestion(level);
    }

    return _buildSynonymQuestion(selectedWord.word, selectedWord.synonyms, level, words);
  }

  /// Sadece eş anlam sorusu oluşturur
  GeneratedQuestion _buildSynonymQuestion(
    String prompt,
    List<String> correctAnswers,
    String level,
    List<SynonymAntonymWord> allWords,
  ) {
    // Doğru cevap: listeden rastgele birini seç
    final correctAnswer = correctAnswers[_random.nextInt(correctAnswers.length)];

    // Yanlış seçenekler: diğer kelimelerin zıt anlamlarından veya farklı kelimelerden al
    final wrongOptions = <String>[];
    final shuffledWords = List<SynonymAntonymWord>.from(allWords)..shuffle(_random);
    
    // Prompt kelimesinin lowercase versiyonu (karşılaştırma için)
    final promptLower = prompt.toLowerCase();
    
    for (final w in shuffledWords) {
      if (wrongOptions.length >= 3) break;
      if (w.word.toLowerCase() == promptLower) continue;
      
      // Zıt anlamlarını yanlış seçenek olarak kullan
      for (final opt in w.antonyms) {
        if (wrongOptions.length >= 3) break;
        // Prompt ile aynı kelime olmasın (büyük/küçük harf fark etmez)
        if (opt.toLowerCase() == promptLower) continue;
        if (opt != correctAnswer && !wrongOptions.contains(opt) && !correctAnswers.contains(opt)) {
          wrongOptions.add(opt);
        }
      }
    }

    // Yeterli seçenek yoksa, herhangi bir kelimeyi ekle
    if (wrongOptions.length < 3) {
      for (final w in shuffledWords) {
        if (wrongOptions.length >= 3) break;
        // Prompt ile aynı kelime olmasın (büyük/küçük harf fark etmez)
        if (w.word.toLowerCase() == promptLower) continue;
        if (!wrongOptions.contains(w.word) && !correctAnswers.contains(w.word)) {
          wrongOptions.add(w.word);
        }
      }
    }

    final options = [correctAnswer, ...wrongOptions.take(3)]..shuffle(_random);
    final correctIndex = options.indexOf(correctAnswer);

    // Sadece kelimeyi göster (What is a SYNONYM of... yazısı olmadan)
    final questionText = prompt;

    return GeneratedQuestion(
      prompt: questionText,
      options: options,
      correctIndex: correctIndex >= 0 ? correctIndex : 0,
      level: level,
      mode: QuestionType.synonym,
    );
  }

  /// Fallback: eş anlam verisi yoksa basit soru üret
  GeneratedQuestion _createFallbackRelationQuestion(String level) {
    final words = getWordsForLevel(level);
    if (words.isEmpty) {
      return GeneratedQuestion(
        prompt: 'No question available',
        options: ['A', 'B', 'C', 'D'],
        correctIndex: 0,
        level: level,
        mode: QuestionType.synonym,
      );
    }

    final word = words[_random.nextInt(words.length)];
    return _createTranslationQuestion(word: word, level: level, isEnToTr: true);
  }

  /// Seviye belirleme testi için sorular üretir (her seviyeden 2 soru = 12 soru)
  List<GeneratedQuestion> generatePlacementTestQuestions() {
    final questions = <GeneratedQuestion>[];

    for (final level in ['A1', 'A2', 'B1', 'B2', 'C1', 'C2']) {
      final levelWords = getWordsForLevel(level);
      if (levelWords.isEmpty) continue;

      final shuffled = List<Map<String, String>>.from(levelWords)..shuffle(_random);

      // Her seviyeden 2 soru
      for (int i = 0; i < min(2, shuffled.length); i++) {
        final isEnToTr = _random.nextBool();
        questions.add(_createTranslationQuestion(
          word: shuffled[i],
          level: level,
          isEnToTr: isEnToTr,
        ));
      }
    }

    questions.shuffle(_random);
    return questions;
  }

  /// Belirli bir seviyeden belirli sayıda soru üretir
  /// Practice modu adaptif zorluk için kullanılır
  List<GeneratedQuestion> generateQuestionsForLevel(UserLevel level, int count) {
    final levelCode = level.code;
    final levelWords = getWordsForLevel(levelCode);
    
    if (levelWords.isEmpty) {
      // Eğer seviyede kelime yoksa, en yakın seviyeden al
      for (final fallbackLevel in ['A2', 'A1', 'B1', 'B2', 'C1', 'C2']) {
        final fallbackWords = getWordsForLevel(fallbackLevel);
        if (fallbackWords.isNotEmpty) {
          return _generateQuestionsFromWords(fallbackWords, fallbackLevel, count);
        }
      }
      return [];
    }
    
    return _generateQuestionsFromWords(levelWords, levelCode, count);
  }

  /// Kelime listesinden soru üretir - az kullanılan kelimelere öncelik verir
  List<GeneratedQuestion> _generateQuestionsFromWords(
    List<Map<String, String>> words,
    String level,
    int count,
  ) {
    final questions = <GeneratedQuestion>[];
    
    // Ağırlıklı rastgele seçim - az kullanılan kelimeler öncelikli
    final selectedWords = WordUsageService.instance.weightedRandomSelect<Map<String, String>>(
      words,
      (word) => word['english'] ?? '',
      count,
    );
    
    for (final word in selectedWords) {
      final isEnToTr = _random.nextBool();
      
      questions.add(_createTranslationQuestion(
        word: word,
        level: level,
        isEnToTr: isEnToTr,
      ));
    }
    
    // Kullanılan kelimeleri işaretle
    final usedWords = selectedWords.map((w) => w['english'] ?? '').toList();
    WordUsageService.instance.markWordsUsed(usedWords);
    
    return questions;
  }
}

/// Soru tipi
enum QuestionType {
  enToTr,   // İngilizce -> Türkçe çeviri
  trToEn,   // Türkçe -> İngilizce çeviri
  synonym,  // Eş anlam (İngilizce -> İngilizce)
  antonym,  // Zıt anlam (İngilizce -> İngilizce)
  relation, // Eski uyumluluk için (deprecated)
}

/// Eş anlam / zıt anlam kelime modeli
class SynonymAntonymWord {
  final String word;
  final List<String> synonyms;
  final List<String> antonyms;

  SynonymAntonymWord({
    required this.word,
    required this.synonyms,
    required this.antonyms,
  });

  factory SynonymAntonymWord.fromJson(Map<String, dynamic> json) {
    return SynonymAntonymWord(
      word: json['word'] as String,
      synonyms: (json['synonyms'] as List?)?.cast<String>() ?? [],
      antonyms: (json['antonyms'] as List?)?.cast<String>() ?? [],
    );
  }
}

/// Üretilen soru modeli
class GeneratedQuestion {
  final String prompt;
  final List<String> options;
  final int correctIndex;
  final String level;
  final QuestionType mode;

  GeneratedQuestion({
    required this.prompt,
    required this.options,
    required this.correctIndex,
    required this.level,
    required this.mode,
  });

  String get correctAnswer => options[correctIndex];
}
