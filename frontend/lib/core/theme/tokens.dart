import 'package:flutter/material.dart';

/// Spacing scale in logical pixels. Components use these, never raw numbers.
abstract final class Space {
  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 48;
}

/// Concentric corners: an inner radius is the outer one minus its padding
/// (a 20 card with 12 padding holds 8 thumbnails). Buttons and chips are pills.
abstract final class Radii {
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 20;
  static const double xl = 28;
  static const double pill = 999;
}

/// Short and calm. Everything collapses to zero when the system asks for
/// reduced motion (see [motionOf]).
abstract final class Motion {
  static const Duration press = Duration(milliseconds: 100);
  static const Duration hover = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 200);
  static const Duration pane = Duration(milliseconds: 300);
  static const Curve standard = Curves.easeOutCubic;

  /// [duration], or zero when animations are turned off.
  static Duration motionOf(BuildContext context, Duration duration) =>
      MediaQuery.disableAnimationsOf(context) ? Duration.zero : duration;
}

/// How see-through floating bars are: the mini player, the story toolbar and
/// the phone tab bar. Content itself is never glass.
@immutable
class OsmsGlass extends ThemeExtension<OsmsGlass> {
  const OsmsGlass({required this.blur, required this.tint});

  static const frosted = OsmsGlass(blur: 24, tint: 0.74);
  static const tinted = OsmsGlass(blur: 24, tint: 0.88);
  static const solid = OsmsGlass(blur: 0, tint: 1);

  /// Backdrop blur sigma. Zero means no blur at all.
  final double blur;

  /// Opacity of the surface colour over the blur. Text sits on this, so it
  /// stays high enough to keep contrast whatever scrolls underneath.
  final double tint;

  bool get isSolid => blur == 0 || tint >= 1;

  @override
  OsmsGlass copyWith({double? blur, double? tint}) => OsmsGlass(blur: blur ?? this.blur, tint: tint ?? this.tint);

  @override
  OsmsGlass lerp(OsmsGlass? other, double t) {
    if (other == null) return this;
    return OsmsGlass(blur: blur + (other.blur - blur) * t, tint: tint + (other.tint - tint) * t);
  }
}

/// Fixed sizes: reading measure, pane widths, icons, avatars, strokes.
abstract final class Sizes {
  /// About 70 characters of reading text.
  static const double readingWidth = 680;
  static const double sidebarWidth = 264;
  static const double listWidth = 392;
  static const double listWidthTablet = 344;
  static const double cardMaxWidth = 440;
  static const double sheetMaxWidth = 560;
  static const double signInPanelWidth = 480;
  static const double chipMaxWidth = 240;
  static const double buttonHeight = 48;

  /// Below this width, disagreement sides stack instead of sitting side by side.
  static const double sideBySideMin = 520;

  /// Below this width, onboarding tiles use one column.
  static const double twoColumnMin = 480;

  static const double iconXs = 12;
  static const double iconSm = 14;
  static const double iconMd = 18;
  static const double iconLg = 22;
  static const double iconXl = 32;

  static const double avatarSm = 20;
  static const double avatarMd = 28;
  static const double avatarLg = 40;

  static const double thumbnail = 76;
  static const double chipHeight = 28;
  static const double playButton = 56;
  static const double timelineNode = 22;

  static const double hairline = 1;
  static const double rail = 3;
  static const double focusRing = 2;
}

/// Semantic colours. Read with `context.colors`.
@immutable
class OsmsColors extends ThemeExtension<OsmsColors> {
  const OsmsColors({
    required this.canvas,
    required this.surface,
    required this.surfaceMuted,
    required this.surfaceSunken,
    required this.border,
    required this.borderStrong,
    required this.text,
    required this.textSecondary,
    required this.textTertiary,
    required this.accent,
    required this.onAccent,
    required this.accentSoft,
    required this.newSignal,
    required this.newSignalSoft,
    required this.disagree,
    required this.disagreeSoft,
    required this.error,
    required this.avatarTints,
    required this.visualInks,
    required this.visualGround,
  });

