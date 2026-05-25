import 'package:flutter/material.dart';

class GridConfigDialog extends StatefulWidget {
  final int initialColumns;
  final int initialRows;
  final String title;

  const GridConfigDialog({
    super.key,
    required this.initialColumns,
    required this.initialRows,
    this.title = 'Siatka symboli',
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
    _columns = widget.initialColumns;
    _rows = widget.initialRows;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Tytuł z ikoną
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFF42A5F5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.grid_view, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 12),
                Text(
                  widget.title,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Podgląd siatki
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: _buildGridPreview(),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '$_columns × $_rows',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 24),

            // Kolumny
            _buildCounter(
              label: 'Kolumny',
              value: _columns,
              color: const Color(0xFF66BB6A),
              onDecrement: _columns > 1 ? () => setState(() => _columns--) : null,
              onIncrement: _columns < 6 ? () => setState(() => _columns++) : null,
            ),
            const SizedBox(height: 16),

            // Wiersze
            _buildCounter(
              label: 'Wiersze',
              value: _rows,
              color: const Color(0xFFFFB74D),
              onDecrement: _rows > 1 ? () => setState(() => _rows--) : null,
              onIncrement: _rows < 8 ? () => setState(() => _rows++) : null,
            ),
            const SizedBox(height: 24),

            // Przyciski
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Anuluj'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context, (_columns, _rows)),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF42A5F5),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Zapisz'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGridPreview() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cellWidth = (constraints.maxWidth - (_columns - 1) * 4) / _columns;
        final cellHeight = (constraints.maxHeight - (_rows - 1) * 4) / _rows;

        return Wrap(
          spacing: 4,
          runSpacing: 4,
          children: List.generate(_columns * _rows, (index) {
            return Container(
              width: cellWidth,
              height: cellHeight,
              decoration: BoxDecoration(
                color: const Color(0xFF42A5F5).withOpacity(0.3),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: const Color(0xFF42A5F5), width: 1),
              ),
            );
          }),
        );
      },
    );
  }

  Widget _buildCounter({
    required String label,
    required int value,
    required Color color,
    VoidCallback? onDecrement,
    VoidCallback? onIncrement,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey[800],
            ),
          ),
          const Spacer(),
          // Minus button
          GestureDetector(
            onTap: onDecrement,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: onDecrement != null ? color : Colors.grey[300],
                shape: BoxShape.circle,
                boxShadow: onDecrement != null
                    ? [BoxShadow(color: color.withOpacity(0.3), blurRadius: 6, offset: const Offset(0, 2))]
                    : null,
              ),
              child: Icon(
                Icons.remove,
                color: onDecrement != null ? Colors.white : Colors.grey[500],
                size: 24,
              ),
            ),
          ),
          // Value
          SizedBox(
            width: 50,
            child: Text(
              '$value',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
          // Plus button
          GestureDetector(
            onTap: onIncrement,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: onIncrement != null ? color : Colors.grey[300],
                shape: BoxShape.circle,
                boxShadow: onIncrement != null
                    ? [BoxShadow(color: color.withOpacity(0.3), blurRadius: 6, offset: const Offset(0, 2))]
                    : null,
              ),
              child: Icon(
                Icons.add,
                color: onIncrement != null ? Colors.white : Colors.grey[500],
                size: 24,
              ),
            ),
          ),
        ],
      ),
    );
  }
}