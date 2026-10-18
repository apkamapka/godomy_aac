import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Stare ścieżki assets (sprzed 1.1) → nowe pliki WebP.
String resolveAssetPath(String path) {
  const legacyDir = 'assets/category_icons/';
  if (path.startsWith(legacyDir)) {
    final file = path.substring(legacyDir.length);
    final dot = file.lastIndexOf('.');
    final base = dot > 0 ? file.substring(0, dot) : file;
    return 'assets/symbols/$base.webp';
  }
  return path;
}

/// Obrazek symbolu: plik, asset albo emoji. Dekoduje w rozmiarze kafelka
/// (`cacheWidth`), więc nawet duże zdjęcia z aparatu nie zamulają tablicy.
class SymbolImage extends StatelessWidget {
  final String? imagePath;
  final String? emoji;
  final BoxFit fit;
  final int? cacheWidth;
  final IconData fallbackIcon;

  const SymbolImage({
    super.key,
    this.imagePath,
    this.emoji,
    this.fit = BoxFit.contain,
    this.cacheWidth,
    this.fallbackIcon = Icons.image_outlined,
  });

  @override
  Widget build(BuildContext context) {
    final path = imagePath;
    if (path != null && path.isNotEmpty) {
      if (path.startsWith('assets/')) {
        return Image.asset(
          resolveAssetPath(path),
          fit: fit,
          cacheWidth: cacheWidth,
          gaplessPlayback: true,
          errorBuilder: (context, error, stack) => _fallback(context),
        );
      }
      return Image.file(
        File(path),
        fit: fit,
        cacheWidth: cacheWidth,
        gaplessPlayback: true,
        errorBuilder: (context, error, stack) => _emojiOr(context),
      );
    }
    return _emojiOr(context);
  }

  Widget _emojiOr(BuildContext context) {
    final e = emoji;
    if (e != null && e.isNotEmpty) {
      return FittedBox(
        fit: BoxFit.contain,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Text(e, style: const TextStyle(fontSize: 96, height: 1.15)),
        ),
      );
    }
    return _fallback(context);
  }

  Widget _fallback(BuildContext context) {
    return FittedBox(
      fit: BoxFit.contain,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(fallbackIcon, size: 48, color: context.aac.inkSoft.withValues(alpha: 0.5)),
      ),
    );
  }
}

/// Okrągły awatar profilu: zdjęcie albo pierwsza litera na kolorowym tle.
class ProfileAvatar extends StatelessWidget {
  final String name;
  final String? photoPath;
  final double size;
  final bool border;

  const ProfileAvatar({
    super.key,
    required this.name,
    this.photoPath,
    this.size = 40,
    this.border = true,
  });

  static const _colors = [
    Color(0xFFFFB94A),
    Color(0xFF16A6CF),
    Color(0xFF3DBA6F),
    Color(0xFF8A66D6),
    Color(0xFFFF6B5B),
    Color(0xFFE0679A),
    Color(0xFF26A69A),
    Color(0xFF5C6BC0),
  ];

  static Color colorFor(String name) {
    var h = 0;
    for (final c in name.codeUnits) {
      h = (h * 31 + c) & 0x7fffffff;
    }
    return _colors[h % _colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final hasPhoto = photoPath != null && photoPath!.isNotEmpty;
    final initial = name.trim().isEmpty ? '?' : name.trim().characters.first.toUpperCase();
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: colorFor(name),
        border: border ? Border.all(color: Colors.white, width: size * 0.07) : null,
        boxShadow: border
            ? [BoxShadow(color: context.aac.line, offset: const Offset(0, 2), blurRadius: 0)]
            : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: hasPhoto
          ? Image.file(
              File(photoPath!),
              fit: BoxFit.cover,
              cacheWidth: (size * dpr).round(),
              errorBuilder: (context, error, stack) => _Initial(initial: initial, size: size),
            )
          : _Initial(initial: initial, size: size),
    );
  }
}

class _Initial extends StatelessWidget {
  final String initial;
  final double size;
  const _Initial({required this.initial, required this.size});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        initial,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          fontSize: size * 0.44,
          height: 1,
        ),
      ),
    );
  }
}

/// Mały „ołówek”/„krzyżyk” w rogu kafelka w trybie opiekuna.
class CornerBadge extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color edge;
  final double size;
  final VoidCallback? onTap;

  const CornerBadge({
    super.key,
    required this.icon,
    required this.color,
    required this.edge,
    this.size = 30,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final badge = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2.5),
        boxShadow: [BoxShadow(color: edge, offset: const Offset(0, 2), blurRadius: 0)],
      ),
      child: Icon(icon, size: size * 0.5, color: Colors.white),
    );
    if (onTap == null) return badge;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(padding: const EdgeInsets.all(4), child: badge),
    );
  }
}

/// Kolor brzegu dla dowolnego tła (skrót).
Color tileEdge(Color background) => AppColors.edgeFor(background);
