import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/app_localizations.dart';
import '../../core/theme/app_colors.dart';
import '../providers/sentence_provider.dart';
import '../widgets/symbol_image.dart';

/// „Pokaż rozmówcy”: ułożone zdanie na cały ekran – duże obrazki i litery.
/// Przycisk obrotu odwraca treść o 180°, żeby osoba naprzeciwko mogła czytać.
class PartnerViewScreen extends ConsumerStatefulWidget {
  final String profileId;
  const PartnerViewScreen({super.key, required this.profileId});

  @override
  ConsumerState<PartnerViewScreen> createState() => _PartnerViewScreenState();
}

class _PartnerViewScreenState extends ConsumerState<PartnerViewScreen> {
  bool _flipped = false;

  void _close() {
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
    final sentence = ref.watch(sentenceProvider);
    final items = sentence.items;
    final pictures = items
        .where((i) => (i.imagePath?.isNotEmpty ?? false) || (i.emoji?.isNotEmpty ?? false))
        .toList();

    return Scaffold(
      backgroundColor: palette.surface,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: RotatedBox(
                quarterTurns: _flipped ? 2 : 0,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      if (items.isEmpty) {
                        return Center(
                          child: Text(
                            l10n.sentenceHint,
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 20, color: palette.inkSoft, fontWeight: FontWeight.w700),
                          ),
                        );
                      }
                      final pictureSize = (constraints.maxWidth / 4.4).clamp(64.0, 150.0);
                      final picturesHeight = pictures.isEmpty ? 0.0 : pictureSize + 16;
                      final text = sentence.text;
                      final fontSize = _fitFontSize(
                        text,
                        maxWidth: constraints.maxWidth,
                        maxHeight: (constraints.maxHeight - picturesHeight - 24).clamp(40.0, 2000.0),
                      );
                      return Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (pictures.isNotEmpty)
                            SizedBox(
                              height: pictureSize,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                shrinkWrap: true,
                                itemCount: pictures.length,
                                separatorBuilder: (_, __) => const SizedBox(width: 10),
                                itemBuilder: (context, index) {
                                  final item = pictures[index];
                                  return Container(
                                    width: pictureSize,
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: item.color,
                                      borderRadius: BorderRadius.circular(18),
                                      border: Border.all(color: AppColors.outlineFor(item.color), width: 2),
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: ColoredBox(
                                        color: palette.tileWindow,
                                        child: SymbolImage(
                                          imagePath: item.imagePath,
                                          emoji: item.emoji,
                                          cacheWidth: 400,
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          if (pictures.isNotEmpty) const SizedBox(height: 24),
                          Text(
                            text,
                            textAlign: TextAlign.center,
                            textScaler: TextScaler.noScaling,
                            style: TextStyle(
                              fontSize: fontSize,
                              fontWeight: FontWeight.w900,
                              height: 1.15,
                              color: palette.ink,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              child: Row(
                children: [
                  IconButton.filledTonal(
                    tooltip: l10n.close,
                    iconSize: 28,
                    style: IconButton.styleFrom(minimumSize: const Size(56, 56)),
                    onPressed: _close,
                    icon: const Icon(Icons.close_rounded),
                  ),
                  const SizedBox(width: 10),
                  IconButton.filledTonal(
                    tooltip: l10n.flipView,
                    iconSize: 28,
                    style: IconButton.styleFrom(minimumSize: const Size(56, 56)),
                    onPressed: () => setState(() => _flipped = !_flipped),
                    icon: const Icon(Icons.screen_rotation_rounded),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: items.isEmpty
                          ? null
                          : () {
                              final notifier = ref.read(sentenceProvider.notifier);
                              if (sentence.speaking) {
                                notifier.stop();
                              } else {
                                notifier.speakAll();
                              }
                            },
                      icon: Icon(sentence.speaking ? Icons.stop_rounded : Icons.volume_up_rounded),
                      label: Text(sentence.speaking ? l10n.stop : l10n.speak),
                    ),
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

/// Największa czcionka (72 → 24), przy której tekst mieści się w polu.
double _fitFontSize(String text, {required double maxWidth, required double maxHeight}) {
  for (var size = 72.0; size > 24; size -= 4) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(fontFamily: 'Nunito', fontSize: size, fontWeight: FontWeight.w900, height: 1.15),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout(maxWidth: maxWidth);
    final fits = painter.height <= maxHeight;
    painter.dispose();
    if (fits) return size;
  }
  return 24;
}
