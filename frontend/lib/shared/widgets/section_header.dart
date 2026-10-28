import 'package:flutter/material.dart';

import '../../core/theme/tokens.dart';

/// Icon, title and an optional count or trailing widget. Sentence case.
class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.icon, required this.title, this.iconColor, this.trailing});

  final IconData icon;
  final String title;
  final Color? iconColor;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      header: true,
      child: Row(
        children: [
          Icon(icon, size: Sizes.iconMd, color: iconColor ?? c.textSecondary),
          const SizedBox(width: Space.sm),
          Flexible(child: Text(title, style: context.text.subhead)),
          if (trailing != null) ...[const SizedBox(width: Space.sm), trailing!],
        ],
      ),
    );
  }
}

/// A quiet bordered note for empty states.
class QuietNote extends StatelessWidget {
  const QuietNote({super.key, required this.icon, required this.title, required this.body, this.action});

  final IconData icon;
  final String title;
  final String body;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    return Container(
      padding: const EdgeInsets.all(Space.lg),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(Radii.lg),
        border: Border.all(color: c.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: Sizes.iconLg, color: c.textTertiary),
          const SizedBox(width: Space.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: t.subhead),
                const SizedBox(height: Space.xs),
                Text(body, style: t.bodySmall.copyWith(color: c.textSecondary)),
                if (action != null) ...[const SizedBox(height: Space.md), action!],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A small rounded count, e.g. the number of disagreements.
class CountPill extends StatelessWidget {
  const CountPill({super.key, required this.count, this.background, this.foreground});

  final int count;
  final Color? background;
  final Color? foreground;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Space.sm, vertical: Space.xxs),
      decoration: BoxDecoration(
        color: background ?? c.surfaceSunken,
        borderRadius: BorderRadius.circular(Radii.pill),
      ),
      child: Text(
        '$count',
        style: context.text.caption.copyWith(color: foreground ?? c.textSecondary, fontWeight: FontWeight.w600),
      ),
    );
  }
}
