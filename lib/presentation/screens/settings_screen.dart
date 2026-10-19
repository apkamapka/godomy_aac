import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_links.dart';
import '../../core/l10n/app_localizations.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/url_helper.dart';
import '../../data/models/profile_model.dart';
import '../../data/repositories/profile_repository.dart';
import '../../data/services/app_settings.dart';
import '../../data/services/default_content_service.dart';
import '../../data/services/tts_service.dart';
import '../providers/backup_provider.dart';
import '../providers/board_provider.dart';
import '../providers/theme_provider.dart';
import '../widgets/app_drawer.dart';
import '../widgets/app_sheet.dart';
import '../widgets/caregiver_lock.dart';

/// Ustawienia: tryb opiekuna, mowa, tablica, urządzenie, dane, informacje.
class SettingsScreen extends ConsumerWidget {
  final String profileId;
  const SettingsScreen({super.key, required this.profileId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final profile = ref.watch(profileProvider(profileId)).valueOrNull;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settings)),
      body: ListView(
        padding: EdgeInsets.fromLTRB(16, 0, 16, 32 + MediaQuery.paddingOf(context).bottom),
        children: [
          SectionTitle(l10n.settingsFeatures(profile?.name ?? '')),
          _FeatureSettings(profileId: profileId),
          SectionTitle(l10n.settingsAccessibility),
          _AccessibilitySettings(profileId: profileId),
          SectionTitle(l10n.settingsSpeech),
          if (profile != null) _VoiceSettings(profile: profile) else const _LoadingCard(),
          SectionTitle(l10n.settingsCaregiver),
          _LockMethodPicker(),
          SectionTitle(l10n.settingsDevice),
          const _DeviceSettings(),
          SectionTitle(l10n.settingsData),
          _DataSettings(profileId: profileId),
          SectionTitle(l10n.about),
          const _AboutCard(),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Karty pomocnicze
// -----------------------------------------------------------------------------

class _Card extends StatelessWidget {
  final List<Widget> children;
  const _Card({required this.children});

  @override
  Widget build(BuildContext context) {
    final palette = context.aac;
    return Container(
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: palette.line, width: 1.5),
      ),
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(children: children),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    return const _Card(children: [
      Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      ),
    ]);
  }
}

class _IconBox extends StatelessWidget {
  final IconData icon;
  final Color color;
  const _IconBox(this.icon, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: color, size: 22),
    );
  }
}

// -----------------------------------------------------------------------------
// Tryb opiekuna
// -----------------------------------------------------------------------------

class _LockMethodPicker extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final settings = ref.watch(appSettingsProvider);

    Future<void> select(LockMethod method) async {
      final notifier = ref.read(appSettingsProvider.notifier);
      if (method == LockMethod.pin && !ref.read(appSettingsProvider).hasPin) {
        final saved = await setNewPin(context, ref);
        if (!saved) return;
      }
      await notifier.setLockMethod(method);
    }

    Widget option(LockMethod method, IconData icon, String title, String subtitle) {
      final selected = settings.lockMethod == method;
      return ListTile(
        onTap: () => select(method),
        leading: _IconBox(icon, selected ? AppColors.sky : context.aac.inkSoft),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: Icon(
          selected ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded,
          color: selected ? AppColors.sky : context.aac.inkSoft,
        ),
      );
    }

    return _Card(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
        child: Text(
          l10n.lockExplain,
          style: TextStyle(color: context.aac.inkSoft, fontWeight: FontWeight.w600),
        ),
      ),
      option(LockMethod.math, Icons.calculate_rounded, l10n.lockMath, l10n.lockMathDesc),
      option(LockMethod.pin, Icons.pin_rounded, l10n.lockPin, l10n.lockPinDesc),
      option(LockMethod.hold, Icons.touch_app_rounded, l10n.lockHold, l10n.lockHoldDesc),
      if (settings.lockMethod == LockMethod.pin)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
          child: OutlinedButton.icon(
            onPressed: () async {
              final saved = await setNewPin(context, ref);
              if (saved && context.mounted) showToast(context, l10n.pinSaved);
            },
            icon: const Icon(Icons.password_rounded),
            label: Text(l10n.pinChange),
          ),
        ),
    ]);
  }
}

