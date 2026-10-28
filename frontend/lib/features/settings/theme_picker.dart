import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/palettes.dart';
import '../../core/theme/tokens.dart';
import '../../shared/widgets/story_visual.dart';

/// One tile per palette, each previewed in its own colours.
class ThemePicker extends StatelessWidget {
  const ThemePicker({
    super.key,
    required this.palettes,
    required this.selectedId,
    required this.brightness,
    required this.onSelect,
  });

  final List<Palette> palettes;
  final String selectedId;

  /// Which version the tiles preview: the one the reader will see.
  final Brightness brightness;
  final ValueChanged<Palette> onSelect;

  static const _tileMinWidth = 168.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = (constraints.maxWidth / _tileMinWidth).floor().clamp(1, 3);
        final width = (constraints.maxWidth - Space.md * (columns - 1)) / columns;
        return Wrap(
          spacing: Space.md,
          runSpacing: Space.md,
          children: [
            for (final p in palettes)
              SizedBox(
                width: width,
                child: _ThemeTile(
                  palette: p,
                  brightness: brightness,
                  selected: p.id == selectedId,
                  onTap: () => onSelect(p),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _ThemeTile extends StatelessWidget {
  const _ThemeTile({required this.palette, required this.brightness, required this.selected, required this.onTap});

  final Palette palette;
  final Brightness brightness;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(Radii.lg),
      side: BorderSide(
        color: selected ? c.accent : c.border,
        width: selected ? Sizes.focusRing : Sizes.hairline,
      ),
    );
    return Semantics(
      button: true,
      selected: selected,
      label: '${palette.name} theme',
      child: Material(
        color: c.surface,
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Theme(
                data: AppTheme.build(palette, brightness),
                child: const _MiniPreview(),
              ),
              Padding(
                padding: const EdgeInsets.all(Space.md),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(palette.name, style: t.label.copyWith(fontWeight: FontWeight.w600)),
                          const SizedBox(height: Space.xxs),
                          Text(palette.description, style: t.caption.copyWith(color: c.textSecondary)),
                        ],
                      ),
                    ),
                    const SizedBox(width: Space.xs),
                    Icon(
                      selected ? Icons.check_circle_rounded : Icons.circle_outlined,
                      size: Sizes.iconMd,
                      color: selected ? c.accent : c.borderStrong,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A miniature of the app in the surrounding theme: sidebar, a story card with
/// its art, title lines and a "new" pill.
class _MiniPreview extends StatelessWidget {
  const _MiniPreview();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    Widget bar(double widthFactor, Color color, {double height = Space.xs + Space.xxs}) => FractionallySizedBox(
      widthFactor: widthFactor,
      alignment: Alignment.centerLeft,
      child: Container(
        height: height,
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(Radii.pill)),
      ),
    );

    return ExcludeSemantics(
      child: Container(
        height: Space.xxxl * 2,
        color: c.canvas,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: Space.xxl,
              color: c.surfaceMuted,
              padding: const EdgeInsets.all(Space.sm),
              child: Column(
                children: [
                  for (var i = 0; i < 4; i++) ...[
                    bar(1, i == 0 ? c.accent : c.border),
                    const SizedBox(height: Space.xs + Space.xxs),
                  ],
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(Space.sm),
                child: Container(
                  decoration: BoxDecoration(
                    color: c.surface,
                    borderRadius: BorderRadius.circular(Radii.sm),
                    border: Border.all(color: c.border),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Expanded(child: StoryVisual(seed: 5, threads: 6, aspectRatio: 3.2)),
                      Padding(
                        padding: const EdgeInsets.all(Space.xs + Space.xxs),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            bar(0.85, c.text),
                            const SizedBox(height: Space.xs),
                            bar(0.55, c.textTertiary, height: Space.xs),
                            const SizedBox(height: Space.xs + Space.xxs),
                            Container(
                              width: Space.xxl,
                              height: Space.sm + Space.xxs,
                              decoration: BoxDecoration(
                                color: c.newSignalSoft,
                                borderRadius: BorderRadius.circular(Radii.pill),
                              ),
                              alignment: Alignment.centerLeft,
                              padding: const EdgeInsets.only(left: Space.xs),
                              child: Container(
                                width: Space.xs + Space.xxs,
                                height: Space.xs + Space.xxs,
                                decoration: BoxDecoration(color: c.newSignal, shape: BoxShape.circle),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
