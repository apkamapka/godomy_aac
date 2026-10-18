import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/system_ids.dart';
import '../../data/models/category_model.dart';
import '../../data/models/category_symbol_model.dart';
import '../../data/models/library_symbol_model.dart';
import '../../data/models/profile_model.dart';
import '../../data/repositories/category_repository.dart';
import '../../data/repositories/category_symbol_repository.dart';
import '../../data/repositories/library_symbol_repository.dart';
import '../../data/repositories/profile_repository.dart';
import '../../data/services/app_settings.dart';
import '../../data/services/default_content_service.dart';

enum BoardItemKind { folder, symbol }

/// Element tablicy (folder albo symbol) z już rozwiązanymi danymi z biblioteki.
class BoardItem {
  final BoardItemKind kind;
  final String id;
  final String name;
  final String? emoji;
  final String? imagePath;
  final Color color;
  final int position;
  final String? voicePath;

  final CategoryModel? category;
  final CategorySymbolModel? symbol;
  final LibrarySymbolModel? library;

  const BoardItem({
    required this.kind,
    required this.id,
    required this.name,
    required this.emoji,
    required this.imagePath,
    required this.color,
    required this.position,
    this.voicePath,
    this.category,
    this.symbol,
    this.library,
  });

  bool get isFolder => kind == BoardItemKind.folder;
  bool get hasRecording => voicePath != null && voicePath!.isNotEmpty;

  factory BoardItem.folder(CategoryModel c) {
    return BoardItem(
      kind: BoardItemKind.folder,
      id: c.id,
      name: c.name,
      emoji: c.emoji,
      imagePath: c.iconPath,
      color: Color(c.backgroundColor),
      position: c.position,
      category: c,
    );
  }

  factory BoardItem.symbol(CategorySymbolModel s, LibrarySymbolModel? lib) {
    final look = SymbolLook.of(s, lib);
    return BoardItem(
      kind: BoardItemKind.symbol,
      id: s.id,
      name: look.name,
      emoji: look.emoji,
      imagePath: look.imagePath,
      color: Color(s.backgroundColor),
      position: s.position,
      voicePath: s.voiceRecordingPath,
      symbol: s,
      library: lib,
    );
  }
}

/// Jak wygląda symbol po uwzględnieniu nadpisań z kategorii.
///
/// Pusty napis w nadpisaniu (`''`) oznacza „świadomie bez obrazka/emoji”
/// – np. symbol z biblioteki z obrazkiem, któremu w tej kategorii nadano emoji.
class SymbolLook {
  final String name;
  final String? emoji;
  final String? imagePath;

  const SymbolLook(this.name, this.emoji, this.imagePath);

  static SymbolLook of(CategorySymbolModel s, LibrarySymbolModel? lib) {
    final name = (s.nameOverride != null && s.nameOverride!.trim().isNotEmpty)
        ? s.nameOverride!
        : (lib?.name ?? '');
    final emoji = s.emojiOverride != null
        ? (s.emojiOverride!.isEmpty ? null : s.emojiOverride)
        : lib?.emoji;
    final image = s.imagePathOverride != null
        ? (s.imagePathOverride!.isEmpty ? null : s.imagePathOverride)
        : lib?.imagePath;
    return SymbolLook(name, emoji, image);
  }
}

/// Klucz tablicy: profil + folder (null = tablica startowa).
typedef BoardKey = ({String profileId, String? categoryId});

List<BoardItem> _combine(
  List<CategoryModel> categories,
  List<CategorySymbolModel> symbols,
  Map<String, LibrarySymbolModel> library,
) {
  final items = <BoardItem>[
    ...categories.map(BoardItem.folder),
    ...symbols.map((s) => BoardItem.symbol(s, library[s.librarySymbolId])),
  ];
  // Stabilne sortowanie: pozycja, a przy remisie foldery przed symbolami.
  items.sort((a, b) {
    final byPos = a.position.compareTo(b.position);
    if (byPos != 0) return byPos;
    if (a.isFolder != b.isFolder) return a.isFolder ? -1 : 1;
    return 0;
  });
  return items;
}