// -----------------------------------------------------------------------------
// Mowa (zapisywana w profilu)
// -----------------------------------------------------------------------------

class _VoiceSettings extends ConsumerStatefulWidget {
  final ProfileModel profile;
  const _VoiceSettings({required this.profile});

  @override
  ConsumerState<_VoiceSettings> createState() => _VoiceSettingsState();
}

class _VoiceSettingsState extends ConsumerState<_VoiceSettings> {
  late double _rate = widget.profile.ttsRate;
  late double _pitch = widget.profile.ttsPitch;
  late String? _voice = widget.profile.ttsVoiceId;
  late String _locale = widget.profile.ttsLanguage;
  List<Map<String, String>>? _voices;

  @override
  void initState() {
    super.initState();
    _loadVoices();
  }

  Future<void> _loadVoices() async {
    final voices = await ref.read(ttsServiceProvider).getPolishVoices();
    if (mounted) setState(() => _voices = voices);
  }

  Future<void> _save() async {
    final tts = ref.read(ttsServiceProvider);
    final repoFuture = ref.read(profileRepositoryProvider.future);
    await tts.applySettings(voiceName: _voice, voiceLocale: _locale, rate: _rate, pitch: _pitch);
    final repo = await repoFuture;
    final fresh = await repo.getById(widget.profile.id) ?? widget.profile;
    await repo.update(fresh.copyWith(
      ttsVoiceId: _voice,
      ttsLanguage: _locale,
      ttsRate: _rate,
      ttsPitch: _pitch,
      updatedAt: DateTime.now(),
    ));
  }

