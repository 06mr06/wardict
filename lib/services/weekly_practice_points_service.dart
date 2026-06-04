import 'dart:convert';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/powerup.dart';
import 'firebase/auth_service.dart';
import 'shop_service.dart';

/// Ödül özeti (UI / dialog).
class MilestoneBreakdown {
  final int threshold;
  final int coins;
  final Map<PowerupType, int> powerups;

  const MilestoneBreakdown({
    required this.threshold,
    required this.coins,
    required this.powerups,
  });
}

class WeeklyPracticePointsService {
  WeeklyPracticePointsService._();
  static final WeeklyPracticePointsService instance =
      WeeklyPracticePointsService._();

  static const String _weekKeyPref = 'weekly_practice_week_id';
  static const String _pointsPref = 'weekly_practice_points';
  static const String _claimedPref = 'weekly_practice_claimed';

  /// [users/{uid}] — tarayıcı verisi silinse de aynı hesapla geri yüklenir.
  static const String _firestoreField = 'weeklyPracticeBar';

  /// Eşikler: 2000, 4000, 7000, 10000 (çubuk sonu).
  static const List<int> thresholds = [2000, 4000, 7000, 10000];
  static const int displayMax = 10000;

  final ValueNotifier<int> pointsNotifier = ValueNotifier<int>(0);

  /// Claim / rollover sonrası progress bar yenilensin diye.
  final ValueNotifier<int> uiBump = ValueNotifier<int>(0);

  String _weekId(DateTime now) {
    final local = DateTime(now.year, now.month, now.day);
    final monday = local.subtract(Duration(days: local.weekday - 1));
    return '${monday.year}-${monday.month.toString().padLeft(2, '0')}-${monday.day.toString().padLeft(2, '0')}';
  }

  Future<void> _ensureWeekRollover(SharedPreferences prefs) async {
    final current = _weekId(DateTime.now());
    final stored = prefs.getString(_weekKeyPref);
    if (stored == null) {
      await prefs.setString(_weekKeyPref, current);
      if (!prefs.containsKey(_pointsPref)) {
        await prefs.setInt(_pointsPref, 0);
      }
      if (!prefs.containsKey(_claimedPref)) {
        await prefs.setString(_claimedPref, jsonEncode(<int>[]));
      }
      return;
    }
    if (stored != current) {
      await prefs.setString(_weekKeyPref, current);
      await prefs.setInt(_pointsPref, 0);
      await prefs.setString(_claimedPref, jsonEncode(<int>[]));
      await _pushToRemote(prefs);
    }
  }

  Future<void> _pushToRemote(SharedPreferences prefs) async {
    final uid = AuthService.instance.userId;
    if (uid == null) return;
    try {
      await _ensureWeekRollover(prefs);
      final week = prefs.getString(_weekKeyPref) ?? _weekId(DateTime.now());
      final pts = prefs.getInt(_pointsPref) ?? 0;
      final rawClaim = prefs.getString(_claimedPref);
      final claimed = _parseClaimedRaw(rawClaim);
      await FirebaseFirestore.instance.collection('users').doc(uid).set(
        {
          _firestoreField: {
            'weekId': week,
            'points': pts,
            'claimed': claimed.toList()..sort(),
          },
          'lastOnline': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } catch (e) {
      debugPrint('WeeklyPracticePointsService cloud push failed: $e');
    }
  }

  Set<int> _parseClaimedRaw(String? rawClaim) {
    if (rawClaim == null || rawClaim.isEmpty) return <int>{};
    try {
      final list = jsonDecode(rawClaim) as List<dynamic>;
      return list.map((e) => e as int).toSet();
    } catch (_) {
      return <int>{};
    }
  }

  /// Firestore’daki bu hafta puanını yerelle birleştir (web önbellek/site verisi silinince).
  Future<void> mergeFromRemote() async {
    final uid = AuthService.instance.userId;
    if (uid == null) return;
    try {
      final snap =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final data = snap.data();
      final bar = data?[_firestoreField];
      if (bar is! Map<String, dynamic>) return;
      final remoteWeek = bar['weekId'] as String?;
      if (remoteWeek == null) return;
      final current = _weekId(DateTime.now());
      if (remoteWeek != current) return;

      final remotePts = (bar['points'] as num?)?.toInt() ?? 0;
      final remoteClaimedSet = <int>{};
      final cr = bar['claimed'];
      if (cr is List) {
        for (final e in cr) {
          if (e is int) remoteClaimedSet.add(e);
        }
      }

      final prefs = await SharedPreferences.getInstance();
      final localPts = prefs.getInt(_pointsPref) ?? 0;
      final localClaimed = _parseClaimedRaw(prefs.getString(_claimedPref));
      final mergedPts = math.max(localPts, remotePts);
      final mergedClaim = {...localClaimed, ...remoteClaimedSet};

      await prefs.setString(_weekKeyPref, current);
      await prefs.setInt(_pointsPref, mergedPts);
      await prefs.setString(
        _claimedPref,
        jsonEncode(mergedClaim.toList()..sort()),
      );
    } catch (e) {
      debugPrint('WeeklyPracticePointsService mergeFromRemote failed: $e');
    }
  }

  Future<void> syncFromCloudAndRollover() async {
    await mergeFromRemote();
    await rolloverIfNeeded();
    await refreshNotifier();
  }

  Future<void> rolloverIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    await _ensureWeekRollover(prefs);
  }

  Future<int> getWeeklyPoints() async {
    final prefs = await SharedPreferences.getInstance();
    await _ensureWeekRollover(prefs);
    return prefs.getInt(_pointsPref) ?? 0;
  }

  Future<Set<int>> getClaimedThresholds() async {
    final prefs = await SharedPreferences.getInstance();
    await _ensureWeekRollover(prefs);
    final raw = prefs.getString(_claimedPref);
    if (raw == null || raw.isEmpty) return <int>{};
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list.map((e) => e as int).toSet();
    } catch (_) {
      return <int>{};
    }
  }

