import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Przeliczenie siatki dla orientacji poziomej: kafelki byłyby zbyt płaskie,
/// więc w poziomie dwa razy więcej kolumn i o połowę mniej wierszy.
class BoardGridLayout {
  BoardGridLayout._();

  static bool isLandscape(Size size) => size.width > size.height * 1.15;

  static (int, int) effective(int columns, int rows, Size screen) {
    final c = columns.clamp(1, 8);
    final r = rows.clamp(1, 10);
    if (!isLandscape(screen)) return (c, r);
    return (math.min(8, c * 2), math.max(1, (r / 2).ceil()));
  }
}

/// Siatka kafelków wypełniająca dostępne miejsce: `rows` wierszy na ekran,
/// a gdy elementów jest więcej – przewijanie.
class BoardGrid extends StatelessWidget {
  final int columns;
  final int rows;
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final EdgeInsets padding;
  final double spacing;
  final double minTileHeight;

  /// Czy w poziomie podwajać kolumny (tablice tak; arkusze z gotowym układem nie).
  final bool adaptToLandscape;

  /// Buduje od razu wszystkie kafelki (także niewidoczne) – potrzebne przy
  /// skanowaniu, które przechodzi po wszystkich elementach.
  final bool buildAll;

  const BoardGrid({
    super.key,
    required this.columns,
    required this.rows,
    required this.itemCount,
    required this.itemBuilder,
    this.padding = const EdgeInsets.fromLTRB(12, 6, 12, 12),
    this.spacing = 10,
    this.minTileHeight = 84,
    this.adaptToLandscape = true,
    this.buildAll = false,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final (cols, rws) = adaptToLandscape
            ? BoardGridLayout.effective(columns, rows, MediaQuery.sizeOf(context))
            : (columns, rows);
        final availableH = constraints.maxHeight.isFinite
            ? constraints.maxHeight - padding.vertical
            : 600.0;
        final tileH = math.max(minTileHeight, (availableH - spacing * (rws - 1)) / rws);
        return GridView.builder(
          padding: padding,
          cacheExtent: buildAll ? 100000 : null,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            mainAxisSpacing: spacing,
            crossAxisSpacing: spacing,
            mainAxisExtent: tileH,
          ),
          itemCount: itemCount,
          itemBuilder: itemBuilder,
        );
      },
    );
  }
}

/// Pasek słów kluczowych (stałe miejsca na tablicy startowej).
class CoreWordsBand extends StatelessWidget {
  final int itemCount;
  final Widget Function(BuildContext context, int index) itemBuilder;
  final Widget? trailing;

  const CoreWordsBand({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    if (itemCount == 0 && trailing == null) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, constraints) {
        const hPad = 12.0;
        const gap = 7.0;
        final width = constraints.maxWidth - hPad * 2;
        final screen = MediaQuery.sizeOf(context);
        final landscape = BoardGridLayout.isLandscape(screen);
        final cols = (width / 84).floor().clamp(4, 8);
        final tileW = (width - gap * (cols - 1)) / cols;
        final tileH = landscape
            ? (tileW * 0.82).clamp(60.0, 84.0)
            : (tileW * 0.98).clamp(64.0, 104.0);
        final total = itemCount + (trailing != null ? 1 : 0);
        final rowCount = math.min(3, (total / cols).ceil());

        final rowWidgets = <Widget>[];
        for (var r = 0; r < rowCount; r++) {
          final cells = <Widget>[];
          for (var c = 0; c < cols; c++) {
            final index = r * cols + c;
            Widget cell;
            if (index < itemCount) {
              cell = itemBuilder(context, index);
            } else if (index == itemCount && trailing != null) {
              cell = trailing!;
            } else {
              cell = const SizedBox.shrink();
            }
            if (c > 0) cells.add(const SizedBox(width: gap));
            cells.add(Expanded(child: SizedBox(height: tileH, child: cell)));
          }
          if (r > 0) rowWidgets.add(const SizedBox(height: gap));
          rowWidgets.add(Row(children: cells));
        }
        return Padding(
          padding: const EdgeInsets.fromLTRB(hPad, 0, hPad, 8),
          child: Column(mainAxisSize: MainAxisSize.min, children: rowWidgets),
        );
      },
    );
  }
}
