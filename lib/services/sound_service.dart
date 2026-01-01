import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Ses efektleri servisi
class SoundService {
  static final SoundService instance = SoundService._internal();
  SoundService._internal();

  final AudioPlayer _coinPlayer = AudioPlayer();
  final AudioPlayer _notificationPlayer = AudioPlayer();
  
  bool _soundEnabled = true;
  bool _vibrationEnabled = true;

  bool get soundEnabled => _soundEnabled;
  bool get vibrationEnabled => _vibrationEnabled;

  /// Ses ayarlarını güncelle
  void setSoundEnabled(bool enabled) {
    _soundEnabled = enabled;
  }

  /// Titreşim ayarlarını güncelle  
  void setVibrationEnabled(bool enabled) {
    _vibrationEnabled = enabled;
  }

  /// Coin kazanma/harcama sesi
  Future<void> playCoinSound() async {
    if (!_soundEnabled) return;
    try {
      await _coinPlayer.setSource(AssetSource('sounds/coin.mp3'));
      await _coinPlayer.resume();
    } catch (e) {
      // Ses dosyası yoksa system sound çal
      _playSystemSound();
      debugPrint('Coin sound error: $e');
    }
    vibrate(HapticFeedbackType.medium);
  }

  /// Davet bildirim sesi
  Future<void> playInviteSound() async {
    if (!_soundEnabled) return;
    try {
      await _notificationPlayer.setSource(AssetSource('sounds/notification.mp3'));
      await _notificationPlayer.resume();
    } catch (e) {
      // Ses dosyası yoksa system sound çal
      _playSystemSound();
      debugPrint('Notification sound error: $e');
    }
    vibrate(HapticFeedbackType.heavy);
  }

  /// Doğru cevap sesi
  void playCorrect() {
    if (!_soundEnabled) return;
    _playSystemSound();
  }

  /// Yanlış cevap sesi
  void playWrong() {
    if (!_soundEnabled) return;
    _playSystemSound();
  }

  /// Seviye atlama sesi
  void playLevelUp() {
    if (!_soundEnabled) return;
    _playSystemSound();
  }

  /// Başarı sesi
  void playSuccess() {
    if (!_soundEnabled) return;
    _playSystemSound();
  }

  /// Buton tıklama sesi
  void playClick() {
    if (!_soundEnabled) return;
    _playSystemSound();
  }

  /// Bildirim sesi
  void playNotification() {
    if (!_soundEnabled) return;
    _playSystemSound();
  }

  /// Geri sayım sesi
  void playCountdown() {
    if (!_soundEnabled) return;
    _playSystemSound();
  }

  /// Oyun başlama sesi
  void playGameStart() {
    if (!_soundEnabled) return;
    _playSystemSound();
  }

  /// Oyun bitişi sesi
  void playGameEnd() {
    if (!_soundEnabled) return;
    _playSystemSound();
  }

  /// Sistem sesi çal (haptic feedback ile)
  void _playSystemSound() {
    try {
      // Web platformunda ses desteği sınırlı olduğundan sadece haptic kullanıyoruz
      if (!kIsWeb) {
        SystemSound.play(SystemSoundType.click);
      }
    } catch (e) {
      debugPrint('Sound error: $e');
    }
  }

  /// Titreşim feedback'i
  void vibrate([HapticFeedbackType type = HapticFeedbackType.light]) {
    if (!_vibrationEnabled) return;
    
    try {
      switch (type) {
        case HapticFeedbackType.light:
          HapticFeedback.lightImpact();
          break;
        case HapticFeedbackType.medium:
          HapticFeedback.mediumImpact();
          break;
        case HapticFeedbackType.heavy:
          HapticFeedback.heavyImpact();
          break;
        case HapticFeedbackType.selection:
          HapticFeedback.selectionClick();
          break;
      }
    } catch (e) {
      debugPrint('Vibration error: $e');
    }
  }
}

/// Titreşim tipi
enum HapticFeedbackType {
  light,
  medium,
  heavy,
  selection,
}
