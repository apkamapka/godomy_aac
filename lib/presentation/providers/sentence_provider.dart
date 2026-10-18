import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/services/audio_player_service.dart';
import '../../data/services/tts_service.dart';
import 'board_provider.dart';

/// Jeden element budowanego zdania.
class SentenceItem {
  final String key;
  final String? symbolId;
  final String label;
  final String? emoji;
  final String? imagePath;
  final Color color;
  final String? voicePath;
  final bool isText;

  const SentenceItem({
    required this.key,
    required this.label,
    required this.color,
    this.symbolId,
    this.emoji,
    this.imagePath,
    this.voicePath,
    this.isText = false,
  });

  bool get hasRecording => voicePath != null && voicePath!.isNotEmpty;
}

class SentenceState {
  final List<SentenceItem> items;

  /// Indeks aktualnie czytanego elementu (do podświetlenia).
  final int? speakingIndex;
  final bool speaking;

  const SentenceState({
    this.items = const [],
    this.speakingIndex,
    this.speaking = false,
  });

  bool get isEmpty => items.isEmpty;
  String get text => items.map((i) => i.label).join(' ');

  SentenceState copyWith({
    List<SentenceItem>? items,
    int? speakingIndex,
    bool clearSpeakingIndex = false,
    bool? speaking,
  }) {
    return SentenceState(
      items: items ?? this.items,
      speakingIndex: clearSpeakingIndex ? null : (speakingIndex ?? this.speakingIndex),
      speaking: speaking ?? this.speaking,
    );
  }
}

/// Budowanie i czytanie zdania.
///
/// Kolejne słowa bez nagrań czytamy jednym ciągiem (naturalna intonacja),
/// a postęp syntezy podświetla bieżące słowo. Własne nagrania odtwarzamy
/// po kolei i czekamy na ich koniec.
class SentenceNotifier extends Notifier<SentenceState> {
  int _counter = 0;
  bool _cancel = false;

  @override
  SentenceState build() => const SentenceState();

  String _nextKey() => 's${_counter++}';

  void addItem(BoardItem item) {
    state = state.copyWith(items: [
      ...state.items,
      SentenceItem(
        key: _nextKey(),
        symbolId: item.id,
        label: item.name,
        emoji: item.emoji,
        imagePath: item.imagePath,
        color: item.color,
        voicePath: item.voicePath,
      ),
    ]);
  }

  void addText(String text) {
    final clean = text.trim();
    if (clean.isEmpty) return;
    state = state.copyWith(items: [
      ...state.items,
      SentenceItem(
        key: _nextKey(),
        label: clean,
        color: const Color(0xFFFFFFFF),
        isText: true,
      ),
    ]);
  }

  void removeLast() {
    if (state.items.isEmpty || state.speaking) return;
    state = state.copyWith(items: state.items.sublist(0, state.items.length - 1));
  }

  void removeAt(int index) {
    if (index < 0 || index >= state.items.length || state.speaking) return;
    state = state.copyWith(items: [...state.items]..removeAt(index));
  }

  void clear() {
    if (state.speaking) return;
    state = const SentenceState();
  }

  /// Czyta całe zdanie.
  Future<void> speakAll() async {
    if (state.speaking || state.items.isEmpty) return;
    _cancel = false;
    final items = List<SentenceItem>.of(state.items);
    final tts = ref.read(ttsServiceProvider);
    final audio = ref.read(audioPlayerServiceProvider);

    state = state.copyWith(speaking: true, speakingIndex: 0);
    try {
      var i = 0;
      while (i < items.length && !_cancel) {
        final item = items[i];
        if (item.hasRecording) {
          _highlight(i);
          await audio.playAndWait(item.voicePath!);
          i++;
          continue;
        }

        // Zbierz kolejne słowa bez nagrań w jedną wypowiedź.
        final start = i;
        final buffer = StringBuffer();
        final ranges = <(int, int, int)>[];
        while (i < items.length && !items[i].hasRecording) {
          if (buffer.isNotEmpty) buffer.write(' ');
          final from = buffer.length;
          buffer.write(items[i].label);
          ranges.add((i, from, buffer.length));
          i++;
        }
        _highlight(start);
        await tts.speak(buffer.toString(), onProgress: (charStart, charEnd) {
          for (final r in ranges) {
            if (charStart >= r.$2 && charStart <= r.$3) {
              _highlight(r.$1);
              break;
            }
          }
        });
      }
    } catch (_) {
      // Błąd syntezy/odtwarzania nie może zablokować paska zdania.
    } finally {
      state = state.copyWith(speaking: false, clearSpeakingIndex: true);
    }
  }

  void _highlight(int index) {
    if (_cancel) return;
    if (state.speakingIndex != index) {
      state = state.copyWith(speakingIndex: index);
    }
  }

  /// Przerywa czytanie zdania.
  Future<void> stop() async {
    _cancel = true;
    await ref.read(ttsServiceProvider).stop();
    await ref.read(audioPlayerServiceProvider).stop();
  }

  /// Mówi pojedynczy element (po dotknięciu kafelka) – przerywa zdanie.
  Future<void> speakSingle({required String text, String? voicePath}) async {
    try {
      if (state.speaking) await stop();
      if (voicePath != null && voicePath.isNotEmpty) {
        await ref.read(audioPlayerServiceProvider).play(voicePath);
      } else {
        await ref.read(ttsServiceProvider).speak(text);
      }
    } catch (_) {
      // Brak głosu/pliku nie może wywrócić tablicy.
    }
  }
}

final sentenceProvider = NotifierProvider<SentenceNotifier, SentenceState>(SentenceNotifier.new);
