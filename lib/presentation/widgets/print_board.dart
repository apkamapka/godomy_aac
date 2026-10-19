import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../core/l10n/app_localizations.dart';
import '../../core/theme/app_colors.dart';
import '../providers/board_provider.dart';
import 'app_sheet.dart';
import 'symbol_image.dart';

/// Wydruk tablicy: kafelki z obrazkami i podpisami jako PDF A4
/// (np. tablica papierowa na basen, do kąpieli, na wyjazd).
Future<void> showPrintBoardSheet(
  BuildContext context, {
  required String title,
  required List<BoardItem> items,
  required List<BoardItem> coreWords,
  required int initialColumns,
  String? Function(BoardItem item)? photoFor,
}) {
  final l10n = AppLocalizations.of(context)!;
  return showAppSheet<void>(
    context: context,
    title: l10n.printBoardTitle,
    icon: Icons.print_rounded,
    scrollable: true,
    builder: (_) => _PrintOptions(
      title: title,
      items: items,
      coreWords: coreWords,
      initialColumns: initialColumns,
      photoFor: photoFor,
    ),
  );
}

class _PrintOptions extends StatefulWidget {
  final String title;
  final List<BoardItem> items;
  final List<BoardItem> coreWords;
  final int initialColumns;
  final String? Function(BoardItem item)? photoFor;

  const _PrintOptions({
    required this.title,
    required this.items,
    required this.coreWords,
    required this.initialColumns,
    this.photoFor,
  });

  @override
  State<_PrintOptions> createState() => _PrintOptionsState();
}

class _PrintOptionsState extends State<_PrintOptions> {
  late int _columns = widget.initialColumns.clamp(2, 6);
  late bool _includeCore = widget.coreWords.isNotEmpty;
  bool _busy = false;

  Future<void> _generate() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _busy = true);
    try {
      final sections = <PrintSection>[
        if (_includeCore && widget.coreWords.isNotEmpty)
          PrintSection(l10n.coreWords, widget.coreWords),
        PrintSection(null, widget.items),
      ];
      final bytes = await buildBoardPdf(
        title: widget.title,
        sections: sections,
        columns: _columns,
        footer: 'godoMyAAC',
        photoFor: widget.photoFor,
      );
      final safe = widget.title.replaceAll(RegExp(r'[^\w\s-]', unicode: true), '').trim();
      final saved = await FilePicker.platform.saveFile(
        dialogTitle: l10n.printSavePdf,
        fileName: 'tablica_${safe.isEmpty ? 'godomyaac' : safe.replaceAll(' ', '_')}.pdf',
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        bytes: bytes,
      );
      if (!mounted) return;
      Navigator.pop(context);
      if (saved != null) showToast(context, l10n.printSaved);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      showToast(context, l10n.error(e.toString()), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final palette = context.aac;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.printBoardHint(widget.title),
          style: TextStyle(color: palette.inkSoft, fontWeight: FontWeight.w600),
        ),
        SectionTitle(l10n.printColumns, padding: const EdgeInsets.fromLTRB(4, 16, 4, 8)),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var c = 2; c <= 6; c++)
              ChoiceChip(
                label: Text('$c'),
                selected: _columns == c,
                onSelected: _busy ? null : (_) => setState(() => _columns = c),
              ),
          ],
        ),
        if (widget.coreWords.isNotEmpty) ...[
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.printIncludeCore),
            value: _includeCore,
            onChanged: _busy ? null : (v) => setState(() => _includeCore = v),
          ),
        ],
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _busy ? null : _generate,
          icon: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                )
              : const Icon(Icons.picture_as_pdf_rounded),
          label: Text(_busy ? l10n.printPreparing : l10n.printSavePdf),
        ),
      ],
    );
  }
}

// =============================================================================
// Tworzenie PDF (bez dodatkowych bibliotek): każda strona to obraz A4
// narysowany przez Fluttera (polskie litery, emoji i obrazki jak w aplikacji).
// =============================================================================

class PrintSection {
  final String? title;
  final List<BoardItem> items;
  const PrintSection(this.title, this.items);
}

// A4 przy 150 dpi.
const int _pageW = 1240;
const int _pageH = 1754;
const double _margin = 70;
const double _gap = 22;