  /// Ink on paper. Interaction is ink, violet marks only what's new, and
  /// disagreement stays neutral (it is labelled in words, not coloured).
  /// Chosen to stay clear of the accents other readers use (blue, green, red,
  /// orange, gold, teal with amber).
  static const light = OsmsColors(
    canvas: Color(0xFFF7F6F3),
    surface: Color(0xFFFFFFFF),
    surfaceMuted: Color(0xFFF0EFEB),
    surfaceSunken: Color(0xFFE8E6E1),
    border: Color(0xFFE3E1DB),
    borderStrong: Color(0xFFCBC8C0),
    text: Color(0xFF1D1C21),
    textSecondary: Color(0xFF55535C),
    textTertiary: Color(0xFF696771),
    accent: Color(0xFF23212B),
    onAccent: Color(0xFFFFFFFF),
    accentSoft: Color(0xFFECEAF2),
    newSignal: Color(0xFF6440C8),
    newSignalSoft: Color(0xFFEEE8FB),
    disagree: Color(0xFF3E3C45),
    disagreeSoft: Color(0xFFEFEEEA),
    error: Color(0xFFB3261E),
    avatarTints: [
      Color(0xFFDCE6F5),
      Color(0xFFDDEBD3),
      Color(0xFFF4E2CF),
      Color(0xFFE8DCF0),
      Color(0xFFD3EBE7),
      Color(0xFFF3D9D9),
      Color(0xFFECE6CC),
      Color(0xFFDDE1E7),
    ],
    visualInks: [
      Color(0xFF6440C8),
      Color(0xFF2E2B36),
      Color(0xFFB5677F),
      Color(0xFF6C7A93),
      Color(0xFF8E7AA8),
    ],
    visualGround: Color(0xFFEDEBE6),
  );

  static const dark = OsmsColors(
    canvas: Color(0xFF121115),
    surface: Color(0xFF1B1A1F),
    surfaceMuted: Color(0xFF16151A),
    surfaceSunken: Color(0xFF242329),
    border: Color(0xFF2D2C33),
    borderStrong: Color(0xFF3E3D45),
    text: Color(0xFFECEAF1),
    textSecondary: Color(0xFFADAAB6),
    textTertiary: Color(0xFF8E8B97),
    accent: Color(0xFFECEAF3),
    onAccent: Color(0xFF17161C),
    accentSoft: Color(0xFF2A2833),
    newSignal: Color(0xFFB9A2FF),
    newSignalSoft: Color(0xFF2A2240),
    disagree: Color(0xFFD4D1DC),
    disagreeSoft: Color(0xFF232228),
    error: Color(0xFFF2B8B5),
    avatarTints: [
      Color(0xFF24344C),
      Color(0xFF2A3B27),
      Color(0xFF45331F),
      Color(0xFF3A2D47),
      Color(0xFF1F3B37),
      Color(0xFF46292B),
      Color(0xFF3D3820),
      Color(0xFF2C323B),
    ],
    visualInks: [
      Color(0xFFB9A2FF),
      Color(0xFFD9D6E3),
      Color(0xFFE3A3B5),
      Color(0xFFA3B1C8),
      Color(0xFFC3B3DB),
    ],
    visualGround: Color(0xFF201F25),
  );

  final Color canvas;
  final Color surface;
  final Color surfaceMuted;
  final Color surfaceSunken;
  final Color border;
  final Color borderStrong;
  final Color text;
  final Color textSecondary;
  final Color textTertiary;
  final Color accent;
  final Color onAccent;
  final Color accentSoft;
  final Color newSignal;
  final Color newSignalSoft;
  final Color disagree;
  final Color disagreeSoft;
  final Color error;
  final List<Color> avatarTints;
  final List<Color> visualInks;
  final Color visualGround;

  /// A stable tint for anything with an id, e.g. a source avatar.
  Color tintFor(String id) => avatarTints[id.hashCode.abs() % avatarTints.length];

