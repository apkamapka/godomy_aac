import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Motyw aplikacji: font Nunito (zaokrąglony, czytelny), paleta akApp,
/// „grube karty” zamiast domyślnych cieni Material.
class AppTheme {
  AppTheme._();

  static const fontFamily = 'Nunito';

  // Zgodność wsteczna z kodem, który używał tych nazw.
  static const primaryColor = AppColors.sky;
  static const secondaryColor = AppColors.coral;
  static const errorColor = AppColors.coralDeep;
  static const successColor = AppColors.leaf;
  static const warningColor = AppColors.sun;

  static final ThemeData lightTheme = _build(Brightness.light);
  static final ThemeData darkTheme = _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final palette = isDark ? AacPalette.dark : AacPalette.light;

    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.sky,
      brightness: brightness,
    ).copyWith(
      primary: isDark ? const Color(0xFF4CC3E6) : AppColors.sky,
      onPrimary: Colors.white,
      primaryContainer: isDark ? const Color(0xFF0E5D75) : AppColors.skySoft,
      onPrimaryContainer: isDark ? Colors.white : AppColors.skyDeep,
      secondary: AppColors.coral,
      onSecondary: Colors.white,
      tertiary: AppColors.leaf,
      onTertiary: Colors.white,
      error: AppColors.coralDeep,
      onError: Colors.white,
      surface: palette.surface,
      onSurface: palette.ink,
      onSurfaceVariant: palette.inkSoft,
      outline: palette.line,
      outlineVariant: palette.line,
      surfaceContainerLowest: palette.surface,
      surfaceContainerLow: palette.surface,
      surfaceContainer: palette.surface,
      surfaceContainerHigh: palette.surfaceHigh,
      surfaceContainerHighest: palette.surfaceHigh,
    );

    final baseText = ThemeData(brightness: brightness, fontFamily: fontFamily).textTheme;
    final textTheme = baseText
        .copyWith(
          displaySmall: baseText.displaySmall?.copyWith(fontWeight: FontWeight.w900),
          headlineLarge: baseText.headlineLarge?.copyWith(fontWeight: FontWeight.w900),
          headlineMedium: baseText.headlineMedium?.copyWith(fontWeight: FontWeight.w900),
          headlineSmall: baseText.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
          titleLarge: baseText.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          titleMedium: baseText.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          titleSmall: baseText.titleSmall?.copyWith(fontWeight: FontWeight.w800),
          bodyLarge: baseText.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
          bodyMedium: baseText.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          bodySmall: baseText.bodySmall?.copyWith(fontWeight: FontWeight.w600),
          labelLarge: baseText.labelLarge?.copyWith(fontWeight: FontWeight.w800),
          labelMedium: baseText.labelMedium?.copyWith(fontWeight: FontWeight.w800),
          labelSmall: baseText.labelSmall?.copyWith(fontWeight: FontWeight.w700),
        )
        .apply(
          fontFamily: fontFamily,
          bodyColor: palette.ink,
          displayColor: palette.ink,
        );

    final roundedShape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(16));

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      fontFamily: fontFamily,
      colorScheme: scheme,
      textTheme: textTheme,
      scaffoldBackgroundColor: palette.paper,
      canvasColor: palette.surface,
      dividerColor: palette.line,
      extensions: <ThemeExtension<dynamic>>[palette],
      splashFactory: InkSparkle.splashFactory,
      visualDensity: VisualDensity.standard,
      appBarTheme: AppBarThemeData(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: palette.paper,
        surfaceTintColor: Colors.transparent,
        foregroundColor: palette.ink,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: fontFamily,
          color: palette.ink,
          fontSize: 21,
          fontWeight: FontWeight.w900,
        ),
        iconTheme: IconThemeData(color: palette.ink),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: palette.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: palette.line, width: 1.5),
        ),
        margin: EdgeInsets.zero,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(64, 52),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          shape: roundedShape,
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontSize: 16,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size(64, 52),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          shape: roundedShape,
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontSize: 16,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: palette.ink,
          minimumSize: const Size(64, 52),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          side: BorderSide(color: palette.line, width: 2),
          shape: roundedShape,
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: isDark ? scheme.primary : AppColors.skyDeep,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: Colors.white,
        elevation: 2,
        shape: roundedShape,
      ),
      inputDecorationTheme: InputDecorationThemeData(
        filled: true,
        fillColor: palette.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        labelStyle: TextStyle(fontFamily: fontFamily, color: palette.inkSoft, fontWeight: FontWeight.w700),
        hintStyle: TextStyle(fontFamily: fontFamily, color: palette.inkSoft.withValues(alpha: 0.7)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: palette.line, width: 2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: palette.line, width: 2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: scheme.primary, width: 2.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.coralDeep, width: 2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.coralDeep, width: 2.5),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: palette.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        titleTextStyle: TextStyle(
          fontFamily: fontFamily,
          color: palette.ink,
          fontSize: 22,
          fontWeight: FontWeight.w900,
        ),
        contentTextStyle: TextStyle(
          fontFamily: fontFamily,
          color: palette.inkSoft,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: palette.surface,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: palette.surface,
        showDragHandle: false,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: isDark ? AppColors.nightSurfaceHigh : AppColors.ink,
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        contentTextStyle: const TextStyle(
          fontFamily: fontFamily,
          color: Colors.white,
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
      ),
      drawerTheme: DrawerThemeData(
        backgroundColor: palette.paper,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.horizontal(right: Radius.circular(28)),
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: palette.ink,
        textColor: palette.ink,
        titleTextStyle: TextStyle(
          fontFamily: fontFamily,
          color: palette.ink,
          fontSize: 16,
          fontWeight: FontWeight.w800,
        ),
        subtitleTextStyle: TextStyle(
          fontFamily: fontFamily,
          color: palette.inkSoft,
          fontSize: 13.5,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return Colors.white;
          return isDark ? AppColors.nightInkSoft : Colors.white;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return scheme.primary;
          return palette.line;
        }),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: scheme.primary,
        inactiveTrackColor: palette.line,
        thumbColor: scheme.primary,
        overlayColor: scheme.primary.withValues(alpha: 0.12),
        trackHeight: 6,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: palette.surface,
        selectedColor: scheme.primaryContainer,
        side: BorderSide(color: palette.line, width: 1.5),
        labelStyle: TextStyle(
          fontFamily: fontFamily,
          color: palette.ink,
          fontWeight: FontWeight.w800,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      dividerTheme: DividerThemeData(color: palette.line, thickness: 1.5, space: 24),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: scheme.primary),
      iconTheme: IconThemeData(color: palette.ink),
    );
  }
}
