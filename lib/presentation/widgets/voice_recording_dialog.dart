import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/app_localizations.dart';
import '../../core/theme/app_colors.dart';
import '../../data/services/audio_player_service.dart';
import '../../data/services/voice_recorder_service.dart';

/// Nagrywanie własnego głosu dla symbolu (np. głos mamy).
/// Zwraca ścieżkę nagrania albo null (anulowano).
class VoiceRecordingDialog extends ConsumerStatefulWidget {
  final String? existingRecordingPath;

  const VoiceRecordingDialog({super.key, this.existingRecordingPath});

  @override
  ConsumerState<VoiceRecordingDialog> createState() => _VoiceRecordingDialogState();
}

class _VoiceRecordingDialogState extends ConsumerState<VoiceRecordingDialog> {
  bool _isRecording = false;
  bool _isPlaying = false;
  String? _recordingPath;
  Duration _duration = Duration.zero;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _recordingPath = widget.existingRecordingPath;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _start() async {
    final recorder = ref.read(voiceRecorderServiceProvider);
    final path = await recorder.startRecording();
    if (path == null) {
      if (mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.micPermissionNeeded)),
        );
      }
      return;
    }
    setState(() {
      _isRecording = true;
      _duration = Duration.zero;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _duration += const Duration(seconds: 1));
    });
  }

  Future<void> _stop() async {
    _timer?.cancel();
    final path = await ref.read(voiceRecorderServiceProvider).stopRecording();
    if (!mounted) return;
    setState(() {
      _isRecording = false;
      if (path != null) _recordingPath = path;
    });
  }

  Future<void> _play() async {
    final path = _recordingPath;
    if (path == null) return;
    setState(() => _isPlaying = true);
    await ref.read(audioPlayerServiceProvider).playAndWait(path);
    if (mounted) setState(() => _isPlaying = false);
  }

  Future<void> _stopPlaying() async {
    await ref.read(audioPlayerServiceProvider).stop();
    if (mounted) setState(() => _isPlaying = false);
  }

  Future<void> _cancel() async {
    _timer?.cancel();
    if (_isRecording) {
      await ref.read(voiceRecorderServiceProvider).cancelRecording();
    }
    if (mounted) Navigator.pop(context);
  }

  String _format(Duration d) =>
      '${d.inMinutes.toString().padLeft(2, '0')}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final palette = context.aac;
    final hasRecording = _recordingPath != null && !_isRecording;

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l10n.voiceRecording, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(
                l10n.voiceRecordingHint,
                textAlign: TextAlign.center,
                style: TextStyle(color: palette.inkSoft, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 20),
              GestureDetector(
                onTap: _isRecording ? _stop : _start,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _isRecording ? AppColors.coral : AppColors.coral.withValues(alpha: 0.15),
                    boxShadow: _isRecording
                        ? [BoxShadow(color: AppColors.coral.withValues(alpha: 0.35), spreadRadius: 10, blurRadius: 0)]
                        : const [],
                  ),
                  child: Icon(
                    _isRecording ? Icons.stop_rounded : Icons.mic_rounded,
                    size: 52,
                    color: _isRecording ? Colors.white : AppColors.coralDeep,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _isRecording
                    ? _format(_duration)
                    : (hasRecording ? l10n.recordingReady : l10n.tapToRecord),
                style: TextStyle(
                  fontSize: _isRecording ? 26 : 16,
                  fontWeight: FontWeight.w900,
                  color: _isRecording ? AppColors.coralDeep : palette.ink,
                ),
              ),
              if (hasRecording) ...[
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _isPlaying ? _stopPlaying : _play,
                        icon: Icon(_isPlaying ? Icons.stop_rounded : Icons.play_arrow_rounded),
                        label: Text(_isPlaying ? l10n.stop : l10n.playRecording),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _start,
                        icon: const Icon(Icons.refresh_rounded),
                        label: Text(l10n.recordAgain),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: TextButton(onPressed: _cancel, child: Text(l10n.cancel)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      onPressed: hasRecording ? () => Navigator.pop(context, _recordingPath) : null,
                      child: Text(l10n.save),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
