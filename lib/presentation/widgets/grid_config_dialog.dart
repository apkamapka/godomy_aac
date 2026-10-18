import 'package:flutter/material.dart';

import '../../core/l10n/app_localizations.dart';
import '../../core/theme/app_colors.dart';

/// Wybór liczby kolumn i wierszy siatki (z podglądem).
class GridConfigDialog extends StatefulWidget {
  final int initialColumns;
  final int initialRows;
  final String title;

  const GridConfigDialog({
    super.key,
    required this.initialColumns,
    required this.initialRows,
    this.title = 'Siatka',
  });

  @override
  State<GridConfigDialog> createState() => _GridConfigDialogState();
}

class _GridConfigDialogState extends State<GridConfigDialog> {
  late int _columns;
  late int _rows;

  @override
  void initState() {
    super.initState();
    _columns = widget.initialColumns.clamp(1, 6);
    _rows = widget.initialRows.clamp(1, 8);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final palette = context.aac;
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(widget.title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(
                l10n.gridHint,
                textAlign: TextAlign.center,
                style: TextStyle(color: palette.inkSoft, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 18),
              Container(
                width: 150,
                height: 150,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: palette.paper,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: _GridPreview(columns: _columns, rows: _rows),
              ),
              const SizedBox(height: 8),
              Text(
                '$_columns × $_rows',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 18),
              _Counter(
                label: l10n.gridColumns,
                value: _columns,
                color: AppColors.leaf,
                onDecrement: _columns > 1 ? () => setState(() => _columns--) : null,
                onIncrement: _columns < 6 ? () => setState(() => _columns++) : null,
              ),
              const SizedBox(height: 12),
              _Counter(
                label: l10n.gridRows,
                value: _rows,
                color: AppColors.sunDeep,
                onDecrement: _rows > 1 ? () => setState(() => _rows--) : null,
                onIncrement: _rows < 8 ? () => setState(() => _rows++) : null,
              ),
              const SizedBox(height: 22),
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
                      onPressed: () => Navigator.pop(context, (_columns, _rows)),
                      child: Text(l10n.save),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GridPreview extends StatelessWidget {
  final int columns;
  final int rows;
  const _GridPreview({required this.columns, required this.rows});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var r = 0; r < rows; r++) ...[
          if (r > 0) const SizedBox(height: 4),
          Expanded(
            child: Row(
              children: [
                for (var c = 0; c < columns; c++) ...[
                  if (c > 0) const SizedBox(width: 4),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.sky.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(color: AppColors.sky, width: 1.5),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _Counter extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  final VoidCallback? onDecrement;
  final VoidCallback? onIncrement;

  const _Counter({
    required this.label,
    required this.value,
    required this.color,
    this.onDecrement,
    this.onIncrement,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          ),
          _RoundButton(icon: Icons.remove_rounded, color: color, onTap: onDecrement),
          SizedBox(
            width: 48,
            child: Text(
              '$value',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: color),
            ),
          ),
          _RoundButton(icon: Icons.add_rounded, color: color, onTap: onIncrement),
        ],
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  const _RoundButton({required this.icon, required this.color, this.onTap});

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Material(
      color: enabled ? color : context.aac.line,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 42,
          height: 42,
          child: Icon(icon, color: Colors.white),
        ),
      ),
    );
  }
}
