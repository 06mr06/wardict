import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import '../models/user_level.dart';
import 'word_usage_service.dart';
import 'word_category_service.dart';

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

    await WordCategoryService.instance.initialize();
  }

  /// Fiil/isim vb. paket etiketi; bilinmiyorsa [other] — o zaman şık filtresi uygulanmaz.
  String _wordPosCategory(String english) =>
      WordCategoryService.instance.getCategory(english);

  /// Çeviri şıkları: mümkünse hedef kelime ile aynı sözcük türü (ör. fiil–fiil).
  bool _matchesDistractorCategory(String targetEnglish, String candidateEnglish) {
    final t = _wordPosCategory(targetEnglish);
    if (t == 'other') return true;
    return _wordPosCategory(candidateEnglish) == t;
  }

  /// Belirli bir kelime paketini yükler (Marketten alınan özel paketler)
  Future<List<Map<String, String>>> loadWordPack(String packId) async {
    try {
      final jsonString = await rootBundle.loadString('assets/data/pack_$packId.json');
      final wordList = json.decode(jsonString) as List<dynamic>;
      return wordList.map((e) => Map<String, String>.from(e as Map)).toList();
    } catch (e) {
      debugPrint('Error loading word pack $packId: $e');
      return [];
    }
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
  Map<String, int> getQuestionDistribution(UserLevel userLevel, {int? lp}) {
    // LP aralığına göre dağılımı belirle (Ara puanlara yaklaştıkça dağılım zorlaşır)
    bool isNearBorder = false;
    if (lp != null) {
      // Ara puan limitleri: Her seviye geçişi öncesi (Örn: 1150, 1350, 1650...)
      // 5/3/2 dağılımı için kontrol
      int modLp = lp % 250; 
      if (modLp >= 100) { // Her 250'lik dilimin son 150 puanında zorluk artar
        isNearBorder = true;
      }
    }

    final distribution = <String, int>{};
    final String current = userLevel.code.toUpperCase();
    final String next = userLevel.nextLevel.code.toUpperCase();
    final String twoUp = userLevel.twoLevelsUp.code.toUpperCase();

    if (isNearBorder) {
      // 5 Kendi Seviyesi / 3 Bir Üst / 2 İki Üst
      distribution[current] = 5;
      distribution[next] = 3;
      distribution[twoUp] = (twoUp == next) ? 5 : 2; // C1/C2 kısıtı için
    } else {
      // 6 Kendi Seviyesi / 3 Bir Üst / 1 İki Üst
      distribution[current] = 6;
      distribution[next] = 3;
      distribution[twoUp] = (twoUp == next) ? 4 : 1; // C1/C2 kısıtı için
    }

    // C2 kısıtı: Eğer en üst seviyeyse hepsi C2
    if (userLevel == UserLevel.c2) return {'C2': 10};

    return distribution;
  }

  /// Kullanıcı seviyesine göre 10 soru üretir
  /// 7 çeviri (en-tr veya tr-en), 3 eş/zıt anlam
  List<GeneratedQuestion> generateQuestions(UserLevel userLevel, {int? lp}) {
    final distribution = getQuestionDistribution(userLevel, lp: lp);
    final questions = <GeneratedQuestion>[];
    final wordsUsed = <String>{}; // Track original English words

    // Her seviye için gereken soru sayılarını al
    for (final entry in distribution.entries) {
      final level = entry.key;
      final count = entry.value;
      if (count <= 0) continue;

      // Bu seviye için gereken çeviri ve eş anlam sayılarını belirle (70/30 kuralı)
      int synonymCount = (count * 0.3).round();
      if (synonymCount == 0 && count > 0 && _random.nextDouble() < 0.3) {
        synonymCount = 1;
      }
      int translationCount = count - synonymCount;

      // Fill translation questions
      if (translationCount > 0) {
        final levelWords = getWordsForLevel(level)
            .where((w) => !wordsUsed.contains(w['english']?.toLowerCase()))
            .toList();
            
        final selected = WordUsageService.instance.weightedRandomSelect<Map<String, String>>(
          levelWords,
          (word) => word['english'] ?? '',
          translationCount,
        );

        for (final word in selected) {
          final english = word['english'] ?? '';
          final q = _createTranslationQuestion(
            word: word,
            level: level,
            isEnToTr: _random.nextBool(),
          );
          questions.add(q);
          wordsUsed.add(english.toLowerCase());
                }
      }

      // Fill synonym questions
      if (synonymCount > 0) {
        for (int i = 0; i < synonymCount; i++) {
          final q = _createSynonymQuestion(level: level, excludedWords: wordsUsed);
          questions.add(q);
          wordsUsed.add(q.prompt.toLowerCase());
                }
      }
    }

    // Top toplam 10 soruya tamamla (eğer eksik kaldıysa)
    while (questions.length < 10) {
      final currentLevelCode = userLevel.code.toUpperCase();
      if (_random.nextDouble() < 0.7) {
        // Önce kendi seviyesinden tamamlamaya çalış
        var levelWords = getWordsForLevel(currentLevelCode)
            .where((w) => !wordsUsed.contains((w['english'] ?? '').toLowerCase()))
            .toList();
        
        // Kendi seviyesi bittiyse A2, o da bittiyse A1'den al (basitten zora güvenli liman)
        // Kendi seviyesi bittiyse alt seviyelerden (ama B2 altındaysa çok basite inmeyerek) al
        String fallbackLevel = currentLevelCode;
        if (levelWords.isEmpty) {
          // B2 ve üzeri ise A1/A2 yerine B1'e kadar düşsün, yoksa yine A2/A1
          final userLvl = UserLevel.fromCode(currentLevelCode);
          if (userLvl.order >= 3) { // B2+
            fallbackLevel = 'B1';
            levelWords = getWordsForLevel('B1').where((w) => !wordsUsed.contains((w['english'] ?? '').toLowerCase())).toList();
            if (levelWords.isEmpty) {
              fallbackLevel = 'B2'; // Hiç bulamazsa B2'den tekrar al (tekrara düşmek basitten iyidir)
              levelWords = getWordsForLevel('B2');
            }
          } else {
            fallbackLevel = 'A2';
            levelWords = getWordsForLevel('A2').where((w) => !wordsUsed.contains((w['english'] ?? '').toLowerCase())).toList();
            if (levelWords.isEmpty) {
              fallbackLevel = 'A1';
              levelWords = getWordsForLevel('A1').where((w) => !wordsUsed.contains((w['english'] ?? '').toLowerCase())).toList();
            }
          }
        }
        
        final wordsToPick = levelWords;
        
        if (wordsToPick.isNotEmpty) {
          final word = wordsToPick[_random.nextInt(wordsToPick.length)];
          questions.add(_createTranslationQuestion(
            word: word,
            level: fallbackLevel,
            isEnToTr: _random.nextBool(),
          ));
          wordsUsed.add((word['english'] ?? '').toLowerCase());
          debugPrint('📝 WordPool: Completed question with $fallbackLevel (Target: $currentLevelCode)');
        } else {
          // Hiç kelime kalmadıysa (imkansız ama) döngüden çık
          break;
        }
      } else {
        final q = _createSynonymQuestion(level: currentLevelCode, excludedWords: wordsUsed);
        questions.add(q);
        wordsUsed.add(q.prompt.toLowerCase());
            }
    }

    // Sadece ilk 10'u al ve karıştır
    final finalQuestions = questions.take(10).toList()..shuffle(_random);

    // Kullanılan kelimeleri işaretle
    WordUsageService.instance.markWordsUsed(wordsUsed.toList());
    
    return finalQuestions;
  }

  /// Practice (70/30) için: Aynı havuzdan 10 soru, maksimum 2 eski yanlış, minimum 8 yeni kelime
  List<GeneratedQuestion> generateQuestions70_30(UserLevel userLevel, {List<String>? previousWrongWords}) {
    // Sadece kendi seviyesinden 10 kelime
    final levelCode = userLevel.code.toUpperCase();
    final allWords = getWordsForLevel(levelCode);
    final questions = <GeneratedQuestion>[];
    final usedWords = <String>{};

    // Önce eski yanlışlardan max 2 tanesini ekle
    if (previousWrongWords != null && previousWrongWords.isNotEmpty) {
      final wrongsToAsk = previousWrongWords.toSet().intersection(allWords.map((w) => w['english']!).toSet()).toList();
      wrongsToAsk.shuffle(_random);
      for (final word in wrongsToAsk.take(2)) {
        final wordMap = allWords.firstWhere((w) => w['english'] == word);
        questions.add(_createTranslationQuestion(word: wordMap, level: levelCode, isEnToTr: _random.nextBool()));
        usedWords.add(word);
      }
    }

    final remaining = 10 - questions.length;
    var unusedWordsList = allWords.where((w) => !usedWords.contains(w['english'])).toList();
    
    // Fallback: Seviyede kelime bittiyse A2 sonra A1
    if (unusedWordsList.isEmpty && questions.length < 10) {
      unusedWordsList = getWordsForLevel('A2').where((w) => !usedWords.contains(w['english'])).toList();
      if (unusedWordsList.isEmpty) {
        unusedWordsList = getWordsForLevel('A1').where((w) => !usedWords.contains(w['english'])).toList();
      }
    }

    // Ağırlıklı rastgele seçim
    final selectedNewWords = WordUsageService.instance.weightedRandomSelect<Map<String, String>>(
      unusedWordsList,
      (w) => w['english'] ?? '',
      remaining,
    );

    for (final word in selectedNewWords) {
      questions.add(_createTranslationQuestion(word: word, level: levelCode, isEnToTr: _random.nextBool()));
    }

    // Kullanılan kelimeleri işaretle
    final askedWords = questions.map((q) => q.correctAnswer).toList();
    WordUsageService.instance.markWordsUsed(askedWords);
    return questions;
  }

  /// Belirli bir veya birden fazla paketten 10 soru üretir
  Future<List<GeneratedQuestion>> generateQuestionsFromPacks(List<String> packIds, UserLevel userLevel) async {
    final combinedWords = <Map<String, String>>[];
    
    for (final packId in packIds) {
      if (packId == 'base') {
        combinedWords.addAll(getWordsForLevel(userLevel.code.toUpperCase()));
      } else {
        final words = await loadWordPack(packId);
        combinedWords.addAll(words);
      }
    }
    
    if (combinedWords.isEmpty) return [];

    final questions = <GeneratedQuestion>[];
    // 10 soru üret (çeviri modunda - Ağırlıklı Rastgele Seçim ile)
    final selectedWords = WordUsageService.instance.weightedRandomSelect<Map<String, String>>(
      combinedWords,
      (w) => w['english'] ?? '',
      10,
    );
    
    for (final word in selectedWords) {
      final isEnToTr = _random.nextBool();
      questions.add(_createTranslationQuestion(
        word: word,
        level: word['level'] ?? userLevel.code.toUpperCase(),
        isEnToTr: isEnToTr,
        customPool: combinedWords,
      ));
    }

    // Kullanılan kelimeleri işaretle
    final askedWords = questions.map((q) => q.correctAnswer).toList();
    WordUsageService.instance.markWordsUsed(askedWords);
    
    return questions..shuffle(_random);
  }


  /// Çeviri sorusu oluşturur
  GeneratedQuestion _createTranslationQuestion({
    required Map<String, String> word,
    required String level,
    required bool isEnToTr,
    List<Map<String, String>>? customPool,
    int depth = 0,
  }) {
    final english = word['english'] ?? '';
    final turkish = word['turkish'] ?? '';

    if (english.isEmpty || turkish.isEmpty) {
      if (depth < 5) {
        return _createTranslationQuestion(
          word: _getRandomWordForLevel(level),
          level: level,
          isEnToTr: isEnToTr,
          depth: depth + 1,
        );
      }
    }

    // Türkçe'si ile İngilizce'si hemen hemen aynı olan kelimeleri filtrele
    if (_areSimilarWords(english, turkish)) {
      if (depth < 5) {
        // Benzer kelime bulundu, başka kelime seçmeye çalış
        return _createTranslationQuestion(
          word: _getRandomWordForLevel(level, excludeEnglish: english),
          level: level,
          isEnToTr: isEnToTr,
          depth: depth + 1,
        );
      }
    }

    final prompt = isEnToTr ? english : turkish;
    final correctAnswer = isEnToTr ? turkish : english;

    // İki kelime kontrolü
    final isTwoWordPrompt = prompt.split(' ').length == 2;

    final levelWords = customPool ?? getWordsForLevel(level);
    final wrongOptions = <String>[];
    final wrongMeanings = <String>[];

    bool tryAddDistractor(Map<String, String> w, {required bool requireSameCategory}) {
      final option = isEnToTr ? w['turkish']! : w['english']!;
      final meaning = isEnToTr ? w['english']! : w['turkish']!;
      final wEnglish = w['english']!;
      final wTurkish = w['turkish']!;
      if (requireSameCategory && !_matchesDistractorCategory(english, wEnglish)) {
        return false;
      }
      final isTwoWordOption = option.split(' ').length >= 2;
      if (option != correctAnswer &&
          !wrongOptions.contains(option) &&
          (!isTwoWordPrompt || isTwoWordOption || customPool != null) &&
          !_areSimilarWords(wEnglish, wTurkish)) {
        wrongOptions.add(option);
        wrongMeanings.add(meaning);
        return true;
      }
      return false;
    }

    final shuffledWords = List<Map<String, String>>.from(levelWords)..shuffle(_random);
    // 1) Aynı sözcük türü (fiil/isim/…) — WordCategoryService paketleri
    for (final w in shuffledWords) {
      if (wrongOptions.length >= 3) break;
      tryAddDistractor(w, requireSameCategory: true);
    }

    // 2) Aynı seviyede/havuzda tür filtresi olmadan
    if (wrongOptions.length < 3) {
      for (final w in shuffledWords) {
        if (wrongOptions.length >= 3) break;
        tryAddDistractor(w, requireSameCategory: false);
      }
    }

    // 3) Diğer seviyeler (yine tür filtresi yok — yeterli şık için)
    if (customPool == null && wrongOptions.length < 3) {
      for (final l in [level, 'B2', 'B1', 'A2', 'A1', 'C1', 'C2']) {
        if (wrongOptions.length >= 3) break;
        if (l == level) continue;
        final otherWords = getWordsForLevel(l);
        final shuffledOther = List<Map<String, String>>.from(otherWords)..shuffle(_random);
        for (final w in shuffledOther) {
          if (wrongOptions.length >= 3) break;
          tryAddDistractor(w, requireSameCategory: false);
        }
      }
    }

    // Seçenekleri karıştır
    final allOptions = [correctAnswer, ...wrongOptions.take(3)];
    final allMeanings = [isEnToTr ? turkish : english, ...wrongMeanings.take(3)];
    
    final indices = List<int>.generate(allOptions.length, (i) => i);
    indices.shuffle();
    
    final shuffledOptions = indices.map((i) => allOptions[i]).toList();
    final shuffledMeanings = indices.map((i) => allMeanings[i]).toList();
    final correctIdx = indices.indexOf(0);

    return GeneratedQuestion(
      prompt: prompt,
      options: shuffledOptions,
      optionMeanings: shuffledMeanings,
      correctIndex: correctIdx,
      level: level,
      mode: isEnToTr ? QuestionType.enToTr : QuestionType.trToEn,
      turkishMeaning: word['turkish'],
    );
  }

  /// Sadece eş anlamlı kelime sorusu oluşturur (İngilizce → İngilizce)
  GeneratedQuestion _createSynonymQuestion({
    required String level,
    Set<String>? excludedWords,
  }) {
    // Mevcut seviye + bir alt ve bir üst seviyeden kelimeleri topla (Çeşitliliği artırmak için)
    List<SynonymAntonymWord> words = [];
    
    // Mevcut seviye
    words.addAll(getSynonymAntonymWords(level));
    
    // Komşu seviyeleri bul
    final userLvl = UserLevel.fromCode(level);
    if (userLvl != UserLevel.a1) {
      words.addAll(getSynonymAntonymWords(userLvl.previousLevel.code.toUpperCase()));
    }
    if (userLvl != UserLevel.c2) {
      words.addAll(getSynonymAntonymWords(userLvl.nextLevel.code.toUpperCase()));
    }

    // Eğer hala boşsa tüm seviyeleri tara (Yakınlıktan uzağa)
    if (words.isEmpty) {
      debugPrint('⚠️ WordPool: No synonym words for $level. Broadening search...');
      final fallbackOrder = [
        userLvl == UserLevel.a1 ? 'A2' : userLvl.previousLevel.code.toUpperCase(),
        userLvl.nextLevel.code.toUpperCase(),
        'B2', 'B1', 'A2', 'A1'
      ];
      for (final lvl in fallbackOrder) {
        words.addAll(getSynonymAntonymWords(lvl));
        if (words.isNotEmpty) break; // Bir seviye dolusu bulursak yetebilir
      }
    }

    // Hala kelime yoksa fallback: eski sisteme dön
    if (words.isEmpty) {
      return _createFallbackRelationQuestion(level);
    }

    // Eş anlamlı kelimesi olan ve daha önce kullanılmamış kelimeleri bul
    final candidates = words.where((w) {
      if (w.synonyms.isEmpty) return false;
      if (excludedWords != null && excludedWords.contains(w.word.toLowerCase())) return false;
      return true;
    }).toList();
    
    if (candidates.isEmpty) {
      return _createFallbackRelationQuestion(level);
    }

    // Ağırlıklı rastgele seçim - az kullanılan eş anlamlı kelimeleri seç
    final selected = WordUsageService.instance.weightedRandomSelect<SynonymAntonymWord>(
      candidates,
      (w) => w.word,
      1,
    );

    final selectedWord = selected.first;
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

    // Güvenlik: Yeterli seçenek yoksa doldur
    while (wrongOptions.length < 3) {
      wrongOptions.add("Option ${wrongOptions.length + 1}");
    }

    final options = [correctAnswer, ...wrongOptions.take(3)]..shuffle(_random);
    final correctIndex = options.indexOf(correctAnswer);
    
    // Türkçe karşılığını bul (Eş anlamlı soruları için)
    final turkishMeaning = _findTurkishMeaning(prompt);

    // Sadece kelimeyi göster (What is a SYNONYM of... yazısı olmadan)
    final questionText = prompt;

    return GeneratedQuestion(
      prompt: questionText,
      options: options,
      optionMeanings: List.filled(options.length, ""), // No meanings needed for synonym mode display logic
      correctIndex: correctIndex >= 0 ? correctIndex : 0,
      level: level,
      mode: QuestionType.synonym,
      turkishMeaning: turkishMeaning, // Türkçe karşılığı ekle
    );
  }

  /// Zıt anlam sorusu oluşturur
  GeneratedQuestion _createAntonymQuestion({required String level}) {
    List<SynonymAntonymWord> words = getSynonymAntonymWords(level);
    final candidates = words.where((w) => w.antonyms.isNotEmpty).toList();
    if (candidates.isEmpty) return _createFallbackRelationQuestion(level);

    final selectedWord = candidates[_random.nextInt(candidates.length)];
    final correctAnswer = selectedWord.antonyms[_random.nextInt(selectedWord.antonyms.length)];
    
    final wrongOptions = <String>[];
    final shuffled = List.from(words)..shuffle(_random);
    for (final w in shuffled) {
      if (wrongOptions.length >= 3) break;
      if (w.word != selectedWord.word && !selectedWord.antonyms.contains(w.word)) {
        wrongOptions.add(w.word);
      }
    }
    
    while (wrongOptions.length < 3) {
      wrongOptions.add("Word ${_random.nextInt(100)}");
    }

    final options = [correctAnswer, ...wrongOptions.take(3)]..shuffle(_random);
    return GeneratedQuestion(
      prompt: selectedWord.word,
      options: options,
      optionMeanings: List.filled(options.length, ""),
      correctIndex: options.indexOf(correctAnswer),
      level: level,
      mode: QuestionType.antonym,
      turkishMeaning: selectedWord.turkishMeaning,
    );
  }

  /// Kelimenin Türkçe karşılığını tüm havuzda arar
  String? _findTurkishMeaning(String englishWord) {
    if (_wordsByLevel == null) return null;
    
    final lowerWord = englishWord.toLowerCase();
    
    // 1. Ana kelime listesinde ara
    for (final levelWords in _wordsByLevel!.values) {
      for (final wordMap in levelWords) {
        if ((wordMap['english'] ?? '').toLowerCase() == lowerWord) {
          return wordMap['turkish'];
        }
      }
    }

    // 2. Eş anlamlı / Zıt anlamlı kelime listesinde ara
    if (_synonymAntonymsByLevel != null) {
      for (final levelWords in _synonymAntonymsByLevel!.values) {
        for (final saWord in levelWords) {
          // Kelimenin kendisi mi?
          if (saWord.word.toLowerCase() == lowerWord) {
            return saWord.turkishMeaning;
          }
          // Eş anlamlılarından biri mi?
          if (saWord.synonyms.any((s) => s.toLowerCase() == lowerWord)) {
            return saWord.turkishMeaning; // Yakın anlamlı olduğu için ana kelimenin anlamı verilebilir
          }
          // Zıt anlamlılarından biri mi?
          if (saWord.antonyms.any((a) => a.toLowerCase() == lowerWord)) {
            // Zıt anlamlı olduğu için anlam tam tersi çıkar, o yüzden vermemek daha güvenli olabilir 
            // ama yine de istenirse bi sistem kurulabilir. Şimdilik pas geçiyoruz.
          }
        }
      }
    }

    return null;
  }

  /// Kelimenin Türkçesini havuzdan arayarak bulur
  String? getTurkishMeaning(String englishWord) {
    return _findTurkishMeaning(englishWord);
  }

  /// Fallback: eş anlam verisi yoksa basit soru üret
  GeneratedQuestion _createFallbackRelationQuestion(String level) {
    final words = getWordsForLevel(level);
    if (words.isEmpty) {
      return GeneratedQuestion(
        prompt: 'No question available',
        options: ['A', 'B', 'C', 'D'],
        optionMeanings: ['', '', '', ''],
        correctIndex: 0,
        level: level,
        mode: QuestionType.synonym,
      );
    }

    final word = words[_random.nextInt(words.length)];
    return _createTranslationQuestion(word: word, level: level, isEnToTr: true);
  }



  /// Belirli bir seviyeden belirli sayıda soru üretir
  /// Practice modu adaptif zorluk için kullanılır
  List<GeneratedQuestion> generateQuestionsForLevel(UserLevel level, int count) {
    final levelCode = level.code;
    final levelWords = getWordsForLevel(levelCode);
    
    if (levelWords.isEmpty) {
      debugPrint('⚠️ WordPool: No words found for level ${level.code}. Falling back...');
      // Daha mantıklı bir fallback sırası: Yakın seviyelerden başla
      final fallbackOrder = [
        level.code,
        level == UserLevel.a1 ? 'A2' : level.previousLevel.code,
        level.nextLevel.code,
        'B2', 'B1', 'A2', 'A1'
      ];
      
      for (final fallbackCode in fallbackOrder) {
        final fallbackWords = getWordsForLevel(fallbackCode);
        if (fallbackWords.isNotEmpty) {
          debugPrint('✅ WordPool: Falling back to $fallbackCode for level ${level.code}');
          return _generateQuestionsFromWords(fallbackWords, fallbackCode, count);
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

  /// İki kelimenin benzer olup olmadığını kontrol eder
  bool _areSimilarWords(String english, String turkish) {
    // Basit benzerlik kontrolü: aynı harf sayısı, benzer yazım
    final engLower = english.toLowerCase().replaceAll(' ', '');
    final turLower = turkish.toLowerCase().replaceAll(' ', '');

    // Tamamen aynı ise (örnek: concept-concept)
    if (engLower == turLower) return true;

    // Çok benzer ise (örnek: democracy-demokrasi)
    if (engLower.length == turLower.length) {
      int diffCount = 0;
      for (int i = 0; i < engLower.length; i++) {
        if (engLower[i] != turLower[i]) diffCount++;
        if (diffCount > 2) break; // 2'den fazla fark varsa benzer değil
      }
      if (diffCount <= 2) return true;
    }

    // Özel durumlar
    final similarPairs = {
      'democracy': 'demokrasi',
      'concept': 'konsept',
      'system': 'sistem',
      'problem': 'problem',
      'music': 'müzik',
      'film': 'film',
      'sport': 'spor',
      'art': 'sanat',
      'science': 'bilim',
      'technology': 'teknoloji',
    };

    return similarPairs.containsKey(engLower) && similarPairs[engLower] == turLower;
  }

  /// Belirtilen seviyeden rastgele kelime seçer (hariç tutulan kelime varsa)
  Map<String, String> _getRandomWordForLevel(String level, {String? excludeEnglish}) {
    final levelWords = getWordsForLevel(level);
    if (levelWords.isEmpty) {
      // Fallback olarak A1'den kelime seç
      return _getRandomWordForLevel('A1', excludeEnglish: excludeEnglish);
    }

    final availableWords = excludeEnglish != null
        ? levelWords.where((w) => w['english'] != excludeEnglish).toList()
        : levelWords;

    if (availableWords.isEmpty) {
      // Hariç tutulan kelime dışında kelime yoksa, başka seviyeden seç
      for (final lvl in ['A1', 'A2', 'B1', 'B2', 'C1', 'C2']) {
        if (lvl == level) continue;
        final otherWords = getWordsForLevel(lvl);
        final filtered = excludeEnglish != null
            ? otherWords.where((w) => w['english'] != excludeEnglish).toList()
            : otherWords;
        if (filtered.isNotEmpty) {
          return filtered[_random.nextInt(filtered.length)];
        }
      }
      // Son çare olarak orijinal listeden seç
      return levelWords[_random.nextInt(levelWords.length)];
    }

    return availableWords[_random.nextInt(availableWords.length)];
  }

  /// Günün kelimesinden (fun fact) soru oluşturur
  GeneratedQuestion createQuestionFromFact(Map<String, String> fact, String level) {
    final wordText = fact['word'] ?? '';
    final meaningText = fact['meaning'] ?? '';
    
    return _createTranslationQuestion(
      word: {'english': wordText, 'turkish': meaningText},
      level: level,
      isEnToTr: true,
    );
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
  final String? turkishMeaning;

  SynonymAntonymWord({
    required this.word,
    required this.synonyms,
    required this.antonyms,
    this.turkishMeaning,
  });

  factory SynonymAntonymWord.fromJson(Map<String, dynamic> json) {
    return SynonymAntonymWord(
      word: json['word'] as String,
      synonyms: (json['synonyms'] as List?)?.cast<String>() ?? [],
      antonyms: (json['antonyms'] as List?)?.cast<String>() ?? [],
      turkishMeaning: json['turkishMeaning'] as String?,
    );
  }
}

/// Üretilen soru modeli
class GeneratedQuestion {
  final String prompt;
  final List<String> options;
  final List<String> optionMeanings;
  final int correctIndex;
  final String level;
  final QuestionType mode;
  final String? turkishMeaning;

  GeneratedQuestion({
    required this.prompt,
    required this.options,
    required this.optionMeanings,
    required this.correctIndex,
    required this.level,
    required this.mode,
    this.turkishMeaning,
  });

  String get correctAnswer => options[correctIndex];

  Map<String, dynamic> toJson() {
    return {
      'prompt': prompt,
      'options': options,
      'optionMeanings': optionMeanings,
      'correctIndex': correctIndex,
      'level': level,
      'mode': mode.index,
      'turkishMeaning': turkishMeaning,
    };
  }

  factory GeneratedQuestion.fromJson(Map<String, dynamic> json) {
    return GeneratedQuestion(
      prompt: json['prompt'] as String,
      options: List<String>.from(json['options'] ?? []),
      optionMeanings: List<String>.from(json['optionMeanings'] ?? []),
      correctIndex: json['correctIndex'] as int,
      level: json['level'] as String,
      mode: QuestionType.values[json['mode'] as int? ?? 0],
      turkishMeaning: json['turkishMeaning'] as String?,
    );
  }
}
