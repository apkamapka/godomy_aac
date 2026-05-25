import 'package:isar/isar.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/category_symbol_model.dart';
import '../services/isar_service.dart';

part 'category_symbol_repository.g.dart';

@riverpod
Future<CategorySymbolRepository> categorySymbolRepository(Ref ref) async {
  final isar = await ref.watch(isarProvider.future);
  return CategorySymbolRepository(isar);
}

class CategorySymbolRepository {
  final Isar _isar;

  CategorySymbolRepository(this._isar);

  // CREATE
  Future<void> create(CategorySymbolModel symbol) async {
    await _isar.writeTxn(() async {
      await _isar.categorySymbolModels.put(symbol);
    });
  }

  // CREATE MANY
  Future<void> createMany(List<CategorySymbolModel> symbols) async {
    await _isar.writeTxn(() async {
      await _isar.categorySymbolModels.putAll(symbols);
    });
  }

  // READ - wszystkie symbole
  Future<List<CategorySymbolModel>> getAll() async {
    return await _isar.categorySymbolModels.where().findAll();
  }

  // READ - symbole dla kategorii
  // READ - symbole dla kategorii (null = root level)
  Future<List<CategorySymbolModel>> getByCategoryId(String? categoryId) async {
    if (categoryId == null) {
      return await _isar.categorySymbolModels
          .filter()
          .categoryIdIsNull()
          .sortByPosition()
          .findAll();
    }
    return await _isar.categorySymbolModels
        .filter()
        .categoryIdEqualTo(categoryId)
        .sortByPosition()
        .findAll();
  }

  // READ - stream (live updates) dla kategorii (null = root level)
  Stream<List<CategorySymbolModel>> watchByCategoryId(String? categoryId) {
    if (categoryId == null) {
      return _isar.categorySymbolModels
          .filter()
          .categoryIdIsNull()
          .sortByPosition()
          .watch(fireImmediately: true);
    }
    return _isar.categorySymbolModels
        .filter()
        .categoryIdEqualTo(categoryId)
        .sortByPosition()
        .watch(fireImmediately: true);
  }

  // READ - po ID
  Future<CategorySymbolModel?> getById(String id) async {
    return await _isar.categorySymbolModels.get(fastHash(id));
  }

  // READ - po librarySymbolId
  Future<List<CategorySymbolModel>> getByLibrarySymbolId(String librarySymbolId) async {
    return await _isar.categorySymbolModels
        .filter()
        .librarySymbolIdEqualTo(librarySymbolId)
        .findAll();
  }

  // UPDATE
  Future<void> update(CategorySymbolModel symbol) async {
    await _isar.writeTxn(() async {
      await _isar.categorySymbolModels.put(symbol);
    });
  }

  // DELETE
  Future<void> delete(String id) async {
    await _isar.writeTxn(() async {
      await _isar.categorySymbolModels.delete(fastHash(id));
    });
  }

  // DELETE wszystkie symbole kategorii
  Future<void> deleteByCategoryId(String categoryId) async {
    await _isar.writeTxn(() async {
      final symbols = await getByCategoryId(categoryId);
      final ids = symbols.map((s) => fastHash(s.id)).toList();
      await _isar.categorySymbolModels.deleteAll(ids);
    });
  }

  // DELETE wszystkie instancje symbolu z biblioteki
  Future<void> deleteByLibrarySymbolId(String librarySymbolId) async {
    await _isar.writeTxn(() async {
      final symbols = await getByLibrarySymbolId(librarySymbolId);
      final ids = symbols.map((s) => fastHash(s.id)).toList();
      await _isar.categorySymbolModels.deleteAll(ids);
    });
  }

  // Aktualizacja pozycji (drag & drop)
  Future<void> updatePositions(List<CategorySymbolModel> symbols) async {
    await _isar.writeTxn(() async {
      for (var i = 0; i < symbols.length; i++) {
        final updated = symbols[i].copyWith(position: i);
        await _isar.categorySymbolModels.put(updated);
      }
    });
  }

  // COUNT
  // COUNT
  Future<int> countByCategoryId(String? categoryId) async {
    if (categoryId == null) {
      return await _isar.categorySymbolModels
          .filter()
          .categoryIdIsNull()
          .count();
    }
    return await _isar.categorySymbolModels
        .filter()
        .categoryIdEqualTo(categoryId)
        .count();
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