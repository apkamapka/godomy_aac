import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_links.dart';
import '../../core/constants/system_ids.dart';
import '../../core/l10n/app_localizations.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/url_helper.dart';
import '../../data/models/profile_model.dart';
import '../../data/repositories/category_repository.dart';
import '../../data/repositories/profile_repository.dart';
import '../../data/services/app_settings.dart';
import '../../data/services/sentence_store.dart';
import '../providers/backup_provider.dart';
import '../providers/caregiver_provider.dart';
import '../providers/profiles_provider.dart';
import '../providers/sentence_provider.dart';
import '../widgets/app_sheet.dart';
import '../widgets/symbol_image.dart';

/// Wybór profilu („Kto dziś mówi?”).
class ProfilesScreen extends ConsumerWidget {
  const ProfilesScreen({super.key});

  Future<void> _select(BuildContext context, WidgetRef ref, ProfileModel profile) async {
    try {
      final repo = await ref.read(profileRepositoryProvider.future);
      // copyWith – zachowujemy ustawienia głosu (wcześniej były tracone).
      await repo.update(profile.copyWith(updatedAt: DateTime.now()));
    } catch (_) {}
    ref.read(sentenceProvider.notifier).clear();
    ref.read(caregiverModeProvider.notifier).state = false;
    await ref.read(appSettingsProvider.notifier).setLastProfile(profile.id);
    if (context.mounted) context.go('/folder/${profile.id}');
  }

