import 'package:flutter/material.dart';

/// Paleta marki akApp / godoMyAAC.
///
/// Błękit nieba (#16A6CF) to kolor główny, głęboki indygo (#2B1A45) to kolor
/// tekstu i obrysów. Akcenty (koral, słońce, liść) używamy oszczędnie:
/// koral = „Pilne”, liść = potwierdzenia, słońce = wyróżnienia.
class AppColors {
  AppColors._();

  static const sky = Color(0xFF16A6CF);
  static const skyDeep = Color(0xFF0E7FA0);
  static const skySoft = Color(0xFFD7F0F8);

  static const ink = Color(0xFF2B1A45);
  static const inkSoft = Color(0xFF6A5F80);

  static const paper = Color(0xFFEAF4F9);
  static const surface = Color(0xFFFFFFFF);
  static const line = Color(0xFFD3E2EB);

  static const coral = Color(0xFFFF6B5B);
  static const coralDeep = Color(0xFFD94A3B);
  static const coralSoft = Color(0xFFFFF1EF);

  static const sun = Color(0xFFFFC83D);
  static const sunDeep = Color(0xFFC98A00);

  static const leaf = Color(0xFF3DBA6F);
  static const leafDeep = Color(0xFF2A9555);

  static const grape = Color(0xFF8A66D6);

  // Tryb ciemny – „nocne indygo”.
  static const nightPaper = Color(0xFF151022);
  static const nightSurface = Color(0xFF231A38);
  static const nightSurfaceHigh = Color(0xFF2E2448);
  static const nightLine = Color(0xFF3A2F55);
  static const nightInk = Color(0xFFF4F0FF);
  static const nightInkSoft = Color(0xFFB9AED0);

  /// Okienko z obrazkiem na kafelku (biel w jasnym, lekko przygaszona w ciemnym).
  static const tileWindow = Color(0xFFFFFFFF);
  static const tileWindowNight = Color(0xFFF1EEF7);

  /// Ciemniejszy „brzeg” kafelka wyliczony z koloru tła – daje efekt
  /// grubej, laminowanej karty.
  static Color edgeFor(Color background) {
    final hsl = HSLColor.fromColor(background);
    if (hsl.saturation < 0.08) {
      // Biel / szarości – chłodny szary brzeg.
      return hsl.lightness > 0.85 ? const Color(0xFFB9C8D3) : _darken(background, 0.22);
    }
    return hsl
        .withLightness((hsl.lightness * 0.62).clamp(0.0, 1.0))
        .withSaturation((hsl.saturation * 1.05).clamp(0.0, 1.0))
        .toColor();
  }

  /// Delikatny obrys kafelka (między tłem a brzegiem).
  static Color outlineFor(Color background) {
    return Color.lerp(background, edgeFor(background), 0.55)!;
  }

  /// Kolor podpisu na kafelku – indygo na jasnych tłach, biel na ciemnych.
  static Color labelOn(Color background) {
    return background.computeLuminance() < 0.33 ? Colors.white : ink;
  }

  static Color _darken(Color c, double amount) {
    final hsl = HSLColor.fromColor(c);
    return hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0)).toColor();
  }
}

/// Rodzaje słów wg zmodyfikowanego klucza Fitzgeralda – kolory, które
/// logopedzi stosują na tablicach AAC.
enum WordKind {
  people,
  actions,
  describe,
  things,
  social,
  questions,
  negation,
  misc,
}

extension WordKindColors on WordKind {
  Color get color {
    switch (this) {
      case WordKind.people:
        return const Color(0xFFFFE680);
      case WordKind.actions:
        return const Color(0xFFC3EDB4);
      case WordKind.describe:
        return const Color(0xFFC2E5FA);
      case WordKind.things:
        return const Color(0xFFFFD5AA);
      case WordKind.social:
        return const Color(0xFFFBCFE1);
      case WordKind.questions:
        return const Color(0xFFDED0F8);
      case WordKind.negation:
        return const Color(0xFFFAC0BE);
      case WordKind.misc:
        return const Color(0xFFFFFFFF);
    }
  }

