import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
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
import '../../data/services/sentence_store.dart';
import '../providers/sentence_provider.dart';
import 'app_sheet.dart';
import 'symbol_image.dart';

/// Zapis ułożonego zdania: do „Moich zdań” (gotowe na później) albo jako
/// jeden kafelek na tablicy (np. „chcę pić wodę”, obrazek = kolaż).
Future<void> showSaveSentenceSheet(
  BuildContext context, {
  required String profileId,
  required String? categoryId,
  required int nextPosition,
  required String folderName,
  bool allowMySentences = true,
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
      allowMySentences: allowMySentences,
    ),
  );
}

enum _SaveTarget { mySentences, tile }

class _SaveSentenceForm extends ConsumerStatefulWidget {
  final String profileId;
  final String? categoryId;
  final int nextPosition;
  final String folderName;
  final bool allowMySentences;

  const _SaveSentenceForm({
    required this.profileId,
    required this.categoryId,
    required this.nextPosition,
    required this.folderName,
    required this.allowMySentences,
  });

  @override
  ConsumerState<_SaveSentenceForm> createState() => _SaveSentenceFormState();
}

class _SaveSentenceFormState extends ConsumerState<_SaveSentenceForm> {
  late final TextEditingController _name;
  late _SaveTarget _target;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: ref.read(sentenceProvider).text);
    _target = widget.allowMySentences ? _SaveTarget.mySentences : _SaveTarget.tile;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_target == _SaveTarget.mySentences) {
      await _saveToMySentences();
    } else {
      await _saveAsTile();
    }
  }

  Future<void> _saveToMySentences() async {
    final l10n = AppLocalizations.of(context)!;
    final items = ref.read(sentenceProvider).items;
    final added = await ref.read(savedSentencesProvider(widget.profileId).notifier).add(items);
    if (!mounted) return;
    Navigator.pop(context);
    showToast(context, added ? l10n.sentenceSavedToMine : l10n.sentenceAlreadySaved);
  }

  Future<void> _saveAsTile() async {
    final l10n = AppLocalizations.of(context)!;
    final name = _name.text.trim();
    if (name.isEmpty) return;
    setState(() => _saving = true);
    try {
      final items = ref.read(sentenceProvider).items;
      final libraryRepoFuture = ref.read(librarySymbolRepositoryProvider.future);
      final symbolRepoFuture = ref.read(categorySymbolRepositoryProvider.future);
      final collage = await renderSentenceCollage(items);
      final libraryRepo = await libraryRepoFuture;
      final symbolRepo = await symbolRepoFuture;
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
                  child: Icon(Icons.chat_rounded, size: 44, color: AppColors.ink),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          ref.read(sentenceProvider).text,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
        ),
        if (widget.allowMySentences) ...[
          const SizedBox(height: 14),
          SegmentedButton<_SaveTarget>(
            showSelectedIcon: false,
            segments: [
              ButtonSegment(
                value: _SaveTarget.mySentences,
                icon: const Icon(Icons.forum_rounded),
                label: Text(l10n.mySentences),
              ),
              ButtonSegment(
                value: _SaveTarget.tile,
                icon: const Icon(Icons.crop_square_rounded),
                label: Text(l10n.saveAsTileOption),
              ),
            ],
            selected: {_target},
            onSelectionChanged: (s) => setState(() => _target = s.first),
          ),
        ],
        const SizedBox(height: 12),
        if (_target == _SaveTarget.mySentences)
          Text(
            l10n.saveToMineHint,
            style: TextStyle(color: palette.inkSoft, fontWeight: FontWeight.w700),
          )
        else ...[
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
        ],
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
    final image = await loadUiImage(item.imagePath);
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
