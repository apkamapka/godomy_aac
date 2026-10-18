import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/l10n/app_localizations.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/library_symbol_model.dart';
import '../providers/library_symbols_provider.dart';
import 'app_sheet.dart';
import 'symbol_image.dart';

// =============================================================================
// Obrazki z telefonu
// =============================================================================

Future<String> _userImagesDir() async {
  final docs = await getApplicationDocumentsDirectory();
  final dir = Directory('${docs.path}/user_images');
  if (!await dir.exists()) await dir.create(recursive: true);
  return dir.path;
}

/// Obrazek lub GIF z galerii/plików. Zwraca ścieżkę kopii w katalogu aplikacji.
Future<String?> pickImageFromFiles() async {
  final result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: ['gif', 'jpg', 'jpeg', 'png', 'webp'],
    allowMultiple: false,
  );
  final path = result?.files.single.path;
  if (path == null) return null;
  final ext = path.contains('.') ? path.split('.').last.toLowerCase() : 'jpg';
  final target = '${await _userImagesDir()}/img_${DateTime.now().millisecondsSinceEpoch}.$ext';
  await File(path).copy(target);
  return target;
}

/// Zdjęcie z aparatu (od razu zmniejszone – szybsza tablica, mniej miejsca).
Future<String?> pickImageFromCamera() async {
  final picked = await ImagePicker().pickImage(
    source: ImageSource.camera,
    maxWidth: 1024,
    maxHeight: 1024,
    imageQuality: 85,
  );
  if (picked == null) return null;
  final target = '${await _userImagesDir()}/photo_${DateTime.now().millisecondsSinceEpoch}.jpg';
  await File(picked.path).copy(target);
  return target;
}

// =============================================================================
// Emoji
// =============================================================================

const _suggestedEmoji = [
  '😀', '😢', '😡', '😨', '😴', '🤒', '🤕', '🥰',
  '👍', '👎', '✋', '🙏', '🤲', '👋', '🏁', '⏸️',
  '🍎', '🍌', '🍞', '🥛', '🧃', '🍕', '🍪', '🍦',
  '🚽', '🛁', '🛏️', '🏠', '🏫', '🚗', '🚌', '🌳',
  '⚽', '🧸', '🎨', '🎵', '📺', '📱', '📖', '🧩',
  '🐶', '🐱', '☀️', '🌧️', '❄️', '❤️', '❓', '⭐',
];

/// Wybór emoji: podpowiedzi + własne z klawiatury.
Future<String?> pickEmoji(BuildContext context, {String? initial}) {
  final l10n = AppLocalizations.of(context)!;
  return showAppSheet<String>(
    context: context,
    title: l10n.emoji,
    icon: Icons.emoji_emotions_rounded,
    iconColor: AppColors.sunDeep,
    builder: (sheetContext) => _EmojiPicker(initial: initial),
  );
}

class _EmojiPicker extends StatefulWidget {
  final String? initial;
  const _EmojiPicker({this.initial});

  @override
  State<_EmojiPicker> createState() => _EmojiPickerState();
}

