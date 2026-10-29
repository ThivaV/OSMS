import 'package:flutter/material.dart';

import '../../core/theme/tokens.dart';

/// Above the stories while they are samples: signed in, but OSMS isn't collecting
/// real stories yet. Never let invented stories pass for real ones.
class SampleBanner extends StatelessWidget {
  const SampleBanner({super.key, this.sourceCount = 0});

  /// How many sources the reader follows, for "Your N sources...".
  final int sourceCount;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    final yours = switch (sourceCount) {
      0 => 'Stories from your sources',
      1 => 'Stories from your source',
      _ => 'Stories from your $sourceCount sources',
    };
    return Container(
      padding: const EdgeInsets.all(Space.lg),
      decoration: BoxDecoration(
        color: c.surfaceMuted,
        borderRadius: BorderRadius.circular(Radii.lg),
        border: Border.all(color: c.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.science_outlined, size: Sizes.iconLg, color: c.textSecondary),
          const SizedBox(width: Space.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('These are sample stories', style: t.subhead),
                const SizedBox(height: Space.xxs),
                Text(
                  '$yours appear here once OSMS starts collecting them. Until then, these invented '
                  'stories and the briefing show how it works.',
                  style: t.bodySmall.copyWith(color: c.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
