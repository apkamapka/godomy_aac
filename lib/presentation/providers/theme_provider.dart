import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/services/app_settings.dart';

/// Motyw (systemowy / jasny / ciemny). Odczyt synchroniczny z ustawień
/// wczytanych w `main()` – bez mignięcia złym motywem przy starcie.
final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  return ThemeModeNotifier(ref.watch(appPrefsProvider));
});

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  static const _key = 'isDarkMode';
  final SharedPreferences _prefs;

  ThemeModeNotifier(this._prefs) : super(_read(_prefs));

  static ThemeMode _read(SharedPreferences prefs) {
    final isDark = prefs.getBool(_key);
    if (isDark == null) return ThemeMode.system;
    return isDark ? ThemeMode.dark : ThemeMode.light;
  }

  Future<void> toggleTheme() =>
      setThemeMode(state == ThemeMode.light ? ThemeMode.dark : ThemeMode.light);

  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    if (mode == ThemeMode.system) {
      await _prefs.remove(_key);
    } else {
      await _prefs.setBool(_key, mode == ThemeMode.dark);
    }
  }
}
