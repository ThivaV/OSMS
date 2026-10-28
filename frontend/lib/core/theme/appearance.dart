import 'package:flutter/material.dart';

enum ReadingFont { serif, sans }

/// How see-through floating bars are. High contrast always gets solid.
enum GlassStyle {
  frosted('Frosted'),
  tinted('Tinted'),
  solid('Solid');

  const GlassStyle(this.label);
  final String label;
}

/// What the reader picked in Settings. Lives on the account (`users` row), so it
/// follows them across devices.
@immutable
class Appearance {
  const Appearance({
    this.mode = ThemeMode.system,
    this.paletteId = 'folio',
    this.pureBlack = false,
    this.readingFont = ReadingFont.serif,
    this.readingScale = 1,
    this.glass = GlassStyle.frosted,
  });

  final ThemeMode mode;
  final String paletteId;
  final GlassStyle glass;

  /// Pure black surfaces in dark mode, for OLED screens.
  final bool pureBlack;
  final ReadingFont readingFont;

  /// Reading text size, 0.85–1.4. The interface keeps the system text size.
  final double readingScale;

  static const minReadingScale = 0.85;
  static const maxReadingScale = 1.4;

  Brightness brightnessFor(Brightness platform) => switch (mode) {
    ThemeMode.light => Brightness.light,
    ThemeMode.dark => Brightness.dark,
    ThemeMode.system => platform,
  };

  Appearance copyWith({
    ThemeMode? mode,
    String? paletteId,
    bool? pureBlack,
    ReadingFont? readingFont,
    double? readingScale,
    GlassStyle? glass,
  }) => Appearance(
    mode: mode ?? this.mode,
    paletteId: paletteId ?? this.paletteId,
    pureBlack: pureBlack ?? this.pureBlack,
    readingFont: readingFont ?? this.readingFont,
    readingScale: readingScale ?? this.readingScale,
    glass: glass ?? this.glass,
  );
}
