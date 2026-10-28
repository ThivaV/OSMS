import 'package:flutter/material.dart';

import '../../core/models/models.dart';
import '../../core/theme/tokens.dart';
import '../../shared/formatting.dart';
import '../../shared/widgets/hover_lift.dart';
import '../../shared/widgets/new_facts_badge.dart';
import '../../shared/widgets/section_header.dart';
import '../../shared/widgets/story_card.dart';
import '../../shared/widgets/story_visual.dart';

/// Today at a glance: a lead story, the briefing and what's new beside it,
/// then the rest as a grid. Fills the reading pane until a story is opened.
class TodayOverview extends StatelessWidget {
  const TodayOverview({super.key, required this.stories, this.briefing, this.user, this.onOpen, this.onPlayBriefing});

  /// Ranked: the first is the lead.
  final List<Story> stories;
  final Briefing? briefing;
  final User? user;
  final ValueChanged<Story>? onOpen;
  final VoidCallback? onPlayBriefing;

  static const _maxWidth = 1200.0;
  static const _sideBySideMin = 900.0;
  static const _threeColumnsMin = 1100.0;
  static const _twoColumnsMin = 600.0;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    final now = DateTime.now();
    final firstName = user?.displayName.split(' ').first;
    final withNews = stories.where((s) => s.newFactCount > 0).toList();
    final items = stories.fold(0, (sum, s) => sum + s.itemCount);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.clamp(0.0, _maxWidth) - Space.xl * 2;
        final columns = width >= _threeColumnsMin ? 3 : (width >= _twoColumnsMin ? 2 : 1);
        final tileWidth = (width - Space.lg * (columns - 1)) / columns;

