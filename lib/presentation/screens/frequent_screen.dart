import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/app_localizations.dart';
import '../../core/theme/app_colors.dart';
import '../../data/services/app_settings.dart';
import '../providers/board_provider.dart';
import '../widgets/aac_tile.dart';
import '../widgets/app_sheet.dart';
import '../widgets/board_grid.dart';
import '../widgets/sentence_bar.dart';
import '../widgets/tile_actions.dart';

/// „Częste” – symbole, których dziecko używa najczęściej (liczone na
/// tym urządzeniu, osobno dla każdego profilu).
class FrequentScreen extends ConsumerStatefulWidget {
  final String profileId;
  const FrequentScreen({super.key, required this.profileId});

  @override
  ConsumerState<FrequentScreen> createState() => _FrequentScreenState();
}

class _FrequentScreenState extends ConsumerState<FrequentScreen> {
  final _flyTarget = GlobalKey();

  Future<void> _resetStats() async {
    final l10n = AppLocalizations.of(context)!;
    final ok = await showConfirmDialog(
      context,
      title: l10n.frequentReset,
      message: l10n.frequentResetConfirm,
      confirmLabel: l10n.frequentReset,
      cancelLabel: l10n.cancel,
      destructive: true,
    );
    if (!ok) return;
    await ref.read(usageStoreProvider).clear(widget.profileId);
    ref.invalidate(frequentItemsProvider(widget.profileId));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final palette = context.aac;
    final itemsAsync = ref.watch(frequentItemsProvider(widget.profileId));
    final profile = ref.watch(profileProvider(widget.profileId)).valueOrNull;
    final settings = ref.watch(profileSettingsProvider(widget.profileId));
    final compact = MediaQuery.sizeOf(context).height < 560;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(
              height: 60,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    IconButton.filledTonal(
                      onPressed: () => context.pop(),
                      icon: const Icon(Icons.arrow_back_rounded),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.star_rounded, color: AppColors.sunDeep, size: 28),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        l10n.frequent,
                        style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
                      ),
                    ),
                    PopupMenuButton<String>(
                      icon: Icon(Icons.more_vert_rounded, color: palette.ink),
                      onSelected: (_) => _resetStats(),
                      itemBuilder: (_) => [
                        PopupMenuItem(value: 'reset', child: Text(l10n.frequentReset)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            if (settings.showSentenceBar)
              SentenceBar(
                flyTargetKey: _flyTarget,
                jaPhotoPath: profile?.photoPath,
                compact: compact,
              ),
            Expanded(
              child: itemsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text(l10n.error(e.toString()))),
                data: (items) {
                  if (items.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('⭐', style: TextStyle(fontSize: 52)),
                            const SizedBox(height: 10),
                            Text(
                              l10n.frequentEmpty,
                              textAlign: TextAlign.center,
                              style: TextStyle(color: palette.inkSoft, fontWeight: FontWeight.w700, fontSize: 16),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  return BoardGrid(
                    columns: 4,
                    rows: 4,
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      final isJa = isJaItem(item, profile);
                      return AacTile(
                        label: item.name,
                        imagePath: isJa ? profile!.photoPath : item.imagePath,
                        emoji: item.emoji,
                        imageFit: isJa ? BoxFit.cover : BoxFit.contain,
                        color: item.color,
                        hasRecording: item.hasRecording,
                        onTap: (rect) => handleSymbolTap(
                          context: context,
                          ref: ref,
                          profileId: widget.profileId,
                          item: item,
                          rect: rect,
                          direct: false,
                          settings: settings,
                          flyTarget: _flyTarget,
                          profile: profile,
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
