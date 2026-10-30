import 'package:flutter/material.dart';

import '../../core/models/models.dart';
import '../../core/theme/tokens.dart';
import '../../shared/formatting.dart';
import '../../shared/widgets/ask_story_box.dart';
import '../../shared/widgets/citation_chip.dart';
import '../../shared/widgets/disagreement_panel.dart';
import '../../shared/widgets/glass.dart';
import '../../shared/widgets/new_facts_badge.dart';
import '../../shared/widgets/section_header.dart';
import '../../shared/widgets/source_chip.dart';
import '../../shared/widgets/story_card.dart';
import '../../shared/widgets/story_timeline.dart';
import '../../shared/widgets/story_visual.dart';
import '../../shared/widgets/whats_new_section.dart';

/// The story page, in a fixed order: summary, what's new, where sources
/// disagree, how it developed, every source, then ask this story. A floating
/// toolbar listens, jumps to sections, saves and shares.
class StoryDetailView extends StatefulWidget {
  const StoryDetailView({
    super.key,
    required this.story,
    this.onListen,
    this.onShare,
    this.askQuestion,
    this.askResult,
    this.askThinking = false,
    this.askUnavailable = false,
    this.askSuggestions = const [],
    this.onAsk,
  });

  final Story story;
  final VoidCallback? onListen;
  final VoidCallback? onShare;

  /// Ask this story (secondary, rule 4). The parent owns the async work and
  /// rebuilds with the answer; without [onAsk] the box explains it is idle.
  final String? askQuestion;
  final AskResult? askResult;
  final bool askThinking;
  final bool askUnavailable;
  final List<String> askSuggestions;
  final ValueChanged<String>? onAsk;

  @override
  State<StoryDetailView> createState() => _StoryDetailViewState();
}

class _StoryDetailViewState extends State<StoryDetailView> {
  final _whatsNew = GlobalKey();
  final _disagreements = GlobalKey();
  final _timeline = GlobalKey();
  final _sources = GlobalKey();
  final _ask = GlobalKey();
  bool _saved = false;

  void _jumpTo(GlobalKey key) {
    final target = key.currentContext;
    if (target == null) return;
    Scrollable.ensureVisible(
      target,
      duration: Motion.motionOf(context, Motion.pane),
      curve: Motion.standard,
      alignment: 0.05,
    );
  }

