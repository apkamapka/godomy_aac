import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/l10n/app_localizations.dart';
import '../../data/repositories/category_symbol_repository.dart';
import '../providers/library_symbols_provider.dart';
import '../../data/models/library_symbol_model.dart';
import '../../data/repositories/library_symbol_repository.dart';

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.library),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => _showLibraryInfo(context),
          ),
        ],
      ),
      body: Column(
        children: [
          // Wyszukiwarka
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: l10n.searchSymbols,
                prefixIcon: Icon(Icons.search, color: Theme.of(context).colorScheme.primary),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    setState(() {
                      _searchController.clear();
                      _searchQuery = '';
                    });
                  },
                )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: Theme.of(context).colorScheme.primary,
                    width: 2,
                  ),
                ),
                filled: true,
                fillColor: Theme.of(context).brightness == Brightness.dark
                    ? Colors.grey[800]
                    : Colors.grey[50],
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase();
                });
              },
            ),
          ),

          // Lista symboli
          Expanded(
            child: StreamBuilder<List<LibrarySymbolModel>>(
              stream: ref.watch(librarySymbolsProvider.stream),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text(l10n.error(snapshot.error.toString())));
                }

                final allSymbols = snapshot.data ?? [];
                allSymbols.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

                final symbols = _searchQuery.isEmpty
                    ? allSymbols
                    : allSymbols.where((s) => s.name.toLowerCase().contains(_searchQuery)).toList();

                if (symbols.isEmpty) {
                  return _buildEmptyState(context, l10n);
                }

                return _buildSymbolsGrid(context, symbols);
              },
            ),
          ),
        ],
      ),
      floatingActionButton: _buildFAB(context, l10n),
    );
  }

  Widget _buildFAB(BuildContext context, AppLocalizations l10n) {
    return GestureDetector(
      onTap: () => context.push('/library/add'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
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
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.add, color: Colors.white, size: 24),
            const SizedBox(width: 8),
            Text(
              l10n.addSymbol,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, AppLocalizations l10n) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.photo_library_outlined, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isEmpty ? l10n.noSymbols : 'Brak wyników',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isEmpty ? l10n.addFirstSymbol : 'Spróbuj innego wyszukiwania',
            style: TextStyle(color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildSymbolsGrid(BuildContext context, List<LibrarySymbolModel> symbols) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 0.85,
      ),
      itemCount: symbols.length,
      itemBuilder: (context, index) {
        final symbol = symbols[index];
        return _buildSymbolCard(context, symbol);
      },
    );
  }

  Widget _buildSymbolCard(BuildContext context, LibrarySymbolModel symbol) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () => _showSymbolDetails(context, symbol),
      onLongPress: () => _showSymbolMenu(context, symbol),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? Colors.grey[800] : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.3 : 0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            // Obrazek
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[700] : Colors.grey[100],
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: Center(
                  child: symbol.emoji != null
                      ? Text(symbol.emoji!, style: const TextStyle(fontSize: 48))
                      : symbol.imagePath != null
                      ? ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                    child: Image.file(
                      File(symbol.imagePath!),
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                      errorBuilder: (context, error, stackTrace) {
                        return const Icon(Icons.broken_image, size: 48, color: Colors.red);
                      },
                    ),
                  )
                      : Icon(Icons.image, size: 48, color: Colors.grey[400]),
                ),
              ),
            ),
            // Nazwa
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
              ),
              child: Text(
                symbol.name,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.black87,
                ),
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

  void _showSymbolDetails(BuildContext context, LibrarySymbolModel symbol) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
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
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Obrazek
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[700] : Colors.grey[100],
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: symbol.emoji != null
                    ? Center(child: Text(symbol.emoji!, style: const TextStyle(fontSize: 64)))
                    : symbol.imagePath != null
                    ? Image.file(File(symbol.imagePath!), fit: BoxFit.cover)
                    : Icon(Icons.image, size: 64, color: Colors.grey[400]),
              ),
            ),
            const SizedBox(height: 16),
            // Nazwa
            Text(
              symbol.name,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            // Tagi
            if (symbol.tags.isNotEmpty) ...[
              Wrap(
                spacing: 6,
                children: symbol.tags
                    .map((tag) => Chip(
                  label: Text(tag, style: const TextStyle(fontSize: 12)),
                  backgroundColor: const Color(0xFF42A5F5).withOpacity(0.1),
                ))
                    .toList(),
              ),
              const SizedBox(height: 8),
            ],
            // Info
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.bar_chart, size: 16, color: Colors.grey[500]),
                const SizedBox(width: 4),
                Text('${l10n.usageCount}: ${symbol.usageCount}',
                    style: TextStyle(color: Colors.grey[600])),
              ],
            ),
            if (symbol.isSystemDefault) ...[
              const SizedBox(height: 4),
              Text(
                l10n.systemSymbol,
                style: const TextStyle(
                  color: Color(0xFF7E57C2),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
            const SizedBox(height: 20),
            // Przycisk zamknij
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(l10n.close),
              ),
            ),
            const SizedBox(height: 28),
          ],
        ),
      ),
    );
  }

  void _showSymbolMenu(BuildContext context, LibrarySymbolModel symbol) {
    final l10n = AppLocalizations.of(context)!;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (bottomSheetContext) => Padding(
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
            // Nazwa symbolu
            Text(
              symbol.name,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            // Przyciski
            Row(
              children: [
                Expanded(
                  child: _buildMenuButton(
                    icon: Icons.edit,
                    label: l10n.edit,
                    color: const Color(0xFFFDD835),
                    textColor: Colors.black87,
                    onTap: () {
                      Navigator.pop(bottomSheetContext);
                      context.push('/library/edit/${symbol.id}');
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMenuButton(
                    icon: Icons.delete,
                    label: l10n.deleteSymbol,
                    color: const Color(0xFFE53935),
                    textColor: Colors.white,
                    onTap: () {
                      Navigator.pop(bottomSheetContext);
                      _handleDeleteSymbol(context, symbol);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
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
            BoxShadow(
              color: color.withOpacity(0.4),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, size: 32, color: textColor),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textColor),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleDeleteSymbol(BuildContext context, LibrarySymbolModel symbol) async {
    final l10n = AppLocalizations.of(context)!;

    try {
      final categorySymbolRepo = await ref.read(categorySymbolRepositoryProvider.future);
      final allCategorySymbols = await categorySymbolRepo.getAll();
      final usagesInCategories = allCategorySymbols.where((cs) => cs.librarySymbolId == symbol.id).toList();
      final usageCount = usagesInCategories.length;

      if (!mounted) return;

      final confirm = await _showDeleteConfirmDialog(context, symbol, usageCount, l10n);

      if (confirm != true) return;

      // Usuwanie
      if (usagesInCategories.isNotEmpty) {
        for (final categorySymbol in usagesInCategories) {
          await categorySymbolRepo.delete(categorySymbol.id);
        }
      }

      final libraryRepo = await ref.read(librarySymbolRepositoryProvider.future);
      await libraryRepo.delete(symbol.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(usageCount > 0
                ? '✓ Symbol usunięty z biblioteki i $usageCount kategorii'
                : l10n.symbolDeleted),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.error(e.toString())), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<bool?> _showDeleteConfirmDialog(
      BuildContext context,
      LibrarySymbolModel symbol,
      int usageCount,
      AppLocalizations l10n,
      ) {
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
              decoration: BoxDecoration(
                color: const Color(0xFFE53935),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.delete_forever, size: 32, color: Colors.white),
            ),
            const SizedBox(height: 12),
            const Text('Usuń symbol', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              '"${symbol.name}"',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 16),
            if (symbol.isSystemDefault)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning, color: Colors.orange, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text('To jest symbol systemowy',
                          style: TextStyle(color: Colors.orange[900], fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            if (usageCount > 0)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber, color: Colors.red, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Symbol używany w $usageCount ${usageCount == 1 ? 'kategorii' : 'kategoriach'}',
                        style: TextStyle(color: Colors.red[900], fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 8),
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
                    child: Text(usageCount > 0 ? 'Usuń wszędzie' : l10n.delete),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  void _showLibraryInfo(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final count = await ref.read(librarySymbolsCountProvider.future);

    if (context.mounted) {
      showModalBottomSheet(
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
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
              ),
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: const Color(0xFF7E57C2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.library_books, size: 32, color: Colors.white),
              ),
              const SizedBox(height: 12),
              Text(l10n.library, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(l10n.libraryInfo(count), style: TextStyle(color: Colors.grey[600])),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(l10n.close),
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      );
    }
  }
}