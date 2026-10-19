import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../models/sentence_item.dart';
import 'app_settings.dart';

/// Lista zdań zapisana w ustawieniach urządzenia, osobno dla każdego profilu.
abstract class _SentenceListNotifier extends FamilyNotifier<List<StoredSentence>, String> {
  String get _prefix;

  String get _key => '$_prefix$arg';

  @override
  List<StoredSentence> build(String arg) {
    final raw = ref.watch(appPrefsProvider).getString('$_prefix$arg');
    if (raw == null) return const [];
    try {
      final list = jsonDecode(raw) as List;
      return [
        for (final e in list)
          if (e is Map) StoredSentence.fromJson(Map<String, dynamic>.from(e)),
      ].where((s) => s.items.isNotEmpty).toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> _save(List<StoredSentence> list) async {
    state = list;
    await ref
        .read(appPrefsProvider)
        .setString(_key, jsonEncode(list.map((s) => s.toJson()).toList()));
  }

  Future<void> remove(String id) => _save(state.where((s) => s.id != id).toList());
}

/// „Moje zdania” – zdania przygotowane przez opiekuna na później.
class SavedSentencesNotifier extends _SentenceListNotifier {
  static const prefix = 'saved_sentences_';
  static String keyFor(String profileId) => '$prefix$profileId';

  @override
  String get _prefix => prefix;

  bool contains(List<SentenceItem> items) {
    final text = items.map((i) => i.label).join(' ');
    return state.any((s) => s.text == text);
  }

  /// Dodaje zdanie na koniec listy (bez duplikatów). Zwraca false, gdy już było.
  Future<bool> add(List<SentenceItem> items) async {
    if (items.isEmpty || contains(items)) return false;
    final sentence = StoredSentence(
      id: const Uuid().v4(),
      items: List.of(items),
      time: DateTime.now(),
    );
    await _save([...state, sentence]);
    return true;
  }

  Future<void> move(int oldIndex, int newIndex) async {
    final list = List.of(state);
    if (newIndex > oldIndex) newIndex -= 1;
    final item = list.removeAt(oldIndex);
    list.insert(newIndex, item);
    await _save(list);
  }
}

final savedSentencesProvider =
    NotifierProvider.family<SavedSentencesNotifier, List<StoredSentence>, String>(
  SavedSentencesNotifier.new,
);

/// Historia – ostatnio wypowiedziane zdania (najnowsze na górze).
class SentenceHistoryNotifier extends _SentenceListNotifier {
  static const prefix = 'sentence_history_';
  static const maxEntries = 30;
  static String keyFor(String profileId) => '$prefix$profileId';

  @override
  String get _prefix => prefix;

  Future<void> record(List<SentenceItem> items) async {
    if (items.isEmpty) return;
    final text = items.map((i) => i.label).join(' ');
    final rest = state.where((s) => s.text != text);
    final entry = StoredSentence(
      id: const Uuid().v4(),
      items: List.of(items),
      time: DateTime.now(),
    );
    await _save([entry, ...rest].take(maxEntries).toList());
  }

  Future<void> clear() => _save(const []);
}

final sentenceHistoryProvider =
    NotifierProvider.family<SentenceHistoryNotifier, List<StoredSentence>, String>(
  SentenceHistoryNotifier.new,
);
