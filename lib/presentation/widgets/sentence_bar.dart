import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/app_localizations.dart';
import '../../core/theme/app_colors.dart';
import '../../data/services/app_settings.dart';
import '../providers/caregiver_provider.dart';
import '../providers/sentence_provider.dart';
import 'scan_scope.dart';
import 'symbol_image.dart';

/// Pasek zdania w kształcie dymka z dużym przyciskiem „Mów”.
///
/// * dotknięcie dymka – przeczytaj całe zdanie,
/// * przytrzymanie słowa – usuń je,
/// * ⌫ – usuń ostatnie słowo, przytrzymanie ⌫ – wyczyść wszystko,
/// * ⌨ – dopisz własny tekst,
/// * „Pokaż” – zdanie na cały ekran dla rozmówcy,
/// * „Zapisz” (opiekun) – do „Moich zdań” albo jako kafelek.
class SentenceBar extends ConsumerStatefulWidget {
  /// Zdjęcie profilu – pokazywane zamiast obrazka przy słowie „ja”.
  final String? jaPhotoPath;

  /// Miejsce, do którego „wlatują” obrazki z kafelków.
  final GlobalKey flyTargetKey;

  /// Zapis zdania (tylko w trybie opiekuna).
  final VoidCallback? onSave;

  /// Pokazanie zdania rozmówcy na całym ekranie (null = funkcja wyłączona).
  final VoidCallback? onShow;

  final bool compact;

  const SentenceBar({
    super.key,
    required this.flyTargetKey,
    this.jaPhotoPath,
    this.onSave,
    this.onShow,
    this.compact = false,
  });

  @override
  ConsumerState<SentenceBar> createState() => _SentenceBarState();
}

class _SentenceBarState extends ConsumerState<SentenceBar> {
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _speakOrStop() async {
    final notifier = ref.read(sentenceProvider.notifier);
    if (ref.read(sentenceProvider).speaking) {
      await notifier.stop();
      return;
    }
    // Ochrona przed przypadkowym, wielokrotnym dotknięciem (ustawienie profilu).
    if (!ref.read(caregiverModeProvider)) {
      final guardMs = ref.read(activeProfileSettingsProvider).repeatGuardMs;
      if (!ref.read(touchGuardProvider).tryActivate(guardMs)) return;
    }
    HapticFeedback.lightImpact();
    await notifier.speakAll();
  }

