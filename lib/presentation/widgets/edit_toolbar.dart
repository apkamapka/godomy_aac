import 'package:flutter/material.dart';

import '../../core/l10n/app_localizations.dart';
import '../../core/theme/app_colors.dart';

/// Dolny pasek narzędzi w trybie opiekuna.
class EditToolbar extends StatelessWidget {
  final VoidCallback onAdd;
  final VoidCallback onReorder;
  final VoidCallback? onGrid;

  /// Wydruk tablicy do PDF (null = niedostępne, np. pusta tablica).
  final VoidCallback? onPrint;
  final VoidCallback onToggleDelete;
  final VoidCallback onDone;
  final bool deleteMode;

  const EditToolbar({
    super.key,
    required this.onAdd,
    required this.onReorder,
    required this.onToggleDelete,
    required this.onDone,
    required this.deleteMode,
    this.onGrid,
    this.onPrint,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final palette = context.aac;
    return Container(
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
        boxShadow: [
          BoxShadow(
            color: AppColors.ink.withValues(alpha: 0.10),
            blurRadius: 18,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 10, 4, 8),
          child: Row(
            children: [
              _ToolButton(
                icon: Icons.add_rounded,
                label: l10n.add,
                color: AppColors.leaf,
                onTap: onAdd,
              ),
              _ToolButton(
                icon: Icons.swap_vert_rounded,
                label: l10n.order,
                color: AppColors.grape,
                onTap: onReorder,
              ),
              if (onGrid != null)
                _ToolButton(
                  icon: Icons.grid_view_rounded,
                  label: l10n.grid,
                  color: AppColors.sunDeep,
                  onTap: onGrid!,
                ),
              if (onPrint != null)
                _ToolButton(
                  icon: Icons.print_rounded,
                  label: l10n.print,
                  color: AppColors.skyDeep,
                  onTap: onPrint!,
                ),
              _ToolButton(
                icon: deleteMode ? Icons.delete_forever_rounded : Icons.delete_outline_rounded,
                label: deleteMode ? l10n.deleteModeOn : l10n.delete,
                color: AppColors.coralDeep,
                active: deleteMode,
                onTap: onToggleDelete,
              ),
              _ToolButton(
                icon: Icons.check_rounded,
                label: l10n.done,
                color: AppColors.sky,
                active: true,
                onTap: onDone,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ToolButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool active;
  final VoidCallback onTap;

  const _ToolButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Semantics(
        button: true,
        label: label,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: active ? color : color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: active ? Colors.white : color, size: 26),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textScaler: TextScaler.noScaling,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: context.aac.ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
