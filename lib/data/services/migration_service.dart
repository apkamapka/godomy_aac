import 'package:flutter/foundation.dart';

import '../../core/constants/system_ids.dart';
import '../repositories/category_symbol_repository.dart';
import '../repositories/profile_repository.dart';

/// Jednorazowe poprawki danych po aktualizacji.
class MigrationService {
  MigrationService._();

  /// Do wersji 1.0 symbole dodane bezpośrednio na tablicę startową miały
  /// `categoryId == null` i pokazywały się we WSZYSTKICH profilach.
  /// Jeśli jest tylko jeden profil, przypisujemy je do niego. Przy kilku
  /// profilach zostają wspólne (tak jak było) – opiekun może je przenieść
  /// usuwając i dodając ponownie.
  static Future<void> run({
    required ProfileRepository profiles,
    required CategorySymbolRepository symbols,
  }) async {
    try {
      final all = await profiles.getAll();
      if (all.length != 1) return;
      final legacy = await symbols.getByCategoryId(null);
      if (legacy.isEmpty) return;
      final rootId = SystemIds.rootOf(all.first.id);
      await symbols.updateMany(
        legacy.map((s) => s.copyWith(categoryId: rootId)).toList(),
      );
    } catch (e) {
      if (kDebugMode) debugPrint('Migracja nie powiodła się: $e');
    }
  }
}