Future<Uint8List> buildBoardPdf({
  required String title,
  required List<PrintSection> sections,
  required int columns,
  required String footer,
  String? Function(BoardItem item)? photoFor,
}) async {
  final cols = columns.clamp(1, 8);
  const contentW = _pageW - 2 * _margin;
  final tileW = (contentW - _gap * (cols - 1)) / cols;
  final tileH = tileW * 1.18;
  final pixelWidth = tileW.round().clamp(64, 1024);

  final images = <String, ui.Image?>{};
  Future<ui.Image?> imageFor(String? path) async {
    if (path == null || path.isEmpty) return null;
    if (images.containsKey(path)) return images[path];
    final image = await loadUiImage(path, targetWidth: pixelWidth);
    images[path] = image;
    return image;
  }

  final pages = <Uint8List>[];
  late ui.PictureRecorder recorder;
  late Canvas canvas;
  var y = 0.0;
  var pageNo = 0;

  void startPage() {
    pageNo++;
    recorder = ui.PictureRecorder();
    canvas = Canvas(recorder, Rect.fromLTWH(0, 0, _pageW.toDouble(), _pageH.toDouble()));
    canvas.drawRect(
      Rect.fromLTWH(0, 0, _pageW.toDouble(), _pageH.toDouble()),
      Paint()..color = Colors.white,
    );
    _drawText(
      canvas,
      '$footer · $pageNo',
      Offset(_margin, _pageH - _margin + 14),
      maxWidth: contentW,
      fontSize: 20,
      weight: FontWeight.w700,
      color: AppColors.inkSoft,
    );
    y = _margin;
  }

  Future<void> finishPage() async {
    final picture = recorder.endRecording();
    final image = await picture.toImage(_pageW, _pageH);
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    image.dispose();
    picture.dispose();
    if (data == null) throw StateError('PDF: nie udało się narysować strony');
    final rgba = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    pages.add(await _compressPage(rgba));
  }

  final bottomLimit = _pageH - _margin - 30;

  startPage();
  y += _drawText(canvas, title, Offset(_margin, y), maxWidth: contentW, fontSize: 46, weight: FontWeight.w900) + 18;

  for (final section in sections) {
    if (section.items.isEmpty) continue;
    if (section.title != null) {
      if (y + 50 + tileH > bottomLimit) {
        await finishPage();
        startPage();
      }
      y += _drawText(
            canvas,
            section.title!,
            Offset(_margin, y),
            maxWidth: contentW,
            fontSize: 30,
            weight: FontWeight.w800,
            color: AppColors.inkSoft,
          ) +
          10;
    }
    for (var i = 0; i < section.items.length; i += cols) {
      if (y + tileH > bottomLimit) {
        await finishPage();
        startPage();
      }
      for (var c = 0; c < cols && i + c < section.items.length; c++) {
        final item = section.items[i + c];
        final rect = Rect.fromLTWH(_margin + c * (tileW + _gap), y, tileW, tileH);
        final photo = photoFor?.call(item);
        final image = await imageFor(photo ?? item.imagePath);
        _drawTile(canvas, rect, item, image, cover: photo != null);
      }
      y += tileH + _gap;
    }
    y += 16;
  }
  await finishPage();

  for (final image in images.values) {
    image?.dispose();
  }
  return _assemblePdf(pages, _pageW, _pageH);
}

/// Rysuje tekst i zwraca jego wysokość.
double _drawText(
  Canvas canvas,
  String text,
  Offset at, {
  required double maxWidth,
  required double fontSize,
  required FontWeight weight,
  Color color = AppColors.ink,
  int maxLines = 2,
}) {
  final painter = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(fontFamily: 'Nunito', fontSize: fontSize, fontWeight: weight, color: color, height: 1.15),
    ),
    textDirection: TextDirection.ltr,
    maxLines: maxLines,
    ellipsis: '…',
  )..layout(maxWidth: maxWidth);
  painter.paint(canvas, at);
  final height = painter.height;
  painter.dispose();
  return height;
}

