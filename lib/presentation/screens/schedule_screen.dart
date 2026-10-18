import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/app_localizations.dart';
import '../../core/theme/app_colors.dart';
import '../../data/services/app_settings.dart';
import '../../data/services/default_content_service.dart';
import '../providers/board_provider.dart';
import '../providers/caregiver_provider.dart';
import '../providers/sentence_provider.dart';
import '../widgets/aac_tile.dart';
import '../widgets/board_grid.dart';
import '../widgets/symbol_image.dart';

/// Plan dnia z obrazków: „Teraz” i „Potem” + lista kroków do odhaczania.
/// Postęp zapisuje się na dany dzień – jutro plan zaczyna się od nowa.
class ScheduleScreen extends ConsumerStatefulWidget {
  final String profileId;
  const ScheduleScreen({super.key, required this.profileId});

  @override
  ConsumerState<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends ConsumerState<ScheduleScreen> {
  late Set<String> _done;

  @override
  void initState() {
    super.initState();
    _done = ref.read(scheduleProgressProvider).doneToday(widget.profileId);
  }

  Future<void> _save() => ref.read(scheduleProgressProvider).save(widget.profileId, _done);

  void _speak(String text) {
    ref.read(sentenceProvider.notifier).speakSingle(text: text);
  }

  void _toggle(BoardItem item) {
    setState(() {
      if (!_done.remove(item.id)) _done.add(item.id);
    });
    _save();
  }

  void _completeCurrent(List<BoardItem> steps) {
    final l10n = AppLocalizations.of(context)!;
    final current = _firstOpen(steps);
    if (current == null) return;
    if (ref.read(appSettingsProvider).haptics) HapticFeedback.mediumImpact();
    setState(() => _done.add(current.id));
    _save();
    final next = _firstOpen(steps);
    if (next != null) {
      _speak('${l10n.scheduleDone}! ${l10n.scheduleNow}: ${next.name}');
    } else {
      _speak(l10n.scheduleAllDoneSpeech);
    }
  }

  void _reset() {
    setState(() => _done = <String>{});
    ref.read(scheduleProgressProvider).reset(widget.profileId);
  }

  BoardItem? _firstOpen(List<BoardItem> steps) {
    for (final s in steps) {
      if (!_done.contains(s.id)) return s;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final caregiver = ref.watch(caregiverModeProvider);
    final boardAsync = ref.watch(systemBoardProvider((widget.profileId, SystemBoard.schedule)));
    final board = boardAsync.valueOrNull;
    final AsyncValue<List<BoardItem>> itemsAsync;
    if (board != null) {
      itemsAsync = ref.watch(boardItemsProvider((profileId: widget.profileId, categoryId: board.id)));
    } else if (boardAsync.hasError) {
      itemsAsync = AsyncValue.error(boardAsync.error!, boardAsync.stackTrace ?? StackTrace.current);
    } else {
      itemsAsync = const AsyncValue.loading();
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.schedule),
        actions: [
          IconButton(
            tooltip: l10n.scheduleRestart,
            onPressed: _reset,
            icon: const Icon(Icons.restart_alt_rounded),
          ),
          if (caregiver && board != null)
            IconButton(
              tooltip: l10n.scheduleEdit,
              onPressed: () => context.push('/folder/${widget.profileId}/c/${board.id}'),
              icon: const Icon(Icons.edit_rounded),
            ),
          const SizedBox(width: 6),
        ],
      ),
      body: SafeArea(
        top: false,
        child: itemsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text(l10n.error(e.toString()))),
          data: (items) {
            final steps = items.where((i) => !i.isFolder).toList();
            if (steps.isEmpty) {
              return _EmptySchedule(caregiver: caregiver);
            }
            final current = _firstOpen(steps);
            BoardItem? next;
            if (current != null) {
              final idx = steps.indexOf(current);
              for (var i = idx + 1; i < steps.length; i++) {
                if (!_done.contains(steps[i].id)) {
                  next = steps[i];
                  break;
                }
              }
            }
            final landscape = BoardGridLayout.isLandscape(MediaQuery.sizeOf(context));

            final focus = current == null
                ? _AllDone(onRestart: _reset)
                : _NowThen(
                    current: current,
                    next: next,
                    onSpeak: _speak,
                    onDone: () => _completeCurrent(steps),
                  );
            final list = _StepList(
              steps: steps,
              done: _done,
              current: current,
              onSpeak: (item) => _speak(item.name),
              onToggle: _toggle,
            );

            if (landscape) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(flex: 5, child: SingleChildScrollView(child: focus)),
                  Expanded(flex: 4, child: list),
                ],
              );
            }
            return Column(
              children: [
                focus,
                Expanded(child: list),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _NowThen extends StatelessWidget {
  final BoardItem current;
  final BoardItem? next;
  final ValueChanged<String> onSpeak;
  final VoidCallback onDone;

  const _NowThen({
    required this.current,
    required this.next,
    required this.onSpeak,
    required this.onDone,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final palette = context.aac;
    final screen = MediaQuery.sizeOf(context);
    final bigH = (screen.height * 0.27).clamp(150.0, 260.0);

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                flex: 5,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.scheduleNow,
                      style: const TextStyle(color: AppColors.skyDeep, fontWeight: FontWeight.w900, fontSize: 16),
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      height: bigH,
                      child: AacTile(
                        label: current.name,
                        imagePath: current.imagePath,
                        emoji: current.emoji,
                        color: current.color,
                        highlighted: true,
                        onTap: (_) => onSpeak(current.name),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 4,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.scheduleThen,
                      style: TextStyle(color: palette.inkSoft, fontWeight: FontWeight.w900, fontSize: 16),
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      height: bigH * 0.78,
                      child: next == null
                          ? Container(
                              decoration: BoxDecoration(
                                color: palette.surface,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(color: palette.line, width: 2),
                              ),
                              alignment: Alignment.center,
                              child: const Text('🏁', style: TextStyle(fontSize: 44)),
                            )
                          : Opacity(
                              opacity: 0.9,
                              child: AacTile(
                                label: next!.name,
                                imagePath: next!.imagePath,
                                emoji: next!.emoji,
                                color: next!.color,
                                onTap: (_) => onSpeak(next!.name),
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 60,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.leaf,
                textStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, fontFamily: 'Nunito'),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
              onPressed: onDone,
              icon: const Icon(Icons.check_rounded, size: 28),
              label: Text(l10n.scheduleDone),
            ),
          ),
        ],
      ),
    );
  }
}

class _StepList extends StatelessWidget {
  final List<BoardItem> steps;
  final Set<String> done;
  final BoardItem? current;
  final ValueChanged<BoardItem> onSpeak;
  final ValueChanged<BoardItem> onToggle;

