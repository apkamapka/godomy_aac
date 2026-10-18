import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/constants/app_links.dart';
import '../../core/l10n/app_localizations.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/url_helper.dart';
import '../../data/models/profile_model.dart';
import '../../data/services/app_settings.dart';
import '../providers/caregiver_provider.dart';
import '../providers/sentence_provider.dart';
import 'symbol_image.dart';

final appVersionProvider = FutureProvider<String>((ref) async {
  try {
    final info = await PackageInfo.fromPlatform();
    return info.version;
  } catch (_) {
    return '';
  }
});

/// Menu boczne (dostępne w trybie opiekuna na tablicy startowej).
class AppDrawer extends ConsumerWidget {
  final String profileId;
  final ProfileModel? profile;

  const AppDrawer({super.key, required this.profileId, this.profile});

  void _go(BuildContext context, String location) {
    Navigator.pop(context);
    context.push(location);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final palette = context.aac;
    final version = ref.watch(appVersionProvider).valueOrNull ?? '';
    final name = profile?.name ?? '';

    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Row(
                children: [
                  ProfileAvatar(name: name, photoPath: profile?.photoPath, size: 64),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                        ),
                        Text(
                          l10n.caregiverModeOn,
                          style: const TextStyle(color: AppColors.skyDeep, fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                children: [
                  _DrawerItem(
                    icon: Icons.photo_library_rounded,
                    color: AppColors.grape,
                    label: l10n.library,
                    onTap: () => _go(context, '/library'),
                  ),
                  _DrawerItem(
                    icon: Icons.event_note_rounded,
                    color: AppColors.leaf,
                    label: l10n.schedule,
                    onTap: () => _go(context, '/folder/$profileId/schedule'),
                  ),
                  _DrawerItem(
                    icon: Icons.star_rounded,
                    color: AppColors.sunDeep,
                    label: l10n.frequent,
                    onTap: () => _go(context, '/folder/$profileId/frequent'),
                  ),
                  _DrawerItem(
                    icon: Icons.tune_rounded,
                    color: AppColors.sky,
                    label: l10n.settings,
                    onTap: () => _go(context, '/folder/$profileId/settings'),
                  ),
                  const Divider(height: 28),
                  _DrawerItem(
                    icon: Icons.switch_account_rounded,
                    color: AppColors.coral,
                    label: l10n.switchProfile,
                    onTap: () {
                      // Router bierzemy od razu: po wyłączeniu trybu opiekuna
                      // menu znika z drzewa i jego context przestaje być ważny.
                      final router = GoRouter.of(context);
                      Navigator.pop(context);
                      ref.read(sentenceProvider.notifier).clear();
                      ref.read(caregiverModeProvider.notifier).state = false;
                      ref.read(deleteModeProvider.notifier).state = false;
                      ref.read(appSettingsProvider.notifier).clearLastProfile();
                      router.go('/profiles');
                    },
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                children: [
                  InkWell(
                    onTap: () => openExternalUrl(context, AppLinks.website),
                    borderRadius: BorderRadius.circular(28),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ClipOval(
                            child: Image.asset('assets/images/akapp_logo.png', width: 36, height: 36),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              '${l10n.appTitle}${version.isNotEmpty ? ' $version' : ''} · akApp Studio',
                              style: TextStyle(fontSize: 12.5, color: palette.inkSoft, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Wrap: przy dużej czcionce przyciski przechodzą do nowej linii.
                  Wrap(
                    alignment: WrapAlignment.center,
                    children: [
                      TextButton(
                        onPressed: () => openExternalUrl(context, AppLinks.terms),
                        child: Text(l10n.termsOfService),
                      ),
                      TextButton(
                        onPressed: () => openExternalUrl(context, AppLinks.privacyPolicy),
                        child: Text(l10n.privacyPolicy),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;

  const _DrawerItem({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(icon, color: color),
        ),
        title: Text(label),
        trailing: Icon(Icons.chevron_right_rounded, color: context.aac.inkSoft),
      ),
    );
  }
}
