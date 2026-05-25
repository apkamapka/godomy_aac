import 'dart:async';
import 'package:eyedid_flutter/constants/eyedid_flutter_calibration_option.dart';
import 'package:eyedid_flutter/eyedid_flutter.dart';
import 'package:eyedid_flutter/events/eyedid_flutter_calibration.dart';
import 'package:eyedid_flutter/events/eyedid_flutter_metrics.dart';
import 'package:eyedid_flutter/events/eyedid_flutter_status.dart';
import 'package:eyedid_flutter/gaze_tracker_options.dart';
import 'package:flutter/material.dart';

class GazePoint {
  final double x;
  final double y;
  final bool isValid;

  const GazePoint({
    required this.x,
    required this.y,
    required this.isValid,
  });

  static const invalid = GazePoint(x: 0, y: 0, isValid: false);
}

// Enum dla typów błędów
enum EyeTrackingError {
  none,
  noPermission,
  noInternet,
  invalidKey,
  expiredKey,
  unknown,
}

class EyeTrackingInitResult {
  final bool success;
  final EyeTrackingError error;

  EyeTrackingInitResult({required this.success, this.error = EyeTrackingError.none});
}

class EyeTrackingService {
  static const String _licenseKey = 'dev_7q8p4lql3ihj3mf8fuknvcpk7xms6m55afe3o0hc';

  final EyedidFlutter _eyedidPlugin = EyedidFlutter();

  bool _isInitialized = false;
  bool _isTracking = false;
  bool _isCalibrating = false;
  bool _isInitializing = false;

  final _gazeController = StreamController<GazePoint>.broadcast();
  final _calibrationProgressController = StreamController<double>.broadcast();
  final _calibrationPointController = StreamController<Offset?>.broadcast();

  Stream<GazePoint> get gazeStream => _gazeController.stream;
  Stream<double> get calibrationProgressStream => _calibrationProgressController.stream;
  Stream<Offset?> get calibrationPointStream => _calibrationPointController.stream;

  bool get isInitialized => _isInitialized;
  bool get isTracking => _isTracking;
  bool get isCalibrating => _isCalibrating;

  StreamSubscription? _trackingSubscription;
  StreamSubscription? _calibrationSubscription;
  StreamSubscription? _statusSubscription;

  Future<EyeTrackingInitResult> initialize() async {
    if (_isInitialized) return EyeTrackingInitResult(success: true);
    if (_isInitializing) {
      debugPrint('❌ Eye tracking init failed: Already attempting');
      return EyeTrackingInitResult(success: false, error: EyeTrackingError.unknown);
    }

    _isInitializing = true;

    try {
      // Sprawdź uprawnienia kamery
      final hasPermission = await _eyedidPlugin.checkCameraPermission();
      if (!hasPermission) {
        final granted = await _eyedidPlugin.requestCameraPermission();
        if (!granted) {
          debugPrint('❌ Eye tracking: brak uprawnień do kamery');
          _isInitializing = false;
          return EyeTrackingInitResult(success: false, error: EyeTrackingError.noPermission);
        }
      }

      // Inicjalizuj tracker
      final options = GazeTrackerOptionsBuilder()
          .setUseGazeFilter(true)
          .setUseBlink(false)
          .setUseUserStatus(false)
          .build();

      final result = await _eyedidPlugin.initGazeTracker(
        licenseKey: _licenseKey,
        options: options,
      );

      if (result.result) {
        _isInitialized = true;
        _setupListeners();
        debugPrint('✅ Eye tracking zainicjalizowany');
        _isInitializing = false;
        return EyeTrackingInitResult(success: true);
      } else {
        debugPrint('❌ Eye tracking init failed: ${result.message}');
        _isInitializing = false;

        // Rozpoznaj typ błędu
        final message = result.message ?? '';
        return EyeTrackingInitResult(
          success: false,
          error: _parseError(message),
        );
      }
    } catch (e) {
      debugPrint('❌ Eye tracking error: $e');
      _isInitializing = false;

      return EyeTrackingInitResult(
        success: false,
        error: _parseError(e.toString()),
      );
    }
  }

  EyeTrackingError _parseError(String message) {
    final lowerMessage = message.toLowerCase();
    if (lowerMessage.contains('cannot_find_host') ||
        lowerMessage.contains('internet') ||
        lowerMessage.contains('resolve host') ||
        lowerMessage.contains('network')) {
      return EyeTrackingError.noInternet;
    } else if (lowerMessage.contains('expired')) {
      return EyeTrackingError.expiredKey;
    } else if (lowerMessage.contains('invalid') || lowerMessage.contains('key')) {
      return EyeTrackingError.invalidKey;
    }
    return EyeTrackingError.unknown;
  }

