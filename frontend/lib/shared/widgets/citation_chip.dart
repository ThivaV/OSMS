import 'package:flutter/material.dart';

import '../../core/models/models.dart';
import '../../core/theme/tokens.dart';
import 'kind_icons.dart';

/// A small publisher-first chip at the end of a summary sentence: who said it,
/// and in what form (article, episode, video, post). Never a bare number.
class CitationChip extends StatelessWidget {
  const CitationChip({super.key, required this.source, this.onTap});

  final Source source;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      button: onTap != null,
      label: 'Source: ${source.name}',
      excludeSemantics: true,
      child: Material(
        color: c.surfaceMuted,
        shape: const StadiumBorder(),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.sm, vertical: Space.xxs),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(iconForSourceType(source.type), size: Sizes.iconXs, color: c.textTertiary),
                const SizedBox(width: Space.xs),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: Sizes.chipMaxWidth / 1.5),
                  child: Text(
                    source.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.caption.copyWith(color: c.textSecondary, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Sources for one sentence: up to two chips, then "+N".
class CitationGroup extends StatelessWidget {
  const CitationGroup({super.key, required this.sources, this.onOpenSource});

  final List<Source> sources;
  final ValueChanged<Source>? onOpenSource;

  static const _max = 2;

  @override
  Widget build(BuildContext context) {
    final extra = sources.length - _max;
    return Wrap(
      spacing: Space.xs,
      runSpacing: Space.xs,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final s in sources.take(_max))
          CitationChip(source: s, onTap: onOpenSource == null ? null : () => onOpenSource!(s)),
        if (extra > 0)
          Text('+$extra', style: context.text.caption.copyWith(color: context.colors.textTertiary)),
      ],
    );
  }
}
