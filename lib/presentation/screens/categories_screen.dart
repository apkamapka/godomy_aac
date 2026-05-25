import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/l10n/app_localizations.dart';
import '../../data/models/profile_model.dart';
import '../../data/repositories/profile_repository.dart';
import '../../data/services/default_categories_service.dart';
import '../providers/categories_provider.dart';
import '../providers/profiles_provider.dart';
import '../../data/models/category_model.dart';
import '../../data/repositories/category_repository.dart';
import '../widgets/category_card.dart';
import '../providers/theme_provider.dart';
import '../../data/services/default_symbols_service.dart';
import '../../data/repositories/library_symbol_repository.dart';
import '../../data/repositories/category_symbol_repository.dart';
import '../widgets/cloud_header.dart';

class CategoriesScreen extends ConsumerStatefulWidget {
  final String profileId;

  const CategoriesScreen({super.key, required this.profileId});

  @override
  ConsumerState<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends ConsumerState<CategoriesScreen> {
  ProfileModel? _profile;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _showAddDefaultSymbolsDialog(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;

    // Sprawdź czy istnieją już kategorie
    final categoryRepository = await ref.read(categoryRepositoryProvider.future);
    final categories = await categoryRepository.getByProfileId(widget.profileId);

    if (categories.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Najpierw dodaj kategorie!'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Dodać domyślne symbole?'),
        content: const Text(
          'Zostaną dodane podstawowe symbole do wszystkich istniejących kategorii.\n\n'
              'Symbole będą dostępne w bibliotece i przypisane do odpowiednich kategorii.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Dodaj'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      // Import serwisów
      final libraryRepo = await ref.read(librarySymbolRepositoryProvider.future);
      final categorySymbolRepo = await ref.read(categorySymbolRepositoryProvider.future);

      // Utwórz symbole dla wszystkich kategorii
      final (librarySymbols, categorySymbols) =
      await DefaultSymbolsService.createDefaultSymbolsForAllCategories(
        categories,
            () async => await libraryRepo.getAll(),
            (categoryId) async => await categorySymbolRepo.getByCategoryId(categoryId), // ✅ NOWE
      );

      // Zapisz do bazy
      await libraryRepo.createMany(librarySymbols);
      await categorySymbolRepo.createMany(categorySymbols);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('✓ Symbole zostały dodane'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('❌ Error adding default symbols: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Błąd: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _loadProfile() async {
    try {
      final repository = await ref.read(profileRepositoryProvider.future);
      final profile = await repository.getById(widget.profileId);

      print('🔍 Loading profile: ${widget.profileId}');

      if (profile != null) {
        print('✅ Profile found: ${profile.name}');
        ref.read(selectedProfileProvider.notifier).select(profile);

        // WAŻNE: NIE twórz automatycznie domyślnych kategorii!
        // User sam zdecyduje czy je chce dodać

        if (mounted) {
          setState(() {
            _profile = profile;
            _isLoading = false;
          });
          print('🎨 UI updated');
        }
      } else {
        print('❌ Profile not found');
        if (mounted) {
          context.go('/profiles');
        }
      }
    } catch (e, stackTrace) {
      print('❌ Error loading profile: $e');
      print('Stack trace: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Błąd ładowania profilu: $e')),
        );
        context.go('/profiles');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_profile == null) {
      return const Scaffold(
        body: Center(child: Text('Profil nie znaleziony')),
      );
    }

    final categoriesAsync = ref.watch(categoriesProvider(widget.profileId));
    final menuCollapsed = ref.watch(menuCollapsedProvider);
    final deleteMode = ref.watch(deleteModeProvider);

    return Scaffold(
      appBar: AppBar(
        title: const SizedBox.shrink(),
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu, size: 28),
            onPressed: () {
              Scaffold.of(context).openDrawer();
            },
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person, size: 28),
            onPressed: () {
              context.go('/profiles');
            },
          ),
        ],
      ),
      drawer: _buildDrawer(context, l10n),
      body: Column(
        children: [
          // CloudHeader zamiast TopMenu + CollapseToggle
          CloudHeader(
            title: _profile!.name,
            collapsed: menuCollapsed,
            onToggle: () => ref.read(menuCollapsedProvider.notifier).toggle(),
            onAddCategory: () => context.push('/categories/${widget.profileId}/editor'),
            onGridConfig: () => _showGridConfigDialog(context),
          ),

          // Categories Grid
          Expanded(
            child: categoriesAsync.when(
              data: (categories) {
                print('📊 UI rendering ${categories.length} categories');
                if (categories.isEmpty) {
                  return _buildEmptyState(context, l10n);
                }
                return _buildCategoriesGrid(context, ref, categories, deleteMode);
              },
              loading: () {
                print('⏳ Categories loading...');
                return const Center(child: CircularProgressIndicator());
              },
              error: (error, stack) {
                print('❌ Categories error: $error');
                return Center(
                  child: Text(l10n.error(error.toString())),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showGridConfigDialog(BuildContext context) async {
    final repository = await ref.read(categoryRepositoryProvider.future);
    final categories = await repository.getByProfileId(widget.profileId);

    int selectedColumns = categories.isNotEmpty ? categories.first.gridConfig.columns : 3;

    final result = await showModalBottomSheet<int>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Uchwyt
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Tytuł z ikoną
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFB74D),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.grid_view, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Kolumny kategorii',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Podgląd siatki
              Container(
                width: 140,
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: List.generate(selectedColumns, (index) {
                      return Expanded(
                        child: Container(
                          margin: EdgeInsets.symmetric(horizontal: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFB74D).withOpacity(0.3),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFFFB74D), width: 1),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '$selectedColumns ${selectedColumns == 1 ? 'kolumna' : selectedColumns < 5 ? 'kolumny' : 'kolumn'}',
                style: TextStyle(fontSize: 14, color: Colors.grey[600], fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 24),

              // Kontrolki +/-
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFB74D).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFFFB74D).withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Minus
                    GestureDetector(
                      onTap: selectedColumns > 1
                          ? () => setState(() => selectedColumns--)
                          : null,
                      child: Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: selectedColumns > 1 ? const Color(0xFFFFB74D) : Colors.grey[300],
                          shape: BoxShape.circle,
                          boxShadow: selectedColumns > 1
                              ? [BoxShadow(color: const Color(0xFFFFB74D).withOpacity(0.4), blurRadius: 8, offset: const Offset(0, 3))]
                              : null,
                        ),
                        child: Icon(Icons.remove, color: selectedColumns > 1 ? Colors.white : Colors.grey[500], size: 28),
                      ),
                    ),
                    // Liczba
                    SizedBox(
                      width: 80,
                      child: Text(
                        '$selectedColumns',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Color(0xFFFFB74D)),
                      ),
                    ),
                    // Plus
                    GestureDetector(
                      onTap: selectedColumns < 6
                          ? () => setState(() => selectedColumns++)
                          : null,
                      child: Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: selectedColumns < 6 ? const Color(0xFFFFB74D) : Colors.grey[300],
                          shape: BoxShape.circle,
                          boxShadow: selectedColumns < 6
                              ? [BoxShadow(color: const Color(0xFFFFB74D).withOpacity(0.4), blurRadius: 8, offset: const Offset(0, 3))]
                              : null,
                        ),
                        child: Icon(Icons.add, color: selectedColumns < 6 ? Colors.white : Colors.grey[500], size: 28),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Przyciski
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Anuluj'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.pop(context, selectedColumns),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFFFB74D),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Zapisz'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );

    if (result == null || !context.mounted) return;

    for (final cat in categories) {
      await repository.update(cat.copyWith(
        gridConfig: GridConfig(columns: result, rows: cat.gridConfig.rows),
        updatedAt: DateTime.now(),
      ));
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('✓ Kolumny: $result'), backgroundColor: Colors.green),
      );
    }
  }

