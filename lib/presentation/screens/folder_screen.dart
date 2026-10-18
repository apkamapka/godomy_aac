import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/system_ids.dart';
import '../../core/l10n/app_localizations.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/category_model.dart';
import '../../data/models/category_symbol_model.dart';
import '../../data/models/profile_model.dart';
import '../../data/repositories/category_repository.dart';
import '../../data/repositories/category_symbol_repository.dart';
import '../../data/services/app_settings.dart';
import '../../data/services/default_content_service.dart';
import '../../data/services/tts_service.dart';
import '../providers/board_provider.dart';
import '../providers/caregiver_provider.dart';
import '../providers/symbols_grid_config_provider.dart';
import '../widgets/aac_tile.dart';
import '../widgets/app_drawer.dart';
import '../widgets/app_sheet.dart';
import '../widgets/board_grid.dart';
import '../widgets/caregiver_lock.dart';
import '../widgets/edit_toolbar.dart';
import '../widgets/grid_config_dialog.dart';
import '../widgets/reorder_sheet.dart';
import '../widgets/save_sentence_sheet.dart';
import '../widgets/sentence_bar.dart';
import '../widgets/symbol_image.dart';
import '../widgets/tile_actions.dart';
import '../widgets/urgent_sheet.dart';

/// Tablica komunikacyjna: tablica startowa (categoryId == null) albo folder.
class FolderScreen extends ConsumerStatefulWidget {
  final String profileId;
  final String? categoryId;

  const FolderScreen({
    super.key,
    required this.profileId,
    this.categoryId,
  });

  @override
  ConsumerState<FolderScreen> createState() => _FolderScreenState();
}

class _FolderScreenState extends ConsumerState<FolderScreen> {
  final _flyTarget = GlobalKey();

  bool get _isRoot => widget.categoryId == null;
  BoardKey get _boardKey => (profileId: widget.profileId, categoryId: widget.categoryId);

  @override
  void initState() {
    super.initState();
    // Głos z ustawień profilu (i po każdej zmianie profilu).
    ref.listenManual<AsyncValue<ProfileModel?>>(
      profileProvider(widget.profileId),
      (previous, next) {
        final profile = next.valueOrNull;
        if (profile != null) {
          ref.read(ttsServiceProvider).applySettings(
                voiceName: profile.ttsVoiceId,
                voiceLocale: profile.ttsLanguage,
                rate: profile.ttsRate,
                pitch: profile.ttsPitch,
              );
        }
      },
      fireImmediately: true,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _onOpen());
  }

  Future<void> _onOpen() async {
    if (!mounted) return;
    await ref.read(appSettingsProvider.notifier).setLastProfile(widget.profileId);
    if (_isRoot) {
      try {
        final service = await ref.read(defaultContentServiceProvider.future);
        await service.ensureSystemBoards(widget.profileId);
      } catch (_) {}
    }
  }

  // ---------------------------------------------------------------------------
  // Akcje na kafelkach
  // ---------------------------------------------------------------------------

  void _onTileTap(
    BoardItem item,
    Rect rect, {
    required CommunicationMode mode,
    required ProfileSettings settings,
    required bool deleteMode,
  }) {
    if (deleteMode) {
      _deleteItem(item);
      return;
    }
    if (item.isFolder) {
      if (ref.read(appSettingsProvider).haptics) HapticFeedback.selectionClick();
      context.push('/folder/${widget.profileId}/c/${item.id}');
      return;
    }
    handleSymbolTap(
      context: context,
      ref: ref,
      profileId: widget.profileId,
      item: item,
      rect: rect,
      direct: mode == CommunicationMode.direct,
      settings: settings,
      flyTarget: _flyTarget,
      profile: ref.read(profileProvider(widget.profileId)).valueOrNull,
    );
  }

  void _editItem(BoardItem item) {
    if (item.isFolder) {
      context.push('/folder/${widget.profileId}/category-editor?categoryId=${item.id}');
    } else {
      context.push('/folder/${widget.profileId}/edit-symbol/${item.id}');
    }
  }

