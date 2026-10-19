import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../core/l10n/app_localizations.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/profile_model.dart';
import '../../data/repositories/profile_repository.dart';
import '../../data/services/app_settings.dart';
import '../../data/services/default_content_service.dart';
import '../widgets/app_sheet.dart';
import '../widgets/symbol_image.dart';

/// Tworzenie i edycja profilu (imię, zdjęcie, gotowa tablica).
class ProfileEditorScreen extends ConsumerStatefulWidget {
  final String? profileId;

  /// Pierwszy profil po ekranie powitalnym.
  final bool firstRun;

  const ProfileEditorScreen({super.key, this.profileId, this.firstRun = false});

  @override
  ConsumerState<ProfileEditorScreen> createState() => _ProfileEditorScreenState();
}

class _ProfileEditorScreenState extends ConsumerState<ProfileEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();

  String? _photoPath;
  ProfileModel? _existing;
  bool _loading = false;
  bool _saving = false;
  bool _addStarter = true;

  bool get _isEdit => widget.profileId != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final repo = await ref.read(profileRepositoryProvider.future);
    final profile = await repo.getById(widget.profileId!);
    if (!mounted) return;
    setState(() {
      _existing = profile;
      _nameController.text = profile?.name ?? '';
      _photoPath = profile?.photoPath;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto(ImageSource source) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      final picked = await ImagePicker().pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );
      if (picked == null) return;
      final dir = await getApplicationDocumentsDirectory();
      final path = '${dir.path}/profile_${DateTime.now().millisecondsSinceEpoch}.jpg';
      await File(picked.path).copy(path);
      if (mounted) setState(() => _photoPath = path);
    } catch (e) {
      if (mounted) showToast(context, l10n.pickImageError(e.toString()), error: true);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final l10n = AppLocalizations.of(context)!;
    setState(() => _saving = true);
    try {
      final repo = await ref.read(profileRepositoryProvider.future);
      final now = DateTime.now();
      final name = _nameController.text.trim();

      if (_existing != null) {
        await repo.update(_existing!.copyWith(name: name, photoPath: _photoPath, updatedAt: now));
        if (!mounted) return;
        showToast(context, l10n.profileUpdated);
        context.pop();
        return;
      }

      final profile = ProfileModel(
        id: const Uuid().v4(),
        name: name,
        photoPath: _photoPath,
        createdAt: now,
        updatedAt: now,
      );
      await repo.create(profile);

      final content = await ref.read(defaultContentServiceProvider.future);
      if (_addStarter) await content.addStarterBoard(profile.id);
      await content.ensureSystemBoards(profile.id);

      await ref.read(appSettingsProvider.notifier).setLastProfile(profile.id);
      if (!mounted) return;
      context.go('/folder/${profile.id}');
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        showToast(context, l10n.savingError(e.toString()), error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final palette = context.aac;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? l10n.editProfile : l10n.newProfile),
        automaticallyImplyLeading: !widget.firstRun,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                Form(
                  key: _formKey,
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(20, 8, 20, 32 + MediaQuery.paddingOf(context).bottom),
                    children: [
                      Center(
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            ValueListenableBuilder<TextEditingValue>(
                              valueListenable: _nameController,
                              builder: (context, value, _) => ProfileAvatar(
                                name: value.text.isEmpty ? '?' : value.text,
                                photoPath: _photoPath,
                                size: 132,
                              ),
                            ),
                            if (_photoPath != null)
                              Positioned(
                                right: -4,
                                top: -4,
                                child: CornerBadge(
                                  icon: Icons.close_rounded,
                                  color: AppColors.coralDeep,
                                  edge: const Color(0xFFA8362A),
                                  size: 36,
                                  onTap: () => setState(() => _photoPath = null),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _pickPhoto(ImageSource.gallery),
                              icon: const Icon(Icons.photo_library_rounded),
                              label: Text(l10n.gallery),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _pickPhoto(ImageSource.camera),
                              icon: const Icon(Icons.photo_camera_rounded),
                              label: Text(l10n.camera),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l10n.profilePhotoHint,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: palette.inkSoft, fontWeight: FontWeight.w600, fontSize: 13.5),
                      ),
                      const SizedBox(height: 22),
                      TextFormField(
                        controller: _nameController,
                        textCapitalization: TextCapitalization.words,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                        decoration: InputDecoration(
                          labelText: l10n.profileName,
                          hintText: l10n.profileNameHint,
                          prefixIcon: const Icon(Icons.badge_rounded),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty) ? l10n.profileNameRequired : null,
                      ),
                      if (!_isEdit) ...[
                        const SizedBox(height: 16),
                        Container(
                          decoration: BoxDecoration(
                            color: palette.surface,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: palette.line, width: 1.5),
                          ),
                          child: SwitchListTile(
                            value: _addStarter,
                            onChanged: (v) => setState(() => _addStarter = v),
                            title: Text(l10n.starterBoard),
                            subtitle: Text(l10n.starterBoardDesc),
                          ),
                        ),
                      ],
                      const SizedBox(height: 26),
                      SizedBox(
                        height: 56,
                        child: FilledButton.icon(
                          onPressed: _saving ? null : _save,
                          icon: Icon(_isEdit ? Icons.save_rounded : Icons.arrow_forward_rounded),
                          label: Text(_isEdit ? l10n.saveChanges : l10n.createProfileAndStart),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_saving && !_isEdit)
                  Positioned.fill(
                    child: ColoredBox(
                      color: palette.paper.withValues(alpha: 0.92),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const CircularProgressIndicator(),
                            const SizedBox(height: 16),
                            Text(
                              l10n.preparingBoard,
                              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}
