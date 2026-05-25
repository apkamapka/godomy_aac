import 'package:audioplayers/audioplayers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'audio_player_service.dart' as audioplayers;

part 'audio_player_service.g.dart';

@Riverpod(keepAlive: true)
AudioPlayerService audioPlayerService(AudioPlayerServiceRef ref) {
  return AudioPlayerService();
}

enum PlayerState {
  idle,
  playing,
  paused,
  stopped,
  completed,
}

class AudioPlayerService {
  final AudioPlayer _player = AudioPlayer();
  PlayerState _state = PlayerState.idle;
  String? _currentFilePath;

  PlayerState get state => _state;
  String? get currentFilePath => _currentFilePath;

  AudioPlayerService() {
    _setupListeners();
  }

  void _setupListeners() {
    _player.onPlayerStateChanged.listen((state) {
      switch (state) {
        case audioplayers.PlayerState.playing:
          _state = PlayerState.playing;
          break;
        case audioplayers.PlayerState.paused:
          _state = PlayerState.paused;
          break;
        case audioplayers.PlayerState.stopped:
          _state = PlayerState.stopped;
          break;
        case audioplayers.PlayerState.completed:
          _state = PlayerState.completed;
          break;
        default:
          _state = PlayerState.idle;
      }
    });
  }

  /// Odtwórz nagranie z pliku
  Future<void> play(String filePath) async {
    try {
      // Zatrzymaj jeśli coś już gra
      await stop();

      _currentFilePath = filePath;

      await _player.play(DeviceFileSource(filePath));

      print('▶️ Playing: $filePath');
    } catch (e) {
      print('❌ Error playing audio: $e');
      _state = PlayerState.idle;
      rethrow;
    }
  }

  /// Zatrzymaj odtwarzanie
  Future<void> stop() async {
    try {
      await _player.stop();
      _state = PlayerState.stopped;
      print('⏹️ Audio stopped');
    } catch (e) {
      print('❌ Error stopping audio: $e');
    }
  }

  /// Pauza
  Future<void> pause() async {
    try {
      await _player.pause();
      _state = PlayerState.paused;
      print('⏸️ Audio paused');
    } catch (e) {
      print('❌ Error pausing audio: $e');
    }
  }

  /// Wznów
  Future<void> resume() async {
    try {
      await _player.resume();
      _state = PlayerState.playing;
      print('▶️ Audio resumed');
    } catch (e) {
      print('❌ Error resuming audio: $e');
    }
  }

  /// Sprawdź czy odtwarza
  bool get isPlaying => _state == PlayerState.playing;

  /// Sprawdź czy jest w pauzie
  bool get isPaused => _state == PlayerState.paused;

  /// Dispose
  void dispose() {
    _player.dispose();
  }
}