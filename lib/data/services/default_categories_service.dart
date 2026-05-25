import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../models/category_model.dart';

class DefaultCategoriesService {
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

  /// Tworzy domyślne kategorie dla nowego profilu
  static Future<List<CategoryModel>> createDefaultCategories(String profileId) async {
    final now = DateTime.now();
    List<CategoryModel> categories = [];
    int position = 0;

    // ========== GŁÓWNE KATEGORIE ==========
    final mainCategoryConfigs = [
      {
        'name': 'Potrzeby',
        'icon': 'potrzeby-folder.png',
        'color': 0xFFFFCDD2, // Red 100
        'textColor': 0xFFB71C1C,
        'iconColor': 0xFFD32F2F,
      },
      {
        'name': 'Emocje i uczucia',
        'icon': 'emocje-folder.png',
        'color': 0xFFFFF9C4, // Yellow 100
        'textColor': 0xFFF57F17,
        'iconColor': 0xFFFBC02D,
      },
      {
        'name': 'Komunikacja podstawowa',
        'icon': 'komunikacja_folder.png',
        'color': 0xFFC8E6C9, // Green 100
        'textColor': 0xFF1B5E20,
        'iconColor': 0xFF388E3C,
      },
      {
        'name': 'Czynności/Aktywności',
        'icon': 'czynnosci-folder.png',
        'color': 0xFFE1BEE7, // Purple 100
        'textColor': 0xFF4A148C,
        'iconColor': 0xFF7B1FA2,
      },
      {
        'name': 'Części ciała',
        'icon': 'czesci-ciala-folder.png',
        'color': 0xFFFFE0B2, // Orange 100
        'textColor': 0xFFE65100,
        'iconColor': 0xFFF57C00,
      },
      {
        'name': 'Osoby',
        'icon': 'osoby.png',
        'color': 0xFFD7CCC8, // Brown 100
        'textColor': 0xFF3E2723,
        'iconColor': 0xFF5D4037,
      },
      {
        'name': 'Pory roku/Pogoda',
        'icon': 'pogoda-folder.png',
        'color': 0xFFB2EBF2, // Cyan 100
        'textColor': 0xFF006064,
        'iconColor': 0xFF00838F,
      },
      {
        'name': 'Przedmioty',
        'icon': 'przedmioty-folder.png',
        'color': 0xFFD1C4E9, // Deep Purple 100
        'textColor': 0xFF311B92,
        'iconColor': 0xFF512DA8,
      },
    ];

    // Mapa do przechowywania ID kategorii głównych (potrzebne dla podkategorii)
    final Map<String, String> mainCategoryIds = {};

    for (final config in mainCategoryConfigs) {
      final id = _uuid.v4();
      final name = config['name'] as String;
      mainCategoryIds[name] = id;

      final iconPath = await _copyAssetToLocal(
        'assets/category_icons/${config['icon']}',
      );

      categories.add(
        CategoryModel(
          id: id,
          name: name,
          iconPath: iconPath.isNotEmpty ? iconPath : null,
          backgroundColor: config['color'] as int,
          textColor: config['textColor'] as int,
          iconColor: config['iconColor'] as int,
          communicationMode: CommunicationMode.text,
          gridConfig: GridConfig(columns: 3, rows: 4),
          scrollLocked: false,
          position: position++,
          profileId: profileId,
          parentId: null, // Kategoria główna
          createdAt: now,
          updatedAt: now,
        ),
      );
    }

    // ========== PODKATEGORIE: Czynności/Aktywności ==========
    final czynnosciSubcategories = [
      {
        'name': 'Ruch',
        'icon': 'ruch-folder.png',
        'color': 0xFFB3E5FC, // Light Blue 100
        'textColor': 0xFF01579B,
        'iconColor': 0xFF0288D1,
      },
      {
        'name': 'Akcje',
        'icon': 'Akcje-folder.png',
        'color': 0xFFFFCCBC, // Deep Orange 100
        'textColor': 0xFFBF360C,
        'iconColor': 0xFFE64A19,
      },
    ];

    final czynnosciParentId = mainCategoryIds['Czynności/Aktywności']!;
    int czynnosciSubPosition = 0;

    for (final config in czynnosciSubcategories) {
      final id = _uuid.v4();
      final name = config['name'] as String;
      mainCategoryIds[name] = id; // Zapisz ID dla symboli

      final iconPath = await _copyAssetToLocal(
        'assets/category_icons/${config['icon']}',
      );

      categories.add(
        CategoryModel(
          id: id,
          name: name,
          iconPath: iconPath.isNotEmpty ? iconPath : null,
          backgroundColor: config['color'] as int,
          textColor: config['textColor'] as int,
          iconColor: config['iconColor'] as int,
          communicationMode: CommunicationMode.text,
          gridConfig: GridConfig(columns: 3, rows: 4),
          scrollLocked: false,
          position: czynnosciSubPosition++,
          profileId: profileId,
          parentId: czynnosciParentId, // Podkategoria Czynności
          createdAt: now,
          updatedAt: now,
        ),
      );
    }

    // ========== PODKATEGORIE: Przedmioty ==========
    final przedmiotySubcategories = [
      {
        'name': 'Meble',
        'icon': 'meble-folder.png',
        'color': 0xFFBCAAA4, // Brown 200
        'textColor': 0xFF4E342E,
        'iconColor': 0xFF6D4C41,
      },
      {
        'name': 'Naczynia',
        'icon': 'naczynia-folder.png',
        'color': 0xFFB2DFDB, // Teal 100
        'textColor': 0xFF004D40,
        'iconColor': 0xFF00796B,
      },
      {
        'name': 'Zabawki',
        'icon': 'zabawki-folder.png',
        'color': 0xFFF8BBD9, // Pink 100
        'textColor': 0xFF880E4F,
        'iconColor': 0xFFC2185B,
      },
      {
        'name': 'Przybory',
        'icon': 'przybory-folder.png',
        'color': 0xFFFFE082, // Amber 200
        'textColor': 0xFFFF6F00,
        'iconColor': 0xFFFFA000,
      },
    ];

    final przedmiotyParentId = mainCategoryIds['Przedmioty']!;
    int przedmiotySubPosition = 0;

    for (final config in przedmiotySubcategories) {
      final id = _uuid.v4();
      final name = config['name'] as String;
      mainCategoryIds[name] = id; // Zapisz ID dla symboli

      final iconPath = await _copyAssetToLocal(
        'assets/category_icons/${config['icon']}',
      );

      categories.add(
        CategoryModel(
          id: id,
          name: name,
          iconPath: iconPath.isNotEmpty ? iconPath : null,
          backgroundColor: config['color'] as int,
          textColor: config['textColor'] as int,
          iconColor: config['iconColor'] as int,
          communicationMode: CommunicationMode.text,
          gridConfig: GridConfig(columns: 3, rows: 4),
          scrollLocked: false,
          position: przedmiotySubPosition++,
          profileId: profileId,
          parentId: przedmiotyParentId, // Podkategoria Przedmioty
          createdAt: now,
          updatedAt: now,
        ),
      );
    }

    return categories;
  }
}