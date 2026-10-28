import 'package:flutter/material.dart';

import '../../core/theme/tokens.dart';
import '../formatting.dart';

/// "2 new facts since Tuesday". OSMS's replacement for unread counts.
class NewFactsBadge extends StatelessWidget {
  const NewFactsBadge({super.key, required this.count, this.since});

  final int count;

  /// When the reader last read the story.
  final DateTime? since;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;

    if (count == 0) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_outline_rounded, size: Sizes.iconSm, color: c.textTertiary),
          const SizedBox(width: Space.xs),
          Text('Up to date', style: t.caption.copyWith(color: c.textTertiary)),
        ],
      );
    }

    final label = [plural(count, 'new fact'), if (since != null) sinceLabel(since!)].join(' ');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Space.sm, vertical: Space.xxs + Space.xxs),
      decoration: BoxDecoration(color: c.newSignalSoft, borderRadius: BorderRadius.circular(Radii.pill)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: Space.sm - Space.xxs,
            height: Space.sm - Space.xxs,
            decoration: BoxDecoration(color: c.newSignal, shape: BoxShape.circle),
          ),
          const SizedBox(width: Space.xs + Space.xxs),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: t.label.copyWith(color: c.newSignal, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
