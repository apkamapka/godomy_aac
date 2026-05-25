import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/eye_tracking_provider.dart';
import '../../data/services/eye_tracking_service.dart';

class GazeIndicator extends ConsumerWidget {
  const GazeIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isEnabled = ref.watch(eyeTrackingEnabledProvider);
    final isCalibrating = ref.watch(isCalibrationActiveProvider);
    final gazeAsync = ref.watch(gazePointProvider);

    // Nie pokazuj podczas kalibracji
    if (!isEnabled || isCalibrating) return const SizedBox.shrink();

    return gazeAsync.when(
      data: (gaze) {
        if (!gaze.isValid) {
          return const _LostTrackingIndicator();
        }

        return Positioned(
          left: gaze.x - 20,
          top: gaze.y - 20,
          child: IgnorePointer(
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.blue.withOpacity(0.3),
                border: Border.all(
                  color: Colors.blue,
                  width: 3,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.withOpacity(0.4),
                    blurRadius: 12,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Center(
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.blue,
                  ),
                ),
              ),
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

class _LostTrackingIndicator extends StatelessWidget {
  const _LostTrackingIndicator();

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 60,
      left: 16,
      right: 16,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.orange.withOpacity(0.9),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.visibility_off, color: Colors.white, size: 16),
              SizedBox(width: 6),
              Text(
                'Brak wzroku',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}