  Future<void> _deleteItem(BoardItem item) async {
    final l10n = AppLocalizations.of(context)!;
    final ok = await showConfirmDialog(
      context,
      title: item.isFolder ? l10n.deleteCategory : l10n.deleteSymbol,
      message: item.isFolder
          ? l10n.confirmDeleteCategoryWithContent(item.name)
          : l10n.confirmDeleteSymbol(item.name),
      confirmLabel: l10n.delete,
      cancelLabel: l10n.cancel,
      destructive: true,
      icon: Icons.delete_rounded,
    );
    if (!ok) return;
    try {
      if (item.isFolder) {
        final repo = await ref.read(categoryRepositoryProvider.future);
        await repo.deleteWithChildren(item.id);
      } else {
        final repo = await ref.read(categorySymbolRepositoryProvider.future);
        await repo.delete(item.id);
      }
      if (mounted) showToast(context, item.isFolder ? l10n.categoryDeleted : l10n.symbolDeleted);
    } catch (e) {
      if (mounted) showToast(context, l10n.error(e.toString()), error: true);
    }
  }

  // ---------------------------------------------------------------------------
  // Pasek narzędzi opiekuna
  // ---------------------------------------------------------------------------

  Future<void> _showAddSheet({required bool allowFolders}) async {
    final l10n = AppLocalizations.of(context)!;
    final cid = widget.categoryId;
    final choice = await showAppSheet<String>(
      context: context,
      title: l10n.whatToAdd,
      builder: (sheetContext) => Row(
        children: [
          Expanded(
            child: BigActionButton(
              icon: Icons.add_photo_alternate_rounded,
              label: l10n.addSymbol,
              color: AppColors.leaf,
              filled: true,
              height: 110,
              onTap: () => Navigator.pop(sheetContext, 'symbol'),
            ),
          ),
          if (allowFolders) ...[
            const SizedBox(width: 12),
            Expanded(
              child: BigActionButton(
                icon: Icons.create_new_folder_rounded,
                label: l10n.addCategory,
                color: AppColors.sky,
                filled: true,
                height: 110,
                onTap: () => Navigator.pop(sheetContext, 'folder'),
              ),
            ),
          ],
        ],
      ),
    );
    if (!mounted || choice == null) return;
    if (choice == 'symbol') {
      context.push('/folder/${widget.profileId}/add-symbol${cid != null ? '?categoryId=$cid' : ''}');
    } else {
      context.push('/folder/${widget.profileId}/category-editor${cid != null ? '?parentId=$cid' : ''}');
    }
  }

  Future<void> _reorder(List<BoardItem> items) async {
    final l10n = AppLocalizations.of(context)!;
    if (items.isEmpty) {
      showToast(context, l10n.noItemsToSort);
      return;
    }
    final result = await showReorderSheet(context, items);
    if (result == null) return;
    try {
      final now = DateTime.now();
      final categories = <CategoryModel>[];
      final symbols = <CategorySymbolModel>[];
      for (var i = 0; i < result.length; i++) {
        final item = result[i];
        if (item.category != null) {
          categories.add(item.category!.copyWith(position: i, updatedAt: now));
        } else if (item.symbol != null) {
          symbols.add(item.symbol!.copyWith(position: i, updatedAt: now));
        }
      }
      final catRepo = await ref.read(categoryRepositoryProvider.future);
      final symRepo = await ref.read(categorySymbolRepositoryProvider.future);
      if (categories.isNotEmpty) await catRepo.updateMany(categories);
      if (symbols.isNotEmpty) await symRepo.updateMany(symbols);
      if (mounted) showToast(context, l10n.orderSaved);
    } catch (e) {
      if (mounted) showToast(context, l10n.error(e.toString()), error: true);
    }
  }

  Future<void> _configureGrid(int columns, int rows) async {
    final l10n = AppLocalizations.of(context)!;
    final result = await showDialog<(int, int)>(
      context: context,
      builder: (_) => GridConfigDialog(
        initialColumns: columns,
        initialRows: rows,
        title: l10n.grid,
      ),
    );
    if (result == null) return;
    final (c, r) = result;
    await ref.read(symbolsGridConfigsProvider.notifier).setConfig(
          _gridKey,
          SymbolsGridConfig(columns: c, rows: r),
        );
    if (mounted) showToast(context, l10n.gridSet(c, r));
  }

