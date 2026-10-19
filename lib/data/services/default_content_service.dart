import 'dart:async';
import 'dart:io';
import 'dart:ui' show Color;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../core/constants/system_ids.dart';
import '../../core/theme/app_colors.dart';
import '../models/category_model.dart';
import '../models/category_symbol_model.dart';
import '../models/library_symbol_model.dart';
import '../repositories/category_repository.dart';
import '../repositories/category_symbol_repository.dart';
import '../repositories/library_symbol_repository.dart';

/// Tablice systemowe profilu.
enum SystemBoard { core, urgent, schedule }

extension SystemBoardIds on SystemBoard {
  String get parentId {
    switch (this) {
      case SystemBoard.core:
        return SystemIds.coreParent;
      case SystemBoard.urgent:
        return SystemIds.urgentParent;
      case SystemBoard.schedule:
        return SystemIds.scheduleParent;
    }
  }
}

/// Opis symbolu w gotowej treści.
class _Sym {
  final String name;
  final WordKind kind;
  final String? file;
  final String? emoji;

  const _Sym(this.name, this.kind, {this.file, this.emoji});
}

/// Opis folderu w gotowej treści.
class _Folder {
  final String name;
  final List<String> aliases;
  final String icon;
  final Color color;
  final List<_Sym> symbols;
  final List<_Folder> children;
  final int columns;
  final int rows;

  const _Folder(
    this.name, {
    required this.icon,
    required this.color,
    this.aliases = const [],
    this.symbols = const [],
    this.children = const [],
    this.columns = 3,
    this.rows = 4,
  });
}

class StarterResult {
  final int categories;
  final int symbols;
  const StarterResult(this.categories, this.symbols);
}

/// Gotowa tablica startowa + tablice systemowe (słowa kluczowe, Pilne,
/// Plan dnia). Kolory kafelków wg klucza Fitzgeralda.
class DefaultContentService {
  final CategoryRepository categoryRepo;
  final CategorySymbolRepository symbolRepo;
  final LibrarySymbolRepository libraryRepo;

  DefaultContentService({
    required this.categoryRepo,
    required this.symbolRepo,
    required this.libraryRepo,
  });

  static const _uuid = Uuid();
  static const _assetDir = 'assets/symbols';

  /// Animowane obrazki (animowany WebP).
  static const _animated = {'tak-gif.webp', 'nie-gif.webp', 'iść-gif.webp', 'skakać-gif.webp'};

  // ---------------------------------------------------------------------------
  // Treść
  // ---------------------------------------------------------------------------

