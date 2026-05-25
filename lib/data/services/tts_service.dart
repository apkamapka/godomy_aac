import 'package:flutter_tts/flutter_tts.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'tts_service.g.dart';

@Riverpod(keepAlive: true)
TTSService ttsService(TtsServiceRef ref) {
  return TTSService();
}

class TTSService {
  final FlutterTts _flutterTts = FlutterTts();
  bool _isInitialized = false;

  /// Inicjalizacja TTS
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Domyślne ustawienia
      await _flutterTts.setLanguage('pl-PL');
      await _flutterTts.setSpeechRate(0.5);
      await _flutterTts.setPitch(1.0);
      await _flutterTts.setVolume(1.0);

      // Callbacks (opcjonalne - do debugowania)
      _flutterTts.setStartHandler(() {
        print('🗣️ TTS: Start speaking');
      });

      _flutterTts.setCompletionHandler(() {
        print('✅ TTS: Completed');
      });

      _flutterTts.setErrorHandler((msg) {
        print('❌ TTS Error: $msg');
      });

      _isInitialized = true;
      print('✅ TTS Service initialized');
    } catch (e) {
      print('❌ TTS Initialization failed: $e');
      rethrow;
    }
  }

  /// Sprawdzenie czy TTS jest dostępny
  Future<bool> isAvailable() async {
    try {
      final voices = await _flutterTts.getVoices;
      return voices != null && voices.isNotEmpty;
    } catch (e) {
      print('❌ TTS not available: $e');
      return false;
    }
  }

  /// Pobranie dostępnych głosów
  Future<List<Map<String, String>>> getVoices() async {
    try {
      final voices = await _flutterTts.getVoices;
      if (voices == null) return [];

      return voices
          .map<Map<String, String>>((voice) => {
        'name': voice['name']?.toString() ?? '',
        'locale': voice['locale']?.toString() ?? '',
      })
          .toList();
    } catch (e) {
      print('❌ Error getting voices: $e');
      return [];
    }
  }

  /// Pobranie polskich głosów
  Future<List<Map<String, String>>> getPolishVoices() async {
    final allVoices = await getVoices();
    return allVoices
        .where((voice) => voice['locale']?.startsWith('pl') == true)
        .toList();
  }

  /// Ustawienie języka
  Future<void> setLanguage(String language) async {
    await initialize();
    await _flutterTts.setLanguage(language);
  }

  /// Ustawienie głosu
  Future<void> setVoice(String voiceId) async {
    await initialize();
    await _flutterTts.setVoice({'name': voiceId, 'locale': 'pl-PL'});
  }

  /// Ustawienie prędkości (0.0 - 1.0)
  Future<void> setRate(double rate) async {
    await initialize();
    await _flutterTts.setSpeechRate(rate);
  }

  /// Ustawienie wysokości (0.5 - 2.0)
  Future<void> setPitch(double pitch) async {
    await initialize();
    await _flutterTts.setPitch(pitch);
  }

  /// Ustawienie głośności (0.0 - 1.0)
  Future<void> setVolume(double volume) async {
    await initialize();
    await _flutterTts.setVolume(volume);
  }

  /// Wypowiedz tekst
  Future<void> speak(String text) async {
    if (text.trim().isEmpty) return;

    await initialize();

    // Zatrzymaj jeśli coś już mówi
    await stop();

    try {
      await _flutterTts.speak(text);
      print('🗣️ Speaking: "$text"');
    } catch (e) {
      print('❌ Error speaking: $e');
      rethrow;
    }
  }

  /// Zatrzymaj mowę
  Future<void> stop() async {
    try {
      await _flutterTts.stop();
      print('⏹️ TTS stopped');
    } catch (e) {
      print('❌ Error stopping TTS: $e');
    }
  }

  /// Test głosu z przykładowym tekstem
  Future<void> testVoice() async {
    await speak('Witaj! To jest test głosu.');
  }

  /// Dispose (cleanup)
  void dispose() {
    _flutterTts.stop();
    _isInitialized = false;
  }
}