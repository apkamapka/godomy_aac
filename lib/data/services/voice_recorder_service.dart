import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';

part 'voice_recorder_service.g.dart';

@Riverpod(keepAlive: true)
VoiceRecorderService voiceRecorderService(VoiceRecorderServiceRef ref) {
  return VoiceRecorderService();
}

enum RecordingState {
  idle,
  recording,
  paused,
  stopped,
}

class VoiceRecorderService {
  final AudioRecorder _recorder = AudioRecorder();
  RecordingState _state = RecordingState.idle;
  String? _currentRecordingPath;
  DateTime? _recordingStartTime;

  RecordingState get state => _state;
  String? get currentRecordingPath => _currentRecordingPath;
  DateTime? get recordingStartTime => _recordingStartTime;

  /// Sprawdzenie uprawnień mikrofonu
  Future<bool> checkPermission() async {
    final status = await Permission.microphone.status;

    if (status.isGranted) {
      return true;
    }

    if (status.isDenied) {
      final result = await Permission.microphone.request();
      return result.isGranted;
    }

    // Permanently denied
    if (status.isPermanentlyDenied) {
      // Użytkownik musi ręcznie włączyć w ustawieniach
      await openAppSettings();
      return false;
    }

    return false;
  }

  /// Rozpocznij nagrywanie
  Future<String?> startRecording() async {
    try {
      // Sprawdź uprawnienia
      final hasPermission = await checkPermission();
      if (!hasPermission) {
        if (kDebugMode) debugPrint('❌ No microphone permission');
        return null;
      }

      // Sprawdź czy już nagrywa
      if (_state == RecordingState.recording) {
        if (kDebugMode) debugPrint('⚠️ Already recording');
        return null;
      }

      // Przygotuj ścieżkę do pliku
      final directory = await getApplicationDocumentsDirectory();
      final recordingsDir = Directory('${directory.path}/voice_recordings');

      if (!await recordingsDir.exists()) {
        await recordingsDir.create(recursive: true);
      }

      final fileName = '${const Uuid().v4()}.m4a';
      final filePath = '${recordingsDir.path}/$fileName';

      // Rozpocznij nagrywanie
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
        ),
        path: filePath,
      );

      _currentRecordingPath = filePath;
      _recordingStartTime = DateTime.now();
      _state = RecordingState.recording;

      return filePath;
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Error starting recording: $e');
      _state = RecordingState.idle;
      return null;
    }
  }

  /// Zatrzymaj nagrywanie
  Future<String?> stopRecording() async {
    try {
      if (_state != RecordingState.recording) {
        if (kDebugMode) debugPrint('⚠️ Not recording');
        return null;
      }

      await _recorder.stop();

      _state = RecordingState.stopped;
      return _currentRecordingPath;
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Error stopping recording: $e');
      _state = RecordingState.idle;
      return null;
    }
  }

  /// Anuluj nagrywanie (usuń plik)
  Future<void> cancelRecording() async {
    try {
      if (_state == RecordingState.recording) {
        await _recorder.stop();
      }

      if (_currentRecordingPath != null) {
        final file = File(_currentRecordingPath!);
        if (await file.exists()) {
          await file.delete();
        }
      }

      _currentRecordingPath = null;
      _recordingStartTime = null;
      _state = RecordingState.idle;
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Error cancelling recording: $e');
    }
  }

  /// Usuń nagranie (plik)
  Future<bool> deleteRecording(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
        return true;
      }
      return false;
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Error deleting recording: $e');
      return false;
    }
  }

  /// Sprawdź czy nagrywa
  bool get isRecording => _state == RecordingState.recording;

  /// Reset stanu
  void reset() {
    _currentRecordingPath = null;
    _recordingStartTime = null;
    _state = RecordingState.idle;
  }

  /// Dispose
  void dispose() {
    _recorder.dispose();
  }
}