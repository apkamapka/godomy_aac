import 'package:flutter/material.dart';

import '../../core/l10n/app_localizations.dart';
import '../../core/theme/app_colors.dart';
import '../providers/board_provider.dart';
import 'symbol_image.dart';

/// Arkusz zmiany kolejności kafelków. Zwraca nową kolejność albo null.
Future<List<BoardItem>?> showReorderSheet(BuildContext context, List<BoardItem> items) {
  return showModalBottomSheet<List<BoardItem>>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    useRootNavigator: true,
    builder: (_) => _ReorderSheet(items: items),
  );
}

class _ReorderSheet extends StatefulWidget {
  final List<BoardItem> items;
  const _ReorderSheet({required this.items});

  @override
  State<_ReorderSheet> createState() => _ReorderSheetState();
}

class _ReorderSheetState extends State<_ReorderSheet> {
  late final List<BoardItem> _items = List.of(widget.items);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final palette = context.aac;
    final height = MediaQuery.sizeOf(context).height * 0.82;

    return SizedBox(
      height: height,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
        child: Column(
          children: [
            Center(
              child: Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(color: palette.line, borderRadius: BorderRadius.circular(3)),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.grape.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.swap_vert_rounded, color: AppColors.grape),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(l10n.changeOrder, style: Theme.of(context).textTheme.titleLarge)),
              ],
            ),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                l10n.reorderHint,
                style: TextStyle(color: palette.inkSoft, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ReorderableListView.builder(
                buildDefaultDragHandles: false,
                itemCount: _items.length,
                onReorder: (oldIndex, newIndex) {
                  setState(() {
                    if (newIndex > oldIndex) newIndex -= 1;
                    final item = _items.removeAt(oldIndex);
                    _items.insert(newIndex, item);
                  });
                },
                itemBuilder: (context, index) {
                  final item = _items[index];
                  return Padding(
                    key: ValueKey('${item.kind.name}_${item.id}'),
                    padding: const EdgeInsets.only(bottom: 8),
                    child: ReorderableDelayedDragStartListener(
                      index: index,
                      child: Container(
                        decoration: BoxDecoration(
                          color: item.color,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.outlineFor(item.color), width: 1.5),
                        ),
                        padding: const EdgeInsets.fromLTRB(8, 6, 4, 6),
                        child: Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: palette.tileWindow,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: SymbolImage(
                                imagePath: item.imagePath,
                                emoji: item.emoji,
                                cacheWidth: 144,
                                fallbackIcon: item.isFolder ? Icons.folder_rounded : Icons.image_outlined,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 16,
                                      color: AppColors.labelOn(item.color),
                                    ),
                                  ),
                                  Text(
                                    item.isFolder ? l10n.kindFolder : l10n.kindSymbol,
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.labelOn(item.color).withValues(alpha: 0.7),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              '${index + 1}',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                color: AppColors.labelOn(item.color).withValues(alpha: 0.6),
                              ),
                            ),
                            ReorderableDragStartListener(
                              index: index,
                              child: Padding(
                                padding: const EdgeInsets.all(10),
                                child: Icon(
                                  Icons.drag_indicator_rounded,
                                  color: AppColors.labelOn(item.color).withValues(alpha: 0.7),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(l10n.cancel),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context, _items),
                    child: Text(l10n.save),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