class _EmojiPickerState extends State<_EmojiPicker> {
  late final TextEditingController _controller = TextEditingController(text: widget.initial ?? '');

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final palette = context.aac;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GridView.count(
            crossAxisCount: 8,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 4,
            crossAxisSpacing: 4,
            children: [
              for (final e in _suggestedEmoji)
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => Navigator.pop(context, e),
                  child: Center(child: Text(e, style: const TextStyle(fontSize: 26))),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            l10n.emojiInputHint,
            style: TextStyle(color: palette.inkSoft, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 32),
                  decoration: const InputDecoration(hintText: '😀'),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton(
                onPressed: () {
                  final text = _controller.text.trim();
                  if (text.isNotEmpty) Navigator.pop(context, text);
                },
                child: Text(l10n.choose),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Biblioteka symboli
// =============================================================================

Future<LibrarySymbolModel?> pickFromLibrary(BuildContext context) {
  return showModalBottomSheet<LibrarySymbolModel>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    useRootNavigator: true,
    builder: (_) => const _LibraryPicker(),
  );
}

class _LibraryPicker extends ConsumerStatefulWidget {
  const _LibraryPicker();

  @override
  ConsumerState<_LibraryPicker> createState() => _LibraryPickerState();
}

class _LibraryPickerState extends ConsumerState<_LibraryPicker> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final palette = context.aac;
    final symbolsAsync = ref.watch(librarySymbolsProvider);
    final height = MediaQuery.sizeOf(context).height * 0.88;
    final width = MediaQuery.sizeOf(context).width;
    final columns = width >= 600 ? 5 : 3;

    return SizedBox(
      height: height,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
        child: Column(
          children: [
            const SheetHandle(),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: Text(l10n.selectFromLibrary, style: Theme.of(context).textTheme.titleLarge)),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
              decoration: InputDecoration(
                hintText: l10n.searchLibrary,
                prefixIcon: const Icon(Icons.search_rounded),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: symbolsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text(l10n.error(e.toString()))),
                data: (all) {
                  final list = all
                      .where((s) => _query.isEmpty || s.name.toLowerCase().contains(_query))
                      .toList()
                    ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
                  if (list.isEmpty) {
                    return Center(
                      child: Text(
                        l10n.noSymbolsInLibrary,
                        style: TextStyle(color: palette.inkSoft, fontWeight: FontWeight.w700),
                      ),
                    );
                  }
                  return GridView.builder(
                    padding: const EdgeInsets.only(bottom: 24),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columns,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      childAspectRatio: 0.82,
                    ),
                    itemCount: list.length,
                    itemBuilder: (context, index) {
                      final s = list[index];
                      return Material(
                        color: palette.surface,
                        borderRadius: BorderRadius.circular(16),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => Navigator.pop(context, s),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: palette.line, width: 1.5),
                            ),
                            child: Column(
                              children: [
                                Expanded(
                                  child: SymbolImage(imagePath: s.imagePath, emoji: s.emoji, cacheWidth: 240),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  s.name,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, height: 1.1),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Kolor kafelka (klucz Fitzgeralda + dodatkowe)
// =============================================================================

class TileColorPicker extends StatelessWidget {
  final Color selected;
  final ValueChanged<Color> onChanged;

  const TileColorPicker({super.key, required this.selected, required this.onChanged});

  bool _isSelected(Color c) => c.toARGB32() == selected.toARGB32();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final palette = context.aac;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.colorByWordKind,
          style: TextStyle(color: palette.inkSoft, fontWeight: FontWeight.w700, fontSize: 13.5),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final kind in WordKind.values)
              _KindSwatch(
                color: kind.color,
                label: kind.label,
                selected: _isSelected(kind.color),
                onTap: () => onChanged(kind.color),
              ),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          l10n.moreColors,
          style: TextStyle(color: palette.inkSoft, fontWeight: FontWeight.w700, fontSize: 13.5),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final c in ExtraTileColors.values)
              _ColorDot(color: c, selected: _isSelected(c), onTap: () => onChanged(c)),
          ],
        ),
      ],
    );
  }
}

class _KindSwatch extends StatelessWidget {
  final Color color;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _KindSwatch({required this.color, required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final edge = AppColors.edgeFor(color);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? AppColors.ink : AppColors.outlineFor(color), width: selected ? 3 : 1.5),
          boxShadow: [BoxShadow(color: edge, offset: const Offset(0, 2), blurRadius: 0)],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected) ...[
              const Icon(Icons.check_rounded, size: 18, color: AppColors.ink),
              const SizedBox(width: 4),
            ],
            Text(label, style: const TextStyle(color: AppColors.ink, fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }
}

class _ColorDot extends StatelessWidget {
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _ColorDot({required this.color, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: selected ? AppColors.ink : AppColors.outlineFor(color), width: selected ? 3 : 1.5),
        ),
        child: selected ? const Icon(Icons.check_rounded, size: 20, color: AppColors.ink) : null,
      ),
    );
  }
}

/// Rząd przycisków wyboru obrazka.
class PictureSourceButtons extends StatelessWidget {
  final VoidCallback? onLibrary;
  final VoidCallback onFiles;
  final VoidCallback onCamera;
  final VoidCallback onEmoji;

  const PictureSourceButtons({
    super.key,
    this.onLibrary,
    required this.onFiles,
    required this.onCamera,
    required this.onEmoji,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final buttons = <Widget>[
      if (onLibrary != null)
        BigActionButton(icon: Icons.photo_library_rounded, label: l10n.sourceLibrary, color: AppColors.grape, height: 84, onTap: onLibrary),
      BigActionButton(icon: Icons.image_rounded, label: l10n.sourceFiles, color: AppColors.sky, height: 84, onTap: onFiles),
      BigActionButton(icon: Icons.photo_camera_rounded, label: l10n.camera, color: AppColors.leaf, height: 84, onTap: onCamera),
      BigActionButton(icon: Icons.emoji_emotions_rounded, label: l10n.emoji, color: AppColors.sunDeep, height: 84, onTap: onEmoji),
    ];
    return Row(
      children: [
        for (var i = 0; i < buttons.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(child: buttons[i]),
        ],
      ],
    );
  }
}