  static const _folders = <_Folder>[
    _Folder(
      'Potrzeby',
      icon: 'potrzeby-folder.webp',
      color: Color(0xFFFAC0BE),
      symbols: [
        _Sym('toaleta', WordKind.things, file: 'toaleta.webp'),
        _Sym('pić', WordKind.actions, file: 'pić.webp'),
        _Sym('jeść', WordKind.actions, file: 'jeść.webp'),
        _Sym('spać', WordKind.actions, file: 'spać.webp'),
        _Sym('pampers', WordKind.things, file: 'pampers.webp'),
        _Sym('myć zęby', WordKind.actions, file: 'myć zęby.webp'),
        _Sym('myć ręce', WordKind.actions, file: 'myć ręce.webp'),
        _Sym('kąpać się', WordKind.actions, file: 'kąpać się.webp'),
      ],
    ),
    _Folder(
      'Emocje',
      aliases: ['Emocje i uczucia'],
      icon: 'emocje-folder.webp',
      color: Color(0xFFC2E5FA),
      symbols: [
        _Sym('radosna', WordKind.describe, file: 'radosna.webp'),
        _Sym('smutna', WordKind.describe, file: 'smutna.webp'),
        _Sym('boję się', WordKind.describe, file: 'boję się.webp'),
        _Sym('zmęczona', WordKind.describe, file: 'zmęczona.webp'),
        _Sym('znudzona', WordKind.describe, file: 'znudzona.webp'),
        _Sym('zła', WordKind.describe, file: 'zła.webp'),
        _Sym('podekscytowana', WordKind.describe, file: 'podekscytowana.webp'),
        _Sym('przytul mnie', WordKind.social, file: 'przytul mnie.webp'),
      ],
    ),
    _Folder(
      'Rozmowa',
      aliases: ['Komunikacja podstawowa'],
      icon: 'komunikacja_folder.webp',
      color: Color(0xFFFBCFE1),
      columns: 4,
      rows: 4,
      symbols: [
        _Sym('tak', WordKind.actions, file: 'tak-gif.webp'),
        _Sym('nie', WordKind.negation, file: 'nie-gif.webp'),
        _Sym('proszę', WordKind.social, file: 'proszę.webp'),
        _Sym('dziękuję', WordKind.social, file: 'dziękuję.webp'),
        _Sym('przepraszam', WordKind.social, file: 'przepraszam.webp'),
        _Sym('potrzebuję pomocy', WordKind.actions, file: 'potrzebuję pomocy.webp'),
        _Sym('lubię to', WordKind.actions, file: 'lubię to.webp'),
        _Sym('nie lubię', WordKind.negation, file: 'nie lubię.webp'),
        _Sym('nie wiem', WordKind.social, file: 'nie wiem.webp'),
        _Sym('jeszcze', WordKind.describe, file: 'jeszcze.webp'),
        _Sym('boli', WordKind.negation, file: 'boli.webp'),
        _Sym('gorąco', WordKind.describe, file: 'gorąco.webp'),
        _Sym('zimno', WordKind.describe, file: 'zimno.webp'),
        _Sym('dzień dobry', WordKind.social, file: 'dzień dobry.webp'),
        _Sym('dobranoc', WordKind.social, file: 'dobranoc.webp'),
        _Sym('pa pa', WordKind.social, file: 'pa pa.webp'),
      ],
    ),
    _Folder(
      'Czynności',
      aliases: ['Czynności/Aktywności'],
      icon: 'czynnosci-folder.webp',
      color: Color(0xFFC3EDB4),
      symbols: [
        _Sym('bawić się', WordKind.actions, file: 'bawić się.webp'),
        _Sym('spacer', WordKind.actions, file: 'spacer.webp'),
        _Sym('siedzieć', WordKind.actions, file: 'siedzieć.webp'),
        _Sym('czytać', WordKind.actions, file: 'czytać.webp'),
        _Sym('rysować', WordKind.actions, file: 'rysować.webp'),
        _Sym('muzyka', WordKind.things, file: 'muzyka.webp'),
        _Sym('śpiewać', WordKind.actions, file: 'śpiewać.webp'),
        _Sym('tańczyć', WordKind.actions, file: 'tańczyc.webp'),
      ],
      children: [
        _Folder(
          'Ruch',
          icon: 'ruch-folder.webp',
          color: Color(0xFFC3EDB4),
          symbols: [
            _Sym('chodzić', WordKind.actions, file: 'iść-gif.webp'),
            _Sym('biegać', WordKind.actions, file: 'biegać.webp'),
            _Sym('skakać', WordKind.actions, file: 'skakać-gif.webp'),
            _Sym('stać', WordKind.actions, file: 'stać.webp'),
          ],
        ),
        _Folder(
          'Akcje',
          icon: 'Akcje-folder.webp',
          color: Color(0xFFC3EDB4),
          symbols: [
            _Sym('brać', WordKind.actions, file: 'brać.webp'),
            _Sym('dawać', WordKind.actions, file: 'dawać.webp'),
            _Sym('otwierać', WordKind.actions, file: 'otwierać.webp'),
            _Sym('zamykać', WordKind.actions, file: 'zamykać.webp'),
            _Sym('trzymać', WordKind.actions, file: 'trzymać.webp'),
            _Sym('upuścić', WordKind.actions, file: 'upuścić.webp'),
            _Sym('wkładać', WordKind.actions, file: 'wkładać.webp'),
            _Sym('wyciągać', WordKind.actions, file: 'wyciągać.webp'),
            _Sym('być', WordKind.actions, file: 'być.webp'),
          ],
        ),
      ],
    ),
    _Folder(
      'Ciało',
      aliases: ['Części ciała'],
      icon: 'czesci-ciala-folder.webp',
      color: Color(0xFFFFD5AA),
      symbols: [
        _Sym('głowa', WordKind.things, file: 'głowa.webp'),
        _Sym('oko', WordKind.things, file: 'oko.webp'),
        _Sym('ucho', WordKind.things, file: 'ucho.webp'),
        _Sym('nos', WordKind.things, file: 'nos.webp'),
        _Sym('usta', WordKind.things, file: 'usta.webp'),
        _Sym('ręka', WordKind.things, file: 'ręka.webp'),
        _Sym('brzuch', WordKind.things, file: 'brzuch.webp'),
        _Sym('nogi', WordKind.things, file: 'nogi.webp'),
        _Sym('stopy', WordKind.things, file: 'stopy.webp'),
      ],
    ),
    _Folder(
      'Osoby',
      icon: 'osoby.webp',
      color: Color(0xFFFFE680),
      symbols: [
        _Sym('ja', WordKind.people, file: 'ja.webp'),
        _Sym('ty', WordKind.people, file: 'ty.webp'),
      ],
    ),
    _Folder(
      'Pogoda',
      aliases: ['Pory roku/Pogoda'],
      icon: 'pogoda-folder.webp',
      color: Color(0xFFB2EBF2),
      symbols: [
        _Sym('słońce', WordKind.things, file: 'słońce.webp'),
        _Sym('chmury', WordKind.things, file: 'chmury.webp'),
        _Sym('pada deszcz', WordKind.actions, file: 'pada deszcz.webp'),
        _Sym('śnieg', WordKind.things, file: 'śnieg.webp'),
        _Sym('wiatr', WordKind.things, file: 'wiatr.webp'),
        _Sym('wiosna', WordKind.things, file: 'wiosna.webp'),
        _Sym('lato', WordKind.things, file: 'lato.webp'),
        _Sym('jesień', WordKind.things, file: 'jesień.webp'),
        _Sym('zima', WordKind.things, file: 'zima.webp'),
      ],
    ),
    _Folder(
      'Przedmioty',
      icon: 'przedmioty-folder.webp',
      color: Color(0xFFFFD5AA),
      children: [
        _Folder(
          'Meble',
          icon: 'meble-folder.webp',
          color: Color(0xFFFFD5AA),
          symbols: [
            _Sym('krzesło', WordKind.things, file: 'krzesło.webp'),
            _Sym('stół', WordKind.things, file: 'stól.webp'),
            _Sym('łóżko', WordKind.things, file: 'łóżko.webp'),
          ],
        ),
        _Folder(
          'Naczynia',
          icon: 'naczynia-folder.webp',
          color: Color(0xFFFFD5AA),
          symbols: [
            _Sym('kubek', WordKind.things, file: 'kubek.webp'),
            _Sym('butelka', WordKind.things, file: 'butelka.webp'),
            _Sym('szklanka', WordKind.things, file: 'szklanka.webp'),
            _Sym('talerz', WordKind.things, file: 'talerz.webp'),
            _Sym('miska', WordKind.things, file: 'miska.webp'),
            _Sym('łyżka', WordKind.things, file: 'łyżka.webp'),
            _Sym('widelec', WordKind.things, file: 'widelec.webp'),
          ],
        ),
        _Folder(
          'Zabawki',
          icon: 'zabawki-folder.webp',
          color: Color(0xFFFFD5AA),
          symbols: [
            _Sym('piłka', WordKind.things, file: 'piłka.webp'),
            _Sym('lalka', WordKind.things, file: 'lalka.webp'),
          ],
        ),
        _Folder(
          'Przybory',
          icon: 'przybory-folder.webp',
          color: Color(0xFFFFD5AA),
          symbols: [
            _Sym('książka', WordKind.things, file: 'książka.webp'),
            _Sym('ołówek', WordKind.things, file: 'ołowek.webp'),
          ],
        ),
      ],
    ),
  ];