  @override
  Widget build(BuildContext context) {
    final story = widget.story;
    final c = context.colors;
    final t = context.text;
    final sources = [...story.sources]..sort((a, b) => (b.followed ? 1 : 0) - (a.followed ? 1 : 0));
    final firstReport = story.timeline.isEmpty
        ? null
        : story.timeline.reduce((a, b) => a.at.isBefore(b.at) ? a : b);

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= Sizes.readingWidth;
        return Stack(
          children: [
            SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                wide ? Space.xxl : Space.lg,
                Space.xl,
                wide ? Space.xxl : Space.lg,
                Space.xxxl * 2.5,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: Sizes.readingWidth),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        [story.topic, 'updated ${timeAgo(story.updatedAt)}'].join('  ·  '),
                        style: t.caption.copyWith(color: c.textTertiary),
                      ),
                      const SizedBox(height: Space.sm),
                      Text(story.title, style: wide ? t.display : t.title),
                      const SizedBox(height: Space.md),
                      Wrap(
                        spacing: Space.md,
                        runSpacing: Space.sm,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          SourceSummary(story: story),
                          if (story.lastReadAt != null)
                            NewFactsBadge(count: story.newFactCount, since: story.lastReadAt),
                        ],
                      ),
                      if (firstReport != null) ...[
                        const SizedBox(height: Space.sm),
                        Text(
                          'First reported ${shortDate(firstReport.at)}, ${clockTime(firstReport.at)}  ·  '
                          '${plural(story.itemCount, 'item')} in ${plural(story.languages.length, 'language')}',
                          style: t.caption.copyWith(color: c.textTertiary),
                        ),
                      ],
                      const SizedBox(height: Space.xl),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(Radii.lg),
                        child: StoryVisual(
                          seed: story.visualSeed,
                          threads: story.sources.length,
                          aspectRatio: 2.6,
                          isIllustration: story.hasIllustration,
                        ),
                      ),
                      const SizedBox(height: Space.xl),
                      if (story.summaryPoints.isEmpty)
                        Text(story.summary, style: t.reading)
                      else
                        for (final point in story.summaryPoints) ...[
                          Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(text: '${point.text} '),
                                WidgetSpan(
                                  alignment: PlaceholderAlignment.middle,
                                  child: CitationGroup(sources: point.sources, onOpenSource: (_) {}),
                                ),
                              ],
                            ),
                            style: t.reading,
                          ),
                          const SizedBox(height: Space.md),
                        ],
                      const SizedBox(height: Space.sm),
                      Text(
                        'Summary written by OSMS from ${plural(story.sources.length, 'source')}. '
                        'Tap a source to read the original.',
                        style: t.caption.copyWith(color: c.textTertiary),
                      ),
                      const SizedBox(height: Space.xxl),
                      KeyedSubtree(
                        key: _whatsNew,
                        child: WhatsNewSection(claims: story.whatsNew, since: story.lastReadAt),
                      ),
                      const SizedBox(height: Space.xxl),
                      KeyedSubtree(key: _disagreements, child: DisagreementPanel(disagreements: story.disagreements)),
                      const SizedBox(height: Space.xxl),
                      KeyedSubtree(
                        key: _timeline,
                        child: StoryTimeline(events: story.timeline, lastReadAt: story.lastReadAt),
                      ),
                      const SizedBox(height: Space.xxl),
                      SectionHeader(
                        key: _sources,
                        icon: Icons.layers_outlined,
                        title: 'Every source',
                        trailing: CountPill(count: sources.length),
                      ),
                      const SizedBox(height: Space.xs),
                      Text('Yours come first, ticked.', style: t.caption.copyWith(color: c.textTertiary)),
                      const SizedBox(height: Space.md),
                      Wrap(
                        spacing: Space.sm,
                        runSpacing: Space.sm,
                        children: [for (final s in sources) SourceChip(source: s, onTap: () {})],
                      ),
                      const SizedBox(height: Space.xxl),
                      KeyedSubtree(
                        key: _ask,
                        child: AskStoryBox(
                          question: widget.askQuestion,
                          result: widget.askResult,
                          thinking: widget.askThinking,
                          unavailable: widget.askUnavailable,
                          suggestions: widget.askSuggestions,
                          onAsk: widget.onAsk,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              left: Space.lg,
              right: Space.lg,
              bottom: Space.lg,
              child: Center(
                child: _StoryToolbar(
                  saved: _saved,
                  hasDisagreements: story.disagreements.isNotEmpty,
                  onListen: widget.onListen ?? () {},
                  onWhatsNew: () => _jumpTo(_whatsNew),
                  onDisagreements: () => _jumpTo(_disagreements),
                  onTimeline: () => _jumpTo(_timeline),
                  onSources: () => _jumpTo(_sources),
                  onAsk: () => _jumpTo(_ask),
                  onSave: () => setState(() => _saved = !_saved),
                  onShare: widget.onShare ?? () {},
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Neutral ink on glass: violet means "new" and never appears here. The main
/// action (Listen) sits apart from the jumps, which sit apart from save/share.
class _StoryToolbar extends StatelessWidget {
  const _StoryToolbar({
    required this.saved,
    required this.hasDisagreements,
    required this.onListen,
    required this.onWhatsNew,
    required this.onDisagreements,
    required this.onTimeline,
    required this.onSources,
    required this.onAsk,
    required this.onSave,
    required this.onShare,
  });

  final bool saved;
  final bool hasDisagreements;
  final VoidCallback onListen;
  final VoidCallback onWhatsNew;
  final VoidCallback onDisagreements;
  final VoidCallback onTimeline;
  final VoidCallback onSources;
  final VoidCallback onAsk;
  final VoidCallback onSave;
  final VoidCallback onShare;

  static const _compactBelow = 460.0;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    Widget gap() => Container(
      width: Sizes.hairline,
      height: Space.xl,
      margin: const EdgeInsets.symmetric(horizontal: Space.xs),
      color: c.border,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        // Phones get an icon-only Listen and drop the "every source" jump.
        final compact = constraints.maxWidth < _compactBelow;
        final density = compact ? VisualDensity.compact : VisualDensity.standard;
        return GlassSurface(
          padding: const EdgeInsets.all(Space.sm),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (compact)
                IconButton.filled(
                  tooltip: 'Listen',
                  onPressed: onListen,
                  icon: const Icon(Icons.headphones_rounded),
                )
              else
                FilledButton.icon(
                  onPressed: onListen,
                  icon: const Icon(Icons.headphones_rounded, size: Sizes.iconMd),
                  label: const Text('Listen'),
                ),
              gap(),
              IconButton(
                tooltip: 'What’s new',
                visualDensity: density,
                onPressed: onWhatsNew,
                icon: const Icon(Icons.update_rounded),
              ),
              IconButton(
                tooltip: hasDisagreements ? 'Where sources disagree' : 'Sources agree so far',
                visualDensity: density,
                onPressed: onDisagreements,
                icon: const Icon(Icons.compare_arrows_rounded),
              ),
              IconButton(
                tooltip: 'Timeline',
                visualDensity: density,
                onPressed: onTimeline,
                icon: const Icon(Icons.timeline_rounded),
              ),
              if (!compact)
                IconButton(tooltip: 'Every source', onPressed: onSources, icon: const Icon(Icons.layers_outlined)),
              IconButton(
                tooltip: 'Ask this story',
                visualDensity: density,
                onPressed: onAsk,
                icon: const Icon(Icons.contact_support_outlined),
              ),
              gap(),
              IconButton(
                tooltip: saved ? 'Saved' : 'Save for later',
                visualDensity: density,
                isSelected: saved,
                onPressed: onSave,
                icon: const Icon(Icons.bookmark_outline_rounded),
                selectedIcon: const Icon(Icons.bookmark_rounded),
              ),
              IconButton(
                tooltip: 'Share',
                visualDensity: density,
                onPressed: onShare,
                icon: const Icon(Icons.share_outlined),
              ),
            ],
          ),
        );
      },
    );
  }
}
