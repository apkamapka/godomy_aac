import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:path_provider/path_provider.dart';
import '../../data/models/profile_model.dart';
import '../../data/repositories/profile_repository.dart';
import '../../core/l10n/app_localizations.dart';

class ProfileEditorScreen extends ConsumerStatefulWidget {
  final String? profileId;

  const ProfileEditorScreen({super.key, this.profileId});

  @override
  ConsumerState<ProfileEditorScreen> createState() => _ProfileEditorScreenState();
}

class _ProfileEditorScreenState extends ConsumerState<ProfileEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  String? _photoPath;
  bool _isLoading = false;
  ProfileModel? _existingProfile;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    if (widget.profileId != null) {
      final repository = await ref.read(profileRepositoryProvider.future);
      final profile = await repository.getById(widget.profileId!);
      if (profile != null) {
        setState(() {
          _existingProfile = profile;
          _nameController.text = profile.name;
          _photoPath = profile.photoPath;
        });
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
    final isEditMode = _existingProfile != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditMode ? l10n.editProfile : 'Nowy Profil'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Zdjęcie - sekcja
            _buildSectionTitle('Zdjęcie', Icons.photo_camera),
            const SizedBox(height: 12),
            _buildPhotoPreview(context),
            const SizedBox(height: 16),
            // Przyciski zdjęcia
            Row(
              children: [
                Expanded(
                  child: _buildActionButton(
                    icon: Icons.photo_library,
                    label: 'Galeria',
                    color: const Color(0xFF42A5F5),
                    onTap: () => _pickImage(ImageSource.gallery),
                    height: 70,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildActionButton(
                    icon: Icons.camera_alt,
                    label: 'Aparat',
                    color: const Color(0xFF66BB6A),
                    onTap: () => _pickImage(ImageSource.camera),
                    height: 70,
                  ),
                ),
                if (_photoPath != null) ...[
                  const SizedBox(width: 12),
                  _buildActionButton(
                    icon: Icons.delete,
                    label: 'Usuń',
                    color: const Color(0xFFE53935),
                    onTap: () => setState(() => _photoPath = null),
                    height: 70,
                  ),
                ],
              ],
            ),

            const SizedBox(height: 28),

            // Nazwa - sekcja
            _buildSectionTitle('Nazwa profilu', Icons.person),
            const SizedBox(height: 12),
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Nazwa profilu',
                labelStyle: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w500,
                ),
                hintText: 'np. Jan, Mama, Ania',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 2),
                ),
                prefixIcon: Icon(Icons.badge, color: Theme.of(context).colorScheme.primary),
                filled: true,
                fillColor: Theme.of(context).brightness == Brightness.dark ? Colors.grey[800] : Colors.grey[50],
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Podaj nazwę profilu';
                }
                return null;
              },
              textCapitalization: TextCapitalization.words,
            ),

            const SizedBox(height: 32),

            // Przycisk zapisu
            _buildActionButton(
              icon: isEditMode ? Icons.save : Icons.person_add,
              label: isEditMode ? l10n.saveChanges : 'Utwórz profil',
              color: const Color(0xFF66BB6A),
              onTap: _saveProfile,
              height: 70,
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
            BoxShadow(color: color.withOpacity(0.4), blurRadius: 8, offset: const Offset(0, 3)),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 26, color: Colors.white),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildPhotoPreview(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: 180,
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[800] : Colors.grey[100],
        border: Border.all(color: isDark ? Colors.grey[700]! : Colors.grey[300]!),
      ),
      child: Center(
        child: _photoPath != null && File(_photoPath!).existsSync()
            ? ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.file(
            File(_photoPath!),
            width: 140,
            height: 140,
            fit: BoxFit.cover,
          ),
        )
            : Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person, size: 80, color: isDark ? Colors.grey[600] : Colors.grey[400]),
            const SizedBox(height: 8),
            Text('Brak zdjęcia', style: TextStyle(fontSize: 14, color: isDark ? Colors.grey[400] : Colors.grey[500])),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        final appDir = await getApplicationDocumentsDirectory();
        final fileName = 'profile_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final savedPath = '${appDir.path}/$fileName';
        await File(pickedFile.path).copy(savedPath);

        setState(() => _photoPath = savedPath);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Błąd podczas wybierania zdjęcia: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final repository = await ref.read(profileRepositoryProvider.future);
      final now = DateTime.now();

      final profile = ProfileModel(
        id: _existingProfile?.id ?? const Uuid().v4(),
        name: _nameController.text.trim(),
        photoPath: _photoPath,
        createdAt: _existingProfile?.createdAt ?? now,
        updatedAt: now,
      );

      if (_existingProfile != null) {
        await repository.update(profile);
      } else {
        await repository.create(profile);
      }

      if (mounted) {
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_existingProfile != null ? 'Profil zaktualizowany' : 'Profil utworzony'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Błąd podczas zapisywania: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }
}