void _drawTile(Canvas canvas, Rect r, BoardItem item, ui.Image? image, {required bool cover}) {
  final color = item.color;
  final radius = Radius.circular(r.width * 0.09);
  final edge = AppColors.edgeFor(color);

  // „Brzeg” karty i sama karta.
  canvas.drawRRect(RRect.fromRectAndRadius(r.shift(const Offset(0, 6)), radius), Paint()..color = edge);
  final card = RRect.fromRectAndRadius(r, radius);
  canvas.drawRRect(card, Paint()..color = color);
  canvas.drawRRect(
    card,
    Paint()
      ..color = AppColors.outlineFor(color)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3,
  );

  final pad = r.width * 0.06;
  final labelH = r.height * 0.21;
  final window = Rect.fromLTRB(r.left + pad, r.top + pad, r.right - pad, r.bottom - labelH);
  final windowRRect = RRect.fromRectAndRadius(window, Radius.circular(r.width * 0.06));
  canvas.drawRRect(windowRRect, Paint()..color = Colors.white);

  if (image != null) {
    canvas.save();
    canvas.clipRRect(windowRRect);
    paintImage(
      canvas: canvas,
      rect: cover ? window : window.deflate(pad * 0.7),
      image: image,
      fit: cover ? BoxFit.cover : BoxFit.contain,
      filterQuality: FilterQuality.medium,
    );
    canvas.restore();
  } else if (item.emoji != null && item.emoji!.isNotEmpty) {
    final painter = TextPainter(
      text: TextSpan(text: item.emoji, style: TextStyle(fontSize: window.shortestSide * 0.62)),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, window.center - Offset(painter.width / 2, painter.height / 2));
    painter.dispose();
  }

  // Podpis – jedna linia, a gdy się nie mieści: dwie i mniejsza czcionka.
  final label = item.isFolder ? '${item.name} ›' : item.name;
  final labelWidth = r.width - 2 * pad;
  var fontSize = labelH * 0.5;
  TextPainter layoutLabel(double size, int lines) => TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            fontFamily: 'Nunito',
            fontSize: size,
            fontWeight: FontWeight.w800,
            color: AppColors.labelOn(color),
            height: 1.05,
          ),
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
        maxLines: lines,
        ellipsis: '…',
      )..layout(maxWidth: labelWidth);
  var painter = layoutLabel(fontSize, 1);
  if (painter.didExceedMaxLines) {
    painter.dispose();
    fontSize = labelH * 0.36;
    painter = layoutLabel(fontSize, 2);
  }
  painter.paint(
    canvas,
    Offset(r.left + (r.width - painter.width) / 2, window.bottom + (labelH - painter.height) / 2),
  );
  painter.dispose();
}

/// Kompresja w osobnym wątku (UI się nie zacina). Funkcja najwyższego
/// poziomu – domknięcie widzi tylko [rgba], a nie np. obiekty płótna.
Future<Uint8List> _compressPage(Uint8List rgba) => Isolate.run(() => _deflateRgb(rgba));

/// RGBA → RGB (strona jest nieprzezroczysta) i kompresja zlib (FlateDecode).
Uint8List _deflateRgb(Uint8List rgba) {
  final pixels = rgba.length ~/ 4;
  final rgb = Uint8List(pixels * 3);
  for (var p = 0, i = 0, o = 0; p < pixels; p++, i += 4, o += 3) {
    rgb[o] = rgba[i];
    rgb[o + 1] = rgba[i + 1];
    rgb[o + 2] = rgba[i + 2];
  }
  return Uint8List.fromList(zlib.encode(rgb));
}

/// Minimalny PDF 1.4: każda strona A4 z jednym obrazem na całą stronę.
Uint8List _assemblePdf(List<Uint8List> pages, int pixelWidth, int pixelHeight) {
  final out = BytesBuilder(copy: false);
  void write(String text) => out.add(latin1.encode(text));

  const w = '595.28';
  const h = '841.89';
  final n = pages.length;
  int pageObj(int i) => 3 + i * 3;
  int contentObj(int i) => 4 + i * 3;
  int imageObj(int i) => 5 + i * 3;
  final total = 2 + n * 3;
  final offsets = List<int>.filled(total + 1, 0);

  void begin(int number) {
    offsets[number] = out.length;
    write('$number 0 obj\n');
  }

  write('%PDF-1.4\n');
  out.add(const [0x25, 0xE2, 0xE3, 0xCF, 0xD3, 0x0A]);

  begin(1);
  write('<< /Type /Catalog /Pages 2 0 R >>\nendobj\n');
  begin(2);
  final kids = List.generate(n, (i) => '${pageObj(i)} 0 R').join(' ');
  write('<< /Type /Pages /Kids [$kids] /Count $n >>\nendobj\n');

  for (var i = 0; i < n; i++) {
    begin(pageObj(i));
    write('<< /Type /Page /Parent 2 0 R /MediaBox [0 0 $w $h] '
        '/Resources << /XObject << /Im0 ${imageObj(i)} 0 R >> >> '
        '/Contents ${contentObj(i)} 0 R >>\nendobj\n');

    const content = 'q $w 0 0 $h 0 0 cm /Im0 Do Q';
    begin(contentObj(i));
    write('<< /Length ${content.length} >>\nstream\n$content\nendstream\nendobj\n');

    begin(imageObj(i));
    write('<< /Type /XObject /Subtype /Image /Width $pixelWidth /Height $pixelHeight '
        '/ColorSpace /DeviceRGB /BitsPerComponent 8 /Filter /FlateDecode '
        '/Length ${pages[i].length} >>\nstream\n');
    out.add(pages[i]);
    write('\nendstream\nendobj\n');
  }

  final xref = out.length;
  write('xref\n0 ${total + 1}\n');
  write('0000000000 65535 f \n');
  for (var k = 1; k <= total; k++) {
    write('${offsets[k].toString().padLeft(10, '0')} 00000 n \n');
  }
  write('trailer\n<< /Size ${total + 1} /Root 1 0 R >>\nstartxref\n$xref\n%%EOF\n');
  return out.takeBytes();
}