  String _voiceLabel(int index, Map<String, String> voice) {
    final l10n = AppLocalizations.of(context)!;
    final name = voice['name'] ?? '';
    final online = name.toLowerCase().contains('network');
    return '${l10n.voice} ${index + 1}${online ? ' · ${l10n.voiceOnline}' : ''}';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final palette = context.aac;
    final voices = _voices;

    return _Card(children: [
      ListTile(
        leading: const _IconBox(Icons.record_voice_over_rounded, AppColors.sky),
        title: Text(l10n.voice),
        subtitle: Text(
          voices == null
              ? l10n.loading
              : (voices.isEmpty ? l10n.voiceNone : l10n.voiceCount(voices.length)),
        ),
      ),
      if (voices != null && voices.isNotEmpty)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: Text(l10n.voiceDefault),
                selected: _voice == null,
                onSelected: (_) {
                  setState(() {
                    _voice = null;
                    _locale = 'pl-PL';
                  });
                  _save();
                },
              ),
              for (var i = 0; i < voices.length; i++)
                ChoiceChip(
                  label: Text(_voiceLabel(i, voices[i])),
                  selected: _voice == voices[i]['name'],
                  onSelected: (_) {
                    setState(() {
                      _voice = voices[i]['name'];
                      _locale = voices[i]['locale'] ?? 'pl-PL';
                    });
                    _save().then((_) => ref.read(ttsServiceProvider).testVoice());
                  },
                ),
            ],
          ),
        ),
      const Divider(height: 8, indent: 16, endIndent: 16),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: Row(
          children: [
            Text(l10n.speechRate, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            const Spacer(),
            Text(l10n.speechRateValue((_rate * 100).round()), style: TextStyle(color: palette.inkSoft, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
      Slider(
        value: _rate.clamp(0.2, 1.0),
        min: 0.2,
        max: 1.0,
        divisions: 16,
        onChanged: (v) => setState(() => _rate = v),
        onChangeEnd: (_) => _save(),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
        child: Row(
          children: [
            Text(l10n.speechPitch, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            const Spacer(),
            Text(_pitch.toStringAsFixed(1), style: TextStyle(color: palette.inkSoft, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
      Slider(
        value: _pitch.clamp(0.5, 2.0),
        min: 0.5,
        max: 2.0,
        divisions: 15,
        onChanged: (v) => setState(() => _pitch = v),
        onChangeEnd: (_) => _save(),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () async {
              await _save();
              await ref.read(ttsServiceProvider).testVoice();
            },
            icon: const Icon(Icons.play_arrow_rounded),
            label: Text(l10n.voiceTest),
          ),
        ),
      ),
    ]);
  }
}

// -----------------------------------------------------------------------------
// Funkcje (ustawienia profilu – każde dziecko jest inne)
// -----------------------------------------------------------------------------

class _FeatureSettings extends ConsumerWidget {
  final String profileId;
  const _FeatureSettings({required this.profileId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final s = ref.watch(profileSettingsProvider(profileId));
    final notifier = ref.read(profileSettingsProvider(profileId).notifier);

    Widget toggle(IconData icon, Color color, String title, String subtitle, bool value, ProfileSettings Function(bool v) apply) {
      return SwitchListTile(
        secondary: _IconBox(icon, color),
        title: Text(title),
        subtitle: Text(subtitle),
        value: value,
        onChanged: (v) => notifier.update(apply(v)),
      );
    }

    return _Card(children: [
      ListTile(
        leading: const _IconBox(Icons.person_rounded, AppColors.coral),
        title: Text(l10n.editProfile),
        subtitle: Text(l10n.editProfileDesc),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () => context.push('/profile-editor?id=$profileId'),
      ),
      const Divider(height: 8, indent: 16, endIndent: 16),
      toggle(Icons.chat_bubble_rounded, AppColors.grape, l10n.showSentenceBar, l10n.showSentenceBarDesc,
          s.showSentenceBar, (v) => s.copyWith(showSentenceBar: v)),
      toggle(Icons.volume_up_rounded, AppColors.sky, l10n.speakOnTap, l10n.speakOnTapDesc,
          s.speakOnTap, (v) => s.copyWith(speakOnTap: v)),
      toggle(Icons.view_module_rounded, AppColors.leaf, l10n.showCoreWords, l10n.showCoreWordsDesc,
          s.showCoreWords, (v) => s.copyWith(showCoreWords: v)),
      toggle(Icons.back_hand_rounded, AppColors.coral, l10n.featureUrgent, l10n.featureUrgentDesc,
          s.showUrgent, (v) => s.copyWith(showUrgent: v)),
      toggle(Icons.thumbs_up_down_rounded, AppColors.leaf, l10n.yesNo, l10n.featureYesNoDesc,
          s.showYesNo, (v) => s.copyWith(showYesNo: v)),
      toggle(Icons.forum_rounded, AppColors.grape, l10n.featureSentences, l10n.featureSentencesDesc,
          s.showSentences, (v) => s.copyWith(showSentences: v)),
      toggle(Icons.open_in_full_rounded, AppColors.sky, l10n.featureShowToPartner, l10n.featureShowToPartnerDesc,
          s.showToPartner, (v) => s.copyWith(showToPartner: v)),
      toggle(Icons.star_rounded, AppColors.sunDeep, l10n.frequent, l10n.featureFrequentDesc,
          s.showFrequent, (v) => s.copyWith(showFrequent: v)),
      toggle(Icons.event_note_rounded, AppColors.sky, l10n.schedule, l10n.featureScheduleDesc,
          s.showSchedule, (v) => s.copyWith(showSchedule: v)),
      toggle(Icons.face_rounded, AppColors.coral, l10n.featureJaPhoto, l10n.featureJaPhotoDesc,
          s.jaPhoto, (v) => s.copyWith(jaPhoto: v)),
      toggle(Icons.animation_rounded, AppColors.grape, l10n.featureAnimations, l10n.featureAnimationsDesc,
          s.animations, (v) => s.copyWith(animations: v)),
    ]);
  }
}

// -----------------------------------------------------------------------------
// Dostępność (ustawienia profilu)
// -----------------------------------------------------------------------------

/// „0,3 s”, „1 s” – sekundy po polsku.
String _seconds(int ms) {
  final value = ms / 1000;
  final text = ms % 1000 == 0
      ? value.toStringAsFixed(0)
      : (ms % 100 == 0 ? value.toStringAsFixed(1) : value.toStringAsFixed(2));
  return '${text.replaceAll('.', ',')} s';
}

class _AccessibilitySettings extends ConsumerWidget {
  final String profileId;
  const _AccessibilitySettings({required this.profileId});

  static const _holdOptions = [0, 300, 600, 1000];
  static const _guardOptions = [0, 500, 1000, 2000];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final palette = context.aac;
    final s = ref.watch(profileSettingsProvider(profileId));
    final notifier = ref.read(profileSettingsProvider(profileId).notifier);

    Widget choices(List<int> options, int selected, ValueChanged<int> onSelected) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final o in options)
              ChoiceChip(
                label: Text(o == 0 ? l10n.off : _seconds(o)),
                selected: selected == o,
                onSelected: (_) => onSelected(o),
              ),
          ],
        ),
      );
    }

    return _Card(children: [
      ListTile(
        leading: const _IconBox(Icons.touch_app_rounded, AppColors.sky),
        title: Text(l10n.holdToActivate),
        subtitle: Text(l10n.holdToActivateDesc),
      ),
      choices(_holdOptions, _holdOptions.contains(s.holdMs) ? s.holdMs : 0,
          (v) => notifier.update(s.copyWith(holdMs: v))),
      ListTile(
        leading: const _IconBox(Icons.do_not_touch_rounded, AppColors.coral),
        title: Text(l10n.repeatGuard),
        subtitle: Text(l10n.repeatGuardDesc),
      ),
      choices(_guardOptions, _guardOptions.contains(s.repeatGuardMs) ? s.repeatGuardMs : 0,
          (v) => notifier.update(s.copyWith(repeatGuardMs: v))),
      const Divider(height: 8, indent: 16, endIndent: 16),
      SwitchListTile(
        secondary: const _IconBox(Icons.switch_access_shortcut_rounded, AppColors.grape),
        title: Text(l10n.scanning),
        subtitle: Text(l10n.scanningDesc),
        value: s.scanning,
        onChanged: (v) => notifier.update(s.copyWith(scanning: v)),
      ),
      if (s.scanning) ...[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
          child: Row(
            children: [
              Text(l10n.scanningSpeed, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              const Spacer(),
              Text(
                _seconds(s.scanIntervalMs),
                style: TextStyle(color: palette.inkSoft, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
        Slider(
          value: s.scanIntervalMs.clamp(750, 4000).toDouble(),
          min: 750,
          max: 4000,
          divisions: 13,
          onChanged: (v) => notifier.update(s.copyWith(scanIntervalMs: v.round())),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Text(
            l10n.scanningHint,
            style: TextStyle(color: palette.inkSoft, fontWeight: FontWeight.w600, fontSize: 13.5),
          ),
        ),
      ],
    ]);
  }
}

// -----------------------------------------------------------------------------
// Urządzenie
// -----------------------------------------------------------------------------

class _DeviceSettings extends ConsumerWidget {
  const _DeviceSettings();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final app = ref.watch(appSettingsProvider);
    final themeMode = ref.watch(themeModeProvider);

    return _Card(children: [
      SwitchListTile(
        secondary: const _IconBox(Icons.vibration_rounded, AppColors.sunDeep),
        title: Text(l10n.haptics),
        subtitle: Text(l10n.hapticsDesc),
        value: app.haptics,
        onChanged: (v) => ref.read(appSettingsProvider.notifier).setHaptics(v),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.theme, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<ThemeMode>(
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(value: ThemeMode.system, label: Text(l10n.themeSystem)),
                  ButtonSegment(value: ThemeMode.light, label: Text(l10n.themeLight), icon: const Icon(Icons.light_mode_rounded)),
                  ButtonSegment(value: ThemeMode.dark, label: Text(l10n.themeDark), icon: const Icon(Icons.dark_mode_rounded)),
                ],
                selected: {themeMode},
                onSelectionChanged: (s) => ref.read(themeModeProvider.notifier).setThemeMode(s.first),
              ),
            ),
          ],
        ),
      ),
    ]);
  }
}