  /// Słowa kluczowe – zawsze w tym samym miejscu na tablicy startowej.
  static const _core = <_Sym>[
    _Sym('ja', WordKind.people, file: 'ja.webp'),
    _Sym('chcę', WordKind.actions, file: 'chcę.webp'),
    _Sym('nie', WordKind.negation, file: 'nie-gif.webp'),
    _Sym('tak', WordKind.actions, file: 'tak-gif.webp'),
    _Sym('jeszcze', WordKind.describe, file: 'jeszcze.webp'),
    _Sym('pomóż', WordKind.actions, file: 'potrzebuję pomocy.webp'),
    _Sym('daj', WordKind.actions, file: 'dawać.webp'),
    _Sym('koniec', WordKind.misc, file: 'koniec.webp'),
  ];

  /// Pilne – mówione od razu po dotknięciu.
  static const _urgent = <_Sym>[
    _Sym('chcę do toalety', WordKind.negation, file: 'toaleta.webp'),
    _Sym('boli mnie', WordKind.negation, file: 'boli.webp'),
    _Sym('chcę pić', WordKind.negation, file: 'pić.webp'),
    _Sym('pomocy!', WordKind.negation, file: 'potrzebuję pomocy.webp'),
    _Sym('potrzebuję przerwy', WordKind.negation, file: 'przerwa.webp'),
    _Sym('chcę jeść', WordKind.negation, file: 'jeść.webp'),
  ];

