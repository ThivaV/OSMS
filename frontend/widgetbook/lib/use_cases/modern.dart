import 'package:flutter/material.dart';
import 'package:osms/core/layout/three_pane_layout.dart';
import 'package:osms/core/theme/tokens.dart';
import 'package:osms/features/briefing/briefing_player.dart';
import 'package:osms/features/search/command_palette.dart';
import 'package:osms/features/stories/story_list.dart';
import 'package:osms/features/stories/today_overview.dart';
import 'package:osms/shared/widgets/pill_nav.dart';
import 'package:osms/shared/widgets/source_chip.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart' as widgetbook;

import '../fixtures/fixtures.dart' as fx;
import 'frame.dart';

// ── Today overview ───────────────────────────────────────────────────────────

@widgetbook.UseCase(name: 'Normal', type: TodayOverview, path: '[Story]')
Widget todayNormal(BuildContext context) =>
    Material(
      child: TodayOverview(
        stories: fx.stories,
        briefing: fx.briefing,
        user: fx.user,
        research: fx.research,
        onOpen: (_) {},
        onOpenPaper: (_) {},
      ),
    );

@widgetbook.UseCase(name: 'Empty', type: TodayOverview, path: '[Story]')
Widget todayEmpty(BuildContext context) => const Material(child: TodayOverview(stories: []));

@widgetbook.UseCase(name: 'Extreme content', type: TodayOverview, path: '[Story]')
Widget todayExtreme(BuildContext context) => Material(
  child: TodayOverview(
    stories: [fx.extremeStory, ...fx.stories, ...fx.stories],
    briefing: fx.extremeBriefing,
    user: fx.longUser,
    research: [fx.extremePaper, ...fx.research, ...fx.research],
    onOpen: (_) {},
    onOpenPaper: (_) {},
  ),
);

// ── Floating bars (glass) ────────────────────────────────────────────────────

/// The list scrolls under the bars, so the frosting shows. Switch the theme
/// addon, or Settings → Floating bars, to compare Frosted, Tinted and Solid.
Widget _overList(Widget bars) => Material(
  child: Stack(
    children: [
      Positioned.fill(child: StoryList(stories: fx.stories, bottomInset: ThreePaneLayout.floatingInset * 1.6)),
      Positioned(left: Space.lg, right: Space.lg, bottom: Space.lg, child: Center(child: bars)),
    ],
  ),
);

@widgetbook.UseCase(name: 'Normal', type: PillNav, path: '[Layout]')
Widget floatingNormal(BuildContext context) => _overList(
  Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      BriefingFloatingBar(briefing: fx.briefing),
      const SizedBox(height: Space.sm),
      _LivePillNav(),
    ],
  ),
);

@widgetbook.UseCase(name: 'Empty', type: PillNav, path: '[Layout]')
Widget floatingEmpty(BuildContext context) => _overList(_LivePillNav());

@widgetbook.UseCase(name: 'Extreme content', type: PillNav, path: '[Layout]')
Widget floatingExtreme(BuildContext context) => _overList(
  Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      BriefingFloatingBar(briefing: fx.extremeBriefing, chapter: 7),
      const SizedBox(height: Space.sm),
      _LivePillNav(
        destinations: const [
          PillNavDestination(icon: Icons.wb_sunny_outlined, label: 'Today'),
          PillNavDestination(icon: Icons.headphones_rounded, label: 'Briefing'),
          PillNavDestination(icon: Icons.bookmark_outline_rounded, label: 'Saved for later'),
          PillNavDestination(icon: Icons.layers_outlined, label: 'Sources and topics'),
          PillNavDestination(icon: Icons.tune_rounded, label: 'Settings'),
        ],
      ),
    ],
  ),
);

class _LivePillNav extends StatefulWidget {
  const _LivePillNav({
    this.destinations = const [
      PillNavDestination(icon: Icons.wb_sunny_outlined, label: 'Today'),
      PillNavDestination(icon: Icons.headphones_rounded, label: 'Briefing'),
      PillNavDestination(icon: Icons.bookmark_outline_rounded, label: 'Saved'),
      PillNavDestination(icon: Icons.layers_outlined, label: 'Sources'),
    ],
  });

  final List<PillNavDestination> destinations;

  @override
  State<_LivePillNav> createState() => _LivePillNavState();
}

class _LivePillNavState extends State<_LivePillNav> {
  int _selected = 0;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: Sizes.sheetMaxWidth),
    child: PillNav(destinations: widget.destinations, selected: _selected, onSelect: (i) => setState(() => _selected = i)),
  );
}

// ── Command palette ──────────────────────────────────────────────────────────

List<CommandItem> _items(int sources) => [
  for (final s in fx.stories)
    CommandItem(icon: Icons.article_outlined, label: s.title, detail: s.topic, group: 'Stories'),
  for (final s in sources > 10 ? fx.manySources(sources) : fx.followedSources)
    CommandItem(
      icon: Icons.rss_feed_rounded,
      label: s.name,
      detail: s.type.label,
      group: 'Sources',
      leading: SourceAvatar(source: s, size: Sizes.avatarSm),
    ),
  const CommandItem(icon: Icons.headphones_rounded, label: 'Play the morning briefing', group: 'Actions', shortcut: 'Space'),
  const CommandItem(icon: Icons.add_rounded, label: 'Add a source', group: 'Actions', shortcut: 'N'),
  const CommandItem(icon: Icons.science_outlined, label: 'Follow research on arXiv', group: 'Actions'),
  const CommandItem(icon: Icons.tune_rounded, label: 'Settings and themes', group: 'Actions', shortcut: '⌘,'),
];

@widgetbook.UseCase(name: 'Normal', type: CommandPalette, path: '[Layout]')
Widget paletteNormal(BuildContext context) => Frame(maxWidth: 640, child: CommandPalette(items: _items(6)));

@widgetbook.UseCase(name: 'Empty', type: CommandPalette, path: '[Layout]')
Widget paletteEmpty(BuildContext context) =>
    Frame(maxWidth: 640, child: CommandPalette(items: _items(6), initialQuery: 'zebra crossing'));

@widgetbook.UseCase(name: 'Extreme content', type: CommandPalette, path: '[Layout]')
Widget paletteExtreme(BuildContext context) =>
    Frame(maxWidth: 640, child: CommandPalette(items: _items(40), initialQuery: 'e'));
