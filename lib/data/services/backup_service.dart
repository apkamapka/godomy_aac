import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../models/profile_model.dart';
import '../models/category_model.dart';
import '../models/category_symbol_model.dart';
import '../models/library_symbol_model.dart';
import '../repositories/profile_repository.dart';
import '../repositories/category_repository.dart';
import '../repositories/category_symbol_repository.dart';
import '../repositories/library_symbol_repository.dart';

/// Wersja formatu pliku kopii zapasowej.
///
/// Podbijaj, jeśli zmieni się struktura danych - pozwala wykryć i obsłużyć
/// stare kopie po aktualizacji aplikacji.
const int kBackupFormatVersion = 1;

/// Wynik importu - ile czego odtworzono.
class ImportResult {
  final String profileName;
  final int categories;
  final int symbols;

  const ImportResult({
    required this.profileName,
    required this.categories,
    required this.symbols,
  });
}

/// Serwis kopii zapasowych profili.
///
/// Eksport: pakuje profil + jego drzewo kategorii + symbole w tych kategoriach
/// + używane symbole z biblioteki + wszystkie pliki (zdjęcia, nagrania) do ZIP.
///
/// Import: odtwarza wszystko jako NOWY profil (świeże ID), kopiuje pliki w nowe
/// miejsce i podmienia ścieżki - nic nie nadpisuje istniejących danych.
class BackupService {
  final ProfileRepository profileRepo;
  final CategoryRepository categoryRepo;
  final CategorySymbolRepository categorySymbolRepo;
  final LibrarySymbolRepository librarySymbolRepo;

  BackupService({
    required this.profileRepo,
    required this.categoryRepo,
    required this.categorySymbolRepo,
    required this.librarySymbolRepo,
  });

  static const _uuid = Uuid();

  // ========================= EKSPORT =========================

  /// Buduje plik ZIP kopii zapasowej profilu. Zwraca ścieżkę do gotowego pliku.
  Future<String> exportProfile(String profileId) async {
    final profile = await profileRepo.getById(profileId);
    if (profile == null) {
      throw Exception('Profil nie istnieje');
    }

    // Całe drzewo kategorii profilu (wszystkie poziomy).
    final categories = await categoryRepo.getByProfileId(profileId);

    // Symbole we wszystkich tych kategoriach.
    final categorySymbols = <CategorySymbolModel>[];
    for (final cat in categories) {
      categorySymbols.addAll(await categorySymbolRepo.getByCategoryId(cat.id));
    }

    // Tylko te symbole z biblioteki, które są faktycznie używane.
    final usedLibraryIds =
        categorySymbols.map((s) => s.librarySymbolId).toSet();
    final librarySymbols = <LibrarySymbolModel>[];
    for (final libId in usedLibraryIds) {
      final lib = await librarySymbolRepo.getById(libId);
      if (lib != null) librarySymbols.add(lib);
    }

    // Zbierz wszystkie ścieżki plików do spakowania.
    // Mapujemy oryginalną ścieżkę -> nazwa pliku w ZIP-ie (unikalna).
    final fileMap = <String, String>{};
    void addFile(String? path) {
      if (path == null || path.isEmpty) return;
      if (fileMap.containsKey(path)) return;
      // Pliki z assets (np. domyślne symbole) pomijamy - są w samej apce.
      if (path.startsWith('assets/')) return;
      final f = File(path);
      if (!f.existsSync()) return;
      final ext = path.contains('.') ? path.substring(path.lastIndexOf('.')) : '';
      fileMap[path] = 'files/${_uuid.v4()}$ext';
    }

    addFile(profile.photoPath);
    for (final c in categories) {
      addFile(c.iconPath);
    }
    for (final s in categorySymbols) {
      addFile(s.imagePathOverride);
      addFile(s.voiceRecordingPath);
    }
    for (final l in librarySymbols) {
      addFile(l.imagePath);
    }

    // Zbuduj JSON. Ścieżki plików zapisujemy jako nazwy względne w ZIP.
    final manifest = {
      'formatVersion': kBackupFormatVersion,
      'exportedAt': DateTime.now().toIso8601String(),
      'profile': _profileToJson(profile, fileMap),
      'categories':
          categories.map((c) => _categoryToJson(c, fileMap)).toList(),
      'categorySymbols':
          categorySymbols.map((s) => _categorySymbolToJson(s, fileMap)).toList(),
      'librarySymbols':
          librarySymbols.map((l) => _librarySymbolToJson(l, fileMap)).toList(),
    };

    // Spakuj wszystko do archiwum.
    final archive = Archive();
    final jsonBytes = utf8.encode(jsonEncode(manifest));
    archive.addFile(ArchiveFile('backup.json', jsonBytes.length, jsonBytes));

    for (final entry in fileMap.entries) {
      final bytes = await File(entry.key).readAsBytes();
      archive.addFile(ArchiveFile(entry.value, bytes.length, bytes));
    }

    final zipData = ZipEncoder().encode(archive)!;

    // Zapisz do katalogu tymczasowego pod czytelną nazwą.
    final tmpDir = await getTemporaryDirectory();
    final safeName = profile.name.replaceAll(RegExp(r'[^\w\s-]'), '').trim();
    final stamp = DateTime.now().toIso8601String().substring(0, 10);
    final outPath =
        '${tmpDir.path}/godoMyAAC_${safeName.isEmpty ? 'profil' : safeName}_$stamp.zip';
    final outFile = File(outPath);
    await outFile.writeAsBytes(zipData);

    return outPath;
  }

