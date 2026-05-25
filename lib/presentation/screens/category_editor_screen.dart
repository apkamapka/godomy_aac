import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:path_provider/path_provider.dart';
import '../../core/l10n/app_localizations.dart';
import '../../data/models/category_model.dart';
import '../../data/repositories/category_repository.dart';

class CategoryEditorScreen extends ConsumerStatefulWidget {
  final String profileId;
  final String? categoryId;
  final String? parentId;  // dla nowej podkategorii

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
  static const _uuid = Uuid();

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();

  String? _iconPath;
  String? _emoji;
  Color _backgroundColor = const Color(0xFFBBDEFB);
  Color _textColor = const Color(0xFF0D47A1);
  Color _iconColor = const Color(0xFF1976D2);
  int _columns = 3;
  int _rows = 4;

  CategoryModel? _existingCategory;
  bool _isLoading = false;
  bool _isEditMode = false;

  @override
  void initState() {
    super.initState();
    if (widget.categoryId != null) {
      _isEditMode = true;
      _loadCategory();
    }
  }

  Future<void> _loadCategory() async {
    setState(() => _isLoading = true);

    try {
      final repository = await ref.read(categoryRepositoryProvider.future);
      final category = await repository.getById(widget.categoryId!);

      if (category != null) {
        setState(() {
          _existingCategory = category;
          _nameController.text = category.name;
          _iconPath = category.iconPath;
          _backgroundColor = Color(category.backgroundColor);
          _textColor = Color(category.textColor);
          _iconColor = Color(category.iconColor);
          _columns = category.gridConfig.columns;
          _rows = category.gridConfig.rows;
          _isLoading = false;
        });
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Kategoria nie znaleziona'),
              backgroundColor: Colors.red,
            ),
          );
          context.pop();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Błąd: $e'),
            backgroundColor: Colors.red,
          ),
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
        appBar: AppBar(
          title: Text(_isEditMode ? l10n.editCategory : l10n.newCategory),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditMode ? l10n.editCategory : l10n.newCategory),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Nazwa
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: l10n.categoryName,
                labelStyle: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w500,
                ),
                hintText: l10n.categoryNameHint,
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

            // Kolor tła - sekcja
            _buildSectionTitle(l10n.backgroundColor, Icons.palette),
            const SizedBox(height: 12),
            _buildColorPicker(context),

            const SizedBox(height: 28),

            // Ikona - sekcja
            _buildSectionTitle(l10n.icon, Icons.image),
            const SizedBox(height: 12),

            // Podgląd
            _buildIconPreview(context),

            const SizedBox(height: 16),

            // Przyciski wyboru - duże kafelki
            Row(
              children: [
                Expanded(
                  child: _buildActionButton(
                    icon: Icons.photo_library,
                    label: l10n.image,
                    color: const Color(0xFF42A5F5), // Niebieski
                    onTap: _pickImage,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildActionButton(
                    icon: Icons.emoji_emotions,
                    label: 'Emoji',
                    color: const Color(0xFFFFB74D), // Pomarańczowy
                    onTap: _pickEmoji,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 32),

            // Przycisk zapisu - duży kafelek
            _buildActionButton(
              icon: Icons.save,
              label: _isEditMode ? l10n.saveChanges : l10n.createCategory,
              color: const Color(0xFF66BB6A), // Zielony
              onTap: _handleSave,
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
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 28,
              color: Colors.white,
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
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
    } else if (_iconPath != null && _iconPath!.isNotEmpty) {
      final file = File(_iconPath!);
      if (file.existsSync()) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.file(
            file,
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
      const Color(0xFFFFCDD2), // Red 100
      const Color(0xFFF8BBD0), // Pink 100
      const Color(0xFFE1BEE7), // Purple 100
      const Color(0xFFD1C4E9), // Deep Purple 100
      const Color(0xFFC5CAE9), // Indigo 100
      const Color(0xFFBBDEFB), // Blue 100
      const Color(0xFFB3E5FC), // Light Blue 100
      const Color(0xFFB2EBF2), // Cyan 100
      const Color(0xFFB2DFDB), // Teal 100
      const Color(0xFFC8E6C9), // Green 100
      const Color(0xFFF0F4C3), // Lime 100
      const Color(0xFFFFF9C4), // Yellow 100
      const Color(0xFFFFECB3), // Amber 100
      const Color(0xFFFFE0B2), // Orange 100
      const Color(0xFFFFCCBC), // Deep Orange 100
      const Color(0xFFD7CCC8), // Brown 100
      const Color(0xFFF5F5F5), // Grey 100
      const Color(0xFFCFD8DC), // Blue Grey 100
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
                  // Automatycznie dobierz kolory tekstu i ikony
                  _textColor = _getDarkColor(color);
                  _iconColor = _getMediumColor(color);
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
                child: isSelected
                    ? const Icon(Icons.check, color: Colors.black)
                    : null,
              ),
            ),
          );
        },
      ),
    );
  }

  Color _getDarkColor(Color backgroundColor) {
    // Mapowanie kolorów tła na ciemne kolory tekstu
    final colorMap = {
      0xFFFFCDD2: const Color(0xFFB71C1C), // Red
      0xFFF8BBD0: const Color(0xFF880E4F), // Pink
      0xFFE1BEE7: const Color(0xFF4A148C), // Purple
      0xFFD1C4E9: const Color(0xFF311B92), // Deep Purple
      0xFFC5CAE9: const Color(0xFF1A237E), // Indigo
      0xFFBBDEFB: const Color(0xFF0D47A1), // Blue
      0xFFB3E5FC: const Color(0xFF01579B), // Light Blue
      0xFFB2EBF2: const Color(0xFF006064), // Cyan
      0xFFB2DFDB: const Color(0xFF004D40), // Teal
      0xFFC8E6C9: const Color(0xFF1B5E20), // Green
      0xFFF0F4C3: const Color(0xFF827717), // Lime
      0xFFFFF9C4: const Color(0xFFF57F17), // Yellow
      0xFFFFECB3: const Color(0xFFFF6F00), // Amber
      0xFFFFE0B2: const Color(0xFFE65100), // Orange
      0xFFFFCCBC: const Color(0xFFBF360C), // Deep Orange
      0xFFD7CCC8: const Color(0xFF3E2723), // Brown
      0xFFF5F5F5: const Color(0xFF212121), // Grey
      0xFFCFD8DC: const Color(0xFF263238), // Blue Grey
    };

    return colorMap[backgroundColor.value] ?? const Color(0xFF000000);
  }

  Color _getMediumColor(Color backgroundColor) {
    // Mapowanie kolorów tła na średnie kolory ikony
    final colorMap = {
      0xFFFFCDD2: const Color(0xFFD32F2F), // Red
      0xFFF8BBD0: const Color(0xFFC2185B), // Pink
      0xFFE1BEE7: const Color(0xFF7B1FA2), // Purple
      0xFFD1C4E9: const Color(0xFF512DA8), // Deep Purple
      0xFFC5CAE9: const Color(0xFF303F9F), // Indigo
      0xFFBBDEFB: const Color(0xFF1976D2), // Blue
      0xFFB3E5FC: const Color(0xFF0277BD), // Light Blue
      0xFFB2EBF2: const Color(0xFF00838F), // Cyan
      0xFFB2DFDB: const Color(0xFF00796B), // Teal
      0xFFC8E6C9: const Color(0xFF388E3C), // Green
      0xFFF0F4C3: const Color(0xFFAFB42B), // Lime
      0xFFFFF9C4: const Color(0xFFFBC02D), // Yellow
      0xFFFFECB3: const Color(0xFFFF8F00), // Amber
      0xFFFFE0B2: const Color(0xFFF57C00), // Orange
      0xFFFFCCBC: const Color(0xFFE64A19), // Deep Orange
      0xFFD7CCC8: const Color(0xFF5D4037), // Brown
      0xFFF5F5F5: const Color(0xFF424242), // Grey
      0xFFCFD8DC: const Color(0xFF455A64), // Blue Grey
    };

    return colorMap[backgroundColor.value] ?? const Color(0xFF666666);
  }

  Future<void> _pickEmoji() async {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController();

    if (_emoji != null) {
      controller.text = _emoji!;
    }

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
            // Uchwyt
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Ikona i tytuł
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: const Color(0xFFFFB74D),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.emoji_emotions,
                size: 32,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Emoji',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Wpisz lub wybierz emoji z klawiatury',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 20),

            // Pole tekstowe
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

            // Przyciski
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
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
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(l10n.add),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 30), // ← DODAJ TO
          ],
        ),
      ),
    );

    if (emoji != null && emoji.isNotEmpty) {
      setState(() {
        _emoji = emoji;
        _iconPath = null;
      });
    }
  }

  Future<void> _pickImage() async {
    final l10n = AppLocalizations.of(context)!;

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Uchwyt
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Ikona i tytuł
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: const Color(0xFF42A5F5),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.photo_library,
                size: 32,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              l10n.selectImageOrGif,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              l10n.selectImageDescription,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),

            // Przyciski wyboru - duże kafelki
            Row(
              children: [
                Expanded(
                  child: _buildImageSourceButton(
                    icon: Icons.photo_library,
                    label: l10n.pickFromGallery,
                    color: const Color(0xFF42A5F5),
                    onTap: () => Navigator.pop(context, ImageSource.gallery),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildImageSourceButton(
                    icon: Icons.camera_alt,
                    label: l10n.takePhoto,
                    color: const Color(0xFF66BB6A),
                    onTap: () => Navigator.pop(context, ImageSource.camera),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),
          ],
        ),
      ),
    );

    if (source == null) return;

    try {
      final picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: source);

      if (image != null) {
        // Skopiuj do app directory
        final appDir = await getApplicationDocumentsDirectory();
        final fileName = 'category_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final savedPath = '${appDir.path}/$fileName';
        await File(image.path).copy(savedPath);

        setState(() {
          _iconPath = savedPath;
          _emoji = null;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.error(e.toString())),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildImageSourceButton({
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
            BoxShadow(
              color: color.withOpacity(0.4),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 36,
              color: Colors.white,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    final l10n = AppLocalizations.of(context)!;

    if (_iconPath == null && (_emoji == null || _emoji!.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.iconRequired),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final repository = await ref.read(categoryRepositoryProvider.future);
      final now = DateTime.now();

      if (_isEditMode && _existingCategory != null) {
        // Edycja
        final updatedCategory = _existingCategory!.copyWith(
          name: _nameController.text.trim(),
          iconPath: _iconPath,
          backgroundColor: _backgroundColor.value,
          textColor: _textColor.value,
          iconColor: _iconColor.value,
          gridConfig: GridConfig(columns: _columns, rows: _rows),
          updatedAt: now,
        );

        await repository.update(updatedCategory);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.categoryUpdated)),
          );
          context.pop();
        }
      } else {
        // Tworzenie nowej
        final categories = await repository.getByParentId(widget.profileId, widget.parentId);
        final position = categories.length;

        final newCategory = CategoryModel(
          id: _uuid.v4(),
          name: _nameController.text.trim(),
          iconPath: _iconPath,
          backgroundColor: _backgroundColor.value,
          textColor: _textColor.value,
          iconColor: _iconColor.value,
          communicationMode: CommunicationMode.text,
          gridConfig: GridConfig(columns: _columns, rows: _rows),
          scrollLocked: false,
          position: position,
          profileId: widget.profileId,
          parentId: widget.parentId,
          createdAt: now,
          updatedAt: now,
        );

        await repository.create(newCategory);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.categoryCreated)),
          );
          context.pop();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.error(e.toString())),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}