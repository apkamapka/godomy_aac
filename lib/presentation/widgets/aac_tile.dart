import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../data/services/app_settings.dart';
import '../providers/caregiver_provider.dart';
import 'symbol_image.dart';

/// Kafelek AAC w stylu laminowanej karty obrazkowej:
/// kolorowa ramka (klucz Fitzgeralda), białe okienko z obrazkiem i podpis.
/// Foldery mają „zakładkę” jak teczka.
class AacTile extends ConsumerStatefulWidget {
  final String label;
  final String? imagePath;
  final String? emoji;
  final Color color;
  final bool isFolder;
  final bool hasRecording;
  final bool showEdit;
  final bool showDelete;
  final bool highlighted;
  final bool dense;
  final BoxFit imageFit;

  /// Wywoływane z prostokątem kafelka (współrzędne globalne) – potrzebne do
  /// animacji „wlatywania” obrazka do paska zdania.
  final void Function(Rect globalRect)? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const AacTile({
    super.key,
    required this.label,
    required this.color,
    this.imagePath,
    this.emoji,
    this.isFolder = false,
    this.hasRecording = false,
    this.showEdit = false,
    this.showDelete = false,
    this.highlighted = false,
    this.dense = false,
    this.imageFit = BoxFit.contain,
    this.onTap,
    this.onLongPress,
    this.onEdit,
    this.onDelete,
  });

  @override
  ConsumerState<AacTile> createState() => _AacTileState();
}

class _AacTileState extends ConsumerState<AacTile> with SingleTickerProviderStateMixin {
  bool _pressed = false;

  /// Postęp przytrzymania (ochrona przed przypadkowym dotykiem).
  AnimationController? _hold;
  bool _holdFired = false;

  @override
  void dispose() {
    _hold?.dispose();
    super.dispose();
  }

  void _setPressed(bool value) {
    if (_pressed != value && mounted) setState(() => _pressed = value);
  }

  /// Przytrzymanie działa tylko u dziecka (w trybie opiekuna przytrzymanie
  /// otwiera edycję).
  int get _holdMs {
    if (widget.onTap == null || ref.read(caregiverModeProvider)) return 0;
    return ref.read(activeProfileSettingsProvider).holdMs;
  }