// -----------------------------------------------------------------------------
// Dane: gotowa tablica, kopia zapasowa
// -----------------------------------------------------------------------------

class _DataSettings extends ConsumerWidget {
  final String profileId;
  const _DataSettings({required this.profileId});

  Future<void> _addStarter(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    final ok = await showConfirmDialog(
      context,
      title: l10n.starterBoardAdd,
      message: l10n.starterBoardAddConfirm,
      confirmLabel: l10n.add,
      cancelLabel: l10n.cancel,
      icon: Icons.dashboard_customize_rounded,
    );
    if (!ok || !context.mounted) return;
    _showProgress(context, l10n.loading);
    try {
      final service = await ref.read(defaultContentServiceProvider.future);
      final result = await service.addStarterBoard(profileId);
      if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
      if (context.mounted) {
        showToast(
          context,
          result.categories == 0 ? l10n.starterBoardNothing : l10n.starterBoardAdded(result.categories, result.symbols),
        );
      }
    } catch (e) {
      if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
      if (context.mounted) showToast(context, l10n.error(e.toString()), error: true);
    }
  }

  void _showProgress(BuildContext context, String text) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        content: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 18),
            Expanded(child: Text(text)),
          ],
        ),
      ),
    );
  }

  Future<void> _export(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    _showProgress(context, l10n.exporting);
    try {
      final service = await ref.read(backupServiceProvider.future);
      final zipPath = await service.exportProfile(profileId);
      final bytes = await File(zipPath).readAsBytes();
      final fileName = zipPath.split('/').last;
      if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
      final savedPath = await FilePicker.platform.saveFile(
        dialogTitle: l10n.exportProfile,
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: ['zip'],
        bytes: bytes,
      );
      if (savedPath != null && context.mounted) showToast(context, l10n.exportSaved);
    } catch (e) {
      if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
      if (context.mounted) showToast(context, '${l10n.exportError}: $e', error: true);
    }
  }

  Future<void> _import(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['zip'],
    );
    if (picked == null || picked.files.single.path == null || !context.mounted) return;
    _showProgress(context, l10n.importing);
    try {
      final service = await ref.read(backupServiceProvider.future);
      final result = await service.importProfile(picked.files.single.path!);
      if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: const Icon(Icons.check_circle_rounded, color: AppColors.leaf, size: 40),
          title: Text(l10n.importSuccess),
          content: Text(l10n.importSummary(result.profileName, result.categories, result.symbols)),
          actions: [
            FilledButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.close)),
          ],
        ),
      );
    } catch (e) {
      if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
      if (context.mounted) showToast(context, '${l10n.importError}: $e', error: true);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    return _Card(children: [
      ListTile(
        leading: const _IconBox(Icons.dashboard_customize_rounded, AppColors.leaf),
        title: Text(l10n.starterBoardAdd),
        subtitle: Text(l10n.starterBoardAddDesc),
        onTap: () => _addStarter(context, ref),
      ),
      ListTile(
        leading: const _IconBox(Icons.upload_file_rounded, AppColors.sky),
        title: Text(l10n.exportProfile),
        subtitle: Text(l10n.exportProfileDesc),
        onTap: () => _export(context, ref),
      ),
      ListTile(
        leading: const _IconBox(Icons.download_rounded, AppColors.grape),
        title: Text(l10n.importProfile),
        subtitle: Text(l10n.importProfileDesc),
        onTap: () => _import(context, ref),
      ),
    ]);
  }
}

