import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gif_view/gif_view.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../../core/l10n/app_localizations.dart';
import '../../data/models/category_symbol_model.dart';
import '../../data/models/library_symbol_model.dart';
import '../../data/repositories/category_symbol_repository.dart';
import '../../data/repositories/library_symbol_repository.dart';
import '../providers/library_symbols_provider.dart';

class AddSymbolScreen extends ConsumerStatefulWidget {
  final String profileId;
  final String? categoryId;  // null = root level

  const AddSymbolScreen({
    super.key,
    required this.profileId,
    this.categoryId,
  });

  @override
  ConsumerState<AddSymbolScreen> createState() => _AddSymbolScreenState();
}

class _AddSymbolScreenState extends ConsumerState<AddSymbolScreen> {
  static const _uuid = Uuid();

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();

  String? _emoji;
  String? _imagePath;
  LibrarySymbolModel? _selectedLibrarySymbol;
  Color _backgroundColor = const Color(0xFFBBDEFB);
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.addSymbolToCategory),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            if (mounted) {
              context.pop();
            }
          },
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Nazwa
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: l10n.symbolName,
                labelStyle: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w500,
                ),
                hintText: l10n.symbolNameHint,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: Theme.of(context).colorScheme.primary,
                    width: 2,
                  ),
                ),
                prefixIcon: Icon(
                  Icons.label,
                  color: Theme.of(context).colorScheme.primary,
                ),
                filled: true,
                fillColor: Theme.of(context).brightness == Brightness.dark ? Colors.grey[800] : Colors.grey[50],
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return l10n.nameRequired;
                }
                if (value.trim().length < 2) {
                  return l10n.nameTooShort;
                }
                if (value.trim().length > 30) {
                  return l10n.nameTooLong;
                }
                return null;
              },
            ),

            const SizedBox(height: 28),

            // Ikona - sekcja
            _buildSectionTitle(l10n.icon, Icons.image),
            const SizedBox(height: 12),

            // Podgląd
            _buildIconPreview(context),

            const SizedBox(height: 16),

            // Przyciski wyboru - 3 kafelki
            Row(
              children: [
                Expanded(
                  child: _buildActionButton(
                    icon: Icons.library_books,
                    label: 'Biblioteka',
                    color: const Color(0xFF7E57C2), // Fioletowy
                    onTap: _showLibraryDialog,
                    height: 70,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildActionButton(
                    icon: Icons.photo_library,
                    label: 'Telefon',
                    color: const Color(0xFF42A5F5), // Niebieski
                    onTap: _addFromPhone,
                    height: 70,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildActionButton(
                    icon: Icons.emoji_emotions,
                    label: 'Emoji',
                    color: const Color(0xFFFFB74D), // Pomarańczowy
                    onTap: _pickEmoji,
                    height: 70,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 28),

            // Kolor tła - sekcja
            _buildSectionTitle(l10n.backgroundColor, Icons.palette),
            const SizedBox(height: 12),
            _buildColorPicker(context),

            const SizedBox(height: 32),

            // Przycisk zapisu
            _buildActionButton(
              icon: Icons.add_circle,
              label: l10n.add,
              color: const Color(0xFF66BB6A), // Zielony
              onTap: _saveSymbol,
              height: 70,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(
          icon,
          size: 22,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    double height = 80,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.4),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 26,
              color: Colors.white,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIconPreview(BuildContext context) {
    return Container(
      height: 150,
      decoration: BoxDecoration(
        color: _backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[600]! : Colors.grey[400]!),
      ),
      child: Center(
        child: _buildIconWidget(),
      ),
    );
  }

  Widget _buildIconWidget() {
    if (_emoji != null && _emoji!.isNotEmpty) {
      return Text(
        _emoji!,
        style: const TextStyle(fontSize: 80),
      );
    } else if (_imagePath != null && _imagePath!.isNotEmpty) {
      final isGif = _imagePath!.toLowerCase().endsWith('.gif');
      final file = File(_imagePath!);

      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: isGif
            ? FutureBuilder<Uint8List>(
          future: file.readAsBytes(),
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              return GifView.memory(
                snapshot.data!,
                width: 120,
                height: 120,
                fit: BoxFit.cover,
                frameRate: 30,
              );
            }
            return const CircularProgressIndicator();
          },
        )
            : Image.file(
          file,
          width: 120,
          height: 120,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          errorBuilder: (context, error, stackTrace) {
            return const Icon(Icons.broken_image, size: 60, color: Colors.red);
          },
        ),
      );
    } else if (_selectedLibrarySymbol != null) {
      if (_selectedLibrarySymbol!.emoji != null) {
        return Text(
          _selectedLibrarySymbol!.emoji!,
          style: const TextStyle(fontSize: 80),
        );
      } else if (_selectedLibrarySymbol!.imagePath != null) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.file(
            File(_selectedLibrarySymbol!.imagePath!),
            width: 120,
            height: 120,
            fit: BoxFit.cover,
          ),
        );
      }
    }

    return Icon(
      Icons.image_outlined,
      size: 80,
      color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[600] : Colors.grey[400],
    );
  }

  Widget _buildColorPicker(BuildContext context) {
    final colors = [
      const Color(0xFFFFCDD2), const Color(0xFFEF9A9A), const Color(0xFFE57373),
      const Color(0xFFF8BBD0), const Color(0xFFF48FB1), const Color(0xFFF06292),
      const Color(0xFFE1BEE7), const Color(0xFFCE93D8), const Color(0xFFBA68C8),
      const Color(0xFFBBDEFB), const Color(0xFF90CAF9), const Color(0xFF64B5F6),
      const Color(0xFFB2EBF2), const Color(0xFF80DEEA), const Color(0xFF4DD0E1),
      const Color(0xFFC8E6C9), const Color(0xFFA5D6A7), const Color(0xFF81C784),
      const Color(0xFFFFF9C4), const Color(0xFFFFF59D), const Color(0xFFFFF176),
      const Color(0xFFFFE0B2), const Color(0xFFFFCC80), const Color(0xFFFFB74D),
      const Color(0xFFD7CCC8), const Color(0xFFBCAAA4), const Color(0xFFA1887F),
      const Color(0xFFF5F5F5), const Color(0xFFEEEEEE), const Color(0xFFE0E0E0),
    ];

    return SizedBox(
      height: 60,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: colors.length,
        itemBuilder: (context, index) {
          final color = colors[index];
          final isSelected = _backgroundColor.value == color.value;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _backgroundColor = color;
                });
              },
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? Colors.black : Colors.grey[300]!,
                    width: isSelected ? 3 : 1,
                  ),
                ),
                child: isSelected ? const Icon(Icons.check, color: Colors.black) : null,
              ),
            ),
          );
        },
      ),
    );
  }

  // Pokaż dialog z biblioteką
  void _showLibraryDialog() {
    showDialog(
      context: context,
      builder: (context) => _LibraryDialog(
        onSelect: (symbol) {
          if (mounted) {
            setState(() {
              _selectedLibrarySymbol = symbol;
              _nameController.text = symbol.name;
              _emoji = symbol.emoji;
              _imagePath = symbol.imagePath;
            });
          }
          Navigator.pop(context);
        },
      ),
    );
  }

  Future<void> _pickEmoji() async {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController();

    final emoji = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: const Color(0xFFFFB74D),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.emoji_emotions, size: 32, color: Colors.white),
            ),
            const SizedBox(height: 12),
            const Text('Emoji', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('Wpisz lub wybierz emoji z klawiatury',
                style: TextStyle(fontSize: 14, color: Colors.grey[600])),
            const SizedBox(height: 20),
            TextField(
              controller: controller,
              decoration: InputDecoration(
                hintText: '😀',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: Color(0xFFFFB74D), width: 2),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: Color(0xFFFFB74D), width: 2),
                ),
                filled: true,
                fillColor: const Color(0xFFFFF3E0),
              ),
              style: const TextStyle(fontSize: 48),
              textAlign: TextAlign.center,
              maxLength: 2,
              autofocus: true,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(l10n.cancel),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () {
                      if (controller.text.isNotEmpty) {
                        Navigator.pop(context, controller.text);
                      }
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFFFB74D),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(l10n.add),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );

    if (emoji != null && emoji.isNotEmpty) {
      setState(() {
        _emoji = emoji;
        _imagePath = null;
        _selectedLibrarySymbol = null;
      });
    }
  }

  Future<void> _addFromPhone() async {
    final l10n = AppLocalizations.of(context)!;

    final source = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: const Color(0xFF42A5F5),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.photo_library, size: 32, color: Colors.white),
            ),
            const SizedBox(height: 12),
            Text(l10n.selectImageOrGif,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(l10n.selectImageDescription,
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                textAlign: TextAlign.center),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: _buildSourceButton(
                    icon: Icons.photo_library,
                    label: l10n.pickFromGallery,
                    color: const Color(0xFF42A5F5),
                    onTap: () => Navigator.pop(context, 'gallery'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildSourceButton(
                    icon: Icons.camera_alt,
                    label: l10n.takePhoto,
                    color: const Color(0xFF66BB6A),
                    onTap: () => Navigator.pop(context, 'camera'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );

    if (source == null) return;

    try {
      setState(() => _isLoading = true);

      String? pickedPath;

      if (source == 'camera') {
        final picker = ImagePicker();
        final XFile? image = await picker.pickImage(source: ImageSource.camera);
        if (image != null) {
          pickedPath = image.path;
        } else {
          setState(() => _isLoading = false);
          return;
        }
      } else {
        final result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['gif', 'jpg', 'jpeg', 'png', 'webp'],
          allowMultiple: false,
        );

        if (result == null || result.files.single.path == null) {
          setState(() => _isLoading = false);
          return;
        }
        pickedPath = result.files.single.path!;
      }

      final appDir = await getApplicationDocumentsDirectory();
      final extension = pickedPath.split('.').last;
      final fileName = 'symbol_${DateTime.now().millisecondsSinceEpoch}.$extension';
      final savedPath = '${appDir.path}/$fileName';
      await File(pickedPath).copy(savedPath);

      if (mounted) {
        setState(() {
          _imagePath = savedPath;
          _emoji = null;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.error(e.toString())), backgroundColor: Colors.red),
        );
      }
    }
  }

  Widget _buildSourceButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: color.withOpacity(0.4), blurRadius: 8, offset: const Offset(0, 3)),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 36, color: Colors.white),
            const SizedBox(height: 8),
            Text(label,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Future<void> _saveSymbol() async {
    if (!_formKey.currentState!.validate()) return;

    final l10n = AppLocalizations.of(context)!;

    if (_selectedLibrarySymbol == null && _emoji == null && _imagePath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.selectSymbolFirst), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final repository = await ref.read(categorySymbolRepositoryProvider.future);
      final existingSymbols = await repository.getByCategoryId(widget.categoryId);
      final position = existingSymbols.length;

      String librarySymbolId;

      if (_selectedLibrarySymbol != null) {
        librarySymbolId = _selectedLibrarySymbol!.id;
      } else {
        final libraryRepo = await ref.read(librarySymbolRepositoryProvider.future);
        final now = DateTime.now();

        LibrarySymbolModel? existingSymbol;
        if (_imagePath != null) {
          final allSymbols = await libraryRepo.getAll();
          final newFile = File(_imagePath!);
          final newFileBytes = await newFile.readAsBytes();

          for (final symbol in allSymbols) {
            if (symbol.imagePath != null && symbol.imagePath!.isNotEmpty) {
              final existingFile = File(symbol.imagePath!);
              if (existingFile.existsSync()) {
                try {
                  final existingFileBytes = await existingFile.readAsBytes();
                  if (existingFileBytes.length == newFileBytes.length) {
                    bool identical = true;
                    for (int i = 0; i < newFileBytes.length; i++) {
                      if (newFileBytes[i] != existingFileBytes[i]) {
                        identical = false;
                        break;
                      }
                    }
                    if (identical) {
                      existingSymbol = symbol;
                      await newFile.delete();
                      break;
                    }
                  }
                } catch (e) {
                  // ignore
                }
              }
            }
          }
        }

        if (existingSymbol != null) {
          librarySymbolId = existingSymbol.id;
        } else {
          final newLibrarySymbol = LibrarySymbolModel(
            id: _uuid.v4(),
            name: _nameController.text.trim(),
            emoji: _emoji,
            imagePath: _imagePath,
            tags: [],
            isSystemDefault: false,
            isAnimated: _imagePath?.toLowerCase().endsWith('.gif') ?? false,
            createdAt: now,
            updatedAt: now,
            usageCount: 0,
          );

          await libraryRepo.create(newLibrarySymbol);
          ref.invalidate(librarySymbolsProvider);
          librarySymbolId = newLibrarySymbol.id;
        }
      }

      final now = DateTime.now();
      final newSymbol = CategorySymbolModel(
        id: _uuid.v4(),
        librarySymbolId: librarySymbolId,
        categoryId: widget.categoryId,
        nameOverride: _nameController.text.trim() != _selectedLibrarySymbol?.name
            ? _nameController.text.trim()
            : null,
        backgroundColor: _backgroundColor.value,
        position: position,
        createdAt: now,
        updatedAt: now,
      );

      await repository.create(newSymbol);

      if (_selectedLibrarySymbol != null) {
        final libraryRepo = await ref.read(librarySymbolRepositoryProvider.future);
        await libraryRepo.incrementUsageCount(_selectedLibrarySymbol!.id);
      }

      if (mounted) {
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.symbolAddedToCategory)),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.error(e.toString())), backgroundColor: Colors.red),
        );
      }
    }
  }
}

