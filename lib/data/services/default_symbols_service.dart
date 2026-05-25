import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../models/library_symbol_model.dart';
import '../models/category_symbol_model.dart';
import '../models/category_model.dart';

class DefaultSymbolsService {
  static const _uuid = Uuid();

  /// Kopiuje ikony z assets do local storage
  static Future<String> _copyAssetToLocal(String assetPath) async {
    try {
      final byteData = await rootBundle.load(assetPath);
      final appDir = await getApplicationDocumentsDirectory();
      final fileName = assetPath.split('/').last;
      final file = File('${appDir.path}/$fileName');
      await file.writeAsBytes(byteData.buffer.asUint8List());
      return file.path;
    } catch (e) {
      print('⚠️ Error copying asset: $e');
      return '';
    }
  }

  /// Tworzy domyślne symbole dla kategorii
  /// Zwraca tuple: (List<LibrarySymbolModel>, List<CategorySymbolModel>)
  static Future<(List<LibrarySymbolModel>, List<CategorySymbolModel>)>
  createDefaultSymbolsForCategory(
      CategoryModel category,
      Future<List<LibrarySymbolModel>> Function() getExistingSymbols,
      Future<List<CategorySymbolModel>> Function(String categoryId) getExistingCategorySymbols,
      ) async {

    final now = DateTime.now();
    final librarySymbols = <LibrarySymbolModel>[];
    final categorySymbols = <CategorySymbolModel>[];

    // Pobierz istniejące symbole z biblioteki
    final existingSymbols = await getExistingSymbols();
    print('📚 Sprawdzam bibliotekę: ${existingSymbols.length} istniejących symboli');

    // Pobierz istniejące przypisania dla tej kategorii
    final existingCategorySymbols = await getExistingCategorySymbols(category.id);
    print('🔗 Kategoria "${category.name}" ma już ${existingCategorySymbols.length} przypisanych symboli');

    // ========== MAPA SYMBOLI DLA KATEGORII ==========
    final Map<String, List<Map<String, dynamic>>> categorySymbols_data = {

      // ========== POTRZEBY ==========
      'Potrzeby': [
        {'name': 'toaleta', 'file': 'toaleta.png', 'color': 0xFF81C784},
        {'name': 'pić', 'file': 'pić.png', 'color': 0xFF4DD0E1},
        {'name': 'jeść', 'file': 'jeść.png', 'color': 0xFFFFF176},
        {'name': 'spać', 'file': 'spać.png', 'color': 0xFFBA68C8},
        {'name': 'pampers', 'file': 'pampers.png', 'color': 0xFF64B5F6},
        {'name': 'myć zęby', 'file': 'myć zęby.png', 'color': 0xFFFFFFFF},
        {'name': 'myć ręce', 'file': 'myć ręce.png', 'color': 0xFFA1887F},
        {'name': 'kąpać się', 'file': 'kąpać się.png', 'color': 0xFFFFF176},
      ],

      // ========== EMOCJE I UCZUCIA (rozszerzone) ==========
      'Emocje i uczucia': [
        {'name': 'radosna', 'file': 'radosna.png', 'color': 0xFFFFF176},
        {'name': 'smutna', 'file': 'smutna.png', 'color': 0xFF64B5F6},
        {'name': 'boję się', 'file': 'boję się.png', 'color': 0xFFBA68C8},
        {'name': 'zmęczona', 'file': 'zmęczona.png', 'color': 0xFFA1887F},
        {'name': 'znudzona', 'file': 'znudzona.png', 'color': 0xFFFFB74D},
        {'name': 'przytul mnie', 'file': 'przytul mnie.png', 'color': 0xFFF06292},
        // NOWE:
        {'name': 'podekscytowana', 'file': 'podekscytowana.png', 'color': 0xFFFFD54F},
        {'name': 'zła', 'file': 'zła.png', 'color': 0xFFE57373},
      ],

      // ========== KOMUNIKACJA PODSTAWOWA (rozszerzona) ==========
      'Komunikacja podstawowa': [
        {'name': 'tak', 'file': 'tak-gif.gif', 'color': 0xFF81C784},
        {'name': 'nie', 'file': 'nie-gif.gif', 'color': 0xFFE57373},
        {'name': 'dziękuję', 'file': 'dziękuję.png', 'color': 0xFFFFF176},
        {'name': 'przepraszam', 'file': 'przepraszam.png', 'color': 0xFFBA68C8},
        {'name': 'proszę', 'file': 'proszę.png', 'color': 0xFF64B5F6},
        {'name': 'potrzebuję pomocy', 'file': 'potrzebuję pomocy.png', 'color': 0xFFFFB74D},
        {'name': 'nie lubię', 'file': 'nie lubię.png', 'color': 0xFFF06292},
        {'name': 'lubię to', 'file': 'lubię to.png', 'color': 0xFF81C784},
        {'name': 'nie wiem', 'file': 'nie wiem.png', 'color': 0xFF4DD0E1},
        {'name': 'jeszcze', 'file': 'jeszcze.png', 'color': 0xFFA1887F},
        {'name': 'boli', 'file': 'boli.png', 'color': 0xFFE57373},
        {'name': 'gorąco', 'file': 'gorąco.png', 'color': 0xFFFFB74D},
        {'name': 'zimno', 'file': 'zimno.png', 'color': 0xFF64B5F6},
        {'name': 'pa pa', 'file': 'pa pa.png', 'color': 0xFF81C784},
        // NOWE:
        {'name': 'dzień dobry', 'file': 'dzień dobry.png', 'color': 0xFFFFF176},
        {'name': 'dobranoc', 'file': 'dobranoc.png', 'color': 0xFF7986CB},
      ],

      // ========== CZYNNOŚCI/AKTYWNOŚCI (główne - bez podkategorii) ==========
      'Czynności/Aktywności': [
        {'name': 'bawić się', 'file': 'bawić się.png', 'color': 0xFFFFF176},
        {'name': 'spacer', 'file': 'spacer.png', 'color': 0xFF81C784},
        {'name': 'siedzieć', 'file': 'siedzieć.png', 'color': 0xFFBA68C8},
        {'name': 'czytać', 'file': 'czytać.png', 'color': 0xFF64B5F6},
        {'name': 'rysować', 'file': 'rysować.png', 'color': 0xFFFFB74D},
        {'name': 'muzyka', 'file': 'muzyka.png', 'color': 0xFFFFF176},
        // NOWE:
        {'name': 'śpiewać', 'file': 'śpiewać.png', 'color': 0xFFF06292},
        {'name': 'tańczyć', 'file': 'tańczyc.png', 'color': 0xFFBA68C8},
      ],

      // ========== PODKATEGORIA: RUCH ==========
      'Ruch': [
        {'name': 'chodzić', 'file': 'iść-gif.gif', 'color': 0xFF4DD0E1},
        {'name': 'biegać', 'file': 'biegać.png', 'color': 0xFF81C784},
        {'name': 'skakać', 'file': 'skakać.png', 'color': 0xFFFFF176},
        {'name': 'stać', 'file': 'stać.png', 'color': 0xFFFFB74D},
      ],

      // ========== PODKATEGORIA: AKCJE ==========
      'Akcje': [
        {'name': 'brać', 'file': 'brać.png', 'color': 0xFF81C784},
        {'name': 'dawać', 'file': 'dawać.png', 'color': 0xFF64B5F6},
        {'name': 'otwierać', 'file': 'otwierać.png', 'color': 0xFFFFF176},
        {'name': 'zamykać', 'file': 'zamykać.png', 'color': 0xFFBA68C8},
        {'name': 'trzymać', 'file': 'trzymać.png', 'color': 0xFFFFB74D},
        {'name': 'upuścić', 'file': 'upuścić.png', 'color': 0xFFE57373},
        {'name': 'wkładać', 'file': 'wkładać.png', 'color': 0xFF4DD0E1},
        {'name': 'wyciągać', 'file': 'wyciągać.png', 'color': 0xFFA1887F},
        {'name': 'być', 'file': 'być.png', 'color': 0xFFF06292},
      ],

      // ========== CZĘŚCI CIAŁA ==========
      'Części ciała': [
        {'name': 'ręka', 'file': 'ręka.png', 'color': 0xFFFFB74D},
        {'name': 'nogi', 'file': 'nogi.png', 'color': 0xFF81C784},
        {'name': 'stopy', 'file': 'stopy.png', 'color': 0xFF4DD0E1},
        {'name': 'ucho', 'file': 'ucho.png', 'color': 0xFFFFF176},
        {'name': 'usta', 'file': 'usta.png', 'color': 0xFFF06292},
        {'name': 'oko', 'file': 'oko.png', 'color': 0xFF64B5F6},
        {'name': 'głowa', 'file': 'głowa.png', 'color': 0xFFBA68C8},
        {'name': 'brzuch', 'file': 'brzuch.png', 'color': 0xFFA1887F},
      ],

      // ========== OSOBY ==========
      'Osoby': [
        {'name': 'ja', 'file': 'ja.png', 'color': 0xFF81C784},
        {'name': 'ty', 'file': 'ty.png', 'color': 0xFF64B5F6},
      ],

      // ========== PORY ROKU/POGODA (rozszerzona) ==========
      'Pory roku/Pogoda': [
        {'name': 'wiosna', 'file': 'wiosna.png', 'color': 0xFF81C784},
        {'name': 'lato', 'file': 'lato.png', 'color': 0xFFFFF176},
        {'name': 'jesień', 'file': 'jesień.png', 'color': 0xFFFFB74D},
        {'name': 'zima', 'file': 'zima.png', 'color': 0xFF64B5F6},
        {'name': 'pada deszcz', 'file': 'pada deszcz.png', 'color': 0xFF4DD0E1},
        // NOWE:
        {'name': 'słońce', 'file': 'słońce.png', 'color': 0xFF81D4FA}, // błękitne
        {'name': 'chmury', 'file': 'chmury.png', 'color': 0xFFFFF9C4}, // jasny żółty
        {'name': 'śnieg', 'file': 'śnieg.png', 'color': 0xFFFFFFFF},
        {'name': 'wiatr', 'file': 'wiatr.png', 'color': 0xFF80DEEA},
      ],

      // ========== PRZEDMIOTY (pusta - tylko podkategorie) ==========
      'Przedmioty': [],

      // ========== PODKATEGORIA: MEBLE ==========
      'Meble': [
        {'name': 'krzesło', 'file': 'krzesło.png', 'color': 0xFFA1887F},
        {'name': 'łóżko', 'file': 'łóżko.png', 'color': 0xFFBA68C8},
        {'name': 'stół', 'file': 'stól.png', 'color': 0xFFBCAAA4},
      ],

      // ========== PODKATEGORIA: NACZYNIA ==========
      'Naczynia': [
        {'name': 'butelka', 'file': 'butelka.png', 'color': 0xFF4DD0E1},
        {'name': 'kubek', 'file': 'kubek.png', 'color': 0xFF64B5F6},
        {'name': 'szklanka', 'file': 'szklanka.png', 'color': 0xFF80DEEA},
        {'name': 'talerz', 'file': 'talerz.png', 'color': 0xFFE0E0E0},
        {'name': 'miska', 'file': 'miska.png', 'color': 0xFFB2DFDB},
        {'name': 'łyżka', 'file': 'łyżka.png', 'color': 0xFFBDBDBD},
        {'name': 'widelec', 'file': 'widelec.png', 'color': 0xFFBDBDBD},
      ],

      // ========== PODKATEGORIA: ZABAWKI ==========
      'Zabawki': [
        {'name': 'lalka', 'file': 'lalka.png', 'color': 0xFFF48FB1},
        {'name': 'piłka', 'file': 'piłka.png', 'color': 0xFFFFF176},
      ],

      // ========== PODKATEGORIA: PRZYBORY ==========
      'Przybory': [
        {'name': 'książka', 'file': 'książka.png', 'color': 0xFF64B5F6},
        {'name': 'ołówek', 'file': 'ołowek.png', 'color': 0xFFFFF176},
      ],
    };

    final symbolsData = categorySymbols_data[category.name] ?? [];

    for (int i = 0; i < symbolsData.length; i++) {
      final symbolData = symbolsData[i];
      final fileName = symbolData['file'] as String;
      final symbolName = symbolData['name'] as String;
      final backgroundColor = symbolData['color'] as int;

      // 1. Sprawdź czy symbol jest w bibliotece
      final existingSymbol = existingSymbols.firstWhere(
            (s) => s.name == symbolName,
        orElse: () => LibrarySymbolModel(
          id: '',
          name: '',
          createdAt: now,
          updatedAt: now,
          usageCount: 0,
        ),
      );

      String librarySymbolId;

      if (existingSymbol.id.isNotEmpty) {
        librarySymbolId = existingSymbol.id;
        print('♻️ Używam istniejącego symbolu: $symbolName (${existingSymbol.id})');
      } else {
        // Kopiuj plik i utwórz nowy symbol w bibliotece
        final imagePath = await _copyAssetToLocal('assets/category_icons/$fileName');
        if (imagePath.isEmpty) {
          print('⚠️ Nie można skopiować pliku: $fileName');
          continue;
        }

        librarySymbolId = _uuid.v4();
        final isGif = fileName.toLowerCase().endsWith('.gif');

        final librarySymbol = LibrarySymbolModel(
          id: librarySymbolId,
          name: symbolName,
          imagePath: imagePath,
          tags: [category.name.toLowerCase()],
          isSystemDefault: true,
          isAnimated: isGif,
          createdAt: now,
          updatedAt: now,
          usageCount: 0,
        );
        librarySymbols.add(librarySymbol);
        print('🆕 Tworzę nowy symbol: $symbolName ($librarySymbolId)');
      }

      // 2. Sprawdź czy to przypisanie symbol↔kategoria już istnieje
      final alreadyAssigned = existingCategorySymbols.any(
            (cs) => cs.librarySymbolId == librarySymbolId,
      );

      if (alreadyAssigned) {
        print('⏭️ Symbol "$symbolName" już przypisany do kategorii "${category.name}" - pomijam');
        continue;
      }

      // 3. Utwórz nowe przypisanie symbol↔kategoria
      final categorySymbol = CategorySymbolModel(
        id: _uuid.v4(),
        librarySymbolId: librarySymbolId,
        categoryId: category.id,
        backgroundColor: backgroundColor,
        position: i,
        createdAt: now,
        updatedAt: now,
      );
      categorySymbols.add(categorySymbol);
      print('➕ Dodaję symbol "$symbolName" do kategorii "${category.name}"');
    }

    return (librarySymbols, categorySymbols);
  }

  /// Tworzy domyślne symbole dla wszystkich kategorii
  static Future<(List<LibrarySymbolModel>, List<CategorySymbolModel>)>
  createDefaultSymbolsForAllCategories(
      List<CategoryModel> categories,
      Future<List<LibrarySymbolModel>> Function() getExistingSymbols,
      Future<List<CategorySymbolModel>> Function(String categoryId) getExistingCategorySymbols,
      ) async {

    final allLibrarySymbols = <LibrarySymbolModel>[];
    final allCategorySymbols = <CategorySymbolModel>[];

    for (final category in categories) {
      final (librarySymbols, categorySymbols) =
      await createDefaultSymbolsForCategory(
        category,
        getExistingSymbols,
        getExistingCategorySymbols,
      );

      allLibrarySymbols.addAll(librarySymbols);
      allCategorySymbols.addAll(categorySymbols);
    }

    return (allLibrarySymbols, allCategorySymbols);
  }
}