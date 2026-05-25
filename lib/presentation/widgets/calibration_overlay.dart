import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/eye_tracking_provider.dart';

class CalibrationOverlay extends ConsumerStatefulWidget {
  final VoidCallback onComplete;
  final VoidCallback onCancel;

  const CalibrationOverlay({
    super.key,
    required this.onComplete,
    required this.onCancel,
  });

  @override
  ConsumerState<CalibrationOverlay> createState() => _CalibrationOverlayState();
}

class _CalibrationOverlayState extends ConsumerState<CalibrationOverlay> {
  Offset? _currentPoint;
  double _progress = 0;
  bool _isCollecting = false;
  bool _showInstructions = true;
  StreamSubscription? _pointSubscription;
  StreamSubscription? _progressSubscription;

  @override
  void initState() {
    super.initState();
    // Opóźnij start kalibracji - nie można modyfikować providera w initState
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startCalibration();
    });
  }

  @override
  void dispose() {
    _pointSubscription?.cancel();
    _progressSubscription?.cancel();
    super.dispose();
  }

  Future<void> _startCalibration() async {
    if (!mounted) return;

    // Oznacz że kalibracja trwa
    ref.read(isCalibrationActiveProvider.notifier).start();

    // Pokaż instrukcje przez 2 sekundy
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    setState(() => _showInstructions = false);

    final service = ref.read(eyeTrackingServiceProvider);

    // Nasłuchuj punktów kalibracji
    _pointSubscription = service.calibrationPointStream.listen((point) {
      debugPrint('📍 Calibration point: $point');
      if (!mounted) return;

      if (point == null) {
        // Kalibracja zakończona
        debugPrint('✅ Kalibracja zakończona!');
        ref.read(isCalibrationActiveProvider.notifier).stop();
        widget.onComplete();
        return;
      }

      setState(() {
        _currentPoint = point;
        _progress = 0;
        _isCollecting = false;
      });

      // Rozpocznij zbieranie próbek po krótkim opóźnieniu
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted && _currentPoint == point) {
          debugPrint('🎯 Rozpoczynam zbieranie próbek dla punktu: $point');
          setState(() => _isCollecting = true);
          service.startCollectSamples();
        }
      });
    });

    // Nasłuchuj postępu
    _progressSubscription = service.calibrationProgressStream.listen((progress) {
      debugPrint('📊 Calibration progress: $progress');
      if (mounted) {
        setState(() => _progress = progress);
      }
    });

    // Rozpocznij kalibrację
    debugPrint('🎯 Rozpoczynam kalibrację...');
    await service.startCalibration();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Material(
        color: Colors.black.withOpacity(0.95),
        child: Stack(
          children: [
            // Instrukcje
            if (_showInstructions)
              Center(
                child: Container(
                  padding: const EdgeInsets.all(32),
                  margin: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.visibility,
                        size: 64,
                        color: Colors.blue,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Kalibracja Eye Tracking',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Patrz na pojawiające się punkty,\naż się wypełnią.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                      const SizedBox(height: 24),
                      const CircularProgressIndicator(),
                    ],
                  ),
                ),
              ),

            // Punkt kalibracji
            if (_currentPoint != null && !_showInstructions)
              Positioned(
                left: _currentPoint!.dx - 30,
                top: _currentPoint!.dy - 30,
                child: _CalibrationPoint(
                  progress: _progress,
                  isCollecting: _isCollecting,
                ),
              ),

            // Przycisk anulowania
            Positioned(
              top: MediaQuery.of(context).padding.top + 16,
              right: 16,
              child: IconButton(
                onPressed: () {
                  ref.read(isCalibrationActiveProvider.notifier).stop();
                  widget.onCancel();
                },
                icon: const Icon(Icons.close, color: Colors.white, size: 32),
              ),
            ),

            // Info na dole
            if (!_showInstructions)
              Positioned(
                bottom: MediaQuery.of(context).padding.bottom + 32,
                left: 0,
                right: 0,
                child: Text(
                  _currentPoint != null ? 'Patrz na punkt' : 'Oczekiwanie na punkt...',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 18,
                  ),
                ),
              ),

            // Debug info
            if (!_showInstructions)
              Positioned(
                top: MediaQuery.of(context).padding.top + 60,
                left: 16,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Point: ${_currentPoint?.dx.toInt()}, ${_currentPoint?.dy.toInt()}\nProgress: ${(_progress * 100).toInt()}%\nCollecting: $_isCollecting',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CalibrationPoint extends StatelessWidget {
  final double progress;
  final bool isCollecting;

  const _CalibrationPoint({
    required this.progress,
    required this.isCollecting,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 60,
      height: 60,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Tło
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.2),
              border: Border.all(color: Colors.white, width: 2),
            ),
          ),
          // Progress
          SizedBox(
            width: 56,
            height: 56,
            child: CircularProgressIndicator(
              value: progress,
              strokeWidth: 4,
              backgroundColor: Colors.transparent,
              valueColor: AlwaysStoppedAnimation<Color>(
                isCollecting ? Colors.green : Colors.blue,
              ),
            ),
          ),
          // Środek
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isCollecting ? Colors.green : Colors.blue,
            ),
          ),
        ],
      ),
    );
  }
}