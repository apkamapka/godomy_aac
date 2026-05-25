import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/library_symbol_model.dart';
import '../../data/repositories/library_symbol_repository.dart';

part 'library_symbols_provider.g.dart';

// ✅ DODAJ autoDispose - to wymusza odświeżanie!
@riverpod
Stream<List<LibrarySymbolModel>> librarySymbols(Ref ref) async* {
  print('🔄 [PROVIDER] librarySymbols - tworzę nowy stream');
  final repository = await ref.watch(librarySymbolRepositoryProvider.future);

  // Nasłuchuj na zmiany w bazie danych
  await for (final symbols in repository.watchAll()) {
    print('📡 [PROVIDER] Otrzymano ${symbols.length} symboli z Isar');
    yield symbols;
  }
}

// Provider dla wyszukiwania
@riverpod
class SearchQuery extends _$SearchQuery {
  @override
  String build() => '';

  void update(String query) {
    state = query;
  }

  void clear() {
    state = '';
  }
}

// Provider dla filtrowanych symboli
@riverpod
Future<List<LibrarySymbolModel>> filteredLibrarySymbols(Ref ref) async {
  final repository = await ref.watch(librarySymbolRepositoryProvider.future);
  final query = ref.watch(searchQueryProvider);

  if (query.isEmpty) {
    return await repository.getAll();
  } else {
    return await repository.searchByName(query);
  }
}

// Provider dla najczęściej używanych
@riverpod
Future<List<LibrarySymbolModel>> mostUsedSymbols(Ref ref, {int limit = 10}) async {
  final repository = await ref.watch(librarySymbolRepositoryProvider.future);
  return await repository.getMostUsed(limit: limit);
}

// Provider dla liczby symboli
@riverpod
Future<int> librarySymbolsCount(Ref ref) async {
  final repository = await ref.watch(librarySymbolRepositoryProvider.future);
  return await repository.count();
}