  const _StepList({
    required this.steps,
    required this.done,
    required this.current,
    required this.onSpeak,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.aac;
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 20),
      itemCount: steps.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final step = steps[index];
        final isDone = done.contains(step.id);
        final isCurrent = current?.id == step.id;
        return Opacity(
          opacity: isDone ? 0.55 : 1,
          child: Material(
            color: palette.surface,
            borderRadius: BorderRadius.circular(18),
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () => onSpeak(step),
              child: Container(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: isCurrent ? AppColors.sky : palette.line,
                    width: isCurrent ? 3 : 1.5,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: step.color,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: ColoredBox(
                          color: palette.tileWindow,
                          child: SymbolImage(
                            imagePath: step.imagePath,
                            emoji: step.emoji,
                            cacheWidth: 160,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        step.name,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          decoration: isDone ? TextDecoration.lineThrough : null,
                          decorationThickness: 2,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => onToggle(step),
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isDone
                              ? AppColors.leaf
                              : (isCurrent ? AppColors.sky : palette.surfaceHigh),
                        ),
                        alignment: Alignment.center,
                        child: isDone
                            ? const Icon(Icons.check_rounded, color: Colors.white)
                            : Text(
                                '${index + 1}',
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  color: isCurrent ? Colors.white : palette.inkSoft,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _AllDone extends StatelessWidget {
  final VoidCallback onRestart;
  const _AllDone({required this.onRestart});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: AppColors.leaf.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🎉', style: TextStyle(fontSize: 52)),
            const SizedBox(height: 8),
            Text(l10n.scheduleAllDone, style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onRestart,
              icon: const Icon(Icons.restart_alt_rounded),
              label: Text(l10n.scheduleRestart),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptySchedule extends StatelessWidget {
  final bool caregiver;
  const _EmptySchedule({required this.caregiver});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('📅', style: TextStyle(fontSize: 52)),
            const SizedBox(height: 10),
            Text(
              caregiver ? l10n.scheduleEmptyCaregiver : l10n.scheduleEmptyChild,
              textAlign: TextAlign.center,
              style: TextStyle(color: context.aac.inkSoft, fontWeight: FontWeight.w700, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}
