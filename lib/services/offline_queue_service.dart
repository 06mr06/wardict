import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Offline işlem kuyruğu.
///
/// Kritik yazmalar (altın ekle/harca, günlük bonus, IAP doğrulama vb.) bağlantı
/// yokken buraya düşer; bağlantı geri gelince FIFO sırasıyla yeniden denenir.
///
/// Her item JSON: `{ "id": "<uuid>", "action": "<name>", "payload": {...},
///                    "attempts": 0, "createdAt": <ms> }`
class OfflineQueueService {
  static final OfflineQueueService instance = OfflineQueueService._();
  OfflineQueueService._();

  static const String _queueKey = 'offline_op_queue_v1';
  static const int _maxAttempts = 8;
  static const Duration _baseRetryDelay = Duration(seconds: 3);

  final Map<String, Future<bool> Function(Map<String, dynamic>)> _handlers = {};
  StreamSubscription<List<ConnectivityResult>>? _connSub;
  bool _isFlushing = false;
  Timer? _retryTimer;

  /// İşlem tipini ve handler'ı kaydet.
  /// Handler `true` döndürürse kuyruktan silinir, `false` ise retry olur,
  /// exception atarsa retry olur.
  void registerHandler(
    String action,
    Future<bool> Function(Map<String, dynamic>) handler,
  ) {
    _handlers[action] = handler;
  }

  /// Servisi başlat — connectivity dinleyicisini kur.
  Future<void> initialize() async {
    _connSub ??= Connectivity().onConnectivityChanged.listen((results) {
      final online = results.any((r) =>
          r == ConnectivityResult.mobile ||
          r == ConnectivityResult.wifi ||
          r == ConnectivityResult.ethernet);
      if (online) {
        // Bağlantı yeniden geldiğinde kuyruğu boşalt
        flush();
      }
    });
    // İlk açılışta da dene
    await flush();
  }

  Future<void> dispose() async {
    await _connSub?.cancel();
    _connSub = null;
    _retryTimer?.cancel();
    _retryTimer = null;
  }

  /// Kuyruğa yeni işlem ekle. Eklemenin ardından hemen flush denenir.
  Future<void> enqueue(String action, Map<String, dynamic> payload) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_queueKey) ?? [];
    final item = {
      'id': '${DateTime.now().microsecondsSinceEpoch}_${list.length}',
      'action': action,
      'payload': payload,
      'attempts': 0,
      'createdAt': DateTime.now().millisecondsSinceEpoch,
    };
    list.add(jsonEncode(item));
    await prefs.setStringList(_queueKey, list);
    debugPrint('🗃️ OfflineQueue: enqueue $action (${list.length} item)');
    // Sıra dolu değilse hemen dene; yoksa retry timer'a bırak
    unawaited(flush());
  }

  /// Kuyruktaki tüm öğeleri çalıştırmayı dener.
  Future<void> flush() async {
    if (_isFlushing) return;
    _isFlushing = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_queueKey) ?? [];
      if (raw.isEmpty) return;

      final remaining = <String>[];
      for (final s in raw) {
        Map<String, dynamic> item;
        try {
          item = jsonDecode(s) as Map<String, dynamic>;
        } catch (_) {
          continue; // bozuk satırı atla
        }
        final action = item['action'] as String? ?? '';
        final handler = _handlers[action];
        if (handler == null) {
          // Tanımsız handler → sakla, belki sonra register olur
          remaining.add(s);
          continue;
        }
        final payload = Map<String, dynamic>.from(item['payload'] ?? {});
        int attempts = (item['attempts'] as int?) ?? 0;

        bool ok = false;
        try {
          ok = await handler(payload);
        } catch (e) {
          debugPrint('⚠️ OfflineQueue handler $action error: $e');
        }

        if (ok) {
          debugPrint('✅ OfflineQueue: $action flushed');
          continue; // bırak, kuyruğa geri koyma
        }

        attempts += 1;
        if (attempts >= _maxAttempts) {
          debugPrint('❌ OfflineQueue: $action max retry → dropped');
          continue;
        }
        item['attempts'] = attempts;
        remaining.add(jsonEncode(item));
      }

      await prefs.setStringList(_queueKey, remaining);

      if (remaining.isNotEmpty) {
        _scheduleRetry(remaining.first);
      }
    } finally {
      _isFlushing = false;
    }
  }

  void _scheduleRetry(String firstItem) {
    _retryTimer?.cancel();
    int attempts = 0;
    try {
      final m = jsonDecode(firstItem) as Map<String, dynamic>;
      attempts = (m['attempts'] as int?) ?? 0;
    } catch (_) {}
    // Exponential backoff (3s, 6s, 12s, 24s, 48s, max 2dk)
    final delaySec =
        (_baseRetryDelay.inSeconds * (1 << attempts)).clamp(3, 120);
    _retryTimer = Timer(Duration(seconds: delaySec), flush);
  }

  /// Test / debug amaçlı kuyruğu temizle.
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_queueKey);
  }

  Future<int> pendingCount() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_queueKey) ?? []).length;
  }
}
