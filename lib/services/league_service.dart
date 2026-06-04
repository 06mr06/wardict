import 'dart:async';
import 'package:flutter/material.dart';
import 'firebase/firestore_service.dart';
import 'firebase/auth_service.dart';

class LeagueService {
  static LeagueService? _instance;
  static LeagueService get instance => _instance ??= LeagueService._();

  LeagueService._();

  /// Haftalık sıfırlamaya kalan süreyi hesapla (Her Pazar 23:59:59)
  Duration get timeUntilReset {
    final now = DateTime.now();
    
    // Bir sonraki Pazartesi 00:00:00
    int daysUntilMonday = (DateTime.monday - now.weekday) % 7;
    if (daysUntilMonday == 0 && now.hour >= 0) {
      // Bugün Pazartesi ise, 7 gün sonraki Pazartesiye bak
      daysUntilMonday = 7;
    }
    
    final nextReset = DateTime(now.year, now.month, now.day + daysUntilMonday);
    return nextReset.difference(now);
  }

  String get formattedTimeUntilReset {
    final duration = timeUntilReset;
    final days = duration.inDays;
    final hours = duration.inHours % 24;
    final minutes = duration.inMinutes % 60;

    if (days > 0) {
      return '$days gün $hours sa';
    } else {
      return '$hours sa $minutes dk';
    }
  }

  /// Lig ödüllerini ve terfi durumunu kontrol et
  /// Not: Gerçek uygulamada bu Cloud Functions ile yapılmalıdır.
  /// Burada basit bir simülasyon/istemci tarafı kontrolü yapıyoruz.
  Future<void> checkLeagueRewards(BuildContext context) async {
    final userId = AuthService.instance.userId;
    if (userId == null) return;

    final profile = await FirestoreService.instance.getCurrentUserProfile();
    if (profile == null) return;

    // TODO: Firestore'da 'lastRewardClaimedAt' gibi bir alan tutulmalı.
    // Şimdilik sadece sistemi hazırlıyoruz.
  }

  /// Lig kuralları ve ödülleri (Elmas / Altın / Gümüş — liderlik sekmeleriyle aynı isimler)
  List<Map<String, dynamic>> get leagueRules => [
    {
      'league': '💎',
      'tierName': 'Elmas',
      'promotion': 'Üst %10 → en yüksek ödül kümesi (üst lig yakında)',
      'relegation': 'Alt %20 → Altın Ligi',
      'reward': '100 🪙 + Özel Rozet',
    },
    {
      'league': '🥇',
      'tierName': 'Altın',
      'promotion': 'Üst %20 → Elmas Ligi\'ne yükseliş',
      'relegation': 'Alt %20 → Gümüş Ligi',
      'reward': '50 🪙',
    },
    {
      'league': '🥈',
      'tierName': 'Gümüş',
      'promotion': 'Üst %30 → Altın Ligi\'ne yükseliş',
      'relegation': 'Sabit taban lig',
      'reward': '25 🪙',
    },
  ];
}
