import 'dart:async';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/category_model.dart';
import '../../data/models/category_symbol_model.dart';
import '../../data/repositories/category_repository.dart';
import '../../data/repositories/category_symbol_repository.dart';

part 'folder_content_provider.g.dart';

// Model zawartości folderu
class FolderContent {
  final List<CategoryModel> categories;
  final List<CategorySymbolModel> symbols;

  const FolderContent({
    required this.categories,
    required this.symbols,
  });

  bool get isEmpty => categories.isEmpty && symbols.isEmpty;
  int get totalCount => categories.length + symbols.length;
}

// Provider dla zawartości folderu - reaguje na oba streamy!
@riverpod
Stream<FolderContent> folderContent(
    Ref ref,
    String profileId,
    String? parentId,
    ) {
  final controller = StreamController<FolderContent>.broadcast();

  List<CategoryModel>? latestCategories;
  List<CategorySymbolModel>? latestSymbols;
  StreamSubscription? categoriesSub;
  StreamSubscription? symbolsSub;

  void emitIfReady() {
    if (latestCategories != null && latestSymbols != null) {
      controller.add(FolderContent(
        categories: latestCategories!,
        symbols: latestSymbols!,
      ));
    }
  }

  Future<void> setup() async {
    final categoryRepo = await ref.read(categoryRepositoryProvider.future);
    final symbolRepo = await ref.read(categorySymbolRepositoryProvider.future);

    // Słuchamy kategorii
    categoriesSub = categoryRepo.watchByParentId(profileId, parentId).listen((categories) {
      latestCategories = categories;
      emitIfReady();
    });

    // Słuchamy symboli
    symbolsSub = symbolRepo.watchByCategoryId(parentId).listen((symbols) {
      latestSymbols = symbols;
      emitIfReady();
    });
  }

  setup();

  ref.onDispose(() {
    categoriesSub?.cancel();
    symbolsSub?.cancel();
    controller.close();
  });

  return controller.stream;
}

// Provider dla informacji o aktualnej kategorii (do breadcrumbs/tytułu)
@riverpod
Future<CategoryModel?> currentCategory(Ref ref, String? categoryId) async {
  if (categoryId == null) return null;

  final repository = await ref.watch(categoryRepositoryProvider.future);
  return await repository.getById(categoryId);
}

// Provider dla ścieżki breadcrumbs
@riverpod
Future<List<CategoryModel>> categoryBreadcrumbs(
    Ref ref,
    String? categoryId,
    ) async {
  if (categoryId == null) return [];

  final repository = await ref.watch(categoryRepositoryProvider.future);
  final breadcrumbs = <CategoryModel>[];

  String? currentId = categoryId;
  while (currentId != null) {
    final category = await repository.getById(currentId);
    if (category == null) break;
    breadcrumbs.insert(0, category);
    currentId = category.parentId;
  }

  return breadcrumbs;
}

// Provider dla stanu zwijania menu
@riverpod
class FolderMenuCollapsed extends _$FolderMenuCollapsed {
  @override
  bool build() => false;

  void toggle() => state = !state;
  void collapse() => state = true;
  void expand() => state = false;
}

// Provider dla trybu usuwania
@riverpod
class FolderDeleteMode extends _$FolderDeleteMode {
  @override
  bool build() => false;

  void toggle() => state = !state;
  void enable() => state = true;
  void disable() => state = false;
}

// Provider dla trybu sortowania
@riverpod
class FolderSortMode extends _$FolderSortMode {
  @override
  bool build() => false;

  void toggle() => state = !state;
  void enable() => state = true;
  void disable() => state = false;
}