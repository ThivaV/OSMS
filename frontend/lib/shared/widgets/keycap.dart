import 'package:flutter/material.dart';

import '../../core/theme/tokens.dart';

/// A keyboard shortcut hint, e.g. `⌘K`.
class Keycap extends StatelessWidget {
  const Keycap(this.keys, {super.key});

  final String keys;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Space.xs + Space.xxs, vertical: Space.xxs),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(Radii.sm / 2),
        border: Border.all(color: c.borderStrong),
      ),
      child: Text(keys, style: context.text.caption.copyWith(color: c.textSecondary, fontWeight: FontWeight.w600)),
    );
  }
}
