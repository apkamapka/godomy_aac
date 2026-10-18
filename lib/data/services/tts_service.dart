import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'tts_service.g.dart';

@Riverpod(keepAlive: true)
TTSService ttsService(TtsServiceRef ref) {
  return TTSService();
}

/// Callback postępu mowy – zakres znaków aktualnie czytanego słowa.
typedef SpeechProgress = void Function(int start, int end);

/// Synteza mowy (systemowy TTS, działa offline jeśli głos jest pobrany).
///
/// `speak` czeka, aż wypowiedź się skończy (awaitSpeakCompletion), więc da się
/// po kolei odczytywać zdanie i podświetlać aktualne słowo.
class TTSService {
  final FlutterTts _flutterTts = FlutterTts();
  bool _isInitialized = false;
  Future<void>? _initFuture;

  SpeechProgress? _onProgress;

  String? _voiceName;
  String? _voiceLocale;
  double _rate = 0.5;
  double _pitch = 1.0;

  Future<void> initialize() {
    return _initFuture ??= _doInitialize();
  }

  Future<void> _doInitialize() async {
    try {
      await _flutterTts.setLanguage('pl-PL');
      await _flutterTts.setSpeechRate(_rate);
      await _flutterTts.setPitch(_pitch);
      await _flutterTts.setVolume(1.0);
      await _flutterTts.awaitSpeakCompletion(true);

      _flutterTts.setProgressHandler((text, start, end, word) {
        _onProgress?.call(start, end);
      });
      _flutterTts.setErrorHandler((msg) {
        if (kDebugMode) debugPrint('TTS error: $msg');
      });

      _isInitialized = true;
    } catch (e) {
      _initFuture = null;
      if (kDebugMode) debugPrint('TTS init failed: $e');
      rethrow;
    }
  }

  bool get isInitialized => _isInitialized;

  /// Ustawienia głosu z profilu (tempo 0.1–1.0, wysokość 0.5–2.0).
  Future<void> applySettings({
    String? voiceName,
    String? voiceLocale,
    double rate = 0.5,
    double pitch = 1.0,
  }) async {
    try {
      await initialize();
    } catch (_) {
      return; // Brak silnika TTS – nic do ustawienia.
    }
    _rate = rate.clamp(0.1, 1.0);
    _pitch = pitch.clamp(0.5, 2.0);
    try {
      await _flutterTts.setSpeechRate(_rate);
      await _flutterTts.setPitch(_pitch);
      if (voiceName != null && voiceName.isNotEmpty) {
        if (voiceName != _voiceName) {
          await _flutterTts.setVoice({
            'name': voiceName,
            'locale': (voiceLocale == null || voiceLocale.isEmpty) ? 'pl-PL' : voiceLocale,
          });
        }
      } else if (_voiceName != null) {
        // Powrót do domyślnego głosu polskiego.
        await _flutterTts.clearVoice();
        await _flutterTts.setLanguage('pl-PL');
      }
      _voiceName = (voiceName == null || voiceName.isEmpty) ? null : voiceName;
      _voiceLocale = voiceLocale;
    } catch (e) {
      if (kDebugMode) debugPrint('TTS settings error: $e');
    }
  }

  String? get currentVoiceName => _voiceName;
  String? get currentVoiceLocale => _voiceLocale;

  /// Sprawdzenie czy TTS jest dostępny
  Future<bool> isAvailable() async {
    try {
      final voices = await _flutterTts.getVoices;
      return voices != null && (voices as List).isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Pobranie dostępnych głosów
  Future<List<Map<String, String>>> getVoices() async {
    try {
      await initialize();
      final voices = await _flutterTts.getVoices;
      if (voices == null) return [];
      return (voices as List)
          .map<Map<String, String>>((voice) {
            final map = voice as Map;
            return {
              'name': map['name']?.toString() ?? '',
              'locale': map['locale']?.toString() ?? '',
            };
          })
          .where((v) => v['name']!.isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Głosy polskie (locale zaczyna się od „pl”).
  Future<List<Map<String, String>>> getPolishVoices() async {
    final allVoices = await getVoices();
    final polish = allVoices
        .where((voice) => voice['locale']!.toLowerCase().startsWith('pl'))
        .toList();
    polish.sort((a, b) => a['name']!.compareTo(b['name']!));
    return polish;
  }

  /// Wypowiada tekst i czeka na koniec wypowiedzi.
  /// Zwraca `true`, jeśli wypowiedź doszła do końca (nie została przerwana).
  Future<bool> speak(String text, {SpeechProgress? onProgress}) async {
    final clean = text.trim();
    if (clean.isEmpty) return true;

    try {
      await initialize();
    } catch (_) {
      return false;
    }
    await stop();

    _onProgress = onProgress;
    try {
      // Zabezpieczenie: gdyby silnik TTS nie zgłosił końca, nie wisimy w nieskończoność.
      final words = clean.split(RegExp(r'\s+')).length;
      final timeout = Duration(milliseconds: 4000 + words * 1500);
      final result = await _flutterTts.speak(clean).timeout(timeout, onTimeout: () => 0);
      return result == 1;
    } catch (e) {
      if (kDebugMode) debugPrint('TTS speak error: $e');
      return false;
    } finally {
      _onProgress = null;
    }
  }

  /// Zatrzymaj mowę
  Future<void> stop() async {
    try {
      await _flutterTts.stop();
    } catch (_) {}
  }

  /// Test głosu z przykładowym tekstem
  Future<void> testVoice() async {
    await speak('Cześć! Tak brzmi mój głos.');
  }

  void dispose() {
    _flutterTts.stop();
    _isInitialized = false;
    _initFuture = null;
  }
}