  /// Przykładowy plan dnia – opiekun łatwo go zmieni.
  static const _schedule = <_Sym>[
    _Sym('śniadanie', WordKind.things, file: 'jeść.webp'),
    _Sym('myć zęby', WordKind.actions, file: 'myć zęby.webp'),
    _Sym('zabawa', WordKind.actions, file: 'bawić się.webp'),
    _Sym('spacer', WordKind.actions, file: 'spacer.webp'),
    _Sym('obiad', WordKind.things, file: 'talerz.webp'),
    _Sym('kąpiel', WordKind.actions, file: 'kąpać się.webp'),
    _Sym('spać', WordKind.actions, file: 'spać.webp'),
  ];

  // ---------------------------------------------------------------------------
  // API
  // ---------------------------------------------------------------------------

  /// Operacje tworzące treść wykonujemy po kolei (bez wyścigów, np. gdy dwa
  /// ekrany jednocześnie poproszą o tę samą tablicę systemową).
  static Future<void> _queue = Future<void>.value();

  static Future<T> _serialized<T>(Future<T> Function() task) {
    final completer = Completer<T>();
    _queue = _queue.then((_) async {
      try {
        completer.complete(await task());
      } catch (e, st) {
        completer.completeError(e, st);
      }
    });
    return completer.future;
  }

  /// Dodaje gotową tablicę startową. Foldery, które już istnieją na tablicy
  /// (po nazwie lub starej nazwie), są pomijane – nic się nie dubluje.
  Future<StarterResult> addStarterBoard(String profileId) => _serialized(() => _addStarterBoard(profileId));

  Future<StarterResult> _addStarterBoard(String profileId) async {
    final library = await _LibraryIndex.load(libraryRepo);
    final rootCategories = await categoryRepo.getByParentId(profileId, null);
    final rootSymbols = await symbolRepo.getRoot(SystemIds.rootOf(profileId));

    final existingNames = rootCategories.map((c) => c.name.trim().toLowerCase()).toSet();
    var position = _nextPosition(rootCategories.map((c) => c.position), rootSymbols.map((s) => s.position));

    var catCount = 0;
    var symCount = 0;
    for (final folder in _folders) {
      final names = [folder.name, ...folder.aliases].map((n) => n.toLowerCase());
      if (names.any(existingNames.contains)) continue;
      final (c, s) = await _createFolder(profileId, folder, parentId: null, position: position++, library: library);
      catCount += c;
      symCount += s;
    }
    await _flushLibrary(library);
    return StarterResult(catCount, symCount);
  }

  /// Tworzy brakujące tablice systemowe profilu (z domyślną treścią).
  Future<void> ensureSystemBoards(String profileId) => _serialized(() => _ensureSystemBoards(profileId));

  Future<void> _ensureSystemBoards(String profileId) async {
    await _upgradeEmojiSymbols();
    _LibraryIndex? library;
    for (final board in SystemBoard.values) {
      final existing = await categoryRepo.getSystemCategory(profileId, board.parentId);
      if (existing != null) continue;
      library ??= await _LibraryIndex.load(libraryRepo);
      await _createSystemBoard(profileId, board, library);
    }
    if (library != null) await _flushLibrary(library);
  }

  /// Zwraca kategorię tablicy systemowej (tworzy ją, jeśli trzeba).
  Future<CategoryModel> systemBoard(String profileId, SystemBoard board) =>
      _serialized(() => _systemBoard(profileId, board));

