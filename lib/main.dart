import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'app.dart';
import 'services/ad_service.dart';
import 'services/analytics_service.dart';
import 'services/economy_service.dart';
import 'services/firebase/firebase_service.dart';
import 'services/notification_service.dart';
import 'services/offline_queue_service.dart';
import 'services/purchase_service.dart';
import 'services/word_category_service.dart';
import 'services/word_usage_service.dart';
import 'services/sound_service.dart';

import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

void main() async {
  // Tüm zone-level hatalarını da Crashlytics'e yakala
  await runZonedGuarded<Future<void>>(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // Yerelleştirme ayarları (Türkçe)
    await initializeDateFormatting('tr', null);
    Intl.defaultLocale = 'tr';

    // Load environment variables
    try {
      await dotenv.load(fileName: '.env');
    } catch (e) {
      debugPrint('⚠️ .env file not found: $e');
    }

    // Firebase (core + App Check)
    await FirebaseService.instance.initialize();

    // Analytics + Crashlytics (Firebase sonrasında)
    await AnalyticsService.instance.initialize();

    // Offline operation kuyruğu
    EconomyService.instance.registerOfflineHandlers();
    await OfflineQueueService.instance.initialize();

    // Bildirim servisini başlat (FCM)
    await NotificationService.instance.initialize();

    // Reklam servisini başlat
    await AdService.instance.initialize();

    // Satın alma servisini başlat
    await PurchaseService.instance.initialize();

    // Kelime kullanım servisini başlat
    await WordUsageService.instance.loadUsageData();

    // Kategori servisini başlat
    await WordCategoryService.instance.initialize();

    // Ses ayarlarını yükle
    await SoundService.instance.init();

    // İlk açılış event'i
    unawaited(AnalyticsService.instance.logAppOpen());

    runApp(const LugorenaApp());
  }, (error, stack) {
    AnalyticsService.instance.recordError(error, stack, fatal: true);
  });
}
