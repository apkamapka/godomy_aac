import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_colors.dart';

/// Skanowanie (dostęp przełącznikiem): elementy oznaczone [ScanTarget]
/// podświetlają się po kolei, a dotknięcie ekranu (albo przycisk – spacja,
/// Enter – np. z przełącznika Bluetooth) wybiera podświetlony element.
///
/// Kolejność wynika z położenia na ekranie: wiersz po wierszu, od lewej.
class ScanScope extends StatefulWidget {
  final bool enabled;
  final Duration interval;

  /// Od tej odległości od góry dotknięcie wybiera element. Wyżej (np. pasek
  /// z kłódką opiekuna) dotyk działa normalnie.
  final double tapAreaTop;

  final Widget child;

  const ScanScope({
    super.key,
    required this.enabled,
    required this.child,
    this.interval = const Duration(milliseconds: 1500),
    this.tapAreaTop = 0,
  });

  @override
  State<ScanScope> createState() => _ScanScopeState();
}

class ScanController extends ChangeNotifier {
  final List<_ScanTargetState> _targets = [];
  _ScanTargetState? _current;
  bool _enabled = false;

  bool get enabled => _enabled;

  void _add(_ScanTargetState t) => _targets.add(t);

  void _remove(_ScanTargetState t) {
    _targets.remove(t);
    // Bez powiadamiania: usuwanie dzieje się przy rozmontowywaniu drzewa,
    // a pozostałe cele i tak nie były podświetlone.
    if (identical(_current, t)) _current = null;
  }

  void _setCurrent(_ScanTargetState? t) {
    if (identical(_current, t)) return;
    _current = t;
    notifyListeners();
  }

  void _setEnabled(bool value) {
    if (_enabled == value) return;
    _enabled = value;
    if (!value) _current = null;
    notifyListeners();
  }

  bool _isCurrent(_ScanTargetState t) => _enabled && identical(_current, t);

  /// Widoczne cele w kolejności czytania (wiersze z tolerancją).
  List<_ScanTargetState> _ordered() {
    final withRects = <(_ScanTargetState, Rect)>[];
    for (final t in _targets) {
      final r = t._globalRect();
      if (r != null) withRects.add((t, r));
    }
    withRects.sort((a, b) => a.$2.center.dy.compareTo(b.$2.center.dy));
    final rows = <List<(_ScanTargetState, Rect)>>[];
    for (final e in withRects) {
      if (rows.isNotEmpty && (e.$2.center.dy - rows.last.first.$2.center.dy).abs() <= 24) {
        rows.last.add(e);
      } else {
        rows.add([e]);
      }
    }
    final result = <_ScanTargetState>[];
    for (final row in rows) {
      row.sort((a, b) => a.$2.left.compareTo(b.$2.left));
      result.addAll(row.map((e) => e.$1));
    }
    return result;
  }
}

class _ScanScopeState extends State<ScanScope> {
  final _controller = ScanController();
  final _focus = FocusNode(debugLabel: 'scan');
  Timer? _timer;
  int _index = -1;
  ModalRoute<dynamic>? _route;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _route = ModalRoute.of(context);
  }

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(covariant ScanScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.enabled != widget.enabled || oldWidget.interval != widget.interval) {
      _sync();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _focus.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _sync() {
    _timer?.cancel();
    _timer = null;
    _index = -1;
    _controller._setEnabled(widget.enabled);
    if (widget.enabled) {
      _timer = Timer.periodic(widget.interval, (_) => _tick());
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && widget.enabled) _focus.requestFocus();
      });
    }
  }

  bool get _routeIsCurrent => _route?.isCurrent ?? true;

  void _tick() {
    if (!mounted || !widget.enabled || !_routeIsCurrent) return;
    final targets = _controller._ordered();
    if (targets.isEmpty) {
      _controller._setCurrent(null);
      return;
    }
    _index = (_index + 1) % targets.length;
    final target = targets[_index];
    _controller._setCurrent(target);
    target._reveal();
  }

  void _select() {
    final target = _controller._current;
    if (target == null || !target.mounted) return;
    HapticFeedback.selectionClick();
    _controller._setCurrent(null);
    _index = -1;
    // Odliczanie od nowa – następne podświetlenie po pełnym odstępie.
    _sync();
    target._activate();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (!widget.enabled || event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.space ||
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter ||
        key == LogicalKeyboardKey.select) {
      _select();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    // Struktura drzewa jest zawsze ta sama (włączanie skanowania nie
    // przebudowuje tablicy i nie gubi jej stanu).
    return _ScanInherited(
      controller: _controller,
      child: Focus(
        focusNode: _focus,
        canRequestFocus: widget.enabled,
        skipTraversal: true,
        onKeyEvent: _onKey,
        child: Stack(
          fit: StackFit.passthrough,
          children: [
            widget.child,
            if (widget.enabled)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                top: widget.tapAreaTop,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _select,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ScanInherited extends InheritedWidget {
  final ScanController controller;

  const _ScanInherited({required this.controller, required super.child});

  static ScanController? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_ScanInherited>()?.controller;

  @override
  bool updateShouldNotify(_ScanInherited oldWidget) => controller != oldWidget.controller;
}

/// Element, który można wybrać skanowaniem. Bez [ScanScope] (albo gdy
/// skanowanie jest wyłączone) po prostu pokazuje [child].
class ScanTarget extends StatefulWidget {
  final void Function(Rect globalRect) onSelect;
  final double radius;
  final Widget child;

  const ScanTarget({
    super.key,
    required this.onSelect,
    required this.child,
    this.radius = 18,
  });

  @override
  State<ScanTarget> createState() => _ScanTargetState();
}

class _ScanTargetState extends State<ScanTarget> {
  ScanController? _controller;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final controller = _ScanInherited.maybeOf(context);
    if (!identical(controller, _controller)) {
      _controller?._remove(this);
      _controller = controller;
      _controller?._add(this);
    }
  }

  @override
  void dispose() {
    _controller?._remove(this);
    super.dispose();
  }

  Rect? _globalRect() {
    if (!mounted) return null;
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.attached || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  void _reveal() {
    if (!mounted) return;
    Scrollable.ensureVisible(
      context,
      alignment: 0.5,
      duration: const Duration(milliseconds: 220),
      alignmentPolicy: ScrollPositionAlignmentPolicy.explicit,
    );
  }

  void _activate() {
    widget.onSelect(_globalRect() ?? Rect.zero);
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (controller == null) return widget.child;
    return ListenableBuilder(
      listenable: controller,
      child: widget.child,
      builder: (context, child) {
        final on = controller._isCurrent(this);
        return Stack(
          clipBehavior: Clip.none,
          fit: StackFit.passthrough,
          children: [
            child!,
            if (on)
              Positioned(
                left: -5,
                top: -5,
                right: -5,
                bottom: -5,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(widget.radius + 5),
                      border: Border.all(color: AppColors.sunDeep, width: 5),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.sun.withValues(alpha: 0.55),
                          blurRadius: 0,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