        final header = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(longDate(now), style: t.caption.copyWith(color: c.textTertiary, fontWeight: FontWeight.w600)),
            const SizedBox(height: Space.xs),
            Text(firstName == null ? 'Today' : '${greeting(now)}, $firstName', style: t.title),
            const SizedBox(height: Space.xs),
            Text(
              stories.isEmpty
                  ? 'No stories yet. Add a few sources to begin.'
                  : '${plural(stories.length, 'story', 'stories')} from ${plural(items, 'item')}'
                        '${withNews.isEmpty ? '' : '  ·  ${withNews.length} with new facts'}',
              style: t.body.copyWith(color: c.textSecondary),
            ),
          ],
        );

        if (stories.isEmpty) {
          return SingleChildScrollView(padding: const EdgeInsets.all(Space.xl), child: header);
        }

        final lead = _LeadCard(story: stories.first, large: width >= _sideBySideMin, onTap: () => onOpen?.call(stories.first));
        final briefingTile = briefing == null || briefing!.chapters.isEmpty
            ? null
            : _BriefingTile(briefing: briefing!, onPlay: onPlayBriefing);
        final newsTile = _NewSinceTile(stories: withNews, onOpen: onOpen);

        final Widget top;
        if (width >= _sideBySideMin) {
          top = IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(flex: 8, child: lead),
                const SizedBox(width: Space.lg),
                Expanded(
                  flex: 4,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ?briefingTile,
                      if (briefingTile != null) const SizedBox(height: Space.lg),
                      Expanded(child: newsTile),
                    ],
                  ),
                ),
              ],
            ),
          );
        } else {
          top = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              lead,
              const SizedBox(height: Space.lg),
              ?briefingTile,
              if (briefingTile != null) const SizedBox(height: Space.lg),
              newsTile,
            ],
          );
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(Space.xl, Space.xl, Space.xl, Space.xxxl * 2.5),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _maxWidth),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  header,
                  const SizedBox(height: Space.xl),
                  top,
                  if (stories.length > 1) ...[
                    const SizedBox(height: Space.xxl),
                    const SectionHeader(icon: Icons.view_agenda_outlined, title: 'More stories'),
                    const SizedBox(height: Space.md),
                    Wrap(
                      spacing: Space.lg,
                      runSpacing: Space.lg,
                      children: [
                        for (final s in stories.skip(1))
                          SizedBox(
                            width: tileWidth,
                            child: StoryCard(story: s, onTap: () => onOpen?.call(s)),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _LeadCard extends StatelessWidget {
  const _LeadCard({required this.story, required this.large, this.onTap});

  final Story story;
  final bool large;
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
          side: BorderSide(color: c.border),
        ),
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              StoryVisual(seed: story.visualSeed, threads: story.sources.length, aspectRatio: large ? 2.2 : 16 / 9),
              Padding(
                padding: EdgeInsets.all(large ? Space.xl : Space.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Lead story  ·  ${story.topic}  ·  ${timeAgo(story.updatedAt)}',
                      style: t.caption.copyWith(color: c.textTertiary, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: Space.sm),
                    Text(story.title, style: large ? t.display : t.title),
                    const SizedBox(height: Space.md),
                    Text(
                      story.summary,
                      maxLines: large ? 4 : 3,
                      overflow: TextOverflow.ellipsis,
                      style: t.body.copyWith(color: c.textSecondary),
                    ),
                    const SizedBox(height: Space.lg),
                    Wrap(
                      spacing: Space.md,
                      runSpacing: Space.sm,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        SourceSummary(story: story),
                        if (story.lastReadAt != null && story.newFactCount > 0)
                          NewFactsBadge(count: story.newFactCount, since: story.lastReadAt),
                      ],
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

/// The briefing as a tile: play, length, and one bar segment per story.
class _BriefingTile extends StatelessWidget {
  const _BriefingTile({required this.briefing, this.onPlay});

  final Briefing briefing;
  final VoidCallback? onPlay;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    return HoverLift(
      child: Material(
        color: c.accentSoft,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.lg)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPlay ?? () {},
          child: Padding(
            padding: const EdgeInsets.all(Space.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: Sizes.playButton - Space.sm,
                      height: Sizes.playButton - Space.sm,
                      decoration: BoxDecoration(color: c.accent, shape: BoxShape.circle),
                      child: Icon(Icons.play_arrow_rounded, color: c.onAccent, size: Sizes.iconXl - Space.xs),
                    ),
                    const SizedBox(width: Space.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Morning briefing', style: t.subhead),
                          Text(
                            '${plural(briefing.chapters.length, 'story', 'stories')}  ·  ${durationLabel(briefing.duration)}',
                            style: t.caption.copyWith(color: c.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Space.lg),
                Row(
                  children: [
                    for (final (i, ch) in briefing.chapters.indexed) ...[
                      Expanded(
                        flex: ch.duration.inSeconds.clamp(1, 1 << 20),
                        child: Container(
                          height: Sizes.rail,
                          decoration: BoxDecoration(
                            color: c.text.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(Radii.pill),
                          ),
                        ),
                      ),
                      if (i < briefing.chapters.length - 1) const SizedBox(width: Space.xxs),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Stories with new facts since the reader last looked, newest first.
class _NewSinceTile extends StatelessWidget {
  const _NewSinceTile({required this.stories, this.onOpen});

  final List<Story> stories;
  final ValueChanged<Story>? onOpen;

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(icon: Icons.update_rounded, iconColor: c.newSignal, title: 'New since you last read'),
          const SizedBox(height: Space.md),
          if (stories.isEmpty)
            Text('Nothing new yet. New facts will show up here.', style: t.bodySmall.copyWith(color: c.textSecondary))
          else
            for (final s in stories.take(4))
              InkWell(
                borderRadius: BorderRadius.circular(Radii.sm),
                onTap: onOpen == null ? null : () => onOpen!(s),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: Space.sm),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: Space.xs + Space.xxs),
                        child: Container(
                          width: Space.sm,
                          height: Space.sm,
                          decoration: BoxDecoration(color: c.newSignal, shape: BoxShape.circle),
                        ),
                      ),
                      const SizedBox(width: Space.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(s.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: t.label),
                            Text(
                              plural(s.newFactCount, 'new fact'),
                              style: t.caption.copyWith(color: c.newSignal, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }
}
