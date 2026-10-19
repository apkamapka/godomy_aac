import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/app_localizations.dart';
import '../../core/theme/app_colors.dart';
import '../../data/services/app_settings.dart';
import '../../data/services/default_content_service.dart';
import '../providers/board_provider.dart';
import '../providers/caregiver_provider.dart';
import '../providers/sentence_provider.dart';
import 'aac_tile.dart';
import 'app_sheet.dart';
import 'board_grid.dart';
import 'scan_scope.dart';

/// Przycisk „Pilne” w górnym pasku.
class UrgentButton extends StatelessWidget {
  /// Szerokość pełnej wersji (ikona + napis) – do układu górnego paska.
  static const double fullWidth = 100;

  final VoidCallback onTap;
  final bool compact;
  final double size;

  const UrgentButton({
    super.key,
    required this.onTap,
    this.compact = false,
    this.size = 44,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // Ikona zamiast emoji ✋ – emoji potrafią znikać po odblokowaniu ekranu.
    const icon = Icon(Icons.back_hand_rounded, color: Colors.white, size: 22);
    return Semantics(
      button: true,
      label: l10n.urgent,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: size,
          width: compact ? size : null,
          padding: compact ? EdgeInsets.zero : const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.coral,
            borderRadius: BorderRadius.circular(size / 2),
            boxShadow: const [
              BoxShadow(color: AppColors.coralDeep, offset: Offset(0, 3), blurRadius: 0),
            ],
          ),
          child: compact
              ? icon
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    icon,
                    const SizedBox(width: 6),
                    Text(
                      l10n.urgent,
                      textScaler: TextScaler.noScaling,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

/// Arkusz „Pilne”: duże kafelki mówione od razu po dotknięciu.
Future<void> showUrgentSheet(BuildContext context, String profileId) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    useRootNavigator: true,
    backgroundColor: AppColors.coralSoft,
    builder: (_) => _UrgentSheet(profileId: profileId),
  );
}

class _UrgentSheet extends ConsumerStatefulWidget {
  final String profileId;
  const _UrgentSheet({required this.profileId});

  @override
  ConsumerState<_UrgentSheet> createState() => _UrgentSheetState();
}

class _UrgentSheetState extends ConsumerState<_UrgentSheet> {
  String? _spokenId;

  Future<void> _speak(BoardItem item) async {
    if (ref.read(appSettingsProvider).haptics) HapticFeedback.heavyImpact();
    setState(() => _spokenId = item.id);
    await ref.read(sentenceProvider.notifier).speakSingle(text: item.name, voicePath: item.voicePath);
    if (mounted && _spokenId == item.id) setState(() => _spokenId = null);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final caregiver = ref.watch(caregiverModeProvider);
    final settings = ref.watch(profileSettingsProvider(widget.profileId));
    final scanning = settings.scanning && !caregiver;
    final boardAsync = ref.watch(systemBoardProvider((widget.profileId, SystemBoard.urgent)));
    final screen = MediaQuery.sizeOf(context);
    final landscape = BoardGridLayout.isLandscape(screen);

    return SizedBox(
      height: screen.height * (landscape ? 0.92 : 0.86),
      child: ScanScope(
        enabled: scanning,
        interval: Duration(milliseconds: settings.scanIntervalMs),
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, 10, 16, 16 + sheetBottomInset(context)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: AppColors.coral.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(Icons.back_hand_rounded, color: AppColors.coral, size: 30),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      l10n.urgent,
                      style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: AppColors.ink),
                    ),
                  ),
                  if (caregiver)
                    boardAsync.maybeWhen(
                      data: (board) => TextButton.icon(
                        style: TextButton.styleFrom(foregroundColor: AppColors.coralDeep),
                        onPressed: () {
                          Navigator.pop(context);
                          context.push('/folder/${widget.profileId}/c/${board.id}');
                        },
                        icon: const Icon(Icons.edit_rounded),
                        label: Text(l10n.edit),
                      ),
                      orElse: () => const SizedBox.shrink(),
                    ),
                ],
              ),
              Text(
                l10n.urgentHint,
                style: const TextStyle(color: AppColors.inkSoft, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: boardAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text(l10n.error(e.toString()))),
                  data: (board) {
                    final itemsAsync = ref.watch(
                      boardItemsProvider((profileId: widget.profileId, categoryId: board.id)),
                    );
                    return itemsAsync.when(
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (e, _) => Center(child: Text(l10n.error(e.toString()))),
                      data: (items) {
                        final symbols = items.where((i) => !i.isFolder).toList();
                        if (symbols.isEmpty) {
                          return Center(
                            child: Text(
                              l10n.urgentEmpty,
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.inkSoft),
                            ),
                          );
                        }
                        final cols = landscape ? 3 : 2;
                        final rows = landscape ? 2 : 3;
                        return BoardGrid(
                          columns: cols,
                          rows: rows,
                          padding: const EdgeInsets.only(top: 4, bottom: 4),
                          spacing: 12,
                          minTileHeight: 110,
                          adaptToLandscape: false,
                          buildAll: scanning,
                          itemCount: symbols.length,
                          itemBuilder: (context, index) {
                            final item = symbols[index];
                            return ScanTarget(
                              radius: 18,
                              onSelect: (_) => _speak(item),
                              child: AacTile(
                                label: item.name,
                                imagePath: item.imagePath,
                                emoji: item.emoji,
                                color: item.color,
                                hasRecording: item.hasRecording,
                                highlighted: _spokenId == item.id,
                                onTap: (_) => _speak(item),
                              ),
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              ScanTarget(
                radius: 16,
                onSelect: (_) => Navigator.pop(context),
                child: SizedBox(
                  height: 56,
                  child: OutlinedButton(
                    // Arkusz jest zawsze jasny (także w trybie ciemnym).
                    style: OutlinedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.ink,
                      side: const BorderSide(color: AppColors.coral, width: 2),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: Text(l10n.close),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
