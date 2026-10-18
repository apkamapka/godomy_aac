import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/app_localizations.dart';
import '../../core/theme/app_colors.dart';
import '../../data/services/app_settings.dart';

/// Pierwsze uruchomienie: krótko o tym, jak działa aplikacja.
class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final palette = context.aac;

    final points = <(String, String, String)>[
      ('👆', l10n.welcomePoint1Title, l10n.welcomePoint1),
      ('💬', l10n.welcomePoint2Title, l10n.welcomePoint2),
      ('🔒', l10n.welcomePoint3Title, l10n.welcomePoint3),
      ('📱', l10n.welcomePoint4Title, l10n.welcomePoint4),
    ];

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
              children: [
                Center(
                  child: Container(
                    width: 112,
                    height: 112,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(color: AppColors.sky.withValues(alpha: 0.25), blurRadius: 0, spreadRadius: 8),
                      ],
                    ),
                    padding: const EdgeInsets.all(14),
                    child: ClipOval(child: Image.asset('assets/images/app_icon.png', fit: BoxFit.cover)),
                  ),
                ),
                const SizedBox(height: 22),
                Text(
                  l10n.welcomeTitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, height: 1.1),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.welcomeSubtitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16.5, color: palette.inkSoft, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 26),
                for (final p in points)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: palette.surface,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [BoxShadow(color: palette.line, offset: const Offset(0, 2), blurRadius: 0)],
                          ),
                          child: Text(p.$1, style: const TextStyle(fontSize: 24)),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(p.$2, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
                              const SizedBox(height: 2),
                              Text(
                                p.$3,
                                style: TextStyle(color: palette.inkSoft, fontWeight: FontWeight.w600, height: 1.3),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 18),
                SizedBox(
                  height: 58,
                  child: FilledButton.icon(
                    onPressed: () async {
                      await ref.read(appSettingsProvider.notifier).setOnboardingDone();
                      if (context.mounted) context.go('/profile-editor?first=1');
                    },
                    icon: const Icon(Icons.person_add_rounded),
                    label: Text(l10n.welcomeCta),
                  ),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: () async {
                    await ref.read(appSettingsProvider.notifier).setOnboardingDone();
                    if (context.mounted) context.go('/profiles');
                  },
                  child: Text(l10n.welcomeImport),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
