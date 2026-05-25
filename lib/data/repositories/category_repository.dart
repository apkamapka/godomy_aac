import 'package:isar/isar.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/category_model.dart';
import '../services/isar_service.dart';
import '../models/category_symbol_model.dart';

part 'category_repository.g.dart';

@riverpod
Future<CategoryRepository> categoryRepository(Ref ref) async {
  final isar = await ref.watch(isarProvider.future);
  return CategoryRepository(isar);
}

class CategoryRepository {
  final Isar _isar;

  CategoryRepository(this._isar);

  // CREATE
  Future<void> create(CategoryModel category) async {
    await _isar.writeTxn(() async {
      await _isar.categoryModels.put(category);
    });
  }

  // READ - wszystkie kategorie
  Future<List<CategoryModel>> getAll() async {
    return await _isar.categoryModels.where().findAll();
  }

  // READ - kategorie dla profilu
  // READ - kategorie dla profilu
  Future<List<CategoryModel>> getByProfileId(String profileId) async {
    return await _isar.categoryModels
        .filter()
        .profileIdEqualTo(profileId)
        .sortByPosition()
        .findAll();
  }

  // READ - stream (live updates) dla profilu
  Stream<List<CategoryModel>> watchByProfileId(String profileId) {
    return _isar.categoryModels
        .filter()
        .profileIdEqualTo(profileId)
        .sortByPosition()
        .watch(fireImmediately: true);
  }

  // READ - kategorie dla danego rodzica (null = root)
  Future<List<CategoryModel>> getByParentId(String profileId, String? parentId) async {
    if (parentId == null) {
      return await _isar.categoryModels
          .filter()
          .profileIdEqualTo(profileId)
          .parentIdIsNull()
          .sortByPosition()
          .findAll();
    }
    return await _isar.categoryModels
        .filter()
        .profileIdEqualTo(profileId)
        .parentIdEqualTo(parentId)
        .sortByPosition()
        .findAll();
  }

  // READ - stream dla danego rodzica (null = root)
  Stream<List<CategoryModel>> watchByParentId(String profileId, String? parentId) {
    if (parentId == null) {
      return _isar.categoryModels
          .filter()
          .profileIdEqualTo(profileId)
          .parentIdIsNull()
          .sortByPosition()
          .watch(fireImmediately: true);
    }
    return _isar.categoryModels
        .filter()
        .profileIdEqualTo(profileId)
        .parentIdEqualTo(parentId)
        .sortByPosition()
        .watch(fireImmediately: true);
  }

  // DELETE kaskadowe - usuwa kategorię i wszystkie dzieci (rekurencyjnie)
  Future<void> deleteWithChildren(String id) async {
    await _isar.writeTxn(() async {
      await _deleteRecursive(id);
    });
  }

  Future<void> _deleteRecursive(String id) async {
    // Znajdź wszystkie dzieci
    final children = await _isar.categoryModels
        .filter()
        .parentIdEqualTo(id)
        .findAll();

    // Rekurencyjnie usuń dzieci
    for (final child in children) {
      await _deleteRecursive(child.id);
    }

    // Usuń symbole z tej kategorii
    final symbols = await _isar.categorySymbolModels
        .filter()
        .categoryIdEqualTo(id)
        .findAll();
    await _isar.categorySymbolModels.deleteAll(
        symbols.map((s) => fastHash(s.id)).toList()
    );

    // Usuń samą kategorię
    await _isar.categoryModels.delete(fastHash(id));
  }

  // READ - po ID
  Future<CategoryModel?> getById(String id) async {
    return await _isar.categoryModels.get(fastHash(id));
  }

  // UPDATE
  Future<void> update(CategoryModel category) async {
    await _isar.writeTxn(() async {
      await _isar.categoryModels.put(category);
    });
  }

  // DELETE
  Future<void> delete(String id) async {
    await _isar.writeTxn(() async {
      await _isar.categoryModels.delete(fastHash(id));
    });
  }

  // DELETE wszystkie kategorie profilu
  Future<void> deleteByProfileId(String profileId) async {
    await _isar.writeTxn(() async {
      final categories = await getByProfileId(profileId);
      final ids = categories.map((c) => fastHash(c.id)).toList();
      await _isar.categoryModels.deleteAll(ids);
    });
  }

  // Aktualizacja pozycji (drag & drop)
  Future<void> updatePositions(List<CategoryModel> categories) async {
    await _isar.writeTxn(() async {
      for (var i = 0; i < categories.length; i++) {
        final updated = categories[i].copyWith(position: i);
        await _isar.categoryModels.put(updated);
      }
    });
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