  /// Pure black surfaces for OLED screens; accents stay as they are.
  OsmsColors pureBlack() => copyWith(
    canvas: const Color(0xFF000000),
    surface: const Color(0xFF0B0B0D),
    surfaceMuted: const Color(0xFF000000),
    surfaceSunken: const Color(0xFF161619),
    border: const Color(0xFF242428),
    borderStrong: const Color(0xFF36363C),
    visualGround: const Color(0xFF0E0E11),
  );

  @override
  OsmsColors copyWith({
    Color? canvas,
    Color? surface,
    Color? surfaceMuted,
    Color? surfaceSunken,
    Color? border,
    Color? borderStrong,
    Color? text,
    Color? textSecondary,
    Color? textTertiary,
    Color? accent,
    Color? onAccent,
    Color? accentSoft,
    Color? newSignal,
    Color? newSignalSoft,
    Color? disagree,
    Color? disagreeSoft,
    Color? error,
    List<Color>? avatarTints,
    List<Color>? visualInks,
    Color? visualGround,
  }) => OsmsColors(
    canvas: canvas ?? this.canvas,
    surface: surface ?? this.surface,
    surfaceMuted: surfaceMuted ?? this.surfaceMuted,
    surfaceSunken: surfaceSunken ?? this.surfaceSunken,
    border: border ?? this.border,
    borderStrong: borderStrong ?? this.borderStrong,
    text: text ?? this.text,
    textSecondary: textSecondary ?? this.textSecondary,
    textTertiary: textTertiary ?? this.textTertiary,
    accent: accent ?? this.accent,
    onAccent: onAccent ?? this.onAccent,
    accentSoft: accentSoft ?? this.accentSoft,
    newSignal: newSignal ?? this.newSignal,
    newSignalSoft: newSignalSoft ?? this.newSignalSoft,
    disagree: disagree ?? this.disagree,
    disagreeSoft: disagreeSoft ?? this.disagreeSoft,
    error: error ?? this.error,
    avatarTints: avatarTints ?? this.avatarTints,
    visualInks: visualInks ?? this.visualInks,
    visualGround: visualGround ?? this.visualGround,
  );

  @override
  OsmsColors lerp(OsmsColors? other, double t) {
    if (other == null) return this;
    Color mix(Color a, Color b) => Color.lerp(a, b, t)!;
    List<Color> mixAll(List<Color> a, List<Color> b) =>
        [for (var i = 0; i < a.length; i++) mix(a[i], b[i])];
    return OsmsColors(
      canvas: mix(canvas, other.canvas),
      surface: mix(surface, other.surface),
      surfaceMuted: mix(surfaceMuted, other.surfaceMuted),
      surfaceSunken: mix(surfaceSunken, other.surfaceSunken),
      border: mix(border, other.border),
      borderStrong: mix(borderStrong, other.borderStrong),
      text: mix(text, other.text),
      textSecondary: mix(textSecondary, other.textSecondary),
      textTertiary: mix(textTertiary, other.textTertiary),
      accent: mix(accent, other.accent),
      onAccent: mix(onAccent, other.onAccent),
      accentSoft: mix(accentSoft, other.accentSoft),
      newSignal: mix(newSignal, other.newSignal),
      newSignalSoft: mix(newSignalSoft, other.newSignalSoft),
      disagree: mix(disagree, other.disagree),
      disagreeSoft: mix(disagreeSoft, other.disagreeSoft),
      error: mix(error, other.error),
      avatarTints: mixAll(avatarTints, other.avatarTints),
      visualInks: mixAll(visualInks, other.visualInks),
      visualGround: mix(visualGround, other.visualGround),
    );
  }
}

/// Font families. When the app runs as a dependency (Widgetbook), Flutter
/// registers its fonts as `packages/osms/<family>`, hence the fallbacks.
abstract final class Fonts {
  static const String sans = 'Inter';
  static const String serif = 'Newsreader';
  static const List<String> sansFallback = [
    'packages/osms/Inter',
    'NotoSansTamil',
    'packages/osms/NotoSansTamil',
  ];
  static const List<String> serifFallback = [
    'packages/osms/Newsreader',
    'NotoSansTamil',
    'packages/osms/NotoSansTamil',
  ];
}

