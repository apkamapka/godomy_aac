import 'package:flutter/material.dart';

/// Krótka animacja: kopia obrazka „wlatuje” z kafelka do paska zdania.
/// Pokazuje dziecku, gdzie trafiło słowo.
class FlyToTarget {
  FlyToTarget._();

  static void run({
    required BuildContext context,
    required Rect from,
    required Rect to,
    required Widget child,
    Duration duration = const Duration(milliseconds: 420),
  }) {
    if (from.isEmpty || to.isEmpty) return;
    if (MediaQuery.disableAnimationsOf(context)) return;
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _Flying(
        from: from,
        to: to,
        duration: duration,
        onDone: () {
          if (entry.mounted) entry.remove();
        },
        child: child,
      ),
    );
    overlay.insert(entry);
  }
}

class _Flying extends StatefulWidget {
  final Rect from;
  final Rect to;
  final Duration duration;
  final VoidCallback onDone;
  final Widget child;

  const _Flying({
    required this.from,
    required this.to,
    required this.duration,
    required this.onDone,
    required this.child,
  });

  @override
  State<_Flying> createState() => _FlyingState();
}

class _FlyingState extends State<_Flying> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _curve;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _curve = CurvedAnimation(parent: _controller, curve: Curves.easeInOutCubic);
    _controller.forward().whenComplete(widget.onDone);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Overlay leży na całym ekranie, więc globalne współrzędne pasują.
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _curve,
        builder: (context, child) {
          final t = _curve.value;
          final rect = Rect.lerp(widget.from, widget.to, t)!;
          // Lekki łuk w górę w połowie lotu.
          final lift = -40.0 * (1 - (2 * t - 1) * (2 * t - 1));
          final opacity = t < 0.85 ? 1.0 : (1 - (t - 0.85) / 0.15).clamp(0.0, 1.0);
          return Stack(
            children: [
              Positioned(
                left: rect.left,
                top: rect.top + lift,
                width: rect.width,
                height: rect.height,
                child: Opacity(opacity: opacity, child: child),
              ),
            ],
          );
        },
        child: widget.child,
      ),
    );
  }
}
