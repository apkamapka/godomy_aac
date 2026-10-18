import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Wspólny wygląd arkuszy (bottom sheet): uchwyt, tytuł, treść.
Future<T?> showAppSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  String? title,
  String? subtitle,
  IconData? icon,
  Color? iconColor,
  bool scrollable = false,
  bool useRootNavigator = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    useRootNavigator: useRootNavigator,
    builder: (sheetContext) {
      final content = Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 10,
          bottom: 20 + MediaQuery.viewInsetsOf(sheetContext).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SheetHandle(),
            if (title != null) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  if (icon != null) ...[
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: (iconColor ?? AppColors.sky).withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(icon, color: iconColor ?? AppColors.sky),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(sheetContext).textTheme.titleLarge,
                    ),
                  ),
                ],
              ),
            ],
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: TextStyle(color: sheetContext.aac.inkSoft, fontWeight: FontWeight.w600),
              ),
            ],
            const SizedBox(height: 16),
            if (scrollable) builder(sheetContext) else Flexible(child: builder(sheetContext)),
          ],
        ),
      );
      if (scrollable) {
        return SingleChildScrollView(child: content);
      }
      return content;
    },
  );
}

class SheetHandle extends StatelessWidget {
  const SheetHandle({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 44,
        height: 5,
        decoration: BoxDecoration(
          color: context.aac.line,
          borderRadius: BorderRadius.circular(3),
        ),
      ),
    );
  }
}

/// Potwierdzenie (np. usuwanie). Zwraca true po zatwierdzeniu.
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  String cancelLabel = 'Anuluj',
  bool destructive = false,
  IconData? icon,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: icon == null
          ? null
          : Icon(icon, size: 36, color: destructive ? AppColors.coralDeep : AppColors.sky),
      title: Text(title, textAlign: icon == null ? TextAlign.start : TextAlign.center),
      content: Text(message),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(cancelLabel),
        ),
        FilledButton(
          style: destructive
              ? FilledButton.styleFrom(backgroundColor: AppColors.coralDeep)
              : null,
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// Duży przycisk-kafelek z ikoną (używany w arkuszach i edytorach).
class BigActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;
  final bool filled;
  final double height;

  const BigActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    this.onTap,
    this.filled = false,
    this.height = 88,
  });

  @override
  Widget build(BuildContext context) {
    final edge = AppColors.edgeFor(color);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = filled ? color : color.withValues(alpha: isDark ? 0.22 : 0.14);
    // Na ciemnym tle ciemniejszy „brzeg” byłby słabo widoczny.
    final fg = filled ? Colors.white : (isDark ? color : edge);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          height: height,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: filled ? edge : color.withValues(alpha: 0.35), width: 2),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 30, color: fg),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                // Długie słowo (np. „Biblioteka”) w wąskim przycisku zmniejszamy
                // zamiast obcinać.
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    style: TextStyle(color: fg, fontWeight: FontWeight.w900, fontSize: 14.5, height: 1.1),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Nagłówek sekcji w formularzach i ustawieniach.
class SectionTitle extends StatelessWidget {
  final String text;
  final EdgeInsetsGeometry padding;

  const SectionTitle(this.text, {super.key, this.padding = const EdgeInsets.fromLTRB(4, 20, 4, 10)});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Text(
        text,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w900,
          color: context.aac.inkSoft,
        ),
      ),
    );
  }
}

/// Komunikat na dole ekranu w jednym stylu.
void showToast(BuildContext context, String message, {bool error = false}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? AppColors.coralDeep : null,
        duration: const Duration(seconds: 2),
      ),
    );
}
