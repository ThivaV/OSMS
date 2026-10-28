import 'package:flutter/material.dart';

import '../../core/models/models.dart';
import '../../core/theme/tokens.dart';
import '../../shared/formatting.dart';
import '../../shared/widgets/section_header.dart';
import '../../shared/widgets/story_card.dart';

/// Today's stories. The header says how many items they came from, in place
/// of an unread count.
class StoryList extends StatelessWidget {
  const StoryList({
    super.key,
    required this.stories,
    this.title = 'Today',
    this.selectedId,
    this.layout = StoryCardLayout.row,
    this.onSelect,
    this.onLayoutChanged,
    this.onAddSource,
    this.banner,
    this.bottomInset = Space.xl,
  });

  final List<Story> stories;

  /// Room under the last story, e.g. for a floating player.
  final double bottomInset;

  /// Shown under the header, e.g. the demo banner while signed out.
  final Widget? banner;
  final String title;
  final String? selectedId;
  final StoryCardLayout layout;
  final ValueChanged<Story>? onSelect;
  final ValueChanged<StoryCardLayout>? onLayoutChanged;
  final VoidCallback? onAddSource;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    final items = stories.fold(0, (sum, s) => sum + s.itemCount);
    final gap = layout == StoryCardLayout.card ? Space.lg : Space.xxs;

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(Space.lg, Space.xl, Space.lg, Space.md),
          sliver: SliverToBoxAdapter(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: t.title),
                      const SizedBox(height: Space.xxs),
                      Text(
                        stories.isEmpty
                            ? 'No stories yet'
                            : '${plural(stories.length, 'story', 'stories')} from ${plural(items, 'item')}',
                        style: t.caption.copyWith(color: c.textTertiary),
                      ),
                    ],
                  ),
                ),
                if (onLayoutChanged != null)
                  SegmentedButton<StoryCardLayout>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(value: StoryCardLayout.row, icon: Icon(Icons.view_list_rounded), tooltip: 'List'),
                      ButtonSegment(value: StoryCardLayout.card, icon: Icon(Icons.view_agenda_outlined), tooltip: 'Cards'),
                    ],
                    selected: {layout},
                    onSelectionChanged: (s) => onLayoutChanged!(s.first),
                  ),
              ],
            ),
          ),
        ),
        if (banner != null)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(Space.md, 0, Space.md, Space.md),
            sliver: SliverToBoxAdapter(child: banner),
          ),
        if (stories.isEmpty)
          SliverPadding(
            padding: const EdgeInsets.all(Space.lg),
            sliver: SliverToBoxAdapter(
              child: QuietNote(
                icon: Icons.inbox_outlined,
                title: 'Your stories will appear here',
                body: 'Add a few sources and OSMS groups everything they publish about the same event into one story.',
                action: FilledButton.icon(
                  onPressed: onAddSource ?? () {},
                  icon: const Icon(Icons.add_rounded, size: Sizes.iconMd),
                  label: const Text('Add a source'),
                ),
              ),
            ),
          )
        else
          SliverPadding(
            padding: EdgeInsets.fromLTRB(Space.sm, 0, Space.sm, bottomInset),
            sliver: SliverList.separated(
              itemCount: stories.length,
              separatorBuilder: (_, _) => SizedBox(height: gap),
              itemBuilder: (context, i) {
                final story = stories[i];
                final card = StoryCard(
                  story: story,
                  layout: layout,
                  selected: story.id == selectedId,
                  onTap: onSelect == null ? null : () => onSelect!(story),
                );
                return layout == StoryCardLayout.card
                    ? Padding(padding: const EdgeInsets.symmetric(horizontal: Space.sm), child: card)
                    : card;
              },
            ),
          ),
      ],
    );
  }
}
