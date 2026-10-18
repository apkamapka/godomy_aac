import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'audio_player_service.g.dart';

@Riverpod(keepAlive: true)
AudioPlayerService audioPlayerService(AudioPlayerServiceRef ref) {
  return AudioPlayerService();
}

/// Odtwarzanie własnych nagrań głosu.
///
/// `playAndWait` czeka do końca nagrania – potrzebne przy czytaniu całego
/// zdania (poprzednia wersja nie czekała i nagrania się nakładały).
class AudioPlayerService {
  final AudioPlayer _player = AudioPlayer();
  String? _currentFilePath;

  String? get currentFilePath => _currentFilePath;

  bool get isPlaying => _player.state == PlayerState.playing;

  /// Odtwórz nagranie z pliku (bez czekania na koniec).
  Future<void> play(String filePath) async {
    await stop();
    _currentFilePath = filePath;
    await _player.play(DeviceFileSource(filePath));
  }

  /// Odtwórz nagranie i poczekaj na jego koniec.
  /// Zwraca `true`, gdy nagranie doszło do końca, `false` gdy przerwano.
  Future<bool> playAndWait(
    String filePath, {
    Duration timeout = const Duration(seconds: 30),
  }) async {
    await stop();
    _currentFilePath = filePath;

    final completer = Completer<bool>();
    var started = false;

    final completeSub = _player.onPlayerComplete.listen((_) {
      if (!completer.isCompleted) completer.complete(true);
    });
    final stateSub = _player.onPlayerStateChanged.listen((state) {
      if (state == PlayerState.playing) started = true;
      if (started && state == PlayerState.stopped && !completer.isCompleted) {
        completer.complete(false);
      }
    });

    try {
      await _player.play(DeviceFileSource(filePath));
      return await completer.future.timeout(timeout, onTimeout: () => false);
    } catch (e) {
      if (kDebugMode) debugPrint('Audio error: $e');
      return false;
    } finally {
      await completeSub.cancel();
      await stateSub.cancel();
    }
  }

  /// Zatrzymaj odtwarzanie
  Future<void> stop() async {
    try {
      if (_player.state == PlayerState.playing || _player.state == PlayerState.paused) {
        await _player.stop();
      }
    } catch (_) {}
  }

  void dispose() {
    _player.dispose();
  }
}
