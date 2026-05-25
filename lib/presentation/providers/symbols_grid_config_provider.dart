import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../data/models/category_model.dart';

part 'symbols_grid_config_provider.g.dart';

// Model dla konfiguracji siatki symboli
class SymbolsGridConfig {
  final int columns;
  final int rows;

  const SymbolsGridConfig({
    this.columns = 3,
    this.rows = 4,
  });

  SymbolsGridConfig copyWith({
    int? columns,
    int? rows,
  }) {
    return SymbolsGridConfig(
      columns: columns ?? this.columns,
      rows: rows ?? this.rows,
    );
  }

  // JSON serialization
  Map<String, dynamic> toJson() => {
    'columns': columns,
    'rows': rows,
  };

  factory SymbolsGridConfig.fromJson(Map<String, dynamic> json) {
    return SymbolsGridConfig(
      columns: json['columns'] as int,
      rows: json['rows'] as int,
    );
  }
}

// SharedPreferences provider
@Riverpod(keepAlive: true)
Future<SharedPreferences> sharedPreferences(Ref ref) async {
  return await SharedPreferences.getInstance();
}

// Provider przechowujący konfiguracje siatki dla każdej kategorii
// Klucz: categoryId, Wartość: SymbolsGridConfig
@riverpod
class SymbolsGridConfigs extends _$SymbolsGridConfigs {
  static const String _storageKey = 'symbols_grid_configs';

  @override
  Map<String, SymbolsGridConfig> build() {
    _loadFromStorage();
    return {};
  }

  // Ładuj z SharedPreferences
  Future<void> _loadFromStorage() async {
    try {
      final prefs = await ref.read(sharedPreferencesProvider.future);
      final jsonString = prefs.getString(_storageKey);

      if (jsonString != null) {
        final Map<String, dynamic> decoded = json.decode(jsonString);
        final configs = <String, SymbolsGridConfig>{};

        decoded.forEach((categoryId, configJson) {
          configs[categoryId] = SymbolsGridConfig.fromJson(configJson);
        });

        state = configs;
        print('✅ Załadowano ${configs.length} konfiguracji siatki');
      }
    } catch (e) {
      print('⚠️ Błąd ładowania konfiguracji: $e');
    }
  }

  // Zapisz do SharedPreferences
  Future<void> _saveToStorage() async {
    try {
      final prefs = await ref.read(sharedPreferencesProvider.future);
      final encoded = <String, dynamic>{};

      state.forEach((categoryId, config) {
        encoded[categoryId] = config.toJson();
      });

      await prefs.setString(_storageKey, json.encode(encoded));
      print('💾 Zapisano ${state.length} konfiguracji siatki');
    } catch (e) {
      print('⚠️ Błąd zapisywania konfiguracji: $e');
    }
  }

  // Pobierz konfigurację dla kategorii (lub domyślną)
  SymbolsGridConfig getConfig(String categoryId, GridConfig defaultFromCategory) {
    return state[categoryId] ?? SymbolsGridConfig(
      columns: defaultFromCategory.columns,
      rows: defaultFromCategory.rows,
    );
  }

  // Ustaw konfigurację dla kategorii
  Future<void> setConfig(String categoryId, SymbolsGridConfig config) async {
    state = {
      ...state,
      categoryId: config,
    };
    await _saveToStorage();
    print('✅ Zapisano siatkę dla $categoryId: ${config.columns}x${config.rows}');
  }

  // Resetuj do domyślnej z kategorii
  Future<void> resetConfig(String categoryId) async {
    final newState = {...state};
    newState.remove(categoryId);
    state = newState;
    await _saveToStorage();
    print('🔄 Zresetowano siatkę dla $categoryId');
  }
}