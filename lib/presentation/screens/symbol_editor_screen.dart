import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../core/constants/system_ids.dart';
import '../../core/l10n/app_localizations.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/category_symbol_model.dart';
import '../../data/models/library_symbol_model.dart';
import '../../data/repositories/category_repository.dart';
import '../../data/repositories/category_symbol_repository.dart';
import '../../data/repositories/library_symbol_repository.dart';
import '../../data/services/audio_player_service.dart';
import '../widgets/aac_tile.dart';
import '../widgets/app_sheet.dart';
import '../widgets/media_pickers.dart';
import '../widgets/voice_recording_dialog.dart';

/// Dodawanie i edycja obrazka (symbolu) w folderze – jeden ekran dla obu
/// przypadków, z podglądem kafelka na żywo.
class SymbolEditorScreen extends ConsumerStatefulWidget {
  final String profileId;

  /// Folder docelowy przy dodawaniu (null = tablica startowa).
  final String? categoryId;

  /// Symbol do edycji (null = nowy).
  final String? symbolId;

  const SymbolEditorScreen({
    super.key,
    required this.profileId,
    this.categoryId,
    this.symbolId,
  });

  @override
  ConsumerState<SymbolEditorScreen> createState() => _SymbolEditorScreenState();
}

class _SymbolEditorScreenState extends ConsumerState<SymbolEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();

  CategorySymbolModel? _original;
  LibrarySymbolModel? _library;
  String? _imagePath;
  String? _emoji;
  bool _pictureChanged = false;
  Color _color = WordKind.misc.color;
  String? _voicePath;
  bool _loading = false;
  bool _saving = false;

  bool get _isEdit => widget.symbolId != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) _load();
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final symbolRepoFuture = ref.read(categorySymbolRepositoryProvider.future);
    final libraryRepoFuture = ref.read(librarySymbolRepositoryProvider.future);
    final symbolRepo = await symbolRepoFuture;
    final libraryRepo = await libraryRepoFuture;
    final symbol = await symbolRepo.getById(widget.symbolId!);
    final lib = symbol == null ? null : await libraryRepo.getById(symbol.librarySymbolId);
    if (!mounted) return;
    if (symbol == null) {
      showToast(context, AppLocalizations.of(context)!.symbolNotFound, error: true);
      context.pop();
      return;
    }
    setState(() {
      _original = symbol;
      _library = lib;
      _name.text = (symbol.nameOverride != null && symbol.nameOverride!.trim().isNotEmpty)
          ? symbol.nameOverride!
          : (lib?.name ?? '');
      _imagePath = (symbol.imagePathOverride?.isNotEmpty ?? false) ? symbol.imagePathOverride : null;
      _emoji = (symbol.emojiOverride?.isNotEmpty ?? false) ? symbol.emojiOverride : null;
      _color = Color(symbol.backgroundColor);
      _voicePath = symbol.voiceRecordingPath;
      _loading = false;
    });
  }

  // --- Podgląd -------------------------------------------------------------

  String? get _previewImage {
    if (_imagePath != null) return _imagePath;
    if (_emoji != null) return null;
    if (!_pictureChanged && _original != null) {
      final o = _original!.imagePathOverride;
      if (o != null) return o.isEmpty ? null : o;
    }
    return _library?.imagePath;
  }

  String? get _previewEmoji {
    if (_emoji != null) return _emoji;
    if (_imagePath != null) return null;
    if (!_pictureChanged && _original != null) {
      final o = _original!.emojiOverride;
      if (o != null) return o.isEmpty ? null : o;
    }
    return _library?.emoji;
  }

  // --- Wybór obrazka -------------------------------------------------------

  Future<void> _fromLibrary() async {
    final picked = await pickFromLibrary(context);
    if (picked == null || !mounted) return;
    setState(() {
      final previousLibName = _library?.name;
      _library = picked;
      _imagePath = null;
      _emoji = null;
      _pictureChanged = true;
      if (_name.text.trim().isEmpty || _name.text.trim() == previousLibName) {
        _name.text = picked.name;
      }
      if (picked.backgroundColor != null) _color = Color(picked.backgroundColor!);
    });
  }

  Future<void> _fromFiles() async {
    final l10n = AppLocalizations.of(context)!;
    try {
      final path = await pickImageFromFiles();
      if (path == null || !mounted) return;
      setState(() {
        _imagePath = path;
        _emoji = null;
        _pictureChanged = true;
      });
    } catch (e) {
      if (mounted) showToast(context, l10n.pickImageError(e.toString()), error: true);
    }
  }

  Future<void> _fromCamera() async {
    final l10n = AppLocalizations.of(context)!;
    try {
      final path = await pickImageFromCamera();
      if (path == null || !mounted) return;
      setState(() {
        _imagePath = path;
        _emoji = null;
        _pictureChanged = true;
      });
    } catch (e) {
      if (mounted) showToast(context, l10n.pickImageError(e.toString()), error: true);
    }
  }

  Future<void> _pickEmoji() async {
    final emoji = await pickEmoji(context, initial: _emoji);
    if (emoji == null || !mounted) return;
    setState(() {
      _emoji = emoji;
      _imagePath = null;
      _pictureChanged = true;
    });
  }

  // --- Nagranie --------------------------------------------------------------

  Future<void> _record() async {
    final path = await showDialog<String>(
      context: context,
      builder: (_) => VoiceRecordingDialog(existingRecordingPath: _voicePath),
    );
    if (path != null && mounted) setState(() => _voicePath = path);
  }

  // --- Zapis -----------------------------------------------------------------

  Future<int> _nextPosition(String targetCategoryId) async {
    final symbolRepo = await ref.read(categorySymbolRepositoryProvider.future);
    final categoryRepo = await ref.read(categoryRepositoryProvider.future);
    final symbols = SystemIds.isRoot(targetCategoryId)
        ? await symbolRepo.getRoot(targetCategoryId, includeLegacy: true)
        : await symbolRepo.getByCategoryId(targetCategoryId);
    final categories = await categoryRepo.getByParentId(
      widget.profileId,
      SystemIds.isRoot(targetCategoryId) ? null : targetCategoryId,
    );
    var maxPos = -1;
    for (final s in symbols) {
      if (s.position > maxPos) maxPos = s.position;
    }
    for (final c in categories) {
      if (c.position > maxPos) maxPos = c.position;
    }
    return maxPos + 1;
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context)!;
    if (!_formKey.currentState!.validate()) return;
    if (_previewImage == null && _previewEmoji == null) {
      showToast(context, l10n.selectSymbolFirst, error: true);
      return;
    }
    setState(() => _saving = true);
    try {
      final symbolRepo = await ref.read(categorySymbolRepositoryProvider.future);
      final libraryRepo = await ref.read(librarySymbolRepositoryProvider.future);
      final now = DateTime.now();
      final name = _name.text.trim();

      if (_isEdit && _original != null) {
        await _saveEdit(symbolRepo, libraryRepo, name, now);
      } else {
        await _saveNew(symbolRepo, libraryRepo, name, now);
      }
      if (!mounted) return;
      showToast(context, _isEdit ? l10n.symbolUpdated : l10n.symbolAddedToCategory);
      context.pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      showToast(context, l10n.error(e.toString()), error: true);
    }
  }

  Future<LibrarySymbolModel> _createLibrarySymbol(
    LibrarySymbolRepository repo,
    String name,
    DateTime now,
  ) async {
    final lib = LibrarySymbolModel(
      id: const Uuid().v4(),
      name: name,
      imagePath: _imagePath,
      emoji: _imagePath == null ? _emoji : null,
      tags: const [],
      isSystemDefault: false,
      isAnimated: _imagePath?.toLowerCase().endsWith('.gif') ?? false,
      createdAt: now,
      updatedAt: now,
      usageCount: 0,
    );
    await repo.create(lib);
    return lib;
  }

  Future<void> _saveNew(
    CategorySymbolRepository symbolRepo,
    LibrarySymbolRepository libraryRepo,
    String name,
    DateTime now,
  ) async {
    final target = widget.categoryId ?? SystemIds.rootOf(widget.profileId);
    LibrarySymbolModel lib;
    if (_library != null && _imagePath == null && _emoji == null) {
      lib = _library!;
    } else {
      lib = await _createLibrarySymbol(libraryRepo, name, now);
    }
    await symbolRepo.create(CategorySymbolModel(
      id: const Uuid().v4(),
      librarySymbolId: lib.id,
      categoryId: target,
      nameOverride: name != lib.name ? name : null,
      backgroundColor: _color.toARGB32(),
      voiceRecordingPath: _voicePath,
      position: await _nextPosition(target),
      createdAt: now,
      updatedAt: now,
    ));
  }

  Future<void> _saveEdit(
    CategorySymbolRepository symbolRepo,
    LibrarySymbolRepository libraryRepo,
    String name,
    DateTime now,
  ) async {
    final original = _original!;
    var lib = _library;
    lib ??= await _createLibrarySymbol(libraryRepo, name, now);

    String librarySymbolId = original.librarySymbolId;
    String? imageOverride = original.imagePathOverride;
    String? emojiOverride = original.emojiOverride;

    if (_pictureChanged) {
      librarySymbolId = lib.id;
      if (_imagePath != null) {
        imageOverride = _imagePath;
        emojiOverride = (lib.emoji?.isNotEmpty ?? false) ? '' : null;
      } else if (_emoji != null) {
        emojiOverride = _emoji;
        imageOverride = (lib.imagePath?.isNotEmpty ?? false) ? '' : null;
      } else {
        imageOverride = null;
        emojiOverride = null;
      }
    }

    await symbolRepo.update(original.copyWith(
      librarySymbolId: librarySymbolId,
      nameOverride: name != lib.name ? name : null,
      imagePathOverride: imageOverride,
      emojiOverride: emojiOverride,
      backgroundColor: _color.toARGB32(),
      voiceRecordingPath: _voicePath,
      updatedAt: now,
    ));
  }

  Future<void> _delete() async {
    final l10n = AppLocalizations.of(context)!;
    final ok = await showConfirmDialog(
      context,
      title: l10n.deleteSymbol,
      message: l10n.confirmDeleteSymbol(_name.text.trim()),
      confirmLabel: l10n.delete,
      cancelLabel: l10n.cancel,
      destructive: true,
      icon: Icons.delete_rounded,
    );
    if (!ok) return;
    final repo = await ref.read(categorySymbolRepositoryProvider.future);
    await repo.delete(widget.symbolId!);
    if (mounted) {
      showToast(context, l10n.symbolDeleted);
      context.pop();
    }
  }

  // --- UI ----------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final palette = context.aac;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? l10n.editSymbol : l10n.addSymbol),
        actions: [
          if (_isEdit)
            IconButton(
              tooltip: l10n.delete,
              onPressed: _delete,
              icon: const Icon(Icons.delete_outline_rounded, color: AppColors.coralDeep),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: EdgeInsets.fromLTRB(20, 4, 20, 32 + MediaQuery.paddingOf(context).bottom),
                children: [
                  Center(
                    child: SizedBox(
                      width: 150,
                      height: 172,
                      child: ValueListenableBuilder<TextEditingValue>(
                        valueListenable: _name,
                        builder: (context, value, _) => AacTile(
                          label: value.text.trim().isEmpty ? '…' : value.text.trim(),
                          imagePath: _previewImage,
                          emoji: _previewEmoji,
                          color: _color,
                          hasRecording: _voicePath != null,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _name,
                    textCapitalization: TextCapitalization.none,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                    decoration: InputDecoration(
                      labelText: l10n.symbolName,
                      hintText: l10n.symbolNameHint,
                      helperText: l10n.symbolNameHelper,
                    ),
                    validator: (v) {
                      final t = v?.trim() ?? '';
                      if (t.isEmpty) return l10n.nameRequired;
                      if (t.length > 40) return l10n.nameTooLong;
                      return null;
                    },
                  ),
                  SectionTitle(l10n.picture),
                  PictureSourceButtons(
                    onLibrary: _fromLibrary,
                    onFiles: _fromFiles,
                    onCamera: _fromCamera,
                    onEmoji: _pickEmoji,
                  ),
                  SectionTitle(l10n.backgroundColor),
                  TileColorPicker(selected: _color, onChanged: (c) => setState(() => _color = c)),
                  SectionTitle(l10n.voiceRecording),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: palette.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: palette.line, width: 1.5),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: (_voicePath != null ? AppColors.leaf : AppColors.inkSoft).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            _voicePath != null ? Icons.mic_rounded : Icons.mic_none_rounded,
                            color: _voicePath != null ? AppColors.leafDeep : palette.inkSoft,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _voicePath != null ? l10n.symbolHasOwnRecording : l10n.symbolUsesTts,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        if (_voicePath != null) ...[
                          IconButton(
                            tooltip: l10n.playRecording,
                            onPressed: () => ref.read(audioPlayerServiceProvider).play(_voicePath!),
                            icon: const Icon(Icons.play_arrow_rounded),
                          ),
                          IconButton(
                            tooltip: l10n.deleteRecording,
                            onPressed: () => setState(() => _voicePath = null),
                            icon: const Icon(Icons.delete_outline_rounded),
                          ),
                        ] else
                          TextButton(onPressed: _record, child: Text(l10n.recordVoice)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    height: 56,
                    child: FilledButton.icon(
                      onPressed: _saving ? null : _save,
                      icon: const Icon(Icons.check_rounded),
                      label: Text(_isEdit ? l10n.saveChanges : l10n.add),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
