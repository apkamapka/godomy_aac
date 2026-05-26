import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/l10n/app_localizations.dart';
import '../../core/constants/app_links.dart';
import '../../core/utils/url_helper.dart';
import '../providers/profiles_provider.dart';
import '../../data/models/profile_model.dart';
import '../../data/repositories/profile_repository.dart';

class ProfilesScreen extends ConsumerWidget {
  const ProfilesScreen({super.key});

  static const List<Color> profileColors = [
    Color(0xFF7E57C2), // Fioletowy
    Color(0xFF42A5F5), // Niebieski
    Color(0xFF66BB6A), // Zielony
    Color(0xFFFFB74D), // Pomarańczowy
    Color(0xFFEF5350), // Czerwony
    Color(0xFF26C6DA), // Cyjan
    Color(0xFFEC407A), // Różowy
    Color(0xFF8D6E63), // Brązowy
  ];

  Color _getProfileColor(int index) {
    return profileColors[index % profileColors.length];
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profilesAsync = ref.watch(profilesProvider);
    final l10n = AppLocalizations.of(context)!;

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.grey[900] : const Color(0xFFE3F2FD),
      body: SafeArea(
        child: profilesAsync.when(
          data: (profiles) {
            if (profiles.isEmpty) {
              return _buildEmptyState(context, l10n);
            }
            return _buildProfileList(context, ref, profiles, l10n);
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => Center(child: Text(l10n.error(error.toString()))),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, AppLocalizations l10n) {
    return Column(
      children: [
        const SizedBox(height: 60),
        // Logo
        _buildLogo(context, 160),
        const SizedBox(height: 24),
        // Tytuł
        Text(
          l10n.selectProfile,
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white
                : Colors.black87,
          ),
        ),
        const Spacer(),
        // Tekst
        Icon(Icons.person_add, size: 80, color: Colors.grey[300]),
        const SizedBox(height: 16),
        Text(
          l10n.noProfiles,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 48),
          child: Text(
            l10n.addFirstProfile,
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
        ),
        const Spacer(),
        // Przycisk
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: _buildCreateButton(context, l10n),
        ),
        _buildCreatedByFooter(context, l10n),
      ],
    );
  }

  Widget _buildProfileList(BuildContext context, WidgetRef ref, List<ProfileModel> profiles, AppLocalizations l10n) {
    return Column(
      children: [
        const SizedBox(height: 30),
        // Logo
        _buildLogo(context, 100),
        const SizedBox(height: 16),
        // Tytuł
        Text(
          l10n.selectProfile,
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white
                : Colors.black87,
          ),
        ),
        const SizedBox(height: 24),
        // Lista profili
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: profiles.length,
            itemBuilder: (context, index) {
              final profile = profiles[index];
              return _buildProfileCard(context, ref, profile, index, l10n);
            },
          ),
        ),
        // Przycisk
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: _buildCreateButton(context, l10n),
        ),
        _buildCreatedByFooter(context, l10n),
      ],
    );
  }

  Widget _buildLogo(BuildContext context, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF42A5F5).withOpacity(0.3),
            blurRadius: 20,
            spreadRadius: 5,
          ),
        ],
      ),
      child: ClipOval(
        child: Padding(
          padding: EdgeInsets.all(size * 0.12),
          child: Image.asset('assets/images/app_icon.png', fit: BoxFit.contain),
        ),
      ),
    );
  }

  Widget _buildProfileCard(BuildContext context, WidgetRef ref, ProfileModel profile, int index, AppLocalizations l10n) {
    final color = _getProfileColor(index);
    final hasPhoto = profile.photoPath != null &&
        profile.photoPath!.isNotEmpty &&
        File(profile.photoPath!).existsSync();
    final lastUsed = _formatLastUsed(profile.updatedAt);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: () => _selectProfile(context, ref, profile, l10n),
        onLongPress: () => _showProfileMenu(context, ref, profile, color),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.2),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              // Avatar
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: hasPhoto
                      ? null
                      : LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [color, color.withOpacity(0.7)],
                  ),
                  boxShadow: [
                    BoxShadow(color: color.withOpacity(0.4), blurRadius: 8, offset: const Offset(0, 3)),
                  ],
                ),
                child: hasPhoto
                    ? ClipOval(
                  child: Image.file(File(profile.photoPath!), fit: BoxFit.cover, width: 70, height: 70),
                )
                    : Center(
                  child: Text(
                    profile.name.isNotEmpty ? profile.name[0].toUpperCase() : '?',
                    style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // Nazwa i data
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.name,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,  // Karta jest biała - tekst zawsze ciemny
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.access_time, size: 14, color: Colors.grey[500]),
                        const SizedBox(width: 4),
                        Text(lastUsed, style: TextStyle(fontSize: 13, color: Colors.grey[500])),
                      ],
                    ),
                  ],
                ),
              ),
              // Strzałka
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.chevron_right, color: color, size: 28),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCreatedByFooter(BuildContext context, AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            l10n.createdBy,
            style: TextStyle(fontSize: 12, color: Colors.grey[500]),
          ),
          const SizedBox(height: 4),
          InkWell(
            onTap: () => openExternalUrl(context, AppLinks.website),
            borderRadius: BorderRadius.circular(28),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: ClipOval(
                child: Image.asset(
                  'assets/images/akapp_logo.png',
                  width: 52,
                  height: 52,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCreateButton(BuildContext context, AppLocalizations l10n) {
    return GestureDetector(
      onTap: () => context.push('/profile-editor'),
      child: Container(
        width: double.infinity,
        height: 60,
        decoration: BoxDecoration(
          color: const Color(0xFF66BB6A),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF66BB6A).withOpacity(0.4),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.person_add, size: 26, color: Colors.white),
            const SizedBox(width: 12),
            Text(
              l10n.addProfile,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  String _formatLastUsed(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Przed chwilą';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes} min temu';
    } else if (difference.inDays < 1) {
      return '${difference.inHours} godz. temu';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} dni temu';
    } else {
      return DateFormat('dd.MM.yyyy').format(dateTime);
    }
  }

  void _selectProfile(BuildContext context, WidgetRef ref, ProfileModel profile, AppLocalizations l10n) async {
    // Aktualizuj datę ostatniego użycia
    try {
      final repository = await ref.read(profileRepositoryProvider.future);
      final updatedProfile = ProfileModel(
        id: profile.id,
        name: profile.name,
        photoPath: profile.photoPath,
        createdAt: profile.createdAt,
        updatedAt: DateTime.now(), // ← Aktualizacja daty
      );
      await repository.update(updatedProfile);
    } catch (e) {
      // Ignoruj błędy - wybór profilu powinien działać nawet jeśli aktualizacja się nie powiedzie
    }

    ref.read(selectedProfileProvider.notifier).select(profile);
    context.go('/folder/${profile.id}');

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.profileSelected(profile.name)),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showProfileMenu(BuildContext scaffoldContext, WidgetRef ref, ProfileModel profile, Color profileColor) {
    final l10n = AppLocalizations.of(scaffoldContext)!;

    showModalBottomSheet(
      context: scaffoldContext,
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
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
            ),
            // Nazwa profilu z avatarem
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [profileColor, profileColor.withOpacity(0.7)],
                    ),
                  ),
                  child: Center(
                    child: Text(
                      profile.name.isNotEmpty ? profile.name[0].toUpperCase() : '?',
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  profile.name,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 24),
            // Przyciski
            Row(
              children: [
                Expanded(
                  child: _buildMenuButton(
                    icon: Icons.edit,
                    label: l10n.editProfile,
                    color: const Color(0xFFFDD835),
                    textColor: Colors.black87,
                    onTap: () {
                      Navigator.pop(context);
                      scaffoldContext.push('/profile-editor?id=${profile.id}');
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMenuButton(
                    icon: Icons.delete,
                    label: l10n.deleteProfile,
                    color: const Color(0xFFE53935),
                    textColor: Colors.white,
                    onTap: () {
                      Navigator.pop(context);
                      _handleDeleteProfile(scaffoldContext, ref, profile);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 26),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuButton({
    required IconData icon,
    required String label,
    required Color color,
    required Color textColor,
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
          children: [
            Icon(icon, size: 36, color: textColor),
            const SizedBox(height: 8),
            Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textColor)),
          ],
        ),
      ),
    );
  }

  Future<void> _handleDeleteProfile(BuildContext context, WidgetRef ref, ProfileModel profile) async {
    final l10n = AppLocalizations.of(context)!;

    await Future.delayed(const Duration(milliseconds: 300));

    final confirm = await _showDeleteDialog(context, profile.name, l10n);

    if (confirm != true) return;

    try {
      final repository = await ref.read(profileRepositoryProvider.future);
      await repository.delete(profile.id);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.profileDeleted), backgroundColor: Colors.green, behavior: SnackBarBehavior.floating),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.error(e.toString())), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  Future<bool?> _showDeleteDialog(BuildContext context, String profileName, AppLocalizations l10n) {
    return showModalBottomSheet<bool>(
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
              decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
            ),
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(color: const Color(0xFFE53935), borderRadius: BorderRadius.circular(16)),
              child: const Icon(Icons.warning, size: 32, color: Colors.white),
            ),
            const SizedBox(height: 12),
            Text(l10n.deleteProfile, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              '${l10n.confirmDeleteProfile}\n"$profileName"?',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(12)),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.red, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.operationIrreversible,
                      style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
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
                    onPressed: () => Navigator.pop(context, true),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFE53935),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(l10n.delete),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 42),
          ],
        ),
      ),
    );
  }
}