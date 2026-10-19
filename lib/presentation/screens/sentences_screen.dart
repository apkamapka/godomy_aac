import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/app_localizations.dart';
import '../../core/theme/app_colors.dart';
import '../../data/services/app_settings.dart';
import '../../data/services/sentence_store.dart';
import '../providers/caregiver_provider.dart';
import '../providers/sentence_provider.dart';
import '../widgets/app_sheet.dart';
import '../widgets/scan_scope.dart';
import '../widgets/symbol_image.dart';

/// „Moje zdania”: zdania przygotowane na później + historia wypowiedzianych.
class SentencesScreen extends ConsumerStatefulWidget {
  final String profileId;
  const SentencesScreen({super.key, required this.profileId});

  @override
  ConsumerState<SentencesScreen> createState() => _SentencesScreenState();
}

class _SentencesScreenState extends ConsumerState<SentencesScreen> {
  String? _speakingId;
  int? _speakingIndex;

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/folder/${widget.profileId}');
    }
  }

  Future<void> _speak(StoredSentence sentence) async {
    final notifier = ref.read(sentenceProvider.notifier);
    if (_speakingId == sentence.id) {
      await notifier.stop();
      return;
    }
    if (!ref.read(caregiverModeProvider)) {
      final guardMs = ref.read(profileSettingsProvider(widget.profileId)).repeatGuardMs;
      if (!ref.read(touchGuardProvider).tryActivate(guardMs)) return;
    }
    setState(() {
      _speakingId = sentence.id;
      _speakingIndex = null;
    });
    await notifier.speakItems(sentence.items, onIndex: (i) {
      if (mounted && _speakingId == sentence.id) setState(() => _speakingIndex = i);
    });
    if (mounted && _speakingId == sentence.id) {
      setState(() {
        _speakingId = null;
        _speakingIndex = null;
      });
    }
  }

  void _toBar(StoredSentence sentence) {
    ref.read(sentenceProvider.notifier).addItems(sentence.items);
    _back();
  }

  Future<void> _delete(StoredSentence sentence) async {
    final l10n = AppLocalizations.of(context)!;
    final ok = await showConfirmDialog(
      context,
      title: l10n.deleteSentence,
      message: '„${sentence.text}”',
      confirmLabel: l10n.delete,
      cancelLabel: l10n.cancel,
      destructive: true,
      icon: Icons.delete_rounded,
    );
    if (!ok) return;
    await ref.read(savedSentencesProvider(widget.profileId).notifier).remove(sentence.id);
  }

  Future<void> _saveFromHistory(StoredSentence sentence) async {
    final l10n = AppLocalizations.of(context)!;
    final added = await ref.read(savedSentencesProvider(widget.profileId).notifier).add(sentence.items);
    if (mounted) showToast(context, added ? l10n.sentenceSavedToMine : l10n.sentenceAlreadySaved);
  }

  Future<void> _clearHistory() async {
    final l10n = AppLocalizations.of(context)!;
    final ok = await showConfirmDialog(
      context,
      title: l10n.historyClear,
      message: l10n.historyClearConfirm,
      confirmLabel: l10n.historyClear,
      cancelLabel: l10n.cancel,
      destructive: true,
      icon: Icons.history_rounded,
    );
    if (ok) await ref.read(sentenceHistoryProvider(widget.profileId).notifier).clear();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final caregiver = ref.watch(caregiverModeProvider);
    final settings = ref.watch(profileSettingsProvider(widget.profileId));
    final saved = ref.watch(savedSentencesProvider(widget.profileId));
    final history = ref.watch(sentenceHistoryProvider(widget.profileId));

    return ScanScope(
      enabled: settings.scanning && !caregiver,
      interval: Duration(milliseconds: settings.scanIntervalMs),
      child: DefaultTabController(
        length: 2,
        child: Builder(
          builder: (context) => Scaffold(
            appBar: AppBar(
              leading: ScanTarget(
                radius: 24,
                onSelect: (_) => _back(),
                child: IconButton(
                  tooltip: l10n.back,
                  onPressed: _back,
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
              ),
              title: Text(l10n.mySentences),
              actions: [
                if (caregiver && history.isNotEmpty)
                  IconButton(
                    tooltip: l10n.historyClear,
                    onPressed: _clearHistory,
                    icon: const Icon(Icons.delete_sweep_rounded),
                  ),
              ],
              bottom: TabBar(
                labelStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                tabs: [
                  for (var i = 0; i < 2; i++)
                    ScanTarget(
                      radius: 12,
                      onSelect: (_) => DefaultTabController.of(context).animateTo(i),
                      child: Tab(
                        icon: Icon(i == 0 ? Icons.bookmark_rounded : Icons.history_rounded),
                        text: i == 0 ? l10n.savedTab : l10n.historyTab,
                      ),
                    ),
                ],
              ),
            ),
            body: TabBarView(
              children: [
                _buildList(saved, history: false, caregiver: caregiver, toBar: settings.showSentenceBar),
                _buildList(history, history: true, caregiver: caregiver, toBar: settings.showSentenceBar),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildList(
    List<StoredSentence> list, {
    required bool history,
    required bool caregiver,
    required bool toBar,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final palette = context.aac;
    if (list.isEmpty) {
      final text = history
          ? l10n.historyEmpty
          : (caregiver ? l10n.mySentencesEmptyCaregiver : l10n.mySentencesEmpty);
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(history ? Icons.history_rounded : Icons.forum_rounded, size: 52, color: palette.inkSoft),
              const SizedBox(height: 10),
              Text(
                text,
                textAlign: TextAlign.center,
                style: TextStyle(color: palette.inkSoft, fontWeight: FontWeight.w700, fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }

    final saved = ref.read(savedSentencesProvider(widget.profileId));
    final bottom = 24 + MediaQuery.paddingOf(context).bottom;

    Widget row(StoredSentence s, int index) {
      final alreadySaved = history && saved.any((x) => x.text == s.text);
      return Padding(
        key: ValueKey(s.id),
        padding: const EdgeInsets.only(bottom: 10),
        child: ScanTarget(
          radius: 18,
          onSelect: (_) => _speak(s),
          child: _SentenceRow(
            sentence: s,
            speaking: _speakingId == s.id,
            speakingIndex: _speakingId == s.id ? _speakingIndex : null,
            onTap: () => _speak(s),
            actions: [
              if (toBar)
                IconButton(
                  tooltip: l10n.toSentenceBar,
                  onPressed: () => _toBar(s),
                  icon: const Icon(Icons.input_rounded),
                ),
              if (caregiver && !history)
                IconButton(
                  tooltip: l10n.delete,
                  onPressed: () => _delete(s),
                  icon: const Icon(Icons.delete_outline_rounded, color: AppColors.coralDeep),
                ),
              if (caregiver && history)
                IconButton(
                  tooltip: l10n.saveToMine,
                  onPressed: alreadySaved ? null : () => _saveFromHistory(s),
                  icon: Icon(alreadySaved ? Icons.bookmark_rounded : Icons.bookmark_add_rounded),
                ),
            ],
          ),
        ),
      );
    }

    if (caregiver && !history) {
      return ReorderableListView.builder(
        padding: EdgeInsets.fromLTRB(14, 14, 14, bottom),
        itemCount: list.length,
        onReorder: (oldIndex, newIndex) =>
            ref.read(savedSentencesProvider(widget.profileId).notifier).move(oldIndex, newIndex),
        itemBuilder: (context, index) => row(list[index], index),
      );
    }
    return ListView.builder(
      padding: EdgeInsets.fromLTRB(14, 14, 14, bottom),
      itemCount: list.length,
      itemBuilder: (context, index) => row(list[index], index),
    );
  }
}

class _SentenceRow extends StatelessWidget {
  final StoredSentence sentence;
  final bool speaking;
  final int? speakingIndex;
  final VoidCallback onTap;
  final List<Widget> actions;

  const _SentenceRow({
    required this.sentence,
    required this.speaking,
    required this.speakingIndex,
    required this.onTap,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.aac;
    final items = sentence.items;
    final hasPictures = items.any((i) => (i.imagePath?.isNotEmpty ?? false) || (i.emoji?.isNotEmpty ?? false));
    return Material(
      color: palette.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: speaking ? AppColors.sky : palette.line,
              width: speaking ? 3 : 1.5,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (hasPictures)
                      SizedBox(
                        height: 52,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: items.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 6),
                          itemBuilder: (context, index) {
                            final item = items[index];
                            final active = speakingIndex == index;
                            return AnimatedContainer(
                              duration: const Duration(milliseconds: 140),
                              width: 52,
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                color: item.color,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: active ? AppColors.sky : AppColors.outlineFor(item.color),
                                  width: active ? 3 : 1.5,
                                ),
                              ),
                              child: (item.imagePath?.isNotEmpty ?? false) || (item.emoji?.isNotEmpty ?? false)
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(7),
                                      child: ColoredBox(
                                        color: palette.tileWindow,
                                        child: SymbolImage(
                                          imagePath: item.imagePath,
                                          emoji: item.emoji,
                                          cacheWidth: 150,
                                        ),
                                      ),
                                    )
                                  : Center(
                                      child: Text(
                                        item.label,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.labelOn(item.color),
                                        ),
                                      ),
                                    ),
                            );
                          },
                        ),
                      ),
                    if (hasPictures) const SizedBox(height: 6),
                    Text(
                      sentence.text,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
              Icon(
                speaking ? Icons.stop_rounded : Icons.volume_up_rounded,
                color: speaking ? AppColors.coral : AppColors.sky,
              ),
              ...actions,
            ],
          ),
        ),
      ),
    );
  }
}
