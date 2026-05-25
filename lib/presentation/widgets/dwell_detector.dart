import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/eye_tracking_provider.dart';
import '../../data/services/eye_tracking_service.dart';

class DwellDetector extends ConsumerStatefulWidget {
  final Widget child;
  final VoidCallback onDwellComplete;
  final Duration dwellDuration;
  final GlobalKey itemKey;

  const DwellDetector({
    super.key,
    required this.child,
    required this.onDwellComplete,
    required this.itemKey,
    this.dwellDuration = const Duration(milliseconds: 1000),
  });

  @override
  ConsumerState<DwellDetector> createState() => _DwellDetectorState();
}

class _DwellDetectorState extends ConsumerState<DwellDetector>
    with SingleTickerProviderStateMixin {
  bool _isGazeInside = false;
  late AnimationController _progressController;
  StreamSubscription<GazePoint>? _gazeSubscription;

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(
      vsync: this,
      duration: widget.dwellDuration,
    );

    _progressController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onDwellComplete();
        _resetDwell();
      }
    });
  }

  @override
  void dispose() {
    _gazeSubscription?.cancel();
    _progressController.dispose();
    super.dispose();
  }

  void _startListening() {
    final service = ref.read(eyeTrackingServiceProvider);
    _gazeSubscription = service.gazeStream.listen(_handleGazePoint);
  }

  void _handleGazePoint(GazePoint gaze) {
    if (!mounted) return;

    final renderBox = widget.itemKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final position = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;
    final rect = Rect.fromLTWH(position.dx, position.dy, size.width, size.height);

    final isInside = gaze.isValid && rect.contains(Offset(gaze.x, gaze.y));

    if (isInside && !_isGazeInside) {
      // Weszliśmy w obszar
      _isGazeInside = true;
      _progressController.forward(from: 0);
    } else if (!isInside && _isGazeInside) {
      // Wyszliśmy z obszaru
      _resetDwell();
    }
  }

  void _resetDwell() {
    _isGazeInside = false;
    _progressController.reset();
  }

  @override
  Widget build(BuildContext context) {
    final isEnabled = ref.watch(eyeTrackingEnabledProvider);
    final isCalibrating = ref.watch(isCalibrationActiveProvider);

    // Start/stop listening based on enabled state (nie podczas kalibracji)
    if (isEnabled && !isCalibrating && _gazeSubscription == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _startListening());
    } else if ((!isEnabled || isCalibrating) && _gazeSubscription != null) {
      _gazeSubscription?.cancel();
      _gazeSubscription = null;
      _resetDwell();
    }

    return Stack(
      children: [
        widget.child,
        if (isEnabled && !isCalibrating)
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _progressController,
                builder: (context, child) {
                  if (_progressController.value == 0) {
                    return const SizedBox.shrink();
                  }
                  return Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.blue,
                        width: 3,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: Container(
                          height: double.infinity,
                          width: double.infinity,
                          alignment: Alignment.bottomCenter,
                          child: FractionallySizedBox(
                            heightFactor: _progressController.value,
                            widthFactor: 1,
                            child: Container(
                              color: Colors.blue.withOpacity(0.3),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
      ],
    );
  }
}