/// Zawartość tablicy, odświeżana na żywo (kategorie + symbole + biblioteka).
final boardItemsProvider =
    StreamProvider.autoDispose.family<List<BoardItem>, BoardKey>((ref, key) {
  final controller = StreamController<List<BoardItem>>();
  final subs = <StreamSubscription<dynamic>>[];

  List<CategoryModel>? categories;
  List<CategorySymbolModel>? symbols;
  Map<String, LibrarySymbolModel>? library;

  void emit() {
    if (categories == null || symbols == null || library == null) return;
    if (controller.isClosed) return;
    controller.add(_combine(categories!, symbols!, library!));
  }

  Future<void> setup() async {
    try {
      final catRepo = await ref.read(categoryRepositoryProvider.future);
      final symRepo = await ref.read(categorySymbolRepositoryProvider.future);
      final libRepo = await ref.read(librarySymbolRepositoryProvider.future);
      if (controller.isClosed) return;

      subs.add(catRepo.watchByParentId(key.profileId, key.categoryId).listen((v) {
        categories = v;
        emit();
      }));

      final Stream<List<CategorySymbolModel>> symbolStream = key.categoryId == null
          ? symRepo.watchRoot(SystemIds.rootOf(key.profileId), includeLegacy: true)
          : symRepo.watchByCategoryId(key.categoryId);
      subs.add(symbolStream.listen((v) {
        symbols = v;
        emit();
      }));

      subs.add(libRepo.watchAll().listen((v) {
        library = {for (final l in v) l.id: l};
        emit();
      }));
    } catch (e, st) {
      if (!controller.isClosed) controller.addError(e, st);
    }
  }

  setup();

  ref.onDispose(() {
    for (final s in subs) {
      s.cancel();
    }
    controller.close();
  });

  return controller.stream;
});

/// Profil (na żywo – zmiana zdjęcia/głosu od razu widoczna).
final profileProvider =
    StreamProvider.autoDispose.family<ProfileModel?, String>((ref, id) async* {
  final repo = await ref.watch(profileRepositoryProvider.future);
  await for (final all in repo.watchAll()) {
    ProfileModel? found;
    for (final p in all) {
      if (p.id == id) {
        found = p;
        break;
      }
    }
    yield found;
  }
});

/// Tablica systemowa profilu (tworzona przy pierwszym użyciu).
final systemBoardProvider =
    FutureProvider.autoDispose.family<CategoryModel, (String, SystemBoard)>((ref, key) async {
  final service = await ref.watch(defaultContentServiceProvider.future);
  return service.systemBoard(key.$1, key.$2);
});

/// Ścieżka folderów od tablicy startowej do [categoryId] (do „okruszków”).
final breadcrumbsProvider =
    FutureProvider.autoDispose.family<List<CategoryModel>, String>((ref, categoryId) async {
  final repo = await ref.watch(categoryRepositoryProvider.future);
  final result = <CategoryModel>[];
  String? current = categoryId;
  var guard = 0;
  while (current != null && guard++ < 20) {
    final c = await repo.getById(current);
    if (c == null) break;
    result.insert(0, c);
    current = c.parentId;
  }
  return result;
});

/// Kategoria (np. bieżący folder) – na żywo.
final categoryByIdProvider =
    StreamProvider.autoDispose.family<CategoryModel?, String>((ref, id) async* {
  final repo = await ref.watch(categoryRepositoryProvider.future);
  yield* repo.watchById(id);
});

/// „Częste” – najczęściej dotykane symbole profilu.
final frequentItemsProvider =
    FutureProvider.autoDispose.family<List<BoardItem>, String>((ref, profileId) async {
  final usage = ref.watch(usageStoreProvider);
  final ids = usage.top(profileId, limit: 24);
  if (ids.isEmpty) return [];

  final symRepo = await ref.watch(categorySymbolRepositoryProvider.future);
  final libRepo = await ref.watch(librarySymbolRepositoryProvider.future);
  final symbols = await symRepo.getByIds(ids);
  final byId = {for (final s in symbols) s.id: s};

  final result = <BoardItem>[];
  for (final id in ids) {
    final s = byId[id];
    if (s == null) continue;
    final lib = await libRepo.getById(s.librarySymbolId);
    if (lib == null) continue;
    result.add(BoardItem.symbol(s, lib));
  }
  return result;
});
