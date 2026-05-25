import 'package:isar/isar.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/library_symbol_model.dart';
import '../services/isar_service.dart';

part 'library_symbol_repository.g.dart';

@riverpod
Future<LibrarySymbolRepository> librarySymbolRepository(Ref ref) async {
  final isar = await ref.watch(isarProvider.future);
  return LibrarySymbolRepository(isar);
}

class LibrarySymbolRepository {
  final Isar _isar;

  LibrarySymbolRepository(this._isar);

  // CREATE
  Future<void> create(LibrarySymbolModel symbol) async {
    await _isar.writeTxn(() async {
      await _isar.librarySymbolModels.put(symbol);
    });

    // Wymuszenie synchronizacji Isar
    await _isar.librarySymbolModels.where().findAll();
  }

  // CREATE MANY
  Future<void> createMany(List<LibrarySymbolModel> symbols) async {
    await _isar.writeTxn(() async {
      await _isar.librarySymbolModels.putAll(symbols);
    });
  }

  // READ - wszystkie symbole
  Future<List<LibrarySymbolModel>> getAll() async {
    return await _isar.librarySymbolModels.where().findAll();
  }

  // READ - stream (live updates)
  Stream<List<LibrarySymbolModel>> watchAll() {
    return _isar.librarySymbolModels
        .where()
        .sortByName()
        .watch(fireImmediately: true);
  }

  // READ - po ID
  Future<LibrarySymbolModel?> getById(String id) async {
    return await _isar.librarySymbolModels.get(fastHash(id));
  }

  // READ - wyszukiwanie po nazwie
  Future<List<LibrarySymbolModel>> searchByName(String query) async {
    if (query.isEmpty) return getAll();

    return await _isar.librarySymbolModels
        .filter()
        .nameContains(query, caseSensitive: false)
        .sortByName()
        .findAll();
  }

  // READ - po tagach
  Future<List<LibrarySymbolModel>> getByTag(String tag) async {
    return await _isar.librarySymbolModels
        .filter()
        .tagsElementContains(tag, caseSensitive: false)
        .sortByName()
        .findAll();
  }

  // READ - tylko systemowe
  Future<List<LibrarySymbolModel>> getSystemDefaults() async {
    return await _isar.librarySymbolModels
        .filter()
        .isSystemDefaultEqualTo(true)
        .sortByName()
        .findAll();
  }

  // READ - najczęściej używane
  Future<List<LibrarySymbolModel>> getMostUsed({int limit = 20}) async {
    return await _isar.librarySymbolModels
        .where()
        .sortByUsageCountDesc()
        .limit(limit)
        .findAll();
  }

  // UPDATE
  Future<void> update(LibrarySymbolModel symbol) async {
    await _isar.writeTxn(() async {
      await _isar.librarySymbolModels.put(symbol);
    });
  }

  // UPDATE usage count
  Future<void> incrementUsageCount(String id) async {
    final symbol = await getById(id);
    if (symbol != null) {
      final updated = symbol.copyWith(
        usageCount: symbol.usageCount + 1,
        updatedAt: DateTime.now(),
      );
      await update(updated);
    }
  }

  // DELETE
  Future<void> delete(String id) async {
    await _isar.writeTxn(() async {
      await _isar.librarySymbolModels.delete(fastHash(id));
    });
  }

  // DELETE ALL (ostrożnie!)
  Future<void> deleteAll() async {
    await _isar.writeTxn(() async {
      await _isar.librarySymbolModels.clear();
    });
  }

  // DELETE only non-system
  Future<void> deleteAllNonSystem() async {
    await _isar.writeTxn(() async {
      final nonSystem = await _isar.librarySymbolModels
          .filter()
          .isSystemDefaultEqualTo(false)
          .findAll();

      final ids = nonSystem.map((s) => fastHash(s.id)).toList();
      await _isar.librarySymbolModels.deleteAll(ids);
    });
  }

  // COUNT
  Future<int> count() async {
    return await _isar.librarySymbolModels.count();
  }
}

/// Fast hash function
int fastHash(String string) {
  var hash = 0xcbf29ce484222325;
  var i = 0;
  while (i < string.length) {
    final codeUnit = string.codeUnitAt(i++);
    hash ^= codeUnit >> 8;
    hash *= 0x100000001b3;
    hash ^= codeUnit & 0xFF;
    hash *= 0x100000001b3;
  }
  return hash;
}