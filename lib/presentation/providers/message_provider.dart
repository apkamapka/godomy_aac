import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/category_symbol_model.dart';
import '../../data/models/library_symbol_model.dart';
// ✅ NOWE IMPORTY
import '../../data/services/tts_service.dart';
import '../../data/services/audio_player_service.dart';

part 'message_provider.g.dart';

// Model reprezentujący symbol w wiadomości
class MessageSymbol {
  final String id; // ID CategorySymbolModel
  final String librarySymbolId;
  final String? emoji;
  final String? imagePath;
  final String name;
  final int backgroundColor;
  final String? voiceRecordingPath; // ✅ NOWE POLE!

  MessageSymbol({
    required this.id,
    required this.librarySymbolId,
    required this.emoji,
    required this.imagePath,
    required this.name,
    required this.backgroundColor,
    this.voiceRecordingPath, // ✅ NOWE POLE!
  });

  factory MessageSymbol.fromCategorySymbol(
      CategorySymbolModel categorySymbol,
      LibrarySymbolModel librarySymbol,
      ) {
    return MessageSymbol(
      id: categorySymbol.id,
      librarySymbolId: librarySymbol.id,
      emoji: categorySymbol.emojiOverride ?? librarySymbol.emoji,
      imagePath: categorySymbol.imagePathOverride ?? librarySymbol.imagePath,
      name: categorySymbol.nameOverride ?? librarySymbol.name,
      backgroundColor: categorySymbol.backgroundColor,
      voiceRecordingPath: categorySymbol.voiceRecordingPath, // ✅ NOWE!
    );
  }
}

// Provider dla listy symboli w wiadomości
@riverpod
class MessageSymbols extends _$MessageSymbols {
  @override
  List<MessageSymbol> build() => [];

  // Dodaj symbol do wiadomości
  void add(MessageSymbol symbol) {
    state = [...state, symbol];
  }

  // ✅ NOWE: Dodaj tekst jako symbol
  void addText(String text) {
    if (text.trim().isEmpty) return;

    final textSymbol = MessageSymbol(
      id: 'text_${DateTime.now().millisecondsSinceEpoch}',
      librarySymbolId: 'text',
      emoji: null,
      imagePath: null,
      name: text.trim(),
      backgroundColor: 0xFFE1BEE7, // Różowy kolor
      voiceRecordingPath: null, // Użyje TTS
    );

    state = [...state, textSymbol];
  }

  // Usuń ostatni symbol
  void removeLast() {
    if (state.isEmpty) return;
    state = state.sublist(0, state.length - 1);
  }

  // Usuń symbol po indeksie
  void removeAt(int index) {
    if (index < 0 || index >= state.length) return;
    state = [...state]..removeAt(index);
  }

  // Wyczyść wszystkie symbole
  void clear() {
    state = [];
  }

  // Pobierz tekst z symboli (nazwy połączone spacjami)
  String getText() {
    return state.map((s) => s.name).join(' ');
  }

  // ✅ NOWA METODA: Wypowiedz wszystkie symbole po kolei
  Future<void> speakAll() async {
    if (state.isEmpty) {
      print('⚠️ Brak symboli do wypowiedzenia');
      return;
    }

    final ttsService = ref.read(ttsServiceProvider);
    final audioPlayer = ref.read(audioPlayerServiceProvider);

    print('🗣️ Rozpoczynam wypowiadanie ${state.length} symboli...');

    for (var i = 0; i < state.length; i++) {
      final symbol = state[i];

      try {
        // PRIORYTET: Nagranie > TTS
        if (symbol.voiceRecordingPath != null &&
            symbol.voiceRecordingPath!.isNotEmpty) {
          // Odtwórz nagranie
          print('🎵 [$i/${state.length}] Odtwarzanie nagrania: ${symbol.name}');
          await audioPlayer.play(symbol.voiceRecordingPath!);

          // Czekaj aż się skończy (max 10 sekund)
          int waited = 0;
          while (audioPlayer.isPlaying && waited < 100) {
            await Future.delayed(const Duration(milliseconds: 100));
            waited++;
          }

          // Krótka przerwa między symbolami
          await Future.delayed(const Duration(milliseconds: 300));
        } else {
          // Użyj TTS
          print('🗣️ [$i/${state.length}] TTS: ${symbol.name}');
          await ttsService.speak(symbol.name);

          // Czekaj na zakończenie TTS (prosty delay - można ulepszyć)
          // Szacujemy ~300ms na każdy wyraz
          final wordsCount = symbol.name.split(' ').length;
          final estimatedDuration = Duration(milliseconds: 500 + (wordsCount * 300));
          await Future.delayed(estimatedDuration);

          // Krótka przerwa między symbolami
          await Future.delayed(const Duration(milliseconds: 200));
        }
      } catch (e) {
        print('❌ Błąd podczas wypowiadania symbolu "${symbol.name}": $e');
        // Kontynuuj mimo błędu
      }
    }

    print('✅ Zakończono wypowiadanie wszystkich symboli');
  }
}

// Provider dla stanu widoczności Message Container
@riverpod
class MessageContainerVisible extends _$MessageContainerVisible {
  @override
  bool build() => false;

  void toggle() {
    state = !state;
  }

  void show() {
    state = true;
  }

  void hide() {
    state = false;
  }
}