import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'package:shared_preferences/shared_preferences.dart';

/// Ses efektleri servisi
class SoundService {
  static final SoundService instance = SoundService._internal();
  SoundService._internal();

  final AudioPlayer _player = AudioPlayer();
  bool _soundEnabled = true;
  bool _vibrationEnabled = true;

  bool get soundEnabled => _soundEnabled;
  bool get vibrationEnabled => _vibrationEnabled;

  /// Ses ayarlarını başlat (önceki seçimleri yükle)
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _soundEnabled = prefs.getBool('sound_enabled') ?? true;
    _vibrationEnabled = prefs.getBool('vibration_enabled') ?? true;
  }

  /// Ses ayarlarını güncelle
  void setSoundEnabled(bool enabled) async {
    _soundEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('sound_enabled', enabled);
  }

  /// Titreşim ayarlarını güncelle  
  void setVibrationEnabled(bool enabled) async {
    _vibrationEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('vibration_enabled', enabled);
  }

  /// Belirli bir ses dosyasını çal
  Future<void> _playSound(String fileName) async {
    if (!_soundEnabled || kIsWeb) return;
    try {
      await _player.play(AssetSource('sounds/$fileName'));
    } catch (e) {
      debugPrint('Error playing sound $fileName: $e');
    }
  }

  /// Coin kazanma/harcama sesi
  Future<void> playCoinSound() async {
    _playSound('correct.mp3');
    vibrate(HapticFeedbackType.medium);
  }

  /// Davet bildirim sesi
  Future<void> playInviteSound() async {
    _playSound('correct.mp3');
    vibrate(HapticFeedbackType.heavy);
  }

  /// Doğru cevap sesi
  void playCorrect() {
    _playSound('correct.mp3');
    vibrate(HapticFeedbackType.light);
  }

  /// Yanlış cevap sesi
  void playWrong() {
    _playSound('wrong.mp3');
    vibrate(HapticFeedbackType.medium);
  }

  /// Seviye atlama sesi
  void playLevelUp() {
    _playSound('correct.mp3');
    vibrate(HapticFeedbackType.heavy);
  }

  /// Başarı sesi
  void playSuccess() {
    _playSound('victory.mp3');
    vibrate(HapticFeedbackType.heavy);
  }

  /// Buton tıklama sesi
  void playClick() {
    // Hafif tık sesi ve titreşim
    vibrate(HapticFeedbackType.selection);
  }

  /// Bildirim sesi
  void playNotification() {
    _playSound('correct.mp3');
    vibrate(HapticFeedbackType.medium);
  }

  /// Geri sayım sesi
  void playCountdown() {
    _playSound('correct.mp3');
    vibrate(HapticFeedbackType.light);
  }

  /// Oyun başlama sesi
  void playGameStart() {
    _playSound('correct.mp3');
    vibrate(HapticFeedbackType.medium);
  }

  /// Oyun bitişi sesi
  void playGameEnd() {
    _playSound('victory.mp3');
    vibrate(HapticFeedbackType.heavy);
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
