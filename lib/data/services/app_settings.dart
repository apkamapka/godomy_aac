import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// SharedPreferences wczytane raz w `main()` i podane przez override –
/// dzięki temu ustawienia są dostępne synchronicznie w całej aplikacji.
final appPrefsProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('appPrefsProvider musi być nadpisany w main()');
});

// ============================================================
// Ustawienia urządzenia (wspólne dla wszystkich profili)
// ============================================================

/// Sposób odblokowania trybu opiekuna.
enum LockMethod {
  /// Działanie matematyczne do rozwiązania.
  math,

  /// 4-cyfrowy PIN.
  pin,

  /// Przytrzymanie kłódki przez 3 sekundy.
  hold,
}

class AppSettings {
  final LockMethod lockMethod;
  final String? pinHash;
  final bool haptics;
  final String? lastProfileId;
  final bool onboardingDone;

  const AppSettings({
    required this.lockMethod,
    required this.pinHash,
    required this.haptics,
    required this.lastProfileId,
    required this.onboardingDone,
  });

  bool get hasPin => pinHash != null && pinHash!.isNotEmpty;
}

class AppSettingsNotifier extends Notifier<AppSettings> {
  static const _kLock = 'lock_method';
  static const _kPin = 'lock_pin_hash';
  static const _kHaptics = 'haptics';
  static const _kLastProfile = 'last_profile_id';
  static const _kOnboarding = 'onboarding_done';

  SharedPreferences get _prefs => ref.read(appPrefsProvider);

  @override
  AppSettings build() {
    final prefs = ref.watch(appPrefsProvider);
    final lockName = prefs.getString(_kLock);
    return AppSettings(
      lockMethod: LockMethod.values.firstWhere(
        (m) => m.name == lockName,
        orElse: () => LockMethod.math,
      ),
      pinHash: prefs.getString(_kPin),
      haptics: prefs.getBool(_kHaptics) ?? true,
      lastProfileId: prefs.getString(_kLastProfile),
      onboardingDone: prefs.getBool(_kOnboarding) ?? false,
    );
  }

  AppSettings _copy({
    LockMethod? lockMethod,
    String? pinHash,
    bool clearPin = false,
    bool? haptics,
    String? lastProfileId,
    bool clearLastProfile = false,
    bool? onboardingDone,
  }) {
    return AppSettings(
      lockMethod: lockMethod ?? state.lockMethod,
      pinHash: clearPin ? null : (pinHash ?? state.pinHash),
      haptics: haptics ?? state.haptics,
      lastProfileId: clearLastProfile ? null : (lastProfileId ?? state.lastProfileId),
      onboardingDone: onboardingDone ?? state.onboardingDone,
    );
  }

  Future<void> setLockMethod(LockMethod method) async {
    state = _copy(lockMethod: method);
    await _prefs.setString(_kLock, method.name);
  }

  Future<void> setPin(String pin) async {
    final hash = hashPin(pin);
    state = _copy(pinHash: hash);
    await _prefs.setString(_kPin, hash);
  }

  Future<void> clearPin() async {
    state = _copy(clearPin: true);
    await _prefs.remove(_kPin);
  }

  bool checkPin(String pin) => state.hasPin && state.pinHash == hashPin(pin);

  Future<void> setHaptics(bool value) async {
    state = _copy(haptics: value);
    await _prefs.setBool(_kHaptics, value);
  }

  Future<void> setLastProfile(String profileId) async {
    if (state.lastProfileId == profileId) return;
    state = _copy(lastProfileId: profileId);
    await _prefs.setString(_kLastProfile, profileId);
  }

  Future<void> clearLastProfile() async {
    state = _copy(clearLastProfile: true);
    await _prefs.remove(_kLastProfile);
  }

  Future<void> setOnboardingDone() async {
    state = _copy(onboardingDone: true);
    await _prefs.setBool(_kOnboarding, true);
  }

  /// Prosty skrót PIN-u (to blokada przed dzieckiem, nie zabezpieczenie danych).
  static String hashPin(String pin) {
    // FNV-1a 32-bit.
    var hash = 0x811c9dc5;
    for (final unit in 'godomy-pin:$pin'.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    return hash.toRadixString(16);
  }
}

final appSettingsProvider =
    NotifierProvider<AppSettingsNotifier, AppSettings>(AppSettingsNotifier.new);

// ============================================================
// Ustawienia profilu (każde dziecko może mieć inne)
// ============================================================

class ProfileSettings {
  // --- Tablica ---------------------------------------------------------------

  /// Czy mówić słowo od razu po dotknięciu kafelka.
  final bool speakOnTap;

  /// Czy pokazywać pasek zdania (u góry tablicy).
  final bool showSentenceBar;

