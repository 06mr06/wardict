import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase/auth_service.dart';
import 'firebase/firestore_service.dart';

/// Haftalık puan kazanımı verisi
class WeeklyScore {
  final String username;
  final int totalGained; // Sadece kazanılan (+) puanlar
  final DateTime lastUpdated;

  WeeklyScore({
    required this.username,
    required this.totalGained,
    required this.lastUpdated,
  });

  Map<String, dynamic> toJson() => {
    'username': username,
    'totalGained': totalGained,
    'lastUpdated': lastUpdated.toIso8601String(),
  };

  factory WeeklyScore.fromJson(Map<String, dynamic> json) => WeeklyScore(
    username: json['username'],
    totalGained: json['totalGained'],
    lastUpdated: DateTime.parse(json['lastUpdated']),
  );
}

class RankingService {
  static final RankingService instance = RankingService._();
  RankingService._();

  static const String _weeklyScoresKey = 'weekly_scores_v1';
  static const String _lastResetKey = 'last_weekly_reset';

  /// Bot düellosu sonrası puan ekle (Galibiyet: 20, Mağlubiyet: 5)
  Future<void> addBotDuelScore(String username, {required bool isWin}) async {
    final points = isWin ? 20 : 5;
    await addScore(username, points);
  }

  /// Haftalık puanı günceller (Hem yerel hem bulut)
  Future<void> addScore(String username, int gainedAmount) async {
    if (gainedAmount <= 0) return; // Sadece kazançlar eklenir

    await _checkWeeklyReset();
    
    // 1. Yerel Veriyi Güncelle (SharedPrefs)
    final prefs = await SharedPreferences.getInstance();
    final scoresJson = prefs.getString(_weeklyScoresKey);
    List<WeeklyScore> scores = [];

    if (scoresJson != null) {
      try {
        final List<dynamic> decoded = jsonDecode(scoresJson);
        scores = decoded.map((e) => WeeklyScore.fromJson(e)).toList();
      } catch (e) {
        debugPrint('Parsing error: $e');
      }
    }

    final index = scores.indexWhere((s) => s.username == username);
    if (index != -1) {
      scores[index] = WeeklyScore(
        username: username,
        totalGained: scores[index].totalGained + gainedAmount,
        lastUpdated: DateTime.now(),
      );
    } else {
      scores.add(WeeklyScore(
        username: username,
        totalGained: gainedAmount,
        lastUpdated: DateTime.now(),
      ));
    }
    await prefs.setString(_weeklyScoresKey, jsonEncode(scores.map((e) => e.toJson()).toList()));

    // 2. Bulut Verisini Güncelle (Firestore) - EĞER GİRİŞ YAPILMIŞSA
    final currentUserId = AuthService.instance.userId;
    if (currentUserId != null) {
      try {
        await FirestoreService.instance.updateUserProfile(currentUserId, {
          'weeklyGained': FieldValue.increment(gainedAmount),
        });
        debugPrint('✅ Firestore haftalık puan güncellendi: +$gainedAmount');
      } catch (e) {
        debugPrint('❌ Firestore haftalık puan güncelleme hatası: $e');
      }
    }
  }

  /// Haftalık sıralamayı döndürür
  Future<List<WeeklyScore>> getWeeklyRanking() async {
    await _checkWeeklyReset();
    
    final prefs = await SharedPreferences.getInstance();
    final scoresJson = prefs.getString(_weeklyScoresKey);
    if (scoresJson == null) return [];

    final List<dynamic> decoded = jsonDecode(scoresJson);
    final scores = decoded.map((e) => WeeklyScore.fromJson(e)).toList();
    
    // Puanı en yüksekten en düşüğe sırala
    scores.sort((a, b) => b.totalGained.compareTo(a.totalGained));
    return scores;
  }

  /// Haftalık sıfırlama kontrolü (Pazartesi günü sıfırlanır)
  Future<void> _checkWeeklyReset() async {
    final prefs = await SharedPreferences.getInstance();
    final lastResetStr = prefs.getString(_lastResetKey);
    final now = DateTime.now();

    if (lastResetStr != null) {
      final lastReset = DateTime.parse(lastResetStr);
      // Eğer son sıfırlamadan bu yana haftalık fark oluşmuşsa (ISO haftasına göre)
      if (_getIsoWeek(now) != _getIsoWeek(lastReset)) {
        await prefs.remove(_weeklyScoresKey);
        await prefs.setString(_lastResetKey, now.toIso8601String());
        
        // 3. Bulut verisini sıfırla (Firestore)
        final currentUserId = AuthService.instance.userId;
        if (currentUserId != null) {
          try {
            await FirestoreService.instance.updateUserProfile(currentUserId, {
              'weeklyGained': 0,
            });
            debugPrint('⚠️ Haftalık bulut puanı sıfırlandı (Yeni Hafta)');
          } catch (e) {
            debugPrint('❌ Haftalık bulut puanı sıfırlama hatası: $e');
          }
        }
      }
    } else {
      await prefs.setString(_lastResetKey, now.toIso8601String());
    }
  }

  int _getIsoWeek(DateTime date) {
    int days = date.difference(DateTime(date.year, 1, 1)).inDays;
    return (days / 7).floor();
  }
}
