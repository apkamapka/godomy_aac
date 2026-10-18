import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../core/l10n/app_localizations.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/library_symbol_model.dart';
import '../../data/repositories/library_symbol_repository.dart';
import '../widgets/aac_tile.dart';
import '../widgets/app_sheet.dart';
import '../widgets/media_pickers.dart';

/// Dodawanie i edycja obrazka w bibliotece (bez przypisania do folderu).
class LibrarySymbolEditorScreen extends ConsumerStatefulWidget {
  final String? symbolId;
  const LibrarySymbolEditorScreen({super.key, this.symbolId});

  @override
  ConsumerState<LibrarySymbolEditorScreen> createState() => _LibrarySymbolEditorScreenState();
}

class _LibrarySymbolEditorScreenState extends ConsumerState<LibrarySymbolEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();

  LibrarySymbolModel? _existing;
  String? _imagePath;
  String? _emoji;
  Color? _color;
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
    final repo = await ref.read(librarySymbolRepositoryProvider.future);
    final symbol = await repo.getById(widget.symbolId!);
    if (!mounted) return;
    if (symbol == null) {
      showToast(context, AppLocalizations.of(context)!.librarySymbolNotFound, error: true);
      context.pop();
      return;
    }
    setState(() {
      _existing = symbol;
      _name.text = symbol.name;
      _imagePath = symbol.imagePath;
      _emoji = symbol.emoji;
      _color = symbol.backgroundColor != null ? Color(symbol.backgroundColor!) : null;
      _loading = false;
    });
  }

  Future<void> _pick(Future<String?> Function() picker) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      final path = await picker();
      if (path != null && mounted) {
        setState(() {
          _imagePath = path;
          _emoji = null;
        });
      }
    } catch (e) {
      if (mounted) showToast(context, l10n.pickImageError(e.toString()), error: true);
    }
  }

  Future<void> _pickEmoji() async {
    final emoji = await pickEmoji(context, initial: _emoji);
    if (emoji != null && mounted) {
      setState(() {
        _emoji = emoji;
        _imagePath = null;
      });
    }
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context)!;
    if (!_formKey.currentState!.validate()) return;
    if (_imagePath == null && _emoji == null) {
      showToast(context, l10n.iconRequired, error: true);
      return;
    }
    setState(() => _saving = true);
    try {
      final repo = await ref.read(librarySymbolRepositoryProvider.future);
      final now = DateTime.now();
      if (_existing != null) {
        await repo.update(_existing!.copyWith(
          name: _name.text.trim(),
          imagePath: _imagePath,
          emoji: _emoji,
          backgroundColor: _color?.toARGB32(),
          isAnimated: _imagePath?.toLowerCase().endsWith('.gif') ?? false,
          updatedAt: now,
        ));
        if (!mounted) return;
        showToast(context, l10n.symbolUpdated);
      } else {
        await repo.create(LibrarySymbolModel(
          id: const Uuid().v4(),
          name: _name.text.trim(),
          imagePath: _imagePath,
          emoji: _emoji,
          backgroundColor: _color?.toARGB32(),
          isAnimated: _imagePath?.toLowerCase().endsWith('.gif') ?? false,
          isSystemDefault: false,
          createdAt: now,
          updatedAt: now,
          usageCount: 0,
        ));
        if (!mounted) return;
        showToast(context, l10n.symbolCreated);
      }
      context.pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      showToast(context, l10n.error(e.toString()), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final palette = context.aac;

    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? l10n.editSymbol : l10n.addSymbol)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
                children: [
                  Center(
                    child: SizedBox(
                      width: 150,
                      height: 172,
                      child: ValueListenableBuilder<TextEditingValue>(
                        valueListenable: _name,
                        builder: (context, value, _) => AacTile(
                          label: value.text.trim().isEmpty ? '…' : value.text.trim(),
                          imagePath: _imagePath,
                          emoji: _emoji,
                          color: _color ?? palette.surface,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _name,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                    decoration: InputDecoration(
                      labelText: l10n.symbolName,
                      hintText: l10n.symbolNameHint,
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
                    onFiles: () => _pick(pickImageFromFiles),
                    onCamera: () => _pick(pickImageFromCamera),
                    onEmoji: _pickEmoji,
                  ),
                  SectionTitle(l10n.defaultColor),
                  TileColorPicker(
                    selected: _color ?? Colors.transparent,
                    onChanged: (c) => setState(() => _color = c),
                  ),
                  if (_color != null)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: () => setState(() => _color = null),
                        child: Text(l10n.noDefaultColor),
                      ),
                    ),
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 56,
                    child: FilledButton.icon(
                      onPressed: _saving ? null : _save,
                      icon: const Icon(Icons.check_rounded),
                      label: Text(_isEdit ? l10n.saveChanges : l10n.add),
                    ),
                  ),
                  if (_isEdit && (_existing?.isSystemDefault ?? false))
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        l10n.systemSymbolEditable,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: palette.inkSoft, fontWeight: FontWeight.w600),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}
