import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/category_symbol_model.dart';
import '../../data/repositories/category_symbol_repository.dart';

part 'category_symbols_provider.g.dart';

// StreamProvider z parametrem categoryId - automatyczne live updates!
@riverpod
Stream<List<CategorySymbolModel>> categorySymbols(Ref ref, String categoryId) async* {
  final repository = await ref.watch(categorySymbolRepositoryProvider.future);
  yield* repository.watchByCategoryId(categoryId);
}

// Provider dla liczby symboli w kategorii
@riverpod
Future<int> categorySymbolsCount(Ref ref, String categoryId) async {
  final repository = await ref.watch(categorySymbolRepositoryProvider.future);
  return await repository.countByCategoryId(categoryId);
}