  String get _gridKey => widget.categoryId ?? 'root_${widget.profileId}';

  // ---------------------------------------------------------------------------
  // Budowanie
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final profileAsync = ref.watch(profileProvider(widget.profileId));
    final profile = profileAsync.valueOrNull;

    if (profileAsync.hasValue && profile == null) {
      return _MissingScreen(
        message: l10n.profileNotFound,
        onTap: () => context.go('/profiles'),
      );
    }

    final caregiver = ref.watch(caregiverModeProvider);
    final deleteMode = ref.watch(deleteModeProvider);
    final settings = ref.watch(profileSettingsProvider(widget.profileId));
    final category = _isRoot ? null : ref.watch(categoryByIdProvider(widget.categoryId!)).valueOrNull;
    final isSystemBoard = category != null && SystemIds.isSystemParent(category.parentId);
    final itemsAsync = ref.watch(boardItemsProvider(_boardKey));
    final items = itemsAsync.valueOrNull ?? const <BoardItem>[];

    final gridConfigs = ref.watch(symbolsGridConfigsProvider);
    final defaultGrid = category?.gridConfig;
    final saved = gridConfigs[_gridKey];
    final columns = saved?.columns ?? defaultGrid?.columns ?? 3;
    final rows = saved?.rows ?? defaultGrid?.rows ?? 3;
    // Tablice systemowe (słowa kluczowe, Pilne, Plan dnia) otwierane do edycji
    // nie mają paska zdania – dotknięcie tylko mówi.
    final mode = isSystemBoard
        ? CommunicationMode.direct
        : (category?.communicationMode ?? CommunicationMode.text);

    final screen = MediaQuery.sizeOf(context);
    final landscape = BoardGridLayout.isLandscape(screen);
    final compact = screen.height < 560;
    final showSentence = settings.showSentenceBar && !isSystemBoard;

