import 'package:flutter/material.dart';

import '../../core/models/models.dart';
import '../../core/theme/tokens.dart';
import '../../shared/formatting.dart';
import '../../shared/widgets/hover_lift.dart';
import '../../shared/widgets/item_card.dart';
import '../../shared/widgets/new_facts_badge.dart';
import '../../shared/widgets/section_header.dart';
import '../../shared/widgets/story_card.dart';
import '../../shared/widgets/story_visual.dart';
import 'no_stories.dart';

/// Today at a glance: a lead story, the briefing and what's new beside it,
/// then the rest as a grid. Fills the reading pane until a story is opened.
class TodayOverview extends StatelessWidget {
  const TodayOverview({
    super.key,
    required this.stories,
    this.research = const [],
    this.briefing,
    this.user,
    this.onOpen,
    this.onOpenPaper,
    this.onPlayBriefing,
    this.sourceCount = 0,
    this.onChooseSources,
    this.onAddSource,
    this.emptyTitle,
    this.emptyBody,
    this.banner,
  });

  /// Ranked: the first is the lead.
  final List<Story> stories;

  /// New arXiv papers matched to the reader's research interests, best first.
  final List<Item> research;
  final Briefing? briefing;
  final User? user;
  final ValueChanged<Story>? onOpen;
  final ValueChanged<Item>? onOpenPaper;
  final VoidCallback? onPlayBriefing;

  /// How many sources the reader follows: what an empty Today says.
  final int sourceCount;

  /// The empty state's buttons; each is hidden without its callback.
  final VoidCallback? onChooseSources;
  final VoidCallback? onAddSource;

  /// Overrides for a filtered empty Today (e.g. Saved, with nothing kept yet).
  final String? emptyTitle;
  final String? emptyBody;

  /// Above the greeting, e.g. the demo notice while signed out.
  final Widget? banner;

  static const _maxWidth = 1200.0;
  static const _sideBySideMin = 900.0;
  static const _threeColumnsMin = 1100.0;
  static const _twoColumnsMin = 600.0;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    final now = DateTime.now();
    final firstName = user?.shownName.split(' ').first;
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
                  ? NoStories.summary(sourceCount)
                  : '${plural(stories.length, 'story', 'stories')} from ${plural(items, 'item')}'
                        '${withNews.isEmpty ? '' : '  ·  ${withNews.length} with new facts'}',
              style: t.body.copyWith(color: c.textSecondary),
            ),
          ],
        );

        if (stories.isEmpty) {
          final actions = NoStoriesActions(onChooseSources: onChooseSources, onAddSource: onAddSource);
          return SingleChildScrollView(
            padding: const EdgeInsets.all(Space.xl),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: Sizes.sheetMaxWidth),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (banner case final banner?) ...[banner, const SizedBox(height: Space.xl)],
                    header,
                    const SizedBox(height: Space.xl),
                    Container(
                      padding: const EdgeInsets.all(Space.xl),
                      decoration: BoxDecoration(
                        color: c.surface,
                        borderRadius: BorderRadius.circular(Radii.lg),
                        border: Border.all(color: c.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(emptyTitle ?? NoStories.title, style: t.subhead),
                          const SizedBox(height: Space.xs),
                          Text(
                            emptyBody ?? NoStories.body(sourceCount),
                            style: t.bodySmall.copyWith(color: c.textSecondary),
                          ),
                          if (actions.hasActions) ...[const SizedBox(height: Space.lg), actions],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
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
                  if (banner case final banner?) ...[banner, const SizedBox(height: Space.xl)],
                  header,
                  const SizedBox(height: Space.xl),
                  top,
                  if (research.isNotEmpty) ...[
                    const SizedBox(height: Space.xxl),
                    _ResearchSection(papers: research, onOpen: onOpenPaper),
                  ],
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
              StoryVisual(
                seed: story.visualSeed,
                threads: story.sources.length,
                aspectRatio: large ? 2.2 : 16 / 9,
                isIllustration: story.hasIllustration,
              ),
              Padding(
                padding: EdgeInsets.all(large ? Space.xl : Space.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${story.topic}  ·  ${timeAgo(story.updatedAt)}',
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

/// New arXiv papers for the reader's research interests, each with why it's here.
class _ResearchSection extends StatelessWidget {
  const _ResearchSection({required this.papers, this.onOpen});

  final List<Item> papers;
  final ValueChanged<Item>? onOpen;

  static const _shown = 5;

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
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeader(
            icon: Icons.science_outlined,
            title: 'New research for you',
            trailing: CountPill(count: papers.length),
          ),
          const SizedBox(height: Space.xxs),
          Text(
            'From arXiv, matched to your research interests.',
            style: t.caption.copyWith(color: c.textTertiary),
          ),
          const SizedBox(height: Space.sm),
          for (final (i, p) in papers.take(_shown).indexed) ...[
            if (i > 0) const Divider(),
            _PaperRow(paper: p, onTap: onOpen == null ? null : () => onOpen!(p)),
          ],
        ],
      ),
    );
  }
}

class _PaperRow extends StatelessWidget {
  const _PaperRow({required this.paper, this.onTap});

  final Item paper;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    final first = paper.authors.isEmpty ? null : paper.authors.first;
    final meta = [
      if (first != null) paper.authors.length > 1 ? '$first et al.' : first,
      if (paper.categories.isNotEmpty) paper.categories.first,
      timeAgo(paper.publishedAt),
    ].join('  ·  ');
    final reason = paper.matchedTerms.isNotEmpty
        ? 'Matches “${paper.matchedTerms.first}”'
        : (paper.matchedByMeaning ? 'Related to your interests' : null);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(Radii.sm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Space.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: Space.xxs),
              child: Icon(Icons.description_outlined, size: Sizes.iconMd, color: c.textTertiary),
            ),
            const SizedBox(width: Space.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(paper.title ?? '', maxLines: 2, overflow: TextOverflow.ellipsis, style: t.headlineSmall),
                  const SizedBox(height: Space.xxs),
                  Text(meta, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.caption.copyWith(color: c.textTertiary)),
                  if (reason != null) ...[
                    const SizedBox(height: Space.xs),
                    PaperTag(label: reason, emphasis: true),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