  Future<CategoryModel> _systemBoard(String profileId, SystemBoard board) async {
    final existing = await categoryRepo.getSystemCategory(profileId, board.parentId);
    if (existing != null) return existing;
    final library = await _LibraryIndex.load(libraryRepo);
    final created = await _createSystemBoard(profileId, board, library);
    await _flushLibrary(library);
    return created;
  }

  // ---------------------------------------------------------------------------
  // Implementacja
  // ---------------------------------------------------------------------------

  /// Gotowe symbole, które w wersji 1.1 były emoji – teraz mają obrazki
  /// (emoji potrafią znikać po odblokowaniu ekranu na niektórych telefonach).
  static const _emojiUpgrades = {
    'chcę': 'chcę.webp',
    'koniec': 'koniec.webp',
    'potrzebuję przerwy': 'przerwa.webp',
  };

  Future<void> _upgradeEmojiSymbols() async {
    try {
      final all = await libraryRepo.getAll();
      final now = DateTime.now();
      final updates = <LibrarySymbolModel>[];
      for (final symbol in all) {
        if (!symbol.isSystemDefault) continue;
        if (symbol.imagePath != null && symbol.imagePath!.isNotEmpty) continue;
        final file = _emojiUpgrades[symbol.name.trim().toLowerCase()];
        if (file == null) continue;
        final path = await _copyAsset(file);
        if (path == null) continue;
        updates.add(symbol.copyWith(imagePath: path, emoji: null, updatedAt: now));
      }
      if (updates.isNotEmpty) await libraryRepo.createMany(updates);
    } catch (e) {
      if (kDebugMode) debugPrint('Aktualizacja obrazków nie powiodła się: $e');
    }
  }

  int _nextPosition(Iterable<int> a, Iterable<int> b) {
    var maxPos = -1;
    for (final p in a) {
      if (p > maxPos) maxPos = p;
    }
    for (final p in b) {
      if (p > maxPos) maxPos = p;
    }
    return maxPos + 1;
  }

  Future<(int, int)> _createFolder(
    String profileId,
    _Folder folder, {
    required String? parentId,
    required int position,
    required _LibraryIndex library,
  }) async {
    final now = DateTime.now();
    final id = _uuid.v4();
    final iconPath = await _copyAsset(folder.icon);
    final edge = AppColors.edgeFor(folder.color);

    await categoryRepo.create(CategoryModel(
      id: id,
      name: folder.name,
      iconPath: iconPath,
      backgroundColor: folder.color.toARGB32(),
      textColor: AppColors.ink.toARGB32(),
      iconColor: edge.toARGB32(),
      communicationMode: CommunicationMode.text,
      gridConfig: GridConfig(columns: folder.columns, rows: folder.rows),
      scrollLocked: false,
      position: position,
      profileId: profileId,
      parentId: parentId,
      createdAt: now,
      updatedAt: now,
    ));

    var categories = 1;
    var symbols = await _createSymbols(id, folder.symbols, library, startPosition: 0);

    var childPosition = folder.symbols.length;
    for (final child in folder.children) {
      final (c, s) = await _createFolder(
        profileId,
        child,
        parentId: id,
        position: childPosition++,
        library: library,
      );
      categories += c;
      symbols += s;
    }
    return (categories, symbols);
  }

  Future<CategoryModel> _createSystemBoard(
    String profileId,
    SystemBoard board,
    _LibraryIndex library,
  ) async {
    final now = DateTime.now();
    final (name, items, mode, grid, color) = switch (board) {
      SystemBoard.core => (
          'Słowa kluczowe',
          _core,
          CommunicationMode.text,
          GridConfig(columns: 4, rows: 2),
          WordKind.misc.color,
        ),
      SystemBoard.urgent => (
          'Pilne',
          _urgent,
          CommunicationMode.direct,
          GridConfig(columns: 2, rows: 3),
          WordKind.negation.color,
        ),
      SystemBoard.schedule => (
          'Plan dnia',
          _schedule,
          CommunicationMode.text,
          GridConfig(columns: 3, rows: 3),
          WordKind.describe.color,
        ),
    };

    final category = CategoryModel(
      id: _uuid.v4(),
      name: name,
      backgroundColor: color.toARGB32(),
      textColor: AppColors.ink.toARGB32(),
      iconColor: AppColors.edgeFor(color).toARGB32(),
      communicationMode: mode,
      gridConfig: grid,
      scrollLocked: false,
      position: 0,
      profileId: profileId,
      parentId: board.parentId,
      createdAt: now,
      updatedAt: now,
    );
    await categoryRepo.create(category);
    await _createSymbols(category.id, items, library, startPosition: 0);
    return category;
  }

