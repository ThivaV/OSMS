import 'package:flutter/material.dart';

import '../../core/models/models.dart';
import '../../core/theme/tokens.dart';
import '../formatting.dart';
import 'hover_lift.dart';
import 'kind_icons.dart';
import 'new_facts_badge.dart';
import 'source_chip.dart';
import 'story_visual.dart';

enum StoryCardLayout {
  /// Visual on top; the cards view.
  card,

  /// Dense row with a square visual; the list view and the three-pane list.
  row,
}

/// A story: many items about one event, with its sources and what's new.
class StoryCard extends StatelessWidget {
  const StoryCard({
    super.key,
    required this.story,
    this.layout = StoryCardLayout.card,
    this.selected = false,
    this.onTap,
  });

  final Story story;
  final StoryCardLayout layout;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: onTap != null,
      selected: selected,
      child: switch (layout) {
        StoryCardLayout.card => _CardLayout(story: story, selected: selected, onTap: onTap),
        StoryCardLayout.row => _RowLayout(story: story, selected: selected, onTap: onTap),
      },
    );
  }
}

class _CardLayout extends StatelessWidget {
  const _CardLayout({required this.story, required this.selected, this.onTap});

  final Story story;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    return HoverLift(
      child: Material(
      color: c.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.lg),
        side: BorderSide(color: selected ? c.accent : c.border, width: selected ? Sizes.focusRing : Sizes.hairline),
      ),
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            StoryVisual(seed: story.visualSeed, threads: story.sources.length, aspectRatio: 2.2),
            Padding(
              padding: const EdgeInsets.all(Space.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Kicker(story: story),
                  const SizedBox(height: Space.sm),
                  Text(story.title, maxLines: 3, overflow: TextOverflow.ellipsis, style: t.headline),
                  const SizedBox(height: Space.sm),
                  Text(
                    story.summary,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: t.bodySmall.copyWith(color: c.textSecondary),
                  ),
                  if (story.lastReadAt != null) ...[
                    const SizedBox(height: Space.md),
                    NewFactsBadge(count: story.newFactCount, since: story.lastReadAt),
                  ],
                  const SizedBox(height: Space.md),
                  const Divider(),
                  const SizedBox(height: Space.md),
                  SourceSummary(story: story),
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

class _RowLayout extends StatelessWidget {
  const _RowLayout({required this.story, required this.selected, this.onTap});

  final Story story;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    // Selection is a fill plus a leading rail, never colour alone.
    return Material(
      color: selected ? c.accentSoft : Colors.transparent,
      borderRadius: BorderRadius.circular(Radii.md),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(color: selected ? c.accent : Colors.transparent, width: Sizes.rail),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(Space.md - Sizes.rail, Space.md, Space.md, Space.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Kicker(story: story),
                    const SizedBox(height: Space.xs),
                    Text(story.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: t.headlineSmall),
                    const SizedBox(height: Space.xs),
                    Text(
                      story.summary,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: t.bodySmall.copyWith(color: c.textSecondary),
                    ),
                    const SizedBox(height: Space.sm),
                    Wrap(
                      spacing: Space.sm,
                      runSpacing: Space.xs,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        SourceStack(sources: story.sources, max: 3, size: Sizes.avatarSm),
                        Text(
                          plural(story.sources.length, 'source'),
                          style: t.caption.copyWith(color: c.textSecondary),
                        ),
                        if (story.lastReadAt != null && story.newFactCount > 0)
                          NewFactsBadge(count: story.newFactCount, since: story.lastReadAt),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: Space.md),
              ClipRRect(
                borderRadius: BorderRadius.circular(Radii.sm),
                child: SizedBox(
                  width: Sizes.thumbnail,
                  height: Sizes.thumbnail,
                  child: StoryVisual(seed: story.visualSeed, threads: story.sources.length, aspectRatio: 1),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// `AI research · 2 h ago`
class _Kicker extends StatelessWidget {
  const _Kicker({required this.story});

  final Story story;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: story.topic, style: t.caption.copyWith(color: c.textSecondary, fontWeight: FontWeight.w600)),
          TextSpan(text: '  ·  ${timeAgo(story.updatedAt)}'),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: t.caption.copyWith(color: c.textTertiary),
    );
  }
}

/// Avatars, source count and a per-kind breakdown: "many sources" at a glance.
class SourceSummary extends StatelessWidget {
  const SourceSummary({super.key, required this.story});

  final Story story;

  @override
  Widget build(BuildContext context) {
    final t = context.text;
    return Wrap(
      spacing: Space.md,
      runSpacing: Space.sm,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SourceStack(sources: story.sources),
            const SizedBox(width: Space.sm),
            Text(plural(story.sources.length, 'source'), style: t.label),
          ],
        ),
        KindCounts(counts: story.kindCounts),
      ],
    );
  }
}

/// `▤ 6  ◉ 2  ▶ 1  ◌ 5`, in a fixed order, kinds with no items left out.
class KindCounts extends StatelessWidget {
  const KindCounts({super.key, required this.counts});

  final Map<ItemKind, int> counts;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    final present = [for (final kind in ItemKind.values) if ((counts[kind] ?? 0) > 0) kind];
    return Semantics(
      label: present.map((k) => k.count(counts[k]!)).join(', '),
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final kind in present) ...[
            Icon(iconForKind(kind), size: Sizes.iconSm, color: c.textTertiary),
            const SizedBox(width: Space.xxs),
            Text('${counts[kind]}', style: t.caption.copyWith(color: c.textSecondary)),
            if (kind != present.last) const SizedBox(width: Space.sm),
          ],
        ],
      ),
    );
  }
}
