import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Kelime kullanım takip servisi
/// Her kelimenin kaç kez kullanıldığını takip eder ve az kullanılanlara öncelik verir
class WordUsageService {
  static WordUsageService? _instance;
  static WordUsageService get instance => _instance ??= WordUsageService._();

  WordUsageService._();

  static const String _keyPrefix = 'word_usage_';
  Map<String, int> _usageMap = {};
  bool _isLoaded = false;

  /// Kullanım verilerini yükle
  Future<void> loadUsageData() async {
    if (_isLoaded) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final usageJson = prefs.getString('${_keyPrefix}map');
      
      if (usageJson != null) {
        final decoded = json.decode(usageJson) as Map<String, dynamic>;
        _usageMap = decoded.map((key, value) => MapEntry(key, value as int));
      }
      
      _isLoaded = true;
      debugPrint('WordUsageService: Loaded ${_usageMap.length} word usage records');
    } catch (e) {
      debugPrint('WordUsageService load error: $e');
      _usageMap = {};
    }
  }

  /// Kullanım verilerini kaydet
  Future<void> _saveUsageData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('${_keyPrefix}map', json.encode(_usageMap));
    } catch (e) {
      debugPrint('WordUsageService save error: $e');
    }
  }

  /// Bir kelimenin kullanım sayısını getir
  int getUsageCount(String word) {
    return _usageMap[word.toLowerCase()] ?? 0;
  }

  /// Bir kelimenin kullanıldığını kaydet
  Future<void> markWordUsed(String word) async {
    final key = word.toLowerCase();
    _usageMap[key] = (_usageMap[key] ?? 0) + 1;
    await _saveUsageData();
  }

  /// Birden fazla kelimenin kullanıldığını kaydet
  Future<void> markWordsUsed(List<String> words) async {
    for (final word in words) {
      final key = word.toLowerCase();
      _usageMap[key] = (_usageMap[key] ?? 0) + 1;
    }
    await _saveUsageData();
  }

  /// Kelimeleri kullanım sayısına göre sırala (az kullanılanlar önce)
  /// Ağırlıklı rastgele seçim için kullanılır
  List<T> sortByUsage<T>(List<T> items, String Function(T) getWord) {
    final sortedItems = List<T>.from(items);
    sortedItems.sort((a, b) {
      final usageA = getUsageCount(getWord(a));
      final usageB = getUsageCount(getWord(b));
      return usageA.compareTo(usageB);
    });
    return sortedItems;
  }

  /// Ağırlıklı rastgele seçim yap
  /// Az kullanılan kelimeler daha yüksek olasılıkla seçilir
  List<T> weightedRandomSelect<T>(
    List<T> items,
    String Function(T) getWord,
    int count,
  ) {
    if (items.length <= count) {
      return List<T>.from(items);
    }

    // Her kelime için ağırlık hesapla (kullanım ne kadar azsa ağırlık o kadar yüksek)
    final maxUsage = _usageMap.isEmpty 
        ? 1 
        : _usageMap.values.reduce((a, b) => a > b ? a : b) + 1;

    // Tematik gruplanmayı engellemek için listeyi en başta karıştır
    final itemsToProcess = List<T>.from(items)..shuffle();

    final weightedItems = <MapEntry<T, double>>[];
    for (final item in itemsToProcess) {
      final usage = getUsageCount(getWord(item));
      // Ağırlık: maxUsage - usage + 1 (böylece hiç kullanılmamış en yüksek ağırlığa sahip)
      final weight = (maxUsage - usage + 1).toDouble();
      weightedItems.add(MapEntry(item, weight));
    }

    // Ağırlıklı rastgele seçim
    final selected = <T>[];
    final remainingItems = List<MapEntry<T, double>>.from(weightedItems);

    while (selected.length < count && remainingItems.isNotEmpty) {
      var random = (DateTime.now().microsecondsSinceEpoch % 1000000) / 1000000.0;
      random *= remainingItems.fold<double>(0, (sum, e) => sum + e.value);

      double cumulative = 0;
      MapEntry<T, double>? selectedEntry;

      for (final entry in remainingItems) {
        cumulative += entry.value;
        if (random <= cumulative) {
          selectedEntry = entry;
          break;
        }
      }

      if (selectedEntry != null) {
        selected.add(selectedEntry.key);
        remainingItems.remove(selectedEntry);
      } else if (remainingItems.isNotEmpty) {
        selected.add(remainingItems.last.key);
        remainingItems.removeLast();
      }
    }

    return selected;
  }

  /// Kullanım istatistiklerini getir
  Map<String, dynamic> getUsageStats() {
    if (_usageMap.isEmpty) {
      return {
        'totalWords': 0,
        'totalUsage': 0,
        'averageUsage': 0.0,
        'mostUsed': null,
        'leastUsed': null,
      };
    }

    final totalUsage = _usageMap.values.fold<int>(0, (sum, v) => sum + v);
    final sortedEntries = _usageMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return {
      'totalWords': _usageMap.length,
      'totalUsage': totalUsage,
      'averageUsage': totalUsage / _usageMap.length,
      'mostUsed': sortedEntries.isNotEmpty 
          ? {'word': sortedEntries.first.key, 'count': sortedEntries.first.value}
          : null,
      'leastUsed': sortedEntries.isNotEmpty 
          ? {'word': sortedEntries.last.key, 'count': sortedEntries.last.value}
          : null,
    };
  }

  /// Kullanım verilerini sıfırla
  Future<void> resetUsageData() async {
    _usageMap.clear();
    await _saveUsageData();
    debugPrint('WordUsageService: Usage data reset');
  }
}
