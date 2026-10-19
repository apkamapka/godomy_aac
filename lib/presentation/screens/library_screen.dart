import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/app_localizations.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/library_symbol_model.dart';
import '../../data/repositories/category_symbol_repository.dart';
import '../../data/repositories/library_symbol_repository.dart';
import '../providers/library_symbols_provider.dart';
import '../widgets/app_sheet.dart';
import '../widgets/symbol_image.dart';

/// Biblioteka – wszystkie obrazki dostępne na tym urządzeniu.
class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  String _query = '';

  Future<void> _showDetails(LibrarySymbolModel symbol) async {
    final l10n = AppLocalizations.of(context)!;
    final palette = context.aac;
    final action = await showAppSheet<String>(
      context: context,
      builder: (sheetContext) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 140,
              height: 140,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: symbol.backgroundColor != null ? Color(symbol.backgroundColor!) : palette.surfaceHigh,
                borderRadius: BorderRadius.circular(24),
              ),
              child: SymbolImage(imagePath: symbol.imagePath, emoji: symbol.emoji, cacheWidth: 400),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            symbol.name,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Text(
            '${l10n.usageCount}: ${symbol.usageCount}${symbol.isSystemDefault ? ' · ${l10n.systemSymbol}' : ''}',
            textAlign: TextAlign.center,
            style: TextStyle(color: palette.inkSoft, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: BigActionButton(
                  icon: Icons.edit_rounded,
                  label: l10n.edit,
                  color: AppColors.sky,
                  onTap: () => Navigator.pop(sheetContext, 'edit'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: BigActionButton(
                  icon: Icons.delete_rounded,
                  label: l10n.delete,
                  color: AppColors.coralDeep,
                  onTap: () => Navigator.pop(sheetContext, 'delete'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
    if (!mounted || action == null) return;
    if (action == 'edit') {
      context.push('/library/edit/${symbol.id}');
    } else {
      await _delete(symbol);
    }
  }

  Future<void> _delete(LibrarySymbolModel symbol) async {
    final l10n = AppLocalizations.of(context)!;
    final symbolRepo = await ref.read(categorySymbolRepositoryProvider.future);
    final usages = await symbolRepo.getByLibrarySymbolId(symbol.id);
    if (!mounted) return;
    final ok = await showConfirmDialog(
      context,
      title: l10n.deleteSymbol,
      message: usages.isEmpty
          ? l10n.confirmDeleteSymbol(symbol.name)
          : l10n.libraryDeleteUsed(symbol.name, usages.length),
      confirmLabel: usages.isEmpty ? l10n.delete : l10n.deleteEverywhere,
      cancelLabel: l10n.cancel,
      destructive: true,
      icon: Icons.delete_forever_rounded,
    );
    if (!ok) return;
    try {
      await symbolRepo.deleteByLibrarySymbolId(symbol.id);
      final libraryRepo = await ref.read(librarySymbolRepositoryProvider.future);
      await libraryRepo.delete(symbol.id);
      if (mounted) showToast(context, l10n.symbolDeleted);
    } catch (e) {
      if (mounted) showToast(context, l10n.error(e.toString()), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final palette = context.aac;
    final symbolsAsync = ref.watch(librarySymbolsProvider);
    final width = MediaQuery.sizeOf(context).width;
    final columns = width >= 900 ? 6 : (width >= 600 ? 5 : 3);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.library)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/library/add'),
        icon: const Icon(Icons.add_rounded),
        label: Text(l10n.addSymbol, style: const TextStyle(fontWeight: FontWeight.w900)),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
            child: TextField(
              onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
              decoration: InputDecoration(
                hintText: l10n.searchSymbols,
                prefixIcon: const Icon(Icons.search_rounded),
              ),
            ),
          ),
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
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        _query.isEmpty ? l10n.addFirstSymbolToLibrary : l10n.noResults,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: palette.inkSoft, fontWeight: FontWeight.w700, fontSize: 16),
                      ),
                    ),
                  );
                }
                return GridView.builder(
                  padding: EdgeInsets.fromLTRB(16, 4, 16, 100 + MediaQuery.paddingOf(context).bottom),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.82,
                  ),
                  itemCount: list.length,
                  itemBuilder: (context, index) {
                    final s = list[index];
                    final bg = s.backgroundColor != null ? Color(s.backgroundColor!) : palette.surface;
                    return Material(
                      color: bg,
                      borderRadius: BorderRadius.circular(18),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: () => _showDetails(s),
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(6, 6, 6, 4),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: palette.line, width: 1.5),
                          ),
                          child: Column(
                            children: [
                              Expanded(
                                child: Container(
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    color: palette.tileWindow,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  padding: const EdgeInsets.all(6),
                                  child: SymbolImage(imagePath: s.imagePath, emoji: s.emoji, cacheWidth: 240),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                s.name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                  height: 1.1,
                                  color: s.backgroundColor != null ? AppColors.labelOn(bg) : palette.ink,
                                ),
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
    );
  }
}