  Future<void> _saveClaimed(Set<int> claimed) async {
    final prefs = await SharedPreferences.getInstance();
    final sorted = claimed.toList()..sort();
    await prefs.setString(_claimedPref, jsonEncode(sorted));
  }

  /// UI metinleri için ödül tanımı (henüz verilmemiş olsa da gösterilebilir).
  static MilestoneBreakdown breakdown(int threshold) {
    switch (threshold) {
      case 2000:
        return const MilestoneBreakdown(
          threshold: 2000,
          coins: 100,
          powerups: {},
        );
      case 4000:
        return MilestoneBreakdown(
          threshold: 4000,
          coins: 200,
          powerups: {PowerupType.revealAnswer: 1},
        );
      case 7000:
        return MilestoneBreakdown(
          threshold: 7000,
          coins: 350,
          powerups: {PowerupType.fiftyFifty: 1},
        );
      case 10000:
        return MilestoneBreakdown(
          threshold: 10000,
          coins: 500,
          powerups: {
            PowerupType.revealAnswer: 1,
            PowerupType.fiftyFifty: 1,
          },
        );
      default:
        return MilestoneBreakdown(
          threshold: threshold,
          coins: 0,
          powerups: const {},
        );
    }
  }

  static Color chestColor(int threshold) {
    switch (threshold) {
      case 2000:
        return const Color(0xFF42A5F5);
      case 4000:
        return const Color(0xFFAB47BC);
      case 7000:
        return const Color(0xFFFF9800);
      case 10000:
        return const Color(0xFFFFD54F);
      default:
        return const Color(0xFF78909C);
    }
  }

  Future<void> _grantTier(int threshold) async {
    final b = breakdown(threshold);
    if (b.coins > 0) {
      await ShopService.instance.addCoins(b.coins, reason: 'game_reward');
    }
    for (final e in b.powerups.entries) {
      await ShopService.instance.addPowerupToInventory(e.key, e.value);
    }
  }

  /// Puan ekle; bu oturumda yeni geçilen ve henüz alınmamış eşikleri döner (ödül verilmez).
  Future<List<int>> addSessionPoints(int delta) async {
    if (delta <= 0) return [];
    final prefs = await SharedPreferences.getInstance();
    await _ensureWeekRollover(prefs);
    final oldPts = prefs.getInt(_pointsPref) ?? 0;
    final newPts = oldPts + delta;
    await prefs.setInt(_pointsPref, newPts);
    pointsNotifier.value = newPts;

    final claimed = await getClaimedThresholds();
    final hits = <int>[];
    for (final t in thresholds) {
      if (oldPts < t && newPts >= t && !claimed.contains(t)) {
        hits.add(t);
      }
    }
    uiBump.value++;
    await _pushToRemote(prefs);
    final unique = hits.toSet().toList()..sort();
    return unique;
  }

  /// Sandık ödülünü verir ve eşiği alındı işaretler.
  Future<bool> claimMilestone(int threshold) async {
    if (!thresholds.contains(threshold)) return false;
    final pts = await getWeeklyPoints();
    if (pts < threshold) return false;
    final claimed = await getClaimedThresholds();
    if (claimed.contains(threshold)) return false;
    try {
      await _grantTier(threshold);
      claimed.add(threshold);
      await _saveClaimed(claimed);
      uiBump.value++;
      final prefsAfter = await SharedPreferences.getInstance();
      await _pushToRemote(prefsAfter);
      return true;
    } catch (e) {
      debugPrint('WeeklyPracticePointsService claim error: $e');
      return false;
    }
  }

  Future<void> refreshNotifier() async {
    final p = await getWeeklyPoints();
    pointsNotifier.value = p;
    uiBump.value++;
  }
}