  /// Nazwa grupy po polsku (pokazywana w wyborze koloru).
  String get label {
    switch (this) {
      case WordKind.people:
        return 'Osoby';
      case WordKind.actions:
        return 'Czynności';
      case WordKind.describe:
        return 'Opisy';
      case WordKind.things:
        return 'Rzeczy';
      case WordKind.social:
        return 'Zwroty';
      case WordKind.questions:
        return 'Pytania';
      case WordKind.negation:
        return 'Ważne / nie';
      case WordKind.misc:
        return 'Inne';
    }
  }

  int get argb => color.toARGB32();
}

/// Dodatkowe pastele (poza kluczem Fitzgeralda) do wyboru w edytorach.
class ExtraTileColors {
  ExtraTileColors._();

  static const List<Color> values = [
    Color(0xFFFFCDD2),
    Color(0xFFF8BBD0),
    Color(0xFFE1BEE7),
    Color(0xFFD1C4E9),
    Color(0xFFC5CAE9),
    Color(0xFFBBDEFB),
    Color(0xFFB2EBF2),
    Color(0xFFB2DFDB),
    Color(0xFFC8E6C9),
    Color(0xFFF0F4C3),
    Color(0xFFFFF9C4),
    Color(0xFFFFE0B2),
    Color(0xFFD7CCC8),
    Color(0xFFECEFF1),
  ];
}

/// Kolory zależne od jasnego/ciemnego motywu, dostępne przez
/// `Theme.of(context).extension<AacPalette>()` albo `context.aac`.
@immutable
class AacPalette extends ThemeExtension<AacPalette> {
  final Color paper;
  final Color surface;
  final Color surfaceHigh;
  final Color line;
  final Color ink;
  final Color inkSoft;
  final Color tileWindow;

  const AacPalette({
    required this.paper,
    required this.surface,
    required this.surfaceHigh,
    required this.line,
    required this.ink,
    required this.inkSoft,
    required this.tileWindow,
  });

  static const light = AacPalette(
    paper: AppColors.paper,
    surface: AppColors.surface,
    surfaceHigh: Color(0xFFF4F8FB),
    line: AppColors.line,
    ink: AppColors.ink,
    inkSoft: AppColors.inkSoft,
    tileWindow: AppColors.tileWindow,
  );

  static const dark = AacPalette(
    paper: AppColors.nightPaper,
    surface: AppColors.nightSurface,
    surfaceHigh: AppColors.nightSurfaceHigh,
    line: AppColors.nightLine,
    ink: AppColors.nightInk,
    inkSoft: AppColors.nightInkSoft,
    tileWindow: AppColors.tileWindowNight,
  );

  @override
  AacPalette copyWith({
    Color? paper,
    Color? surface,
    Color? surfaceHigh,
    Color? line,
    Color? ink,
    Color? inkSoft,
    Color? tileWindow,
  }) {
    return AacPalette(
      paper: paper ?? this.paper,
      surface: surface ?? this.surface,
      surfaceHigh: surfaceHigh ?? this.surfaceHigh,
      line: line ?? this.line,
      ink: ink ?? this.ink,
      inkSoft: inkSoft ?? this.inkSoft,
      tileWindow: tileWindow ?? this.tileWindow,
    );
  }

  @override
  AacPalette lerp(ThemeExtension<AacPalette>? other, double t) {
    if (other is! AacPalette) return this;
    return AacPalette(
      paper: Color.lerp(paper, other.paper, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceHigh: Color.lerp(surfaceHigh, other.surfaceHigh, t)!,
      line: Color.lerp(line, other.line, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      inkSoft: Color.lerp(inkSoft, other.inkSoft, t)!,
      tileWindow: Color.lerp(tileWindow, other.tileWindow, t)!,
    );
  }
}

extension AacPaletteContext on BuildContext {
  AacPalette get aac =>
      Theme.of(this).extension<AacPalette>() ??
      (Theme.of(this).brightness == Brightness.dark ? AacPalette.dark : AacPalette.light);
}
