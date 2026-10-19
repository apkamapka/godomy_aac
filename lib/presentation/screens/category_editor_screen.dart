import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../core/constants/system_ids.dart';
import '../../core/l10n/app_localizations.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/category_model.dart';
import '../../data/repositories/category_repository.dart';
import '../../data/repositories/category_symbol_repository.dart';
import '../widgets/aac_tile.dart';
import '../widgets/app_sheet.dart';
import '../widgets/media_pickers.dart';

/// Tworzenie i edycja folderu.
class CategoryEditorScreen extends ConsumerStatefulWidget {
  final String profileId;
  final String? categoryId;

  /// Folder nadrzędny dla nowego folderu (null = tablica startowa).
  final String? parentId;

  const CategoryEditorScreen({
    super.key,
    required this.profileId,
    this.categoryId,
    this.parentId,
  });

  @override
  ConsumerState<CategoryEditorScreen> createState() => _CategoryEditorScreenState();
}

class _CategoryEditorScreenState extends ConsumerState<CategoryEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();

  CategoryModel? _existing;
  String? _iconPath;
  String? _emoji;
  Color _color = WordKind.describe.color;
  CommunicationMode _mode = CommunicationMode.text;
  bool _loading = false;
  bool _saving = false;

  bool get _isEdit => widget.categoryId != null;

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
    final repo = await ref.read(categoryRepositoryProvider.future);
    final category = await repo.getById(widget.categoryId!);
    if (!mounted) return;
    if (category == null) {
      showToast(context, AppLocalizations.of(context)!.categoryNotFound, error: true);
      context.pop();
      return;
    }
    setState(() {
      _existing = category;
      _name.text = category.name;
      _iconPath = category.iconPath;
      _emoji = category.emoji;
      _color = Color(category.backgroundColor);
      _mode = category.communicationMode == CommunicationMode.direct
          ? CommunicationMode.direct
          : CommunicationMode.text;
      _loading = false;
    });
  }

  Future<void> _pickFiles() async {
    final l10n = AppLocalizations.of(context)!;
    try {
      final path = await pickImageFromFiles();
      if (path != null && mounted) {
        setState(() {
          _iconPath = path;
          _emoji = null;
        });
      }
    } catch (e) {
      if (mounted) showToast(context, l10n.pickImageError(e.toString()), error: true);
    }
  }

  Future<void> _pickCamera() async {
    final l10n = AppLocalizations.of(context)!;
    try {
      final path = await pickImageFromCamera();
      if (path != null && mounted) {
        setState(() {
          _iconPath = path;
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
        _iconPath = null;
      });
    }
  }

  Future<void> _pickFromLibrary() async {
    final picked = await pickFromLibrary(context);
    if (picked == null || !mounted) return;
    setState(() {
      _iconPath = picked.imagePath;
      _emoji = picked.imagePath == null ? picked.emoji : null;
      if (_name.text.trim().isEmpty) _name.text = picked.name;
    });
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context)!;
    if (!_formKey.currentState!.validate()) return;
    if ((_iconPath == null || _iconPath!.isEmpty) && (_emoji == null || _emoji!.isEmpty)) {
      showToast(context, l10n.iconRequired, error: true);
      return;
    }
    setState(() => _saving = true);
    try {
      final repo = await ref.read(categoryRepositoryProvider.future);
      final now = DateTime.now();
      final edge = AppColors.edgeFor(_color);
      if (_existing != null) {
        await repo.update(_existing!.copyWith(
          name: _name.text.trim(),
          iconPath: _iconPath,
          emoji: _emoji,
          backgroundColor: _color.toARGB32(),
          textColor: AppColors.labelOn(_color).toARGB32(),
          iconColor: edge.toARGB32(),
          communicationMode: _mode,
          updatedAt: now,
        ));
        if (!mounted) return;
        showToast(context, l10n.categoryUpdated);
      } else {
        // Nowy folder trafia na koniec (za istniejące foldery i obrazki).
        final siblings = await repo.getByParentId(widget.profileId, widget.parentId);
        final symbolRepo = await ref.read(categorySymbolRepositoryProvider.future);
        final symbols = widget.parentId == null
            ? await symbolRepo.getRoot(SystemIds.rootOf(widget.profileId), includeLegacy: true)
            : await symbolRepo.getByCategoryId(widget.parentId);
        var maxPos = -1;
        for (final c in siblings) {
          if (c.position > maxPos) maxPos = c.position;
        }
        for (final s in symbols) {
          if (s.position > maxPos) maxPos = s.position;
        }
        await repo.create(CategoryModel(
          id: const Uuid().v4(),
          name: _name.text.trim(),
          iconPath: _iconPath,
          emoji: _emoji,
          backgroundColor: _color.toARGB32(),
          textColor: AppColors.labelOn(_color).toARGB32(),
          iconColor: edge.toARGB32(),
          communicationMode: _mode,
          gridConfig: GridConfig(columns: 3, rows: 4),
          scrollLocked: false,
          position: maxPos + 1,
          profileId: widget.profileId,
          parentId: widget.parentId,
          createdAt: now,
          updatedAt: now,
        ));
        if (!mounted) return;
        showToast(context, l10n.categoryCreated);
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
    final isSystem = _existing != null && SystemIds.isSystemParent(_existing!.parentId);

    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? l10n.editCategory : l10n.newCategory)),
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
                      height: 180,
                      child: ValueListenableBuilder<TextEditingValue>(
                        valueListenable: _name,
                        builder: (context, value, _) => AacTile(
                          label: value.text.trim().isEmpty ? '…' : value.text.trim(),
                          imagePath: _iconPath,
                          emoji: _emoji,
                          color: _color,
                          isFolder: true,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _name,
                    textCapitalization: TextCapitalization.sentences,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                    decoration: InputDecoration(
                      labelText: l10n.categoryName,
                      hintText: l10n.categoryNameHint,
                    ),
                    validator: (v) {
                      final t = v?.trim() ?? '';
                      if (t.isEmpty) return l10n.nameRequired;
                      if (t.length > 40) return l10n.nameTooLong;
                      return null;
                    },
                  ),
                  if (!isSystem) ...[
                    SectionTitle(l10n.picture),
                    PictureSourceButtons(
                      onLibrary: _pickFromLibrary,
                      onFiles: _pickFiles,
                      onCamera: _pickCamera,
                      onEmoji: _pickEmoji,
                    ),
                    SectionTitle(l10n.backgroundColor),
                    TileColorPicker(selected: _color, onChanged: (c) => setState(() => _color = c)),
                  ],
                  SectionTitle(l10n.tapBehavior),
                  Container(
                    decoration: BoxDecoration(
                      color: palette.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: palette.line, width: 1.5),
                    ),
                    child: Column(
                      children: [
                        _ModeTile(
                          selected: _mode == CommunicationMode.text,
                          icon: Icons.chat_bubble_rounded,
                          title: l10n.modeSentence,
                          subtitle: l10n.modeSentenceDesc,
                          onTap: () => setState(() => _mode = CommunicationMode.text),
                        ),
                        _ModeTile(
                          selected: _mode == CommunicationMode.direct,
                          icon: Icons.campaign_rounded,
                          title: l10n.modeDirect,
                          subtitle: l10n.modeDirectDesc,
                          onTap: () => setState(() => _mode = CommunicationMode.direct),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    height: 56,
                    child: FilledButton.icon(
                      onPressed: _saving ? null : (isSystem ? _saveSystem : _save),
                      icon: const Icon(Icons.check_rounded),
                      label: Text(_isEdit ? l10n.saveChanges : l10n.createCategory),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  /// Tablice systemowe mają tylko nazwę i tryb (bez obrazka).
  Future<void> _saveSystem() async {
    final l10n = AppLocalizations.of(context)!;
    if (!_formKey.currentState!.validate()) return;
    final repo = await ref.read(categoryRepositoryProvider.future);
    await repo.update(_existing!.copyWith(
      name: _name.text.trim(),
      communicationMode: _mode,
      updatedAt: DateTime.now(),
    ));
    if (!mounted) return;
    showToast(context, l10n.categoryUpdated);
    context.pop();
  }
}

class _ModeTile extends StatelessWidget {
  final bool selected;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ModeTile({
    required this.selected,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: selected ? AppColors.sky : context.aac.inkSoft),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: Icon(
        selected ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded,
        color: selected ? AppColors.sky : context.aac.inkSoft,
      ),
    );
  }
}
