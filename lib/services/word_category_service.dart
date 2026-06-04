import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

class WordCategoryService {
  static final WordCategoryService instance = WordCategoryService._();
  WordCategoryService._();

  final Map<String, String> _wordToCategory = {};
  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      final categories = ['verbs', 'nouns', 'phrasals', 'adjectives', 'adverbs', 'idioms'];
      for (final cat in categories) {
        try {
          final fileName = cat == 'phrasals' ? 'pack_phrasal_verbs.json' : 'pack_$cat.json';
          final jsonString = await rootBundle.loadString('assets/data/$fileName');
          final List<dynamic> wordList = json.decode(jsonString);
          
          for (final item in wordList) {
            final english = item['english']?.toString().toLowerCase();
            if (english != null) {
              _wordToCategory[english] = cat;
            }
          }
        } catch (e) {
          debugPrint('⚠️ WordCategoryService: Could not load $cat: $e');
        }
      }
      _isInitialized = true;
      debugPrint('✅ WordCategoryService: Initialized with ${_wordToCategory.length} words');
    } catch (e) {
      debugPrint('❌ WordCategoryService: Initialization failed: $e');
    }
  }

  String getCategory(String englishWord) {
    return _wordToCategory[englishWord.toLowerCase()] ?? 'other';
  }

  String getCategoryName(String categoryId, String langCode) {
    final Map<String, Map<String, String>> names = {
      'verbs': {'tr': 'Fiiller', 'en': 'Verbs'},
      'nouns': {'tr': 'İsimler', 'en': 'Nouns'},
      'phrasals': {'tr': 'Phrasals', 'en': 'Phrasals'},
      'adjectives': {'tr': 'Sıfatlar', 'en': 'Adjectives'},
      'adverbs': {'tr': 'Zarflar', 'en': 'Adverbs'},
      'idioms': {'tr': 'Deyimler', 'en': 'Idioms'},
      'other': {'tr': 'Diğer', 'en': 'Other'},
    };

    return names[categoryId]?[langCode] ?? categoryId;
  }
}
