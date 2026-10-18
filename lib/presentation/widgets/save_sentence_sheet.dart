import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../core/constants/system_ids.dart';
import '../../core/l10n/app_localizations.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/category_symbol_model.dart';
import '../../data/models/library_symbol_model.dart';
import '../../data/repositories/category_symbol_repository.dart';
import '../../data/repositories/library_symbol_repository.dart';
import '../providers/sentence_provider.dart';
import 'app_sheet.dart';
import 'symbol_image.dart';

/// Zapis ułożonego zdania jako jednego kafelka (np. „chcę pić wodę”).
/// Obrazek kafelka to kolaż obrazków ze zdania.
Future<void> showSaveSentenceSheet(
  BuildContext context, {
  required String profileId,
  required String? categoryId,
  required int nextPosition,
  required String folderName,
}) async {
  await showAppSheet<void>(
    context: context,
    title: AppLocalizations.of(context)!.saveSentenceTitle,
    icon: Icons.bookmark_add_rounded,
    scrollable: true,
    builder: (_) => _SaveSentenceForm(
      profileId: profileId,
      categoryId: categoryId,
      nextPosition: nextPosition,
      folderName: folderName,
    ),
  );
}

class _SaveSentenceForm extends ConsumerStatefulWidget {
  final String profileId;
  final String? categoryId;
  final int nextPosition;
  final String folderName;

  const _SaveSentenceForm({
    required this.profileId,
    required this.categoryId,
    required this.nextPosition,
    required this.folderName,
  });

  @override
  ConsumerState<_SaveSentenceForm> createState() => _SaveSentenceFormState();
}

class _SaveSentenceFormState extends ConsumerState<_SaveSentenceForm> {
  late final TextEditingController _name;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: ref.read(sentenceProvider).text);
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context)!;
    final name = _name.text.trim();
    if (name.isEmpty) return;
    setState(() => _saving = true);
    try {
      final items = ref.read(sentenceProvider).items;
      final collage = await renderSentenceCollage(items);
      final libraryRepo = await ref.read(librarySymbolRepositoryProvider.future);
      final symbolRepo = await ref.read(categorySymbolRepositoryProvider.future);
      final now = DateTime.now();
      final lib = LibrarySymbolModel(
        id: const Uuid().v4(),
        name: name,
        imagePath: collage,
        emoji: collage == null ? '💬' : null,
        tags: const ['zdanie'],
        isSystemDefault: false,
        isAnimated: false,
        createdAt: now,
        updatedAt: now,
        usageCount: 0,
      );
      await libraryRepo.create(lib);
      await symbolRepo.create(CategorySymbolModel(
        id: const Uuid().v4(),
        librarySymbolId: lib.id,
        categoryId: widget.categoryId ?? SystemIds.rootOf(widget.profileId),
        backgroundColor: WordKind.social.argb,
        position: widget.nextPosition,
        createdAt: now,
        updatedAt: now,
      ));
      if (!mounted) return;
      Navigator.pop(context);
      showToast(context, l10n.sentenceSaved(name));
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      showToast(context, l10n.error(e.toString()), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final items = ref.watch(sentenceProvider).items;
    final palette = context.aac;
    final visuals = items
        .where((i) => (i.imagePath?.isNotEmpty ?? false) || (i.emoji?.isNotEmpty ?? false))
        .take(4)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          height: 92,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: WordKind.social.color,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              for (final v in visuals)
                // Flexible: 4 obrazki mieszczą się także na wąskim telefonie.
                Flexible(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Container(
                      width: 74,
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: palette.tileWindow,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: SymbolImage(imagePath: v.imagePath, emoji: v.emoji, cacheWidth: 200),
                    ),
                  ),
                ),
              if (visuals.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Text('💬', style: TextStyle(fontSize: 44)),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _name,
          textCapitalization: TextCapitalization.none,
          decoration: InputDecoration(labelText: l10n.tileName),
        ),
        const SizedBox(height: 10),
        Text(
          l10n.saveSentenceWhere(widget.folderName),
          style: TextStyle(color: palette.inkSoft, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 18),
        FilledButton.icon(
          onPressed: _saving ? null : _save,
          icon: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                )
              : const Icon(Icons.check_rounded),
          label: Text(l10n.save),
        ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// Kolaż
// -----------------------------------------------------------------------------

/// Rysuje do 4 obrazków zdania w kwadracie 512×512 i zapisuje jako PNG.
Future<String?> renderSentenceCollage(List<SentenceItem> items) async {
  final visuals = items
      .where((i) => (i.imagePath?.isNotEmpty ?? false) || (i.emoji?.isNotEmpty ?? false))
      .take(4)
      .toList();
  if (visuals.isEmpty) return null;

  const size = 512.0;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, size, size));
  final cells = _cells(visuals.length, size);

  for (var i = 0; i < visuals.length; i++) {
    final item = visuals[i];
    final cell = cells[i].deflate(12);
    final image = await _loadImage(item.imagePath);
    if (image != null) {
      paintImage(
        canvas: canvas,
        rect: cell,
        image: image,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
      );
      image.dispose();
    } else if (item.emoji != null && item.emoji!.isNotEmpty) {
      final painter = TextPainter(
        text: TextSpan(text: item.emoji, style: TextStyle(fontSize: cell.shortestSide * 0.7)),
        textDirection: TextDirection.ltr,
      )..layout();
      painter.paint(canvas, cell.center - Offset(painter.width / 2, painter.height / 2));
      painter.dispose();
    }
  }

  final picture = recorder.endRecording();
  final image = await picture.toImage(size.toInt(), size.toInt());
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  picture.dispose();
  if (data == null) return null;

  final docs = await getApplicationDocumentsDirectory();
  final dir = Directory('${docs.path}/sentences');
  if (!await dir.exists()) await dir.create(recursive: true);
  final file = File('${dir.path}/${const Uuid().v4()}.png');
  await file.writeAsBytes(data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes));
  return file.path;
}

List<Rect> _cells(int count, double s) {
  final h = s / 2;
  switch (count) {
    case 1:
      return [Rect.fromLTWH(0, 0, s, s)];
    case 2:
      return [Rect.fromLTWH(0, s * 0.25, h, h), Rect.fromLTWH(h, s * 0.25, h, h)];
    case 3:
      return [
        Rect.fromLTWH(0, 0, h, h),
        Rect.fromLTWH(h, 0, h, h),
        Rect.fromLTWH(s * 0.25, h, h, h),
      ];
    default:
      return [
        Rect.fromLTWH(0, 0, h, h),
        Rect.fromLTWH(h, 0, h, h),
        Rect.fromLTWH(0, h, h, h),
        Rect.fromLTWH(h, h, h, h),
      ];
  }
}

Future<ui.Image?> _loadImage(String? path) async {
  if (path == null || path.isEmpty) return null;
  try {
    Uint8List bytes;
    if (path.startsWith('assets/')) {
      final data = await rootBundle.load(resolveAssetPath(path));
      bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    } else {
      final file = File(path);
      if (!await file.exists()) return null;
      bytes = await file.readAsBytes();
    }
    final codec = await ui.instantiateImageCodec(bytes, targetWidth: 256);
    final frame = await codec.getNextFrame();
    codec.dispose();
    return frame.image;
  } catch (_) {
    return null;
  }
}