/// The type scale. Serif for story titles and reading, sans for interface.
/// Read with `context.text`.
@immutable
class OsmsText extends ThemeExtension<OsmsText> {
  const OsmsText({
    required this.display,
    required this.title,
    required this.headline,
    required this.headlineSmall,
    required this.reading,
    required this.figure,
    required this.subhead,
    required this.body,
    required this.bodySmall,
    required this.label,
    required this.caption,
    required this.overline,
  });

  /// [serifReading] sets the face for story titles and reading text;
  /// [readingScale] sizes reading text only, never the interface.
  factory OsmsText.withColor(Color color, {bool serifReading = true, double readingScale = 1}) {
    TextStyle serif(double size, double height, int weight, {double tracking = 0}) =>
        TextStyle(
          fontFamily: Fonts.serif,
          fontFamilyFallback: Fonts.serifFallback,
          fontSize: size,
          height: height,
          letterSpacing: tracking,
          fontWeight: FontWeight.values[(weight ~/ 100) - 1],
          fontVariations: [FontVariation('wght', weight.toDouble())],
          color: color,
        );
    TextStyle sans(double size, double height, int weight, {double tracking = 0}) =>
        TextStyle(
          fontFamily: Fonts.sans,
          fontFamilyFallback: Fonts.sansFallback,
          fontSize: size,
          height: height,
          letterSpacing: tracking,
          fontWeight: FontWeight.values[(weight ~/ 100) - 1],
          fontVariations: [FontVariation('wght', weight.toDouble())],
          color: color,
        );
    final content = serifReading ? serif : sans;
    return OsmsText(
      display: content(40, 1.1, 600, tracking: -0.6),
      title: content(26, 1.2, 600, tracking: -0.2),
      headline: content(20, 1.25, 600),
      headlineSmall: content(17, 1.3, 600),
      reading: content(18 * readingScale, 1.6, 400),
      figure: content(24, 1.1, 600).copyWith(
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
      subhead: sans(15, 1.35, 600),
      body: sans(15, 1.5, 400),
      bodySmall: sans(14, 1.45, 400),
      label: sans(13, 1.3, 500),
      caption: sans(12, 1.35, 400),
      overline: sans(11, 1.3, 600, tracking: 0.9),
    );
  }

  final TextStyle display;
  final TextStyle title;
  final TextStyle headline;
  final TextStyle headlineSmall;
  final TextStyle reading;
  final TextStyle figure;
  final TextStyle subhead;
  final TextStyle body;
  final TextStyle bodySmall;
  final TextStyle label;
  final TextStyle caption;
  final TextStyle overline;

  @override
  OsmsText copyWith() => this;

  @override
  OsmsText lerp(OsmsText? other, double t) {
    if (other == null) return this;
    TextStyle mix(TextStyle a, TextStyle b) => TextStyle.lerp(a, b, t)!;
    return OsmsText(
      display: mix(display, other.display),
      title: mix(title, other.title),
      headline: mix(headline, other.headline),
      headlineSmall: mix(headlineSmall, other.headlineSmall),
      reading: mix(reading, other.reading),
      figure: mix(figure, other.figure),
      subhead: mix(subhead, other.subhead),
      body: mix(body, other.body),
      bodySmall: mix(bodySmall, other.bodySmall),
      label: mix(label, other.label),
      caption: mix(caption, other.caption),
      overline: mix(overline, other.overline),
    );
  }
}

extension OsmsThemeContext on BuildContext {
  OsmsColors get colors => Theme.of(this).extension<OsmsColors>()!;
  OsmsText get text => Theme.of(this).extension<OsmsText>()!;

  /// Solid when the system asks for high contrast.
  OsmsGlass get glass =>
      MediaQuery.highContrastOf(this) ? OsmsGlass.solid : (Theme.of(this).extension<OsmsGlass>() ?? OsmsGlass.frosted);
}
