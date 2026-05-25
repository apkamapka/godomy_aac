import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../../core/l10n/app_localizations.dart';
import '../../data/models/library_symbol_model.dart';
import '../../data/repositories/library_symbol_repository.dart';
import 'package:gif_view/gif_view.dart';
import 'dart:typed_data';

class LibraryEditSymbolScreen extends ConsumerStatefulWidget {
  final String symbolId;

  const LibraryEditSymbolScreen({super.key, required this.symbolId});

  @override
  ConsumerState<LibraryEditSymbolScreen> createState() => _LibraryEditSymbolScreenState();
}

class _LibraryEditSymbolScreenState extends ConsumerState<LibraryEditSymbolScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();

  LibrarySymbolModel? _originalSymbol;
  String? _emoji;
  String? _imagePath;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadSymbol();
  }

  Future<void> _loadSymbol() async {
    try {
      final repository = await ref.read(librarySymbolRepositoryProvider.future);
      final symbol = await repository.getById(widget.symbolId);

      if (symbol == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Symbol nie został znaleziony'), backgroundColor: Colors.red),
          );
          context.pop();
        }
        return;
      }

      setState(() {
        _originalSymbol = symbol;
        _nameController.text = symbol.name;
        _emoji = symbol.emoji;
        _imagePath = symbol.imagePath;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Błąd: ${e.toString()}'), backgroundColor: Colors.red),
        );
        context.pop();
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.edit)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.edit)),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Info o symbolu systemowym
            if (_originalSymbol?.isSystemDefault == true)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: const Color(0xFF7E57C2).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF7E57C2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Color(0xFF7E57C2)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text('To jest symbol systemowy. Możesz go edytować.',
                          style: TextStyle(color: Colors.purple[900])),
                    ),
                  ],
                ),
              ),

            // Nazwa
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: l10n.symbolName,
                labelStyle: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w500),
                hintText: l10n.symbolNameHint,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 2),
                ),
                prefixIcon: Icon(Icons.label, color: Theme.of(context).colorScheme.primary),
                filled: true,
                fillColor: Theme.of(context).brightness == Brightness.dark ? Colors.grey[800] : Colors.grey[50],
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) return l10n.nameRequired;
                if (value.trim().length < 2) return l10n.nameTooShort;
                if (value.trim().length > 30) return l10n.nameTooLong;
                return null;
              },
            ),

            const SizedBox(height: 28),

            // Ikona - sekcja
            _buildSectionTitle(l10n.icon, Icons.image),
            const SizedBox(height: 12),
            _buildIconPreview(context),
            const SizedBox(height: 16),

            // Przyciski wyboru
            Row(
              children: [
                Expanded(
                  child: _buildActionButton(
                    icon: Icons.photo_library,
                    label: l10n.image,
                    color: const Color(0xFF42A5F5),
                    onTap: _pickImage,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildActionButton(
                    icon: Icons.emoji_emotions,
                    label: 'Emoji',
                    color: const Color(0xFFFFB74D),
                    onTap: _pickEmoji,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 32),

            // Przycisk zapisu
            _buildActionButton(
              icon: Icons.save,
              label: l10n.saveChanges,
              color: const Color(0xFF66BB6A),
              onTap: _isSaving ? () {} : _handleSave,
              height: 60,
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 22, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 8),
        Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    double height = 70,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: color.withOpacity(0.4), blurRadius: 8, offset: const Offset(0, 3))],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 24, color: Colors.white),
            const SizedBox(width: 10),
            Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
          ],
        ),
      ),
    );
  }

  Widget _buildIconPreview(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: 150,
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[800] : Colors.grey[100],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.grey[700]! : Colors.grey[300]!),
      ),
      child: Center(child: _buildIconWidget()),
    );
  }

  Widget _buildIconWidget() {
    if (_emoji != null) {
      return Text(_emoji!, style: const TextStyle(fontSize: 80));
    } else if (_imagePath != null) {
      final isGif = _imagePath!.toLowerCase().endsWith('.gif');
      final file = File(_imagePath!);

      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: isGif
            ? FutureBuilder<Uint8List>(
          future: file.readAsBytes(),
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              return GifView.memory(snapshot.data!, width: 120, height: 120, fit: BoxFit.cover, frameRate: 30);
            }
            return const CircularProgressIndicator();
          },
        )
            : Image.file(file, width: 120, height: 120, fit: BoxFit.cover, gaplessPlayback: true,
            errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, size: 60, color: Colors.red)),
      );
    } else {
      return Icon(Icons.image_outlined, size: 80, color: Colors.grey[400]);
    }
  }

  Future<void> _pickEmoji() async {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController();
    if (_emoji != null) controller.text = _emoji!;

    final emoji = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => Padding(
        padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(context).viewInsets.bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
            Container(width: 60, height: 60,
                decoration: BoxDecoration(color: const Color(0xFFFFB74D), borderRadius: BorderRadius.circular(16)),
                child: const Icon(Icons.emoji_emotions, size: 32, color: Colors.white)),
            const SizedBox(height: 12),
            const Text('Emoji', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('Wpisz lub wybierz emoji z klawiatury', style: TextStyle(fontSize: 14, color: Colors.grey[600])),
            const SizedBox(height: 20),
            TextField(
              controller: controller,
              decoration: InputDecoration(
                hintText: '😀',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFFFB74D), width: 2)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFFFB74D), width: 2)),
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
                    style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    child: Text(l10n.cancel),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () { if (controller.text.isNotEmpty) Navigator.pop(context, controller.text); },
                    style: FilledButton.styleFrom(backgroundColor: const Color(0xFFFFB74D),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    child: Text(l10n.saveChanges),
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
      setState(() { _emoji = emoji; _imagePath = null; });
    }
  }

  Future<void> _pickImage() async {
    final l10n = AppLocalizations.of(context)!;

    final source = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
            Container(width: 60, height: 60,
                decoration: BoxDecoration(color: const Color(0xFF42A5F5), borderRadius: BorderRadius.circular(16)),
                child: const Icon(Icons.photo_library, size: 32, color: Colors.white)),
            const SizedBox(height: 12),
            Text(l10n.selectImageOrGif, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(l10n.selectImageDescription, style: TextStyle(fontSize: 14, color: Colors.grey[600]), textAlign: TextAlign.center),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(child: _buildSourceButton(Icons.photo_library, l10n.pickFromGallery, const Color(0xFF42A5F5),
                        () => Navigator.pop(context, 'gallery'))),
                const SizedBox(width: 12),
                Expanded(child: _buildSourceButton(Icons.camera_alt, l10n.takePhoto, const Color(0xFF66BB6A),
                        () => Navigator.pop(context, 'camera'))),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );

    if (source == null) return;

    try {
      String? pickedPath;

      if (source == 'camera') {
        final picker = ImagePicker();
        final XFile? image = await picker.pickImage(source: ImageSource.camera);
        if (image != null) pickedPath = image.path;
      } else {
        final result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['gif', 'jpg', 'jpeg', 'png', 'webp'],
          allowMultiple: false,
        );
        if (result != null && result.files.single.path != null) {
          pickedPath = result.files.single.path!;
        }
      }

      if (pickedPath != null) {
        final appDir = await getApplicationDocumentsDirectory();
        final extension = pickedPath.split('.').last;
        final fileName = 'symbol_${DateTime.now().millisecondsSinceEpoch}.$extension';
        final savedPath = '${appDir.path}/$fileName';
        await File(pickedPath).copy(savedPath);

        setState(() { _imagePath = savedPath; _emoji = null; });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.error(e.toString())), backgroundColor: Colors.red),
        );
      }
    }
  }

  Widget _buildSourceButton(IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: color.withOpacity(0.4), blurRadius: 8, offset: const Offset(0, 3))],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 36, color: Colors.white),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    final l10n = AppLocalizations.of(context)!;

    if (_emoji == null && _imagePath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.iconRequired), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final repository = await ref.read(librarySymbolRepositoryProvider.future);

      final updatedSymbol = _originalSymbol!.copyWith(
        name: _nameController.text.trim(),
        emoji: _emoji,
        imagePath: _imagePath,
        isAnimated: _imagePath?.toLowerCase().endsWith('.gif') ?? false,
        updatedAt: DateTime.now(),
      );

      await repository.update(updatedSymbol);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.symbolUpdated), backgroundColor: Colors.green));
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.error(e.toString())), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}