    return Scaffold(
      drawer: _isRoot && caregiver ? AppDrawer(profileId: widget.profileId, profile: profile) : null,
      body: SafeArea(
        bottom: !caregiver,
        child: Column(
          children: [
            _buildTopBar(context, profile, category, caregiver, isSystemBoard, screen.width),
            if (showSentence)
              SentenceBar(
                flyTargetKey: _flyTarget,
                jaPhotoPath: profile?.photoPath,
                compact: compact,
                onSaveAsTile: caregiver
                    ? () => showSaveSentenceSheet(
                          context,
                          profileId: widget.profileId,
                          categoryId: widget.categoryId,
                          nextPosition: _nextPosition(items),
                          folderName: category?.name ?? l10n.startBoard,
                        )
                    : null,
              ),
            if (caregiver) _CaregiverStrip(deleteMode: deleteMode),
            if (_isRoot && settings.showCoreWords && !(landscape && compact))
              _buildCoreBand(profile, settings, caregiver),
            Expanded(
              child: itemsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text(l10n.error(e.toString()))),
                data: (items) {
                  if (items.isEmpty) {
                    return _EmptyBoard(
                      caregiver: caregiver,
                      isRoot: _isRoot,
                      onAdd: () => _showAddSheet(allowFolders: !isSystemBoard),
                    );
                  }
                  return BoardGrid(
                    columns: columns,
                    rows: rows,
                    padding: EdgeInsets.fromLTRB(12, caregiver ? 14 : 6, 12, 12),
                    itemCount: items.length,
                    itemBuilder: (context, index) => _buildTile(
                      items[index],
                      profile: profile,
                      settings: settings,
                      mode: mode,
                      caregiver: caregiver,
                      deleteMode: deleteMode,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: caregiver
          ? EditToolbar(
              deleteMode: deleteMode,
              onAdd: () => _showAddSheet(allowFolders: !isSystemBoard),
              onReorder: () => _reorder(items),
              onGrid: () => _configureGrid(columns, rows),
              onToggleDelete: () => ref.read(deleteModeProvider.notifier).state = !deleteMode,
              onDone: () => setCaregiverMode(ref, false),
            )
          : null,
    );
  }

  int _nextPosition(List<BoardItem> items) {
    var maxPos = -1;
    for (final i in items) {
      if (i.position > maxPos) maxPos = i.position;
    }
    return maxPos + 1;
  }

  Widget _buildTile(
    BoardItem item, {
    required ProfileModel? profile,
    required ProfileSettings settings,
    required CommunicationMode mode,
    required bool caregiver,
    required bool deleteMode,
    bool dense = false,
  }) {
    final isJa = isJaItem(item, profile);
    return AacTile(
      label: item.name,
      imagePath: isJa ? profile!.photoPath : item.imagePath,
      emoji: item.emoji,
      imageFit: isJa ? BoxFit.cover : BoxFit.contain,
      color: item.color,
      isFolder: item.isFolder,
      hasRecording: item.hasRecording,
      dense: dense,
      showEdit: caregiver && !deleteMode,
      showDelete: caregiver && deleteMode,
      onTap: (rect) => _onTileTap(
        item,
        rect,
        mode: mode,
        settings: settings,
        deleteMode: caregiver && deleteMode,
      ),
      onLongPress: caregiver ? () => _editItem(item) : null,
      onEdit: () => _editItem(item),
      onDelete: () => _deleteItem(item),
    );
  }

  Widget _buildCoreBand(
    ProfileModel? profile,
    ProfileSettings settings,
    bool caregiver,
  ) {
    final boardAsync = ref.watch(systemBoardProvider((widget.profileId, SystemBoard.core)));
    final board = boardAsync.valueOrNull;
    if (board == null) return const SizedBox.shrink();
    final itemsAsync = ref.watch(boardItemsProvider((profileId: widget.profileId, categoryId: board.id)));
    final words = (itemsAsync.valueOrNull ?? const <BoardItem>[]).where((i) => !i.isFolder).toList();
    if (words.isEmpty && !caregiver) return const SizedBox.shrink();

    return CoreWordsBand(
      itemCount: words.length,
      itemBuilder: (context, index) => _buildTile(
        words[index],
        profile: profile,
        settings: settings,
        mode: CommunicationMode.text,
        caregiver: caregiver,
        deleteMode: false,
        dense: true,
      ),
      trailing: caregiver
          ? _EditCoreButton(onTap: () => context.push('/folder/${widget.profileId}/c/${board.id}'))
          : null,
    );
  }

  Widget _buildTopBar(
    BuildContext context,
    ProfileModel? profile,
    CategoryModel? category,
    bool caregiver,
    bool isSystemBoard,
    double width,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final narrow = width < 400;
    final tiny = width < 380;
    final buttonSize = tiny ? 40.0 : 44.0;
    final gap = tiny ? 4.0 : 6.0;

    final List<Widget> leading;
    if (_isRoot) {
      leading = [
        if (caregiver)
          Builder(
            builder: (ctx) => _CircleIconButton(
              icon: Icons.menu_rounded,
              tooltip: l10n.menu,
              size: buttonSize,
              onTap: () => Scaffold.of(ctx).openDrawer(),
            ),
          ),
        if (caregiver) SizedBox(width: gap),
        ProfileAvatar(name: profile?.name ?? '', photoPath: profile?.photoPath, size: tiny ? 36 : 40),
        SizedBox(width: gap + 2),
        Expanded(
          child: Text(
            profile?.name ?? '',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
          ),
        ),
        _CircleIconButton(
          icon: Icons.star_rounded,
          tooltip: l10n.frequent,
          size: buttonSize,
          onTap: () => context.push('/folder/${widget.profileId}/frequent'),
        ),
        SizedBox(width: gap),
        _CircleIconButton(
          icon: Icons.event_note_rounded,
          tooltip: l10n.schedule,
          size: buttonSize,
          onTap: () => context.push('/folder/${widget.profileId}/schedule'),
        ),
      ];
    } else {
      leading = [
        _CircleIconButton(
          icon: Icons.arrow_back_rounded,
          tooltip: l10n.back,
          onTap: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/folder/${widget.profileId}');
            }
          },
        ),
        const SizedBox(width: 8),
        Expanded(
          child: isSystemBoard
              ? Text(
                  category?.name ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
                )
              : _Breadcrumbs(profileId: widget.profileId, categoryId: widget.categoryId!),
        ),
      ];
    }

    return SizedBox(
      height: 60,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            ...leading,
            SizedBox(width: gap),
            UrgentButton(
              compact: narrow && _isRoot,
              onTap: () => showUrgentSheet(context, widget.profileId),
            ),
            SizedBox(width: gap),
            const LockButton(),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Elementy pomocnicze
// =============================================================================

class _CircleIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final double size;

  const _CircleIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.size = 44,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.aac;
    return Semantics(
      button: true,
      label: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: palette.surface,
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: palette.line, offset: const Offset(0, 2), blurRadius: 0)],
          ),
          child: Icon(icon, color: palette.ink, size: size * 0.54),
        ),
      ),
    );
  }
}

