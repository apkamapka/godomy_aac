import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:state_notifier/state_notifier.dart';
import '../../data/services/eye_tracking_service.dart';

// Serwis jako singleton
final eyeTrackingServiceProvider = Provider<EyeTrackingService>((ref) {
  final service = EyeTrackingService();
  ref.onDispose(() => service.dispose());
  return service;
});

// Stan czy eye tracking jest włączony
final eyeTrackingEnabledProvider = StateNotifierProvider<EyeTrackingEnabledNotifier, bool>((ref) {
  return EyeTrackingEnabledNotifier(ref);
});

class EyeTrackingEnabledNotifier extends StateNotifier<bool> {
  final Ref _ref;

  EyeTrackingEnabledNotifier(this._ref) : super(false);

  Future<EyeTrackingInitResult> toggle() async {
    if (state) {
      await disable();
      return EyeTrackingInitResult(success: true);
    } else {
      return await enable();
    }
  }

  Future<EyeTrackingInitResult> enable() async {
    final service = _ref.read(eyeTrackingServiceProvider);
    final result = await service.initialize();
    if (result.success) {
      await service.startTracking();
      state = true;
    }
    return result;
  }

  Future<void> disable() async {
    final service = _ref.read(eyeTrackingServiceProvider);
    await service.stopTracking();
    state = false;
  }
}

// Stream aktualnej pozycji wzroku
final gazePointProvider = StreamProvider<GazePoint>((ref) {
  final service = ref.watch(eyeTrackingServiceProvider);
  return service.gazeStream;
});

// Czy trwa kalibracja - używamy StateNotifierProvider zamiast StateProvider
final isCalibrationActiveProvider = StateNotifierProvider<CalibrationActiveNotifier, bool>((ref) {
  return CalibrationActiveNotifier();
});

class CalibrationActiveNotifier extends StateNotifier<bool> {
  CalibrationActiveNotifier() : super(false);

  void start() {
    debugPrint('🎯 CalibrationActiveNotifier: start()');
    state = true;
  }

  void stop() {
    debugPrint('🎯 CalibrationActiveNotifier: stop()');
    state = false;
  }
}

// Punkt kalibracji
final calibrationPointProvider = StreamProvider<Offset?>((ref) {
  final service = ref.watch(eyeTrackingServiceProvider);
  return service.calibrationPointStream;
});

// Postęp kalibracji
final calibrationProgressProvider = StreamProvider<double>((ref) {
  final service = ref.watch(eyeTrackingServiceProvider);
  return service.calibrationProgressStream;
});