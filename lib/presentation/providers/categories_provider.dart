import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/category_model.dart';
import '../../data/repositories/category_repository.dart';

part 'categories_provider.g.dart';

// StreamProvider z parametrem profileId - automatyczne live updates z Isar!
@riverpod
Stream<List<CategoryModel>> categories(Ref ref, String profileId) async* {
  print('🔍 CategoriesProvider: profileId = $profileId'); // DEBUG

  final repository = await ref.watch(categoryRepositoryProvider.future);
  print('📡 CategoriesProvider: Starting stream for profile $profileId'); // DEBUG

  // WAŻNE: yield* przekazuje cały stream - auto-updates!
  await for (final categories in repository.watchByProfileId(profileId)) {
    print('📊 CategoriesProvider: Stream emitted ${categories.length} categories'); // DEBUG
    yield categories;
  }
}

// Provider dla stanu zwijania menu
@riverpod
class MenuCollapsed extends _$MenuCollapsed {
  @override
  bool build() => false;

  void toggle() {
    state = !state;
  }

  void collapse() {
    state = true;
  }

  void expand() {
    state = false;
  }
}

// Provider dla trybu usuwania
@riverpod
class DeleteMode extends _$DeleteMode {
  @override
  bool build() => false;

  void toggle() {
    state = !state;
  }

  void enable() {
    state = true;
  }

  void disable() {
    state = false;
  }
}