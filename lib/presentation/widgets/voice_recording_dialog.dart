import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/l10n/app_localizations.dart';
import '../../data/services/voice_recorder_service.dart';
import '../../data/services/audio_player_service.dart';

class VoiceRecordingDialog extends ConsumerStatefulWidget {
  final String? existingRecordingPath;

  const VoiceRecordingDialog({
    super.key,
    this.existingRecordingPath,
  });

  @override
  ConsumerState<VoiceRecordingDialog> createState() => _VoiceRecordingDialogState();
}

class _VoiceRecordingDialogState extends ConsumerState<VoiceRecordingDialog> {
  bool _isRecording = false;
  bool _isPlaying = false;
  String? _recordingPath;
  Duration _recordingDuration = Duration.zero;
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return AlertDialog(
      title: Text(l10n.voiceRecording),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Timer nagrywania
          if (_isRecording)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                _formatDuration(_recordingDuration),
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

          // Ikona statusu
          Icon(
            _isRecording
                ? Icons.mic
                : _recordingPath != null
                ? Icons.check_circle
                : Icons.mic_none,
            size: 80,
            color: _isRecording
                ? Colors.red
                : _recordingPath != null
                ? Colors.green
                : Colors.grey,
          ),

          const SizedBox(height: 24),

          // Przyciski
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Start/Stop nagrywania
              if (!_isRecording && _recordingPath == null)
                _buildButton(
                  icon: Icons.fiber_manual_record,
                  color: Colors.red,
                  label: l10n.recordVoice,
                  onPressed: _startRecording,
                ),

              if (_isRecording)
                _buildButton(
                  icon: Icons.stop,
                  color: Colors.red,
                  label: 'Stop',
                  onPressed: _stopRecording,
                ),

              // Play nagrania
              if (!_isRecording && _recordingPath != null)
                _buildButton(
                  icon: _isPlaying ? Icons.stop : Icons.play_arrow,
                  color: Colors.blue,
                  label: _isPlaying ? 'Stop' : l10n.playRecording,
                  onPressed: _isPlaying ? _stopPlaying : _playRecording,
                ),

              // Usuń nagranie
              if (!_isRecording && _recordingPath != null)
                _buildButton(
                  icon: Icons.delete,
                  color: Colors.orange,
                  label: l10n.deleteRecording,
                  onPressed: _deleteRecording,
                ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            if (_isRecording) {
              _cancelRecording();
            }
            Navigator.pop(context);
          },
          child: Text(l10n.cancel),
        ),
        if (_recordingPath != null)
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context, _recordingPath);
            },
            child: Text(l10n.saveChanges),
          ),
      ],
    );
  }

  Widget _buildButton({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onPressed,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: Icon(icon, size: 32),
          color: color,
          onPressed: onPressed,
          style: IconButton.styleFrom(
            backgroundColor: color.withOpacity(0.1),
            padding: const EdgeInsets.all(16),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 12),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Future<void> _startRecording() async {
    final recorderService = ref.read(voiceRecorderServiceProvider);

    final path = await recorderService.startRecording();
    if (path == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Nie udało się rozpocząć nagrywania. Sprawdź uprawnienia.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    setState(() {
      _isRecording = true;
      _recordingDuration = Duration.zero;
    });

    // Start timer
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _recordingDuration = Duration(seconds: timer.tick);
        });
      }
    });
  }

  Future<void> _stopRecording() async {
    final recorderService = ref.read(voiceRecorderServiceProvider);

    final path = await recorderService.stopRecording();

    _timer?.cancel();

    if (mounted) {
      setState(() {
        _isRecording = false;
        _recordingPath = path;
      });

      if (path != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✔ Nagranie zapisane'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  Future<void> _cancelRecording() async {
    final recorderService = ref.read(voiceRecorderServiceProvider);
    await recorderService.cancelRecording();

    _timer?.cancel();

    if (mounted) {
      setState(() {
        _isRecording = false;
        _recordingPath = null;
        _recordingDuration = Duration.zero;
      });
    }
  }

  Future<void> _playRecording() async {
    if (_recordingPath == null) return;

    final playerService = ref.read(audioPlayerServiceProvider);

    try {
      await playerService.play(_recordingPath!);

      setState(() {
        _isPlaying = true;
      });

      // Auto-stop po zakończeniu (listener w service to załatwi)
      Future.delayed(const Duration(seconds: 5), () {
        if (mounted) {
          setState(() {
            _isPlaying = false;
          });
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Błąd odtwarzania: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _stopPlaying() async {
    final playerService = ref.read(audioPlayerServiceProvider);
    await playerService.stop();

    setState(() {
      _isPlaying = false;
    });
  }

  Future<void> _deleteRecording() async {
    if (_recordingPath == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Usuń nagranie'),
        content: const Text('Czy na pewno chcesz usunąć to nagranie?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Anuluj'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Usuń'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final recorderService = ref.read(voiceRecorderServiceProvider);
    final success = await recorderService.deleteRecording(_recordingPath!);

    if (success && mounted) {
      setState(() {
        _recordingPath = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✔ Nagranie usunięte'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}