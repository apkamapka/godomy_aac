import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/l10n/app_localizations.dart';
import '../../data/models/category_model.dart';
import '../../data/models/category_symbol_model.dart';
import '../../data/repositories/category_repository.dart';
import '../../data/repositories/category_symbol_repository.dart';
import '../../data/repositories/library_symbol_repository.dart';
import '../providers/category_symbols_provider.dart';
import '../providers/message_provider.dart';
import '../widgets/symbol_card.dart';
import '../widgets/message_container.dart';
import '../providers/symbols_grid_config_provider.dart';
import 'package:flutter_layout_grid/flutter_layout_grid.dart';
import '../widgets/grid_config_dialog.dart';
import '../../data/services/tts_service.dart';
import '../../data/services/audio_player_service.dart';
import '../widgets/symbols_cloud_header.dart';

class SymbolsScreen extends ConsumerStatefulWidget {
  final String profileId;
  final String categoryId;

  const SymbolsScreen({
    super.key,
    required this.profileId,
    required this.categoryId,
  });

  @override
  ConsumerState<SymbolsScreen> createState() => _SymbolsScreenState();
}

class _SymbolsScreenState extends ConsumerState<SymbolsScreen> {
  CategoryModel? _category;
  bool _isMenuCollapsed = false;
  bool _deleteMode = false;

  @override
  void initState() {
    super.initState();
    _loadCategory();
  }

  Future<void> _loadCategory() async {
    final repository = await ref.read(categoryRepositoryProvider.future);
    final category = await repository.getById(widget.categoryId);
    if (mounted) {
      setState(() {
        _category = category;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final symbolsAsync = ref.watch(categorySymbolsProvider(widget.categoryId));

    if (_category == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 46,
        title: const SizedBox.shrink(),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: Column(
        children: [
          // Cloud Header
          SymbolsCloudHeader(
            title: _category!.name,
            backgroundColor: Color(_category!.backgroundColor),
            collapsed: _isMenuCollapsed,
            deleteMode: _deleteMode,
            keyboardVisible: ref.watch(messageContainerVisibleProvider),
            onToggle: () {
              setState(() {
                _isMenuCollapsed = !_isMenuCollapsed;
              });
            },
            onAddSymbol: () {
              context.push('/categories/${widget.profileId}/symbols/${widget.categoryId}/add');
            },
            onDeleteToggle: () {
              setState(() {
                _deleteMode = !_deleteMode;
              });
            },
            onGridConfig: () => _showGridConfigDialog(context),
            onKeyboardToggle: () {
              ref.read(messageContainerVisibleProvider.notifier).toggle();
            },
          ),

          // Grid with symbols
          Expanded(
            child: symbolsAsync.when(
              data: (symbols) {
                if (symbols.isEmpty) {
                  return _buildEmptyState(context, l10n);
                }
                return _buildSymbolsGrid(context, symbols);
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(
                child: Text(l10n.error(error.toString())),
              ),
            ),
          ),

          // Message Container
          const MessageContainer(),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, AppLocalizations l10n) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.grid_view,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            l10n.noSymbols,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            l10n.addFirstSymbol,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () {
              context.push('/categories/${widget.profileId}/symbols/${widget.categoryId}/add');
            },
            icon: const Icon(Icons.add),
            label: Text(l10n.addSymbol),
          ),
        ],
      ),
    );
  }

  Widget _buildSymbolsGrid(
      BuildContext context,
      List<CategorySymbolModel> symbols,
      ) {
    final gridConfigs = ref.watch(symbolsGridConfigsProvider);
    final symbolsGridConfig = gridConfigs[widget.categoryId] ?? SymbolsGridConfig(
      columns: _category!.gridConfig.columns,
      rows: _category!.gridConfig.rows,
    );

    final columns = symbolsGridConfig.columns;
    final rows = symbolsGridConfig.rows;
    final totalCells = columns * rows;

    final displaySymbols = _category!.scrollLocked
        ? symbols.take(totalCells).toList()
        : symbols;

    final allCells = <Widget>[];

    if (_category!.scrollLocked) {
      for (int i = 0; i < totalCells; i++) {
        if (i < displaySymbols.length) {
          allCells.add(_buildSymbolCard(context, displaySymbols[i]));
        } else {
          allCells.add(Container(
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Colors.grey.withOpacity(0.3),
                width: 1,
              ),
            ),
          ));
        }
      }

      final isKeyboardVisible = ref.watch(messageContainerVisibleProvider);

      return Padding(
        padding: EdgeInsets.only(
          left: 4,
          right: 4,
          top: 4,
          bottom: isKeyboardVisible ? 200 : 4,
        ),
        child: LayoutGrid(
          columnSizes: List.filled(columns, 1.fr),
          rowSizes: List.filled(rows, 1.fr),
          columnGap: 4,
          rowGap: 4,
          children: allCells,
        ),
      );
    } else {
      final totalRows = (displaySymbols.length / columns).ceil();
      final totalCellsWithScroll = totalRows * columns;

      for (int i = 0; i < totalCellsWithScroll; i++) {
        if (i < displaySymbols.length) {
          allCells.add(_buildSymbolCard(context, displaySymbols[i]));
        } else {
          allCells.add(Container(
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Colors.grey.withOpacity(0.3),
                width: 1,
              ),
            ),
          ));
        }
      }