  // ========================= IMPORT =========================

  /// Importuje profil z pliku ZIP jako NOWY profil. Zwraca podsumowanie.
  Future<ImportResult> importProfile(String zipPath) async {
    final bytes = await File(zipPath).readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);

    // Wczytaj manifest.
    final jsonFile = archive.files.firstWhere(
      (f) => f.name == 'backup.json',
      orElse: () => throw Exception('Nieprawidłowy plik kopii (brak backup.json)'),
    );
    final manifest =
        jsonDecode(utf8.decode(jsonFile.content as List<int>)) as Map<String, dynamic>;

    final version = manifest['formatVersion'] as int? ?? 0;
    if (version > kBackupFormatVersion) {
      throw Exception(
          'Ta kopia pochodzi z nowszej wersji aplikacji. Zaktualizuj godoMyAAC.');
    }

    // Rozpakuj pliki do katalogu dokumentów z nowymi nazwami.
    // Mapa: nazwa w ZIP -> nowa ścieżka absolutna na urządzeniu.
    final docsDir = await getApplicationDocumentsDirectory();
    final restoredPaths = <String, String>{};
    for (final f in archive.files) {
      if (!f.isFile || !f.name.startsWith('files/')) continue;
      final ext =
          f.name.contains('.') ? f.name.substring(f.name.lastIndexOf('.')) : '';
      final newName = '${_uuid.v4()}$ext';
      final newPath = '${docsDir.path}/$newName';
      await File(newPath).writeAsBytes(f.content as List<int>);
      restoredPaths[f.name] = newPath;
    }

    String? resolvePath(String? zipName) {
      if (zipName == null || zipName.isEmpty) return null;
      if (zipName.startsWith('assets/')) return zipName; // asset zostaje
      return restoredPaths[zipName];
    }

    final now = DateTime.now();

    // --- Profil: nowy ID, nazwa z dopiskiem (import) ---
    final pJson = manifest['profile'] as Map<String, dynamic>;
    final newProfileId = _uuid.v4();
    final importedName = '${pJson['name']} (import)';
    final profile = ProfileModel(
      id: newProfileId,
      name: importedName,
      photoPath: resolvePath(pJson['photoPath'] as String?),
      ttsLanguage: pJson['ttsLanguage'] as String? ?? 'pl-PL',
      ttsVoiceId: pJson['ttsVoiceId'] as String?,
      ttsRate: (pJson['ttsRate'] as num?)?.toDouble() ?? 0.5,
      ttsPitch: (pJson['ttsPitch'] as num?)?.toDouble() ?? 1.0,
      ttsVolume: (pJson['ttsVolume'] as num?)?.toDouble() ?? 1.0,
      createdAt: now,
      updatedAt: now,
    );

    // --- Symbole biblioteki: zachowujemy ID (uuid - bezpieczne).
    // Jeśli taki już istnieje w bibliotece, nie dublujemy.
    final libJson = (manifest['librarySymbols'] as List).cast<Map<String, dynamic>>();
    for (final l in libJson) {
      final id = l['id'] as String;
      final existing = await librarySymbolRepo.getById(id);
      if (existing != null) continue;
      await librarySymbolRepo.create(LibrarySymbolModel(
        id: id,
        name: l['name'] as String,
        imagePath: resolvePath(l['imagePath'] as String?),
        emoji: l['emoji'] as String?,
        backgroundColor: l['backgroundColor'] as int?,
        tags: (l['tags'] as List?)?.cast<String>() ?? const [],
        isSystemDefault: l['isSystemDefault'] as bool? ?? false,
        isAnimated: l['isAnimated'] as bool? ?? false,
        createdAt: now,
        updatedAt: now,
        usageCount: l['usageCount'] as int? ?? 0,
      ));
    }

    // --- Kategorie: nowe ID, remapowanie parentId ---
    final catJson = (manifest['categories'] as List).cast<Map<String, dynamic>>();
    final catIdMap = <String, String>{}; // stareID -> noweID
    for (final c in catJson) {
      catIdMap[c['id'] as String] = _uuid.v4();
    }