  AnimationController _holdController(int ms) {
    final controller = _hold ??= AnimationController(vsync: this)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed && !_holdFired) {
          _holdFired = true;
          _activate();
          _hold?.reset();
          _setPressed(false);
        }
      });
    controller.duration = Duration(milliseconds: ms);
    return controller;
  }

  void _onTapDown(TapDownDetails _) {
    _setPressed(true);
    final ms = _holdMs;
    if (ms > 0) {
      _holdFired = false;
      _holdController(ms).forward(from: 0);
    }
  }

  void _onTapEnd() {
    _setPressed(false);
    final hold = _hold;
    if (hold != null && hold.value > 0) hold.reset();
  }

  void _onTap() {
    if (_holdMs > 0) return; // przy przytrzymaniu kafelek działa sam po czasie
    _activate();
  }

  void _activate() {
    final onTap = widget.onTap;
    if (onTap == null || !mounted) return;
    if (!ref.read(caregiverModeProvider)) {
      final guardMs = ref.read(activeProfileSettingsProvider).repeatGuardMs;
      if (!ref.read(touchGuardProvider).tryActivate(guardMs)) return;
    }
    final box = context.findRenderObject() as RenderBox?;
    final rect = (box != null && box.hasSize)
        ? box.localToGlobal(Offset.zero) & box.size
        : Rect.zero;
    onTap(rect);
  }

  @override
  Widget build(BuildContext context) {
    final animations = ref.watch(activeProfileSettingsProvider.select((s) => s.animations));
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth.isFinite ? constraints.maxWidth : 120.0;
        final h = constraints.maxHeight.isFinite ? constraints.maxHeight : w * 1.1;
        return Semantics(
          button: true,
          label: widget.isFolder ? '${widget.label}, folder' : widget.label,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: widget.onTap == null ? null : _onTapDown,
            onTapUp: widget.onTap == null ? null : (_) => _onTapEnd(),
            onTapCancel: _onTapEnd,
            onTap: widget.onTap == null ? null : _onTap,
            onLongPress: widget.onLongPress,
            child: _buildTile(context, w, h, animations),
          ),
        );
      },
    );
  }

  Widget _buildTile(BuildContext context, double w, double h, bool animations) {
    final color = widget.color;
    final edge = AppColors.edgeFor(color);
    final outline = AppColors.outlineFor(color);
    final shortest = w < h ? w : h;
    final radius = (shortest * 0.14).clamp(10.0, 22.0);
    final edgeDepth = widget.dense ? 3.0 : 4.0;
    final pressedDepth = 1.0;
    final depth = _pressed ? pressedDepth : edgeDepth;

    final tabHeight = widget.isFolder ? (h * 0.07).clamp(7.0, 14.0) : 0.0;
    final cardTop = widget.isFolder ? tabHeight * 0.7 : 0.0;
    final cardHeight = h - cardTop - edgeDepth;
    final pad = (shortest * 0.055).clamp(3.0, 8.0);
    final borderWidth = widget.highlighted ? 3.5 : 2.0;

    final card = AnimatedContainer(
      duration: animations ? const Duration(milliseconds: 90) : Duration.zero,
      curve: Curves.easeOut,
      transform: Matrix4.translationValues(0, edgeDepth - depth, 0),
      height: cardHeight,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: widget.highlighted ? AppColors.sky : outline,
          width: borderWidth,
        ),
        boxShadow: [
          BoxShadow(color: edge, offset: Offset(0, depth), blurRadius: 0),
          if (widget.highlighted)
            BoxShadow(
              color: AppColors.sky.withValues(alpha: 0.35),
              blurRadius: 14,
              spreadRadius: 2,
            ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(pad, pad, pad, 0),
      // Container dolicza grubość ramki do paddingu – uwzględniamy ją w szerokości.
      child: _content(
        context,
        w - pad * 2 - borderWidth * 2,
        cardHeight - pad - borderWidth * 2,
        radius - pad * 0.6,
      ),
    );

    final hold = _hold;
    final scale = !animations ? 1.0 : (_pressed ? 0.965 : (widget.highlighted ? 1.03 : 1.0));

    return AnimatedScale(
      scale: scale,
      duration: animations ? const Duration(milliseconds: 110) : Duration.zero,
      curve: Curves.easeOut,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          if (widget.isFolder)
            Positioned(
              top: 0,
              left: w * 0.08,
              width: w * 0.42,
              height: tabHeight + radius,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: edge,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(tabHeight)),
                ),
              ),
            ),
          Positioned(left: 0, right: 0, top: cardTop, child: card),
          // Postęp przytrzymania – kafelek „napełnia się” od dołu.
          if (hold != null)
            Positioned(
              left: 0,
              right: 0,
              top: cardTop,
              height: cardHeight,
              child: IgnorePointer(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(radius),
                  child: AnimatedBuilder(
                    animation: hold,
                    builder: (context, _) => Align(
                      alignment: Alignment.bottomCenter,
                      child: FractionallySizedBox(
                        widthFactor: 1,
                        heightFactor: hold.value,
                        child: ColoredBox(color: AppColors.sky.withValues(alpha: 0.35)),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          if (widget.showEdit && widget.onEdit != null)
            Positioned(
              top: cardTop - 10,
              right: -10,
              child: CornerBadge(
                icon: Icons.edit_rounded,
                color: AppColors.sky,
                edge: AppColors.skyDeep,
                size: widget.dense ? 24 : 30,
                onTap: widget.onEdit,
              ),
            ),
          if (widget.showDelete && widget.onDelete != null)
            Positioned(
              top: cardTop - 10,
              left: -10,
              child: CornerBadge(
                icon: Icons.close_rounded,
                color: AppColors.coralDeep,
                edge: const Color(0xFFA8362A),
                size: widget.dense ? 24 : 30,
                onTap: widget.onDelete,
              ),
            ),
        ],
      ),
    );
  }

  Widget _content(BuildContext context, double innerW, double innerH, double windowRadius) {
    final label = _LabelFit.compute(
      context,
      widget.label,
      maxWidth: innerW,
      tileWidth: innerW,
      dense: widget.dense,
      isFolder: widget.isFolder,
    );
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final windowColor = context.aac.tileWindow;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: windowColor,
              borderRadius: BorderRadius.circular(windowRadius.clamp(6.0, 18.0)),
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Padding(
                  padding: widget.imageFit == BoxFit.cover
                      ? EdgeInsets.zero
                      : EdgeInsets.all((innerW * 0.06).clamp(2.0, 10.0)),
                  child: SymbolImage(
                    imagePath: widget.imagePath,
                    emoji: widget.emoji,
                    fit: widget.imageFit,
                    cacheWidth: (innerW * dpr).round().clamp(64, 1024),
                    fallbackIcon: widget.isFolder ? Icons.folder_rounded : Icons.image_outlined,
                  ),
                ),
                if (widget.hasRecording)
                  Positioned(
                    right: 4,
                    bottom: 4,
                    child: Container(
                      width: widget.dense ? 16 : 22,
                      height: widget.dense ? 16 : 22,
                      decoration: const BoxDecoration(color: AppColors.leaf, shape: BoxShape.circle),
                      child: Icon(Icons.mic_rounded, size: widget.dense ? 11 : 14, color: Colors.white),
                    ),
                  ),
              ],
            ),
          ),
        ),
        SizedBox(
          height: label.height,
          child: Center(
            child: Text(
              widget.isFolder ? '${widget.label} ›' : widget.label,
              textAlign: TextAlign.center,
              maxLines: label.lines,
              overflow: TextOverflow.ellipsis,
              textScaler: TextScaler.noScaling,
              style: TextStyle(
                fontSize: label.fontSize,
                fontWeight: FontWeight.w800,
                height: 1.05,
                color: AppColors.labelOn(widget.color),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Dobór wielkości podpisu do kafelka: jedna linia, a gdy się nie mieści
/// – dwie linie i ewentualnie mniejsza czcionka.
class _LabelFit {
  final double fontSize;
  final int lines;
  final double height;

  const _LabelFit(this.fontSize, this.lines, this.height);

  static _LabelFit compute(
    BuildContext context,
    String text, {
    required double maxWidth,
    required double tileWidth,
    required bool dense,
    required bool isFolder,
  }) {
    final shown = isFolder ? '$text ›' : text;
    final maxSize = dense ? 15.0 : 24.0;
    final minSize = dense ? 9.0 : 10.0;
    var size = (tileWidth * (dense ? 0.17 : 0.135)).clamp(minSize, maxSize);
    final width = maxWidth <= 0 ? 1.0 : maxWidth;

    TextPainter painter(double fs, int lines) {
      return TextPainter(
        text: TextSpan(
          text: shown,
          style: TextStyle(fontSize: fs, fontWeight: FontWeight.w800, height: 1.05, fontFamily: 'Nunito'),
        ),
        textDirection: TextDirection.ltr,
        maxLines: lines,
      )..layout(maxWidth: width);
    }

    var p = painter(size, 1);
    final fitsOneLine = !p.didExceedMaxLines;
    p.dispose();
    if (fitsOneLine) {
      return _LabelFit(size, 1, size * 1.05 + (dense ? 6 : 10));
    }
    // Dwie linie, w razie potrzeby mniejsza czcionka.
    while (size > minSize) {
      p = painter(size, 2);
      final ok = !p.didExceedMaxLines;
      p.dispose();
      if (ok) break;
      size -= 1;
    }
    return _LabelFit(size, 2, size * 2.1 + (dense ? 6 : 10));
  }
}
