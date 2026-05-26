import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/services/backup_service.dart';
import '../../data/repositories/profile_repository.dart';
import '../../data/repositories/category_repository.dart';
import '../../data/repositories/category_symbol_repository.dart';
import '../../data/repositories/library_symbol_repository.dart';

/// Provider serwisu kopii zapasowych.
///
/// Zwykły FutureProvider (bez generowania kodu) - spina cztery repozytoria
/// potrzebne do eksportu/importu profilu.
final backupServiceProvider = FutureProvider<BackupService>((ref) async {
  final profileRepo = await ref.watch(profileRepositoryProvider.future);
  final categoryRepo = await ref.watch(categoryRepositoryProvider.future);
  final categorySymbolRepo =
      await ref.watch(categorySymbolRepositoryProvider.future);
  final librarySymbolRepo =
      await ref.watch(librarySymbolRepositoryProvider.future);

  return BackupService(
    profileRepo: profileRepo,
    categoryRepo: categoryRepo,
    categorySymbolRepo: categorySymbolRepo,
    librarySymbolRepo: librarySymbolRepo,
  );
});
