import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

/// İnternet bağlantı durumunu takip eden servis
class ConnectionService extends ChangeNotifier {
  static final ConnectionService instance = ConnectionService._internal();
  ConnectionService._internal() {
    _init();
  }

  final Connectivity _connectivity = Connectivity();
  bool _isOnline = true;
  bool get isOnline => _isOnline;

  StreamSubscription<List<ConnectivityResult>>? _subscription;

  void _init() async {
    // İlk durumu al
    final List<ConnectivityResult> results = await _connectivity.checkConnectivity();
    _updateStatus(results);

    // Değişimleri dinle
    _subscription = _connectivity.onConnectivityChanged.listen(_updateStatus);
  }

  void _updateStatus(List<ConnectivityResult> results) {
    // Eğer liste içinde mobile, wifi veya ethernet varsa online kabul et
    final bool online = results.any((result) => 
      result == ConnectivityResult.mobile || 
      result == ConnectivityResult.wifi || 
      result == ConnectivityResult.ethernet);
      
    if (_isOnline != online) {
      _isOnline = online;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