  Future<void> _typeText() async {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.enterText),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(hintText: l10n.enterTextHint),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.cancel)),
          FilledButton(onPressed: () => Navigator.pop(ctx, controller.text), child: Text(l10n.add)),
        ],
      ),
    );
    // Kontroler zwalniamy po zamknięciu animacji dialogu.
    Future.delayed(const Duration(milliseconds: 400), controller.dispose);
    if (!mounted) return;
    if (text != null && text.trim().isNotEmpty) {
      ref.read(sentenceProvider.notifier).addText(text);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final palette = context.aac;
    final sentence = ref.watch(sentenceProvider);
    final caregiver = ref.watch(caregiverModeProvider);

    ref.listen<int>(sentenceProvider.select((s) => s.items.length), (prev, next) {
      if (prev != null && next > prev) _scrollToEnd();
    });

    final speakSize = widget.compact ? 60.0 : 70.0;
    final chipH = widget.compact ? 54.0 : 64.0;
    final bubbleH = chipH + 20;
    final hasItems = sentence.items.isNotEmpty;

    // Przyciski na końcu zdania: „Pokaż” i (dla opiekuna) „Zapisz”.
    final trailingChips = <Widget>[
      if (widget.onShow != null)
        _ActionChip(
          height: chipH,
          icon: Icons.open_in_full_rounded,
          label: l10n.showToPartner,
          onTap: widget.onShow!,
        ),
      if (caregiver && widget.onSave != null && sentence.items.length > 1)
        _ActionChip(
          height: chipH,
          icon: Icons.bookmark_add_rounded,
          label: l10n.saveAsTile,
          onTap: widget.onSave!,
        ),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 2, 12, 14),
      child: SizedBox(
        height: bubbleH,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Dymek
            Positioned.fill(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: palette.surface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.sky, width: 3),
                  boxShadow: sentence.speaking
                      ? [BoxShadow(color: AppColors.sky.withValues(alpha: 0.25), blurRadius: 0, spreadRadius: 6)]
                      : const [],
                ),
              ),
            ),
            // Ogonek dymka
            Positioned(
              left: 30,
              bottom: -9,
              child: Transform.rotate(
                angle: math.pi / 4,
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: palette.surface,
                    border: const Border(
                      right: BorderSide(color: AppColors.sky, width: 3),
                      bottom: BorderSide(color: AppColors.sky, width: 3),
                    ),
                  ),
                ),
              ),
            ),
            // Treść
            Positioned.fill(
              child: Padding(
                padding: EdgeInsets.only(left: 8, right: speakSize + 10, top: 3, bottom: 3),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: hasItems ? _speakOrStop : null,
                        child: hasItems
                            ? ListView.separated(
                                controller: _scroll,
                                scrollDirection: Axis.horizontal,
                                padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 2),
                                itemCount: sentence.items.length + 1 + trailingChips.length,
                                separatorBuilder: (_, __) => const SizedBox(width: 6),
                                itemBuilder: (context, index) {
                                  if (index < sentence.items.length) {
                                    final item = sentence.items[index];
                                    return _SentenceChip(
                                      key: ValueKey(item.key),
                                      item: item,
                                      height: chipH,
                                      highlighted: sentence.speakingIndex == index,
                                      jaPhotoPath: widget.jaPhotoPath,
                                      onLongPress: () {
                                        HapticFeedback.selectionClick();
                                        ref.read(sentenceProvider.notifier).removeAt(index);
                                      },
                                    );
                                  }
                                  if (index == sentence.items.length) {
                                    // Cel animacji „wlatywania”.
                                    return SizedBox(key: widget.flyTargetKey, width: chipH * 0.85, height: chipH);
                                  }
                                  return trailingChips[index - sentence.items.length - 1];
                                },
                              )
                            : Row(
                                children: [
                                  SizedBox(key: widget.flyTargetKey, width: 8, height: chipH),
                                  Expanded(
                                    child: Text(
                                      l10n.sentenceHint,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: palette.inkSoft,
                                        fontWeight: FontWeight.w700,
                                        fontSize: widget.compact ? 14 : 15,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ScanTarget(
                          radius: 11,
                          onSelect: (_) => ref.read(sentenceProvider.notifier).removeLast(),
                          child: _SmallBarButton(
                            icon: Icons.backspace_rounded,
                            height: widget.compact ? 30 : 34,
                            tooltip: l10n.deleteLastHint,
                            onTap: hasItems && !sentence.speaking
                                ? () => ref.read(sentenceProvider.notifier).removeLast()
                                : null,
                            onLongPress: hasItems && !sentence.speaking
                                ? () {
                                    HapticFeedback.mediumImpact();
                                    ref.read(sentenceProvider.notifier).clear();
                                  }
                                : null,
                          ),
                        ),
                        const SizedBox(height: 4),
                        _SmallBarButton(
                          icon: Icons.keyboard_rounded,
                          height: widget.compact ? 30 : 34,
                          tooltip: l10n.enterText,
                          onTap: sentence.speaking ? null : _typeText,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            // Przycisk „Mów”
            Positioned(
              right: 6,
              top: (bubbleH - speakSize) / 2,
              child: ScanTarget(
                radius: speakSize / 2,
                onSelect: (_) {
                  if (ref.read(sentenceProvider).items.isNotEmpty) _speakOrStop();
                },
                child: _SpeakButton(
                  size: speakSize,
                  enabled: hasItems,
                  speaking: sentence.speaking,
                  label: sentence.speaking ? l10n.stop : l10n.speak,
                  onTap: hasItems ? _speakOrStop : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SentenceChip extends StatelessWidget {
  final SentenceItem item;
  final double height;
  final bool highlighted;
  final String? jaPhotoPath;
  final VoidCallback onLongPress;

  const _SentenceChip({
    super.key,
    required this.item,
    required this.height,
    required this.highlighted,
    required this.onLongPress,
    this.jaPhotoPath,
  });

  @override
  Widget build(BuildContext context) {
    final edge = AppColors.edgeFor(item.color);
    final isJa = item.label.trim().toLowerCase() == 'ja' && jaPhotoPath != null && jaPhotoPath!.isNotEmpty;
    final width = height * 0.88;
    final hasPicture = isJa || (item.imagePath != null && item.imagePath!.isNotEmpty) || (item.emoji != null && item.emoji!.isNotEmpty);
    final dpr = MediaQuery.devicePixelRatioOf(context);

    return GestureDetector(
      onLongPress: onLongPress,
      child: AnimatedScale(
        scale: highlighted ? 1.12 : 1.0,
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutBack,
        child: Container(
          width: hasPicture ? width : null,
          constraints: BoxConstraints(minWidth: width * 0.8, maxWidth: width * 2.6),
          padding: const EdgeInsets.fromLTRB(4, 4, 4, 2),
          decoration: BoxDecoration(
            color: item.color,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: highlighted ? AppColors.sky : AppColors.outlineFor(item.color),
              width: highlighted ? 3 : 1.5,
            ),
            boxShadow: [BoxShadow(color: edge, offset: const Offset(0, 2), blurRadius: 0)],
          ),
          child: hasPicture
              ? Column(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: SymbolImage(
                          imagePath: isJa ? jaPhotoPath : item.imagePath,
                          emoji: item.emoji,
                          fit: isJa ? BoxFit.cover : BoxFit.contain,
                          cacheWidth: (width * dpr).round(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textScaler: TextScaler.noScaling,
                      style: TextStyle(
                        fontSize: height * 0.18,
                        fontWeight: FontWeight.w800,
                        height: 1.05,
                        color: AppColors.labelOn(item.color),
                      ),
                    ),
                  ],
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Text(
                        item.label,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        textScaler: TextScaler.noScaling,
                        style: TextStyle(
                          fontSize: height * 0.24,
                          fontWeight: FontWeight.w800,
                          height: 1.05,
                          color: AppColors.labelOn(item.color),
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

class _ActionChip extends StatelessWidget {
  final double height;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionChip({
    required this.height,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ScanTarget(
      radius: 12,
      onSelect: (_) => onTap(),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: height,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: AppColors.skySoft,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.sky, width: 2),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: AppColors.skyDeep),
              const SizedBox(width: 4),
              Text(
                label,
                style: const TextStyle(color: AppColors.skyDeep, fontWeight: FontWeight.w900),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SmallBarButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final double height;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const _SmallBarButton({
    required this.icon,
    required this.tooltip,
    this.height = 34,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.aac;
    final enabled = onTap != null;
    return Semantics(
      button: true,
      label: tooltip,
      child: GestureDetector(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Container(
          width: 38,
          height: height,
          decoration: BoxDecoration(
            color: palette.surfaceHigh,
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(
            icon,
            size: 20,
            color: enabled ? palette.ink : palette.inkSoft.withValues(alpha: 0.4),
          ),
        ),
      ),
    );
  }
}

class _SpeakButton extends StatelessWidget {
  final double size;
  final bool enabled;
  final bool speaking;
  final String label;
  final VoidCallback? onTap;

  const _SpeakButton({
    required this.size,
    required this.enabled,
    required this.speaking,
    required this.label,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = speaking ? AppColors.coral : AppColors.sky;
    final edge = speaking ? AppColors.coralDeep : AppColors.skyDeep;
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedOpacity(
          opacity: enabled ? 1 : 0.45,
          duration: const Duration(milliseconds: 200),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: edge, offset: const Offset(0, 4), blurRadius: 0)],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  speaking ? Icons.stop_rounded : Icons.volume_up_rounded,
                  color: Colors.white,
                  size: size * 0.42,
                ),
                Text(
                  label,
                  textScaler: TextScaler.noScaling,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: size * 0.17,
                    height: 1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