    final newCategories = <CategoryModel>[];
    for (final c in catJson) {
      final oldParent = c['parentId'] as String?;
      newCategories.add(CategoryModel(
        id: catIdMap[c['id'] as String]!,
        name: c['name'] as String,
        iconName: c['iconName'] as String?,
        iconPath: resolvePath(c['iconPath'] as String?),
        emoji: c['emoji'] as String?,
        backgroundColor: c['backgroundColor'] as int,
        textColor: c['textColor'] as int,
        iconColor: c['iconColor'] as int,
        communicationMode: CommunicationMode
            .values[(c['communicationMode'] as int?) ?? 0],
        gridConfig: GridConfig(
          columns: (c['gridConfig']?['columns'] as int?) ?? 3,
          rows: (c['gridConfig']?['rows'] as int?) ?? 4,
        ),
        scrollLocked: c['scrollLocked'] as bool? ?? false,
        position: c['position'] as int? ?? 0,
        profileId: newProfileId,
        parentId: oldParent == null ? null : catIdMap[oldParent],
        createdAt: now,
        updatedAt: now,
      ));
    }

    // --- Symbole w kategoriach: nowe ID, remapowanie categoryId ---
    final symJson =
        (manifest['categorySymbols'] as List).cast<Map<String, dynamic>>();
    final newSymbols = <CategorySymbolModel>[];
    for (final s in symJson) {
      final oldCat = s['categoryId'] as String?;
      newSymbols.add(CategorySymbolModel(
        id: _uuid.v4(),
        librarySymbolId: s['librarySymbolId'] as String,
        categoryId: oldCat == null ? null : catIdMap[oldCat],
        nameOverride: s['nameOverride'] as String?,
        imagePathOverride: resolvePath(s['imagePathOverride'] as String?),
        emojiOverride: s['emojiOverride'] as String?,
        backgroundColor: s['backgroundColor'] as int,
        voiceRecordingPath: resolvePath(s['voiceRecordingPath'] as String?),
        position: s['position'] as int? ?? 0,
        createdAt: now,
        updatedAt: now,
      ));
    }

    // --- Zapis (profil, potem kategorie, potem symbole) ---
    await profileRepo.create(profile);
    for (final c in newCategories) {
      await categoryRepo.create(c);
    }
    if (newSymbols.isNotEmpty) {
      await categorySymbolRepo.createMany(newSymbols);
    }

    return ImportResult(
      profileName: importedName,
      categories: newCategories.length,
      symbols: newSymbols.length,
    );
  }

  // ========================= SERIALIZACJA =========================
  // Ręczna - żeby ścieżki plików zamienić na nazwy względne w ZIP.

  Map<String, dynamic> _profileToJson(ProfileModel p, Map<String, String> fileMap) => {
        'id': p.id,
        'name': p.name,
        'photoPath': fileMap[p.photoPath],
        'ttsLanguage': p.ttsLanguage,
        'ttsVoiceId': p.ttsVoiceId,
        'ttsRate': p.ttsRate,
        'ttsPitch': p.ttsPitch,
        'ttsVolume': p.ttsVolume,
      };

  Map<String, dynamic> _categoryToJson(CategoryModel c, Map<String, String> fileMap) => {
        'id': c.id,
        'name': c.name,
        'iconName': c.iconName,
        'iconPath': c.iconPath != null && c.iconPath!.startsWith('assets/')
            ? c.iconPath
            : fileMap[c.iconPath],
        'emoji': c.emoji,
        'backgroundColor': c.backgroundColor,
        'textColor': c.textColor,
        'iconColor': c.iconColor,
        'communicationMode': c.communicationMode.index,
        'gridConfig': {'columns': c.gridConfig.columns, 'rows': c.gridConfig.rows},
        'scrollLocked': c.scrollLocked,
        'position': c.position,
        'parentId': c.parentId,
      };

  Map<String, dynamic> _categorySymbolToJson(
          CategorySymbolModel s, Map<String, String> fileMap) =>
      {
        'id': s.id,
        'librarySymbolId': s.librarySymbolId,
        'categoryId': s.categoryId,
        'nameOverride': s.nameOverride,
        'imagePathOverride':
            s.imagePathOverride != null && s.imagePathOverride!.startsWith('assets/')
                ? s.imagePathOverride
                : fileMap[s.imagePathOverride],
        'emojiOverride': s.emojiOverride,
        'backgroundColor': s.backgroundColor,
        'voiceRecordingPath': fileMap[s.voiceRecordingPath],
        'position': s.position,
      };

  Map<String, dynamic> _librarySymbolToJson(
          LibrarySymbolModel l, Map<String, String> fileMap) =>
      {
        'id': l.id,
        'name': l.name,
        'imagePath': l.imagePath != null && l.imagePath!.startsWith('assets/')
            ? l.imagePath
            : fileMap[l.imagePath],
        'emoji': l.emoji,
        'backgroundColor': l.backgroundColor,
        'tags': l.tags,
        'isSystemDefault': l.isSystemDefault,
        'isAnimated': l.isAnimated,
        'usageCount': l.usageCount,
      };
}
