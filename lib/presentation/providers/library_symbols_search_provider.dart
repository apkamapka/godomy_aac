import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../data/models/library_symbol_model.dart';
import 'library_symbols_provider.dart';

part 'library_symbols_search_provider.g.dart';

// Provider dla query wyszukiwania
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
Future<List<LibrarySymbolModel>> filteredLibrarySymbols(
    FilteredLibrarySymbolsRef ref,
    ) async {
  final allSymbols = await ref.watch(librarySymbolsProvider.future);
  final searchQuery = ref.watch(searchQueryProvider).toLowerCase();

  if (searchQuery.isEmpty) {
    return allSymbols;
  }

  return allSymbols.where((symbol) {
    final nameMatch = symbol.name.toLowerCase().contains(searchQuery);
    final tagsMatch = symbol.tags.any(
          (tag) => tag.toLowerCase().contains(searchQuery),
    );
    return nameMatch || tagsMatch;
  }).toList();
}