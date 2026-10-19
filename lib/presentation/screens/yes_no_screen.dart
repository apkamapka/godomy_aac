import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/app_localizations.dart';
import '../../core/theme/app_colors.dart';
import '../../data/services/app_settings.dart';
import '../providers/caregiver_provider.dart';
import '../providers/sentence_provider.dart';
import '../widgets/aac_tile.dart';
import '../widgets/board_grid.dart';
import '../widgets/scan_scope.dart';

/// Szybka odpowiedź: dwa wielkie przyciski „Tak” i „Nie”.
class YesNoScreen extends ConsumerStatefulWidget {
  final String profileId;
  const YesNoScreen({super.key, required this.profileId});

  @override
  ConsumerState<YesNoScreen> createState() => _YesNoScreenState();
}

class _YesNoScreenState extends ConsumerState<YesNoScreen> {
  String? _active;

  Future<void> _say(String id, String word) async {
    if (ref.read(appSettingsProvider).haptics) HapticFeedback.mediumImpact();
    setState(() => _active = id);
    await ref.read(sentenceProvider.notifier).speakSingle(text: word);
    if (mounted && _active == id) setState(() => _active = null);
  }

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/folder/${widget.profileId}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final palette = context.aac;
    final settings = ref.watch(profileSettingsProvider(widget.profileId));
    final caregiver = ref.watch(caregiverModeProvider);
    final landscape = BoardGridLayout.isLandscape(MediaQuery.sizeOf(context));

    Widget answer(String id, String label, String image, Color color) {
      return Expanded(
        child: ScanTarget(
          radius: 22,
          onSelect: (_) => _say(id, label.toLowerCase()),
          child: AacTile(
            label: label,
            imagePath: image,
            color: color,
            highlighted: _active == id,
            onTap: (_) => _say(id, label.toLowerCase()),
          ),
        ),
      );
    }

    final answers = <Widget>[
      answer('yes', l10n.yes, 'assets/symbols/tak-gif.webp', WordKind.actions.color),
      const SizedBox(width: 16, height: 16),
      answer('no', l10n.no, 'assets/symbols/nie-gif.webp', WordKind.negation.color),
    ];

    return Scaffold(
      body: SafeArea(
        child: ScanScope(
          enabled: settings.scanning && !caregiver,
          interval: Duration(milliseconds: settings.scanIntervalMs),
          tapAreaTop: 64,
          child: Column(
            children: [
              SizedBox(
                height: 64,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      ScanTarget(
                        radius: 22,
                        onSelect: (_) => _back(),
                        child: IconButton.filledTonal(
                          tooltip: l10n.back,
                          onPressed: _back,
                          icon: const Icon(Icons.arrow_back_rounded),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Icon(Icons.thumbs_up_down_rounded, color: palette.inkSoft),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          l10n.yesNo,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                  child: landscape ? Row(children: answers) : Column(children: answers),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