  Widget _buildDrawer(BuildContext context, AppLocalizations l10n) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? Colors.grey[800] : Colors.white;
    final bgColor = isDark ? Colors.grey[900] : Colors.grey[50];
    final textColor = isDark ? Colors.white : Colors.black87;

    return Drawer(
      child: Container(
        color: bgColor,
        child: SafeArea(
          child: Column(
            children: [
              // Header z logo jako tło i zdjęciem profilu
              Container(
                width: double.infinity,
                height: 200,
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[850] : Colors.grey[200],
                ),
                child: Stack(
                  children: [
                    // Logo jako tło - rozciągnięte
                    Positioned.fill(
                      child: Opacity(
                        opacity: isDark ? 0.12 : 0.25,
                        child: Image.asset(
                          'assets/images/app_icon.png',
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),

                    // Gradient overlay
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: isDark
                                ? [
                              Colors.grey[900]!.withOpacity(0.8),
                              Colors.grey[850]!.withOpacity(0.9),
                            ]
                                : [
                              Colors.white.withOpacity(0.8),
                              Colors.grey[100]!.withOpacity(0.9),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Zawartość - zdjęcie profilu i nazwa
                    Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Zdjęcie profilu lub inicjał
                          Container(
                            width: 90,
                            height: 90,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(0xFF7E57C2),
                              border: Border.all(
                                color: isDark ? Colors.grey[700]! : Colors.white,
                                width: 4,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(isDark ? 0.4 : 0.2),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: _profile?.photoPath != null &&
                                _profile!.photoPath!.isNotEmpty &&
                                File(_profile!.photoPath!).existsSync()
                                ? ClipOval(
                              child: Image.file(
                                File(_profile!.photoPath!),
                                fit: BoxFit.cover,
                                width: 90,
                                height: 90,
                              ),
                            )
                                : Center(
                              child: Text(
                                _profile?.name.isNotEmpty == true
                                    ? _profile!.name[0].toUpperCase()
                                    : '?',
                                style: const TextStyle(
                                  fontSize: 40,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Nazwa profilu
                          Text(
                            _profile?.name ?? '',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : const Color(0xFF333333),
                            ),
                          ),
                          const SizedBox(height: 4),

                          // Nazwa aplikacji mała
                          Text(
                            l10n.appTitle,
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark ? Colors.grey[400] : Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Menu items
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // Biblioteka
                    _buildDrawerItem(
                      icon: Icons.library_books,
                      label: l10n.library,
                      color: const Color(0xFF7E57C2),
                      cardColor: cardColor!,
                      textColor: textColor,
                      onTap: () {
                        Navigator.pop(context);
                        context.push('/library');
                      },
                    ),
                    const SizedBox(height: 12),

                    // Theme toggle
                    _buildThemeToggle(context, cardColor, textColor),
                    const SizedBox(height: 12),

                    // Divider
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Divider(color: isDark ? Colors.grey[700] : Colors.grey[300]),
                    ),

                    // Dodaj domyślne kategorie
                    _buildDrawerItem(
                      icon: Icons.refresh,
                      label: 'Dodaj domyślne kategorie',
                      color: const Color(0xFFFFB74D),
                      cardColor: cardColor,
                      textColor: textColor,
                      onTap: () {
                        Navigator.pop(context);
                        _showAddDefaultCategoriesDialog(context);
                      },
                    ),
                    const SizedBox(height: 12),

                    // Dodaj domyślne symbole
                    _buildDrawerItem(
                      icon: Icons.add_photo_alternate,
                      label: 'Dodaj domyślne symbole',
                      color: const Color(0xFF42A5F5),
                      cardColor: cardColor,
                      textColor: textColor,
                      onTap: () {
                        Navigator.pop(context);
                        _showAddDefaultSymbolsDialog(context);
                      },
                    ),
                  ],
                ),
              ),

              // Footer
              Container(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Wersja 1.0.0',
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String label,
    required Color color,
    required Color cardColor,
    required Color textColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey[500]),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeToggle(BuildContext context, Color cardColor, Color textColor) {
    final themeMode = ref.watch(themeModeProvider);
    final isDark = themeMode == ThemeMode.dark;

    return GestureDetector(
      onTap: () => ref.read(themeModeProvider.notifier).toggleTheme(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? [const Color(0xFF5C6BC0), const Color(0xFF3949AB)]
                      : [const Color(0xFFFFB74D), const Color(0xFFFFA726)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                isDark ? Icons.dark_mode : Icons.light_mode,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                isDark ? 'Tryb ciemny' : 'Tryb jasny',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
            ),
            // Custom switch
            Container(
              width: 52,
              height: 28,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF5C6BC0) : Colors.grey[300],
                borderRadius: BorderRadius.circular(14),
              ),
              child: Stack(
                children: [
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 200),
                    left: isDark ? 26 : 2,
                    top: 2,
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAddDefaultCategoriesDialog(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;

    // Sprawdź czy już są jakieś kategorie
    final repository = await ref.read(categoryRepositoryProvider.future);
    final existingCategories = await repository.getByProfileId(widget.profileId);

    if (existingCategories.isNotEmpty) {
      // Pokaż warning że nadpisze
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Dodać domyślne kategorie?'),
          content: const Text(
            'Dodanie domyślnych kategorii nie usunie istniejących.\n\n'
                'Nowe kategorie zostaną dodane na końcu listy.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n.cancel),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Dodaj'),
            ),
          ],
        ),
      );

      if (confirm != true) return;
    } else {
      // Nie ma kategorii - pokaż prostszy dialog
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Dodać domyślne kategorie?'),
          content: const Text(
            'Zostaną dodane podstawowe kategorie.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n.cancel),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Dodaj'),
            ),
          ],
        ),
      );

      if (confirm != true) return;
    }

    // Dodaj kategorie
    try {
      final defaultCategories = await DefaultCategoriesService.createDefaultCategories(
        widget.profileId,
      );

      for (final category in defaultCategories) {
        await repository.create(category);
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('✓ Kategorie zostały dodane'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('❌ Reset error: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Błąd: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildEmptyState(BuildContext context, AppLocalizations l10n) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.category_outlined,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            l10n.noCategories,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            l10n.addFirstCategory,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 24),
          // Przyciski
          ElevatedButton.icon(
            onPressed: () {
              context.push('/categories/${widget.profileId}/editor');
            },
            icon: const Icon(Icons.add),
            label: Text(l10n.addCategory),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () {
              _showAddDefaultCategoriesDialog(context);
            },
            icon: const Icon(Icons.refresh),
            label: const Text('Dodaj domyślne kategorie'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoriesGrid(
      BuildContext context,
      WidgetRef ref,
      List<CategoryModel> categories,
      bool deleteMode,
      ) {
    print('🎨 Building grid with ${categories.length} categories');

    // Pobierz gridConfig z pierwszej kategorii (wszystkie mają taki sam)
    final gridColumns = categories.isNotEmpty
        ? categories.first.gridConfig.columns
        : 3;

    print('📊 Grid columns from category: $gridColumns');

    // Dostosuj spacing w zależności od liczby kolumn
    final spacing = gridColumns <= 3 ? 6.0 : 4.0;

    // Dostosuj aspect ratio - więcej kolumn = wyższe karty
    final aspectRatio = gridColumns <= 3 ? 1.0 : 0.95;

    return SafeArea(
      bottom: true,
      child: GridView.builder(
        padding: const EdgeInsets.all(8),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: gridColumns,
          crossAxisSpacing: spacing, // Dynamiczne
          mainAxisSpacing: spacing,   // Dynamiczne
          childAspectRatio: aspectRatio, // Lekko wyższe dla wielu kolumn
        ),
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final category = categories[index];
          print('📦 Building category card: ${category.name}');

          return CategoryCard(
            category: category,
            deleteMode: deleteMode,
            onTap: () {
              context.push('/categories/${widget.profileId}/symbols/${category.id}');
            },
            onLongPress: () => _showCategoryMenu(context, ref, category),
            onDelete: () => _onCategoryDelete(context, ref, category),
          );
        },
      ),
    );
  }

  void _onCategoryTap(
      BuildContext context,
      WidgetRef ref,
      CategoryModel category,
      ) {
    final deleteMode = ref.read(deleteModeProvider);
    if (deleteMode) return;

    // Nawigacja do edycji kategorii
    context.push('/categories/${widget.profileId}/editor?categoryId=${category.id}');
  }

  void _showCategoryMenu(BuildContext scaffoldContext, WidgetRef ref, CategoryModel category) {
    final l10n = AppLocalizations.of(scaffoldContext)!;

    showModalBottomSheet(
      context: scaffoldContext,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (bottomSheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Uchwyt
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Nazwa kategorii
              Text(
                category.name,
                style: Theme.of(bottomSheetContext).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),

              // Przyciski w rzędzie
              Row(
                children: [
                  // Edytuj kategorię
                  Expanded(
                    child: _buildMenuButton(
                      context: bottomSheetContext,
                      icon: Icons.edit,
                      label: l10n.editCategory,
                      color: const Color(0xFFFDD835), // Żółty
                      onTap: () {
                        Navigator.pop(bottomSheetContext);
                        scaffoldContext.push(
                          '/categories/${widget.profileId}/editor?categoryId=${category.id}',
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Usuń kategorię
                  Expanded(
                    child: _buildMenuButton(
                      context: bottomSheetContext,
                      icon: Icons.delete,
                      label: l10n.deleteCategory,
                      color: const Color(0xFFE53935), // Czerwony
                      iconColor: Colors.white,
                      textColor: Colors.white,
                      onTap: () {
                        Navigator.pop(bottomSheetContext);
                        _onCategoryDelete(scaffoldContext, ref, category);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    required Color color,
    Color iconColor = Colors.black87,
    Color textColor = Colors.black87,
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
              color: iconColor,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _onCategoryDelete(
      BuildContext context,
      WidgetRef ref,
      CategoryModel category,
      ) async {
    final l10n = AppLocalizations.of(context)!;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteCategory),
        content: Text(l10n.confirmDeleteCategory(category.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final repository = await ref.read(categoryRepositoryProvider.future);
      await repository.delete(category.id);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.categoryDeleted),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
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