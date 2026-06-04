import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase/auth_service.dart';

/// Uygulama kapali iken FCM bildirimlerini handle eden arka plan handler
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('🔔 [FCM] Arka plan bildirimi alındı: ${message.messageId}');
}

/// Bildirim yönetim servisi
class NotificationService {
  static NotificationService? _instance;
  static NotificationService get instance =>
      _instance ??= NotificationService._();

  NotificationService._();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _duelChannel =
      AndroidNotificationChannel(
    'duel_invitations',
    'Düello Davetleri',
    description: 'Gelen düello davetleri için bildirimler',
    importance: Importance.max,
    playSound: true,
  );

  /// Servisi başlat (main.dart'tan çağrılır)
  Future<void> initialize() async {
    // Arka plan mesaj handler'ını kaydet
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Bildirim izni iste (Android 13+, iOS)
    await _requestPermission();

    // Local notifications kanalını oluştur (Android)
    await _setupLocalNotifications();

    // Ön planda mesaj gelince göster
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Bildirime tıklanınca app açılıyorsa
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

    // Token'ı Firestore'a kaydet
    await _saveFcmToken();

    // Token yenilenince tekrar kaydet
    _fcm.onTokenRefresh.listen(_updateFcmToken);

    debugPrint('✅ NotificationService başlatıldı');
  }

  /// Bildirim izni iste
  Future<void> _requestPermission() async {
    final settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    debugPrint('🔔 Bildirim izni: ${settings.authorizationStatus}');
  }

  /// Local notification kanalını ayarla
  Future<void> _setupLocalNotifications() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const initSettings =
        InitializationSettings(android: androidInit, iOS: iosInit);

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (details) {
        debugPrint(
            '🔔 Bildirime tıklandı (local): ${details.payload}');
      },
    );

    // Android kanal oluştur
    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_duelChannel);
  }

  /// Uygulama açıkken gelen mesajı göster
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    debugPrint('🔔 [FCM] Ön plan bildirimi: ${message.data}');

    final notification = message.notification;
    final android = message.notification?.android;

    if (notification != null && android != null && !kIsWeb) {
      await _localNotifications.show(
        notification.hashCode,
        notification.title,
        notification.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _duelChannel.id,
            _duelChannel.name,
            channelDescription: _duelChannel.description,
            importance: Importance.max,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
          ),
        ),
        payload: jsonEncode(message.data),
      );
    }
  }

  /// Bildirime tıklanınca işlem yap
  void _handleNotificationTap(RemoteMessage message) {
    debugPrint('🔔 [FCM] Bildirime tıklandı: ${message.data}');
    // Burada navigator ile ilgili ekrana yönlendirme yapılabilir
    // Örnek: GlobalNavigatorKey.currentState?.push(...)
  }

  /// FCM token'ı Firestore'daki kullanıcı belgesine kaydet
  Future<void> _saveFcmToken() async {
    try {
      final token = await _fcm.getToken();
      if (token != null) {
        await _updateFcmToken(token);
        debugPrint('✅ FCM token kaydedildi');
      }
    } catch (e) {
      debugPrint('⚠️ FCM token kaydedilemedi: $e');
    }
  }

  /// Token'ı manuel olarak senkronize et (Daha güvenli kayıt için)
  Future<void> syncToken() async {
    await _saveFcmToken();
  }

  /// Token Firestore'a yaz
  Future<void> _updateFcmToken(String token) async {
    final userId = AuthService.instance.userId;
    if (userId == null) return;

    try {
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'fcmToken': token,
        'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      // Kullanıcı belgesi yoksa oluştur
      try {
        await FirebaseFirestore.instance.collection('users').doc(userId).set({
          'fcmToken': token,
          'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } catch (e2) {
        debugPrint('⚠️ FCM token Firestore yazılamadı: $e2');
      }
    }
  }

  /// Kullanıcı çıkış yapınca token'ı temizle
  Future<void> clearFcmToken() async {
    final userId = AuthService.instance.userId;
    if (userId == null) return;

    try {
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'fcmToken': FieldValue.delete(),
      });
      await _fcm.deleteToken();
    } catch (e) {
      debugPrint('⚠️ FCM token silinemedi: $e');
    }
  }
}