  Future<int> _createSymbols(
    String categoryId,
    List<_Sym> items,
    _LibraryIndex library, {
    required int startPosition,
  }) async {
    final now = DateTime.now();
    final created = <CategorySymbolModel>[];
    var position = startPosition;
    for (final item in items) {
      final lib = await library.findOrCreate(item, this);
      if (lib == null) continue;
      created.add(CategorySymbolModel(
        id: _uuid.v4(),
        librarySymbolId: lib.id,
        categoryId: categoryId,
        backgroundColor: item.kind.argb,
        position: position++,
        createdAt: now,
        updatedAt: now,
      ));
    }
    // Najpierw nowe symbole biblioteki, potem odwołujące się do nich kafelki
    // (tablica nigdy nie pokaże kafelka bez obrazka/nazwy).
    await _flushLibrary(library);
    if (created.isNotEmpty) await symbolRepo.createMany(created);
    return created.length;
  }

  Future<void> _flushLibrary(_LibraryIndex library) async {
    if (library.pending.isEmpty) return;
    await libraryRepo.createMany(library.pending);
    library.pending.clear();
  }

  /// Kopiuje obrazek z assets do katalogu aplikacji (raz – kolejne profile
  /// korzystają z tego samego pliku). Zwraca ścieżkę lub null.
  Future<String?> _copyAsset(String fileName) async {
    try {
      final docs = await getApplicationDocumentsDirectory();
      final dir = Directory('${docs.path}/symbols');
      if (!await dir.exists()) await dir.create(recursive: true);
      final file = File('${dir.path}/$fileName');
      if (await file.exists() && await file.length() > 0) return file.path;
      final data = await rootBundle.load('$_assetDir/$fileName');
      await file.writeAsBytes(data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes));
      return file.path;
    } catch (e) {
      if (kDebugMode) debugPrint('Nie udało się skopiować $fileName: $e');
      return null;
    }
  }
}

/// Pomocnik: indeks biblioteki po nazwie, żeby nie dublować symboli.
class _LibraryIndex {
  final Map<String, LibrarySymbolModel> byName;
  final List<LibrarySymbolModel> pending = [];

  _LibraryIndex(this.byName);

  static Future<_LibraryIndex> load(LibrarySymbolRepository repo) async {
    final all = await repo.getAll();
    return _LibraryIndex({for (final s in all) s.name.trim().toLowerCase(): s});
  }

  Future<LibrarySymbolModel?> findOrCreate(_Sym item, DefaultContentService service) async {
    final key = item.name.trim().toLowerCase();
    final existing = byName[key];
    if (existing != null) return existing;

    String? imagePath;
    if (item.file != null) {
      imagePath = await service._copyAsset(item.file!);
      if (imagePath == null && item.emoji == null) return null;
    }
    final now = DateTime.now();
    final created = LibrarySymbolModel(
      id: DefaultContentService._uuid.v4(),
      name: item.name,
      imagePath: imagePath,
      emoji: imagePath == null ? item.emoji : null,
      tags: const [],
      isSystemDefault: true,
      isAnimated: item.file != null && DefaultContentService._animated.contains(item.file),
      createdAt: now,
      updatedAt: now,
      usageCount: 0,
    );
    byName[key] = created;
    pending.add(created);
    return created;
  }
}

final defaultContentServiceProvider = FutureProvider<DefaultContentService>((ref) async {
  final categoryRepo = await ref.watch(categoryRepositoryProvider.future);
  final symbolRepo = await ref.watch(categorySymbolRepositoryProvider.future);
  final libraryRepo = await ref.watch(librarySymbolRepositoryProvider.future);
  return DefaultContentService(
    categoryRepo: categoryRepo,
    symbolRepo: symbolRepo,
    libraryRepo: libraryRepo,
  );
});
