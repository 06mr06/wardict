import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';

/// Network bağlantı durumu kontrolü
class NetworkService {
  static NetworkService? _instance;
  static NetworkService get instance => _instance ??= NetworkService._();

  NetworkService._();

  bool _isConnected = true;
  Timer? _checkTimer;
  final _connectionController = StreamController<bool>.broadcast();

  bool get isConnected => _isConnected;
  Stream<bool> get connectionStream => _connectionController.stream;

  /// Bağlantı kontrolünü başlat
  void startMonitoring() {
    _checkTimer?.cancel();
    _checkTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _checkConnection();
    });
    _checkConnection();
  }

  /// Bağlantı kontrolünü durdur
  void stopMonitoring() {
    _checkTimer?.cancel();
    _checkTimer = null;
  }

  /// Anlık bağlantı kontrolü
  Future<bool> checkConnection() async {
    await _checkConnection();
    return _isConnected;
  }

  Future<void> _checkConnection() async {
    try {
      if (kIsWeb) {
        // Web için basit HTTP isteği
        _isConnected = true; // Web'de genelde bağlantı var kabul et
      } else {
        // Mobil için DNS lookup
        final result = await InternetAddress.lookup('google.com')
            .timeout(const Duration(seconds: 3));
        _isConnected = result.isNotEmpty && result[0].rawAddress.isNotEmpty;
      }
    } on SocketException catch (_) {
      _isConnected = false;
    } on TimeoutException catch (_) {
      _isConnected = false;
    } catch (e) {
      _isConnected = false;
    }

    _connectionController.add(_isConnected);
  }

  void dispose() {
    stopMonitoring();
    _connectionController.close();
  }
}