  /// Czy pokazywać słowa kluczowe na tablicy startowej.
  final bool showCoreWords;

  // --- Funkcje (każde dziecko jest inne – każdą można wyłączyć) ---------------

  final bool showUrgent;
  final bool showFrequent;
  final bool showSchedule;
  final bool showYesNo;

  /// „Moje zdania” + historia wypowiedzianych zdań.
  final bool showSentences;

  /// Przycisk „Pokaż” – zdanie na cały ekran dla rozmówcy.
  final bool showToPartner;

  /// Zdjęcie profilu zamiast obrazka na kafelku „ja”.
  final bool jaPhoto;

  /// Animacje (wlatywanie obrazka, wciskanie kafelka).
  final bool animations;

  // --- Dostępność -------------------------------------------------------------

  /// Kafelek działa dopiero po przytrzymaniu (ms). 0 = zwykłe dotknięcie.
  final int holdMs;

  /// Przez tyle ms po wybraniu kafelka kolejne dotknięcia są ignorowane.
  final int repeatGuardMs;

  /// Skanowanie: kafelki podświetlają się po kolei, dotyk ekranu wybiera.
  final bool scanning;
  final int scanIntervalMs;

  const ProfileSettings({
    this.speakOnTap = true,
    this.showSentenceBar = true,
    this.showCoreWords = true,
    this.showUrgent = true,
    this.showFrequent = true,
    this.showSchedule = true,
    this.showYesNo = true,
    this.showSentences = true,
    this.showToPartner = true,
    this.jaPhoto = true,
    this.animations = true,
    this.holdMs = 0,
    this.repeatGuardMs = 0,
    this.scanning = false,
    this.scanIntervalMs = 1500,
  });

  ProfileSettings copyWith({
    bool? speakOnTap,
    bool? showSentenceBar,
    bool? showCoreWords,
    bool? showUrgent,
    bool? showFrequent,
    bool? showSchedule,
    bool? showYesNo,
    bool? showSentences,
    bool? showToPartner,
    bool? jaPhoto,
    bool? animations,
    int? holdMs,
    int? repeatGuardMs,
    bool? scanning,
    int? scanIntervalMs,
  }) {
    return ProfileSettings(
      speakOnTap: speakOnTap ?? this.speakOnTap,
      showSentenceBar: showSentenceBar ?? this.showSentenceBar,
      showCoreWords: showCoreWords ?? this.showCoreWords,
      showUrgent: showUrgent ?? this.showUrgent,
      showFrequent: showFrequent ?? this.showFrequent,
      showSchedule: showSchedule ?? this.showSchedule,
      showYesNo: showYesNo ?? this.showYesNo,
      showSentences: showSentences ?? this.showSentences,
      showToPartner: showToPartner ?? this.showToPartner,
      jaPhoto: jaPhoto ?? this.jaPhoto,
      animations: animations ?? this.animations,
      holdMs: holdMs ?? this.holdMs,
      repeatGuardMs: repeatGuardMs ?? this.repeatGuardMs,
      scanning: scanning ?? this.scanning,
      scanIntervalMs: scanIntervalMs ?? this.scanIntervalMs,
    );
  }

  Map<String, dynamic> toJson() => {
        'speakOnTap': speakOnTap,
        'showSentenceBar': showSentenceBar,
        'showCoreWords': showCoreWords,
        'showUrgent': showUrgent,
        'showFrequent': showFrequent,
        'showSchedule': showSchedule,
        'showYesNo': showYesNo,
        'showSentences': showSentences,
        'showToPartner': showToPartner,
        'jaPhoto': jaPhoto,
        'animations': animations,
        'holdMs': holdMs,
        'repeatGuardMs': repeatGuardMs,
        'scanning': scanning,
        'scanIntervalMs': scanIntervalMs,
      };

  factory ProfileSettings.fromJson(Map<String, dynamic> json) {
    bool b(String key, bool fallback) => json[key] as bool? ?? fallback;
    int i(String key, int fallback) => (json[key] as num?)?.toInt() ?? fallback;
    return ProfileSettings(
      speakOnTap: b('speakOnTap', true),
      showSentenceBar: b('showSentenceBar', true),
      showCoreWords: b('showCoreWords', true),
      showUrgent: b('showUrgent', true),
      showFrequent: b('showFrequent', true),
      showSchedule: b('showSchedule', true),
      showYesNo: b('showYesNo', true),
      showSentences: b('showSentences', true),
      showToPartner: b('showToPartner', true),
      jaPhoto: b('jaPhoto', true),
      animations: b('animations', true),
      holdMs: i('holdMs', 0).clamp(0, 3000),
      repeatGuardMs: i('repeatGuardMs', 0).clamp(0, 5000),
      scanning: b('scanning', false),
      scanIntervalMs: i('scanIntervalMs', 1500).clamp(500, 6000),
    );
  }
}

class ProfileSettingsNotifier extends FamilyNotifier<ProfileSettings, String> {
  static String keyFor(String profileId) => 'profile_settings_$profileId';