  Future<void> _showMenu(BuildContext context, WidgetRef ref, ProfileModel profile) async {
    final l10n = AppLocalizations.of(context)!;
    final choice = await showAppSheet<String>(
      context: context,
      title: profile.name,
      builder: (sheetContext) => Row(
        children: [
          Expanded(
            child: BigActionButton(
              icon: Icons.edit_rounded,
              label: l10n.editProfile,
              color: AppColors.sky,
              onTap: () => Navigator.pop(sheetContext, 'edit'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: BigActionButton(
              icon: Icons.delete_rounded,
              label: l10n.deleteProfile,
              color: AppColors.coralDeep,
              onTap: () => Navigator.pop(sheetContext, 'delete'),
            ),
          ),
        ],
      ),
    );
    if (!context.mounted || choice == null) return;
    if (choice == 'edit') {
      context.push('/profile-editor?id=${profile.id}');
    } else {
      await _delete(context, ref, profile);
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, ProfileModel profile) async {
    final l10n = AppLocalizations.of(context)!;
    final ok = await showConfirmDialog(
      context,
      title: l10n.deleteProfile,
      message: '${l10n.confirmDeleteProfile} „${profile.name}”?\n${l10n.deleteProfileContentWarning}',
      confirmLabel: l10n.delete,
      cancelLabel: l10n.cancel,
      destructive: true,
      icon: Icons.warning_rounded,
    );
    if (!ok) return;
    try {
      final categories = await ref.read(categoryRepositoryProvider.future);
      await categories.deleteProfileContent(profile.id, SystemIds.rootOf(profile.id));
      final profiles = await ref.read(profileRepositoryProvider.future);
      await profiles.delete(profile.id);

      final prefs = ref.read(appPrefsProvider);
      await prefs.remove(ProfileSettingsNotifier.keyFor(profile.id));
      await prefs.remove(SavedSentencesNotifier.keyFor(profile.id));
      await prefs.remove(SentenceHistoryNotifier.keyFor(profile.id));
      await ref.read(usageStoreProvider).clear(profile.id);
      await ref.read(scheduleProgressProvider).reset(profile.id);
      if (ref.read(appSettingsProvider).lastProfileId == profile.id) {
        await ref.read(appSettingsProvider.notifier).clearLastProfile();
      }
      if (context.mounted) showToast(context, l10n.profileDeleted);
    } catch (e) {
      if (context.mounted) showToast(context, l10n.error(e.toString()), error: true);
    }
  }

  Future<void> _import(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['zip'],
    );
    if (picked == null || picked.files.single.path == null || !context.mounted) return;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        content: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 18),
            Expanded(child: Text(l10n.importing)),
          ],
        ),
      ),
    );
    try {
      final service = await ref.read(backupServiceProvider.future);
      final result = await service.importProfile(File(picked.files.single.path!).path);
      if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
      if (context.mounted) {
        showToast(context, l10n.importSummary(result.profileName, result.categories, result.symbols).replaceAll('\n', ' · '));
      }
    } catch (e) {
      if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
      if (context.mounted) showToast(context, '${l10n.importError}: $e', error: true);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final palette = context.aac;
    final profilesAsync = ref.watch(profilesProvider);
    final width = MediaQuery.sizeOf(context).width;
    final columns = width >= 900 ? 4 : (width >= 600 ? 3 : 2);

    return Scaffold(
      body: SafeArea(
        child: profilesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text(l10n.error(e.toString()))),
          data: (profiles) {
            final sorted = [...profiles]..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
            return CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 28, 20, 18),
                    child: Row(
                      children: [
                        ClipOval(
                          child: Image.asset('assets/images/app_icon.png', width: 52, height: 52),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.whoIsTalking,
                                style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, height: 1.1),
                              ),
                              Text(
                                l10n.whoIsTalkingHint,
                                style: TextStyle(color: palette.inkSoft, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverGrid(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columns,
                      mainAxisSpacing: 14,
                      crossAxisSpacing: 14,
                      childAspectRatio: 0.86,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        if (index == sorted.length) {
                          return _AddProfileCard(onTap: () => context.push('/profile-editor'));
                        }
                        final profile = sorted[index];
                        return _ProfileCard(
                          profile: profile,
                          onTap: () => _select(context, ref, profile),
                          onLongPress: () => _showMenu(context, ref, profile),
                          onMenu: () => _showMenu(context, ref, profile),
                        );
                      },
                      childCount: sorted.length + 1,
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                    child: Center(
                      child: TextButton.icon(
                        onPressed: () => _import(context, ref),
                        icon: const Icon(Icons.download_rounded),
                        label: Text(l10n.importProfileFromFile),
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 20, top: 8),
                    child: Center(
                      child: InkWell(
                        onTap: () => openExternalUrl(context, AppLinks.website),
                        borderRadius: BorderRadius.circular(24),
                        child: Padding(
                          padding: const EdgeInsets.all(6),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                l10n.createdBy,
                                style: TextStyle(color: palette.inkSoft, fontWeight: FontWeight.w600, fontSize: 12.5),
                              ),
                              const SizedBox(width: 8),
                              ClipOval(child: Image.asset('assets/images/akapp_logo.png', width: 34, height: 34)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  final ProfileModel profile;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onMenu;

  const _ProfileCard({
    required this.profile,
    required this.onTap,
    required this.onLongPress,
    required this.onMenu,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.aac;
    final color = ProfileAvatar.colorFor(profile.name);
    // Tło + „krawędź” pod spodem malujemy pod przezroczystym Material,
    // żeby efekt dotknięcia (InkWell) był widoczny na wierzchu.
    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: color.withValues(alpha: 0.45), width: 2),
        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.55), offset: const Offset(0, 4), blurRadius: 0)],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(26),
          onTap: onTap,
          onLongPress: onLongPress,
          child: Stack(
            children: [
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, c) => ProfileAvatar(
                            name: profile.name,
                            photoPath: profile.photoPath,
                            size: (c.biggest.shortestSide).clamp(56.0, 140.0),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        profile.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                top: 2,
                right: 2,
                child: IconButton(
                  onPressed: onMenu,
                  icon: Icon(Icons.more_horiz_rounded, color: palette.inkSoft),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddProfileCard extends StatelessWidget {
  final VoidCallback onTap;
  const _AddProfileCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final palette = context.aac;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(26),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            color: AppColors.sky.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: AppColors.sky.withValues(alpha: 0.6), width: 2.5),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(color: AppColors.sky, shape: BoxShape.circle),
                child: const Icon(Icons.add_rounded, color: Colors.white, size: 38),
              ),
              const SizedBox(height: 12),
              Text(
                l10n.addProfile,
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: palette.ink),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