      final screenHeight = MediaQuery.of(context).size.height;
      final availableHeight = screenHeight -
          MediaQuery.of(context).padding.top -
          kToolbarHeight -
          60 -
          180;
      final minRowHeight = availableHeight / rows;
      final isKeyboardVisible = ref.watch(messageContainerVisibleProvider);

      return SingleChildScrollView(
        padding: EdgeInsets.only(
          left: 4,
          right: 4,
          top: 4,
          bottom: isKeyboardVisible ? 200 : 4,
        ),
        child: LayoutGrid(
          columnSizes: List.filled(columns, 1.fr),
          rowSizes: List.filled(totalRows, minRowHeight.px),
          columnGap: 4,
          rowGap: 4,
          children: allCells,
        ),
      );
    }
  }

  Widget _buildSymbolCard(BuildContext context, CategorySymbolModel symbol) {
    return FutureBuilder(
      future: _getLibrarySymbol(symbol.librarySymbolId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Card(
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final librarySymbol = snapshot.data!;
        final emoji = symbol.emojiOverride ?? librarySymbol.emoji;
        final imagePath = symbol.imagePathOverride ?? librarySymbol.imagePath;
        final name = symbol.nameOverride ?? librarySymbol.name;

        return SymbolCard(
          emoji: emoji,
          imagePath: imagePath,
          name: name,
          backgroundColor: symbol.backgroundColor,
          deleteMode: _deleteMode,
          onTap: () => _handleSymbolTap(symbol, librarySymbol),
          onLongPress: () => _showSymbolInfo(context, symbol, librarySymbol),
          onDelete: () => _handleDeleteSymbol(context, symbol),
        );
      },
    );
  }

  Future<dynamic> _getLibrarySymbol(String librarySymbolId) async {
    final repository = await ref.read(librarySymbolRepositoryProvider.future);
    return await repository.getById(librarySymbolId);
  }

  // ✅ ZAKTUALIZOWANA METODA - TTS + nagrania!
  void _handleSymbolTap(CategorySymbolModel categorySymbol, dynamic librarySymbol) async {
    // 1. Dodaj symbol do message container
    final messageSymbol = MessageSymbol.fromCategorySymbol(
      categorySymbol,
      librarySymbol,
    );
    ref.read(messageSymbolsProvider.notifier).add(messageSymbol);

    // 2. Odtwórz dźwięk
    try {
      // PRIORYTET: Nagranie > TTS
      if (categorySymbol.voiceRecordingPath != null) {
        // Odtwórz nagranie
        final audioPlayer = ref.read(audioPlayerServiceProvider);
        await audioPlayer.play(categorySymbol.voiceRecordingPath!);
        print('🎵 Playing recording: ${categorySymbol.voiceRecordingPath}');
      } else {
        // Użyj TTS
        final ttsService = ref.read(ttsServiceProvider);
        final name = categorySymbol.nameOverride ?? librarySymbol.name;
        await ttsService.speak(name);
        print('🗣️ Speaking with TTS: $name');
      }
    } catch (e) {
      print('❌ Error playing audio/TTS: $e');
      // Nie pokazuj błędu użytkownikowi - to nie jest krytyczne
    }
  }

  void _showSymbolInfo(
      BuildContext context,
      CategorySymbolModel categorySymbol,
      dynamic librarySymbol,
      ) {
    final name = categorySymbol.nameOverride ?? librarySymbol.name;
    final emoji = categorySymbol.emojiOverride ?? librarySymbol.emoji;
    final imagePath = categorySymbol.imagePathOverride ?? librarySymbol.imagePath;

    showModalBottomSheet(
      context: context,
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
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Obrazek symbolu
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: Color(categorySymbol.backgroundColor),
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
                  child: _buildSymbolPreview(emoji, imagePath),
                ),
              ),
              const SizedBox(height: 16),

              // Nazwa
              Text(
                name,
                style: Theme.of(bottomSheetContext).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),

              // Info o nagraniu
              if (categorySymbol.voiceRecordingPath != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.mic, size: 16, color: Colors.green[600]),
                      const SizedBox(width: 4),
                      Text(
                        'Ma nagranie głosu',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.green[600],
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 24),

              // Przyciski
              Row(
                children: [
                  // Zamknij
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(bottomSheetContext),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Zamknij',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Edytuj
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        Navigator.pop(bottomSheetContext);
                        context.push('/categories/${widget.profileId}/symbols/${widget.categoryId}/edit/${categorySymbol.id}');
                      },
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Edytuj',
                        style: TextStyle(fontSize: 16),
                      ),
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

  Widget _buildSymbolPreview(String? emoji, String? imagePath) {
    if (imagePath != null && imagePath.isNotEmpty) {
      if (imagePath.startsWith('assets/')) {
        return Image.asset(
          imagePath,
          fit: BoxFit.cover,
        );
      } else {
        return Image.file(
          File(imagePath),
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return const Icon(Icons.broken_image, size: 48, color: Colors.grey);
          },
        );
      }
    } else if (emoji != null && emoji.isNotEmpty) {
      return Center(
        child: Text(
          emoji,
          style: const TextStyle(fontSize: 64),
        ),
      );
    } else {
      return const Icon(Icons.image, size: 48, color: Colors.grey);
    }
  }
  Future<void> _handleDeleteSymbol(
      BuildContext context,
      CategorySymbolModel symbol,
      ) async {
    final l10n = AppLocalizations.of(context)!;

    final librarySymbol = await _getLibrarySymbol(symbol.librarySymbolId);
    final name = symbol.nameOverride ?? librarySymbol.name;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteSymbol),
        content: Text(l10n.confirmDeleteSymbol(name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final repository = await ref.read(categorySymbolRepositoryProvider.future);
      await repository.delete(symbol.id);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.symbolDeleted)),
        );

        setState(() {
          _deleteMode = false;
        });
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

  Future<void> _showGridConfigDialog(BuildContext context) async {
    final gridConfigsNotifier = ref.read(symbolsGridConfigsProvider.notifier);
    final currentConfig = gridConfigsNotifier.getConfig(
      widget.categoryId,
      _category!.gridConfig,
    );

    final result = await showDialog<(int, int)>(
      context: context,
      builder: (context) => GridConfigDialog(
        initialColumns: currentConfig.columns,
        initialRows: currentConfig.rows,
        title: 'Siatka symboli',
      ),
    );

    if (result != null) {
      final (columns, rows) = result;

      await gridConfigsNotifier.setConfig(
        widget.categoryId,
        SymbolsGridConfig(columns: columns, rows: rows),
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✔ Siatka: $columns × $rows'),
            duration: const Duration(seconds: 2),
          ),
        );

        setState(() {});
      }
    }
  }
}