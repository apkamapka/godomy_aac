import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/profile_model.dart';
import '../../data/repositories/library_symbol_repository.dart';
import '../../data/services/app_settings.dart';
import '../providers/board_provider.dart';
import '../providers/sentence_provider.dart';
import 'fly_to_target.dart';
import 'symbol_image.dart';

/// Czy kafelek to „ja”, które pokazujemy ze zdjęciem profilu
/// ([enabled] – ustawienie „Zdjęcie przy »ja«”).
bool isJaItem(BoardItem item, ProfileModel? profile, {bool enabled = true}) {
  if (!enabled || item.isFolder || profile == null) return false;
  final photo = profile.photoPath;
  return photo != null && photo.isNotEmpty && item.name.trim().toLowerCase() == 'ja';
}

/// Wspólna obsługa dotknięcia symbolu (tablica, „Częste”):
/// dodanie do zdania + animacja + mowa + statystyka użycia.
void handleSymbolTap({
  required BuildContext context,
  required WidgetRef ref,
  required String profileId,
  required BoardItem item,
  required Rect rect,
  required bool direct,
  required ProfileSettings settings,
  required GlobalKey flyTarget,
  ProfileModel? profile,
}) {
  if (ref.read(appSettingsProvider).haptics) HapticFeedback.selectionClick();

  recordSymbolUsage(ref, profileId, item);
  final sentence = ref.read(sentenceProvider.notifier);
  final speakOnly = direct || !settings.showSentenceBar;
  if (!speakOnly) {
    sentence.addItem(item);
    if (settings.animations) {
      flyToSentence(
        context: context,
        flyTarget: flyTarget,
        item: item,
        from: rect,
        profile: settings.jaPhoto ? profile : null,
      );
    }
  }
  if (speakOnly || settings.speakOnTap) {
    sentence.speakSingle(text: item.name, voicePath: item.voicePath);
  }
}

void recordSymbolUsage(WidgetRef ref, String profileId, BoardItem item) {
  ref.read(usageStoreProvider).increment(profileId, item.id);
  final lib = item.library;
  if (lib != null) _incrementLibraryUsage(ref, lib.id);
}

Future<void> _incrementLibraryUsage(WidgetRef ref, String librarySymbolId) async {
  try {
    final repo = await ref.read(librarySymbolRepositoryProvider.future);
    await repo.incrementUsageCount(librarySymbolId);
  } catch (_) {
    // Statystyka nie jest krytyczna.
  }
}

/// Animacja obrazka lecącego z kafelka do paska zdania.
void flyToSentence({
  required BuildContext context,
  required GlobalKey flyTarget,
  required BoardItem item,
  required Rect from,
  ProfileModel? profile,
}) {
  final targetContext = flyTarget.currentContext;
  if (targetContext == null) return;
  final box = targetContext.findRenderObject() as RenderBox?;
  if (box == null || !box.attached || !box.hasSize) return;
  final target = box.localToGlobal(Offset.zero) & box.size;
  final toSize = target.height * 0.85;
  final to = Rect.fromCenter(center: target.center, width: toSize, height: toSize);
  final fromSize = from.shortestSide * 0.7;
  final start = Rect.fromCenter(center: from.center, width: fromSize, height: fromSize);
  final isJa = isJaItem(item, profile);

  FlyToTarget.run(
    context: context,
    from: start,
    to: to,
    child: Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: item.color,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: AppColors.ink.withValues(alpha: 0.2), blurRadius: 10)],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: ColoredBox(
          color: context.aac.tileWindow,
          child: SymbolImage(
            imagePath: isJa ? profile!.photoPath : item.imagePath,
            emoji: item.emoji,
            fit: isJa ? BoxFit.cover : BoxFit.contain,
            cacheWidth: 256,
          ),
        ),
      ),
    ),
  );
}
