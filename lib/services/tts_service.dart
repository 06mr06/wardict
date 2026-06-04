import 'package:flutter_tts/flutter_tts.dart';

class TtsService {
  static final TtsService instance = TtsService._();
  TtsService._();

  final FlutterTts _flutterTts = FlutterTts();
  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized) return;
    
    await _flutterTts.setLanguage("en-US");
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);
    await _flutterTts.awaitSpeakCompletion(true);
    
    _isInitialized = true;
  }

  Future<void> speak(String text, {String language = "en-US"}) async {
    if (!_isInitialized) await init();
    
    await _flutterTts.stop(); // Önceki seslendirmeyi durdur
    
    // Dil ayarla
    await _flutterTts.setLanguage(language);
    
    // Türkçe için netlik ayarı
    if (language.startsWith("tr")) {
       await _flutterTts.setSpeechRate(0.45); // Biraz daha yavaş ve tane tane
       await _flutterTts.setPitch(1.0);
    } else {
       await _flutterTts.setSpeechRate(0.5);
       await _flutterTts.setPitch(1.0);
    }
    
    if (text.isNotEmpty) {
      await _flutterTts.speak(text);
    }
  }

  /// Önce İngilizce kelimeyi, sonra Türkçe anlamını seslendirir
  Future<void> speakDual(String english, String? turkish) async {
    if (!_isInitialized) await init();
    
    await _flutterTts.stop();
    
    // 1. İngilizce telaffuz
    await _flutterTts.setLanguage("en-US");
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.speak(english);
    
    // Eğer Türkçe anlam varsa
    if (turkish != null && turkish.isNotEmpty && turkish.toLowerCase() != "none") {
      await _flutterTts.setLanguage("tr-TR");
      await _flutterTts.setSpeechRate(0.45); 
      await _flutterTts.speak(turkish);
    }
  }

  Future<void> stop() async {
    await _flutterTts.stop();
  }
}
