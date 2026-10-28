import 'package:flutter/material.dart';

import 'appearance.dart';
import 'palettes.dart';
import 'tokens.dart';

abstract final class AppTheme {
  /// The default palette (Folio), light and dark.
  static final ThemeData light = build(Palettes.folio, Brightness.light);
  static final ThemeData dark = build(Palettes.folio, Brightness.dark);

  /// The theme for a palette, brightness and the reader's appearance choices.
  static ThemeData build(Palette palette, Brightness brightness, [Appearance appearance = const Appearance()]) {
    var colors = palette.forBrightness(brightness);
    if (brightness == Brightness.dark && appearance.pureBlack) colors = colors.pureBlack();
    final glass = palette.id == Palettes.contrast.id
        ? OsmsGlass.solid
        : switch (appearance.glass) {
            GlassStyle.frosted => OsmsGlass.frosted,
            GlassStyle.tinted => OsmsGlass.tinted,
            GlassStyle.solid => OsmsGlass.solid,
          };
    return _build(brightness, colors, appearance, glass);
  }

  /// The same, for the reader's palette.
  static ThemeData forAppearance(Appearance appearance, Brightness brightness) =>
      build(Palettes.byId(appearance.paletteId), brightness, appearance);

  static ThemeData _build(Brightness brightness, OsmsColors c, Appearance appearance, OsmsGlass glass) {
    final text = OsmsText.withColor(
      c.text,
      serifReading: appearance.readingFont == ReadingFont.serif,
      readingScale: appearance.readingScale,
    );
    final scheme = ColorScheme(
      brightness: brightness,
      primary: c.accent,
      onPrimary: c.onAccent,
      primaryContainer: c.accentSoft,
      onPrimaryContainer: c.text,
      secondary: c.newSignal,
      onSecondary: c.surface,
      secondaryContainer: c.newSignalSoft,
      onSecondaryContainer: c.text,
      tertiary: c.disagree,
      onTertiary: c.surface,
      tertiaryContainer: c.disagreeSoft,
      onTertiaryContainer: c.text,
      error: c.error,
      onError: c.surface,
      surface: c.surface,
      onSurface: c.text,
      onSurfaceVariant: c.textSecondary,
      surfaceContainerLowest: c.surface,
      surfaceContainerLow: c.canvas,
      surfaceContainer: c.surfaceMuted,
      surfaceContainerHigh: c.surfaceSunken,
      surfaceContainerHighest: c.surfaceSunken,
      outline: c.borderStrong,
      outlineVariant: c.border,
    );
    const rounded = StadiumBorder();

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      fontFamily: Fonts.sans,
      fontFamilyFallback: Fonts.sansFallback,
      scaffoldBackgroundColor: c.canvas,
      canvasColor: c.canvas,
      splashFactory: InkRipple.splashFactory,
      extensions: [c, text, glass],
      textTheme: TextTheme(
        displaySmall: text.display,
        headlineSmall: text.title,
        titleLarge: text.headline,
        titleMedium: text.subhead,
        titleSmall: text.label,
        bodyLarge: text.body,
        bodyMedium: text.body,
        bodySmall: text.caption,
        labelLarge: text.label,
        labelMedium: text.label,
        labelSmall: text.caption,
      ),
      iconTheme: IconThemeData(color: c.textSecondary, size: Sizes.iconMd),
      dividerTheme: DividerThemeData(color: c.border, thickness: Sizes.hairline, space: Sizes.hairline),
      cardTheme: CardThemeData(
        color: c.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.lg),
          side: BorderSide(color: c.border),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: c.canvas,
        foregroundColor: c.text,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: text.subhead,
      ),
      drawerTheme: DrawerThemeData(backgroundColor: c.surfaceMuted, shape: const RoundedRectangleBorder()),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: rounded,
          textStyle: text.label,
          padding: const EdgeInsets.symmetric(horizontal: Space.lg, vertical: Space.md),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: rounded,
          textStyle: text.label,
          foregroundColor: c.text,
          side: BorderSide(color: c.borderStrong),
          padding: const EdgeInsets.symmetric(horizontal: Space.lg, vertical: Space.md),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(shape: rounded, textStyle: text.label, foregroundColor: c.accent),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.surface,
        hintStyle: text.body.copyWith(color: c.textTertiary),
        contentPadding: const EdgeInsets.symmetric(horizontal: Space.lg, vertical: Space.md),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.md),
          borderSide: BorderSide(color: c.borderStrong),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.md),
          borderSide: BorderSide(color: c.borderStrong),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.md),
          borderSide: BorderSide(color: c.accent, width: Sizes.focusRing),
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.sm / 2)),
        side: BorderSide(color: c.borderStrong, width: Sizes.focusRing),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: c.accent,
        inactiveTrackColor: c.border,
        thumbColor: c.accent,
        overlayColor: c.accent.withValues(alpha: 0.12),
        trackHeight: Sizes.rail,
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          selectedBackgroundColor: c.accentSoft,
          selectedForegroundColor: c.text,
          foregroundColor: c.textSecondary,
          side: BorderSide(color: c.border),
          textStyle: text.label,
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? c.onAccent : c.textTertiary,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? c.accent : c.surfaceSunken,
        ),
        trackOutlineColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? c.accent : c.borderStrong,
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.xl)),
        titleTextStyle: text.headline,
        contentTextStyle: text.body.copyWith(color: c.textSecondary),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: c.surface,
        surfaceTintColor: Colors.transparent,
        textStyle: text.body,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.md),
          side: BorderSide(color: c.border),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(color: c.text, borderRadius: BorderRadius.circular(Radii.sm)),
        textStyle: text.caption.copyWith(color: c.surface),
      ),
    );
  }
}
