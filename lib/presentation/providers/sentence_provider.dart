import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/sentence_item.dart';
import '../../data/services/app_settings.dart';
import '../../data/services/audio_player_service.dart';
import '../../data/services/sentence_store.dart';
import '../../data/services/tts_service.dart';
import 'board_provider.dart';

export '../../data/models/sentence_item.dart';

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

  /// Numer bieżącego czytania – każde nowe czytanie albo „stop” go zmienia,
  /// więc stara pętla (czekająca na koniec mowy) wie, że ma się zakończyć.
  int _generation = 0;

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

  /// Dodaje gotowe zdanie (np. z „Moich zdań”) na koniec paska.
  void addItems(List<SentenceItem> items) {
    if (items.isEmpty) return;
    state = state.copyWith(items: [
      ...state.items,
      for (final item in items) item.withKey(_nextKey()),
    ]);
  }

  /// Czyta całe zdanie z paska (i zapisuje je w historii profilu).
  Future<void> speakAll() async {
    if (state.speaking || state.items.isEmpty) return;
    final items = List<SentenceItem>.of(state.items);
    _recordHistory(items);
    await _speakSequence(items, highlightInBar: true);
  }

  /// Czyta podane zdanie (np. zapisane) bez zmiany paska.
  /// [onIndex] dostaje indeks aktualnie czytanego słowa (null na końcu).
  Future<void> speakItems(List<SentenceItem> items, {ValueChanged<int?>? onIndex}) async {
    if (items.isEmpty) return;
    if (state.speaking) await stop();
    await _speakSequence(List.of(items), highlightInBar: false, onIndex: onIndex);
  }

  void _recordHistory(List<SentenceItem> items) {
    try {
      final profileId = ref.read(activeProfileIdProvider);
      if (profileId == null) return;
      if (!ref.read(profileSettingsProvider(profileId)).showSentences) return;
      ref.read(sentenceHistoryProvider(profileId).notifier).record(items);
    } catch (_) {
      // Historia nie jest krytyczna.
    }
  }

  Future<void> _speakSequence(
    List<SentenceItem> items, {
    required bool highlightInBar,
    ValueChanged<int?>? onIndex,
  }) async {
    final generation = ++_generation;
    bool alive() => generation == _generation;
    final tts = ref.read(ttsServiceProvider);
    final audio = ref.read(audioPlayerServiceProvider);

    void mark(int index) {
      if (!alive()) return;
      if (highlightInBar) _highlight(index);
      onIndex?.call(index);
    }

    state = state.copyWith(speaking: true, speakingIndex: highlightInBar ? 0 : null);
    try {
      var i = 0;
      while (i < items.length && alive()) {
        final item = items[i];
        if (item.hasRecording) {
          mark(i);
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
        mark(start);
        await tts.speak(buffer.toString(), onProgress: (charStart, charEnd) {
          for (final r in ranges) {
            if (charStart >= r.$2 && charStart <= r.$3) {
              mark(r.$1);
              break;
            }
          }
        });
      }
    } catch (_) {
      // Błąd syntezy/odtwarzania nie może zablokować paska zdania.
    } finally {
      if (alive()) state = state.copyWith(speaking: false, clearSpeakingIndex: true);
      onIndex?.call(null);
    }
  }

  void _highlight(int index) {
    if (state.speakingIndex != index) {
      state = state.copyWith(speakingIndex: index);
    }
  }

  /// Przerywa czytanie zdania.
  Future<void> stop() async {
    _generation++;
    state = state.copyWith(speaking: false, clearSpeakingIndex: true);
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