// Dialog wyboru symbolu z biblioteki - bez zmian
class _LibraryDialog extends ConsumerStatefulWidget {
  final Function(LibrarySymbolModel) onSelect;

  const _LibraryDialog({required this.onSelect});

  @override
  ConsumerState<_LibraryDialog> createState() => _LibraryDialogState();
}

class _LibraryDialogState extends ConsumerState<_LibraryDialog> {
  late final TextEditingController _searchController;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _searchController.addListener(() {
      if (mounted) {
        setState(() {
          _searchQuery = _searchController.text;
        });
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final symbolsAsync = ref.watch(librarySymbolsProvider);

    return Dialog(
      child: Column(
        children: [
          AppBar(
            title: Text(l10n.selectFromLibrary),
            automaticallyImplyLeading: false,
            actions: [
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: l10n.searchLibrary,
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    if (mounted) _searchController.clear();
                  },
                )
                    : null,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          Expanded(
            child: symbolsAsync.when(
              data: (symbols) {
                symbols.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

                final filteredSymbols = _searchQuery.isEmpty
                    ? symbols
                    : symbols.where((s) => s.name.toLowerCase().contains(_searchQuery.toLowerCase())).toList();

                if (filteredSymbols.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(l10n.noSymbolsInLibrary, style: Theme.of(context).textTheme.titleMedium),
                      ],
                    ),
                  );
                }

                return GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    childAspectRatio: 0.85,
                  ),
                  itemCount: filteredSymbols.length,
                  itemBuilder: (context, index) {
                    final symbol = filteredSymbols[index];
                    return _buildSymbolCard(context, symbol);
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(child: Text(l10n.error(error.toString()))),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSymbolCard(BuildContext context, LibrarySymbolModel symbol) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => widget.onSelect(symbol),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              child: Center(
                child: symbol.emoji != null
                    ? Text(symbol.emoji!, style: const TextStyle(fontSize: 40))
                    : symbol.imagePath != null
                    ? Image.file(
                  File(symbol.imagePath!),
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return const Icon(Icons.broken_image, size: 40, color: Colors.red);
                  },
                )
                    : const Icon(Icons.image, size: 40, color: Colors.grey),
              ),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              color: Colors.black.withOpacity(0.05),
              child: Text(
                symbol.name,
                style: const TextStyle(fontSize: 11),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}