  void _setupListeners() {
    debugPrint('🔧 Ustawiam listenery eye tracking...');

    // Słuchaj danych gaze
    _trackingSubscription = _eyedidPlugin.getTrackingEvent().listen((event) {
      final metrics = MetricsInfo(event);
      if (metrics.gazeInfo.trackingState == TrackingState.success) {
        _gazeController.add(GazePoint(
          x: metrics.gazeInfo.gaze.x,
          y: metrics.gazeInfo.gaze.y,
          isValid: true,
        ));
      } else {
        _gazeController.add(GazePoint.invalid);
      }
    });

    // Słuchaj kalibracji
    _calibrationSubscription = _eyedidPlugin.getCalibrationEvent().listen((event) {
      final calibration = CalibrationInfo(event);

      debugPrint('📌 Calibration event: type=${calibration.type}, next=${calibration.next}, progress=${calibration.progress}');

      if (calibration.type == CalibrationType.nextPoint) {
        final point = Offset(
          calibration.next?.x ?? 0,
          calibration.next?.y ?? 0,
        );
        debugPrint('📍 Next calibration point: $point');
        _calibrationPointController.add(point);
      } else if (calibration.type == CalibrationType.progress) {
        debugPrint('📊 Calibration progress: ${calibration.progress}');
        _calibrationProgressController.add(calibration.progress ?? 0);
      } else if (calibration.type == CalibrationType.finished) {
        _isCalibrating = false;
        _calibrationPointController.add(null);
        debugPrint('✅ Kalibracja zakończona');
      }
    });

    // Status
    _statusSubscription = _eyedidPlugin.getStatusEvent().listen((event) {
      final status = StatusInfo(event);
      if (status.type == StatusType.start) {
        _isTracking = true;
        debugPrint('👁️ Tracking started');
      } else if (status.type == StatusType.stop) {
        _isTracking = false;
        debugPrint('👁️ Tracking stopped');
      }
    });

    debugPrint('✅ Listenery eye tracking ustawione');
  }

  Future<void> startTracking() async {
    if (!_isInitialized) {
      final result = await initialize();
      if (!result.success) return;
    }

    try {
      await _eyedidPlugin.startTracking();
      _isTracking = true;
      debugPrint('▶️ Eye tracking started');
    } catch (e) {
      debugPrint('❌ Start tracking error: $e');
    }
  }

  Future<void> stopTracking() async {
    try {
      await _eyedidPlugin.stopTracking();
      _isTracking = false;
      debugPrint('⏹️ Eye tracking stopped');
    } catch (e) {
      debugPrint('❌ Stop tracking error: $e');
    }
  }

  Future<void> startCalibration() async {
    debugPrint('🎯 startCalibration() called - isInitialized: $_isInitialized, isTracking: $_isTracking');

    if (!_isInitialized || !_isTracking) {
      debugPrint('❌ Cannot start calibration - not initialized or not tracking');
      return;
    }

    try {
      _isCalibrating = true;
      // 5-point calibration
      debugPrint('🎯 Wywołuję _eyedidPlugin.startCalibration...');
      await _eyedidPlugin.startCalibration(
        CalibrationMode.five,
        calibrationCriteria: CalibrationCriteria.standard,
      );
      debugPrint('🎯 Kalibracja rozpoczęta');
    } catch (e) {
      _isCalibrating = false;
      debugPrint('❌ Calibration error: $e');
    }
  }

  Future<void> startCollectSamples() async {
    debugPrint('🎯 startCollectSamples() called');
    try {
      await _eyedidPlugin.startCollectSamples();
      debugPrint('🎯 Collect samples started');
    } catch (e) {
      debugPrint('❌ Collect samples error: $e');
    }
  }

  Future<void> dispose() async {
    await _trackingSubscription?.cancel();
    await _calibrationSubscription?.cancel();
    await _statusSubscription?.cancel();

    if (_isTracking) {
      await stopTracking();
    }

    if (_isInitialized) {
      await _eyedidPlugin.releaseGazeTracker();
      _isInitialized = false;
    }

    await _gazeController.close();
    await _calibrationProgressController.close();
    await _calibrationPointController.close();

    debugPrint('🗑️ Eye tracking disposed');
  }
}