class _Breadcrumbs extends ConsumerWidget {
  final String profileId;
  final String categoryId;

  const _Breadcrumbs({required this.profileId, required this.categoryId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final crumbs = ref.watch(breadcrumbsProvider(categoryId)).valueOrNull ?? const <CategoryModel>[];
    final palette = context.aac;
    final children = <Widget>[
      GestureDetector(
        onTap: () => context.go('/folder/$profileId'),
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: palette.surface,
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: palette.line, offset: const Offset(0, 2), blurRadius: 0)],
          ),
          child: Icon(Icons.home_rounded, size: 19, color: palette.ink),
        ),
      ),
    ];
    for (var i = 0; i < crumbs.length; i++) {
      final isLast = i == crumbs.length - 1;
      final popCount = crumbs.length - 1 - i;
      children.add(Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Icon(Icons.chevron_right_rounded, size: 20, color: palette.inkSoft),
      ));
      children.add(GestureDetector(
        onTap: isLast
            ? null
            : () {
                for (var n = 0; n < popCount; n++) {
                  if (context.canPop()) context.pop();
                }
              },
        child: Text(
          crumbs[i].name,
          style: TextStyle(
            fontSize: isLast ? 19 : 15,
            fontWeight: isLast ? FontWeight.w900 : FontWeight.w700,
            color: isLast ? palette.ink : AppColors.skyDeep,
          ),
        ),
      ));
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      reverse: true,
      child: Row(children: children),
    );
  }
}

class _CaregiverStrip extends StatelessWidget {
  final bool deleteMode;
  const _CaregiverStrip({required this.deleteMode});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final color = deleteMode ? AppColors.coralDeep : AppColors.skyDeep;
    final text = deleteMode ? l10n.deleteModeHint : l10n.caregiverModeHint;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            text,
            style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 13),
          ),
        ),
      ),
    );
  }
}

class _EditCoreButton extends StatelessWidget {
  final VoidCallback onTap;
  const _EditCoreButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.skySoft,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.sky, width: 2),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.edit_rounded, color: AppColors.skyDeep),
            const SizedBox(height: 2),
            Text(
              l10n.editCoreWords,
              textAlign: TextAlign.center,
              maxLines: 2,
              style: const TextStyle(color: AppColors.skyDeep, fontWeight: FontWeight.w900, fontSize: 11.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyBoard extends StatelessWidget {
  final bool caregiver;
  final bool isRoot;
  final VoidCallback onAdd;

  const _EmptyBoard({required this.caregiver, required this.isRoot, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final palette = context.aac;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🖼️', style: TextStyle(fontSize: 56)),
            const SizedBox(height: 12),
            Text(
              isRoot ? l10n.boardEmptyTitle : l10n.folderEmpty,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 6),
            Text(
              caregiver ? l10n.boardEmptyCaregiver : l10n.boardEmptyChild,
              textAlign: TextAlign.center,
              style: TextStyle(color: palette.inkSoft, fontWeight: FontWeight.w600),
            ),
            if (caregiver) ...[
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add_rounded),
                label: Text(l10n.add),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MissingScreen extends StatelessWidget {
  final String message;
  final VoidCallback onTap;
  const _MissingScreen({required this.message, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            FilledButton(onPressed: onTap, child: Text(l10n.selectProfile)),
          ],
        ),
      ),
    );
  }
}
