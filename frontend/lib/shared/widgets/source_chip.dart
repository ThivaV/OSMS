import 'package:flutter/material.dart';

import '../../core/models/models.dart';
import '../../core/theme/tokens.dart';
import '../formatting.dart';
import 'kind_icons.dart';

/// A monogram in a stable tint. Stands in for a source; never its logo.
class SourceAvatar extends StatelessWidget {
  const SourceAvatar({super.key, required this.source, this.size = Sizes.avatarMd, this.ringColor});

  final Source source;
  final double size;

  /// Draws a ring so overlapping avatars stay distinct.
  final Color? ringColor;

  @override
  Widget build(BuildContext context) =>
      MonogramAvatar(id: source.id, name: source.name, size: size, ringColor: ringColor);
}

/// Initials in a circle, tinted by [id]. Used for sources and for people.
class MonogramAvatar extends StatelessWidget {
  const MonogramAvatar({super.key, required this.id, required this.name, this.size = Sizes.avatarMd, this.ringColor});

  final String id;
  final String name;
  final double size;
  final Color? ringColor;

  static String monogram(String name) {
    final words = name
        .split(RegExp(r'\s+'))
        .where((w) => w.toLowerCase() != 'the' && RegExp(r'[\p{L}\p{N}]', unicode: true).hasMatch(w));
    final letters = words.take(2).map((w) => w.characters.first.toUpperCase()).join();
    return letters.isEmpty ? '?' : letters;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: c.tintFor(id),
        shape: BoxShape.circle,
        border: ringColor == null ? null : Border.all(color: ringColor!, width: Sizes.focusRing),
      ),
      child: Text(
        monogram(name),
        maxLines: 1,
        style: context.text.label.copyWith(
          fontSize: size * 0.38,
          height: 1,
          color: c.text,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Overlapping avatars with a "+N" pill: how many sources fed a story.
class SourceStack extends StatelessWidget {
  const SourceStack({super.key, required this.sources, this.max = 4, this.size = Sizes.avatarMd});

  final List<Source> sources;
  final int max;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final shown = sources.take(max).toList();
    final hidden = sources.length - shown.length;
    final step = size * 0.62;
    final count = shown.length + (hidden > 0 ? 1 : 0);
    if (count == 0) return const SizedBox.shrink();

    return Semantics(
      label: plural(sources.length, 'source'),
      excludeSemantics: true,
      child: SizedBox(
        width: size + step * (count - 1),
        height: size,
        child: Stack(
          children: [
            for (var i = 0; i < shown.length; i++)
              Positioned(
                left: step * i,
                child: SourceAvatar(source: shown[i], size: size, ringColor: c.surface),
              ),
            if (hidden > 0)
              Positioned(
                left: step * shown.length,
                child: Container(
                  width: size,
                  height: size,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: c.surfaceSunken,
                    shape: BoxShape.circle,
                    border: Border.all(color: c.surface, width: Sizes.focusRing),
                  ),
                  child: Text(
                    '+$hidden',
                    maxLines: 1,
                    style: context.text.caption.copyWith(
                      fontSize: size * 0.34,
                      height: 1,
                      color: c.textSecondary,
                      fontWeight: FontWeight.w600,
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

/// Source name, language and a generic source-type glyph. Sources the reader
/// follows are tinted and ticked.
class SourceChip extends StatelessWidget {
  const SourceChip({super.key, required this.source, this.showLanguage = true, this.onTap});

  final Source source;
  final bool showLanguage;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    final followed = source.followed;
    final shape = StadiumBorder(side: BorderSide(color: followed ? c.borderStrong : c.border));

    return Semantics(
      button: onTap != null,
      label: [
        source.name,
        source.type.label,
        if (showLanguage) languageLabel(source.language),
        if (followed) 'you follow this source',
      ].join(', '),
      excludeSemantics: true,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: Sizes.chipMaxWidth, minHeight: Sizes.chipHeight),
        child: Material(
          color: followed ? c.accentSoft : c.surface,
          shape: shape,
          child: InkWell(
            customBorder: shape,
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: Space.sm + Space.xxs, vertical: Space.xs),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(iconForSourceType(source.type), size: Sizes.iconSm, color: c.textSecondary),
                  const SizedBox(width: Space.xs + Space.xxs),
                  Flexible(
                    child: Text(source.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.label),
                  ),
                  if (showLanguage) ...[
                    const SizedBox(width: Space.xs + Space.xxs),
                    Text(
                      languageLabel(source.language),
                      style: t.caption.copyWith(color: c.textTertiary, fontWeight: FontWeight.w600),
                    ),
                  ],
                  if (followed) ...[
                    const SizedBox(width: Space.xs),
                    Icon(Icons.check_rounded, size: Sizes.iconSm, color: c.accent),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