// -----------------------------------------------------------------------------
// O aplikacji
// -----------------------------------------------------------------------------

class _AboutCard extends ConsumerWidget {
  const _AboutCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final version = ref.watch(appVersionProvider).valueOrNull ?? '';
    return _Card(children: [
      ListTile(
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.asset('assets/images/app_icon.png', width: 40, height: 40),
        ),
        title: Text('${l10n.appTitle} $version'),
        subtitle: Text(l10n.aboutDesc),
      ),
      ListTile(
        leading: ClipOval(child: Image.asset('assets/images/akapp_logo.png', width: 40, height: 40)),
        title: const Text('akApp Studio'),
        subtitle: const Text('akappstudio.pl'),
        onTap: () => openExternalUrl(context, AppLinks.website),
      ),
      ListTile(
        leading: _IconBox(Icons.privacy_tip_rounded, context.aac.inkSoft),
        title: Text(l10n.privacyPolicy),
        onTap: () => openExternalUrl(context, AppLinks.privacyPolicy),
      ),
      ListTile(
        leading: _IconBox(Icons.description_rounded, context.aac.inkSoft),
        title: Text(l10n.termsOfService),
        onTap: () => openExternalUrl(context, AppLinks.terms),
      ),
      ListTile(
        leading: _IconBox(Icons.code_rounded, context.aac.inkSoft),
        title: Text(l10n.licenses),
        onTap: () => showLicensePage(
          context: context,
          applicationName: l10n.appTitle,
          applicationVersion: version,
        ),
      ),
    ]);
  }
}
