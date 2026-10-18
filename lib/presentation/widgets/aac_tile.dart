import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import 'symbol_image.dart';

/// Kafelek AAC w stylu laminowanej karty obrazkowej:
/// kolorowa ramka (klucz Fitzgeralda), białe okienko z obrazkiem i podpis.
/// Foldery mają „zakładkę” jak teczka.
class AacTile extends StatefulWidget {
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
  State<AacTile> createState() => _AacTileState();
}

class _AacTileState extends State<AacTile> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed != value && mounted) setState(() => _pressed = value);
  }

  void _handleTap() {
    final onTap = widget.onTap;
    if (onTap == null) return;
    final box = context.findRenderObject() as RenderBox?;
    final rect = (box != null && box.hasSize)
        ? box.localToGlobal(Offset.zero) & box.size
        : Rect.zero;
    onTap(rect);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth.isFinite ? constraints.maxWidth : 120.0;
        final h = constraints.maxHeight.isFinite ? constraints.maxHeight : w * 1.1;
        return Semantics(
          button: true,
          label: widget.isFolder ? '${widget.label}, folder' : widget.label,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: widget.onTap == null ? null : (_) => _setPressed(true),
            onTapUp: widget.onTap == null ? null : (_) => _setPressed(false),
            onTapCancel: () => _setPressed(false),
            onTap: widget.onTap == null ? null : _handleTap,
            onLongPress: widget.onLongPress,
            child: _buildTile(context, w, h),
          ),
        );
      },
    );
  }

  Widget _buildTile(BuildContext context, double w, double h) {
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
      duration: const Duration(milliseconds: 90),
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

    return AnimatedScale(
      scale: _pressed ? 0.965 : (widget.highlighted ? 1.03 : 1.0),
      duration: const Duration(milliseconds: 110),
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