  @override
  ProfileSettings build(String arg) {
    final prefs = ref.watch(appPrefsProvider);
    final raw = prefs.getString(keyFor(arg));
    if (raw == null) return const ProfileSettings();
    try {
      return ProfileSettings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return const ProfileSettings();
    }
  }

  Future<void> update(ProfileSettings settings) async {
    state = settings;
    await ref.read(appPrefsProvider).setString(keyFor(arg), jsonEncode(settings.toJson()));
  }
}

final profileSettingsProvider =
    NotifierProvider.family<ProfileSettingsNotifier, ProfileSettings, String>(
  ProfileSettingsNotifier.new,
);

/// Aktualnie używany profil (ostatnio otwarta tablica).
final activeProfileIdProvider = Provider<String?>(
  (ref) => ref.watch(appSettingsProvider.select((s) => s.lastProfileId)),
);

/// Ustawienia aktualnego profilu – dla widżetów, które nie znają profilu
/// (np. kafelek: przytrzymanie, animacje).
final activeProfileSettingsProvider = Provider<ProfileSettings>((ref) {
  final id = ref.watch(activeProfileIdProvider);
  if (id == null) return const ProfileSettings();
  return ref.watch(profileSettingsProvider(id));
});

/// Ochrona przed przypadkowym, wielokrotnym dotknięciem.
class TouchGuard {
  DateTime? _last;

  /// Czy wolno teraz aktywować kafelek/przycisk. Zapamiętuje czas aktywacji.
  bool tryActivate(int guardMs) {
    final now = DateTime.now();
    final last = _last;
    if (guardMs > 0 && last != null && now.difference(last).inMilliseconds < guardMs) {
      return false;
    }
    _last = now;
    return true;
  }
}

final touchGuardProvider = Provider<TouchGuard>((ref) => TouchGuard());

// ============================================================
// Statystyki użycia (ekran „Częste”) i postęp planu dnia
// ============================================================

/// Liczy dotknięcia symboli osobno dla każdego profilu.
class UsageStore {
  final SharedPreferences _prefs;
  UsageStore(this._prefs);

  static String _key(String profileId) => 'usage_$profileId';

  Map<String, int> read(String profileId) {
    final raw = _prefs.getString(_key(profileId));
    if (raw == null) return {};
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return decoded.map((k, v) => MapEntry(k, (v as num).toInt()));
    } catch (_) {
      return {};
    }
  }

  Future<void> increment(String profileId, String categorySymbolId) async {
    final map = read(profileId);
    map[categorySymbolId] = (map[categorySymbolId] ?? 0) + 1;
    // Nie trzymamy w nieskończoność rzadko używanych – max 200 wpisów.
    if (map.length > 200) {
      final sorted = map.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
      map
        ..clear()
        ..addEntries(sorted.take(150));
    }
    await _prefs.setString(_key(profileId), jsonEncode(map));
  }

  /// Id symboli posortowane od najczęściej używanych.
  List<String> top(String profileId, {int limit = 24}) {
    final entries = read(profileId).entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries.take(limit).map((e) => e.key).toList();
  }

  Future<void> clear(String profileId) => _prefs.remove(_key(profileId));
}

final usageStoreProvider = Provider<UsageStore>((ref) => UsageStore(ref.watch(appPrefsProvider)));

/// Które kroki planu dnia są już zrobione – zapisywane na dany dzień,
/// następnego dnia plan zaczyna się od nowa.
class ScheduleProgressStore {
  final SharedPreferences _prefs;
  ScheduleProgressStore(this._prefs);

  static String _key(String profileId) => 'schedule_progress_$profileId';

  static String _today() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  Set<String> doneToday(String profileId) {
    final raw = _prefs.getString(_key(profileId));
    if (raw == null) return {};
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      if (decoded['date'] != _today()) return {};
      return (decoded['done'] as List).cast<String>().toSet();
    } catch (_) {
      return {};
    }
  }

  Future<void> save(String profileId, Set<String> done) async {
    await _prefs.setString(
      _key(profileId),
      jsonEncode({'date': _today(), 'done': done.toList()}),
    );
  }

  Future<void> reset(String profileId) => _prefs.remove(_key(profileId));
}

final scheduleProgressProvider =
    Provider<ScheduleProgressStore>((ref) => ScheduleProgressStore(ref.watch(appPrefsProvider)));
